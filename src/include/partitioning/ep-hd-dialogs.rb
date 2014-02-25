# encoding: utf-8

# Copyright (c) [2012-2014] Novell, Inc.
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
  module PartitioningEpHdDialogsInclude


    include Yast::Logger


    def initialize_partitioning_ep_hd_dialogs(include_target)
      textdomain "storage"
    end


    def MiniWorkflowStepPartitionTypeHelptext
      # helptext
      helptext = _("<p>Choose the partition type for the new partition.</p>")

      helptext
    end


    def MiniWorkflowStepPartitionType(data)

      log.info("MiniWorkflowStepPartitionType data:#{data.value}")

      type = Ops.get_symbol(data.value, "type", :unknown)
      slots = Ops.get_map(data.value, "slots", {})

      tmp = VBox()

      if Builtins.haskey(slots, :primary)
        # radio button text
        tmp = Builtins.add(
          tmp,
          term(
            :LeftRadioButton,
            Id(:primary),
            _("&Primary Partition"),
            type == :primary
          )
        )
      end

      if Builtins.haskey(slots, :extended)
        # radio button text
        tmp = Builtins.add(
          tmp,
          term(
            :LeftRadioButton,
            Id(:extended),
            _("&Extended Partition"),
            type == :extended
          )
        )
      end

      if Builtins.haskey(slots, :logical)
        # radio button text
        tmp = Builtins.add(
          tmp,
          term(
            :LeftRadioButton,
            Id(:logical),
            _("&Logical Partition"),
            type == :logical
          )
        )
      end

      # heading for a frame in a dialog
      contents = HVSquash(
        term(
          :FrameWithMarginBox,
          _("New Partition Type"),
          RadioButtonGroup(Id(:partition_type), tmp)
        )
      )

      MiniWorkflow.SetContents(
        Greasemonkey.Transform(contents),
        MiniWorkflowStepPartitionTypeHelptext()
      )
      MiniWorkflow.SetLastStep(false)

      widget = nil
      begin
        widget = MiniWorkflow.UserInput

        case widget
          when :next
            type = Convert.to_symbol(
              UI.QueryWidget(Id(:partition_type), :Value)
            )
        end
      end until widget == :abort || widget == :back || widget == :next

      if widget == :next
        Ops.set(data.value, "type", type)

        # get the largest slot of type
        slot = data.value["slots"][type][0]

        data.value["device"] = slot[:device]

        if Builtins.haskey(data.value, "disk_udev_id")
          Ops.set(
            data.value,
            "udev_id",
            Builtins.maplist(Ops.get_list(data.value, "disk_udev_id", [])) do |s|
              "#{s}-part#{slot[:nr]}"
            end
          )
        end

        if Builtins.haskey(data.value, "disk_udev_path")
          Ops.set(
            data.value,
            "udev_path",
            Builtins.sformat(
              "%1-part%2",
              Ops.get_string(data.value, "disk_udev_path", ""),
              slot[:nr]
            )
          )
        end

        if Ops.get_symbol(data.value, "type", :unknown) == :extended
          Ops.set(data.value, "fsid", Partitions.fsid_extended_win)
          Ops.set(data.value, "used_fs", :unknown)
        end
      end

      log.info("MiniWorkflowStepPartitionType data:#{data.value} ret:#{widget}")

      return widget
    end


    def MiniWorkflowStepPartitionSizeHelptext
      # helptext
      helptext = _("<p>Choose the size for the new partition.</p>")

      helptext
    end


    def MiniWorkflowStepPartitionSize(data)

      log.info("MiniWorkflowStepPartitionSize data:#{data.value}")

      cyl_size = Ops.get_integer(data.value, "cyl_size", 0)
      cyl_count = Ops.get_integer(data.value, "cyl_count", 0)

      type = data.value["type"]

      slots = data.value["slots"][type]

      # get the largest slot
      slot = slots[0]

      region = Convert.convert(
        Ops.get(data.value, "region", slot[:region]),
        :from => "any",
        :to   => "list <integer>"
      )
      size_k = Ops.divide(Ops.multiply(Ops.get(region, 1, 0), cyl_size), 1024)

      min_num_cyl = 1
      max_num_cyl = slot[:region][1]

      min_size_k = Builtins.tointeger(
        Ops.divide(
          Convert.convert(
            Ops.multiply(min_num_cyl, cyl_size),
            :from => "integer",
            :to   => "float"
          ),
          1024.0
        )
      )
      max_size_k = Builtins.tointeger(
        Ops.divide(
          Convert.convert(
            Ops.multiply(max_num_cyl, cyl_size),
            :from => "integer",
            :to   => "float"
          ),
          1024.0
        )
      )

      type = Ops.get_symbol(data.value, "type", :unknown)
      what = :nothing # ;-)

      #prefer max size for extended partition (#428337)
      #cascaded triple operators would do, but this is more readable
      if region == slot[:region]
        what = type == :extended ? :max_size : :manual_size
      else
        what = :manual_region
      end

      contents = HVSquash(
        # frame heading
        term(
          :FrameWithMarginBox,
          _("New Partition Size"),
          RadioButtonGroup(
            Id(:size),
            VBox(
              term(
                :LeftRadioButton,
                Id(:max_size),
                Opt(:notify),
                # radio button text, %1 is replaced by size
                Builtins.sformat(
                  _("Maximum Size (%1)"),
                  Storage.KByteToHumanString(max_size_k)
                )
              ),
              # radio button text
              term(
                :LeftRadioButtonWithAttachment,
                Id(:manual_size),
                Opt(:notify),
                _("Custom Size"),
                VBox(
                  Id(:manual_size_attachment),
                  MinWidth(
                    15,
                    InputField(Id(:size_input), Opt(:shrinkable), _("Size"))
                  )
                )
              ),
              # radio button text
              term(
                :LeftRadioButtonWithAttachment,
                Id(:manual_region),
                Opt(:notify),
                _("Custom Region"),
                VBox(
                  Id(:manual_region_attachment),
                  MinWidth(
                    10,
                    IntField(
                      Id(:start_cyl),
                      _("Start Cylinder"),
                      0,
                      cyl_count,
                      Region.Start(region)
                    )
                  ),
                  MinWidth(
                    10,
                    IntField(
                      Id(:end_cyl),
                      _("End Cylinder"),
                      0,
                      cyl_count,
                      Region.End(region)
                    )
                  )
                )
              )
            )
          )
        )
      )

      MiniWorkflow.SetContents(
        Greasemonkey.Transform(contents),
        MiniWorkflowStepPartitionSizeHelptext()
      )
      MiniWorkflow.SetLastStep(type == :extended)

      UI.ChangeWidget(Id(:size), :Value, what)
      UI.SetFocus(
        what == :extended ?
          Id(:max_size) :
          what == :manual_size ? Id(:size_input) : Id(:manual_region)
      )
      UI.ChangeWidget(
        Id(:manual_size_attachment),
        :Enabled,
        what == :manual_size
      )
      UI.ChangeWidget(
        Id(:size_input),
        :Value,
        Storage.KByteToHumanString(size_k)
      )
      UI.ChangeWidget(
        Id(:manual_region_attachment),
        :Enabled,
        what == :manual_region
      )

      widget = nil
      begin
        widget = MiniWorkflow.UserInput

        case widget
          when :max_size
            UI.ChangeWidget(Id(:manual_size_attachment), :Enabled, false)
            UI.ChangeWidget(Id(:manual_region_attachment), :Enabled, false)
          when :manual_size
            UI.ChangeWidget(Id(:manual_size_attachment), :Enabled, true)
            UI.ChangeWidget(Id(:manual_region_attachment), :Enabled, false)
            UI.SetFocus(Id(:size_input))
          when :manual_region
            UI.ChangeWidget(Id(:manual_size_attachment), :Enabled, false)
            UI.ChangeWidget(Id(:manual_region_attachment), :Enabled, true)
            UI.SetFocus(Id(:end_cyl)) # or `start_cyl, who cares
          when :next
            what = Convert.to_symbol(UI.QueryWidget(Id(:size), :Value))

            case what
              when :manual_size
                tmp = Convert.to_string(UI.QueryWidget(Id(:size_input), :Value))
                if !(
                    size_k_ref = arg_ref(size_k);
                    _HumanStringToKByteWithRangeCheck_result = Storage.HumanStringToKByteWithRangeCheck(
                      tmp,
                      size_k_ref,
                      min_size_k,
                      max_size_k
                    );
                    size_k = size_k_ref.value;
                    _HumanStringToKByteWithRangeCheck_result
                  )
                  # error popup, %1 and %2 are replaced by sizes
                  Popup.Error(
                    Builtins.sformat(
                      _(
                        "The size entered is invalid. Enter a size between %1 and %2."
                      ),
                      Storage.KByteToHumanString(min_size_k),
                      Storage.KByteToHumanString(max_size_k)
                    )
                  )
                  UI.SetFocus(Id(:size_input))
                  widget = :again
                  next
                end
              when :manual_region
                s = Convert.to_integer(UI.QueryWidget(Id(:start_cyl), :Value))
                e = Convert.to_integer(UI.QueryWidget(Id(:end_cyl), :Value))
                region = [s, Ops.add(Ops.subtract(e, s), 1)]

                valid = Ops.greater_than(Region.Length(region), 0) &&
                  Builtins.find(slots) { |slot2| Region.Inside(slot2[:region], region) } != nil

                if !valid
                  # error popup
                  Popup.Error(_("The region entered is invalid."))
                  UI.SetFocus(Id(:end_cyl))
                  widget = :again
                  next
                end
            end
        end
      end until widget == :abort || widget == :back || widget == :next

      if widget == :next
        case Convert.to_symbol(UI.QueryWidget(Id(:size), :Value))
          when :max_size
            Ops.set(data.value, "region", slot[:region])
          when :manual_size
            num_cyl = Builtins.tointeger(
              Ops.add(
                Ops.divide(
                  Ops.multiply(
                    1024.0,
                    Convert.convert(size_k, :from => "integer", :to => "float")
                  ),
                  Convert.convert(cyl_size, :from => "integer", :to => "float")
                ),
                0.5
              )
            )
            num_cyl = Integer.Clamp(num_cyl, min_num_cyl, max_num_cyl)
            Ops.set(data.value, "region", [Ops.get(slot[:region], 0, 0), num_cyl])
          when :manual_region
            Ops.set(data.value, "region", region)
        end

        Ops.set(
          data.value,
          "size_k",
          Ops.divide(
            Ops.multiply(
              Region.Length(
                Convert.convert(
                  Ops.get(data.value, "region") { [0, 0] },
                  :from => "any",
                  :to   => "list <const integer>"
                )
              ),
              cyl_size
            ),
            1024
          )
        )

        if Ops.get_symbol(data.value, "type", :unknown) == :extended
          widget = :finish
        end
      end

      log.info("MiniWorkflowStepPartitionSize data:#{data.value} ret:#{widget}")

      return widget
    end


    def DlgCreatePartition(data)
      aliases = {
        "Type"        => lambda do
          (
            data_ref = arg_ref(data.value);
            _MiniWorkflowStepPartitionType_result = MiniWorkflowStepPartitionType(
              data_ref
            );
            data.value = data_ref.value;
            _MiniWorkflowStepPartitionType_result
          )
        end,
        "Size"        => lambda do
          (
            data_ref = arg_ref(data.value);
            _MiniWorkflowStepPartitionSize_result = MiniWorkflowStepPartitionSize(
              data_ref
            );
            data.value = data_ref.value;
            _MiniWorkflowStepPartitionSize_result
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
        "Type"        => { :next => "Size" },
        "Size"        => { :next => "FormatMount", :finish => :finish },
        "FormatMount" => { :next => "Password", :finish => :finish },
        "Password"    => { :finish => :finish }
      }

      slots = Ops.get_map(data.value, "slots", {})

      if Builtins.haskey(slots, :primary)
        Ops.set(data.value, "type", :primary)
      elsif Builtins.haskey(slots, :extended)
        Ops.set(data.value, "type", :extended)
      elsif Builtins.haskey(slots, :logical)
        Ops.set(data.value, "type", :logical)
      end

      start = Builtins.size(slots) == 1 ? "Size" : "Type"

      if start == "Size"

        # get the largest slot of type
        type = data.value["type"]
        slot = data.value["slots"][type][0]

        data.value["device"] = slot[:device]

        if Builtins.haskey(data.value, "disk_udev_id")
          Ops.set(
            data.value,
            "udev_id",
            Builtins.maplist(Ops.get_list(data.value, "disk_udev_id", [])) do |s|
              "#{s}-part#{slot[:nr]}"
            end
          )
        end

        if Builtins.haskey(data.value, "disk_udev_path")
          Ops.set(
            data.value,
            "udev_path",
            Builtins.sformat(
              "%1-part%2",
              Ops.get_string(data.value, "disk_udev_path", ""),
              slot[:nr]
            )
          )
        end
      end

      # dialog title
      title = Builtins.sformat(
        _("Add Partition on %1"),
        Ops.get_string(data.value, "disk_device", "error")
      )

      widget = MiniWorkflow.Run(
        title,
        StorageIcons.hd_part_icon,
        aliases,
        sequence,
        start
      )

      widget == :finish
    end


    def DlgEditPartition(data)
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
      title = Builtins.sformat(_("Edit Partition %1"), device)

      widget = MiniWorkflow.Run(
        title,
        StorageIcons.hd_part_icon,
        aliases,
        sequence,
        "FormatMount"
      )

      widget == :finish
    end


    def DlgMovePartition(part)
      device = Ops.get_string(part.value, "device", "error")

      free_cyl_before = 0
      free_cyl_after = 0

      free_cyl_before_ref = arg_ref(free_cyl_before)
      free_cyl_after_ref = arg_ref(free_cyl_after)
      Storage.FreeCylindersAroundPartition(
        device,
        free_cyl_before_ref,
        free_cyl_after_ref
      )
      free_cyl_before = free_cyl_before_ref.value
      free_cyl_after = free_cyl_after_ref.value

      if free_cyl_before == 0 && free_cyl_after == 0
        # error popup text, %1 is replace with name of partition
        Popup.Error(
          Builtins.sformat(_("No space to moved partition %1."), device)
        )
        return false
      end

      move = 0

      if Ops.greater_than(free_cyl_before, 0) && free_cyl_after == 0
        # popup text, %1 is replace with name of partition
        if !Popup.YesNo(
            Builtins.sformat(_("Move partition %1 forward?"), device)
          )
          return false
        end

        move = Ops.unary_minus(free_cyl_before)
      elsif free_cyl_before == 0 && Ops.greater_than(free_cyl_after, 0)
        # popup text, %1 is replace with name of partition
        if !Popup.YesNo(
            Builtins.sformat(_("Move partition %1 backward?"), device)
          )
          return false
        end

        move = free_cyl_after
      elsif Ops.greater_than(free_cyl_before, 0) &&
          Ops.greater_than(free_cyl_after, 0)
        UI.OpenDialog(
          Opt(:decorated),
          Greasemonkey.Transform(
            VBox(
              MarginBox(
                2,
                0.4,
                RadioButtonGroup(
                  Id(:directions),
                  VBox(
                    # popup text, %1 is replace with name of partition
                    Label(Builtins.sformat(_("Move partition %1?"), device)),
                    # radio button text
                    term(:LeftRadioButton, Id(:forward), _("Forward"), true),
                    # radio button text
                    term(:LeftRadioButton, Id(:backward), _("Backward"))
                  )
                )
              ),
              ButtonBox(
                PushButton(Id(:cancel), Opt(:cancelButton), Label.CancelButton),
                PushButton(Id(:ok), Opt(:default, :okButton), Label.OKButton)
              )
            )
          )
        )

        widget = Convert.to_symbol(UI.UserInput)

        direction = Convert.to_symbol(UI.QueryWidget(Id(:directions), :Value))

        UI.CloseDialog

        return false if widget != :ok

        case direction
          when :forward
            move = Ops.unary_minus(free_cyl_before)
          when :backward
            move = free_cyl_after
        end
      end

      return false if move == 0

      Ops.set(
        part.value,
        ["region", 0],
        Ops.add(Ops.get_integer(part.value, ["region", 0], 0), move)
      )
      Builtins.y2milestone("part:%1", part.value)
      true
    end


    def DlgResizePartition(data, disk)
      disk = deep_copy(disk)
      (
        data_ref = arg_ref(data.value);
        _DlgResize_result = DlgResize(data_ref, disk);
        data.value = data_ref.value;
        _DlgResize_result
      )
    end


    def ConfirmPartitionsDelete(disk, pnames)
      pnames = deep_copy(pnames)
      ConfirmRecursiveDelete(
        disk,
        pnames,
        _("Confirm Deleting of All Partitions"),
        Builtins.sformat(
          _(
            "The disk \"%1\" contains at least one partition.\nIf you proceed, the following partitions will be deleted:"
          ),
          disk
        ),
        Builtins.sformat(_("Really delete all partitions on \"%1\"?"), disk)
      )
    end


  end
end
