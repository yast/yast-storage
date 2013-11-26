# encoding: utf-8

# Copyright (c) [2012-2013] Novell, Inc.
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
  module PartitioningEpBtrfsInclude
    def initialize_partitioning_ep_btrfs(include_target)
      textdomain "storage"

      Yast.include include_target, "partitioning/ep-btrfs-dialogs.rb"
      Yast.include include_target, "partitioning/ep-btrfs-lib.rb"
    end


    def EpContextMenuBtrfs(device)
      widget = ContextMenu.Simple(
        [
          # TRANSLATORS: context menu entry
          Item(Id(:edit), _("Edit")),
          # TRANSLATORS: context menu entry
          # disabled, see bnc #832196
          # Item(Id(:resize), _("Resize")),
          # TRANSLATORS: context menu entry
          Item(Id(:delete), _("Delete"))
        ]
      )

      case widget
        when :edit
          EpEditBtrfsDevice(device)
        when :resize
          EpResizeBtrfsDevice(device)
        when :delete
          EpDeleteBtrfsDevice(device)
      end

      nil
    end


    def HandleBtrfsButtons(user_data, device, event)
      user_data = deep_copy(user_data)
      event = deep_copy(event)
      Builtins.y2milestone(
        "HandleBtrfsButtons device:%1 user_data:%2 event:%3",
        device,
        event,
        user_data
      )
      disk_device = ""

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
      else
        disk_device = Convert.to_string(user_data)
      end

      case Event.IsWidgetActivated(event)
        when :edit
          EpEditBtrfsDevice(device)
        when :resize
          EpResizeBtrfsDevice(device)
        when :delete
          EpDeleteBtrfsDevice(device)
      end

      nil
    end


    def CreateBtrfsMainPanel(user_data)
      user_data = deep_copy(user_data)
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
          :mount_by
        ]
      )

      target_map = Storage.GetTargetMap
      table_header = StorageFields.TableHeader(fields)
      table_contents = StorageFields.TableContents(
        fields,
        target_map,
        fun_ref(StorageFields.method(:PredicateBtrfs), "symbol (map, map)")
      )
      UI.ReplaceWidget(
        :tree_panel,
        Greasemonkey.Transform(
          VBox(
            HStretch(),
            # heading
            term(:IconAndHeading, _("Btrfs Volumes"), StorageIcons.dm_icon),
            Table(
              Id(:table),
              Opt(:keepSorting, :notify, :notifyContextMenu),
              table_header,
              table_contents
            ),
            ArrangeButtons(
              [
                # TRANSLATORS: push button text
                PushButton(Id(:edit), Opt(:key_F4), _("Edit...")),
                # TRANSLATORS: push button text
                # disabled, see bnc #832196
                # PushButton(Id(:resize), Opt(:key_F8), _("Resize...")),
                # TRANSLATORS: push button text
                PushButton(Id(:delete), Opt(:key_F5), _("Delete...")),
                HStretch()
              ]
            )
          )
        )
      )

      # helptext
      helptext = _("<p>This view shows all Btrfs volumes.</p>")

      Wizard.RestoreHelp(Ops.add(helptext, StorageFields.TableHelptext(fields)))

      nil
    end

    def HandleBtrfsMainPanel(user_data, event)
      user_data = deep_copy(user_data)
      event = deep_copy(event)
      device = Convert.to_string(UI.QueryWidget(Id(:table), :CurrentItem))
      HandleBtrfsButtons(user_data, device, event)
      case Event.IsWidgetContextMenuActivated(event)
        when :table
          EpContextMenuDevice(device)
      end
      UI.SetFocus(Id(:table))

      nil
    end


    def CreateBtrfsOverviewTab(user_data)
      user_data = deep_copy(user_data)
      device = Convert.to_string(user_data)
      Builtins.y2milestone("CreateBtrfsOverviewTab user_data:%1", user_data)

      target_map = Storage.GetTargetMap

      fields = StorageSettings.FilterOverview(
        [
          :heading_device,
          :device,
          :size,
          :used_by,
          :heading_filesystem,
          :fs_type,
          :mount_point,
          :mount_by,
          :uuid,
          :label
        ]
      )

      UI.ReplaceWidget(
        :tab_panel,
        Greasemonkey.Transform(
          VBox(
            StorageFields.Overview(fields, target_map, device),
            HBox(
              # push button text
              PushButton(Id(:edit), _("Edit...")),
              HStretch()
            )
          )
        )
      )

      # helptext
      helptext = _(
        "<p>This view shows detailed information about the\nselected Btrfs volume.</p>\n"
      )

      Wizard.RestoreHelp(
        Ops.add(helptext, StorageFields.OverviewHelptext(fields))
      )

      nil
    end


    def HandleBtrfsOverviewTab(user_data, event)
      user_data = deep_copy(user_data)
      event = deep_copy(event)
      device = Convert.to_string(user_data)
      Builtins.y2milestone("HandleBtrfsOverviewTab user_data:%1", user_data)

      case Event.IsWidgetActivated(event)
        when :edit
          EpEditBtrfsDevice(device)
        when :delete
          EpDeleteBtrfsDevice(device)
        when :resize
          EpResizeBtrfsDevice(device)
      end

      nil
    end


    def CreateBtrfsDevicesTab(user_data)
      user_data = deep_copy(user_data)
      part_device = Convert.to_string(user_data)
      pos = Builtins.search(part_device, "=")
      if pos != nil
        part_device = Builtins.substring(part_device, Ops.add(pos, 1))
      end
      Builtins.y2milestone(
        "CreateBtrfsDevicesTab user_data:%1 part_device:%2",
        user_data,
        part_device
      )

      _Predicate = lambda do |disk, partition|
        disk = deep_copy(disk)
        partition = deep_copy(partition)
        StorageFields.PredicateUsedByDevice(disk, partition, [part_device])
      end

      fields = StorageSettings.FilterTable(
        [:device, :udev_path, :udev_id, :size, :format, :encrypted, :type]
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
        "<p>This view shows all devices used by the\nselected Btrfs volume.</p>\n"
      )

      Wizard.RestoreHelp(Ops.add(helptext, StorageFields.TableHelptext(fields)))

      nil
    end


    def CreateBtrfsPanel(user_data)
      user_data = deep_copy(user_data)
      device = Convert.to_string(user_data)
      Builtins.y2milestone(
        "CreateBtrfsPanel user_data:%1 device:%2",
        user_data,
        device
      )

      data = {
        :overview => {
          :create    => fun_ref(method(:CreateBtrfsOverviewTab), "void (any)"),
          :handle    => fun_ref(
            method(:HandleBtrfsOverviewTab),
            "void (any, map)"
          ),
          :user_data => user_data
        },
        :devices  => {
          :create    => fun_ref(method(:CreateBtrfsDevicesTab), "void (any)"),
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
              Builtins.sformat(_("Btrfs Device: %1"), device),
              StorageIcons.lvm_lv_icon
            ),
            DumbTab(
              Id(:tab),
              [
                # push button text
                Item(Id(:overview), _("&Overview")),
                # push button text
                Item(Id(:devices), _("&Used Devices"))
              ],
              ReplacePoint(Id(:tab_panel), TabPanel.empty_panel)
            )
          )
        )
      )

      TabPanel.Init(data, :overview)

      nil
    end


    def HandleBtrfsPanel(user_data, event)
      user_data = deep_copy(user_data)
      event = deep_copy(event)
      TabPanel.Handle(event)

      nil
    end
  end
end
