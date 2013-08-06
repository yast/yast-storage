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
  module PartitioningEpGraphInclude
    def initialize_partitioning_ep_graph(include_target)
      textdomain "storage"
    end

    def EpContextMenuDeviceGraph
      widget = ContextMenu.Simple(
        [
          Item(
            Id(:add_raid),
            term(:icon, StorageIcons.raid_icon),
            _("Add RAID")
          ),
          Item(
            Id(:add_lvmvg),
            term(:icon, StorageIcons.lvm_icon),
            _("Add Volume Group")
          )
        ]
      )

      case widget
        when :add_raid
          EpCreateRaid()
        when :add_lvmvg
          EpCreateVolumeGroup()
      end

      nil
    end


    def CreateDeviceGraphPanel(user_data)
      filename = "#{Directory.tmpdir}/device.gv"
      Storage.SaveDeviceGraph(filename)

      UI.ReplaceWidget(
        :tree_panel,
        Greasemonkey.Transform(
          VBox(
            # dialog heading, graph is the mathematic term for
            # a set of notes connected with edges
            term(:IconAndHeading, _("Device Graph"), StorageIcons.graph_icon),
            term(
              :Graph,
              Id(:graph),
              Opt(:notify, :notifyContextMenu),
              filename,
              "dot"
            ),
            HBox(
              # button text
              PushButton(Id(:save), _("Save Device Graph...")),
              HStretch()
            )
          )
        )
      )

      SCR.Execute(path(".target.remove"), filename)

      # helptext
      helptext = _("<p>This view shows a graph of devices.</p>")

      Wizard.RestoreHelp(helptext)

      nil
    end


    def RefreshDeviceGraphPanel(user_data)
      filename = "#{Directory.tmpdir}/device.gv"
      Storage.SaveDeviceGraph(filename)

      UI.ChangeWidget(Id(:graph), :Filename, filename)

      SCR.Execute(path(".target.remove"), filename)

      nil
    end


    def HandleDeviceGraphPanel(user_data, event)
      event = deep_copy(event)
      _GotoDevice = lambda do |device|
        TreePanel.SwitchToNew(device)
        UI.SetFocus(UI.WidgetExists(Id(:table)) ? Id(:table) : Id(:text))

        nil
      end

      case Event.IsWidgetContextMenuActivated(event)
        when :graph
          node = Convert.to_string(UI.QueryWidget(Id(:graph), :Item))

          if Builtins.isempty(node)
            EpContextMenuDeviceGraph()
          elsif String.StartsWith(node, "device:")
            EpContextMenuDevice(Builtins.substring(node, 7))
          end 

          # TODO: update graph
      end

      case Event.IsWidgetActivated(event)
        when :graph
          node = Convert.to_string(UI.QueryWidget(Id(:graph), :Item))

          if String.StartsWith(node, "device:")
            _GotoDevice.call(Builtins.substring(node, 7))
          elsif String.StartsWith(node, "mountpoint:")
            _GotoDevice.call(Builtins.substring(node, 11))
          end
        when :save
          filename = UI.AskForSaveFileName("/tmp", "*.gv", "Save as...")
          if filename != nil
            if !Storage.SaveDeviceGraph(filename)
              # error popup
              Popup.Error(_("Saving graph file failed."))
            end
          end
      end

      nil
    end


    def CreateMountGraphPanel(user_data)
      filename = "#{Directory.tmpdir}/mount.gv"
      Storage.SaveMountGraph(filename)

      UI.ReplaceWidget(
        :tree_panel,
        Greasemonkey.Transform(
          VBox(
            # dialog heading, graph is the mathematic term for
            # a set of notes connected with edges
            term(:IconAndHeading, _("Mount Graph"), StorageIcons.graph_icon),
            term(
              :Graph,
              Id(:graph),
              Opt(:notify, :notifyContextMenu),
              filename,
              "dot"
            ),
            HBox(
              # button text
              PushButton(Id(:save), _("Save Mount Graph...")),
              HStretch()
            )
          )
        )
      )

      SCR.Execute(path(".target.remove"), filename)

      # helptext
      helptext = _("<p>This view shows a graph of mount points.</p>")

      Wizard.RestoreHelp(helptext)

      nil
    end


    def RefreshMountGraphPanel(user_data)
      filename = "#{Directory.tmpdir}/mount.gv"
      Storage.SaveMountGraph(filename)

      UI.ChangeWidget(Id(:graph), :Filename, filename)

      SCR.Execute(path(".target.remove"), filename)

      nil
    end


    def HandleMountGraphPanel(user_data, event)
      event = deep_copy(event)
      _GotoDevice = lambda do |device|
        TreePanel.SwitchToNew(device)
        UI.SetFocus(UI.WidgetExists(Id(:table)) ? Id(:table) : Id(:text))

        nil
      end

      case Event.IsWidgetActivated(event)
        when :graph
          node = Convert.to_string(UI.QueryWidget(Id(:graph), :Item))

          if String.StartsWith(node, "mountpoint:")
            _GotoDevice.call(Builtins.substring(node, 11))
          end
        when :save
          filename = UI.AskForSaveFileName("/tmp", "*.gv", "Save as...")
          if filename != nil
            if !Storage.SaveMountGraph(filename)
              # error popup
              Popup.Error(_("Saving graph file failed."))
            end
          end
      end

      nil
    end
  end
end
