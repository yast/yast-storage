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
  module PartitioningEpRaidInclude
    def initialize_partitioning_ep_raid(include_target)
      textdomain "storage"

      Yast.include include_target, "partitioning/ep-raid-dialogs.rb"
      Yast.include include_target, "partitioning/ep-raid-lib.rb"
    end

    def EpContextMenuRaid(device)
      widget = ContextMenu.Simple(
        [
          Item(Id(:edit), _("Edit")),
          Item(Id(:resize), _("Resize")),
          Item(Id(:delete), _("Delete"))
        ]
      )

      case widget
        when :edit
          EpEditRaid(device)
        when :resize
          EpResizeRaid(device)
        when :delete
          EpDeleteRaid(device)
      end

      nil
    end

    def RaidButtonBox
      HBox(
        # push button text
        PushButton(Id(:edit), Opt(:key_F4), _("Edit...")),
        # push button text
        PushButton(Id(:resize), Opt(:key_F6), _("Resize...")),
        # push button text
        PushButton(Id(:delete), Opt(:key_F5), _("Delete..."))
      )
    end

    def HandleRaidButtons(device, event)
      event = deep_copy(event)
      case Event.IsWidgetActivated(event)
        when :add
          EpCreateRaid()
        when :edit
          EpEditRaid(device)
        when :resize
          EpResizeRaid(device)
        when :delete
          EpDeleteRaid(device)
      end

      nil
    end

    def CreateRaidMainPanel(user_data)
      user_data = deep_copy(user_data)
      _Predicate = lambda do |disk, partition|
        disk = deep_copy(disk)
        partition = deep_copy(partition)
        StorageFields.PredicateDiskType(disk, partition, [:CT_MD])
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
          :raid_type,
          :chunk_size
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
            term(:IconAndHeading, _("RAID"), StorageIcons.raid_icon),
            Table(
              Id(:table),
              Opt(:keepSorting, :notify, :notifyContextMenu),
              table_header,
              table_contents
            ),
            HBox(
              # push button text
              PushButton(Id(:add), Opt(:key_F3), _("Add RAID...")),
              RaidButtonBox(),
              HStretch()
            )
          )
        )
      )

      # helptext
      helptext = _("<p>This view shows all RAIDs except BIOS RAIDs.</p>")

      Wizard.RestoreHelp(Ops.add(helptext, StorageFields.TableHelptext(fields)))

      nil
    end


    def HandleRaidMainPanel(user_data, event)
      user_data = deep_copy(user_data)
      event = deep_copy(event)
      device = Convert.to_string(UI.QueryWidget(Id(:table), :CurrentItem))

      HandleRaidButtons(device, event)

      case Event.IsWidgetContextMenuActivated(event)
        when :table
          EpContextMenuDevice(device)
      end

      UI.SetFocus(Id(:table))

      nil
    end


    def CreateRaidOverviewTab(user_data)
      user_data = deep_copy(user_data)
      part_device = Convert.to_string(user_data)

      target_map = Storage.GetTargetMap

      fields = StorageSettings.FilterOverview(
        [
          :heading_device,
          :device,
          :size,
          :encrypted,
          :udev_id,
          :used_by,
          :heading_md,
          :raid_type,
          :chunk_size,
          :parity_algorithm,
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
        VBox(
          HStretch(),
          StorageFields.Overview(fields, target_map, part_device),
          Left(RaidButtonBox())
        )
      )

      # helptext
      helptext = _(
        "<p>This view shows detailed information about the\nselected RAID.</p>"
      )

      Wizard.RestoreHelp(
        Ops.add(helptext, StorageFields.OverviewHelptext(fields))
      )

      nil
    end


    def HandleRaidOverviewTab(user_data, event)
      user_data = deep_copy(user_data)
      event = deep_copy(event)
      HandleRaidButtons(Convert.to_string(user_data), event)

      UI.SetFocus(Id(:text))

      nil
    end


    def CreateRaidDevicesTab(user_data)
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
        "<p>This view shows all devices used by the\nselected RAID.</p>"
      )

      Wizard.RestoreHelp(Ops.add(helptext, StorageFields.TableHelptext(fields)))

      nil
    end


    def CreateRaidPanel(user_data)
      user_data = deep_copy(user_data)
      device = Convert.to_string(user_data)

      data = {
        :overview => {
          :create    => fun_ref(method(:CreateRaidOverviewTab), "void (any)"),
          :handle    => fun_ref(
            method(:HandleRaidOverviewTab),
            "void (any, map)"
          ),
          :user_data => user_data
        },
        :devices  => {
          :create    => fun_ref(method(:CreateRaidDevicesTab), "void (any)"),
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
              Builtins.sformat(_("RAID: %1"), device),
              StorageIcons.raid_icon
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


    def HandleRaidPanel(user_data, event)
      user_data = deep_copy(user_data)
      event = deep_copy(event)
      TabPanel.Handle(event)

      nil
    end
  end
end
