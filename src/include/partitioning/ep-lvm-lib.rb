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
  module PartitioningEpLvmLibInclude
    def initialize_partitioning_ep_lvm_lib(include_target)
      textdomain "storage"
    end

    def AddPvs(vg_name, devs)
      devs = deep_copy(devs)
      ret = true

      Builtins.foreach(devs) do |dev|
        Storage.SetPartitionId(dev, Partitions.fsid_lvm)
        Storage.SetPartitionFormat(dev, false, :none)
        ret = false if !Storage.ExtendLvmVg(vg_name, dev)
      end

      ret
    end


    def RemovePvs(vg_name, devs)
      devs = deep_copy(devs)
      ret = true

      Builtins.foreach(devs) do |dev|
        Storage.UnchangePartitionId(dev)
        ret = false if !Storage.ReduceLvmVg(vg_name, dev)
      end

      ret
    end


    def EpCreateVolumeGroup
      target_map = Storage.GetTargetMap
      unused_pvs = Builtins.filter(get_possible_pvs(target_map)) do |pv|
        !Storage.IsUsedBy(pv)
      end

      if Ops.less_than(Builtins.size(unused_pvs), 1)
        # error popup
        Popup.Error(
          _(
            "There are not enough suitable unused devices to create a volume group.\n" +
              "\n" +
              "To use LVM, at least one unused partition of type 0x8e (or 0x83) or one unused\n" +
              "RAID device is required. Change your partition table accordingly."
          )
        )
        return
      end

      data = {}

      if (
          data_ref = arg_ref(data);
          _DlgCreateVolumeGroupNew_result = DlgCreateVolumeGroupNew(data_ref);
          data = data_ref.value;
          _DlgCreateVolumeGroupNew_result
        )
        vg_name = Ops.get_string(data, "name", "error")
        pe_size = Ops.get_integer(data, "pesize", 0)

        if Storage.CreateLvmVgWithDevs(vg_name, pe_size, true, [])
          devices = Ops.get_list(data, "devices", [])
          AddPvs(vg_name, devices)

          UpdateMainStatus()
          UpdateNavigationTree(nil)
          TreePanel.Create
          UpdateTableFocus(Ops.add("/dev/", vg_name))
        end
      end

      nil
    end


    def EpResizeVolumeGroup(device)
      if device == nil
        # error popup
        Popup.Error(_("No volume group selected."))
        return
      end

      target_map = Storage.GetTargetMap
      data = Convert.convert(
        Ops.get(target_map, device, {}),
        :from => "map",
        :to   => "map <string, any>"
      )

      vgname = Ops.get_string(data, "name", "error")


      _Commit = lambda do |data|
        devices_old = MergeDevices(data)
        devices_new = Ops.get_list(data, "devices_new", [])

        devices_added = AddedToList(devices_old, devices_new)
        devices_removed = RemovedFromList(devices_old, devices_new)

        if Ops.greater_than(Builtins.size(devices_added), 0) ||
            Ops.greater_than(Builtins.size(devices_removed), 0)
          AddPvs(vgname, devices_added)

          if !RemovePvs(vgname, devices_removed)
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
          _DlgResizeVolumeGroup_result = DlgResizeVolumeGroup(
            data_ref,
            fun_ref(_Commit, "symbol (map)")
          );
          data = data_ref.value;
          _DlgResizeVolumeGroup_result
        )
        UpdateMainStatus()
        UpdateNavigationTree(nil)
        TreePanel.Create
      end

      nil
    end
    def EpDeleteVolumeGroup(device)
      if device == nil
        # error popup
        Popup.Error(_("No volume group selected."))
        return false
      end

      vgname = Builtins.substring(device, 5)
      #LV device names
      log_volumes = Storage.GetAffectedDevices(device)
      #how many of those we have?
      count = Builtins.size(log_volumes)

      ret = false
      proceed = Ops.greater_than(count, 0) ?
        #non-empty VG - make sure user wants to delete all LVs
        ConfirmVgDelete(vgname, log_volumes) :
        #empty VG - simple
        Popup.YesNo(
          Builtins.sformat(_("Really delete the volume group \"%1\"?"), vgname)
        )

      if proceed
        recursive = Storage.GetRecursiveRemoval
        Storage.SetRecursiveRemoval(true)

        if Storage.DeleteLvmVg(vgname)
          new_focus = nil
          new_focus = :lvm if UI.QueryWidget(:tree, :CurrentItem) == device

          UpdateMainStatus()
          UpdateNavigationTree(new_focus)
          TreePanel.Create
          ret = true
        else
          Popup.Error(
            Builtins.sformat(_("Deleting volume group \"%1\" failed."), vgname)
          )
          #FIXME: some rollback?
          ret = false
        end

        Storage.SetRecursiveRemoval(recursive)
      end

      ret
    end


    def EpCreateLogicalVolume(device)
      if device == nil
        # error popup
        Popup.Error(_("No logical volume selected."))
        return
      end

      target_map = Storage.GetTargetMap

      data = { "new" => true, "type" => :lvm, "create" => true }

      vg_name = Builtins.substring(device, 5)
      pools = Builtins.filter(
        Ops.get_list(target_map, [device, "partitions"], [])
      ) { |p| Ops.get_boolean(p, "pool", false) }

      if Ops.get_integer(target_map, [device, "pe_free"], 0) == 0 &&
          Builtins.size(pools) == 0
        # error popup
        Popup.Error(
          Builtins.sformat(
            _("No free space left in the volume group \"%1\"."),
            vg_name
          )
        )
        return
      end

      Ops.set(data, "vg_name", vg_name)
      Ops.set(
        data,
        "pesize",
        Ops.get_integer(target_map, [device, "pesize"], 0)
      )
      maxs = Ops.divide(
        Ops.multiply(
          Ops.get_integer(target_map, [device, "pe_free"], 0),
          Ops.get_integer(target_map, [device, "pesize"], 0)
        ),
        1024
      )
      Builtins.foreach(Ops.get_list(target_map, [device, "partitions"], [])) do |p|
        if Ops.get_boolean(p, "create", false) &&
            Ops.get_boolean(p, "pool", false)
          maxs = Ops.subtract(
            maxs,
            ComputePoolMetadataSize(
              Ops.get_integer(p, "size_k", 0),
              Ops.get_integer(target_map, [device, "pesize"], 1024)
            )
          )
        end
      end
      Ops.set(data, "max_size_k", maxs)
      Ops.set(
        data,
        "max_stripes",
        Builtins.size(
          MergeDevices(
            Convert.convert(
              Ops.get(target_map, device, {}),
              :from => "map",
              :to   => "map <string, any>"
            )
          )
        )
      )

      Ops.set(data, "using_devices", [device])

      _Commit = lambda do |data|
        return addLogicalVolume(data, Builtins.substring(device, 5)) ? :finish : :back
      end

      if (
          data_ref = arg_ref(data);
          _DlgCreateLogicalVolume_result = DlgCreateLogicalVolume(
            data_ref,
            fun_ref(_Commit, "symbol (map)")
          );
          data = data_ref.value;
          _DlgCreateLogicalVolume_result
        )
        UpdateMainStatus()
        UpdateNavigationTree(nil)
        TreePanel.Create
        UpdateTableFocus(
          Ops.add(
            Ops.add(
              Ops.add("/dev/", Ops.get_string(data, "vg_name", "error")),
              "/"
            ),
            Ops.get_string(data, "name", "error")
          )
        )
      end

      nil
    end


    def EpEditLogicalVolume(device)
      if device == nil
        # error popup
        Popup.Error(_("No logical volume selected."))
        return
      end

      target_map = Storage.GetTargetMap
      data = Storage.GetPartition(target_map, device)

      if Ops.get_boolean(data, "pool", false)
        # error popup, %1 is replace by partition device name e.g. /dev/system/root
        Popup.Error(
          Builtins.sformat(
            _("The volume %1 is a thin pool.\nIt cannot be edited."),
            device
          )
        )
        return
      end

      if Storage.IsUsedBy(data)
        # error popup, %1 is replace by partition device name e.g. /dev/system/root
        Popup.Error(
          Builtins.sformat(
            _(
              "The volume %1 is in use. It cannot be\nedited. To edit %1, make sure it is not used."
            ),
            device
          )
        )
        return
      end

      if (
          data_ref = arg_ref(data);
          _DlgEditLogicalVolume_result = DlgEditLogicalVolume(data_ref);
          data = data_ref.value;
          _DlgEditLogicalVolume_result
        )
        Storage.ChangeVolumeProperties(data)

        UpdateMainStatus()
        UpdateNavigationTree(nil)
        TreePanel.Create
        UpdateTableFocus(device)
      end

      nil
    end


    def EpResizeLogicalVolume(device)
      if device == nil
        # error popup
        Popup.Error(_("No logical volume selected."))
        return
      end

      target_map = Storage.GetTargetMap
      lv_data = Storage.GetPartition(target_map, device)
      vg_data = Storage.GetDisk(target_map, device)

      if (
          lv_data_ref = arg_ref(lv_data);
          _DlgResizeLogicalVolumeNew_result = DlgResizeLogicalVolumeNew(
            lv_data_ref,
            vg_data
          );
          lv_data = lv_data_ref.value;
          _DlgResizeLogicalVolumeNew_result
        )
        Storage.ResizeVolume(
          device,
          Ops.get_string(vg_data, "device", "error"),
          Ops.get_integer(lv_data, "size_k", 0)
        )

        UpdateMainStatus()
        TreePanel.Create
        UpdateTableFocus(device)
      end

      nil
    end


    def EpDeleteLogicalVolume(device, context)
      if device == nil
        # error popup
        Popup.Error(_("No logical volume selected."))
        return
      end

      parent = ParentDevice(device)
      _next = NextDeviceAfterDelete(device)

      if EpDeleteDevice(device)
        UpdateMainStatus()

        case context
          when :table
            UpdateNavigationTree(nil)
            TreePanel.Create
            if !Builtins.isempty(_next)
              UI.ChangeWidget(Id(:table), :CurrentItem, _next)
            end
          when :overview
            UpdateNavigationTree(parent)
            TreePanel.Create
        end
      end

      nil
    end
  end
end
