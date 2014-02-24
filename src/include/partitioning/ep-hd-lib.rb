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

# File:        ep-main.ycp
# Package:     yast2-storage
# Summary:     Expert Partitioner
# Authors:     Arvin Schnell <aschnell@suse.de>

module Yast
  module PartitioningEpHdLibInclude


    include Yast::Logger


    def initialize_partitioning_ep_hd_lib(include_target)
      textdomain "storage"
    end


    def EpCreatePartitionTable(disk_device)
      if disk_device == nil
        # error popup
        Popup.Error(_("No hard disk selected."))
        return
      end

      target_map = Storage.GetTargetMap
      disk = Ops.get(target_map, disk_device, {})

      if Storage.IsUsedBy(disk)
        # error popup
        Popup.Error(_("The disk is in use and cannot be modified."))
        return
      end

      default_label = Storage.DefaultDiskLabel(disk_device)

      labels = [default_label]

      if default_label != "dasd"
        if !Builtins.contains(labels, "gpt")
          labels = Builtins.add(labels, "gpt")
        end
      end

      label = default_label
      if Ops.greater_than(Builtins.size(labels), 1)
        tmp = Builtins::List.reduce(VBox(), labels) do |t, l|
          Builtins.add(
            t,
            term(
              :LeftRadioButton,
              Id(l),
              Builtins.toupper(l),
              l == default_label
            )
          )
        end

        UI.OpenDialog(
          Opt(:decorated),
          Greasemonkey.Transform(
            VBox(
              # dialog heading
              Label(
                Builtins.sformat(
                  _("Select new partition table type for %1."),
                  disk_device
                )
              ),
              MarginBox(2, 0.4, RadioButtonGroup(Id(:labels), tmp)),
              ButtonBox(
                PushButton(Id(:ok), Opt(:default), Label.OKButton),
                PushButton(Id(:cancel), Label.CancelButton)
              )
            )
          )
        )

        widget = Convert.to_symbol(UI.UserInput)

        label = Convert.to_string(UI.QueryWidget(Id(:labels), :Value))

        UI.CloseDialog

        return if widget != :ok
      end

      # popup text, %1 is be replaced by disk name e.g. /dev/sda
      if Popup.YesNo(
          Builtins.sformat(
            _(
              "Really create new partition table on %1? This will delete all data\non %1 and all RAIDs and Volume Groups using partitions on %1."
            ),
            disk_device
          )
        )
        Storage.CreatePartitionTable(disk_device, label)

        UpdateMainStatus()
        UpdateNavigationTree(nil)
        TreePanel.Create
      end

      nil
    end


    def EpDeleteDisk(device)
      if device == nil
        # error popup
        Popup.Error(_("No disk selected."))
        return
      end

      target_map = Storage.GetTargetMap
      disk = Convert.convert(
        Ops.get(target_map, device, {}),
        :from => "map",
        :to   => "map <string, any>"
      )

      if Ops.get_symbol(disk, "type", :CT_UNKNOWN) == :CT_DMRAID
        # popup text
        if Popup.YesNo(
            Builtins.sformat(_("Really delete BIOS RAID %1?"), device)
          )
          if deleteAllDevPartitions(disk, Stage.initial)
            Storage.DeleteDmraid(device)
          end

          UpdateMainStatus()
          UpdateNavigationTree(:hd)
          TreePanel.Create
        end
      elsif Ops.get_symbol(disk, "type", :CT_UNKNOWN) == :CT_MDPART &&
          Ops.get_string(disk, "sb_ver", "") != "imsm"
        # popup text
        if Popup.YesNo(
            Builtins.sformat(_("Really delete Partitioned RAID %1?"), device)
          )
          if deleteAllDevPartitions(disk, Stage.initial)
            Storage.DeleteMdPartCo(device)
          end

          UpdateMainStatus()
          UpdateNavigationTree(:hd)
          TreePanel.Create
        end
      else
        #partition names
        pnames = Storage.GetAffectedDevices(device)
        count = Builtins.size(pnames)

        if count == 0
          # error ppup
          Popup.Error(_("There are no partitions to delete on this disk."))
          return
        else
          if ConfirmPartitionsDelete(device, pnames) &&
              deleteAllDevPartitions(disk, Stage.initial)
            UpdateMainStatus()
            UpdateNavigationTree(:hd)
            TreePanel.Create
          end
        end
      end

      nil
    end


    def GetPossibleSlots(disk, disk_device)
      disk = deep_copy(disk)
      slots = []
      slots_ref = arg_ref(slots)
      Storage.GetUnusedPartitionSlots(disk_device, slots_ref)
      slots = slots_ref.value

      log.info("slots:#{slots}")

      # individual sort primary, extended and logical slots

      ret = {}

      def helper(slots)
        slots = slots.sort { |a, b| b[:region][1] <=> a[:region][1] }
        return slots.map { |slot| slot.select { |k, v| [:region, :nr, :device].include?(k) } }
      end

      primary_slots = slots.select { |slot| slot.fetch(:primary_possible, false) }
      if !primary_slots.empty?
        ret[:primary] = helper(primary_slots)
      end

      extended_slots = slots.select { |slot| slot.fetch(:extended_possible, false) }
      if !extended_slots.empty?
        ret[:extended] = helper(extended_slots)
      end

      logical_slots = slots.select { |slot| slot.fetch(:logical_possible, false) }
      if !logical_slots.empty?
        ret[:logical] = helper(logical_slots)
      end

      if ret.empty?
        # error popup
        Popup.Error(
          Builtins.sformat(
            _("It is not possible to create a partition on %1."),
            disk_device
          )
        )
      end

      log.info("ret:#{ret}")

      deep_copy(ret)
    end


    # argument is device of hard disk
    def EpCreatePartition(disk_device)
      if disk_device == nil
        # error popup
        Popup.Error(_("No hard disk selected."))
        return
      end

      target_map = Storage.GetTargetMap
      disk = Convert.convert(
        Ops.get(target_map, disk_device, {}),
        :from => "map",
        :to   => "map <string, any>"
      )

      if Ops.get_boolean(disk, "readonly", false)
        Popup.Error(Partitions.RdonlyText(disk, true))
        return
      end

      if !Storage.CanCreate(disk, true)
        return
      end

      slots = GetPossibleSlots(disk, disk_device)

      if !Builtins.isempty(slots)
        data = {
          "new"         => true,
          "create"      => true,
          "disk_device" => disk_device,
          "cyl_size"    => Ops.get_integer(disk, "cyl_size", 0),
          "cyl_count"   => Ops.get_integer(disk, "cyl_count", 0),
          "slots"       => slots
        }

        if Builtins.haskey(disk, "udev_id")
          Ops.set(data, "disk_udev_id", Ops.get_list(disk, "udev_id", []))
        end

        if Builtins.haskey(disk, "udev_path")
          Ops.set(data, "disk_udev_path", Ops.get_string(disk, "udev_path", ""))
        end

        Ops.set(data, "using_devices", [disk_device])

        if (
            data_ref = arg_ref(data);
            _DlgCreatePartition_result = DlgCreatePartition(data_ref);
            data = data_ref.value;
            _DlgCreatePartition_result
          )
          device = Ops.get_string(data, "device", "error")

          mby = Ops.get_symbol(data, "mountby") { Storage.GetMountBy(device) }
          Storage.CreatePartition(
            Ops.get_string(data, "disk_device", ""),
            device,
            Ops.get_symbol(data, "type", :primary),
            Ops.get_integer(data, "fsid", Partitions.fsid_native),
            Ops.get_integer(data, ["region", 0], 0),
            Ops.get_integer(data, ["region", 1], 0),
            mby
          )
          Storage.ChangeVolumeProperties(data)

          UpdateMainStatus()
          UpdateNavigationTree(nil)
          TreePanel.Create
          UpdateTableFocus(device)
        end
      end

      nil
    end


    def EpEditPartition(device)
      if device == nil
        # error popup
        Popup.Error(_("No partition selected."))
        return
      end

      target_map = Storage.GetTargetMap
      part = Storage.GetPartition(target_map, device)

      return if !Storage.CanEdit(part, true)

      if Storage.IsUsedBy(part)
        # error popup, %1 is replace by partition device name e.g. /dev/sdb1
        Popup.Error(
          Builtins.sformat(
            _(
              "The partition %1 is in use. It cannot be\nedited. To edit %1, make sure it is not used."
            ),
            device
          )
        )
        return
      end

      if Ops.get_symbol(part, "type", :primary) == :extended
        # error popup text
        Popup.Error(_("An extended partition cannot be edited."))
        return
      end

      if (
          part_ref = arg_ref(part);
          _DlgEditPartition_result = DlgEditPartition(part_ref);
          part = part_ref.value;
          _DlgEditPartition_result
        )
        Storage.ChangeVolumeProperties(part)

        UpdateMainStatus()
        UpdateNavigationTree(nil)
        TreePanel.Create
        UpdateTableFocus(device)
      end

      nil
    end


    def EpMovePartition(device)
      if device == nil
        # error popup
        Popup.Error(_("No partition selected."))
        return
      end

      target_map = Storage.GetTargetMap
      disk = Storage.GetDisk(target_map, device)
      part = Storage.GetPartition(target_map, device)

      if Ops.get_boolean(disk, "readonly", false)
        Popup.Error(Partitions.RdonlyText(disk, true))
        return
      end

      if !Ops.get_boolean(part, "create", false)
        # error popup, %1 is replace by partition device name, e.g. /dev/sdb1
        Popup.Error(
          Builtins.sformat(
            _(
              "The partition %1 is already created on disk\nand cannot be moved."
            ),
            device
          )
        )
        return
      end

      if Ops.get_symbol(part, "type", :primary) == :extended
        # error popup text
        Popup.Error(_("An extended partition cannot be moved."))
        return
      end

      if (
          part_ref = arg_ref(part);
          _DlgMovePartition_result = DlgMovePartition(part_ref);
          part = part_ref.value;
          _DlgMovePartition_result
        )
        if Storage.UpdatePartition(
            device,
            Ops.get_integer(part, ["region", 0], 0),
            Ops.get_integer(part, ["region", 1], 0)
          )
          UpdateMainStatus()
          TreePanel.Create
          UpdateTableFocus(device)
        end
      end

      nil
    end


    def EpResizePartition(device)
      if device == nil
        # error popup
        Popup.Error(_("No partition selected."))
        return
      end

      target_map = Storage.GetTargetMap
      disk = Storage.GetDisk(target_map, device)
      part = Storage.GetPartition(target_map, device)

      if Ops.get_boolean(disk, "readonly", false)
        Popup.Error(Partitions.RdonlyText(disk, true))
        return
      end

      if Storage.IsUsedBy(part)
        # error popup, %1 is replace by partition device name, e.g. /dev/sdb1
        Popup.Error(
          Builtins.sformat(
            _(
              "The partition %1 is in use. It cannot be\nresized. To resize %1, make sure it is not used."
            ),
            device
          )
        )
        return
      end

      if Ops.get_symbol(part, "type", :primary) == :extended
        # error popup text
        Popup.Error(_("An extended partition cannot be resized."))
        return
      end

      # Need to pass data on the whole disk, to determine free/available space
      if (
          part_ref = arg_ref(part);
          _DlgResizePartition_result = DlgResizePartition(part_ref, disk);
          part = part_ref.value;
          _DlgResizePartition_result
        )
        Storage.ResizePartition(
          device,
          Ops.get_string(disk, "device", "error"),
          Ops.get_integer(part, ["region", 1], 0)
        )

        UpdateMainStatus()
        TreePanel.Create
        UpdateTableFocus(device)
      end

      nil
    end


    def EpDeletePartition(device, context)
      if device == nil
        # error popup
        Popup.Error(_("No partition selected."))
        return
      end

      target_map = Storage.GetTargetMap
      disk = Storage.GetDisk(target_map, device)
      part = Storage.GetPartition(target_map, device)

      return if !Storage.CanDelete(part, disk, true)

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


    def EpCloneDisk(device)
      target_map = Storage.GetTargetMap

      mysize = Ops.get_integer(target_map, [device, "size_k"], 0)
      mycyl_size = Ops.get_integer(target_map, [device, "cyl_size"], 0)
      myparts = Ops.get_list(target_map, [device, "partitions"], [])
      mypart_table_type = Ops.get_string(target_map, [device, "label"]) do
        Storage.DefaultDiskLabel(device)
      end

      # helptext
      helptext = _(
        "<p>Select one or more (if available) hard disks\n" +
          "that will have the same partition layout as\n" +
          "this disk.</p>\n" +
          "<p>Disks marked with the sign '*' contain one or\n" +
          "more partitions. After cloning, these\n" +
          "partitions will be deleted.</p>\n"
      )

      _AvailableTargetDisks = lambda do
        filtered_target_map = Builtins.filter(target_map) do |dev, props|
          dev != device &&
            Storage.IsDiskType(Ops.get_symbol(props, "type", :CT_UNKNOWN)) &&
            !Storage.IsUsedBy(props) &&
            Ops.get_integer(props, "cyl_size", 0) == mycyl_size
        end

        Builtins.y2milestone(
          "Available, suitable and unused disks (other than %1): %2",
          device,
          Map.Keys(filtered_target_map)
        )

        items = []

        Builtins.foreach(filtered_target_map) do |dev, props|
          if Ops.greater_or_equal(Ops.get_integer(props, "size_k", 0), mysize)
            items = Builtins.add(items, dev)
          else
            Builtins.y2milestone(
              "%1 is smaller than needed, skipping it",
              device
            )
          end
        end

        deep_copy(items)
      end

      _ConfirmDeletePartitions = lambda do |to_delete|
        to_delete = deep_copy(to_delete)
        UI.OpenDialog(
          Opt(:warncolor),
          VBox(
            Left(
              Label(
                _(
                  "The following partitions will be deleted\nand all data on them will be lost:"
                )
              )
            ),
            VSpacing(1),
            RichText(HTML.List(to_delete)),
            Left(Label(_("Really delete these partitions?"))),
            VSpacing(1),
            ButtonBox(
              PushButton(Id(:ok), Opt(:default), Label.DeleteButton),
              PushButton(Id(:cancel), Label.CancelButton)
            )
          )
        )
        ret2 = Convert.to_symbol(UI.UserInput)
        UI.CloseDialog

        ret2 == :ok
      end

      if Builtins.isempty(myparts)
        Popup.Error(
          _(
            "There are no partitions on this disk, but a clonable\n" +
              "disk must have at least one partition.\n" +
              "Create partitions before cloning the disk.\n"
          )
        )
        return
      end

      mydisks = _AvailableTargetDisks.call

      if Builtins.isempty(mydisks)
        Popup.Error(
          _(
            "This disk cannot be cloned. There are no suitable\ndisks that could have the same partitioning layout."
          )
        )
        return
      end

      ui_items = Builtins.maplist(mydisks) do |one_disk|
        any_partitions = !Builtins.isempty(
          Ops.get_list(target_map, [one_disk, "partitions"], [])
        )
        Item(
          Id(one_disk),
          Builtins.sformat(
            "%1%2 (%3)",
            one_disk,
            any_partitions ? "*" : "",
            Storage.KByteToHumanString(
              Ops.get_integer(target_map, [one_disk, "size_k"], 42)
            )
          )
        )
      end

      UI.OpenDialog(
        MinSize(
          60,
          20,
          VBox(
            Heading(Builtins.sformat(_("Clone partition layout of %1"), device)),
            VSpacing(1),
            MultiSelectionBox(
              Id(:tdisk),
              _("Available target disks:"),
              ui_items
            ),
            VSpacing(1),
            ButtonBox(
              PushButton(Id(:help), Opt(:helpButton), Label.HelpButton),
              PushButton(Id(:ok), Opt(:default), Label.OKButton),
              PushButton(Id(:cancel), Label.CancelButton)
            )
          )
        )
      )

      UI.ChangeWidget(:help, :HelpText, helptext)

      ret = nil

      while ret != :ok && ret != :cancel
        ret = UI.UserInput

        if ret == :ok
          selected_disks = Convert.convert(
            UI.QueryWidget(Id(:tdisk), :SelectedItems),
            :from => "any",
            :to   => "list <string>"
          )

          if Builtins.isempty(selected_disks)
            Popup.Error(_("Select a target disk for creating a clone"))
            UI.SetFocus(Id(:tdisk))
            ret = nil
            next
          end

          # collect partitions to delete
          partitions_to_delete = []
          Builtins.foreach(selected_disks) do |this_disk|
            partitions_to_delete = Convert.convert(
              Builtins.union(
                partitions_to_delete,
                Storage.GetAffectedDevices(this_disk)
              ),
              :from => "list",
              :to   => "list <string>"
            )
          end

          #if there is anything to delete, ask user if s/he really wants to delete
          if !Builtins.isempty(partitions_to_delete) &&
              !_ConfirmDeletePartitions.call(partitions_to_delete)
            ret = nil
            next
          end

          #We'll be deleting recursively, so that no longer valid
          #LVMs and RAIDs are not left behind
          recursive = Storage.GetRecursiveRemoval
          Storage.SetRecursiveRemoval(true)

          Builtins.foreach(selected_disks) do |this_disk|
            disk_info = Storage.GetDisk(target_map, this_disk)
            Storage.CreatePartitionTable(
              Ops.get_string(disk_info, "device", ""),
              mypart_table_type
            )
            Builtins.foreach(myparts) do |one_partition|
              _next = Storage.NextPartition(
                this_disk,
                Ops.get_symbol(one_partition, "type", :none)
              )
              Storage.CreatePartition(
                this_disk,
                Ops.get_string(_next, "device", "error"),
                Ops.get_symbol(one_partition, "type", :primary),
                Ops.get_integer(one_partition, "fsid", Partitions.fsid_native),
                Ops.get_integer(one_partition, ["region", 0], 0),
                Ops.get_integer(one_partition, ["region", 1], 0),
                Ops.get_symbol(one_partition, "mountby") do
                  Storage.GetMountBy(device)
                end
              ) #FIXME: ChangeVolumeProperties too?
            end
          end

          Storage.SetRecursiveRemoval(recursive)
        end
      end

      UI.CloseDialog

      if ret == :ok
        UpdateMainStatus()
        UpdateNavigationTree(nil)
        TreePanel.Create
      end

      nil
    end


    def EpDasdfmtDisk(device)
      target_map = Storage.GetTargetMap

      disk = Ops.get(target_map, device, {})

      if !Ops.get_boolean(disk, "dasdfmt", false)
        # popup text, %1 is replaced by a dasd name e.g. /dev/dasda
        doit = Popup.YesNo(
          Builtins.sformat(
            _(
              "Running dasdfmt deletes all data on the disk.\nReally execute dasdfmt on disk %1?\n"
            ),
            device
          )
        )

        Storage.InitializeDisk(device, true) if doit
      else
        # popup text
        Popup.Message(
          _(
            "The disk is no longer marked for dasdfmt.\n" +
              "\n" +
              "Partitions currently present on this disk are again\n" +
              "displayed.\n"
          )
        )
        Storage.InitializeDisk(device, false)
      end

      UpdateMainStatus()
      UpdateNavigationTree(nil)
      TreePanel.Create

      nil
    end


  end
end
