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
  module PartitioningEpLvmDialogsInclude
    def initialize_partitioning_ep_lvm_dialogs(include_target)
      textdomain "storage"

      Yast.include include_target, "partitioning/ep-lib.rb"
    end

    def CheckVgName(name)
      ret = true
      allowed_chars = "0123456789" + "ABCDEFGHIJKLMNOPQRSTUVWXYZ" +
        "abcdefghijklmnopqrstuvwxyz" + "._-+"

      if Builtins.size(name) == 0
        # error popup text
        Popup.Error(_("Enter a name for the volume group."))
        ret = false
      elsif Ops.greater_than(Builtins.size(name), 128)
        # error popup text
        Popup.Error(
          _("The name for the volume group is longer than 128 characters.")
        )
        ret = false
      elsif Builtins.substring(name, 0, 1) == "-"
        # error popup text
        Popup.Error(
          _("The name for the volume group must not start with a \"-\".")
        )
        ret = false
      elsif Builtins.findfirstnotof(name, allowed_chars) != nil
        # error popup text
        Popup.Error(
          _(
            "The name for the volume group contains illegal characters. Allowed\nare alphanumeric characters, \".\", \"_\", \"-\" and \"+\"."
          )
        )
        ret = false
      end
      UI.SetFocus(Id(:vgname)) if !ret

      ret
    end


    def CheckVgNameConflict(name, vgs)
      vgs = deep_copy(vgs)
      ret = true
      if Builtins.contains(vgs, name)
        # error popup text
        Popup.Error(
          Builtins.sformat(_("The volume group \"%1\" already exists."), name)
        )
        ret = false
      end

      if !check_vgname_dev(name)
        # error popup text
        Popup.Error(
          Builtins.sformat(
            _(
              "The volume group name \"%1\" conflicts\nwith another entry in the /dev directory.\n"
            ),
            name
          )
        )
        ret = false
      end

      UI.SetFocus(Id(:vgname)) if !ret

      ret
    end


    def ConfirmVgDelete(vgname, log_volumes)
      log_volumes = deep_copy(log_volumes)
      ConfirmRecursiveDelete(
        vgname,
        log_volumes,
        #pop-up dialog title
        _("Confirm Deleting of Volume Group"),
        #pop-up dialog message part 1: %1 is vol.group name
        Builtins.sformat(
          _(
            "The volume group \"%1\" contains at least one logical volume.\n" +
              "If you proceed, the following volumes will be unmounted (if mounted)\n" +
              "and deleted:"
          ),
          vgname
        ),
        #pop-up dialog message part 2: %1 is vol.group name
        Builtins.sformat(
          _(
            "Really delete volume group \"%1\" and all related logical volumes?"
          ),
          vgname
        )
      )
    end


    def CheckPeSize(pe_size)
      if !Integer.IsPowerOfTwo(pe_size) || Ops.less_than(pe_size, 1024)
        # error popup, %1, %2 and %3 are replaced by sizes
        Popup.Error(
          Builtins.sformat(
            _(
              "The data entered is invalid. Insert a physical extent size larger than %1\nin powers of 2, for example, \"%2\" or \"%3\""
            ),
            Storage.KByteToHumanStringOmitZeroes(1),
            Storage.KByteToHumanStringOmitZeroes(4),
            Storage.KByteToHumanStringOmitZeroes(4 * 1024)
          )
        )
        UI.SetFocus(Id(:pesize))
        return false
      else
        return true
      end
    end


    def CheckNumberOfDevicesForVg(num)
      if Ops.less_than(num, 1)
        # error popup
        Popup.Error(Builtins.sformat(_("Select at least one device.")))
        UI.SetFocus(Id(:unselected))
        return false
      else
        return true
      end
    end


    def CheckLvName(lv_name)
      ret = true
      allowed_chars = "0123456789" + "ABCDEFGHIJKLMNOPQRSTUVWXYZ" +
        "abcdefghijklmnopqrstuvwxyz" + "._-+"

      if Builtins.size(lv_name) == 0
        # error popup text
        Popup.Error(_("Enter a name for the logical volume."))
        ret = false
      elsif Ops.greater_than(Builtins.size(lv_name), 128)
        # error popup text
        Popup.Error(
          _("The name for the logical volume is longer than 128 characters.")
        )
        ret = false
      elsif Builtins.findfirstnotof(lv_name, allowed_chars) != nil
        # error popup text
        Popup.Error(
          _(
            "The name for the logical volume contains illegal characters. Allowed\nare alphanumeric characters, \".\", \"_\", \"-\" and \"+\"."
          )
        )
        ret = false
      end

      UI.SetFocus(Id(:lvname)) if !ret

      ret
    end


    def CheckLvNameConflict(lv_name, vg_name, lvs)
      lvs = deep_copy(lvs)
      if Builtins.contains(lvs, lv_name)
        # error popup text
        Popup.Error(
          Builtins.sformat(
            _(
              "A logical volume named \"%1\" already exists\nin volume group \"%2\"."
            ),
            lv_name,
            vg_name
          )
        )
        UI.SetFocus(Id(:lvname))
        return false
      end

      true
    end


    def ComputePoolMetadataSize(siz, pesize)
      chunk = 64
      metasize = Ops.divide(Ops.divide(siz, chunk), 1024 / 64)
      metasize = 2 * 1024 if Ops.less_than(metasize, 2 * 1024)
      while Ops.less_or_equal(chunk, 1048576) &&
          Ops.greater_than(metasize, 128 * 1024)
        chunk = Ops.multiply(chunk, 2)
        metasize = Ops.divide(metasize, 2)
      end
      pe_k = Ops.divide(pesize, 1024)
      metasize = Ops.multiply(
        Ops.divide(Ops.subtract(Ops.add(metasize, pe_k), 1), pe_k),
        pe_k
      )
      Builtins.y2milestone(
        "ComputePoolMetadataSize size:%1 pe:%2 chunk:%3 ret:%4",
        siz,
        pe_k,
        chunk,
        metasize
      )
      metasize
    end

    def MiniWorkflowStepVgHelptext
      # helptext
      helptext = _(
        "<p>Enter the name and physical extent size of the new volume group.</p>"
      )

      # helptext
      helptext = Ops.add(
        helptext,
        _("<p>Select the physical volumes the volume group should contain.</p>")
      )

      helptext
    end


    def MiniWorkflowStepVg(data)
      Builtins.y2milestone("MiniWorkflowStepVg data:%1", data.value)

      target_map = Storage.GetTargetMap

      vgs = get_vgs(target_map)

      vgname = Builtins.size(vgs) == 0 ? "system" : ""
      pesize = 4 * 1024 * 1024
      pvs = []

      fields = StorageSettings.FilterTable(
        [:device, :udev_path, :udev_id, :size, :encrypted, :type]
      )

      unused_pvs = Builtins.filter(get_possible_pvs(target_map)) do |pv|
        !Storage.IsUsedBy(pv)
      end

      contents = VBox()

      pesizes_list = Builtins.maplist(Integer.RangeFrom(19, 26)) do |i|
        Item(
          Id(Ops.shift_left(2, i)),
          Storage.ByteToHumanStringOmitZeroes(Ops.shift_left(2, i))
        )
      end

      # label for input field
      contents = Builtins.add(
        contents,
        Left(InputField(Id(:vgname), _("Volume Group Name")))
      )
      contents = Builtins.add(
        contents,
        Left(
          term(
            :ComboBoxSelected,
            Id(:pesize),
            Opt(:editable),
            # label for combo box
            _("&Physical Extent Size"),
            pesizes_list,
            Id(pesize)
          )
        )
      )

      contents = Builtins.add(
        contents,
        DevicesSelectionBox.Create(
          unused_pvs,
          [],
          fields,
          nil,
          # label for selection box
          _("Available Physical Volumes:"),
          # label for selection box
          _("Selected Physical Volumes:"),
          false
        )
      )

      MiniWorkflow.SetContents(
        Greasemonkey.Transform(contents),
        MiniWorkflowStepVgHelptext()
      )
      MiniWorkflow.SetLastStep(true)
      UI.SetFocus(Id(:vgname))

      widget = nil
      begin
        widget = MiniWorkflow.UserInput
        DevicesSelectionBox.Handle(widget)

        case widget
          when :next
            vgname = Convert.to_string(UI.QueryWidget(Id(:vgname), :Value))

            tmp = UI.QueryWidget(Id(:pesize), :Value)
            if Ops.is_integer?(tmp)
              pesize = Convert.to_integer(tmp)
            elsif !(
                pesize_ref = arg_ref(pesize);
                _HumanStringToByte_result = Storage.HumanStringToByte(
                  Convert.to_string(tmp),
                  pesize_ref
                );
                pesize = pesize_ref.value;
                _HumanStringToByte_result
              )
              pesize = 0
            end # will trigger error below

            pvs = Builtins.maplist(DevicesSelectionBox.GetSelectedDevices) do |pv|
              Ops.get_string(pv, "device", "")
            end

            if !CheckVgName(vgname) || !CheckVgNameConflict(vgname, vgs) ||
                !CheckPeSize(pesize) ||
                !CheckNumberOfDevicesForVg(Builtins.size(pvs))
              widget = :again
            end
        end
      end until widget == :abort || widget == :back || widget == :next

      if widget == :next
        Ops.set(data.value, "name", vgname)
        Ops.set(data.value, "pesize", pesize)
        Ops.set(data.value, "devices", pvs)

        widget = :finish
      end

      Builtins.y2milestone(
        "MiniWorkflowStepVg data:%1 ret:%2",
        data.value,
        widget
      )

      widget
    end


    def MiniWorkflowStepResizeVgHelptext
      # helptext
      helptext = _(
        "<p>Change the devices that are used for the volume group.</p>"
      )

      helptext
    end


    def MiniWorkflowStepResizeVg(data)
      Builtins.y2milestone("MiniWorkflowStepResizeVg data:%1", data.value)

      vgname = Ops.get_string(data.value, "name", "error")
      pvs_new = []

      fields = StorageSettings.FilterTable(
        [:device, :udev_path, :udev_id, :size, :encrypted, :type]
      )

      target_map = Storage.GetTargetMap
      unused_pvs = Builtins.filter(get_possible_pvs(target_map)) do |pv|
        !Storage.IsUsedBy(pv)
      end
      used_pvs = Builtins.filter(get_possible_pvs(target_map)) do |pv|
        Ops.get_string(pv, "used_by_device", "") == Ops.add("/dev/", vgname)
      end

      contents = VBox()

      contents = Builtins.add(
        contents,
        DevicesSelectionBox.Create(
          unused_pvs,
          used_pvs,
          fields,
          nil,
          _("Available Physical Volumes:"),
          _("Selected Physical Volumes:"),
          false
        )
      )

      MiniWorkflow.SetContents(
        Greasemonkey.Transform(contents),
        MiniWorkflowStepResizeVgHelptext()
      )
      MiniWorkflow.SetLastStep(true)

      widget = nil
      begin
        widget = MiniWorkflow.UserInput
        DevicesSelectionBox.Handle(widget)

        case widget
          when :next
            pvs_new = Builtins.maplist(DevicesSelectionBox.GetSelectedDevices) do |pv|
              Ops.get_string(pv, "device", "")
            end

            if !CheckNumberOfDevicesForVg(Builtins.size(pvs_new))
              widget = :again
            end

            # TODO: overall size check
        end
      end until widget == :abort || widget == :back || widget == :next

      if widget == :next
        Ops.set(data.value, "devices_new", pvs_new)

        widget = :finish
      end

      Builtins.y2milestone(
        "MiniWorkflowStepResizeVg data:%1 ret:%2",
        data.value,
        widget
      )

      widget
    end


    def DlgCreateVolumeGroupNew(data)
      aliases = {
        "TheOne" => lambda do
        (
          data_ref = arg_ref(data.value);
          _MiniWorkflowStepVg_result = MiniWorkflowStepVg(data_ref);
          data.value = data_ref.value;
          _MiniWorkflowStepVg_result
        )
        end
      }

      sequence = { "TheOne" => { :finish => :finish } }

      # dialog title
      title = _("Add Volume Group")

      widget = MiniWorkflow.Run(
        title,
        StorageIcons.lvm_icon,
        aliases,
        sequence,
        "TheOne"
      )

      widget == :finish
    end


    def MiniWorkflowStepLvSizeHelptext
      # helptext
      helptext = _(
        "<p>Enter the size as well as the number and size\n" +
          "of stripes for the new logical volume. The number of stripes cannot be higher\n" +
          "than the number of physical volumes of the volume group.</p>"
      )

      # helptext
      helptext = Ops.add(
        helptext,
        _(
          "<p>So called <b>Thin Volumes</b> can created\n" +
            "with arbitrary volume size. The space required is taken on demand from the \n" +
            "assigned <b>Thin Pool</b>. So one can create Thin Volume of a size larger\n" +
            "than the Thin Pool. Of course when there is really data written to a Thin\n" +
            "Volume, the assigned Thin Pool must be able to meet this space requirement.\n" +
            "Thin Volumes cannot have a Stripe Count."
        )
      )

      helptext
    end


    def MiniWorkflowStepLvSize(data)
      Builtins.y2milestone("MiniWorkflowStepLvSize data:%1", data.value)

      min_size_k = Ops.divide(Ops.get_integer(data.value, "pesize", 0), 1024)
      max_size_k = Ops.get_integer(data.value, "max_size_k", 0)
      thin = !Builtins.isempty(Ops.get_string(data.value, "used_pool", ""))
      pool = Ops.get_boolean(data.value, "pool", false)
      if pool
        max_size_k = Ops.subtract(
          max_size_k,
          ComputePoolMetadataSize(
            Ops.get_integer(data.value, "max_size_k", 0),
            Ops.get_integer(data.value, "pesize", 0)
          )
        )
      end
      size_k = Ops.get_integer(data.value, "size_k", max_size_k)

      what = size_k == max_size_k ? :max_size : :manual_size
      name = Ops.get_string(data.value, "name", "")
      max_s = Builtins.sformat(
        _("Maximum Size (%1)"),
        Storage.KByteToHumanString(max_size_k)
      )
      if thin
        what = :manual_size
        max_size_k = 1024 * 1024 * 1024 * 1024 * 1024
        size_k = 2 * 1024 * 1024
        pos = Builtins.search(max_s, "(")
        max_s = Builtins.substring(max_s, 0, pos) if pos != nil
      end

      max_stripes = Ops.get_integer(data.value, "max_stripes", 1)
      stripes = Ops.get_integer(data.value, "stripes", 1)
      stripe_size = Ops.multiply(
        Ops.get_integer(data.value, "stripesize", 64),
        1024
      )

      frames = term(:VStackFrames)

      frames = Builtins.add(
        frames,
        term(
          :FrameWithMarginBox,
          _("Size"),
          RadioButtonGroup(
            Id(:size),
            VBox(
              term(:LeftRadioButton, Id(:max_size), Opt(:notify), max_s),
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
              )
            )
          )
        )
      )

      stripes_list = Builtins.maplist(
        Integer.RangeFrom(1, Ops.add(max_stripes, 1))
      ) { |i| Item(Id(i), Builtins.tostring(i)) }

      stripe_sizes_list = Builtins.maplist(Integer.RangeFrom(11, 20)) do |i|
        Item(
          Id(Ops.shift_left(2, i)),
          Storage.ByteToHumanStringOmitZeroes(Ops.shift_left(2, i))
        )
      end

      # heading for frame
      frames = Builtins.add(
        frames,
        term(
          :FrameWithMarginBox,
          _("Stripes"),
          HBox(
            # combo box label
            Left(
              term(
                :ComboBoxSelected,
                Id(:stripes),
                Opt(:notify),
                _("Number"),
                stripes_list,
                Id(stripes)
              )
            ),
            # combo box label
            Left(
              term(
                :ComboBoxSelected,
                Id(:stripe_size),
                _("Size"),
                stripe_sizes_list,
                Id(stripe_size)
              )
            ),
            HStretch()
          )
        )
      )

      contents = HVSquash(frames)

      #A dialog title - %1 is a logical volume name, %2 is a volume group.
      MiniWorkflow.SetTitle(
        Builtins.sformat(
          _("Add Logical volume %1 on %2"),
          name,
          Ops.add("/dev/", Ops.get_string(data.value, "vg_name", "error"))
        )
      )
      MiniWorkflow.SetContents(
        Greasemonkey.Transform(contents),
        MiniWorkflowStepLvSizeHelptext()
      )
      MiniWorkflow.SetLastStep(false)

      UI.ChangeWidget(Id(:size), :Value, what)
      UI.ChangeWidget(Id(:max_size), :Enabled, !thin)
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
      UI.ChangeWidget(Id(:stripes), :Enabled, !thin)
      UI.ChangeWidget(Id(:stripe_size), :Enabled, Ops.greater_than(stripes, 1))

      widget = nil
      begin
        widget = MiniWorkflow.UserInput

        case widget
          when :max_size
            UI.ChangeWidget(Id(:manual_size_attachment), :Enabled, false)
          when :manual_size
            UI.ChangeWidget(Id(:manual_size_attachment), :Enabled, true)
            UI.SetFocus(Id(:size_input))
          when :stripes
            stripes = Convert.to_integer(UI.QueryWidget(Id(:stripes), :Value))
            UI.ChangeWidget(
              Id(:stripe_size),
              :Enabled,
              Ops.greater_than(stripes, 1)
            )
          when :next
            what = Convert.to_symbol(UI.QueryWidget(Id(:size), :Value))

            if what == :manual_size
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
                Popup.Error(
                  Builtins.sformat(
                    _(
                      "The size entered is invalid. Enter a size between %1 and %2."
                    ),
                    Storage.KByteToHumanString(min_size_k),
                    Storage.KByteToHumanString(max_size_k)
                  )
                )
                widget = :again
              end
            end

            stripes = Convert.to_integer(UI.QueryWidget(Id(:stripes), :Value))
            stripe_size = Convert.to_integer(
              UI.QueryWidget(Id(:stripe_size), :Value)
            )
        end
      end until widget == :abort || widget == :back || widget == :next

      if widget == :next
        case what
          when :max_size
            Ops.set(data.value, "size_k", max_size_k)
          when :manual_size
            Ops.set(data.value, "size_k", size_k)
        end

        Ops.set(data.value, "stripes", stripes)
        Ops.set(data.value, "stripesize", Ops.divide(stripe_size, 1024))

        widget = :finish if Ops.get_boolean(data.value, "pool", false)
      end

      Builtins.y2milestone(
        "MiniWorkflowStepLvSize data:%1 ret:%2",
        data.value,
        widget
      )

      widget
    end


    def DlgResizeVolumeGroup(data, _Commit)
      _Commit = deep_copy(_Commit)

      aliases = {
        "TheOne" => lambda do
        (
          data_ref = arg_ref(data.value);
          _MiniWorkflowStepResizeVg_result = MiniWorkflowStepResizeVg(data_ref);
          data.value = data_ref.value;
          _MiniWorkflowStepResizeVg_result
        )
        end,
        "Commit" => lambda { _Commit.call(data.value) }
      }

      sequence = {
        "TheOne" => { :finish => "Commit" },
        "Commit" => { :finish => :finish }
      }

      # dialog title
      title = Builtins.sformat(
        _("Resize Volume Group %1"),
        Ops.get_string(data.value, "device", "error")
      )

      widget = MiniWorkflow.Run(
        title,
        StorageIcons.lvm_icon,
        aliases,
        sequence,
        "TheOne"
      )

      widget == :finish
    end


    def MiniWorkflowStepLvNameHelptext
      # helptext
      helptext = _("<p>Enter the name of the new logical volume.</p>")
      # helptext
      helptext = Ops.add(
        helptext,
        _(
          "<p>You can declare the logical volume as a <b>Normal Volume</b>.\n" +
            "This is the default and means plain LVM Volumes like all volumes were before the feature of <b>Thin Provisioning</b> existed.\n" +
            "If in doubt this is most probably the right choice</p>"
        )
      )
      # helptext
      helptext = Ops.add(
        helptext,
        _(
          "<p>You can declare the logical volume as a <b>Thin Pool</b>.\nThis means <b>Thin Volumes</b> allocate their needed space on demand from such a pool.</p>"
        )
      )
      # helptext
      helptext = Ops.add(
        helptext,
        _(
          "<p>You can declare the logical volume as a <b>Thin Volume</b>.\nThis means the volume allocates needed space on demand from a <b>Thin Pool</b>.</p>"
        )
      )

      helptext
    end


    def MiniWorkflowStepLvName(data)
      Builtins.y2milestone("MiniWorkflowStepLvName data:%1", data.value)

      target_map = Storage.GetTargetMap

      vg_name = Ops.get_string(data.value, "vg_name", "error")
      vg_key = Ops.add("/dev/", vg_name)

      lvs = get_lv_names(target_map, vg_name)
      pools = Builtins.maplist(
        Builtins.filter(Ops.get_list(target_map, [vg_key, "partitions"], [])) do |p|
          Ops.get_boolean(p, "pool", false)
        end
      ) { |l| Ops.get_string(l, "name", "") }

      lv_name = Ops.get_string(data.value, "name", "")

      frames = term(:VStackFrames)

      # heading for frame
      frames = Builtins.add(
        frames,
        term(
          :FrameWithMarginBox,
          _("Name"),
          VBox(Left(InputField(Id(:lvname), _("Logical Volume"), lv_name)))
        )
      )

      pool_list = Builtins.maplist(pools) { |n| Item(Id(n), n) }

      frames = Builtins.add(
        frames,
        # heading for frame
        term(
          :FrameWithMarginBox,
          _("Type"),
          RadioButtonGroup(
            Id(:type),
            VBox(
              # radio button label
              term(
                :LeftRadioButton,
                Id(:normal),
                Opt(:notify),
                _("Normal Volume")
              ),
              # radio button label
              term(:LeftRadioButton, Id(:pool), Opt(:notify), _("Thin Pool")),
              # radio button label
              term(
                :LeftRadioButtonWithAttachment,
                Id(:thin),
                Opt(:notify),
                _("Thin Volume"),
                VBox(
                  Left(
                    term(
                      :ComboBoxSelected,
                      Id(:used_pool),
                      Opt(:notify),
                      # combo box label
                      _("Used Pool"),
                      pool_list,
                      Id(:used_pool)
                    )
                  )
                )
              )
            )
          )
        )
      )

      contents = HVSquash(frames)

      MiniWorkflow.SetContents(
        Greasemonkey.Transform(contents),
        MiniWorkflowStepLvNameHelptext()
      )
      MiniWorkflow.SetLastStep(false)
      UI.SetFocus(Id(:lvname))
      used_enab = false
      if Ops.get_boolean(data.value, "pool", false)
        ChangeWidgetIfExists(:pool, :Value, true)
      elsif !Builtins.isempty(Ops.get_string(data.value, "used_pool", "")) ||
          Ops.get_integer(data.value, "max_size_k", 0) == 0
        ChangeWidgetIfExists(:thin, :Value, true)
        if !Builtins.isempty(Ops.get_string(data.value, "used_pool", ""))
          ChangeWidgetIfExists(
            :used_pool,
            :Value,
            Ops.get_string(data.value, "used_pool", "")
          )
        end
        used_enab = true
      elsif Ops.greater_than(Ops.get_integer(data.value, "max_size_k", 0), 0)
        ChangeWidgetIfExists(:normal, :Value, true)
      end
      if Ops.get_integer(data.value, "max_size_k", 0) == 0
        ChangeWidgetIfExists(:normal, :Enabled, false)
        ChangeWidgetIfExists(:pool, :Enabled, false)
      end
      ChangeWidgetIfExists(:used_pool, :Enabled, used_enab)

      widget = nil
      begin
        widget = MiniWorkflow.UserInput

        case widget
          when :normal, :pool, :thin
            UI.ChangeWidget(Id(:used_pool), :Enabled, widget == :thin)
          when :next
            lv_name = Convert.to_string(UI.QueryWidget(Id(:lvname), :Value))

            if !CheckLvName(lv_name) ||
                !CheckLvNameConflict(lv_name, vg_name, lvs)
              widget = :again
            end
        end
      end until widget == :abort || widget == :back || widget == :next

      if widget == :next
        Ops.set(data.value, "name", lv_name)

        # ChangeVolumeProperties and thus addLogicalVolume need the device
        Ops.set(
          data.value,
          "device",
          Ops.add(
            Ops.add(Ops.add("/dev/", vg_name), "/"),
            Ops.get_string(data.value, "name", "")
          )
        )
        if Builtins.haskey(data.value, "used_pool")
          data.value = Builtins.remove(data.value, "used_pool")
        end
        if Builtins.haskey(data.value, "pool")
          data.value = Builtins.remove(data.value, "pool")
        end
        if Convert.to_boolean(UI.QueryWidget(Id(:pool), :Value))
          Ops.set(data.value, "pool", true)
        end
        if Convert.to_boolean(UI.QueryWidget(Id(:thin), :Value))
          Ops.set(
            data.value,
            "used_pool",
            UI.QueryWidget(Id(:used_pool), :Value)
          )
        end
      end

      Builtins.y2milestone(
        "MiniWorkflowStepLvName data:%1 ret:%2",
        data.value,
        widget
      )

      widget
    end


    def DlgCreateLogicalVolume(data, _Commit)
      _Commit = deep_copy(_Commit)
      aliases = {
        "Name"        => lambda do
          (
            data_ref = arg_ref(data.value);
            _MiniWorkflowStepLvName_result = MiniWorkflowStepLvName(data_ref);
            data.value = data_ref.value;
            _MiniWorkflowStepLvName_result
          )
        end,
        "Size"        => lambda do
          (
            data_ref = arg_ref(data.value);
            _MiniWorkflowStepLvSize_result = MiniWorkflowStepLvSize(data_ref);
            data.value = data_ref.value;
            _MiniWorkflowStepLvSize_result
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
        end,
        "Commit"      => lambda { _Commit.call(data.value) }
      }

      sequence = {
        "Name"        => { :next => "Size" },
        "Size"        => { :next => "FormatMount", :finish => "Commit" },
        "FormatMount" => { :next => "Password", :finish => "Commit" },
        "Password"    => { :finish => "Commit" },
        "Commit"      => { :finish => :finish }
      }

      # dialog title, %1 is a volume group
      title = Builtins.sformat(
        _("Add Logical Volume on %1"),
        Ops.add("/dev/", Ops.get_string(data.value, "vg_name", "error"))
      )

      widget = MiniWorkflow.Run(
        title,
        StorageIcons.lvm_lv_icon,
        aliases,
        sequence,
        "Name"
      )

      widget == :finish
    end


    def DlgEditLogicalVolume(data)
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

      # dialog title - %1 is a logical volume name, %2 is a volume group
      title = Builtins.sformat(
        _("Edit Logical Volume %1 on %2"),
        Ops.get_string(data.value, "name", ""),
        Builtins.regexpsub(device, "^(.*)/[^/]*$", "\\1")
      )

      widget = MiniWorkflow.Run(
        title,
        StorageIcons.lvm_lv_icon,
        aliases,
        sequence,
        "FormatMount"
      )

      widget == :finish
    end


    def DlgResizeLogicalVolumeNew(lv_data, vg_data)
      vg_data = deep_copy(vg_data)
      (
        lv_data_ref = arg_ref(lv_data.value);
        _DlgResize_result = DlgResize(lv_data_ref, vg_data);
        lv_data.value = lv_data_ref.value;
        _DlgResize_result
      )
    end
  end
end
