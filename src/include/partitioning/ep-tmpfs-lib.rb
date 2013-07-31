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

# File:        ep-main.ycp
# Package:     yast2-storage
# Summary:     Expert Partitioner
# Authors:     Arvin Schnell <aschnell@suse.de>
module Yast
  module PartitioningEpTmpfsLibInclude
    def initialize_partitioning_ep_tmpfs_lib(include_target)
      textdomain "storage"
    end

    def EpDeleteTmpfsDevice(device)
      if device == nil
        # error popup
        Popup.Error(_("No tmpfs device selected."))
        return
      end

      tmp = Builtins.splitstring(device, ":")
      mount = Ops.get(tmp, 1, "")
      Builtins.y2milestone(
        "EpDeleteTmpfsDevice device:%1 mount:%2",
        device,
        mount
      )
      # YesNo popup.  %1 is path to a file
      if Popup.YesNo(
          Builtins.sformat(_("\nReally delete tmpfs mounted to %1"), mount)
        ) &&
          Storage.DelTmpfsVolume(mount)
        new_focus = nil
        new_focus = :tmpfs if UI.QueryWidget(:tree, :CurrentItem) == device
        UpdateMainStatus()
        UpdateNavigationTree(new_focus)
        TreePanel.Create
      end

      nil
    end

    def EpAddTmpfsDevice
      data = {
        "device"      => "tmpfs",
        "fstype"      => "TMPFS",
        "format"      => true,
        "type"        => :tmpfs,
        "detected_fs" => :tmpfs,
        "used_fs"     => :tmpfs
      }
      if (
          data_ref = arg_ref(data);
          _DlgCreateTmpfs_result = DlgCreateTmpfs(data_ref);
          data = data_ref.value;
          _DlgCreateTmpfs_result
        )
        Builtins.y2milestone("EpAddTmpfsDevice data:%1", data)
        Storage.AddTmpfsVolume(
          Ops.get_string(data, "mount", ""),
          Ops.get_string(data, "fstopt", "")
        )
        UpdateMainStatus()
        UpdateNavigationTree(nil)
        TreePanel.Create
      end

      nil
    end
  end
end
