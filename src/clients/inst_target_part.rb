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

# Module:		inst_target_part.ycp
#
# Authors:		Andreas Schwab (schwab@suse.de)
#			Klaus Kämpf (kkaempf@suse.de)
#
# Purpose:		This module ask the user which partition to use:
#			-Determing possible partitions.
#			-Ask the user which partition to use.
#			-Check the input and return error-messages.
#
# $Id$
module Yast
  class InstTargetPartClient < Client
    def main

      textdomain "storage"

      Yast.import "UI"
      Yast.import "Mode"
      Yast.import "Popup"
      Yast.import "Storage"
      Yast.import "StorageProposal"
      Yast.import "Partitions"
      Yast.import "Product"
      Yast.import "Label"

      # flag for deleting a windows partition
      @win_partition_to_delete = -1

      # this is the device name !
      @target_is = Storage.GetPartDisk

      # fall through to inst_custom_part if target_is not "USE_DISK"
      if Storage.GetPartMode != "USE_DISK" || Storage.GetCustomDisplay
        return Storage.GetExitKey
      end

      # Get test_mode flag from module Mode
      @test_mode = Mode.test

      #-------------------------------------------------------------------------
      # The action
      #-------------------------------------------------------------------------

      @max_partitions = 0

      # The partition number of the first logical partition
      @first_logical_nr = 5

      @max_primary = 0
      # this will tell if automatic partitioning if feasible
      @can_do_auto = false

      @unused_region = [0, 0]

      Yast.include self, "partitioning/auto_part_functions.rb"
      Yast.include self, "partitioning/auto_part_prepare.rb"
      Yast.include self, "partitioning/auto_part_ui.rb"
      Yast.include self, "partitioning/auto_part_create.rb"
      Yast.include self, "partitioning/custom_part_dialogs.rb"

      @win_partition = {} # may be needed later in the resize case (is also a flag)

      # --------------------------------------------------------------
      # find the selected target in the map of all possible targets

      @targetMap = Storage.GetTargetMap

      # description of the choosen target disk
      @target = Ops.get(@targetMap, @target_is, {})

      if @target == {}
        # popup text
        Popup.Message(
          _(
            "Your system can only be configured with the custom partitioning option."
          )
        )
        return :back
      end

      # user visible name of target
      @targetname = Ops.get_string(
        @target,
        "proposal_name",
        Ops.get_string(@target, "device", "?")
      )

      # The current list of partitions
      @partitions = Ops.get_list(@target, "partitions", [])

      #-------------------------------------------------------------------------
      # The action
      #-------------------------------------------------------------------------


      # --------------------------------------------------------------
      # general settings for automatically created partitions

      @max_partitions = compute_max_partitions(@target)

      # The number of possible primary partitions
      @max_primary = Ops.get_integer(@target, "max_primary", 4)

      #==================================================================
      #
      # prepare_partitions
      #
      #=================================================================

      @partitions = prepare_partitions(@target, @partitions)

      SCR.Write(
        path(".target.ycp"),
        Storage.SaveDumpPath("prepared_partitions"),
        @partitions
      )

      @vbox = Empty()

      # show list of partitions if any found (else the disk is completely unpartitioned

      if Ops.greater_than(num_primary(@partitions), 0) ||
          contains_extended(@partitions)
        # If there is an unpartitioned area on the disk, ask user to use it
        # (this will automatically partition this area)

        if !@can_do_auto
          # There was not enough space to install Linux.
          # Check if we could delete/shrink a windows partition.
          #
          @win_partition = can_resize(@partitions)
        end

        if @win_partition != {}
          # this is the resize case
          #
          @vbox = create_resize_dialog(
            @partitions,
            Ops.get_integer(@target, "cyl_size", 1)
          )
          @vbox = Builtins.add(@vbox, VSpacing(1.5))
          @vbox = Builtins.add(@vbox, PushButton(Id(:settings), _("Edit Proposal Settings")))
          Builtins.y2milestone("can resize !")
        else
          # this is the normal case
          #
          @tmp = construct_partition_dialog(
            @partitions,
            Ops.get_string(@target, "label", ""),
            Ops.get_integer(@target, "cyl_size", 1)
          )
          @vbox = Builtins.add(
            Ops.get_term(@tmp, "term", VBox()),
            VBox(
              VSpacing(1.5),
              PushButton(Id(:settings), _("Edit Proposal Settings"))
            )
          )
        end
      else
        @vbox = create_whole_disk_dialog
        @vbox = Builtins.add(@vbox, VSpacing(1.5))
        @vbox = Builtins.add(@vbox, PushButton(Id(:settings), _("Edit Proposal Settings")))
      end

      # Since resize case and normal case have different help texts we need
      # to open different dialogs
      #
      if @win_partition != {}
        open_auto_dialog_resize(@targetname, @vbox)
      else
        open_auto_dialog(@targetname, @vbox)
      end

      @disable_full = false
      if Mode.live_installation
        @partitions = Builtins.maplist(@partitions) do |p|
          if Ops.get_string(p, "mount", "") == "swap" &&
              Storage.TryUnaccessSwap(Ops.get_string(p, "device", ""))
            Ops.set(p, "mount", "")
          end
          deep_copy(p)
        end
        Ops.set(@target, "partitions", @partitions)
      end
      Builtins.foreach(@partitions) do |p|
        Builtins.y2milestone("p:%1", p)
        if Ops.get_symbol(p, "type", :unknown) != :extended &&
            !Storage.CanDelete(p, @target, false)
          if UI.WidgetExists(Id(Ops.get_integer(p, "ui_id", 0)))
            UI.ChangeWidget(Id(Ops.get_integer(p, "ui_id", 0)), :Enabled, false)
            @disable_full = true
          end
        end
      end
      if @disable_full && UI.WidgetExists(Id(:full))
        UI.ChangeWidget(Id(:full), :Enabled, false)
      end

      # Event handling

      @ret = nil
      StorageProposal.SetCreateVg(true)

      @ok = false
      while !@ok
        @ret = Convert.to_symbol(Wizard.UserInput)
        Builtins.y2milestone("USERINPUT ret %1", @ret)

        if @ret == :abort && Popup.ReallyAbort(true)
          break
        elsif @ret == :settings
          StorageProposal.CommonWidgetsPopup()
        elsif @ret == :full
          # Set all checkboxes
          Builtins.foreach(@partitions) do |pentry|
            ptype = Ops.get_symbol(pentry, "type", :unknown)
            ui_id = 0
            if ptype != :extended &&
                Ops.get_integer(pentry, "fsid", 0) != Partitions.fsid_mac_hidden
              ui_id = Ops.get_integer(pentry, "ui_id", 0)
              UI.ChangeWidget(Id(ui_id), :Value, true) if ui_id != 0
            end
          end
        elsif @ret == :back
          @ok = true
        elsif @ret == :next
          @ok = true
          if @ok && @win_partition != {}
            if UI.QueryWidget(Id(:resize), :Value) == true
              # The user decided to shrink his windows.
              # Check if this is Windows NT or Windows 2000 (curently not supported)
              #
              @local_ret = check_win_nt_system(@target)

              if @test_mode
                # In test mode we _always_ assume there is no system that could cause problem
                # so the windows resizer is always accessible (e.g. for screen shots).
                @local_ret = 0
              end

              if @local_ret == 1 # Win NT / 2000
                # The Windows version is Windows NT or Windows 2000. Tell the user that this is currently
                # not supported and that he can go back in the installation or abort it.
                @explanation2 = Builtins.sformat(
                  _(
                    "An error has occurred.\n" +
                      "\n" +
                      "The Windows version on your system is \n" +
                      "not compatible with the resizing tool.\n" +
                      "Shrinking your Windows partition is not possible.\n" +
                      "\n" +
                      "Choose a different disk or abort the installation and\n" +
                      "shrink your Windows partition by other means.\n"
                  )
                )

                @ret = allow_back_abort_only(@explanation2)

                return @ret
              elsif @local_ret == 2 # local error
                # The Windows version used could not be determined. Tell the user
                # he can go back in the installation or abort it.
                @explanation2 = Builtins.sformat(
                  _(
                    "The Windows version of your system could not be determined.\n" +
                      "\n" +
                      "It is therefore not possible to shrink your Windows partition.\n" +
                      "\n" +
                      "Choose a different disk or abort the installation and\n" +
                      "shrink your Windows partition by other means.\n"
                  )
                )

                @ret = allow_back_abort_only(@explanation2)

                return @ret
              end

              # OK --> No NT or 2000

              # Tell the user about the risks of resizing his windows.
              # Ask him if he really wants to do it

              @explanation = Builtins.sformat(
                _(
                  "You selected to shrink your Windows partition.\n" +
                    "In the next dialog, specify the amount of\n" +
                    "Windows space that should be freed for %1.\n" +
                    "\n" +
                    "A data backup is strongly recommended\n" +
                    "because data must be reorganized. \n" +
                    "Under rare circumstances, this could fail.\n" +
                    "\n" +
                    "Only continue if you have successfully run\n" +
                    "the Windows system applications scandisk and defrag.\n" +
                    "\n" +
                    "Really shrink your Windows partition?\n"
                ),
                Product.name
              )

              if !Popup.AnyQuestion(
                  Popup.NoHeadline,
                  @explanation,
                  # button text
                  _("&Shrink Windows"),
                  Label.CancelButton,
                  :focus_yes
                )
                next
              end
              @fat_nr = Ops.add("", Ops.get_integer(@win_partition, "nr", -1))
              Builtins.y2milestone(
                "Partition '%1' selected for resize",
                @fat_nr
              )
              Storage.SetDoResize(@fat_nr)
              break
            else
              # Tell the user about the consequences of deleting his windows.
              # Ask him if he really wants to do it
              @explanation = _(
                "You selected to delete your Windows partition completely.\n" +
                  "\n" +
                  "All data on this partition will be lost in the process.\n" +
                  "\n" +
                  "Really delete your Windows partition?\n"
              )
              if !Popup.AnyQuestion(
                  Popup.NoHeadline,
                  @explanation,
                  # button text
                  _("&Delete Windows"),
                  Label.CancelButton,
                  :focus_yes
                )
                next
              end
              Builtins.y2milestone("Don't resize, use entire partition")
              Storage.SetDoResize("NO")
              @win_partition_to_delete = Builtins.tointeger(
                Ops.get_integer(@win_partition, "nr", -1)
              )
            end
          end

          # this will be set when the first win partition is marked
          # for deletion in the foreach() loop
          @windows_part_marked_for_deletion = false

          # now loop through partitions and check
          # if the partition is selected
          @all_del = true
          @partitions = Builtins.maplist(@partitions) do |p|
            Builtins.y2milestone("p:%1", p)
            ptype = Ops.get_symbol(p, "type", :unknown)
            ui_id = 0
            if ptype != :extended
              ui_id = Ops.get_integer(p, "ui_id", 0)
              selection = Ops.get_integer(p, "fsid", 0) !=
                Partitions.fsid_mac_hidden &&
                (!UI.WidgetExists(Id(ui_id)) ||
                  UI.QueryWidget(Id(ui_id), :Value) == true)
              Builtins.y2milestone("sel:%1", selection)

              if @win_partition_to_delete == Ops.get_integer(p, "nr", -2)
                selection = true
                @windows_part_marked_for_deletion = true
                Builtins.y2milestone(
                  "Windows partition marked for deletion: <%1>",
                  @win_partition_to_delete
                )
              elsif @windows_part_marked_for_deletion &&
                  Ops.get_symbol(p, "type", :dummy) == :free
                # trailing free partition after (deleted) windows partition
                selection = true
                Builtins.y2milestone(
                  "Trailing `free partition marked for deletion"
                )
              end
              Ops.set(p, "delete", selection)
              if @all_del &&
                  !selection && Ops.get_symbol(p, "type", :dummy) != :free
                @all_del = false
              end
            end
            deep_copy(p)
          end

          if !@all_del && StorageProposal.NeedNewDisklabel(@target)
            Popup.Error(ia64_gpt_fix_text)
            @ok = false
          end
          if @ok
            @partitions = StorageProposal.try_remove_sole_extended(@partitions)
            Builtins.y2milestone("partitions '%1'", @partitions)

            @ok = create_partitions(@targetMap, @target, @partitions)
            if !@ok
              @reason = _(
                "Too few partitions are marked for removal or \n" +
                  "the disk is too small. \n" +
                  "To install Linux, select more partitions to \n" +
                  "remove or select a larger disk."
              )
              display_error_box(@reason)
            end
            @tg = Storage.GetTargetMap
            @pl = Ops.get_list(@tg, [@target_is, "partitions"], [])
            if Builtins.haskey(@tg, "/dev/system")
              @pl = Convert.convert(
                Builtins.union(
                  @pl,
                  Ops.get_list(@tg, ["/dev/system", "partitions"], [])
                ),
                :from => "list",
                :to   => "list <map>"
              )
            end
            Builtins.y2milestone("proposed partitions:%1", @pl)
            if StorageProposal.GetProposalHome &&
                Builtins.size(Builtins.filter(@pl) do |p|
                  Ops.get_string(p, "mount", "") == "/home"
                end) == 0
              @ok = false
              @reason = _(
                "Not enough space available to propose separate /home."
              )
              Popup.Error(@reason)
            end
          end
        end
      end # while (true)

      Storage.RestoreTargetBackup("disk") if @ret == :back || @ret == :abort
      Storage.SaveExitKey(@ret)

      @ret
    end

    # Displays a popup with the message (can be dismissed with OK).
    # After that only `abort or `back is allowed
    # Every other user action ==> redisplay message
    # Parameter: message to be displayed
    # Return   : `back or `abort
    #
    def allow_back_abort_only(message)
      ret = :next

      # Enable back and next buttons independent of the settings
      # in installation.ycp so the user has a chance to see the
      # popup more than only once.
      #
      Wizard.EnableNextButton
      Wizard.EnableBackButton
      begin
        Popup.Message(message) # Display the message

        ret = Convert.to_symbol(UI.UserInput) # get user input

        if ret == :abort
          if !Popup.ReallyAbort(true)
            # user didn't want to abort ==> stay in loop
            ret = :dummy
          end
        end
      end until ret == :abort || ret == :back

      ret
    end
  end
end

Yast::InstTargetPartClient.new.main
