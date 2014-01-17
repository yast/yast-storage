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

#  *************************************************************
#  *
#  *     YaST2      SuSE Labs                        -o)
#  *     --------------------                        /\\
#  *                                                _\_v
#  *           www.suse.de / www.suse.com
#  * ----------------------------------------------------------
#  *
#  * Author:        Michael Hager <mike@suse.de>
#  *                Johannes Buchhold <jbuch@suse.de>
#  *
#  *
#  * Description:   Partitioner for experts.
#  *                include for dialogs
#  *
#  *************************************************************
#
#  $Id$
module Yast
  module PartitioningCustomPartDialogsInclude

    def initialize_partitioning_custom_part_dialogs(include_target)
      Yast.import "UI"
      textdomain "storage"

      Yast.import "Storage"
      Yast.import "Partitions"
      Yast.import "FileSystems"
      Yast.import "Package"
      Yast.import "Mode"
      Yast.import "Arch"
      Yast.import "Label"
      Yast.import "Popup"
      Yast.import "StorageProposal"

      Yast.include include_target, "partitioning/custom_part_helptexts.rb"
    end

    def DlgPasswdCryptFs(device, minpwlen, format, tmpcrypt)
      helptext = GetCreateCryptFsHelptext(minpwlen, format, tmpcrypt)
      Builtins.y2milestone(
        "DlgPasswdCryptFs device:%1 minpwlen:%2 format:%3 tmpcrypt:%4",
        device,
        minpwlen,
        format,
        tmpcrypt
      )

      # heading text
      h = _("Enter your Password for the Encrypted File System.")
      label = ""
      if format
        # label text
        label = _("Do not forget what you enter here!")
      end
      if tmpcrypt
        label = Ops.add(label, " ") if Ops.greater_than(Builtins.size(label), 0)
        label = Ops.add(label, _("Empty password allowed."))
      end

      if Ops.greater_than(Builtins.size(device), 0)
        # heading text, %1 is replaced by device name (e.g. /dev/hda1)
        h = Builtins.sformat(
          _("Password for Encrypted File System on %1"),
          device
        )
      end

      ret = Storage.PasswdPopup(helptext, h, label, format, minpwlen, tmpcrypt)
      ret
    end


    #////////////////////////////////////////////////////////////////////////////
    # Dialog Password for Crypted FS Update
    #////////////////////////////////////////////////////////////////////////////


    def DlgUpdateCryptFs(device, mount)
      helptext = GetUpdateCryptFsHelptext()

      # translator comment: %1 is the device name, %2 is a directory
      #            example: "...password for device /dev/hda6 mounted on /var"
      enter = Builtins.sformat(
        _("Enter your encryption password for\ndevice %1 mounted on %2.\n"),
        device,
        mount
      )

      UI.OpenDialog(
        Opt(:decorated),
        HBox(
          HWeight(3, RichText(helptext)),
          HWeight(
            6,
            VBox(
              VSpacing(0.3),
              HBox(
                HSpacing(1),
                # heading text
                Heading(_("Enter your Password for the Encrypted File System")),
                HSpacing(1)
              ),
              VSpacing(2),
              HBox(
                HSpacing(4),
                VBox(
                  # advise user to remember his new password
                  Label(enter),
                  VSpacing(),
                  HBox(
                    Password(
                      Id("pw1"),
                      # Label: get password for user root
                      # Please use newline if label is longer than 40 characters
                      _("&Enter a Password for your File System:"),
                      ""
                    ),
                    HSpacing(15)
                  ),
                  VSpacing(0.5),
                  HBox(
                    Password(
                      Id("pw2"),
                      # Label: get same password again for verification
                      # Please use newline if label is longer than 40 characters
                      _("Reenter the Password for &Verification:"),
                      ""
                    ),
                    HSpacing(15)
                  )
                ),
                HSpacing(4)
              ),
              VSpacing(2),
              ButtonBox(
                PushButton(Id("ok"), Opt(:default), Label.OKButton),
                # Cancel button
                PushButton(Id("cancel"), _("&Skip"))
              ),
              VSpacing(0.5)
            )
          )
        )
      )

      ret = ""
      input_is_ok = false
      pw1 = ""
      pw2 = ""
      begin
        # Clear password fields on every round.
        UI.ChangeWidget(Id("pw1"), :Value, "")
        UI.ChangeWidget(Id("pw2"), :Value, "")

        UI.SetFocus(Id("pw1"))

        ret = Convert.to_string(UI.UserInput)


        if ret != "cancel"
          pw1 = Convert.to_string(UI.QueryWidget(Id("pw1"), :Value))
          pw2 = Convert.to_string(UI.QueryWidget(Id("pw2"), :Value))

          if pw1 != pw2
            # popup text
            Popup.Message(
              _(
                "The first and the second version\n" +
                  "of the password do not match!\n" +
                  "Try again.\n"
              )
            )
          elsif pw1 == ""
            # popup text
            Popup.Message(_("You did not enter a password.\nTry again.\n"))
          elsif Ops.greater_or_equal(Builtins.size(pw1), 1)
            input_is_ok = true
          else
            # popup text
            Popup.Message(
              Builtins.sformat(
                _(
                  "The password must have at least %1 characters.\nTry again.\n"
                ),
                1
              )
            )
          end
        end
      end until input_is_ok || ret == "cancel"

      UI.CloseDialog

      if ret != "cancel"
        return pw1
      else
        return ""
      end
    end

    def DoInputChecks(entry, query)
      entry = deep_copy(entry)
      ret = :ok
      between = Ops.get_list(entry, :between, [])
      below = Ops.get_integer(entry, :below, 0)
      valid_chars = Ops.get_string(entry, :valid_chars, "")
      invalid_chars = Ops.get_string(entry, :invalid_chars, "")
      str_length = Ops.get_integer(entry, :str_length, 0)

      if Ops.get_string(entry, :query_key, "") == "tmpfs_size"
        sz = 0
        pospct = Builtins.search(query, "%")
        posdot = Builtins.search(query, ".")
        posdot = Builtins.search(query, ",") if posdot == nil
        if posdot != nil
          Popup.Error(_("No floating point number."))
          ret = :error
        else
          if pospct != nil &&
              (Ops.greater_than(
                Ops.get_integer(between, 0, 0),
                Builtins.tointeger(query)
              ) ||
                Ops.get_integer(between, 1, 0) != -1 &&
                  Ops.less_than(
                    Ops.get_integer(between, 1, 0),
                    Builtins.tointeger(query)
                  ))
            Popup.Error(Ops.get_string(entry, :error_text_percent, ""))
            ret = :error
          elsif pospct == nil &&
              (!(
                sz_ref = arg_ref(sz);
                _HumanStringToByte_result = Storage.HumanStringToByte(
                  query,
                  sz_ref
                );
                sz = sz_ref.value;
                _HumanStringToByte_result
              ) ||
                Ops.less_than(sz, Ops.get_integer(entry, :min_size, 1)) ||
                !Builtins.regexpmatch(query, "^[0-9]+[KMGkmg]$"))
            Popup.Error(Ops.get_string(entry, :error_text, ""))
            ret = :error
          end
        end
      else
        if between != [] &&
            (Ops.greater_than(Builtins.size(query), 0) ||
              !Ops.get_boolean(entry, :empty_allowed, false))
          Builtins.y2milestone(
            "DoInputChecks entry:%1 query:\"%2\"",
            entry,
            query
          )
          if Ops.greater_than(
              Ops.get_integer(between, 0, 0),
              Builtins.tointeger(query)
            ) ||
              Ops.get_integer(between, 1, 0) != -1 &&
                Ops.less_than(
                  Ops.get_integer(between, 1, 0),
                  Builtins.tointeger(query)
                )
            Popup.Error(Ops.get_string(entry, :error_text, ""))
            ret = :error
          end
        end
        if below != 0 &&
            (Ops.greater_than(Builtins.size(query), 0) ||
              !Ops.get_boolean(entry, :empty_allowed, false))
          Builtins.y2milestone(
            "DoInputChecks entry:%1 query:\"%2\"",
            entry,
            query
          )
          if Ops.less_than(
              Convert.convert(below, :from => "integer", :to => "float"),
              Builtins.tofloat(query)
            )
            Popup.Error(Ops.get_string(entry, :error_text, ""))
            ret = :error
          end
        end
        if str_length != 0 && Ops.greater_than(Builtins.size(query), str_length) &&
            ret != :error
          Popup.Error(Ops.get_string(entry, :error_text, ""))
          ret = :error
        end
      end
      if valid_chars != "" && Ops.greater_than(Builtins.size(query), 0) &&
          ret != :error
        if nil != Builtins.findfirstnotof(query, valid_chars)
          Popup.Error(Ops.get_string(entry, :error_text, ""))
          ret = :error
        end
      end
      if !Builtins.isempty(invalid_chars) && !Builtins.isempty(query) &&
          ret != :error
        if nil != Builtins.findfirstof(query, invalid_chars)
          Popup.Error(Ops.get_string(entry, :error_text, ""))
          ret = :error
        end
      end
      Builtins.y2milestone("DoInputChecks value %1 ret %2", query, ret)
      ret
    end


    # Dialog: Filesystem options
    # @parm new_val map that contains a partition
    # @parm file_systems filesystem definitions
    def FileSystemOptions(org_fs_options, fs_define)
      org_fs_options = deep_copy(org_fs_options)
      fs_define = deep_copy(fs_define)
      Builtins.y2milestone(
        "FileSystemOptions org_fs_options:%1 fs_define:%2",
        org_fs_options,
        fs_define
      )
      fs_options = deep_copy(org_fs_options)
      contents = VBox(VSpacing(1))
      helptext = ""

      Builtins.foreach(Ops.get_list(fs_define, :options, [])) do |option|
        emptyterm = Empty()
        contents = Builtins.add(
          contents,
          Ops.get_term(option, :widget, emptyterm)
        )
        add_help = Ops.get_string(option, :help_text, "")
        helptext = Ops.add(helptext, add_help) if add_help != ""
      end

      UI.OpenDialog(
        Opt(:decorated),
        VBox(
          HSpacing(50),
          # heading text
          Left(Heading(_("File system options:"))),
          VStretch(),
          VSpacing(1),
          HBox(HStretch(), HSpacing(1), contents, HStretch(), HSpacing(1)),
          VSpacing(1),
          VStretch(),
          ButtonBox(
            PushButton(Id(:help), Opt(:helpButton), Label.HelpButton),
            PushButton(Id(:ok), Opt(:default), Label.OKButton),
            PushButton(Id(:cancel), Label.CancelButton)
          )
        )
      )

      UI.ChangeWidget(:help, :HelpText, helptext)

      Builtins.foreach(fs_options) do |query_key, option_map|
        UI.ChangeWidget(
          Id(query_key),
          :Value,
          Ops.get(option_map, "option_value", "")
        )
      end

      iglist = ["auto", "none", "default"]
      ret = :ok
      begin
        ret = Convert.to_symbol(UI.UserInput)
        Builtins.foreach(Ops.get_list(fs_define, :options, [])) do |entry|
          Builtins.y2milestone("FileSystemOptions entry %1", entry)
          if ret != :error
            query = UI.QueryWidget(Id(Ops.get(entry, :query_key)), :Value)
            Builtins.y2milestone("FileSystemOptions query %1", query)
            fs_option = {
              "option_str"   => Ops.get_string(entry, :option_str, ""),
              "option_cmd"   => Ops.get_symbol(entry, :option_cmd, :mkfs),
              "option_value" => query
            }
            if Ops.is_boolean?(query) && query == false &&
                Builtins.haskey(entry, :option_false)
              Ops.set(
                fs_option,
                "option_str",
                Ops.get_string(entry, :option_false, "")
              )
            end
            Builtins.y2milestone("FileSystemOptions fs_option %1", fs_option)

            if Ops.get_boolean(entry, :option_blank, false)
              Ops.set(fs_option, "option_blank", true)
            end

            if Ops.is_string?(query) && !Builtins.contains(iglist, query)
              ret = DoInputChecks(entry, Convert.to_string(query))
            end

            if ret != :error
              if query != Ops.get(entry, :default) &&
                  !Builtins.contains(iglist, query)
                Ops.set(fs_options, Ops.get(entry, :query_key), fs_option)
              elsif Builtins.haskey(fs_options, Ops.get(entry, :query_key))
                fs_options = Builtins.remove(
                  fs_options,
                  Ops.get(entry, :query_key)
                )
              end
            end
            Builtins.y2milestone("FileSystemOptions fs_options %1", fs_options)
          end
        end if ret == :ok
      end until ret == :ok || ret == :cancel

      UI.CloseDialog

      fs_options = deep_copy(org_fs_options) if ret != :ok
      Builtins.y2milestone("FileSystemOptions ret %1", fs_options)
      deep_copy(fs_options)
    end

    def PopupNoSlashLabel
      # popup text
      Popup.Error(
        _(
          "The character '/' is no longer permitted in a volume label.\nChange your volume label so that it does not contain this character.\n"
        )
      )

      nil
    end

    # Dialog: Fstab options
    # @parm old map with original partition
    # @parm new map with changes filled in
    def FstabOptions(old, new)
      old = deep_copy(old)
      new = deep_copy(new)
      helptext = ""
      contents = VBox()
      emptyterm = Empty()

      if Ops.get_symbol(new, "enc_type", :none) == :none &&
          Ops.get_symbol(new, "type", :unknown) != :tmpfs
        # help text, richtext format
        helptext = Ops.add(
          helptext,
          _(
            "<p><b>Mount in /etc/fstab by:</b>\n" +
              "Normally, a file system to mount is identified in /etc/fstab\n" +
              "by the device name. This identification can be changed so the file system \n" +
              "to mount is found by searching for a UUID or a volume label. Not all file \n" +
              "systems can be mounted by UUID or a volume label. If an option is disabled, \n" +
              "this is not possible.\n"
          )
        )

        # help text, richtext format
        helptext = Ops.add(
          helptext,
          _(
            "<p><b>Volume Label:</b>\n" +
              "The name entered in this field is used as the volume label. This usually makes sense only \n" +
              "when you activate the option for mounting by volume label.\n" +
              "A volume label cannot contain the / character or spaces.\n"
          )
        )

        contents = Builtins.add(
          contents,
          VBox(
            RadioButtonGroup(
              Id(:mt_group),
              VBox(
                # label text
                Left(Label(_("Mount in /etc/fstab by"))),
                HBox(
                  VBox(
                    Left(
                      RadioButton(
                        Id(:device),
                        # label text
                        _("&Device Name")
                      )
                    ),
                    Left(
                      RadioButton(
                        Id(:label),
                        # label text
                        _("Volume &Label")
                      )
                    ),
                    Left(
                      RadioButton(
                        Id(:uuid),
                        # label text
                        "U&UID"
                      )
                    )
                  ),
                  Top(
                    VBox(
                      Left(
                        RadioButton(
                          Id(:id),
                          # label text
                          _("Device &ID")
                        )
                      ),
                      Left(
                        RadioButton(
                          Id(:path),
                          # label text
                          _("Device &Path")
                        )
                      )
                    )
                  )
                )
              )
            ),
            TextEntry(
              Id(:vol_label),
              Opt(:hstretch),
              # label text
              _("Volume &Label")
            ),
            VSpacing(1)
          )
        )
      end
      opt_list = []
      if Ops.get_string(new, "mount", "") != "swap"
        Builtins.foreach(FileSystems.GetGeneralFstabOptions) do |entry2|
          if Ops.get_string(entry2, :query_key, "") == "opt_quota" &&
              !FileSystems.CanDoQuota(new)
            next
          end
          if Ops.get_string(entry2, :query_key, "") == "opt_readonly" &&
              !FileSystems.CanMountRo(new)
            next
          end
          opt_list = Builtins.add(opt_list, entry2)
          contents = Builtins.add(
            contents,
            Ops.get_term(entry2, :widget, emptyterm)
          )
          helptext = Ops.add(helptext, Ops.get_string(entry2, :help_text, ""))
        end
        contents = Builtins.add(contents, VSpacing(1))
      end
      Builtins.foreach(
        FileSystems.GetFstabOptWidgets(Ops.get_symbol(new, "used_fs", :ext2))
      ) do |entry2|
        opt_list = Builtins.add(opt_list, entry2)
        contents = Builtins.add(
          contents,
          Ops.get_term(entry2, :widget, emptyterm)
        )
        helptext = Ops.add(helptext, Ops.get_string(entry2, :help_text, ""))
      end
      contents = Builtins.add(contents, VSpacing(1))
      entry = FileSystems.GetArbitraryOptionField
      opt_list = Builtins.add(opt_list, entry)
      contents = Builtins.add(contents, Ops.get_term(entry, :widget, emptyterm))
      helptext = Ops.add(helptext, Ops.get_string(entry, :help_text, ""))

      fstopt = Builtins.deletechars(Ops.get_string(new, "fstopt", ""), " \t")
      fstopt = "" if fstopt == "defaults"

      opt_lstr = Builtins.splitstring(fstopt, ",")
      old_state = {}
      pos = 0
      Builtins.foreach(opt_list) do |opt|
        if Ops.get_symbol(opt, :type, :text) == :boolean
          value = Ops.get_boolean(opt, :default, false)
          pos = 0
          while Ops.less_than(pos, Builtins.size(opt_lstr))
            Builtins.foreach(Ops.get_list(opt, :str_scan, [])) do |list_el|
              if Ops.get_string(list_el, 0, "") == Ops.get(opt_lstr, pos, "")
                value = Ops.get_integer(list_el, 1, 0) == 1
                Ops.set(opt_lstr, pos, "")
              end
            end
            pos = Ops.add(pos, 1)
          end
          Ops.set(old_state, Ops.get_string(opt, :query_key, ""), value)
        else
          value = Ops.get_string(opt, :default, "")
          pos2 = 0
          while Ops.less_than(pos2, Builtins.size(opt_lstr))
            if Ops.greater_than(
                Builtins.size(Ops.get_string(opt, :str_scan, "")),
                0
              ) &&
                Builtins.regexpmatch(
                  Ops.get(opt_lstr, pos2, ""),
                  Ops.get_string(opt, :str_scan, "")
                )
              value = Builtins.regexpsub(
                Ops.get(opt_lstr, pos2, ""),
                Ops.get_string(opt, :str_scan, ""),
                "\\1"
              )
              Ops.set(opt_lstr, pos2, "")
            end
            pos2 = Ops.add(pos2, 1)
          end
          Ops.set(old_state, Ops.get_string(opt, :query_key, ""), value)
        end
      end

      pos = Ops.subtract(Builtins.size(opt_lstr), 1)
      while Ops.greater_or_equal(pos, 0)
        if Builtins.size(Ops.get(opt_lstr, pos, "")) == 0
          opt_lstr = Builtins.remove(opt_lstr, pos)
        end
        pos = Ops.subtract(pos, 1)
      end
      Builtins.y2milestone(
        "FstabOptions key=%1 val:%2",
        Ops.get_string(
          opt_list,
          [Ops.subtract(Builtins.size(opt_list), 1), :query_key],
          ""
        ),
        Builtins.mergestring(opt_lstr, ",")
      )
      arb_opt = Builtins.mergestring(opt_lstr, ",")
      if !Ops.get_boolean(new, "noauto", false) &&
          Ops.get_symbol(new, "enc_type", :none) != :none
        arb_opt = FileSystems.RemoveCryptOpts(arb_opt)
      end
      if FileSystems.CanDoQuota(new) && FileSystems.HasQuota(new)
        Ops.set(old_state, "opt_quota", true)
      end
      arb_opt = FileSystems.RemoveQuotaOpts(arb_opt)
      Ops.set(
        old_state,
        Ops.get_string(
          opt_list,
          [Ops.subtract(Builtins.size(opt_list), 1), :query_key],
          ""
        ),
        arb_opt
      )
      Builtins.y2milestone("FstabOptions old_state=%1", old_state)

      UI.OpenDialog(
        Opt(:decorated),
        VBox(
          HSpacing(50),
          # heading text
          Left(Heading(_("Fstab Options:"))),
          VStretch(),
          VSpacing(1),
          HBox(HStretch(), HSpacing(1), contents, HStretch(), HSpacing(1)),
          VSpacing(1),
          VStretch(),
          ButtonBox(
            PushButton(Id(:help), Opt(:helpButton), Label.HelpButton),
            PushButton(Id(:ok), Opt(:default), Label.OKButton),
            PushButton(Id(:cancel), Label.CancelButton)
          )
        )
      )

      UI.ChangeWidget(:help, :HelpText, helptext)

      if UI.WidgetExists(Id(:mt_group))
        no_mountby_type = [:loop]
        mountby_id_path_type = [:primary, :logical]
        enab = {}
        tmp = !Builtins.contains(
          no_mountby_type,
          Ops.get_symbol(new, "type", :primary)
        )
        Ops.set(
          enab,
          :label,
          tmp &&
            FileSystems.MountLabel(Ops.get_symbol(new, "used_fs", :unknown)) &&
            Ops.get_symbol(new, "enc_type", :none) == :none
        )
        Ops.set(
          enab,
          :uuid,
          tmp &&
            (Ops.get_boolean(new, "format", false) ||
              Ops.greater_than(
                Builtins.size(Ops.get_string(new, "uuid", "")),
                0
              )) &&
            FileSystems.MountUuid(Ops.get_symbol(new, "used_fs", :unknown)) &&
            Ops.get_symbol(new, "enc_type", :none) == :none
        )
        tmp = Builtins.contains(
          mountby_id_path_type,
          Ops.get_symbol(new, "type", :none)
        )
        Ops.set(
          enab,
          :id,
          tmp &&
            Ops.greater_than(Builtins.size(Ops.get_list(new, "udev_id", [])), 0) ||
            Builtins.substring(Ops.get_string(new, "device", ""), 0, 7) == "/dev/md"
        )
        Ops.set(
          enab,
          :path,
          tmp &&
            Ops.greater_than(
              Builtins.size(Ops.get_string(new, "udev_path", "")),
              0
            )
        )
        Builtins.y2milestone("FstabOptions enab %1", enab)
        UI.ChangeWidget(
          Id(:label),
          :Enabled,
          Ops.get_boolean(enab, :label, false)
        )
        UI.ChangeWidget(
          Id(:uuid),
          :Enabled,
          Ops.get_boolean(enab, :uuid, false)
        )
        UI.ChangeWidget(Id(:id), :Enabled, Ops.get_boolean(enab, :id, false))
        UI.ChangeWidget(
          Id(:path),
          :Enabled,
          Ops.get_boolean(enab, :path, false)
        )
        defmb = !Mode.config ?
          Storage.GetMountBy(Ops.get_string(new, "device", "")) :
          :device
        Builtins.y2milestone("FstabOptions defmb %1", defmb)
        if Builtins.haskey(enab, defmb) && !Ops.get_boolean(enab, defmb, false)
          defmb = :device
        end
        UI.ChangeWidget(
          Id(:mt_group),
          :CurrentButton,
          Ops.get_symbol(new, "mountby", defmb)
        )
      end

      if UI.WidgetExists(Id(:vol_label))
        UI.ChangeWidget(
          Id(:vol_label),
          :Enabled,
          FileSystems.MountLabel(Ops.get_symbol(new, "used_fs", :unknown)) &&
            Ops.get_symbol(new, "enc_type", :none) == :none
        )
        UI.ChangeWidget(
          Id(:vol_label),
          :ValidChars,
          Ops.add(FileSystems.nchars, "-._:/")
        )
        UI.ChangeWidget(
          Id(:vol_label),
          :Value,
          Ops.get_string(new, "label", "")
        )
      end

      Builtins.y2milestone(
        "FstabOptions Exists opt_user %1",
        UI.WidgetExists(Id("opt_user"))
      )
      Builtins.y2milestone("FstabOptions new=%1", new)
      if UI.WidgetExists(Id("opt_user"))
        UI.ChangeWidget(
          Id("opt_user"),
          :Enabled,
          Ops.get_symbol(new, "enc_type", :none) == :none
        )
      end
      Builtins.foreach(old_state) do |key, value|
        UI.ChangeWidget(Id(key), :Value, value)
      end

      ret = :ok
      begin
        ret = UI.UserInput
        Builtins.y2milestone("FstabOptions ret %1", ret)
        if ret == :ok
          if UI.WidgetExists(Id(:mt_group))
            Ops.set(
              new,
              "mountby",
              UI.QueryWidget(Id(:mt_group), :CurrentButton)
            )
            if !Ops.get_boolean(new, "format", false) &&
                !Ops.get_boolean(new, "create", false) &&
                Ops.get_symbol(new, "mountby", :device) !=
                  Ops.get_symbol(old, "mountby", :device)
              if !Builtins.haskey(new, "ori_mountby")
                Ops.set(
                  new,
                  "ori_mountby",
                  Ops.get_symbol(old, "mountby", :device)
                )
              end
            end
            Ops.set(new, "label", UI.QueryWidget(Id(:vol_label), :Value))
            if Ops.get_string(new, "label", "") !=
                Ops.get_string(old, "label", "")
              max_len = FileSystems.LabelLength(
                Ops.get_symbol(new, "used_fs", :unknown)
              )
              if Ops.greater_than(
                  Builtins.size(Ops.get_string(new, "label", "")),
                  max_len
                )
                Ops.set(
                  new,
                  "label",
                  Builtins.substring(
                    Ops.get_string(new, "label", ""),
                    0,
                    max_len
                  )
                )
                # popup text %1 is a number
                Popup.Error(
                  Builtins.sformat(
                    _(
                      "\n" +
                        "Maximum volume label length for the selected file system\n" +
                        "is %1. Your volume label has been truncated to this size.\n"
                    ),
                    max_len
                  )
                )
              end
              if Builtins.search(Ops.get_string(new, "label", ""), "/") != nil
                PopupNoSlashLabel()
                ret = :again
              end
              if !Ops.get_boolean(new, "format", false) &&
                  !Ops.get_boolean(new, "create", false) &&
                  !Builtins.haskey(new, "ori_label")
                Ops.set(new, "ori_label", Ops.get_string(old, "label", ""))
              end
            end
            if Ops.get_symbol(new, "mountby", :device) == :label &&
                Builtins.size(Ops.get_string(new, "label", "")) == 0
              ret = :again
              # popup text
              Popup.Error(_("Provide a volume label to mount by label."))
              next
            end
            if Ops.greater_than(
                Builtins.size(Ops.get_string(new, "label", "")),
                0
              ) &&
                !check_unique_label(Storage.GetTargetMap, new)
              ret = :again
              # popup text
              Popup.Error(
                _(
                  "This volume label is already in use. Select a different one."
                )
              )
              next
            end
            if Ops.get_symbol(new, "mountby", :device) == :label &&
                Builtins.search(Ops.get_string(new, "label", ""), "/") != nil
              ret = :again
              PopupNoSlashLabel()
              next
            end
          end
          if UI.WidgetExists(Id("opt_noauto"))
            Ops.set(new, "noauto", UI.QueryWidget(Id("opt_noauto"), :Value))
          end
          new_state = {}
          text = ""
          new_fstopt = ""
          Builtins.foreach(opt_list) do |entry2|
            text = ""
            value = UI.QueryWidget(
              Id(Ops.get_string(entry2, :query_key, "")),
              :Value
            )
            Ops.set(new_state, Ops.get_string(entry2, :query_key, ""), value)
            if Ops.get_symbol(entry2, :type, :text) == :boolean
              text = Ops.get_string(entry2, [:str_opt, "default"], "")
              if value == true &&
                  Builtins.haskey(Ops.get_map(entry2, :str_opt, {}), 1)
                text = Ops.get_string(entry2, [:str_opt, 1], "")
              elsif value == false &&
                  Builtins.haskey(Ops.get_map(entry2, :str_opt, {}), 0)
                text = Ops.get_string(entry2, [:str_opt, 0], "")
              end
            else
              if DoInputChecks(entry2, Convert.to_string(value)) != :ok
                ret = :again
              elsif Ops.greater_than(Builtins.size(Convert.to_string(value)), 0)
                text = Builtins.sformat(
                  Ops.get_string(entry2, :str_opt, "%1"),
                  value
                )
              end
              # this is the default journal mode, no option needed for it
              text = "" if text == "data=ordered"
            end
            if Ops.greater_than(Builtins.size(text), 0)
              if Ops.greater_than(Builtins.size(new_fstopt), 0)
                new_fstopt = Ops.add(new_fstopt, ",")
              end
              new_fstopt = Ops.add(new_fstopt, text)
            end
          end
          if UI.WidgetExists(Id("opt_quota")) &&
              UI.QueryWidget(Id("opt_quota"), :Value) == true
            new_fstopt = FileSystems.AddQuotaOpts(new, new_fstopt)
            if !Ops.get_boolean(old_state, "opt_quota", false) && Mode.normal
              Package.InstallAll(["quota"])
            end
          end
          Builtins.y2milestone("FstabOptions new_state=%1", new_state)
          Builtins.y2milestone(
            "FstabOptions old_fstopt=%1 new_fstopt=%2",
            Ops.get_string(old, "fstopt", ""),
            new_fstopt
          )
          if old_state != new_state &&
              Ops.get_string(old, "fstopt", "") != new_fstopt
            if !Ops.get_boolean(new, "format", false) &&
                !Ops.get_boolean(new, "create", false) &&
                !Builtins.haskey(new, "ori_fstopt")
              Ops.set(new, "ori_fstopt", Ops.get_string(old, "fstopt", ""))
            end
            Ops.set(new, "fstopt", new_fstopt)
          end
          if !CheckFstabOptions(new)
            Ops.set(new, "fstopt", Ops.get_string(old, "fstopt", ""))
            ret = :again
          end
        end
      end until ret == :ok || ret == :cancel

      UI.CloseDialog
      Builtins.y2milestone(
        "FstabOptions fstopt:%1 mountby:%2 label:%3",
        Ops.get_string(new, "fstopt", ""),
        Ops.get_symbol(new, "mountby", :device),
        Ops.get_string(new, "label", "")
      )
      deep_copy(new)
    end


    # Dialogpart: Filesystem
    # @parm new_val map that contains a partition
    # @parm file_systems filesystem definitions
    # @return [Yast::Term] the term contains a ComboBox with the different filesystems
    def FileSystemsComboBox(new_val, file_systems)
      new_val = deep_copy(new_val)
      file_systems = deep_copy(file_systems)
      fs_sel = {}
      filesystems = []
      is_swap = Ops.get_integer(new_val, "fsid", 0) == Partitions.fsid_swap

      Builtins.y2debug("FileSystemsComboBox new=%1 swap=%2", new_val, is_swap)
      ufs = Ops.get_symbol(new_val, "used_fs") { Partitions.DefaultFs }
      Builtins.foreach(file_systems) do |file_system_name, file_system_map|
        if Ops.get_boolean(file_system_map, :real_fs, false) &&
            (file_system_name == ufs ||
              Ops.get_boolean(file_system_map, :supports_format, false))
          Ops.set(fs_sel, file_system_name, {})
          Ops.set(
            fs_sel,
            [file_system_name, "text"],
            Ops.get_string(file_system_map, :name, "Ext2")
          )
          if is_swap
            Ops.set(
              fs_sel,
              [file_system_name, "selected"],
              file_system_name == :swap
            )
          else
            Ops.set(
              fs_sel,
              [file_system_name, "selected"],
              file_system_name == ufs
            )
          end
        end
      end
      Builtins.y2milestone("FileSystemsComboBox fs_sel=%1", fs_sel)
      Builtins.y2milestone("FileSystemsComboBox DefFs=%1", Partitions.DefaultFs)
      if Builtins.haskey(fs_sel, Partitions.DefaultFs) &&
          Builtins.size(Builtins.filter(fs_sel) do |k, e|
            Ops.get_boolean(e, "selected", false)
          end) == 0
        Ops.set(fs_sel, [Partitions.DefaultFs, "selected"], true)
        Builtins.y2milestone("FileSystemsComboBox fs_sel=%1", fs_sel)
      end
      Builtins.foreach(fs_sel) do |fs_type, entry|
        if fs_type != :swap
          filesystems = Builtins.add(
            filesystems,
            Item(
              Id(fs_type),
              Ops.get_string(entry, "text", "Ext2"),
              Ops.get_boolean(entry, "selected", false)
            )
          )
        end
      end
      if Builtins.haskey(fs_sel, :swap)
        filesystems = Builtins.add(
          filesystems,
          Item(
            Id(:swap),
            Ops.get_string(fs_sel, [:swap, "text"], "Swap"),
            Ops.get_boolean(fs_sel, [:swap, "selected"], false)
          )
        )
      end

      VBox(
        ComboBox(
          Id(:fs),
          Opt(:hstretch, :notify),
          # label text
          _("File &System"),
          filesystems
        ),
        PushButton(
          Id(:fs_options),
          Opt(:hstretch),
          # button text
          _("O&ptions...")
        )
      )
    end


    def CryptButton(new_val)
      new_val = deep_copy(new_val)
      cr = Ops.get_symbol(new_val, "enc_type", :none) != :none

      VBox(
        Left(
          CheckBox(
            Id(:crypt_fs),
            Opt(:notify),
            # button text
            _("&Encrypt Device"),
            cr
          )
        )
      )
    end


    # Dialogpart: Filesystem ID
    # @parm new_val map that contains a partition
    # @parm file_systems filesystem definitions
    # @return [Yast::Term] the term contains a ComboBox that allow the user to  edit the filesystem ID
    def FsidComboBox(new_val, file_systems)
      new_val = deep_copy(new_val)
      file_systems = deep_copy(file_systems)
      items = []
      added_items = []
      added_fsids = []
      Builtins.foreach(file_systems) do |fs_name, fs_map|
        fsid_item = Ops.get_string(fs_map, :fsid_item, " ")
        if !Builtins.contains(added_items, fsid_item)
          items = Builtins.add(
            items,
            Item(
              Id(fsid_item),
              fsid_item,
              Ops.get_integer(fs_map, :fsid, 0) ==
                Ops.get_integer(new_val, "fsid", 0)
            )
          )
          added_fsids = Builtins.add(
            added_fsids,
            Ops.get_integer(fs_map, :fsid, 0)
          )
          added_items = Builtins.add(added_items, fsid_item)
        end
      end

      id = Ops.get_integer(new_val, "fsid", 0)
      if id != 0 && !Builtins.contains(added_fsids, id)
        part_id = Ops.add(
          Ops.add(Partitions.ToHexString(id), " "),
          Partitions.FsIdToString(id)
        )
        items = Builtins.add(items, Item(Id(part_id), part_id, true))
      end

      so = {
        "0x83" => 0,
        "0x8"  => 1,
        "0xF"  => 2,
        "0x00" => 7,
        "0x10" => 6,
        "0x0"  => 3
      }
      val = {}
      Builtins.foreach(items) { |t| Ops.set(val, Ops.get_string(t, 1, ""), 5) }
      Builtins.foreach(val) { |s, i| Builtins.foreach(so) do |match, w|
        found = false
        if !found && Builtins.search(s, match) == 0
          Ops.set(val, s, w)
          found = true
        end
      end }
      items = Builtins.sort(items) do |a, b|
        Ops.less_or_equal(
          Ops.get(val, Ops.get_string(a, 1, ""), 5),
          Ops.get(val, Ops.get_string(b, 1, ""), 5)
        )
      end

      ComboBox(
        Id(:fsid_point),
        Opt(:notify, :editable, :hstretch),
        # label text
        _("File system &ID:"),
        items
      )
    end


    # used by autoyast
    def FormatDlg(new_val, file_systems)
      new_val = deep_copy(new_val)
      file_systems = deep_copy(file_systems)
      Builtins.y2debug("FormatDlg val:%1", new_val)

      fsid = Empty()

      if Ops.get_symbol(new_val, "type", :primary) != :lvm &&
          Ops.get_symbol(new_val, "type", :primary) != :sw_raid &&
          Ops.get_symbol(new_val, "type", :primary) != :loop &&
          !Partitions.no_fsid_menu
        fsid = VBox(
          HBox(
            HSpacing(2),
            ReplacePoint(Id(:fsid_dlg_rp), FsidComboBox(new_val, file_systems))
          ),
          VSpacing(0.5),
          VStretch()
        )
      else
        fsid = VSpacing(0.5)
      end

      # label text
      Frame(
        _("Format"),
        RadioButtonGroup(
          Id(:format),
          VBox(
            VSpacing(1),
            # button text
            Left(
              RadioButton(
                Id(:format_false),
                Opt(:notify),
                _("Do &not format"),
                !Ops.get_boolean(new_val, "format", false)
              )
            ),
            fsid,
            Left(
              RadioButton(
                Id(:format_true),
                Opt(:notify),
                # button text
                _("&Format"),
                Ops.get_boolean(new_val, "format", false)
              )
            ),
            HBox(HSpacing(2), FileSystemsComboBox(new_val, file_systems)),
            CryptButton(new_val),
            VSpacing(0.5)
          )
        )
      )
    end


    # Change the state of all symbol from the list symbols
    # @parm symbols all symbols
    # @parm what true or false
    # @return nil
    def ChangeExistingSymbolsState(symbols, what)
      symbols = deep_copy(symbols)
      Builtins.foreach(symbols) do |sym|
        UI.ChangeWidget(Id(sym), :Enabled, what)
      end

      nil
    end


    # Dialogpart: Mount part
    # @parm new_val map that contains a partition
    # @parm file_systems filesystem definitions
    # @return [Yast::Term] ComboBox with all mountpoints
    def MountDlg(new_val, mountpoints)
      new_val = deep_copy(new_val)
      mountpoints = deep_copy(mountpoints)
      if mountpoints == nil
        mountpoints = ["/", "/home", Partitions.BootMount, "/var", "/opt", ""]
      end

      if !Builtins.contains(mountpoints, "") &&
          Ops.get_symbol(new_val, "enc_type", :none) == :none
        mountpoints = Builtins.add(mountpoints, "")
      end
      mount = Ops.get_string(new_val, "mount", "")

      if !Builtins.contains(mountpoints, mount)
        mountpoints = Builtins.union([mount], mountpoints)
      end

      dlg = VBox(
        PushButton(
          Id(:fstab_options),
          Opt(:hstretch),
          # button text
          _("Fs&tab Options")
        ),
        VSpacing(1),
        ComboBox(
          Id(:mount_point),
          Opt(:editable, :hstretch, :notify),
          # label text
          _("&Mount Point"),
          mountpoints
        )
      )
      # return term
      deep_copy(dlg)
    end


    def ModifyPartitionInSystemWarningPopup(part, mount)
      # popup text %1 is a partition name, %2 a dirctory
      warning = Builtins.sformat(
        _(
          "\n" +
            "The selected partition (%1) is currently mounted on %2.\n" +
            "If you change parameters (such as the mount point or the file system type),\n" +
            "your Linux installation might be damaged.\n" +
            "\n" +
            "Unmount the partition if possible. If you are unsure,\n" +
            "we recommend to abort. Do not proceed unless you know\n" +
            "exactly what you are doing.\n" +
            "\n" +
            "Continue?\n"
        ),
        part,
        mount
      )

      ret = false

      ret = Popup.YesNo(warning)

      ret
    end


    def FsysCannotShrinkPopup(ask, lvm)
      ret = true
      txt = ""
      if !lvm
        # Popup text
        txt = _(
          "\n" +
            "The file system on the partition cannot be shrunk by YaST2.\n" +
            "Only fat, ext2, ext3, ext4, and reiser allow shrinking of a file system."
        )
      else
        # Popup text
        txt = _(
          "\n" +
            "The file system on the logical volume cannot be shrunk by YaST2.\n" +
            "Only fat, ext2, ext3, ext4, and reiser allow shrinking of a file system."
        )
      end
      if ask
        txt = Ops.add(txt, "\n")
        if !lvm
          # Popup text
          txt = Ops.add(
            txt,
            _("You risk losing data if you shrink this partition.")
          )
        else
          # Popup text
          txt = Ops.add(
            txt,
            _("You risk losing data if you shrink this logical volume.")
          )
        end
        txt = Ops.add(txt, "\n\n")
        txt = Ops.add(txt, _("Continue?"))
      end
      if ask
        ret = Popup.YesNo(txt)
      else
        Popup.Error(txt)
        ret = false
      end
      ret
    end

    def FsysCannotGrowPopup(ask, lvm)
      ret = true
      txt = ""
      if !lvm
        # Popup text
        txt = _(
          "\n" +
            "The file system on the selected partition cannot be extended by YaST2.\n" +
            "Only fat, ext2, ext3, ext4, xfs, and reiser allow extending a file system."
        )
      else
        # Popup text
        txt = _(
          "\n" +
            "The file system on the selected logical volume cannot be extended by YaST2.\n" +
            "Only fat, ext2, ext3, ext4, xfs, and reiser allow extending a file system."
        )
      end
      if ask
        txt = Ops.add(txt, "\n\n")
        txt = Ops.add(txt, _("Continue resizing?"))
      end
      if ask
        ret = Popup.YesNo(txt)
      else
        Popup.Error(txt)
        ret = false
      end
      ret
    end


    def FsysShrinkReiserWarning(lvm)
      ret = true
      txt = ""
      if !lvm
        # Popup text
        txt = _("You decreased a partition with a reiser file system on it.")
      else
        txt = _(
          "You decreased a logical volume with a reiser file system on it."
        )
      end
      txt = Ops.add(txt, "\n")
      txt = Ops.add(
        txt,
        _(
          "\n" +
            "It is possible to shrink a reiser file system, but this feature is not\n" +
            "very thoroughly tested. A backup of your data is recommended.\n" +
            "\n" +
            "Shrink the file system now?"
        )
      )
      ret = Popup.YesNo(txt)
      ret
    end


    #FIXME: y2-repair uses this, need to find
    #a better place for it
    def ReallyInstPrepdisk
      ret = :none

      doto = Storage.ChangeText
      Builtins.y2milestone("ReallyInstPrepdisk doto:%1", doto)

      if Builtins.size(doto) == 0
        # popup text
        Popup.Message(_("No unsaved changes exist."))
        ret = :back
      else
        dlg = VBox(
          VSpacing(1),
          HSpacing(60),
          # label text
          Left(Heading(_("Changes:"))),
          RichText(doto)
        )

        UI.OpenDialog(
          Opt(:decorated, :warncolor),
          HBox(
            HSpacing(1),
            VBox(
              dlg,
              VSpacing(1),
              # popup text
              Heading(_(" Do you really want to execute these changes?")),
              VSpacing(1),
              HBox(
                PushButton(Id(:back), Label.CancelButton),
                HStretch(),
                # button text
                PushButton(Id(:apply), _("&Apply")),
                PushButton(Id(:finish), Label.FinishButton)
              ),
              VSpacing(0.2)
            ),
            HSpacing(1)
          )
        )

        ret = Convert.to_symbol(UI.UserInput)
        UI.CloseDialog
      end

      Builtins.y2milestone("ReallyInstPrepdisk ret=%1", ret)

      ret
    end


    # Delete all partition in targetMap from the device "del_dev" and return
    # a new targetMap.
    # Check if LVM partition exists on the device.
    # Check if at least on partition is mounted.
    # @return [Hash] targetMap
    def deleteAllDevPartitions(disk, installation)
      disk = deep_copy(disk)
      go_on = true
      del_dev = Ops.get_string(disk, "device", "")
      Builtins.y2milestone(
        "deleteAllDevPartitions disk:%1",
        Builtins.remove(disk, "partitions")
      )

      #///////////////////////////////////////////////////////////////
      # check mount points if not installation

      if !installation
        mounts = Storage.mountedPartitionsOnDisk(del_dev)
        if Builtins.size(mounts) != 0
          #///////////////////////////////////////////////////////
          # mount points found

          mounted_parts = ""
          Builtins.foreach(mounts) do |mount|
            #  %1 is replaced by device name, %1 by directory e.g /dev/hdd1 on /opt
            mounted_parts = Ops.add(
              Ops.add(
                mounted_parts,
                Builtins.sformat(
                  "%1 on %2",
                  Ops.get_string(mount, "device", ""),
                  Ops.get_string(mount, "mount", "")
                )
              ),
              "\n"
            )
          end

          # popup text, %1 is replaced by device name
          message = Builtins.sformat(
            _(
              "The selected device contains partitions that are currently mounted:\n" +
                "%1\n" +
                "We *strongly* recommended to unmount these partitions before deleting the partition table.\n" +
                "Choose Cancel unless you know exactly what you are doing.\n"
            ),
            mounted_parts
          )

          go_on = false if !Popup.ContinueCancel(message)
        end
      end

      if go_on
        partitions = Ops.get_list(disk, "partitions", [])

        used = check_devices_used(partitions, false)

        go_on = used == :UB_NONE

        if used == :UB_LVM
          # popup text, Do not translate LVM.
          Popup.Message(
            _(
              "\n" +
                "The selected device contains at least one LVM partition\n" +
                "assigned to a volume group. Remove all\n" +
                "partitions from their respective volume groups\n" +
                "before deleting the device.\n"
            )
          )
        elsif used == :UB_MD
          # popup text, Do not translate RAID.
          Popup.Message(
            _(
              "\n" +
                "The selected device contains at least one partition\n" +
                "that is part of a RAID system. Unassign the\n" +
                "partitions from their respective RAID systems before\n" +
                "deleting the device.\n"
            )
          )
        elsif used != :UB_NONE
          # popup text
          Popup.Message(
            _(
              "\n" +
                "The selected device contains at least one partition\n" +
                "that is used by another volume. Delete the volume using it\n" +
                "before deleting the device.\n"
            )
          )
        end

        if go_on && Ops.get_symbol(disk, "type", :CT_UNKNONW) != :CT_DMRAID
          #///////////////////////////////////////////////
          # delete all partitions of disk
          # logical partitions get removed when extended is deleted
          dp = Builtins.filter(partitions) do |part|
            Ops.less_or_equal(
              Ops.get_integer(part, "nr", 0),
              Ops.get_integer(disk, "max_primary", 4)
            )
          end
          Builtins.y2milestone("deleteAllDevPartitions dp:%1", dp)
          dp = Builtins.sort(dp) do |a, b|
            Ops.greater_than(
              Ops.get_integer(a, "nr", 0),
              Ops.get_integer(b, "nr", 0)
            )
          end
          Builtins.y2milestone("deleteAllDevPartitions dp:%1", dp)
          Builtins.foreach(dp) do |part|
            go_on = go_on &&
              Storage.DeleteDevice(Ops.get_string(part, "device", ""))
          end
        end
      end
      Builtins.y2milestone("deleteAllDevPartitions ret:%1", go_on)
      go_on
    end

    def SubvolNames(data)
      data = deep_copy(data)
      items = Builtins.maplist(
        Builtins.filter(Ops.get_list(data, "subvol", [])) do |s|
          if Ops.get_boolean(data, "format", false)
            next Ops.get_boolean(s, "create", false)
          else
            next !Ops.get_boolean(s, "delete", false)
          end
        end
      ) { |p| Ops.get_string(p, "name", "") }
      Builtins.y2milestone("items:%1", items)
      deep_copy(items)
    end


    # Dialog: Subvolume handling
    # @parm old map with original partition
    # @parm new map with changes filled in
    def SubvolHandling(old, new)
      old = deep_copy(old)
      new = deep_copy(new)

      # help text, richtext format
      helptext = _(
        "<p>Create and remove subvolumes from a Btrfs filesystem.</p>\n"
      )

      if Mode.installation()
        helptext += _(
          "<p>Enable automatic snapshots for a Btrfs filesystem with snapper.</p>"
        )
      end

      old_subvol = Ops.get_list(new, "subvol", [])
      old_userdata = Ops.get_map(new, "userdata", {})

      items = SubvolNames(new)

      contents = VBox(
        # label text
        MinHeight(
          10,
          SelectionBox(Id(:subvol), _("Existing Subvolumes:"), items)
        ),
        TextEntry(
          Id(:new_path),
          Opt(:hstretch),
          # label text
          _("New Subvolume")
        ),
        HBox(
          PushButton(
            Id(:add),
            # button text
            _("Add new")
          ),
          HSpacing(2),
          PushButton(
            Id(:remove),
            # button text
            _("Remove")
          )
        )
      )

      if Mode.installation()
        contents = Builtins.add(contents, VSpacing(0.5))
        contents = Builtins.add(contents,
          Left(
            CheckBox(
              Id(:snapshots),
              # TRANSLATOR: checkbox text
              _("Enable Snapshots")
            )
          )
        )
      end

      UI.OpenDialog(
        Opt(:decorated),
        VBox(
          HSpacing(50),
          # heading text
          Heading(_("Subvolume Handling")),
          VStretch(),
          VSpacing(1),
          HBox(HStretch(), HSpacing(1), contents, HStretch(), HSpacing(1)),
          VSpacing(1),
          VStretch(),
          ButtonBox(
            PushButton(Id(:help), Opt(:helpButton), Label.HelpButton),
            PushButton(Id(:ok), Opt(:default), Label.OKButton),
            PushButton(Id(:cancel), Label.CancelButton)
          )
        )
      )

      UI.ChangeWidget(Id(:snapshots), :Value, old_userdata["/"] == "snapshots")

      UI.ChangeWidget(:help, :HelpText, helptext)

      ret = :ok
      changed = false
      begin
        ret = UI.UserInput
        Builtins.y2milestone("SubvolHandling ret %1", ret)
        if ret == :remove
          pth = Convert.to_string(UI.QueryWidget(Id(:subvol), :CurrentItem))
          Builtins.y2milestone("SubvolHandling remove path:%1", pth)
          Builtins.y2milestone(
            "SubvolHandling remove subvol:%1",
            Ops.get_list(new, "subvol", [])
          )
          Ops.set(
            new,
            "subvol",
            Builtins.maplist(Ops.get_list(new, "subvol", [])) do |p|
              if Ops.get_string(p, "name", "") == pth
                Ops.set(p, "delete", true)
                p = Builtins.remove(p, "create")
              end
              deep_copy(p)
            end
          )
          Builtins.y2milestone(
            "SubvolHandling remove subvol:%1",
            Ops.get_list(new, "subvol", [])
          )
          items = SubvolNames(new)
          Builtins.y2milestone("SubvolHandling remove items:%1", items)
          changed = true
          UI.ChangeWidget(Id(:subvol), :Items, items)
        end
        if ret == :add
          pth = Convert.to_string(UI.QueryWidget(Id(:new_path), :Value))
          svtmp = Ops.add(FileSystems.default_subvol, "/")
          Builtins.y2milestone(
            "SubvolHandling add path:%1 svtmp:%2",
            pth,
            svtmp
          )
          Builtins.y2milestone("SubvolHandling names:%1", SubvolNames(new))
          if pth == nil || Builtins.size(pth) == 0
            Popup.Message(_("Empty subvolume name not allowed."))
          elsif Ops.greater_than(Builtins.size(FileSystems.default_subvol), 0) &&
              Builtins.substring(pth, 0, Builtins.size(svtmp)) != svtmp
            tmp = Builtins.sformat(
              _(
                "Only subvolume names starting with \"%1\" currently allowed!\nAutomatically prepending \"%1\" to name of subvolume."
              ),
              svtmp
            )
            Popup.Message(tmp)
          end
          if Builtins.contains(SubvolNames(new), pth)
            Popup.Message(
              Builtins.sformat(_("Subvolume name %1 already exists."), pth)
            )
          else
            Ops.set(
              new,
              "subvol",
              Builtins.add(
                Ops.get_list(new, "subvol", []),
                { "create" => true, "name" => pth }
              )
            )
            changed = true
          end
          items = SubvolNames(new)
          UI.ChangeWidget(Id(:subvol), :Items, items)
          UI.ChangeWidget(Id(:new_path), :Value, "")
        end

        if ret == :ok
          val = UI.QueryWidget(Id(:snapshots), :Value)
          if val
            old_userdata["/"] = "snapshots"
          else
            old_userdata.delete("/")
          end
          Ops.set(new, "userdata", old_userdata)
        end

        if ret == :cancel
          if changed
            if Popup.YesNo(
                _("Modifications done so far in this dialog will be lost.")
              )
              Ops.set(new, "subvol", old_subvol)
            else
              ret = :again
            end
          end
        end
      end until ret == :ok || ret == :cancel

      UI.CloseDialog

      Builtins.y2milestone(
        "SubvolHandling subvol:%1 userdata:%2",
        Ops.get_list(new, "subvol", []),
        Ops.get_map(new, "userdata", {})
      )
      deep_copy(new)
    end

  end
end
