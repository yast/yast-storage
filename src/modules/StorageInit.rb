# encoding: utf-8

# Copyright (c) 2012 Novell, Inc.
#
# All Rights Reserved.
#
# This program is free software; you can redistribute it and/or modify it
# under the terms of version 2 of the GNU General Public License as published
# by the Free Software Foundation.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
# FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
# more details.
#
# You should have received a copy of the GNU General Public License along
# with this program; if not, contact Novell, Inc.
#
# To contact Novell about this file by physical or electronic mail, you may
# find current contact information at www.novell.com.

# Module:              StorageInit.ycp
#
# Authors:             Thomas Fehr (fehr@suse.de)
#
# Purpose:             Helper module to initialize libstorage
require "storage"
require "yast"

module Yast
  class StorageInitClass < Module
    def main

      textdomain "storage"

      Yast.import "Popup"
      Yast.import "Mode"
      Yast.import "Stage"
      Yast.import "Label"

      @sint = nil
    end

    def GetProcessName(pid)
      name = Convert.to_string(
        SCR.Read(
          path(".target.symlink"),
          Ops.add(Ops.add("/proc/", Builtins.tostring(pid)), "/exe")
        )
      )
      return nil if name == nil

      pos = Builtins.findlastof(name, "/")
      return name if pos == nil

      Builtins.substring(name, Ops.add(pos, 1))
    end

    def CreateInterface(readonly)

      while @sint == nil
        Builtins.y2milestone("ro:%1", readonly )
        env = ::Storage::Environment.new(readonly)
        Builtins.y2milestone("ro:%1 test:%2 auto:%3 instsys:%4", 
	                     env.readonly, env.testmode, env.autodetect, 
			     env.instsys )
	env.testmode = Mode.test;
	env.autodetect = !Mode.test;
	env.instsys = Stage.initial || Mode.repair;
        Builtins.y2milestone("ro:%1 test:%2 auto:%3 instsys:%4", 
	                     env.readonly, env.testmode, env.autodetect, 
			     env.instsys )

        locker_pid = 0
        @sint, locker_pid = ::Storage::createStorageInterfacePid(env)

        if @sint.kind_of?(Fixnum)
	  locker_pid = @sint
	  @sint = nil
          locker_name = GetProcessName(locker_pid)
          Builtins.y2milestone(
            "locker_pid:%1 locker_name:%2",
            locker_pid,
            locker_name
          )

          if locker_name == nil
            if !Popup.AnyQuestion(
                Label.ErrorMsg,
                # error popup
                _(
                  "The storage subsystem is locked by an unknown application.\nYou must quit that application before you can continue."
                ),
                Label.ContinueButton,
                Label.CancelButton,
                :focus_no
              )
              break
            end
          else
            if !Popup.AnyQuestion(
                Label.ErrorMsg,
                # error popup
                Builtins.sformat(
                  _(
                    "The storage subsystem is locked by the application \"%1\" (%2).\nYou must quit that application before you can continue."
                  ),
                  locker_name,
                  locker_pid
                ),
                Label.ContinueButton,
                Label.CancelButton,
                :focus_no
              )
              break
            end
          end
        end
      end
      Builtins.y2milestone("sint:%1", @sint)
      @sint
    end

    publish :function => :CreateInterface, :type => "any (boolean)"
  end

  StorageInit = StorageInitClass.new
  StorageInit.main
end
