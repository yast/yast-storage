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
  Yast.import "String"
  module PartitioningEpRaidDialogsInclude
    def initialize_partitioning_ep_raid_dialogs(include_target)
      textdomain "storage"
    end

    def MinimalNumberOfDevicesForRaid(raid_type)
      info = {
        "raid0"     => 2,
        "raid1"     => 2,
        "raid5"     => 3,
        "raid6"     => 4,
        "raid10"    => 2,
        "multipath" => 2
      }
      Ops.get(info, raid_type, 0)
    end


    def CheckNumberOfDevicesForRaid(raid_type, num)
      min_num = MinimalNumberOfDevicesForRaid(raid_type)

      if Ops.less_than(num, min_num)
        info = {
          "raid0"     => "RAID0",
          "raid1"     => "RAID1",
          "raid5"     => "RAID5",
          "raid6"     => "RAID6",
          "raid10"    => "RAID10",
          "multipath" => "Multipath RAID"
        }
        # error popup, %1 is replaced by raid type e.g. "RAID1", %2 is replaced by integer
        Popup.Error(
          Builtins.sformat(
            _("For %1, select at least %2 device."),
            Ops.get(info, raid_type, "error"),
            min_num
          )
        )
        UI.SetFocus(Id(:unselected))
        return false
      else
        return true
      end
    end


    def DefaultChunkSizeK(raid_type)
      info = { "raid0" => 32, "raid5" => 128, "raid6" => 128, "raid10" => 32 }
      Ops.get(info, raid_type, 4)
    end


    def MiniWorkflowStepRaidTypeDevicesHelptext
      # helptext
      helptext = _("<p>Select the RAID type for the new RAID.</p>")

      # helptext
      helptext = Ops.add(
        helptext,
        _(
          "<p><b>RAID 0:</b> This level increases your disk performance.\nThere is <b>NO</b> redundancy in this mode. If one of the drives crashes, data recovery will not be possible.</p>\n"
        )
      )

      # helptext
      helptext = Ops.add(
        helptext,
        _(
          "<p><b>RAID 1:</b> <br>This mode has the best redundancy. It can be\n" +
            "used with two or more disks. This mode maintains an exact copy of all data on all\n" +
            "disks. As long as at least one disk is still working, no data is lost. The partitions\n" +
            "used for this type of RAID should have approximately the same size.</p>\n"
        )
      )

      # helptext
      helptext = Ops.add(
        helptext,
        _(
          "<p><b>RAID 5:</b> <br>This mode combines management of a larger number\n" +
            "of disks and still maintains some redundancy. This mode can be used on three disks or more.\n" +
            "If one disk fails, all data is still intact. If two disks fail simultaneously, all data is lost</p>\n"
        )
      )

      # helptext
      helptext = Ops.add(
        helptext,
        _(
          "<p><b>Raid Name</b> gives you the possibility to provide a meaningful\n" +
            "name for the raid. This is optional. If name is provided, the device is\n" +
	    "available as <tt>/dev/md/&lt;name&gt;</tt>.</p>\n"
        )
      )

      # helptext
      helptext = Ops.add(
        helptext,
        _(
          "<p>Add partitions to your RAID. According to\n" +
            "the RAID type, the usable disk size is the sum of these partitions (RAID0), the size\n" +
            "of the smallest partition (RAID 1), or (N-1)*smallest partition (RAID 5).</p>\n"
        )
      )

      # helptext
      helptext = Ops.add(
        helptext,
        _(
          "<p>Generally, the partitions should be on different drives,\nto get the redundancy and performance you want.</p>\n"
        )
      )

      helptext
    end


    def MiniWorkflowStepRaidTypeDevices(data)
      Builtins.y2milestone(
        "MiniWorkflowStepRaidTypeDevices data:%1",
        data.value
      )

      raid_type = Ops.get_string(data.value, "raid_type", "raid0")
      device = Ops.get_string(data.value, "device", "error")
      devices = Ops.get_list(data.value, "devices", [])

      callback = lambda do |devices2|
        devices2 = deep_copy(devices2)
        sizeK = 0
        sizeK_ref = arg_ref(sizeK)
        Storage.ComputeMdSize(
          Builtins.tosymbol(raid_type),
          Builtins.maplist(devices2) do |device2|
            Ops.get_string(device2, "device", "")
          end,
          sizeK_ref
        )
        sizeK = sizeK_ref.value
        sizeK
      end

      fields = StorageSettings.FilterTable(
        [:device, :udev_path, :udev_id, :size, :encrypted, :type]
      )

      target_map = Storage.GetTargetMap
      unused_devices = Builtins.filter(get_possible_rds(target_map)) do |dev|
        !Storage.IsUsedBy(dev) &&
          !Builtins.contains(devices, Ops.get_string(dev, "device", ""))
      end
      used_devices = Builtins.filter(get_possible_rds(target_map)) do |dev|
        !Storage.IsUsedBy(dev) &&
          Builtins.contains(devices, Ops.get_string(dev, "device", ""))
      end

      contents = VBox(
        Left(
          # heading
          HVSquash(
	    HBox(
	      term(
		:FrameWithMarginBox,
		_("RAID Type"),
		RadioButtonGroup(
		  Id(:raid_type),
		  VBox(
		    # Translators, 'Striping' is a technical term here. Translate only if
		    # you are sure!! If in doubt, leave it in English.
		    term(
		      :LeftRadioButton,
		      Id(:raid0),
		      Opt(:notify),
		      _("RAID &0  (Striping)"),
		      raid_type == "raid0"
		    ),
		    # Translators, 'Mirroring' is a technical term here. Translate only if
		    # you are sure!! If in doubt, leave it in English.
		    term(
		      :LeftRadioButton,
		      Id(:raid1),
		      Opt(:notify),
		      _("RAID &1  (Mirroring)"),
		      raid_type == "raid1"
		    ),
		    # Translators, 'Redundant Striping' is a technical term here. Translate
		    # only if you are sure!! If in doubt, leave it in English.
		    term(
		      :LeftRadioButton,
		      Id(:raid5),
		      Opt(:notify),
		      _("RAID &5  (Redundant Striping)"),
		      raid_type == "raid5"
		    ),
		    # Translators, 'Redundant Striping' is a technical term here. Translate only if
		    # you are sure!! If in doubt, leave it in English.
		    term(
		      :LeftRadioButton,
		      Id(:raid6),
		      Opt(:notify),
		      _("RAID &6  (Dual Redundant Striping)"),
		      raid_type == "raid6"
		    ),
		    # Translators, 'Mirroring' and 'Striping' are technical terms here. Translate only if
		    # you are sure!! If in doubt, leave it in English.
		    term(
		      :LeftRadioButton,
		      Id(:raid10),
		      Opt(:notify),
		      _("RAID &10  (Mirroring and Striping)"),
		      raid_type == "raid10"
		    )
		  )
		)
	      ),
	      HSpacing(1),
	      Top(
		TextEntry(
		  Id(:raid_name),
		  # label text
		  _("Raid &Name (optional)")
		)
	      )
            )
          )
        )
      )

      contents = Builtins.add(contents, VSpacing(1))
      contents = Builtins.add(
        contents,
        DevicesSelectionBox.Create(
          unused_devices,
          used_devices,
          fields,
          fun_ref(callback, "integer (list <map>)"),
          # label for selection box
          _("Available Devices:"),
          # label for selection box
          _("Selected Devices:"),
          true
        )
      )

      MiniWorkflow.SetContents(
        Greasemonkey.Transform(contents),
        MiniWorkflowStepRaidTypeDevicesHelptext()
      )
      MiniWorkflow.SetLastStep(false)

      UI.ChangeWidget(Id(:raid_name), :ValidChars, Builtins.deletechars(String.CGraph, "'\""))

      widget = nil
      begin
        widget = MiniWorkflow.UserInput
        DevicesSelectionBox.Handle(widget)

        case widget
          when :raid0, :raid1, :raid10, :raid5, :raid6
            raid_type = Builtins.substring(
              Builtins.tostring(
                Convert.to_symbol(UI.QueryWidget(Id(:raid_type), :Value))
              ),
              1
            )
            DevicesSelectionBox.UpdateSelectedSize
          when :next
            devices = Builtins.maplist(DevicesSelectionBox.GetSelectedDevices) do |device2|
              Ops.get_string(device2, "device", "")
            end

            if !CheckNumberOfDevicesForRaid(raid_type, Builtins.size(devices))
              widget = :again
            end
        end
      end until widget == :abort || widget == :back || widget == :next

      if widget == :next
        rname = UI.QueryWidget(Id(:raid_name), :Value)
	if !rname.empty?
	  data.value["device"] = "/dev/md/"+rname
	else
	  data.value["device"] = "/dev/md"+data.value.fetch("nr",0).to_s
	end
        data.value["raid_type"] = raid_type
        data.value["devices"] = devices

        size_k = 0
        size_k_ref = arg_ref(size_k)
        Storage.ComputeMdSize(Builtins.tosymbol(raid_type), devices, size_k_ref)
        size_k = size_k_ref.value
        Ops.set(data.value, "size_k", size_k)

        Ops.set(data.value, "using_devices", devices)
      end

      Builtins.y2milestone(
        "MiniWorkflowStepRaidTypeDevices data:%1 ret:%2",
        data.value,
        widget
      )

      widget
    end


    def MiniWorkflowStepRaidOptionsHelptext(data)
      raid_type = Ops.get_string(data.value, "raid_type", "error")

      # helptext
      helptext = _(
        "<p><b>Chunk Size:</b><br>It is the smallest \"atomic\" mass\n" +
          "of data that can be written to the devices. A reasonable chunk size for RAID 5 is 128 kB. For RAID 0,\n" +
          "32 kB is a good starting point. For RAID 1, the chunk size does not affect the array very much.</p>\n"
      )

      if Builtins.contains(["raid5", "raid6", "raid10"], raid_type)
        helptext = Ops.add(helptext, "<p><b>")
        helptext = Ops.add(helptext, _("Parity Algorithm:"))
        helptext = Ops.add(helptext, "</b><br>")

        if raid_type == "raid5" || raid_type == "raid6"
          # helptext
          helptext = Ops.add(
            helptext,
            _(
              "The parity algorithm to use with RAID5/6.\nLeft-symmetric is the one that offers maximum performance on typical disks with rotating platters.\n"
            )
          )
        elsif raid_type == "raid10"
          # helptext
          helptext = Ops.add(
            helptext,
            _(
              "For further details regarding the parity \nalgorithm please look at the man page for mdadm (man mdadm).\n"
            )
          )
        end
        helptext = Ops.add(helptext, "</p>")
      end
      helptext
    end

    def getParTerms(mdtype, sz)
      pars = Storage.AllowedParity(mdtype, sz)
      Builtins.maplist(pars) do |e|
        Item(Id(Ops.get_symbol(e, 0, :par_default)), Ops.get_string(e, 1, ""))
      end
    end

    def MiniWorkflowStepRaidOptions(data)
      Builtins.y2milestone("MiniWorkflowStepRaidOptions data:%1", data.value)

      raid_type = Ops.get_string(data.value, "raid_type", "error")
      chunk_size = Ops.multiply(
        Ops.get_integer(data.value, "chunk_size_k") do
          DefaultChunkSizeK(raid_type)
        end,
        1024
      )
      parity_algorithm = Ops.get_symbol(
        data.value,
        "parity_algorithm",
        :par_default
      )

      chunk_sizes_list = Builtins.maplist(Integer.RangeFrom(11, 22)) do |i|
        Item(
          Id(Ops.shift_left(2, i)),
          Storage.ByteToHumanStringOmitZeroes(Ops.shift_left(2, i))
        )
      end

      options = VBox(
        Left(
          term(
            :ComboBoxSelected,
            Id(:chunk_size),
            _("Chunk Size"),
            chunk_sizes_list,
            Id(chunk_size)
          )
        )
      )

      par_list = getParTerms(
        raid_type,
        Builtins.size(Ops.get_list(data.value, "devices", []))
      )

      if Ops.greater_than(Builtins.size(par_list), 0)
        options = Builtins.add(
          options,
          Left(
            term(
              :ComboBoxSelected,
              Id(:parity_algorithm),
              Opt(:hstretch),
              # combo box label
              _("Parity &Algorithm"),
              par_list,
              Id(parity_algorithm)
            )
          )
        )
      end

      # heading
      contents = HVSquash(term(:FrameWithMarginBox, _("RAID Options"), options))

      MiniWorkflow.SetContents(
        Greasemonkey.Transform(contents),
        (
          data_ref = arg_ref(data.value);
          _MiniWorkflowStepRaidOptionsHelptext_result = MiniWorkflowStepRaidOptionsHelptext(
            data_ref
          );
          data.value = data_ref.value;
          _MiniWorkflowStepRaidOptionsHelptext_result
        )
      )
      MiniWorkflow.SetLastStep(false)

      widget = nil
      begin
        widget = MiniWorkflow.UserInput
      end until widget == :abort || widget == :back || widget == :next

      if widget == :next
        chunk_size = Convert.to_integer(UI.QueryWidget(Id(:chunk_size), :Value))

        if UI.WidgetExists(Id(:parity_algorithm))
          parity_algorithm = Convert.to_symbol(
            UI.QueryWidget(Id(:parity_algorithm), :Value)
          )
        end

        Ops.set(data.value, "chunk_size_k", Ops.divide(chunk_size, 1024))
        Ops.set(data.value, "parity_algorithm", parity_algorithm)
      end

      Builtins.y2milestone(
        "MiniWorkflowStepRaidOptions data:%1 ret:%2",
        data.value,
        widget
      )

      widget
    end


    def MiniWorkflowStepResizeHelptext
      # helptext
      helptext = _("<p>Change the devices that are used for the RAID.</p>")

      helptext
    end


    def MiniWorkflowStepResizeRaid(data)
      Builtins.y2milestone("MiniWorkflowStepResizeRaid data:%1", data.value)

      device = Ops.get_string(data.value, "device", "error")
      raid_type = Ops.get_string(data.value, "raid_type", "error")
      devices_new = []

      callback = lambda do |devices|
        devices = deep_copy(devices)
        sizeK = 0
        sizeK_ref = arg_ref(sizeK)
        Storage.ComputeMdSize(
          Builtins.tosymbol(raid_type),
          Builtins.maplist(devices) do |device2|
            Ops.get_string(device2, "device", "")
          end,
          sizeK_ref
        )
        sizeK = sizeK_ref.value
        sizeK
      end

      fields = StorageSettings.FilterTable(
        [:device, :udev_path, :udev_id, :size, :encrypted, :type]
      )

      target_map = Storage.GetTargetMap
      unused_devices = Builtins.filter(get_possible_rds(target_map)) do |dev|
        Ops.get_string(dev, "used_by_device", "") == ""
      end
      used_devices = Builtins.filter(get_possible_rds(target_map)) do |dev|
        Ops.get_string(dev, "used_by_device", "") == device
      end

      contents = VBox()

      contents = Builtins.add(
        contents,
        DevicesSelectionBox.Create(
          unused_devices,
          used_devices,
          fields,
          fun_ref(callback, "integer (list <map>)"),
          _("Available Devices:"),
          _("Selected Devices:"),
          true
        )
      )

      MiniWorkflow.SetContents(
        Greasemonkey.Transform(contents),
        MiniWorkflowStepResizeHelptext()
      )
      MiniWorkflow.SetLastStep(true)

      widget = nil
      begin
        widget = MiniWorkflow.UserInput
        DevicesSelectionBox.Handle(widget)

        case widget
          when :next
            devices_new = Builtins.maplist(
              DevicesSelectionBox.GetSelectedDevices
            ) { |device2| Ops.get_string(device2, "device", "") }

            if !CheckNumberOfDevicesForRaid(
                raid_type,
                Builtins.size(devices_new)
              )
              widget = :again
            end
        end
      end until widget == :abort || widget == :back || widget == :next

      if widget == :next
        Ops.set(data.value, "devices_new", devices_new)

        widget = :finish
      end

      Builtins.y2milestone(
        "MiniWorkflowStepResizeRaid data:%1 ret:%2",
        data.value,
        widget
      )

      widget
    end


    def DlgCreateRaidNew(data)
      aliases = {
        "TypeDevices" => lambda do
          (
            data_ref = arg_ref(data.value);
            _MiniWorkflowStepRaidTypeDevices_result = MiniWorkflowStepRaidTypeDevices(
              data_ref
            );
            data.value = data_ref.value;
            _MiniWorkflowStepRaidTypeDevices_result
          )
        end,
        "Options"     => lambda do
          (
            data_ref = arg_ref(data.value);
            _MiniWorkflowStepRaidOptions_result = MiniWorkflowStepRaidOptions(
              data_ref
            );
            data.value = data_ref.value;
            _MiniWorkflowStepRaidOptions_result
          )
        end,
        "FormatMount" => lambda do
          (
            data_ref = arg_ref(data.value);
            _MiniWorkflowStepFormatMount_result = MiniWorkflowStepFormatMount(
              data_ref
            );
            data.value = data_ref.value;
            _MiniWorkflowStepFormatMount_result
          )
        end,
        "Password"    => lambda do
          (
            data_ref = arg_ref(data.value);
            _MiniWorkflowStepPassword_result = MiniWorkflowStepPassword(
              data_ref
            );
            data.value = data_ref.value;
            _MiniWorkflowStepPassword_result
          )
        end
      }

      sequence = {
        "TypeDevices" => { :next => "Options" },
        "Options"     => { :next => "FormatMount" },
        "FormatMount" => { :next => "Password", :finish => :finish },
        "Password"    => { :finish => :finish }
      }

      # dialog title
      title = Builtins.sformat(
        _("Add RAID %1"),
        Ops.get_string(data.value, "device", "error")
      )

      widget = MiniWorkflow.Run(
        title,
        StorageIcons.raid_icon,
        aliases,
        sequence,
        "TypeDevices"
      )

      widget == :finish
    end


    def DlgResizeRaid(data)
      aliases = {
        "TheOne" => lambda do
        (
          data_ref = arg_ref(data.value);
          _MiniWorkflowStepResizeRaid_result = MiniWorkflowStepResizeRaid(
            data_ref
          );
          data.value = data_ref.value;
          _MiniWorkflowStepResizeRaid_result
        )
        end
      }

      sequence = { "TheOne" => { :finish => :finish } }

      # dialog title
      title = Builtins.sformat(
        _("Resize RAID %1"),
        Ops.get_string(data.value, "device", "error")
      )

      widget = MiniWorkflow.Run(
        title,
        StorageIcons.raid_icon,
        aliases,
        sequence,
        "TheOne"
      )

      widget == :finish
    end


    def DlgEditRaid(data)
      device = Ops.get_string(data.value, "device", "error")

      aliases = {
        "FormatMount" => lambda do
        (
          data_ref = arg_ref(data.value);
          _MiniWorkflowStepFormatMount_result = MiniWorkflowStepFormatMount(
            data_ref
          );
          data.value = data_ref.value;
          _MiniWorkflowStepFormatMount_result
        )
        end,
        "Password" => lambda do
        (
          data_ref = arg_ref(data.value);
          _MiniWorkflowStepPassword_result = MiniWorkflowStepPassword(data_ref);
          data.value = data_ref.value;
          _MiniWorkflowStepPassword_result
        )
        end
      }

      sequence = {
        "FormatMount" => { :next => "Password", :finish => :finish },
        "Password"    => { :finish => :finish }
      }

      # dialog title
      title = Builtins.sformat(_("Edit RAID %1"), device)

      widget = MiniWorkflow.Run(
        title,
        StorageIcons.raid_icon,
        aliases,
        sequence,
        "FormatMount"
      )

      widget == :finish
    end
  end
end
