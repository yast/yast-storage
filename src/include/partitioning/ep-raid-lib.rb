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
  module PartitioningEpRaidLibInclude
    def initialize_partitioning_ep_raid_lib(include_target)
      textdomain "storage"
    end

    def AddDevices(raid_dev, devs)
      devs = deep_copy(devs)
      ret = true

      Builtins.foreach(devs) do |dev|
        Storage.SetPartitionId(dev, Partitions.fsid_raid)
        Storage.SetPartitionFormat(dev, false, :none)
      end
      ret = false if !Storage.ExtendMd(raid_dev, devs)

      ret
    end


    def RemoveDevices(raid_dev, devs)
      devs = deep_copy(devs)
      ret = true

      Builtins.foreach(devs) do |dev|
        Storage.UnchangePartitionId(dev)
        ret = false if !Storage.ShrinkMd(raid_dev, [dev])
      end

      ret
    end

    def ReplaceDevices(raid_dev, devs)
      devs = deep_copy(devs)
      ret = true

      Builtins.foreach(devs) do |dev|
        Storage.SetPartitionId(dev, Partitions.fsid_raid)
        Storage.SetPartitionFormat(dev, false, :none)
      end
      ret = false if !Storage.ReplaceMd(raid_dev, devs)

      ret
    end

    def CanModifyRaid(data)
      data = deep_copy(data)
      ret = true
      if Ops.get_boolean(data, "raid_inactive", false)
        txt = Builtins.sformat(
          _(
            "\n" +
              "Raid %1 cannot be modified because it is in inactive state.\n" +
              "This normally means the subset of raid devices is too small\n" +
              "for the raid to be usable.\n"
          ),
          Ops.get_string(data, "device", "")
        )
        Popup.Error(txt)
        ret = false
      end
      ret
    end

    def EpCreateRaid
      target_map = Storage.GetTargetMap
      unused_devices = Builtins.filter(get_possible_rds(target_map)) do |dev|
        !Storage.IsUsedBy(dev)
      end

      if Ops.less_than(Builtins.size(unused_devices), 2)
        # error popup
        Popup.Error(
          _("There are not enough suitable unused devices to create a RAID.")
        )
        return
      end

      data = { "new" => true, "type" => :sw_raid, "create" => true }

      r = Storage.NextMd
      Ops.set(data, "device", Ops.get_string(r, "device", ""))
      Ops.set(data, "nr", Ops.get_integer(r, "nr", 0))

      if (
          data_ref = arg_ref(data);
          _DlgCreateRaidNew_result = DlgCreateRaidNew(data_ref);
          data = data_ref.value;
          _DlgCreateRaidNew_result
        )
        dev = data.fetch("device","")
        raid_type = Builtins.tosymbol(data.fetch("raid_type","raid0"))

        if Storage.CreateMdWithDevs(dev, raid_type, [])
          devices = Ops.get_list(data, "devices", [])
          AddDevices(dev, devices)

          chunk_size_k = Ops.get_integer(data, "chunk_size_k", 4)
          Storage.ChangeMdChunk(dev, chunk_size_k)

          if Builtins.haskey(data, "parity_algorithm")
            parity_algorithm = Ops.get_symbol(
              data,
              "parity_algorithm",
              :par_default
            )
	    if( parity_algorithm!=:par_default )
	      Storage.ChangeMdParitySymbol(dev, parity_algorithm)
	    end
          end

          Storage.ChangeVolumeProperties(data)

          UpdateMainStatus()
          UpdateNavigationTree(nil)
          TreePanel.Create
          UpdateTableFocus(Ops.get_string(data, "device", "error"))
        end
      end

      nil
    end


    def EpEditRaid(device)
      if device == nil
        # error popup
        Popup.Error(_("No RAID selected."))
        return
      end

      target_map = Storage.GetTargetMap
      data = Storage.GetPartition(target_map, device)

      return if !CanModifyRaid(data)

      if Storage.IsUsedBy(data)
        # error popup, %1 is replaced by device name e.g. /dev/md1
        Popup.Error(
          Builtins.sformat(
            _(
              "The RAID %1 is in use. It cannot be\nedited. To edit %1, make sure it is not used."
            ),
            device
          )
        )
        return
      end

      if (
          data_ref = arg_ref(data);
          _DlgEditRaid_result = DlgEditRaid(data_ref);
          data = data_ref.value;
          _DlgEditRaid_result
        )
        Storage.ChangeVolumeProperties(data)

        UpdateMainStatus()
        UpdateNavigationTree(nil)
        TreePanel.Create
        UpdateTableFocus(device)
      end

      nil
    end


    def EpResizeRaid(device)
      if device == nil
        # error popup
        Popup.Error(_("No RAID selected."))
        return
      end

      target_map = Storage.GetTargetMap
      data = Storage.GetPartition(target_map, device)

      return if !CanModifyRaid(data)

      if !Ops.get_boolean(data, "create", false)
        # error popup, %1 is replaced by device name e.g. /dev/md1
        Popup.Error(
          Builtins.sformat(
            _(
              "The RAID %1 is already created on disk. It cannot be\nresized. To resize %1, remove it and create it again."
            ),
            device
          )
        )
        return
      end

      if Storage.IsUsedBy(data)
        # error popup, %1 is replaced by device name e.g. /dev/md1
        Popup.Error(
          Builtins.sformat(
            _(
              "The RAID %1 is in use. It cannot be\nresized. To resize %1, make sure it is not used."
            ),
            device
          )
        )
        return
      end

      if (
          data_ref = arg_ref(data);
          _DlgResizeRaid_result = DlgResizeRaid(data_ref);
          data = data_ref.value;
          _DlgResizeRaid_result
        )
        dev = data.fetch("device","")
        devices_new = Ops.get_list(data, "devices_new", [])
        Builtins.y2milestone("devices_new:%1", devices_new)
        if Ops.greater_than(Builtins.size(devices_new), 0)
          ReplaceDevices(dev, devices_new)
          UpdateMainStatus()
          UpdateNavigationTree(nil)
          TreePanel.Create
        end
      end

      nil
    end


    def EpDeleteRaid(device)
      if device == nil
        # error popup
        Popup.Error(_("No RAID selected."))
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
  end
end
