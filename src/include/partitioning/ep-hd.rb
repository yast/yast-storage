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
  module PartitioningEpHdInclude
    def initialize_partitioning_ep_hd(include_target)
      textdomain "storage"

      Yast.include include_target, "partitioning/ep-hd-dialogs.rb"
      Yast.include include_target, "partitioning/ep-hd-lib.rb"
    end

    def EpContextMenuHdDisk(device)
      widget = ContextMenu.Simple(
        [
          Item(
            Id(:add),
            term(:icon, StorageIcons.hd_part_icon),
            _("Add Partition")
          ),
          Item(Id(:delete), _("Delete"))
        ]
      )

      case widget
        when :add
          EpCreatePartition(device)
        when :delete
          EpDeleteDisk(device)
      end

      nil
    end


    def EpContextMenuHdPartition(device)
      widget = ContextMenu.Simple(
        [
          Item(Id(:edit), _("Edit")),
          Item(Id(:move), _("Move")),
          Item(Id(:resize), _("Resize")),
          Item(Id(:delete), _("Delete"))
        ]
      )

      case widget
        when :edit
          EpEditPartition(device)
        when :move
          EpMovePartition(device)
        when :resize
          EpResizePartition(device)
        when :delete
          EpDeletePartition(device, :table)
      end

      nil
    end


    def HdButtons
      [
        # push button text
        PushButton(Id(:edit), Opt(:key_F4), _("Edit...")),
        # push button text
        PushButton(Id(:move), Opt(:key_F7), _("Move...")),
        # push button text
        PushButton(Id(:resize), Opt(:key_F6), _("Resize...")),
        # push button text
        PushButton(Id(:delete), Opt(:key_F5), _("Delete..."))
      ]
    end


    def HandleHdButtons(user_data, device, event)
      user_data = deep_copy(user_data)
      event = deep_copy(event)
      disk_device = ""
      is_disk = false

      if user_data == nil
        disk = nil
        part = nil

        target_map = Storage.GetTargetMap
        disk_ref = arg_ref(disk)
        part_ref = arg_ref(part)
        SplitDevice(target_map, device, disk_ref, part_ref)
        disk = disk_ref.value
        part = part_ref.value
        disk_device = Ops.get_string(disk, "device", "")
        is_disk = part == nil
      else
        disk_device = Convert.to_string(user_data)
      end

      case Event.IsWidgetActivated(event)
        when :add
          EpCreatePartition(disk_device)
        when :edit
          if is_disk
            TreePanel.SwitchToNew(disk_device)
          else
            EpEditPartition(device)
          end
        when :move
          if is_disk
            # error popup
            Popup.Error(
              _(
                "Hard disks, BIOS RAIDs and multipath\ndevices cannot be moved."
              )
            )
          else
            EpMovePartition(device)
          end
        when :resize
          if is_disk
            # error popup
            Popup.Error(
              _(
                "Hard disks, BIOS RAIDs and multipath\ndevices cannot be resized."
              )
            )
          else
            EpResizePartition(device)
          end
        when :delete
          if is_disk
            EpDeleteDisk(disk_device)
          else
            EpDeletePartition(
              device,
              UI.WidgetExists(Id(:table)) ? :table : :overview
            )
          end
      end

      nil
    end


    def CreateHdMainPanel(user_data)
      user_data = deep_copy(user_data)
      _Predicate = lambda do |disk, partition|
        disk = deep_copy(disk)
        partition = deep_copy(partition)
        StorageFields.PredicateDiskType(
          disk,
          partition,
          [:CT_DMRAID, :CT_DMMULTIPATH, :CT_MDPART, :CT_DISK]
        )
      end

      fields = StorageSettings.FilterTable(
        [
          :device,
          :udev_path,
          :udev_id,
          :size,
          :format,
          :encrypted,
          :type,
          :fs_type,
          :label,
          :mount_point,
          :mount_by,
          :start_cyl,
          :end_cyl,
          :used_by
        ]
      )

      target_map = Storage.GetTargetMap

      table_header = StorageFields.TableHeader(fields)
      table_contents = StorageFields.TableContents(
        fields,
        target_map,
        fun_ref(_Predicate, "symbol (map, map)")
      )

      UI.ReplaceWidget(
        :tree_panel,
        Greasemonkey.Transform(
          VBox(
            # heading
            term(:IconAndHeading, _("Hard Disks"), StorageIcons.hd_icon),
            Table(
              Id(:table),
              Opt(:keepSorting, :notify, :notifyContextMenu),
              table_header,
              table_contents
            ),
            ArrangeButtons(
              Builtins.flatten(
                [
                  [PushButton(Id(:add), Opt(:key_F3), _("Add Partition..."))], # push button text
                  HdButtons(),
                  [HStretch()]
                ]
              )
            )
          )
        )
      )

      # helptext
      helptext = _(
        "<p>This view shows all hard disks including\niSCSI disks, BIOS RAIDs and multipath disks and their partitions.</p>\n"
      )

      Wizard.RestoreHelp(Ops.add(helptext, StorageFields.TableHelptext(fields)))

      nil
    end


    def HandleHdMainPanel(user_data, event)
      user_data = deep_copy(user_data)
      event = deep_copy(event)
      device = Convert.to_string(UI.QueryWidget(Id(:table), :CurrentItem))

      HandleHdButtons(user_data, device, event)

      case Event.IsWidgetContextMenuActivated(event)
        when :table
          EpContextMenuDevice(device)
      end

      nil
    end


    def CreateHdDiskOverviewTab(user_data)
      user_data = deep_copy(user_data)
      device = Convert.to_string(user_data)

      target_map = Storage.GetTargetMap

      ctype = Ops.get_symbol(target_map, [device, "type"], :CT_DISK)

      fields = [
        :heading_device,
        :device,
        :size,
        :udev_path,
        :udev_id,
        :used_by,
        :heading_hd,
        :vendor,
        :model,
        :num_cyl,
        :cyl_size,
        :bus,
        :bios_id,
        :sector_size,
        :disk_label
      ]

      if Builtins.contains([:CT_MDPART], ctype)
        fields = Convert.convert(
          Builtins.merge(
            fields,
            [:heading_md, :raid_type, :chunk_size, :parity_algorithm]
          ),
          :from => "list",
          :to   => "list <symbol>"
        )
      end

      if Builtins.contains([:CT_DISK], ctype) &&
          (Ops.get_symbol(target_map, [device, "transport"], :unknown) == :fc ||
            Ops.get_symbol(target_map, [device, "transport"], :unknown) == :fcoe)
        fields = Convert.convert(
          Builtins.merge(
            fields,
            [:heading_fc, :fc_wwpn, :fc_port_id, :fc_fcp_lun]
          ),
          :from => "list",
          :to   => "list <symbol>"
        )
      end

      fields = StorageSettings.FilterOverview(fields)

      buttons = HBox()

      if Ops.greater_than(
          Convert.to_integer(
            SCR.Read(path(".target.size"), "/usr/sbin/smartctl")
          ),
          0
        )
        # push button text (do not translate 'SMART', it is the name of the tool)
        buttons = Builtins.add(
          buttons,
          PushButton(Id(:smart), _("Health Test (SMART)..."))
        )
      end

      if Ops.greater_than(
          Convert.to_integer(SCR.Read(path(".target.size"), "/sbin/hdparm")),
          0
        )
        # push button text (do not translate 'hdparm', it is the name of the tool)
        buttons = Builtins.add(
          buttons,
          PushButton(Id(:hdparm), _("Properties (hdparm)..."))
        )
      end

      UI.ReplaceWidget(
        :tab_panel,
        VBox(
          HStretch(),
          StorageFields.Overview(fields, target_map, device),
          Builtins.add(buttons, HStretch())
        )
      )

      # helptext
      helptext = _(
        "<p>This view shows detailed information about the\nselected hard disk.</p>"
      )

      Wizard.RestoreHelp(
        Ops.add(helptext, StorageFields.OverviewHelptext(fields))
      )

      nil
    end


    def DiskMaySupportSmart(disk_device)
      return false if String.StartsWith(disk_device, "/dev/dasd")

      target_map = Storage.GetTargetMap
      disk = Ops.get(target_map, disk_device, {})

      return false if Ops.get_symbol(disk, "type", :CT_UNKNOWN) != :CT_DISK

      if Builtins.contains(["3w-9xxx"], Ops.get_string(disk, "driver", ""))
        return false
      end

      true
    end


    def DiskMaySupportHdparm(disk_device)
      return false if String.StartsWith(disk_device, "/dev/dasd")

      target_map = Storage.GetTargetMap
      disk = Ops.get(target_map, disk_device, {})

      return false if Ops.get_symbol(disk, "type", :CT_UNKNOWN) != :CT_DISK

      true
    end


    def HandleHdDiskOverviewTab(user_data, event)
      user_data = deep_copy(user_data)
      event = deep_copy(event)
      disk_device = Convert.to_string(user_data)

      case Event.IsWidgetActivated(event)
        when :smart
          if !DiskMaySupportSmart(disk_device)
            Popup.Error(_("SMART is not available for this disk."))
          else
            DisplayCommandOutput(
              Builtins.sformat("/usr/sbin/smartctl --health '%1'", disk_device)
            )
          end
        when :hdparm
          if !DiskMaySupportHdparm(disk_device)
            Popup.Error(_("hdparm is not available for this disk."))
          else
            DisplayCommandOutput(
              Builtins.sformat("/sbin/hdparm -aAgr '%1'", disk_device)
            )
          end
      end

      nil
    end


    def CreateHdDiskPartitionsTab(user_data)
      user_data = deep_copy(user_data)
      device = Convert.to_string(user_data)

      _Predicate = lambda do |disk, partition|
        disk = deep_copy(disk)
        partition = deep_copy(partition)
        StorageFields.PredicateDiskDevice(disk, partition, [device])
      end

      fields = StorageSettings.FilterTable(
        [
          :device,
          :udev_path,
          :udev_id,
          :size,
          :format,
          :encrypted,
          :type,
          :fs_type,
          :label,
          :mount_point,
          :mount_by,
          :start_cyl,
          :end_cyl,
          :used_by
        ]
      )

      target_map = Storage.GetTargetMap

      table_header = StorageFields.TableHeader(fields)
      table_contents = StorageFields.TableContents(
        fields,
        target_map,
        fun_ref(_Predicate, "symbol (map, map)")
      )

      expert_cmds = []

      expert_cmds = Builtins.add(
        expert_cmds,
        Item(
          Id(:create_partition_table),
          # menu entry text
          _("Create New Partition Table")
        )
      )

      expert_cmds = Builtins.add(
        expert_cmds,
        Item(
          Id(:clone_disk),
          # menu entry text
          _("Clone this Disk")
        )
      )

      if String.StartsWith(device, "/dev/dasd")
        expert_cmds = Builtins.add(
          expert_cmds,
          Item(
            Id(:dasdfmt),
            # menu entry text
            _("Execute dasd&fmt on the DASD Device")
          )
        )
      end

      UI.ReplaceWidget(
        :tab_panel,
        VBox(
          DiskBarGraph(device),
          Table(
            Id(:table),
            Opt(:keepSorting, :notify, :notifyContextMenu),
            table_header,
            table_contents
          ),
          HBox(
            ArrangeButtons(
              Builtins.flatten(
                [
                  [PushButton(Id(:add), Opt(:key_F3), _("Add..."))], # push button text
                  HdButtons(),
                  [
                    HStretch(),
                    # menu button text
                    MenuButton(Opt(:key_F7), _("Expert..."), expert_cmds)
                  ]
                ]
              )
            )
          )
        )
      )

      # helptext
      helptext = _(
        "<p>This view shows all partitions of the selected\n" +
          "hard disk. If the hard disk is used by e.g. BIOS RAID or multipath, no\n" +
          "partitions are shown here.</p>\n"
      )

      Wizard.RestoreHelp(Ops.add(helptext, StorageFields.TableHelptext(fields)))

      nil
    end


    def HandleHdDiskPartitionsTab(user_data, event)
      user_data = deep_copy(user_data)
      event = deep_copy(event)
      disk_device = Convert.to_string(user_data)
      part_device = Convert.to_string(UI.QueryWidget(Id(:table), :CurrentItem))

      HandleHdButtons(disk_device, part_device, event)

      case Event.IsMenu(event)
        when :create_partition_table
          EpCreatePartitionTable(disk_device)
        when :clone_disk
          EpCloneDisk(disk_device)
        when :dasdfmt
          EpDasdfmtDisk(disk_device)
      end

      case Event.IsWidgetContextMenuActivated(event)
        when :table
          EpContextMenuDevice(part_device)
      end

      UI.SetFocus(Id(:table))

      nil
    end


    def CreateHdDiskDevicesTab(user_data)
      user_data = deep_copy(user_data)
      part_device = Convert.to_string(user_data)

      _Predicate = lambda do |disk, partition|
        disk = deep_copy(disk)
        partition = deep_copy(partition)
        StorageFields.PredicateUsedByDevice(disk, partition, [part_device])
      end

      fields = StorageSettings.FilterTable(
        [
          :device,
          :udev_path,
          :udev_id,
          :size,
          :format,
          :encrypted,
          :type,
          :used_by
        ]
      )

      target_map = Storage.GetTargetMap

      table_header = StorageFields.TableHeader(fields)
      table_contents = StorageFields.TableContents(
        fields,
        target_map,
        fun_ref(_Predicate, "symbol (map, map)")
      )

      UI.ReplaceWidget(
        :tab_panel,
        VBox(
          Table(
            Id(:table),
            Opt(:keepSorting, :notify),
            table_header,
            table_contents
          )
        )
      )

      # helptext
      helptext = _(
        "<p>This view shows all devices used by the\n" +
          "selected hard disk. The view is only available for BIOS RAIDs, partitioned\n" +
          "software RAIDs and multipath disks.</p>\n"
      )

      Wizard.RestoreHelp(Ops.add(helptext, StorageFields.TableHelptext(fields)))

      nil
    end


    def CreateHdDiskPanel(user_data)
      user_data = deep_copy(user_data)
      device = Convert.to_string(user_data)

      target_map = Storage.GetTargetMap

      data = {
        :overview   => {
          :create    => fun_ref(method(:CreateHdDiskOverviewTab), "void (any)"),
          :handle    => fun_ref(
            method(:HandleHdDiskOverviewTab),
            "void (any, map)"
          ),
          :user_data => user_data
        },
        :partitions => {
          :create    => fun_ref(
            method(:CreateHdDiskPartitionsTab),
            "void (any)"
          ),
          :handle    => fun_ref(
            method(:HandleHdDiskPartitionsTab),
            "void (any, map)"
          ),
          :user_data => user_data
        },
        :devices    => {
          :create    => fun_ref(method(:CreateHdDiskDevicesTab), "void (any)"),
          :user_data => user_data
        }
      }

      ctype = Ops.get_symbol(target_map, [device, "type"], :CT_DISK)

      tabs = [
        # tab heading
        Item(Id(:overview), _("&Overview")),
        # tab heading
        Item(Id(:partitions), _("&Partitions"))
      ]

      if Builtins.contains([:CT_DMRAID, :CT_DMMULTIPATH, :CT_MDPART], ctype)
        # tab heading
        tabs = Builtins.add(tabs, Item(Id(:devices), _("&Used Devices")))
      end

      UI.ReplaceWidget(
        :tree_panel,
        Greasemonkey.Transform(
          VBox(
            # heading
            term(
              :IconAndHeading,
              Builtins.sformat(_("Hard Disk: %1"), device),
              StorageIcons.hd_icon
            ),
            DumbTab(
              Id(:tab),
              tabs,
              ReplacePoint(Id(:tab_panel), TabPanel.empty_panel)
            )
          )
        )
      )

      TabPanel.Init(data, :partitions)

      nil
    end


    def HandleHdDiskPanel(user_data, event)
      user_data = deep_copy(user_data)
      event = deep_copy(event)
      TabPanel.Handle(event)

      nil
    end


    def CreateHdPartitionPanel(user_data)
      user_data = deep_copy(user_data)
      device = Convert.to_string(user_data)

      target_map = Storage.GetTargetMap

      fields = StorageSettings.FilterOverview(
        [
          :heading_device,
          :device,
          :size,
          :encrypted,
          :udev_path,
          :udev_id,
          :used_by,
          :fs_id,
          :heading_filesystem,
          :fs_type,
          :mount_point,
          :mount_by,
          :uuid,
          :label
        ]
      )

      UI.ReplaceWidget(
        :tree_panel,
        Greasemonkey.Transform(
          VBox(
            HStretch(),
            # heading
            term(
              :IconAndHeading,
              Builtins.sformat(_("Partition: %1"), device),
              StorageIcons.hd_part_icon
            ),
            StorageFields.Overview(fields, target_map, device),
            ArrangeButtons(Builtins.flatten([HdButtons(), [HStretch()]]))
          )
        )
      )

      # helptext
      helptext = _(
        "<p>This view shows detailed information about the\nselected partition.</p>"
      )

      Wizard.RestoreHelp(
        Ops.add(helptext, StorageFields.OverviewHelptext(fields))
      )

      nil
    end


    def HandleHdPartitionPanel(user_data, event)
      user_data = deep_copy(user_data)
      event = deep_copy(event)
      part_device = Convert.to_string(user_data)

      HandleHdButtons(nil, part_device, event)
      UI.SetFocus(Id(:text))

      nil
    end
  end
end
