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
  module PartitioningEpLoopInclude
    def initialize_partitioning_ep_loop(include_target)
      textdomain "storage"

      Yast.include include_target, "partitioning/ep-loop-dialogs.rb"
      Yast.include include_target, "partitioning/ep-loop-lib.rb"
    end

    def EpContextMenuLoop(device)
      widget = ContextMenu.Simple(
        [Item(Id(:edit), _("Edit")), Item(Id(:delete), _("Delete"))]
      )

      case widget
        when :edit
          EpEditLoop(device)
        when :delete
          EpDeleteLoop(device)
      end

      nil
    end


    def LoopButtonBox
      HBox(
        # push button text
        PushButton(Id(:edit), Opt(:key_F4), _("Edit...")),
        # push button text
        PushButton(Id(:delete), Opt(:key_F5), _("Delete..."))
      )
    end


    def HandleLoopButtons(part_device, event)
      event = deep_copy(event)
      case Event.IsWidgetActivated(event)
        when :add
          EpCreateLoop()
        when :edit
          EpEditLoop(part_device)
        when :delete
          EpDeleteLoop(part_device)
      end

      nil
    end


    def CreateLoopMainPanel(user_data)
      user_data = deep_copy(user_data)
      _Predicate = lambda do |disk, partition|
        disk = deep_copy(disk)
        partition = deep_copy(partition)
        StorageFields.PredicateDiskType(disk, partition, [:CT_LOOP])
      end

      fields = StorageSettings.FilterTable(
        [:device, :size, :fs_type, :label, :mount_point]
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
            term(:IconAndHeading, _("Crypt Files"), StorageIcons.loop_icon),
            Table(
              Id(:table),
              Opt(:keepSorting, :notify, :notifyContextMenu),
              table_header,
              table_contents
            ),
            HBox(
              # push button text
              PushButton(Id(:add), Opt(:key_F3), _("Add Crypt File...")),
              LoopButtonBox(),
              HStretch()
            )
          )
        )
      )

      # helptext
      helptext = _("<p>This view shows all crypt files.</p>")

      Wizard.RestoreHelp(Ops.add(helptext, StorageFields.TableHelptext(fields)))

      nil
    end


    def HandleLoopMainPanel(user_data, event)
      user_data = deep_copy(user_data)
      event = deep_copy(event)
      device = Convert.to_string(UI.QueryWidget(Id(:table), :CurrentItem))

      HandleLoopButtons(device, event)

      case Event.IsWidgetContextMenuActivated(event)
        when :table
          EpContextMenuDevice(device)
      end

      UI.SetFocus(Id(:table))

      nil
    end


    def CreateLoopPanel(user_data)
      user_data = deep_copy(user_data)
      part_device = Convert.to_string(user_data)

      target_map = Storage.GetTargetMap

      fields = StorageSettings.FilterOverview(
        [
          :heading_device,
          :device,
          :size,
          :file_path,
          :heading_filesystem,
          :fs_type,
          :mount_point
        ]
      )

      UI.ReplaceWidget(
        :tree_panel,
        Greasemonkey.Transform(
          VBox(
            # heading
            term(
              :IconAndHeading,
              Builtins.sformat(_("Crypt File: %1"), part_device),
              StorageIcons.loop_icon
            ),
            HStretch(),
            StorageFields.Overview(fields, target_map, part_device),
            HBox(LoopButtonBox(), HStretch())
          )
        )
      )

      # helptext
      helptext = _(
        "<p>This view shows detailed information of the\nselected crypt file.</p>"
      )

      Wizard.RestoreHelp(
        Ops.add(helptext, StorageFields.OverviewHelptext(fields))
      )

      nil
    end


    def HandleLoopPanel(user_data, event)
      user_data = deep_copy(user_data)
      event = deep_copy(event)
      part_device = Convert.to_string(user_data)

      HandleLoopButtons(part_device, event)

      UI.SetFocus(Id(:text))

      nil
    end
  end
end
