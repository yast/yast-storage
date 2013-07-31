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
  module PartitioningEpLvmInclude
    def initialize_partitioning_ep_lvm(include_target)
      textdomain "storage"

      Yast.include include_target, "partitioning/ep-lvm-dialogs.rb"
      Yast.include include_target, "partitioning/ep-lvm-lib.rb"
    end

    def EpContextMenuLvmVg(device)
      widget = ContextMenu.Simple(
        [
          Item(
            Id(:add),
            term(:icon, StorageIcons.lvm_lv_icon),
            _("Add Logical Volume")
          ),
          Item(Id(:resize), _("Resize")),
          Item(Id(:delete), _("Delete"))
        ]
      )

      case widget
        when :add
          EpCreateLogicalVolume(device)
        when :resize
          EpResizeVolumeGroup(device)
        when :delete
          EpDeleteVolumeGroup(device)
      end

      nil
    end


    def EpContextMenuLvmLv(device)
      widget = ContextMenu.Simple(
        [
          Item(Id(:edit), _("Edit")),
          Item(Id(:resize), _("Resize")),
          Item(Id(:delete), _("Delete"))
        ]
      )

      case widget
        when :edit
          EpEditLogicalVolume(device)
        when :resize
          EpResizeLogicalVolume(device)
        when :delete
          EpDeleteLogicalVolume(device, :table)
      end

      nil
    end


    def LvmButtonBox
      HBox(
        # push button text
        PushButton(Id(:edit), Opt(:key_F4), _("Edit...")),
        # push button text
        PushButton(Id(:resize), Opt(:key_F6), _("Resize...")),
        # push button text
        PushButton(Id(:delete), Opt(:key_F5), _("Delete..."))
      )
    end


    def HandleLvmButtons(user_data, device, event)
      user_data = deep_copy(user_data)
      event = deep_copy(event)
      vg = ""
      is_vg = false

      if user_data == nil
        target_map = Storage.GetTargetMap

        disk = nil
        part = nil

        disk_ref = arg_ref(disk)
        part_ref = arg_ref(part)
        SplitDevice(target_map, device, disk_ref, part_ref)
        disk = disk_ref.value
        part = part_ref.value

        vg = Ops.get_string(disk, "device", "")
        is_vg = part == nil
      else
        vg = Convert.to_string(user_data)
      end

      case Event.IsWidgetActivated(event)
        when :add
          EpCreateLogicalVolume(vg)
        when :edit
          if is_vg
            TreePanel.SwitchToNew(vg)
          else
            EpEditLogicalVolume(device)
          end
        when :resize
          if is_vg
            EpResizeVolumeGroup(device)
          else
            EpResizeLogicalVolume(device)
          end
        when :delete
          if is_vg
            EpDeleteVolumeGroup(device)
          else
            EpDeleteLogicalVolume(
              device,
              UI.WidgetExists(Id(:table)) ? :table : :overview
            )
          end
      end

      case Event.IsMenu(event)
        when :group
          EpCreateVolumeGroup()
        when :volume
          EpCreateLogicalVolume(vg)
      end

      nil
    end


    def CreateLvmMainPanel(user_data)
      user_data = deep_copy(user_data)
      _Predicate = lambda do |disk, partition|
        disk = deep_copy(disk)
        partition = deep_copy(partition)
        StorageFields.PredicateDiskType(disk, partition, [:CT_LVM])
      end

      fields = StorageSettings.FilterTable(
        [
          :device,
          :size,
          :format,
          :encrypted,
          :type,
          :fs_type,
          :label,
          :mount_point,
          :mount_by,
          :used_by,
          :lvm_metadata,
          :pe_size,
          :stripes
        ]
      )

      target_map = Storage.GetTargetMap

      table_header = StorageFields.TableHeader(fields)
      table_contents = StorageFields.TableContents(
        fields,
        target_map,
        fun_ref(_Predicate, "symbol (map, map)")
      )
      mb_items = [Item(Id(:group), _("Volume Group"))]

      if !Builtins.isempty(table_contents)
        mb_items = Builtins.add(
          mb_items,
          Item(Id(:volume), _("Logical Volume"))
        )
      end

      UI.ReplaceWidget(
        :tree_panel,
        Greasemonkey.Transform(
          VBox(
            # heading
            term(:IconAndHeading, _("Volume Management"), StorageIcons.lvm_icon),
            Table(
              Id(:table),
              Opt(:keepSorting, :notify, :notifyContextMenu),
              table_header,
              table_contents
            ),
            HBox(
              # push button text
              MenuButton(Id(:add), Opt(:key_F3), _("Add..."), mb_items),
              LvmButtonBox(),
              HStretch()
            )
          )
        )
      )

      # helptext
      helptext = _(
        "<p>This view shows all LVM volume groups and\ntheir logical volumes.</p>"
      )

      Wizard.RestoreHelp(Ops.add(helptext, StorageFields.TableHelptext(fields)))

      nil
    end


    def HandleLvmMainPanel(user_data, event)
      user_data = deep_copy(user_data)
      event = deep_copy(event)
      device = Convert.to_string(UI.QueryWidget(Id(:table), :CurrentItem))

      HandleLvmButtons(user_data, device, event)

      case Event.IsWidgetContextMenuActivated(event)
        when :table
          EpContextMenuDevice(device)
      end

      UI.SetFocus(Id(:table))

      nil
    end


    def CreateLvmVgOverviewTab(user_data)
      user_data = deep_copy(user_data)
      device = Convert.to_string(user_data)

      target_map = Storage.GetTargetMap

      fields = StorageSettings.FilterOverview(
        [:heading_device, :device, :size, :heading_lvm, :lvm_metadata, :pe_size]
      )

      UI.ReplaceWidget(
        :tab_panel,
        VBox(StorageFields.Overview(fields, target_map, device))
      )

      # helptext
      helptext = _(
        "<p>This view shows detailed information about the\nselected volume group.</p>"
      )

      Wizard.RestoreHelp(
        Ops.add(helptext, StorageFields.OverviewHelptext(fields))
      )

      nil
    end


    def HandleLvmVgOverviewTab(user_data, event)
      user_data = deep_copy(user_data)
      event = deep_copy(event)
      device = Convert.to_string(user_data)

      HandleLvmButtons(nil, device, event)
      UI.SetFocus(Id(:text))

      nil
    end


    def CreateLvmVgLvsTab(user_data)
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
          :size,
          :format,
          :encrypted,
          :type,
          :fs_type,
          :label,
          :mount_point,
          :mount_by,
          :used_by,
          :stripes
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
          DiskBarGraph(device),
          Table(
            Id(:table),
            Opt(:keepSorting, :notify, :notifyContextMenu),
            table_header,
            table_contents
          ),
          HBox(
            # push button text
            PushButton(Id(:add), Opt(:key_F3), _("Add...")),
            LvmButtonBox(),
            HStretch()
          )
        )
      )

      # helptext
      helptext = _(
        "<p>This view shows all logical volumes of the\nselected volume group.</p>"
      )

      Wizard.RestoreHelp(Ops.add(helptext, StorageFields.TableHelptext(fields)))

      nil
    end


    def HandleLvmVgLvsTab(user_data, event)
      user_data = deep_copy(user_data)
      event = deep_copy(event)
      vg_device = Convert.to_string(user_data)
      lv_device = Convert.to_string(UI.QueryWidget(Id(:table), :CurrentItem))

      HandleLvmButtons(vg_device, lv_device, event)

      case Event.IsWidgetContextMenuActivated(event)
        when :table
          EpContextMenuDevice(lv_device)
      end

      UI.SetFocus(Id(:table))

      nil
    end


    def CreateLvmVgPvsTab(user_data)
      user_data = deep_copy(user_data)
      disk_device = Convert.to_string(user_data)

      _Predicate = lambda do |disk, partition|
        disk = deep_copy(disk)
        partition = deep_copy(partition)
        StorageFields.PredicateUsedByDevice(disk, partition, [disk_device])
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
        "<p>This view shows all physical volumes used by\nthe selected volume group.</p>"
      )

      Wizard.RestoreHelp(Ops.add(helptext, StorageFields.TableHelptext(fields)))

      nil
    end


    def CreateLvmVgPanel(user_data)
      user_data = deep_copy(user_data)
      device = Convert.to_string(user_data)

      data = {
        :overview => {
          :create    => fun_ref(method(:CreateLvmVgOverviewTab), "void (any)"),
          :handle    => fun_ref(
            method(:HandleLvmVgOverviewTab),
            "void (any, map)"
          ),
          :user_data => user_data
        },
        :lvs      => {
          :create    => fun_ref(method(:CreateLvmVgLvsTab), "void (any)"),
          :handle    => fun_ref(method(:HandleLvmVgLvsTab), "void (any, map)"),
          :user_data => user_data
        },
        :pvs      => {
          :create    => fun_ref(method(:CreateLvmVgPvsTab), "void (any)"),
          :user_data => user_data
        }
      }

      UI.ReplaceWidget(
        :tree_panel,
        Greasemonkey.Transform(
          VBox(
            # heading
            term(
              :IconAndHeading,
              Builtins.sformat(_("Volume Group: %1"), device),
              StorageIcons.lvm_icon
            ),
            DumbTab(
              Id(:tab),
              [
                # push button text
                Item(Id(:overview), _("&Overview")),
                # push button text
                Item(Id(:lvs), _("&Logical Volumes")),
                # push button text
                Item(Id(:pvs), _("&Physical Volumes"))
              ],
              ReplacePoint(Id(:tab_panel), TabPanel.empty_panel)
            )
          )
        )
      )

      TabPanel.Init(data, :lvs)

      nil
    end


    def HandleLvmVgPanel(user_data, event)
      user_data = deep_copy(user_data)
      event = deep_copy(event)
      TabPanel.Handle(event)

      nil
    end


    def CreateLvmLvPanel(user_data)
      user_data = deep_copy(user_data)
      device = Convert.to_string(user_data)
      target_map = Storage.GetTargetMap

      fields = StorageSettings.FilterOverview(
        [
          :heading_device,
          :device,
          :size,
          :encrypted,
          :used_by,
          :heading_lvm,
          :stripes,
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
              Builtins.sformat(_("Logical Volume: %1"), device),
              StorageIcons.lvm_lv_icon
            ),
            StorageFields.Overview(fields, target_map, device),
            HBox(LvmButtonBox(), HStretch())
          )
        )
      )

      # helptext
      helptext = _(
        "<p>This view shows detailed information about the\nselected logical volume.</p>"
      )

      Wizard.RestoreHelp(
        Ops.add(helptext, StorageFields.OverviewHelptext(fields))
      )

      nil
    end


    def HandleLvmLvPanel(user_data, event)
      user_data = deep_copy(user_data)
      event = deep_copy(event)
      device = Convert.to_string(user_data)

      HandleLvmButtons(nil, device, event)
      UI.SetFocus(Id(:text))

      nil
    end
  end
end
