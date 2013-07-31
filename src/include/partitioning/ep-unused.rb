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
  module PartitioningEpUnusedInclude
    def initialize_partitioning_ep_unused(include_target)
      textdomain "storage"

      Yast.include include_target, "partitioning/ep-dialogs.rb"
    end

    def CreateUnusedPanel(user_data)
      user_data = deep_copy(user_data)
      _Predicate = lambda do |disk, partition|
        disk = deep_copy(disk)
        partition = deep_copy(partition)
        disk_type = Ops.get_symbol(disk, "type", :CT_UNKNOWN)

        if partition == nil
          if Builtins.isempty(Ops.get_list(disk, "partitions", [])) &&
              !Storage.IsUsedBy(disk)
            return :show
          end

          return :follow
        else
          if Ops.get_symbol(partition, "type", :primary) != :extended &&
              Builtins.isempty(Ops.get_string(partition, "mount", "")) &&
              !Storage.IsUsedBy(partition)
            return :show
          end

          return :ignore
        end
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
          :label
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
            term(:IconAndHeading, _("Unused Devices"), StorageIcons.unused_icon),
            Table(
              Id(:table),
              Opt(:keepSorting, :notify, :notifyContextMenu),
              table_header,
              table_contents
            ),
            HBox(
              # push button text
              PushButton(Id(:rescan), Opt(:key_F6), _("Rescan")),
              HStretch()
            )
          )
        )
      )

      # helptext
      helptext = _(
        "<p>This view shows devices that have no mount\n" +
          "point assigned to them, disks that are unpartitioned and volume groups that\n" +
          "have no logical volumes.</p>"
      )

      Wizard.RestoreHelp(Ops.add(helptext, StorageFields.TableHelptext(fields)))

      nil
    end


    def HandleUnusedPanel(user_data, event)
      user_data = deep_copy(user_data)
      event = deep_copy(event)
      device = Convert.to_string(UI.QueryWidget(Id(:table), :CurrentItem))

      case Event.IsWidgetContextMenuActivated(event)
        when :table
          EpContextMenuDevice(device)
      end

      case Event.IsWidgetActivated(event)
        when :rescan
          # popup message
          if Popup.YesNo(
              _(
                "Rescanning unused devices cancels\nall current changes. Really rescan unused devices?"
              )
            )
            RescanDisks()
            Storage.CreateTargetBackup("expert-partitioner")

            UpdateMainStatus()
            UpdateNavigationTree(nil)
            TreePanel.Create
          end
      end

      nil
    end
  end
end
