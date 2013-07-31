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
  module PartitioningEpDmInclude
    def initialize_partitioning_ep_dm(include_target)
      textdomain "storage"

      Yast.include include_target, "partitioning/ep-dm-dialogs.rb"
      Yast.include include_target, "partitioning/ep-dm-lib.rb"
    end

    def EpContextMenuDm(device)
      widget = ContextMenu.Simple([Item(Id(:edit), _("Edit"))])

      case widget
        when :edit
          EpEditDmDevice(device)
      end

      nil
    end


    def CreateDmMainPanel(user_data)
      user_data = deep_copy(user_data)
      _Predicate = lambda do |disk, partition|
        disk = deep_copy(disk)
        partition = deep_copy(partition)
        StorageFields.PredicateDiskType(disk, partition, [:CT_DM])
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
            HStretch(),
            # heading
            term(:IconAndHeading, _("Device Mapper (DM)"), StorageIcons.dm_icon),
            Table(
              Id(:table),
              Opt(:keepSorting, :notify, :notifyContextMenu),
              table_header,
              table_contents
            )
          )
        )
      )

      # helptext
      helptext = _(
        "<p>This view shows all Device Mapper devices except for those already \n" +
          "included in some other view. Therefore multipath disks,\n" +
          "BIOS RAIDs and LVM logical volumes are not shown here.</p>\n"
      )

      Wizard.RestoreHelp(Ops.add(helptext, StorageFields.TableHelptext(fields)))

      nil
    end


    def HandleDmMainPanel(user_data, event)
      user_data = deep_copy(user_data)
      event = deep_copy(event)
      device = Convert.to_string(UI.QueryWidget(Id(:table), :CurrentItem))

      case Event.IsWidgetContextMenuActivated(event)
        when :table
          EpContextMenuDevice(device)
      end

      UI.SetFocus(Id(:table))

      nil
    end


    def CreateDmOverviewTab(user_data)
      user_data = deep_copy(user_data)
      dm_device = Convert.to_string(user_data)

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
            StorageFields.Overview(fields, target_map, dm_device),
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
        "<p>This view shows detailed information about the\nselected Device Mapper device.</p>"
      )

      Wizard.RestoreHelp(
        Ops.add(helptext, StorageFields.OverviewHelptext(fields))
      )

      nil
    end


    def HandleDmOverviewTab(user_data, event)
      user_data = deep_copy(user_data)
      event = deep_copy(event)
      dm_device = Convert.to_string(user_data)

      case Event.IsWidgetActivated(event)
        when :edit
          EpEditDmDevice(dm_device)
      end

      nil
    end


    def CreateDmDevicesTab(user_data)
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
        "<p>This view shows all devices used by the\nselected Device Mapper device.</p>"
      )

      Wizard.RestoreHelp(Ops.add(helptext, StorageFields.TableHelptext(fields)))

      nil
    end


    def CreateDmPanel(user_data)
      user_data = deep_copy(user_data)
      device = Convert.to_string(user_data)

      data = {
        :overview => {
          :create    => fun_ref(method(:CreateDmOverviewTab), "void (any)"),
          :handle    => fun_ref(method(:HandleDmOverviewTab), "void (any, map)"),
          :user_data => user_data
        },
        :devices  => {
          :create    => fun_ref(method(:CreateDmDevicesTab), "void (any)"),
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
              Builtins.sformat(_("DM Device: %1"), device),
              StorageIcons.dm_icon
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


    def HandleDmPanel(user_data, event)
      user_data = deep_copy(user_data)
      event = deep_copy(event)
      TabPanel.Handle(event)

      nil
    end
  end
end
