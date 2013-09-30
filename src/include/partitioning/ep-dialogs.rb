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
  module PartitioningEpDialogsInclude
    def initialize_partitioning_ep_dialogs(include_target)
      textdomain "storage"


      Yast.include include_target, "partitioning/ep-lib.rb"
      Yast.include include_target, "partitioning/custom_part_lib.rb"
    end

    def MiniWorkflowStepFormatMountHelptext
      # helptext
      helptext = _(
        "<p>First, choose whether the partition should be\nformatted and the desired file system type.</p>"
      )

      # helptext
      helptext = Ops.add(
        helptext,
        _(
          "<p>If you want to encrypt all data on the\n" +
            "volume, select <b>Encrypt Device</b>. Changing the encryption on an existing\n" +
            "volume will delete all data on it.</p>\n"
        )
      )

      # helptext
      helptext = Ops.add(
        helptext,
        _(
          "<p>Then, choose whether the partition should\nbe mounted and enter the mount point (/, /boot, /home, /var, etc.).</p>"
        )
      )

      helptext
    end


    def MiniWorkflowStepFormatMount(orig_data)
      data = orig_data.value
      d = Storage.GetDiskPartition(Ops.get_string(data, "device", ""))
      lbl = Ops.get_string(
        Storage.GetTargetMap,
        [Ops.get_string(d, "disk", ""), "label"],
        ""
      )
      Builtins.y2milestone(
        "MiniWorkflowStepFormatMount label:%1 data:%2",
        lbl,
        data
      )

      #retrieve all filesystems
      all_filesystems = FileSystems.GetAllFileSystems(true, true, lbl)
      if Ops.get_symbol(data, "type", :primary) == :btrfs
        # multi volume btrfs filesystem can only be formatted as btrfs
        all_filesystems = Convert.convert(
          Builtins.filter(all_filesystems) { |s, p| s == :btrfs },
          :from => "map <symbol, map>",
          :to   => "map <symbol, map <symbol, any>>"
        )
      end
      if Ops.get_symbol(data, "type", :primary) == :tmpfs
        Ops.set(all_filesystems, :tmpfs, FileSystems.GetTmpfsFilesystem)
      end

      _ProposeMountpoints = lambda do |used_fs2, current_mp|
        fs_data = Ops.get(all_filesystems, used_fs2, {})

        #not much choice for swap partitions :)
        if used_fs2 == :swap
          return Ops.get_list(fs_data, :mountpoints, [])
        else
          not_used = notUsedMountpoints(
            Storage.GetTargetMap,
            Ops.get_list(fs_data, :mountpoints, [])
          )
          return Convert.convert(
            Builtins.union([current_mp], not_used),
            :from => "list",
            :to   => "list <string>"
          )
        end
      end

      # disable Options p.b. if no fs options can be set
      # disable Encrypt box if fs doesn't support encryption
      _EnableDisableFsOpts = lambda do |used_fs2|
        fs_data = Ops.get(all_filesystems, used_fs2, {})
        ChangeWidgetIfExists(
          :fs_options,
          :Enabled,
          Ops.get_list(fs_data, :options, []) != []
        )
        ChangeWidgetIfExists(
          :crypt_fs,
          :Enabled,
          Ops.get_boolean(fs_data, :crypt, true) &&
            Ops.get_symbol(data, "used_fs", :unknown) != :btrfs &&
            !Ops.get_boolean(data, "pool", false)
        )

        nil
      end

      do_format = Ops.get_boolean(data, "format", false)
      used_fs = Ops.get_symbol(data, "used_fs", :unknown)
      default_crypt_fs = Ops.get_symbol(data, "type", :unknown) == :loop ? :luks : :none
      crypt_fs = Ops.get_symbol(data, "enc_type", default_crypt_fs) != :none
      orig_crypt_fs = crypt_fs
      mount = Ops.get_string(data, "mount", "")
      do_mount = mount != ""
      if Ops.get_symbol(data, "type", :unknown) == :loop ||
          Ops.get_symbol(data, "type", :unknown) == :tmpfs
        do_mount = true
      end


      _AskPassword = lambda do
        Builtins.y2milestone("AskPassword data:%1", data)
        ret = crypt_fs
        ret = do_format || orig_crypt_fs != crypt_fs || do_mount if ret
        if ret && !do_format
          key = Ops.get_symbol(data, "type", :unknown) != :loop ?
            Ops.get_string(data, "device", "error") :
            Ops.get_string(data, "fpath", "error")
          ret = Storage.NeedCryptPwd(key)
        end
        ret
      end

      # MiniWorkflowStepPartitionSize data:
      # 	$["create":true,
      # 	  "cyl_size":8225280,
      # 	   "device":"/dev/sda1",
      # 	   "disk_device":"/dev/sda",
      # 	   "new":true,
      # 	   "slots":$[`primary:[1, 65]],
      # 	   "type":`primary]

      #Supply some reasonable defaults for newly created partitions
      #and mark it for formatting, too
      if Ops.get_boolean(data, "new", false) &&
          !Ops.get_boolean(data, "formatmount_proposed", false)
        Ops.set(data, "formatmount_proposed", true)

        #propose new mountpoint and filesystem
        mount_point_proposal = SingleMountPointProposal()
        used_fs = Partitions.DefaultFs

        #special case for boot partition
        if mount_point_proposal == Partitions.BootMount
          used_fs = Partitions.DefaultBootFs
        end

        Ops.set(data, "format", !Ops.get_boolean(data, "pool", false))
        Ops.set(data, "fsid", Partitions.fsid_native)
        Ops.set(data, "ori_fsid", Partitions.fsid_native)
        Ops.set(data, "used_fs", used_fs)

        #set globals
        do_format = Ops.get_boolean(data, "format", false)
        mount = mount_point_proposal
        do_mount = mount != ""

        if Ops.get_symbol(data, "type", :unknown) == :loop ||
            Ops.get_symbol(data, "type", :unknown) == :tmpfs
          do_mount = true
        end
      end


      tmp1 = Empty()
      if Builtins.contains(
          [:primary, :extended, :logical],
          Ops.get_symbol(data, "type", :none)
        )
        tmp1 = VBox(
          Id(:do_not_format_attachment),
          FsidComboBox(data, FileSystems.GetAllFileSystems(true, true, lbl))
        )
      end

      fmt = Empty()
      if Ops.get_symbol(data, "type", :none) != :tmpfs
        fmt = term(
          :FrameWithMarginBox,
          _("Formatting Options"),
          RadioButtonGroup(
            Id(:format),
            VBox(
              term(
                :LeftRadioButtonWithAttachment,
                Id(:do_format),
                Opt(:notify),
                _("Format partition"),
                VBox(
                  Id(:do_format_attachment),
                  FileSystemsComboBox(data, all_filesystems)
                )
              ),
              VSpacing(0.45),
              term(
                :LeftRadioButtonWithAttachment,
                Id(:do_not_format),
                Opt(:notify),
                _("Do not format partition"),
                tmp1
              ),
              VSpacing(0.45),
              CryptButton(data)
            )
          )
        )
      end

      notmnt = Empty()
      if Ops.get_symbol(data, "type", :none) != :tmpfs
        notmnt = term(
          :LeftRadioButton,
          Id(:do_not_mount),
          Opt(:notify),
          _("Do not mount partition")
        )
      end

      subvol = ReplacePoint(
        Id(:subvol_rp),
        SubvolPart(Ops.get_symbol(data, "used_fs", :unknown) == :btrfs)
      )

      mountpoints = _ProposeMountpoints.call(used_fs, mount)

      contents = HVSquash(
        HBox(
          fmt,
          HSpacing(1),
          term(
            :VStackFrames,
            term(
              :FrameWithMarginBox,
              _("Mounting Options"),
              RadioButtonGroup(
                Id(:mount),
                VBox(
                  term(
                    :LeftRadioButtonWithAttachment,
                    Id(:do_mount),
                    Opt(:notify),
                    _("Mount partition"),
                    VBox(
                      Id(:do_mount_attachment),
                      ComboBox(
                        Id(:mount_point),
                        Opt(:editable, :hstretch, :notify),
                        _("Mount Point"),
                        mountpoints
                      ),
                      PushButton(
                        Id(:fstab_options),
                        Opt(:hstretch),
                        # button text
                        _("Fs&tab Options...")
                      )
                    )
                  ),
                  VSpacing(0.45),
                  notmnt
                )
              )
            ),
            subvol,
            VStretch()
          )
        )
      )

      MiniWorkflow.SetContents(
        Greasemonkey.Transform(contents),
        MiniWorkflowStepFormatMountHelptext()
      )

      MiniWorkflow.SetLastStep(!_AskPassword.call)

      ChangeWidgetIfExists(
        :format,
        :Value,
        do_format ? :do_format : :do_not_format
      )
      ChangeWidgetIfExists(
        :do_format,
        :Enabled,
        !Ops.get_boolean(data, "pool", false)
      )
      ChangeWidgetIfExists(:do_format_attachment, :Enabled, do_format)
      #not there in RAID/LVM/loop configuration (#483789)
      ChangeWidgetIfExists(:do_not_format_attachment, :Enabled, !do_format)

      _EnableDisableFsOpts.call(used_fs) if do_format

      #not there on s390s
      ChangeWidgetIfExists(:crypt_fs, :Value, crypt_fs)
      ChangeWidgetIfExists(
        :crypt_fs,
        :Enabled,
        !Ops.get_boolean(data, "pool", false)
      )

      UI.ChangeWidget(Id(:mount), :Value, do_mount ? :do_mount : :do_not_mount)
      ChangeWidgetIfExists(
        :do_mount,
        :Enabled,
        !Ops.get_boolean(data, "pool", false)
      )
      UI.ChangeWidget(Id(:do_mount_attachment), :Enabled, do_mount)
      UI.ChangeWidget(Id(:mount_point), :Value, mount)

      widget = nil

      data = HandlePartWidgetChanges(
        true,
        widget,
        all_filesystems,
        orig_data.value,
        data
      )
      begin
        widget = MiniWorkflow.UserInput

        if widget != :back && widget != :abort
          data = HandlePartWidgetChanges(
            false,
            widget,
            all_filesystems,
            orig_data.value,
            data
          )
        end

        case widget
          when :fs
            used_fs = Convert.to_symbol(UI.QueryWidget(Id(:fs), :Value))

            #retrieve info about fs user has selected
            used_fs_data = Ops.get(all_filesystems, used_fs, {})
            Builtins.y2milestone("Selected filesystem details %1", used_fs_data)

            if used_fs != Ops.get_symbol(data, "used_fs", :none)
              #set file system type
              Ops.set(data, "used_fs", used_fs)
              data = Builtins.filter(data) { |key, value| key != "fs_options" }

              #set file system ID (and update the File System ID widget
              #that is - FsidComboBox)
              Ops.set(
                data,
                "fsid",
                Ops.get_integer(used_fs_data, :fsid, Partitions.fsid_native)
              )
              UI.ChangeWidget(
                Id(:fsid_point),
                :Value,
                Ops.get_string(used_fs_data, :fsid_item, "")
              )

              #suggest some nice mountpoints if user wants to mount this partition
              if do_mount
                UI.ChangeWidget(
                  Id(:mount_point),
                  :Items,
                  _ProposeMountpoints.call(used_fs, mount)
                )
              end
            end
          when :crypt_fs
            crypt_fs = Convert.to_boolean(UI.QueryWidget(Id(:crypt_fs), :Value))
            MiniWorkflow.SetLastStep(!_AskPassword.call)
          when :do_format
            do_format = Convert.to_boolean(
              UI.QueryWidget(Id(:do_format), :Value)
            )
            Ops.set(
              data,
              "used_fs",
              Convert.to_symbol(UI.QueryWidget(Id(:fs), :Value))
            )

            UI.ChangeWidget(Id(:do_format_attachment), :Enabled, true)
            ChangeWidgetIfExists(:do_not_format_attachment, :Enabled, false)
            _EnableDisableFsOpts.call(Ops.get_symbol(data, "used_fs", :none))
            UI.SetFocus(Id(:fs))
            MiniWorkflow.SetLastStep(!_AskPassword.call)
          when :do_not_format
            do_format = Convert.to_boolean(
              UI.QueryWidget(Id(:do_format), :Value)
            )
            UI.ChangeWidget(Id(:do_format_attachment), :Enabled, false)
            ChangeWidgetIfExists(:do_not_format_attachment, :Enabled, true)
            MiniWorkflow.SetLastStep(!_AskPassword.call)
          when :fsid_point

          when :do_mount
            do_mount = true
            UI.ChangeWidget(Id(:do_mount_attachment), :Enabled, true)
            UI.SetFocus(Id(:mount_point))
            #propose mountpoints
            #UI::ChangeWidget(`id(`mount_point), `Items, ProposeMountpoints( used_fs, mount ));
            MiniWorkflow.SetLastStep(!_AskPassword.call)
          when :do_not_mount
            do_mount = false
            UI.ChangeWidget(Id(:do_mount_attachment), :Enabled, false)
            MiniWorkflow.SetLastStep(!_AskPassword.call)
          when :next
            if UI.WidgetExists(Id(:do_format))
              do_format = Convert.to_boolean(
                UI.QueryWidget(Id(:do_format), :Value)
              )
            else
              do_format = true
            end
            if UI.WidgetExists(Id(:crypt_fs))
              crypt_fs = Convert.to_boolean(
                UI.QueryWidget(Id(:crypt_fs), :Value)
              )
            else
              crypt_fs = false
            end
            do_mount = Convert.to_boolean(UI.QueryWidget(Id(:do_mount), :Value))
            mount = Convert.to_string(UI.QueryWidget(Id(:mount_point), :Value))

            # TODO: checks
            #crypt-file specific checks
            if Ops.get_symbol(data, "type", :unknown) == :loop
              #is encrypt fs checked?
              if !crypt_fs
                # error popup
                Popup.Error(_("Crypt files must be encrypted."))
                UI.ChangeWidget(Id(:crypt_fs), :Value, true)
                UI.SetFocus(Id(:crypt_fs))
                widget = :again
                next
              end

              #enforce formatting the crypt-file
              if Ops.get_boolean(data, "create_file", false) && !do_format
                # error popup
                Popup.Error(
                  _(
                    "You chose to create the crypt file, but did not specify\n" +
                      "that it should be formatted. This does not make sense.\n" +
                      "\n" +
                      "Also check the format option.\n"
                  )
                )
                UI.ChangeWidget(Id(:do_format), :Value, true)
                UI.ChangeWidget(Id(:do_format_attachment), :Enabled, true)
                UI.SetFocus(Id(:fs))
                widget = :again
                next
              end
              #enforce specifying mountpoint
              if !do_mount
                # error popup
                Popup.Error(_("Crypt files require a mount point."))
                UI.ChangeWidget(Id(:do_mount), :Value, true)
                UI.ChangeWidget(Id(:do_mount_attachment), :Enabled, true)
                UI.SetFocus(Id(:mount_point))
                widget = :again
                next
              end
            end

            #tmpfs specific checks
            if Ops.get_symbol(data, "type", :unknown) == :tmpfs
              #enforce specifying mountpoint
              if !do_mount
                # error popup
                Popup.Error(_("Tmpfs requires a mount point."))
                UI.ChangeWidget(Id(:do_mount), :Value, true)
                UI.ChangeWidget(Id(:do_mount_attachment), :Enabled, true)
                UI.SetFocus(Id(:mount_point))
                widget = :again
                next
              end
            end

            if do_mount
              ret_mp = CheckOkMount(
                Ops.get_string(data, "device", "error"),
                orig_data.value,
                data
              )
              if !Ops.get_boolean(ret_mp, "ok", false)
                if Ops.get_symbol(ret_mp, "field", :none) != :none
                  UI.SetFocus(Id(Ops.get_symbol(ret_mp, "field", :none)))
                end
                widget = :again
                next
              end
            end

            if do_format
              if !check_ok_fssize(Ops.get_integer(data, "size_k", 0), data)
                widget = :again
                next
              end
            end
        end
      end until widget == :abort || widget == :back || widget == :next

      if widget == :next
        if crypt_fs
          Ops.set(
            data,
            "enc_type",
            Ops.get_boolean(data, "format", false) ? :luks : :twofish
          )
        else
          Ops.set(data, "enc_type", :none)
        end

        Ops.set(data, "format", do_format)
        Ops.set(data, "mount", do_mount ? mount : "")

        data = Builtins.filter(data) { |key, value| key != "fs_options" } if !Ops.get_boolean(
          data,
          "format",
          false
        )

        if Builtins.contains(
            [:primary, :extended, :logical],
            Ops.get_symbol(data, "type", :unknown)
          )
          if Ops.get_integer(data, "fsid", 0) !=
              Ops.get_integer(orig_data.value, "fsid", 0)
            Ops.set(data, "change_fsid", true)
          end
        end

        widget = :finish if !_AskPassword.call

        orig_data.value = deep_copy(data)
      end

      Builtins.y2milestone(
        "MiniWorkflowStepFormatMount data:%1 ret:%2",
        data,
        widget
      )

      widget
    end


    def MiniWorkflowStepPasswordHelptext(data)
      data = deep_copy(data)
      min_pw_len = Ops.get_boolean(data, "format", false) ? 8 : 1
      empty_pw_allowed = EmptyCryptPwdAllowed(data)

      # helptext
      helptext = _(
        "<p>\n" +
          "Keep in mind that this file system is only protected when it is not\n" +
          "mounted. Once it is mounted, it is as secure as every other\n" +
          "Linux file system.\n" +
          "</p>"
      )

      if empty_pw_allowed
        if Ops.get_symbol(data, "used_fs", :unknown) == :swap
          # helptext
          helptext = Ops.add(
            helptext,
            _(
              "<p>\n" +
                "The file system used for this volume is swap. You can leave the encryption \n" +
                "password empty, but then the swap device cannot be used for hibernating\n" +
                "(suspend to disk).\n" +
                "</p>\n"
            )
          )
        else
          # helptext
          helptext = Ops.add(
            helptext,
            _(
              "<p>\n" +
                "This mount point corresponds to a temporary filesystem like /tmp or /var/tmp.\n" +
                "If you leave the encryption password empty, the system will create\n" +
                "a random password at system startup for you. This means, you will lose all\n" +
                "data on these filesystems at system shutdown.\n" +
                "</p>\n"
            )
          )
        end
      end

      # helptext
      helptext = Ops.add(
        helptext,
        _(
          "<p>\n" +
            "If you forget your password, you will lose access to the data on your file system.\n" +
            "Choose your password carefully. A combination of letters and numbers\n" +
            "is recommended. To ensure the password was entered correctly,\n" +
            "enter it twice.\n" +
            "</p>\n"
        )
      )

      # helptext, %1 is replaced by integer
      helptext = Ops.add(
        helptext,
        Builtins.sformat(
          _(
            "<p>\n" +
              "You must distinguish between uppercase and lowercase. A password should have at\n" +
              "least %1 characters and, as a rule, not contain any special characters\n" +
              "(e.g., letters with accents or umlauts).\n" +
              "</p>\n"
          ),
          min_pw_len
        )
      )

      # helptext
      helptext = Ops.add(helptext, _("<p>\nDo not forget this password!\n</p>"))

      helptext
    end


    def MiniWorkflowStepPassword(data)
      Builtins.y2milestone("MiniWorkflowStepPassword data:%1", data.value)

      min_pw_len = Ops.get_boolean(data.value, "format", false) ? 8 : 1
      empty_pw_allowed = EmptyCryptPwdAllowed(data.value)
      two_pw = Ops.get_boolean(data.value, "format", false) ||
        Builtins.isempty(Ops.get_string(data.value, "mount", ""))

      label = ""

      if two_pw
        label = _("All data stored on the volume will be lost!")
        label = Ops.add(label, "\n")
        label = Ops.add(label, _("Do not forget what you enter here!"))
        label = Ops.add(label, "\n")
      end
      label = Ops.add(label, _("Empty password allowed.")) if empty_pw_allowed

      ad = Empty()
      if two_pw
        ad = Password(
          Id(:pw2),
          Opt(:hstretch),
          # Label: get same password again for verification
          # Please use newline if label is longer than 40 characters
          _("Reenter the Password for &Verification:"),
          ""
        )
      end


      contents = HVSquash(
        term(
          :FrameWithMarginBox,
          _("Password"),
          VBox(
            Password(
              Id(:pw1),
              Opt(:hstretch),
              # Label: get password for user root
              # Please use newline if label is longer than 40 characters
              _("&Enter a Password for your File System:"),
              ""
            ),
            ad,
            VSpacing(0.5),
            Left(Label(label))
          )
        )
      )

      MiniWorkflow.SetContents(
        Greasemonkey.Transform(contents),
        MiniWorkflowStepPasswordHelptext(data.value)
      )
      MiniWorkflow.SetLastStep(true)

      password = ""
      widget = nil

      #don't put those inside the loop - they'd be reset after each unsuccesful try
      UI.ChangeWidget(Id(:pw1), :Value, "")
      UI.ChangeWidget(Id(:pw2), :Value, "") if two_pw

      dev = Ops.get_symbol(data.value, "type", :unknown) != :loop ?
        Ops.get_string(data.value, "device", "") :
        Ops.get_string(data.value, "fpath", "")
      begin
        widget = MiniWorkflow.UserInput

        if widget == :next
          password = Convert.to_string(UI.QueryWidget(Id(:pw1), :Value))

          tmp = password
          tmp = Convert.to_string(UI.QueryWidget(Id(:pw2), :Value)) if two_pw

          need_verify = !Ops.get_boolean(data.value, "format", false) &&
            !Builtins.isempty(Ops.get_string(data.value, "mount", ""))

          if !Storage.CheckEncryptionPasswords(
              password,
              tmp,
              min_pw_len,
              empty_pw_allowed
            ) ||
              need_verify && !Storage.CheckCryptOk(dev, password, false, false)
            UI.SetFocus(Id(:pw1))
            widget = :again
          end
        end
      end until widget == :abort || widget == :back || widget == :next

      if widget == :next
        Storage.SetCryptPwd(dev, password)
        widget = :finish
      end

      Builtins.y2milestone(
        "MiniWorkflowStepPassword data:%1 ret:%2",
        data.value,
        widget
      )

      widget
    end


    def DlgResize(data, disk)
      disk = deep_copy(disk)
      # This resize dialog is simple but avoids several problems faced
      # before:
      #
      # - Stripped digits in a bargraph (bnc #445590)
      #
      # - Impossible to resize to maximal size (bnc #373744, #442318,
      #   #456816)
      #
      # - Changing dialog size (bnc #460382)
      #
      # If somebody wants fancy stuff like slider or bargraph it's a
      # feature request.


      target_map = Storage.GetTargetMap


      possible = Storage.IsResizable(data.value)
      Builtins.y2milestone("DlgResize data: %1", data.value)
      txt = ""
      if !Ops.get(possible, "device", true)
        # popup text
        txt = _("Resize not supported by underlying device.")
      elsif !Ops.get_boolean(data.value, "format", false) &&
          !Ops.get(possible, "shrink", false) &&
          !Ops.get(possible, "extend", false)
        # popup text
        txt = _(
          "\n" +
            "You cannot resize the selected partition because the file system\n" +
            "on this partition does not support resizing.\n"
        )
      end
      if !Builtins.isempty(txt)
        Popup.Message(txt)
        return false
      end

      cyl_size = 0
      free_cyl_after = 0

      device = Ops.get_string(data.value, "device", "error")
      used_fs = Ops.get_symbol(data.value, "used_fs", :none)

      used_k = FileSystems.MinFsSizeK(used_fs)

      if !Ops.get_boolean(data.value, "format", false)
        if used_fs != :swap
          if used_fs == :ntfs &&
              !TryUmount(
                device,
                _(
                  "It is not possible to check whether a NTFS\ncan be resized while it is mounted."
                ),
                false
              )
            return false
          end

          free_data = Storage.GetFreeSpace(device, used_fs, true)
          if Builtins.isempty(free_data) ||
              !Ops.get_boolean(free_data, "ok", false)
            Builtins.y2error(
              "Failed to retrieve FreeSpace %1, filesystem %2",
              device,
              Ops.get_symbol(data.value, "used_fs", :none)
            )
            #FIXME: Really?
            Popup.Error(
              Builtins.sformat(
                _(
                  "Partition %1 cannot be resized\nbecause the filesystem seems to be inconsistent.\n"
                ),
                device
              )
            )
            return false
          end

          used_k = Integer.Max(
            [used_k, Ops.divide(Ops.get_integer(free_data, "used", 0), 1024)]
          )
        end
      end

      min_free_k = 10 * 1024
      size_k = Ops.get_integer(data.value, "size_k", 0)

      # minimal and maximal size for volume
      min_size_k = Integer.Min([Ops.add(used_k, min_free_k), size_k])
      max_size_k = 0

      heading = ""

      case Ops.get_symbol(data.value, "type", :unknown)
        when :logical, :primary
          # Heading for dialog
          heading = Builtins.sformat(_("Resize Partition %1"), device)

          cyl_size = Ops.get_integer(disk, "cyl_size", 1)
          free_cyl_before = 0
          free_cyl_before_ref = arg_ref(free_cyl_before)
          free_cyl_after_ref = arg_ref(free_cyl_after)
          Storage.FreeCylindersAroundPartition(
            device,
            free_cyl_before_ref,
            free_cyl_after_ref
          )
          free_cyl_before = free_cyl_before_ref.value
          free_cyl_after = free_cyl_after_ref.value

          min_size_k = Integer.Max([min_size_k, Ops.divide(cyl_size, 1024)])
          max_size_k = Ops.add(
            size_k,
            Ops.divide(Ops.multiply(cyl_size, free_cyl_after), 1024)
          )
        when :lvm
          # Heading for dialog
          heading = Builtins.sformat(_("Resize Logical Volume %1"), device)

          min_size_k = Integer.Max(
            [min_size_k, Ops.divide(Ops.get_integer(disk, "pesize", 0), 1024)]
          )
          max_size_k = Ops.add(
            size_k,
            Ops.divide(
              Ops.multiply(
                Ops.get_integer(disk, "pe_free", 0),
                Ops.get_integer(disk, "pesize", 0)
              ),
              1024
            )
          )
      end

      # size_k + min_size_k could be > max_size_k
      min_size_k = Integer.Min([min_size_k, max_size_k])

      Builtins.y2milestone("used_k:%1 size_k:%2", used_k, size_k)
      Builtins.y2milestone(
        "min_size_k:%1 max_size_k:%2",
        min_size_k,
        max_size_k
      )


      infos = VBox(
        Left(
          Label(
            Builtins.sformat(
              _("Current size: %1"),
              Storage.KByteToHumanString(size_k)
            )
          )
        )
      )
      if used_fs != :swap && !Ops.get_boolean(data.value, "format", false)
        infos = Builtins.add(
          infos,
          Left(
            Label(
              Builtins.sformat(
                _("Currently used: %1"),
                Storage.KByteToHumanString(used_k)
              )
            )
          )
        )
      end


      contents = HVSquash(
        # frame heading
        term(
          :FrameWithMarginBox,
          _("Size"),
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
              term(
                :LeftRadioButton,
                Id(:min_size),
                Opt(:notify),
                # radio button text, %1 is replaced by size
                Builtins.sformat(
                  _("Minimum Size (%1)"),
                  Storage.KByteToHumanString(min_size_k)
                )
              ),
              # radio button text
              term(
                :LeftRadioButtonWithAttachment,
                Id(:custom_size),
                Opt(:notify),
                _("Custom Size"),
                VBox(
                  Id(:custom_size_attachment),
                  MinWidth(
                    15,
                    InputField(
                      Id(:custom_size_input),
                      Opt(:shrinkable),
                      _("Size")
                    )
                  )
                )
              ),
              VSpacing(1),
              infos
            )
          )
        )
      )

      UI.OpenDialog(
        VBox(
          Left(Heading(heading)),
          Greasemonkey.Transform(contents),
          VSpacing(1.0),
          ButtonBox(
            PushButton(Id(:help), Opt(:helpButton), Label.HelpButton),
            PushButton(Id(:cancel), Opt(:cancelButton), Label.CancelButton),
            PushButton(Id(:ok), Opt(:default, :okButton), Label.OKButton)
          )
        )
      )

      # help text
      help_text = _("<p>Choose new size.</p>")

      UI.ChangeWidget(:help, :HelpText, help_text)

      UI.ChangeWidget(Id(:size), :Value, :max_size)
      UI.ChangeWidget(Id(:custom_size_attachment), :Enabled, false)
      UI.ChangeWidget(
        Id(:custom_size_input),
        :Value,
        Storage.KByteToHumanString(size_k)
      )

      widget = nil
      asked_big_resize = false

      old_size_k = size_k
      begin
        widget = Convert.to_symbol(UI.UserInput)

        case widget
          when :max_size
            UI.ChangeWidget(Id(:custom_size_attachment), :Enabled, false)
          when :min_size
            UI.ChangeWidget(Id(:custom_size_attachment), :Enabled, false)
          when :custom_size
            UI.ChangeWidget(Id(:custom_size_attachment), :Enabled, true)
            UI.SetFocus(Id(:custom_size_input))
          when :ok
            case Convert.to_symbol(UI.QueryWidget(Id(:size), :Value))
              when :max_size
                size_k = max_size_k
              when :min_size
                size_k = min_size_k
              when :custom_size
                tmp = Convert.to_string(
                  UI.QueryWidget(Id(:custom_size_input), :Value)
                )
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
                  widget = :again
                  next
                end
            end

            if size_k != old_size_k
              mountpoint = Storage.DeviceMounted(device)
              lvm = Ops.get_symbol(data.value, "type", :unknown) == :lvm

              if !Ops.get_boolean(data.value, "format", false) &&
                  !CheckResizePossible(
                    device,
                    false,
                    lvm,
                    Ops.subtract(size_k, old_size_k),
                    used_fs
                  )
                #FIXME: To check whether the part. can be resized only
                #after user tries to do that is stupid - in some cases
                #we can tell beforehand, thus user should never get to this
                #point (e.g. when the partition is mounted)
                Builtins.y2error("Resizing the partition is not possible")
                widget = :again
                next
              end

              if !Ops.get_boolean(data.value, "format", false) &&
                  Ops.greater_than(Builtins.size(mountpoint), 0) &&
                  Builtins.contains([:ext2, :ext3, :ext4], used_fs) &&
                  !asked_big_resize &&
                  Ops.greater_or_equal(
                    Ops.subtract(size_k, old_size_k),
                    1024 * 1024 * 50
                  )
                asked_big_resize = true
                txt2 = Builtins.sformat(
                  _(
                    "You are extending a mounted filesystem by %1 Gigabyte. \n" +
                      "This may be quite slow and can take hours. You might possibly want \n" +
                      "to consider umounting the filesystem, which will increase speed of \n" +
                      "resize task a lot."
                  ),
                  Ops.divide(Ops.subtract(size_k, old_size_k), 1024 * 1024)
                )
                answ = Popup.YesNo(txt2)
                Builtins.y2milestone(
                  "ResizeDlg big_resize_while_mounted ret:%1",
                  answ
                )
                if answ
                  widget = :again
                  next
                end
              end

              case Ops.get_symbol(data.value, "type", :unknown)
                when :logical, :primary
                  @num_cyl = Builtins.tointeger(
                    Ops.add(
                      Ops.divide(
                        Ops.multiply(
                          1024.0,
                          Convert.convert(
                            size_k,
                            :from => "integer",
                            :to   => "float"
                          )
                        ),
                        Convert.convert(
                          cyl_size,
                          :from => "integer",
                          :to   => "float"
                        )
                      ),
                      0.5
                    )
                  )
                  @num_cyl = Integer.Clamp(
                    @num_cyl,
                    1,
                    Ops.add(
                      Ops.get_integer(data.value, ["region", 1], 0),
                      free_cyl_after
                    )
                  )
                  Ops.set(data.value, ["region", 1], @num_cyl)
                when :lvm
                  Ops.set(data.value, "size_k", size_k)
              end
            end
          when :cancel

        end
      end while widget != :cancel && widget != :ok

      UI.CloseDialog

      widget == :ok
    end


    def DisplayCommandOutput(command)
      # TODO: maybe use LogView.ycp, but here we want to wait until the command has finished
      # TODO: better error handling

      UI.OpenDialog(
        VBox(
          # label for log view
          MinWidth(
            60,
            LogView(
              Id(:log),
              Builtins.sformat(_("Output of %1"), command),
              15,
              0
            )
          ),
          PushButton(Opt(:default), Label.CloseButton)
        )
      )

      tmp = Convert.to_map(SCR.Execute(path(".target.bash_output"), command))

      lines = Ops.get_string(tmp, "stderr", "") != "" ?
        Ops.get_string(tmp, "stderr", "") :
        Ops.get_string(tmp, "stdout", "")
      UI.ChangeWidget(Id(:log), :Value, lines)

      UI.UserInput
      UI.CloseDialog

      nil
    end


    def RescanDisks
      UI.OpenDialog(
        Opt(:decorated),
        # popup text
        MarginBox(2, 1, Label(_("Rescanning disks...")))
      )

      Storage.ReReadTargetMap

      UI.CloseDialog

      nil
    end
    def ConfirmRecursiveDelete(device, devices, headline, text_before, text_after)
      devices = deep_copy(devices)
      button_box = ButtonBox(
        PushButton(Id(:yes), Opt(:okButton), Label.DeleteButton),
        PushButton(
          Id(:no_button),
          Opt(:default, :cancelButton),
          Label.CancelButton
        )
      )

      display_info = UI.GetDisplayInfo
      has_image_support = Ops.get_boolean(
        display_info,
        "HasImageSupport",
        false
      )

      layout = VBox(
        VSpacing(0.4),
        HBox(
          has_image_support ? Top(Image(Icon.IconPath("question"))) : Empty(),
          HSpacing(1),
          VBox(
            Left(Heading(headline)),
            VSpacing(0.2),
            Left(Label(text_before)),
            VSpacing(0.2),
            Left(RichText(HTML.List(Builtins.sort(devices)))),
            VSpacing(0.2),
            Left(Label(text_after)),
            button_box
          )
        )
      )

      UI.OpenDialog(layout)
      ret = Convert.to_symbol(UI.UserInput)
      UI.CloseDialog

      ret == :yes
    end
  end
end
