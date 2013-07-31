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
  module PartitioningEpTmpfsInclude
    def initialize_partitioning_ep_tmpfs(include_target)
      textdomain "storage"

      Yast.include include_target, "partitioning/ep-tmpfs-dialogs.rb"
      Yast.include include_target, "partitioning/ep-tmpfs-lib.rb"
    end

    def EpContextMenuTmpfs(device)
      widget = ContextMenu.Simple([Item(Id(:delete), _("Delete"))])

      case widget
        when :delete
          EpDeleteTmpfsDevice(device)
      end

      nil
    end

    def HandleTmpfsButtons(user_data, device, event)
      user_data = deep_copy(user_data)
      event = deep_copy(event)
      Builtins.y2milestone(
        "HandleTmpfsButtons device:%1 user_data:%2 event:%3",
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
        when :delete
          EpDeleteTmpfsDevice(device)
        when :add
          EpAddTmpfsDevice()
      end

      nil
    end

    def CreateTmpfsMainPanel(user_data)
      user_data = deep_copy(user_data)
      fields = StorageSettings.FilterTable(
        [:size, :type, :fs_type, :mount_point]
      )

      target_map = Storage.GetTargetMap
      table_header = StorageFields.TableHeader(fields)
      table_contents = StorageFields.TableContents(
        fields,
        target_map,
        fun_ref(StorageFields.method(:PredicateTmpfs), "symbol (map, map)")
      )
      UI.ReplaceWidget(
        :tree_panel,
        Greasemonkey.Transform(
          VBox(
            HStretch(),
            # heading
            term(:IconAndHeading, _("tmpfs Volumes"), StorageIcons.dm_icon),
            Table(
              Id(:table),
              Opt(:keepSorting, :notify, :notifyContextMenu),
              table_header,
              table_contents
            ),
            ArrangeButtons(
              [
                PushButton(Id(:add), Opt(:key_F3), _("Add...")),
                # push button text
                PushButton(Id(:delete), Opt(:key_F5), _("Delete...")),
                HStretch()
              ] # push button text
            )
          )
        )
      )

      # helptext
      helptext = _("<p>This view shows all tmpfs volumes.</p>")

      Wizard.RestoreHelp(Ops.add(helptext, StorageFields.TableHelptext(fields)))

      nil
    end

    def HandleTmpfsMainPanel(user_data, event)
      user_data = deep_copy(user_data)
      event = deep_copy(event)
      device = Convert.to_string(UI.QueryWidget(Id(:table), :CurrentItem))
      HandleTmpfsButtons(user_data, device, event)
      case Event.IsWidgetContextMenuActivated(event)
        when :table
          EpContextMenuDevice(device)
      end
      UI.SetFocus(Id(:table))

      nil
    end


    def CreateTmpfsOverviewTab(user_data)
      user_data = deep_copy(user_data)
      device = Convert.to_string(user_data)
      Builtins.y2milestone("CreateTmpfsOverviewTab user_data:%1", user_data)

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
          :mount_by
        ]
      )

      UI.ReplaceWidget(
        :tab_panel,
        Greasemonkey.Transform(
          VBox(
            StorageFields.Overview(fields, target_map, device),
            HBox(
              # push button text
              PushButton(Id(:delete), _("Delete...")),
              HStretch()
            )
          )
        )
      )

      # helptext
      helptext = _(
        "<p>This view shows detailed information about the\nselected tmpfs volume.</p>\n"
      )

      Wizard.RestoreHelp(
        Ops.add(helptext, StorageFields.OverviewHelptext(fields))
      )

      nil
    end


    def HandleTmpfsOverviewTab(user_data, event)
      user_data = deep_copy(user_data)
      event = deep_copy(event)
      device = Convert.to_string(user_data)
      Builtins.y2milestone("HandleTmpfsOverviewTab user_data:%1", user_data)

      case Event.IsWidgetActivated(event)
        when :add
          EpAddTmpfsDevice()
        when :delete
          EpDeleteTmpfsDevice(device)
      end

      nil
    end


    def CreateTmpfsPanel(user_data)
      user_data = deep_copy(user_data)
      device = Convert.to_string(user_data)
      Builtins.y2milestone(
        "CreateTmpfsPanel user_data:%1 device:%2",
        user_data,
        device
      )

      data = {
        :overview => {
          :create    => fun_ref(method(:CreateTmpfsOverviewTab), "void (any)"),
          :handle    => fun_ref(
            method(:HandleTmpfsOverviewTab),
            "void (any, map)"
          ),
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
              Builtins.sformat(_("tmpfs mounted at %1"), device),
              StorageIcons.lvm_lv_icon
            ),
            DumbTab(
              Id(:tab),
              [
                # push button text
                Item(Id(:overview), _("&Overview"))
              ],
              ReplacePoint(Id(:tab_panel), TabPanel.empty_panel)
            )
          )
        )
      )

      TabPanel.Init(data, :overview)

      nil
    end


    def HandleTmpfsPanel(user_data, event)
      user_data = deep_copy(user_data)
      event = deep_copy(event)
      TabPanel.Handle(event)

      nil
    end
  end
end
