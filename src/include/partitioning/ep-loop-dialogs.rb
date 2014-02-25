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
  module PartitioningEpLoopDialogsInclude
    def initialize_partitioning_ep_loop_dialogs(include_target)
      textdomain "storage"
    end

    def MiniWorkflowStepLoopNameSizeHelptext
      # TODO

      # helptext
      helptext = _(
        "\n" +
          "<p><b>Path Name of Loop File:</b><br>This must be an absolute path to the file\n" +
          "containing the data for the encrypted loop device to set up.</p>\n"
      )

      # helptext
      helptext = Ops.add(
        helptext,
        _(
          "\n" +
            "<p><b>Create Loop File:</b><br>If this is checked, the file will be created\n" +
            "with the size given in the next field. <b>NOTE:</b> If the file already\n" +
            "exists, all data in it is lost.</p>\n"
        )
      )

      # helptext
      helptext = Ops.add(
        helptext,
        _(
          "\n" +
            "<p><b>Size:</b><br>This is the size of the loop file.  The file system\n" +
            "created in the encrypted loop device will have this size.</p>\n"
        )
      )

      # helptext
      helptext = Ops.add(
        helptext,
        _(
          "\n" +
            "<p><b>NOTE:</b> During installation, YaST cannot carry out consistency\n" +
            "checks of file size and path names because the file system is not\n" +
            "accessible. It will be created at the end of the installation. Be\n" +
            "careful when providing the size and path name.</p>\n"
        )
      )

      helptext
    end


    def MiniWorkflowStepLoopNameSize(data)
      Builtins.y2milestone("MiniWorkflowStepLoopNameSize data:%1", data.value)

      min_size_k = 1024
      size_k = Ops.get_integer(data.value, "size_k", 50 * 1024)
      fpath = Ops.get_string(data.value, "fpath", "")
      create_file = Ops.get_boolean(data.value, "create_file", false)

      contents = HVSquash(
        VBox(
          # input field label
          Left(
            MinWidth(
              25,
              InputField(
                Id(:fpath),
                Opt(:hstretch),
                _("Path Name of Loop File"),
                fpath
              )
            )
          ),
          # push button text
          Mode.normal ?
            Left(PushButton(Id(:browse), _("Browse..."))) :
            Empty(),
          VSpacing(0.75),
          # check box text
          term(
            :LeftCheckBoxWithAttachment,
            Id(:create_file),
            Opt(:notify),
            _("Create Loop File"),
            # input field label
            MinWidth(
              15,
              InputField(
                Id(:size),
                Opt(:shrinkable),
                _("Size"),
                Storage.KByteToHumanString(size_k)
              )
            )
          )
        )
      )

      MiniWorkflow.SetContents(
        Greasemonkey.Transform(contents),
        MiniWorkflowStepLoopNameSizeHelptext()
      )
      MiniWorkflow.SetLastStep(false)

      UI.ChangeWidget(Id(:create_file), :Value, create_file)
      UI.ChangeWidget(Id(:size), :Enabled, create_file)

      widget = nil
      begin
        widget = MiniWorkflow.UserInput

        case widget
          when :browse
            @tmp = UI.AskForExistingFile("/", "*", "")
            fpath = @tmp if @tmp != nil
            UI.ChangeWidget(Id(:fpath), :Value, fpath)

            if Mode.normal
              s = Convert.to_integer(SCR.Read(path(".target.size"), fpath))
              create_file = Ops.less_than(s, 0)
              UI.ChangeWidget(Id(:create_file), :Value, create_file)
            end
          when :create_file
            create_file = Convert.to_boolean(
              UI.QueryWidget(Id(:create_file), :Value)
            )
            UI.ChangeWidget(Id(:size), :Enabled, create_file)
          when :next
            fpath = Convert.to_string(UI.QueryWidget(Id(:fpath), :Value))

            if fpath == "" || Builtins.substring(fpath, 0, 1) != "/"
              # popup text
              Popup.Error(
                Builtins.sformat(
                  _(
                    "The file name \"%1\" is invalid.\nUse an absolute path name.\n"
                  ),
                  fpath
                )
              )
              widget = :again
              next
            end

            if create_file
              tmp = Convert.to_string(UI.QueryWidget(Id(:size), :Value))
              if !(
                  size_k_ref = arg_ref(size_k);
                  _HumanStringToKByteWithRangeCheck_result = Storage.HumanStringToKByteWithRangeCheck(
                    tmp,
                    size_k_ref,
                    min_size_k,
                    nil
                  );
                  size_k = size_k_ref.value;
                  _HumanStringToKByteWithRangeCheck_result
                )
                # error popup, %1 is replaced by size
                Popup.Error(
                  Builtins.sformat(
                    _(
                      "The size entered is invalid. Enter a size of at least %1."
                    ),
                    Storage.KByteToHumanString(min_size_k)
                  )
                )
                widget = :again
                next
              end
            else
              s = Convert.to_integer(SCR.Read(path(".target.size"), fpath))
              Builtins.y2milestone("loop file size:%1", s)

              if Mode.normal
                if Ops.less_than(s, 0)
                  # popup text
                  Popup.Error(
                    Builtins.sformat(
                      _(
                        "The file name \"%1\" does not exist\n" +
                          "and the flag for create is off. Either use an existing file or activate\n" +
                          "the create flag."
                      ),
                      fpath
                    )
                  )
                  widget = :again
                  next
                else
                  size_k = Ops.divide(s, 1024)
                end
              end
            end
        end
      end until widget == :abort || widget == :back || widget == :next

      if widget == :next
        Ops.set(data.value, "fpath", fpath)
        Ops.set(data.value, "create_file", create_file)
        Ops.set(data.value, "size_k", size_k)
      end

      Builtins.y2milestone(
        "MiniWorkflowStepLoopNameSize data:%1 ret:%2",
        data.value,
        widget
      )

      widget
    end


    def DlgCreateLoop(data)
      aliases = {
        "NameSize"    => lambda do
          (
            data_ref = arg_ref(data.value);
            _MiniWorkflowStepLoopNameSize_result = MiniWorkflowStepLoopNameSize(
              data_ref
            );
            data.value = data_ref.value;
            _MiniWorkflowStepLoopNameSize_result
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
        "NameSize"    => { :next => "FormatMount" },
        "FormatMount" => { :next => "Password", :finish => :finish },
        "Password"    => { :finish => :finish }
      }

      # dialog title
      title = _("Add Crypt File")

      widget = MiniWorkflow.Run(
        title,
        StorageIcons.loop_icon,
        aliases,
        sequence,
        "NameSize"
      )

      widget == :finish
    end


    def DlgEditLoop(data)
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
      title = Builtins.sformat(_("Edit Crypt File %1"), device)

      widget = MiniWorkflow.Run(
        title,
        StorageIcons.loop_icon,
        aliases,
        sequence,
        "FormatMount"
      )

      widget == :finish
    end
  end
end
