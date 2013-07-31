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
  module PartitioningEpLoopLibInclude
    def initialize_partitioning_ep_loop_lib(include_target)
      textdomain "storage"
    end

    def EpCreateLoop
      data = { "new" => true, "create" => true }

      Ops.set(data, "type", :loop)
      Ops.set(data, "format", true)

      if (
          data_ref = arg_ref(data);
          _DlgCreateLoop_result = DlgCreateLoop(data_ref);
          data = data_ref.value;
          _DlgCreateLoop_result
        )
        device = Storage.CreateLoop(
          Ops.get_string(data, "fpath", ""),
          Ops.get_boolean(data, "create_file", false),
          Ops.get_integer(data, "size_k", 0),
          Ops.get_string(data, "mount", "")
        )
        Ops.set(data, "device", device)

        Storage.ChangeVolumeProperties(data)

        UpdateMainStatus()
        UpdateNavigationTree(nil)
        TreePanel.Create
        UpdateTableFocus(device)
      end

      nil
    end


    def EpEditLoop(device)
      if device == nil
        Popup.Error(_("No crypt file selected."))
        return
      end

      target_map = Storage.GetTargetMap
      data = Storage.GetPartition(target_map, device)

      if Storage.IsUsedBy(data)
        # error popup, %1 is replaced by device name
        Popup.Error(
          Builtins.sformat(
            _(
              "The Crypt File %1 is in use. It cannot be\nedited. To edit %1, make sure it is not used."
            ),
            device
          )
        )
        return
      end

      if (
          data_ref = arg_ref(data);
          _DlgEditLoop_result = DlgEditLoop(data_ref);
          data = data_ref.value;
          _DlgEditLoop_result
        )
        Storage.ChangeVolumeProperties(data)

        UpdateMainStatus()
        UpdateNavigationTree(nil)
        TreePanel.Create
        UpdateTableFocus(device)
      end

      nil
    end


    def EpDeleteLoop(device)
      if device == nil
        # error popup
        Popup.Error(_("No crypt file selected."))
        return
      end

      if EpDeleteDevice(device)
        UpdateMainStatus()
        UpdateNavigationTree(:loop)
        TreePanel.Create
      end

      nil
    end
  end
end
