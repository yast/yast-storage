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
  module PartitioningEpDmLibInclude
    def initialize_partitioning_ep_dm_lib(include_target)
      textdomain "storage"
    end

    def EpEditDmDevice(device)
      if device == nil
        # error popup
        Popup.Error(_("No DM device selected."))
        return
      end

      target_map = Storage.GetTargetMap
      data = Storage.GetPartition(target_map, device)

      if Storage.IsUsedBy(data)
        # error popup
        Popup.Error(
          Builtins.sformat(
            _(
              "The DM %1 is in use. It cannot be\nedited. To edit %1, make sure it is not used."
            ),
            device
          )
        )
        return
      end

      if (
          data_ref = arg_ref(data);
          _DlgEditDmVolume_result = DlgEditDmVolume(data_ref);
          data = data_ref.value;
          _DlgEditDmVolume_result
        )
        Storage.ChangeVolumeProperties(data)

        UpdateMainStatus()
        UpdateNavigationTree(nil)
        TreePanel.Create
        UpdateTableFocus(device)
      end

      nil
    end
  end
end
