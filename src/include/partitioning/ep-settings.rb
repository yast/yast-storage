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
  module PartitioningEpSettingsInclude
    def initialize_partitioning_ep_settings(include_target)
      textdomain "storage"


      @visible_fields = [
        # list entry
        { :label => _("Label"), :fields => [:label] },
        # list entry
        { :label => _("UUID"), :fields => [:uuid] },
        # list entry
        { :label => _("Mount by"), :fields => [:mount_by] },
        # list entry
        { :label => _("Used by"), :fields => [:used_by] },
        # list entry
        { :label => _("BIOS ID"), :fields => [:bios_id] },
        # list entry
        {
          :label  => _("Cylinder information"),
          :fields => Builtins.toset([:start_cyl, :end_cyl, :num_cyl, :cyl_size])
        },
        # list entry
        {
          :label  => _("Fibre Channel information"),
          :fields => Builtins.toset([:fc_wwpn, :fc_fcp_lun, :fc_port_id])
        },
        # list entry
        { :label => _("Encryption"), :fields => [:encrypted] }
      ]

      @mount_bys = {
        # combo box entry
        :device => _("Device Name"),
        # combo box entry
        :label  => _("Volume Label"),
        # combo box entry
        :uuid   => _("UUID"),
        # combo box entry
        :id     => _("Device ID"),
        # combo box entry
        :path   => _("Device Path")
      }
    end

    def CreateSettingsPanel(user_data)
      user_data = deep_copy(user_data)
      _PreselectVisibleFields = lambda do
        hidden_fields = StorageSettings.GetHiddenFields
        Builtins.maplist(Integer.Range(Builtins.size(@visible_fields))) do |i|
          label = Ops.get_string(@visible_fields, [i, :label], "")
          fields = Ops.get_list(@visible_fields, [i, :fields], [])
          selected = !Builtins::Multiset.includes(hidden_fields, fields)
          Item(Id(i), label, selected)
        end
      end

      mount_by_items = Builtins.maplist(@mount_bys) do |item_id, label|
        Item(Id(item_id), label)
      end

      filesystems = Builtins.filter(
        [:ext2, :ext3, :ext4, :reiser, :xfs, :btrfs]
      ) do |fs|
        FileSystems.IsSupported(fs) && !FileSystems.IsUnsupported(fs)
      end

      filesystem_items = Builtins.maplist(filesystems) do |fs|
        Item(Id(fs), FileSystems.GetName(fs, "Error"))
      end

      partalign_items = Builtins.maplist([:align_optimal, :align_cylinder]) do |pal|
        Item(Id(pal), Builtins.substring(Builtins.sformat("%1", pal), 7))
      end


      UI.ReplaceWidget(
        :tree_panel,
        Greasemonkey.Transform(
          VBox(
            # dialog heading
            term(:IconAndHeading, _("Settings"), StorageIcons.settings_icon),
            VBox(
              Left(
                term(
                  :ComboBoxSelected,
                  Id(:default_mountby),
                  Opt(:notify),
                  # combo box label
                  _("Default Mount by"),
                  mount_by_items,
                  Id(Storage.GetDefaultMountBy)
                )
              ),
              Left(
                term(
                  :ComboBoxSelected,
                  Id(:default_fs),
                  Opt(:notify),
                  # combo box label
                  _("Default File System"),
                  filesystem_items,
                  Id(Partitions.DefaultFs)
                )
              ),
              Left(
                term(
                  :ComboBoxSelected,
                  Id(:part_align),
                  Opt(:notify),
                  # combo box label
                  _("Alignment of Newly Created Partitions"),
                  partalign_items,
                  Id(Storage.GetPartitionAlignment)
                )
              ),
              VSpacing(1),
              Left(
                term(
                  :ComboBoxSelected,
                  Id(:display_name),
                  Opt(:notify),
                  # combo box label
                  _("Show Storage Devices by"),
                  [
                    # combo box entry
                    Item(Id(:device), _("Device Name")),
                    # combo box entry
                    Item(Id(:id), _("Device ID")),
                    # combo box entry
                    Item(Id(:path), _("Device Path"))
                  ],
                  Id(StorageSettings.GetDisplayName)
                )
              ),
              #This looks extremely ugly, but obviously there are few other means how
              #to make MultiSelection widget smaller, yet still readable
              Left(
                HBox(
                  MultiSelectionBox(
                    Id(:visible_fields),
                    Opt(:shrinkable, :notify),
                    # multi selection box label
                    _("Visible Information on Storage Devices"),
                    _PreselectVisibleFields.call
                  ),
                  HStretch()
                )
              )
            ),
            VStretch()
          )
        )
      )


      # helptext
      helptext = _("<p>This view shows general storage\nsettings:</p>")

      # helptext
      helptext = Ops.add(
        helptext,
        _(
          "<p><b>Default Mount by</b> gives the mount by\n" +
            "method for newly created file systems. <i>Device Name</i> uses the kernel\n" +
            "device name, which is not persistent. <i>Device ID</i> and <i>Device Path</i>\n" +
            "use names generated by udev from hardware information. These should be\n" +
            "persistent but unfortunately this is not always true. Finally <i>UUID</i> and\n" +
            "<i>Volume Label</i> use the file systems UUID and label.</p>\n"
        )
      )

      # helptext
      helptext = Ops.add(
        helptext,
        _(
          "<p><b>Default File System</b> gives the file\nsystem type for newly created file systems.</p>\n"
        )
      )

      # helptext
      helptext = Ops.add(
        helptext,
        _(
          "<p><b>Alignment of Newly Created Partitions</b>\n" +
            "determines how created partitions are aligned. <b>cylinder</b> is the traditional alignment at cylinder boundaries of the disk. <b>optimal</b> aligns the \n" +
            "partitions for best performance according to hints provided by the Linux \n" +
            "kernel or tries to be compatible with Windows Vista and Win 7.</p>\n"
        )
      )

      # helptext
      helptext = Ops.add(
        helptext,
        _(
          "<p><b>Show Storage Devices by</b> controls\nthe name displayed for hard disks in the navigation tree.</p>"
        )
      )

      # helptext
      helptext = Ops.add(
        helptext,
        _(
          "<p><b>Visible Information On Storage\nDevices</b> allows to hide information in the tables and overview.</p>"
        )
      )

      Wizard.RestoreHelp(helptext)

      nil
    end


    def HandleSettingsPanel(user_data, event)
      user_data = deep_copy(user_data)
      event = deep_copy(event)
      case Event.IsWidgetValueChanged(event)
        when :display_name
          StorageSettings.SetDisplayName(
            Convert.to_symbol(UI.QueryWidget(Id(:display_name), :Value))
          )
          UpdateNavigationTree(nil)
      end

      case Event.IsWidgetActivated(event)
        when :next
          DestroySettingsPanel(user_data)
      end

      if !StorageSettings.GetModified
        StorageSettings.SetModified
        Wizard.SetNextButton(:next, Label.NextButton)
      end

      nil
    end
    def DestroySettingsPanel(user_data)
      user_data = deep_copy(user_data)
      selected = Convert.convert(
        UI.QueryWidget(Id(:visible_fields), :SelectedItems),
        :from => "any",
        :to   => "list <integer>"
      )
      selected_labels = []

      Builtins.foreach(selected) do |i|
        selected_labels = Builtins.add(
          selected_labels,
          Ops.get_string(@visible_fields, [i, :label], "")
        )
      end

      default_mount = Convert.to_symbol(
        UI.QueryWidget(Id(:default_mountby), :Value)
      )
      default_fs = Convert.to_symbol(UI.QueryWidget(Id(:default_fs), :Value))
      part_align = Convert.to_symbol(UI.QueryWidget(Id(:part_align), :Value))

      Storage.SetDefaultMountBy(default_mount)
      Partitions.SetDefaultFs(default_fs)
      Storage.SetPartitionAlignment(part_align)
      StorageSettings.InvertVisibleFields(@visible_fields, selected)

      nil
    end
  end
end
