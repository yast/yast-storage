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

# Module: 		inst_target_selection.ycp
#
# Authors: 		Klaus Kaempf (kkaempf@suse.de)
#
# Purpose: 		This module selects the harddisk(s) for installation.
#			-Harddisk recognition
#			-Selecting the harddisk for the installation by
#			 the user ( if possible harddisks > 1 ).
#			-Write selected harddisk(s) with SetPartDisk into
#                       Storage
#                      "target_is":<devicename> (key to "targets" map)
#			if custom, set "target_is":"CUSTOM"
#
# $Id$
module Yast
  class InstTargetSelectionClient < Client
    def main
      Yast.import "UI"
      textdomain "storage"

      Yast.import "Arch"
      Yast.import "Mode"
      Yast.import "Stage"
      Yast.import "Popup"
      Yast.import "Partitions"
      Yast.import "Wizard"
      Yast.import "Storage"
      Yast.import "StorageFields"

      Yast.include self, "partitioning/custom_part_helptexts.rb"

      #////////////////////////////////////////////////////
      # look what inst_part_propose has said:

      Builtins.y2milestone("GetPartMode %1", Storage.GetPartMode)

      return Storage.GetExitKey if Storage.GetPartMode == "PROP_MODIFY"


      #////////////////////////////////////////////////////
      # if we get here in update mode it's a BUG

      return :cancel if Mode.update

      #///////////////////////////////////////////////////////////////////
      # MAIN:
      #///////////////////////////////////////////////////////////////////

      @targetMap = Storage.GetTargetMap

      # Check the partition table for correctness

      @contents = Dummy()

      @custom_val = Storage.GetPartMode == "CUSTOM"
      Builtins.y2milestone("custom_val %1", @custom_val)

      if !Builtins.isempty(@targetMap)
        # loop over targetMap and build radio buttons for selection
        # dont use foreach here since we need a counter (as a shortcut)
        # anyway

        @usable_target_map = Builtins.filter(@targetMap) do |d, e|
          Storage.IsPartitionable(e) &&
            !Builtins.contains(
              [:UB_DMRAID, :UB_DMMULTIPATH, :UB_MDPART],
              Ops.get_symbol(e, "used_by_type", :UB_NONE)
            )
        end

        @dskcnt = Builtins.size(@usable_target_map)
        Builtins.y2milestone("dskcnt:%1", @dskcnt)

        @buttonbox = VBox()

        if Ops.greater_or_equal(@dskcnt, 10)
          @disklist = []
          Builtins.foreach(@usable_target_map) do |tname, tdata|
            tlinename = Ops.get_string(
              tdata,
              "proposal_name",
              Ops.get_string(tdata, "device", "?")
            )
            tline = Builtins.sformat("%1", tlinename)
            @disklist = Builtins.add(@disklist, Item(Id(tname), tline))
          end
          @buttonbox = Builtins.add(
            @buttonbox,
            MinWidth(
              40,
              SelectionBox(
                Id(:disklist),
                Opt(:notify),
                _("Available &Disks"),
                @disklist
              )
            )
          )
        else
          @i = 1
          Builtins.foreach(@usable_target_map) do |tname, tdata|
            tlinename = Ops.get_string(
              tdata,
              "proposal_name",
              Ops.get_string(tdata, "device", "?")
            )
            tline = Builtins.sformat("&%1:    %2", @i, tlinename)
            sel = Storage.GetPartDisk == tname && !@custom_val
            @buttonbox = Builtins.add(
              @buttonbox,
              Left(RadioButton(Id(tname), tline, sel))
            )
            @i = Ops.add(@i, 1)
          end
        end

        @buttonbox = Builtins.add(@buttonbox, VSpacing(0.8))
        # Check box for expert partitioning mode rather than
        # just selecting one of the hard disks and use
        # a standard partitioning scheme
        @buttonbox = Builtins.add(
          @buttonbox,
          Left(
            RadioButton(
              Id("CUSTOM"),
              Opt(:notify),
              # label text
              _("&Custom Partitioning (for experts)"),
              @custom_val
            )
          )
        )

        # This dialog selects the target disk for the installation.
        # Below this label, all targets are listed that can be used as
        # installation target

        # heading text
        @contents = Frame(
          _("Hard Disk"),
          RadioButtonGroup(
            Id(:options),
            VBox(VSpacing(0.4), HSquash(@buttonbox), VSpacing(0.4))
          )
        )
      else
        Builtins.y2milestone("NO targetMap")
        # normally the target is located on hard disks. Here no hard disks
        # can be found. YaST2 cannot install. Update CD might have newer drivers.
        @contents = Label(
          _(
            "No disks found. Try using the update CD, if available, for installation."
          )
        )
      end


      # There are several hard disks found. Linux is completely installed on
      # one hard disk - this selection is done here
      # "Preparing Hard Disk" is the description of the dialog what to
      # do while the following locale is the help description
      # help part 1 of 3
      @helptext = _(
        "<p>\n" +
          "All hard disks automatically detected on your system\n" +
          "are shown here. Select the hard disk on which to install &product;.\n" +
          "</p>\n"
      )
      # help part 2 of 3
      @helptext = Ops.add(
        @helptext,
        _(
          "<p>\n" +
            "You may select later which part of the disk is used for &product;.\n" +
            "</p>\n"
        )
      )
      # help part 3 of 3
      @helptext = Ops.add(
        @helptext,
        _(
          "\n" +
            "<p>\n" +
            "The <b>Custom Partitioning</b> option for experts allows full\n" +
            "control over partitioning the hard disks and assigning\n" +
            "partitions to mount points when installing &product;.\n" +
            "</p>\n"
        )
      )


      # first step of hd prepare, select a single disk or "expert" partitioning
      Wizard.SetContents(
        _("Preparing Hard Disk"),
        @contents,
        @helptext,
        Convert.to_boolean(WFM.Args(0)),
        Convert.to_boolean(WFM.Args(1))
      )
      Wizard.SetTitleIcon("yast-partitioning") if Stage.initial

      if UI.WidgetExists(Id(:disklist)) && !@custom_val
        UI.ChangeWidget(Id(:disklist), :CurrentItem, Storage.GetPartDisk)
      end
      @ret = nil

      # Event handling

      @option = nil

      @sym = :none
      begin
        @ret = Wizard.UserInput


        Builtins.y2milestone("ret %1", @ret)

        if Ops.is_string?(@ret) && Convert.to_string(@ret) == "CUSTOM"
          #UI::ChangeWidget( `id(`disklist), `CurrentItem, "" );
          @custom_val = !@custom_val
        end

        @sym = :none
        @sym = Convert.to_symbol(@ret) if Ops.is_symbol?(@ret)

        if @sym == :disklist
          Builtins.y2milestone("set CUSTOM false")
          @custom_val = false
          UI.ChangeWidget(Id("CUSTOM"), :Value, false)
        end

        return :abort if @sym == :abort && Popup.ReallyAbort(true)

        if @sym == :next
          @option = UI.QueryWidget(Id(:options), :CurrentButton)
          Builtins.y2milestone("option %1", @option)
          if @option == nil
            @disk = ""
            if UI.WidgetExists(Id(:disklist)) && !@custom_val
              @disk = Convert.to_string(
                UI.QueryWidget(Id(:disklist), :CurrentItem)
              )
              @disk = "" if @disk == nil
            end
            if Builtins.search(@disk, "/dev/") == 0
              @option = @disk
            else
              # there is a selection from which one option must be
              # chosen - at the moment no option is chosen
              Popup.Message(_("Select one of the options to continue."))
              @sym = :again
            end
          end
          if @option != nil &&
              Builtins.substring(Convert.to_string(@option), 0, 5) == "/dev/"
            @disk_map = Convert.convert(
              Ops.get(@targetMap, Convert.to_string(@option), {}),
              :from => "map",
              :to   => "map <string, any>"
            )
            if Ops.get_boolean(@disk_map, "readonly", false)
              Popup.Error(Partitions.RdonlyText(@disk_map, true))
              @sym = :again
            elsif Storage.IsUsedBy(
                Ops.get(@targetMap, Convert.to_string(@option), {})
              )
              @s = StorageFields.UsedByString(
                Ops.get_map(
                  @targetMap,
                  [Convert.to_string(@option), "used_by", 0],
                  {}
                )
              )
              Popup.Error(
                Builtins.sformat(
                  _("Disk %1 is in use by %2"),
                  Convert.to_string(@option),
                  @s
                )
              )
              @sym = :again
            else
              Storage.SetPartMode("USE_DISK")
              Builtins.y2milestone(
                "PartMode Disk old %1 name %2",
                Storage.GetPartDisk,
                @option
              )
              if Storage.CheckBackupState("disk")
                Storage.DisposeTargetBackup("disk")
              end
              Storage.CreateTargetBackup("disk")
              Storage.ResetOndiskTarget
              Storage.SetPartDisk(Convert.to_string(@option))
              Storage.SetCustomDisplay(false)
              Storage.SetDoResize("NO")
            end # if (option)
          elsif @option != nil
            Builtins.y2milestone(
              "PartMode %1 %2",
              Storage.GetPartMode,
              Storage.GetPartDisk
            )
            Storage.CreateTargetBackup("disk")
            Storage.ResetOndiskTarget if Storage.GetPartMode != "USE_DISK"
            Storage.SetCustomDisplay(true)
          end
        end # if (ret == next)
      end until @sym == :next || @sym == :back || @sym == :cancel
      if @sym != :next
        Storage.SetPartMode("SUGGESTION")
        Storage.SetPartProposalActive(true)
      end
      Storage.SaveExitKey(@sym)
      @sym
    end
  end
end

Yast::InstTargetSelectionClient.new.main
