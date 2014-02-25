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
  module PartitioningEpBtrfsDialogsInclude
    def initialize_partitioning_ep_btrfs_dialogs(include_target)
      textdomain "storage"
    end

    def DlgEditBtrfsVolume(data)
      Builtins.y2milestone("DlgEditBtrfsVolume %1", data.value)
      device = Ops.get_string(data.value, "device", "error")

      aliases = {
        "FormatMount" => lambda do
        (
          data_ref = arg_ref(data.value);
          _MiniWorkflowStepFormatMount_result = MiniWorkflowStepFormatMount(
            data_ref
          );
          data.value = data_ref.value;
          _MiniWorkflowStepFormatMount_result
        )
        end,
        "Password" => lambda do
        (
          data_ref = arg_ref(data.value);
          _MiniWorkflowStepPassword_result = MiniWorkflowStepPassword(data_ref);
          data.value = data_ref.value;
          _MiniWorkflowStepPassword_result
        )
        end
      }

      sequence = {
        "FormatMount" => { :next => "Password", :finish => :finish },
        "Password"    => { :finish => :finish }
      }

      # dialog title
      title = Builtins.sformat(
        _("Edit Btrfs %1"),
        Ops.get_string(data.value, "uuid", "")
      )

      widget = MiniWorkflow.Run(
        title,
        StorageIcons.lvm_lv_icon,
        aliases,
        sequence,
        "FormatMount"
      )

      widget == :finish
    end

    #///////////////////////////////////////////////////////////////
    # Get all volumes, we can probably use as volumes in an BTRFS
    # Add needed information: disksize
    def GetPossibleVols(targetMap)
      targetMap = deep_copy(targetMap)
      ret = []

      #////////////////////////////////////////////////////////////////////
      # add the devicename i.e /dev/hda1 or /dev/system/usr to partition list

      targetMap = Builtins.mapmap(targetMap) do |dev, devmap|
        partitions = Builtins.maplist(Ops.get_list(devmap, "partitions", [])) do |part|
          Ops.set(part, "maindev", dev)
          deep_copy(part)
        end
        { dev => Builtins.add(devmap, "partitions", partitions) }
      end

      #//////////////////////////////////////////////////////////
      # Look for all partitions:
      # no mountpoint
      # id 0x83

      types_no = [:btrfs, :extended]
      types_ok = [:sw_raid, :dm, :lvm]
      fsids = [
        Partitions.fsid_native,
        Partitions.fsid_lvm,
        Partitions.fsid_raid
      ]
      allowed_enc_types = [:none]

      Builtins.foreach(targetMap) do |dev, devmap|
        Builtins.y2milestone(
          "GetPossibleVols parts:%1",
          Ops.get_list(devmap, "partitions", [])
        )
        parts = Builtins.filter(Ops.get_list(devmap, "partitions", [])) do |part|
          (Builtins.size(Ops.get_string(part, "mount", "")) == 0 ||
            Ops.get_symbol(part, "used_by_type", :UB_NONE) == :UB_BTRFS) &&
            !Builtins.contains(types_no, Ops.get_symbol(part, "type", :primary)) &&
            Builtins.contains(
              allowed_enc_types,
              Ops.get_symbol(part, "enc_type", :none)
            ) &&
            (!Storage.IsUsedBy(part) ||
              Ops.get_symbol(part, "used_by_type", :UB_NONE) == :UB_BTRFS) &&
            (Builtins.contains(types_ok, Ops.get_symbol(part, "type", :primary)) ||
              Builtins.contains(fsids, Ops.get_integer(part, "fsid", 0)))
        end
        Builtins.y2milestone("GetPossibleVols filter:%1", parts)
        if Ops.get_symbol(devmap, "used_by_type", :UB_NONE) != :UB_NONE
          parts = []
          Builtins.y2milestone(
            "GetPossibleVols no parts, disk used by %1 %2",
            Ops.get_symbol(devmap, "used_by_type", :UB_NONE),
            Ops.get_string(devmap, "used_by_device", "")
          )
        end
        # currently disallow usage of whole disk devices as parts of BTRFS volumes
        # if( size(devmap["partitions"]:[])==0 &&
        # 		Storage::IsPartType(devmap["type"]:`CT_UNKNOWN) &&
        # 		(!Storage::IsUsedBy(devmap) || devmap["used_by_type"]:`UB_NONE==`UB_LVM))
        # 		{
        # 		map p = $[ "device":dev, "maindev":dev,
        # 			   "size_k":devmap["size_k"]:0 ];
        # 		if( devmap["used_by_type"]:`UB_NONE != `UB_NONE )
        # 		    {
        # 		    p["used_by_type"] = devmap["used_by_type"]:`UB_NONE;
        # 		    p["used_by_device"] = devmap["used_by_device"]:"";
        # 		    }
        # 		parts = [ p ];
        # 		}
        ret = Convert.convert(
          Builtins.merge(ret, parts),
          :from => "list",
          :to   => "list <map>"
        )
      end
      Builtins.y2milestone("GetPossibleVols ret %1", ret)
      deep_copy(ret)
    end

    def CheckNumberOfDevicesForVolume(num)
      if Ops.less_than(num, 1)
        # error popup
        Popup.Error(Builtins.sformat(_("Select at least one device.")))
        UI.SetFocus(Id(:unselected))
        return false
      else
        return true
      end
    end

    def MiniWorkflowStepResizeVolumeHelptext
      # helptext
      helptext = _(
        "<p>Change the devices that are used by the Btrfs volume.</p>"
      )

      helptext
    end


    def MiniWorkflowStepResizeVolume(data)
      Builtins.y2milestone("MiniWorkflowStepResizeVolume data:%1", data.value)

      pvs_new = []

      fields = StorageSettings.FilterTable(
        [:device, :udev_path, :udev_id, :size, :encrypted, :type]
      )

      poss_pvs = GetPossibleVols(Storage.GetTargetMap)
      Builtins.y2milestone(
        "MiniWorkflowStepResizeVolume poss:%1",
        Builtins.maplist(poss_pvs) do |pv|
          [
            Ops.get_string(pv, "device", ""),
            Ops.get_string(pv, "used_by_device", "")
          ]
        end
      )
      unused_pvs = Builtins.filter(poss_pvs) do |pv|
        Ops.get_symbol(pv, "used_by_type", :UB_NONE) == :UB_NONE
      end
      used_pvs = Builtins.filter(poss_pvs) do |pv|
        Ops.get_string(pv, "used_by_device", "") ==
          Ops.get_string(data.value, "uuid", "")
      end

      contents = VBox()

      contents = Builtins.add(
        contents,
        DevicesSelectionBox.Create(
          unused_pvs,
          used_pvs,
          fields,
          nil,
          _("Unused Devices:"),
          _("Selected Devices:"),
          false
        )
      )

      MiniWorkflow.SetContents(
        Greasemonkey.Transform(contents),
        MiniWorkflowStepResizeVolumeHelptext()
      )
      MiniWorkflow.SetLastStep(true)

      widget = nil
      begin
        widget = MiniWorkflow.UserInput
        DevicesSelectionBox.Handle(widget)

        case widget
          when :next
            pvs_new = Builtins.maplist(DevicesSelectionBox.GetSelectedDevices) do |pv|
              Ops.get_string(pv, "device", "")
            end

            if !CheckNumberOfDevicesForVolume(Builtins.size(pvs_new))
              widget = :again
            end 

            # TODO: overall size check
        end
      end until widget == :abort || widget == :back || widget == :next

      if widget == :next
        Ops.set(data.value, "devices_new", pvs_new)

        widget = :finish
      end

      Builtins.y2milestone(
        "MiniWorkflowStepResizeVg data:%1 ret:%2",
        data.value,
        widget
      )

      widget
    end


    def DlgResizeBtrfsVolume(data, _Commit)
      _Commit = deep_copy(_Commit)
      aliases = {
        "TheOne" => lambda do
        (
          data_ref = arg_ref(data.value);
          _MiniWorkflowStepResizeVolume_result = MiniWorkflowStepResizeVolume(
            data_ref
          );
          data.value = data_ref.value;
          _MiniWorkflowStepResizeVolume_result
        )
      end,
        "Commit" => lambda { _Commit.call(data.value) }
      }

      sequence = {
        "TheOne" => { :finish => "Commit" },
        "Commit" => { :finish => :finish }
      }

      Builtins.y2milestone("data:%1", data.value)

      # dialog title
      title = Builtins.sformat(
        _("Resize Btrfs Volume %1"),
        Ops.get_string(data.value, "uuid", "error")
      )

      widget = MiniWorkflow.Run(
        title,
        StorageIcons.lvm_icon,
        aliases,
        sequence,
        "TheOne"
      )

      widget == :finish
    end
  end
end
