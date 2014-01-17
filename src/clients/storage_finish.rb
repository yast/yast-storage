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

# File:
#  storage_finish.ycp
#
# Module:
#  Step of base installation finish
#
# Authors:
#  Jiri Srain <jsrain@suse.cz>
#
# $Id$
#
module Yast
  class StorageFinishClient < Client

    def main

      textdomain "storage"

      Yast.import "Storage"
      Yast.import "StorageSettings"
      Yast.import "StorageUpdate"
      Yast.import "Mode"
      Yast.import "Installation"

      @ret = nil
      @func = ""
      @param = {}

      # Check arguments
      if Ops.greater_than(Builtins.size(WFM.Args), 0) &&
          Ops.is_string?(WFM.Args(0))
        @func = Convert.to_string(WFM.Args(0))
        if Ops.greater_than(Builtins.size(WFM.Args), 1) &&
            Ops.is_map?(WFM.Args(1))
          @param = Convert.to_map(WFM.Args(1))
        end
      end

      Builtins.y2milestone("starting storage_finish")
      Builtins.y2debug("func=%1", @func)
      Builtins.y2debug("param=%1", @param)

      if @func == "Info"
        return {
          "steps" => 1,
          # progress step title
          "title" => _(
            "Saving file system configuration..."
          ),
          "when"  => [:installation, :live_installation, :update, :autoinst]
        }
      elsif @func == "Write"
        #     list<string> storage_initrdm = (list<string>)Storage::GetRootInitrdModules();
        #     foreach(string m, storage_initrdm, {
        #         Initrd::AddModule (m, "");
        #     });
        if !Mode.update
          SCR.Execute(path(".target.mkdir"), Installation.sourcedir)
          Storage.FinishInstall
        else
          StorageUpdate.Update(
            Installation.installedVersion,
            Installation.updateVersion
          )
        end
        if Storage.CheckForLvmRootFs
          SCR.Execute(path(".target.bash"), "/sbin/vgscan")
        end
        Storage.SaveUsedFs
        StorageSettings.Save

        if Mode.installation
          @part = Storage.GetEntryForMountpoint("/")
          if Ops.get_symbol(@part, "used_fs", :unknown) == :btrfs
            if SCR.Execute(path(".target.bash"), "/usr/bin/snapper --no-dbus create-config --fstype=btrfs /") == 0
              SCR.Execute(path(".target.bash"), "/usr/bin/snapper --no-dbus set-config " <<
                          "NUMBER_CLEANUP=yes NUMBER_LIMIT=20 NUMBER_LIMIT_IMPORTANT=10")
              SCR.Write(path(".sysconfig.yast2.USE_SNAPPER"), "yes")
            end
          end
        end

      else
        Builtins.y2error("unknown function: %1", @func)
        @ret = nil
      end

      Builtins.y2debug("ret=%1", @ret)
      Builtins.y2milestone("storage_finish finished")
      deep_copy(@ret)
    end

  end
end

Yast::StorageFinishClient.new.main
