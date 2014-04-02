# encoding: utf-8

# Copyright (c) [2012-2014] Novell, Inc.
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


require "yast"


module Yast

  class StorageUtilsClass < Module

    def main

      textdomain "storage"

      Yast.import "Storage"

    end


    def ConfigureSnapper()
      part = Storage.GetEntryForMountpoint("/")
      if part.fetch("used_fs", :unknown) == :btrfs
        userdata = part.fetch("userdata", {})
        if userdata.fetch("/", "") == "snapshots"
          Builtins.y2milestone("configuring snapper for root fs")
          if SCR.Execute(path(".target.bash"), "/usr/bin/snapper --no-dbus create-config " <<
                         "--fstype=btrfs --add-fstab /") == 0
            SCR.Execute(path(".target.bash"), "/usr/bin/snapper --no-dbus set-config " <<
                        "NUMBER_CLEANUP=yes NUMBER_LIMIT=20 NUMBER_LIMIT_IMPORTANT=10")
            SCR.Write(path(".sysconfig.yast2.USE_SNAPPER"), "yes")
          else
            Builtins.y2error("configuring snapper for root fs failed")
          end
        end
      end
    end

  end

  StorageUtils = StorageUtilsClass.new
  StorageUtils.main

end
