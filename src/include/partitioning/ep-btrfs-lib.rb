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
  module PartitioningEpBtrfsLibInclude
    def initialize_partitioning_ep_btrfs_lib(include_target)
      textdomain "storage"
    end

    def EpEditBtrfsDevice(device)
      if device == nil
        # error popup
        Popup.Error(_("No Btrfs device selected."))
        return
      end

      target_map = Storage.GetTargetMap
      data = Storage.GetPartition(target_map, device)
      Builtins.y2milestone("EpEditBtrfsDevice device:%1 data:%2", device, data)

      if Storage.IsUsedBy(data)
        # error popup
        Popup.Error(
          Builtins.sformat(
            _(
              "The Btrfs %1 is in use. It cannot be\nedited. To edit %1, make sure it is not used."
            ),
            Ops.get_string(data, "uuid", "")
          )
        )
        return
      end

      if (
          data_ref = arg_ref(data);
          _DlgEditBtrfsVolume_result = DlgEditBtrfsVolume(data_ref);
          data = data_ref.value;
          _DlgEditBtrfsVolume_result
        )
        Storage.ChangeVolumeProperties(data)

        UpdateMainStatus()
        UpdateNavigationTree(nil)
        TreePanel.Create
        UpdateTableFocus(device)
      end

      nil
    end

    def EpDeleteBtrfsDevice(device)
      if device == nil
        # error popup
        Popup.Error(_("No Btrfs device selected."))
        return
      end

      target_map = Storage.GetTargetMap
      data = Storage.GetPartition(target_map, device)
      Builtins.y2milestone("EpDeletBtrfsDevice device:%1 data:%2", device, data)

      if !Storage.CanDelete(data, Ops.get(target_map, "/dev/btrfs", {}), true)
        return
      end

      if EpDeleteDevice(device)
        new_focus = nil
        new_focus = :md if UI.QueryWidget(:tree, :CurrentItem) == device
        UpdateMainStatus()
        UpdateNavigationTree(new_focus)
        TreePanel.Create
      end

      nil
    end

    def AddVols(device, devs)
      ret = true
      tg = Storage.GetTargetMap

      Builtins.foreach(devs) do |dev|
	if dev!=device
	  p = Storage.GetPartition(tg, dev)
	  if( p.key?("fsid") && p["fsid"]!=Partitions.fsid_native )
	    Storage.SetPartitionId(dev, Partitions.fsid_native)
	  end
	  Storage.SetPartitionFormat(dev, false, :none)
	  ret = false if !Storage.ExtendBtrfsVolume(device, dev)
	end
      end
      ret
    end


    def RemoveVols(device, devs)
      ret = true

      Builtins.foreach(devs) do |dev|
        Storage.UnchangePartitionId(dev)
        ret = false if !Storage.ReduceBtrfsVolume(device, dev)
      end
      ret
    end

    def EpResizeBtrfsDevice(device)
      if device == nil
        # error popup
        Popup.Error(_("No Btrfs device selected."))
        return
      end

      target_map = Storage.GetTargetMap
      data = Storage.GetPartition(target_map, device)
      Builtins.y2milestone(
        "EpResizeBtrfsDevice device:%1 data:%2",
        device,
        data
      )

      _Commit = lambda do |data|
        devices_old = MergeDevices(data)
        devices_new = Ops.get_list(data, "devices_new", [])

        devices_added = AddedToList(devices_old, devices_new)
        devices_removed = RemovedFromList(devices_old, devices_new)

        if Ops.greater_than(Builtins.size(devices_added), 0)
          Builtins.y2milestone(
            "EpResizeBtrfsDevice device_added:%1",
            devices_added
          )
        end
        if Ops.greater_than(Builtins.size(devices_removed), 0)
          Builtins.y2milestone(
            "EpResizeBtrfsDevice device_removed:%1",
            devices_removed
          )
        end

        if Ops.greater_than(Builtins.size(devices_added), 0) ||
            Ops.greater_than(Builtins.size(devices_removed), 0)
          AddVols(device, devices_added)

          if !RemoveVols(device, devices_removed)
            # error popup
            Popup.Error(_("Failed to remove some physical devices."))

            # TODO: update data

            return :back
          end
        end

        :finish
      end

      if (
          data_ref = arg_ref(data);
          _DlgResizeBtrfsVolume_result = DlgResizeBtrfsVolume(
            data_ref,
            fun_ref(_Commit, "symbol (map)")
          );
          data = data_ref.value;
          _DlgResizeBtrfsVolume_result
        )
        UpdateMainStatus()
        UpdateNavigationTree(nil)
        TreePanel.Create
      end

      nil
    end
  end
end
