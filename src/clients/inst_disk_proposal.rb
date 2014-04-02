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
#  *
#  * Description:   Create a proposal for partitioning
#  *
#  *
#  *
#  *
#  *
#  *************************************************************
#
#  $Id: inst_part_proposal.ycp 43636 2008-01-15 17:25:46Z fehr $
module Yast
  class InstDiskProposalClient < Client
    def main

      textdomain "storage"

      Yast.import "UI"
      Yast.import "Arch"
      Yast.import "Wizard"
      Yast.import "Mode"
      Yast.import "Popup"
      Yast.import "Storage"
      Yast.import "Sequencer"
      Yast.import "StorageProposal"
      Yast.import "Stage"


      Yast.include self, "partitioning/custom_part_dialogs.rb"

      @targetMap = Storage.GetTargetMap

      if Mode.test && Builtins.size(@targetMap) == 0
        Builtins.y2warning(
          "***** Demo mode active - using fake demo values *****"
        )
        @targetMap = Convert.convert(
          SCR.Read(path(".target.yast2"), "demo_target_map.ycp"),
          :from => "any",
          :to   => "map <string, map>"
        )
        Storage.SetTargetMap(@targetMap)
      end


      # Title for dialogue
      @title = _("Suggested Partitioning")
      # Radiobutton for partition dialog
      @modify_str = _("&Expert Partitioner...")
      # Radiobutton for partition dialog
      @detailed_str = _("&Create Partition Setup...")

      @target_is = ""

      @changes = ""
      if Storage.GetPartProposalFirst

        @prop = StorageProposal.get_inst_prop(Storage.GetTargetMap)
        Builtins.y2milestone("prop ok:%1", Ops.get_boolean(@prop, "ok", false))

        if Ops.get_boolean(@prop, "ok", false)
          if CouldNotDoSeparateHome(Ops.get_map(@prop, "target", {}))
            StorageProposal.SetProposalHome(false)
            if UI.WidgetExists(Id(:home))
              UI.ChangeWidget(Id(:home), :Value, false)
            end
          end
          Storage.SetTargetMap(Ops.get_map(@prop, "target", {}))
          @targetMap = Ops.get_map(@prop, "target", {})
          Storage.SetPartProposalMode("accept")
          @changes = Storage.ChangeText
          Storage.HandleProposalPackages
          @target_is = "SUGGESTION"
          Storage.SetPartMode(@target_is)
          Storage.SetPartProposalFirst(false)
          Storage.SetPartProposalActive(true)
        else
          Storage.SetPartProposalMode("impossible")
        end
      else
        @changes = Storage.ChangeText
      end

      if Storage.GetPartProposalMode == "impossible"
        @changes = "<font color=red>"
        @changes = Ops.add(
          @changes,
          _(
            "No automatic proposal possible.\nSpecify mount points manually in the 'Partitioner' dialog."
          )
        )
        @changes = Ops.add(@changes, "</font>")
      end

      Builtins.y2milestone("current proposal: %1", @changes)

      @rframe = VBox(
        VSpacing(0.2),
        # TRANSLATORS: button text
        PushButton(Id(:settings), _("Edit Proposal Settings")),
        HSpacing(0.2)
      )

      @bframe = VBox(
        PushButton(Id(:detailed), @detailed_str),
        VSpacing(0.2),
        PushButton(Id(:modify), @modify_str)
      )

      @space = Convert.convert(
        StorageProposal.SaveHeight ? 1 : 2,
        :from => "integer",
        :to   => "float"
      )

      @contents = MarginBox(
        2,
        0.4,
        VBox(
          MinHeight(8, RichText(Id(:richtext), @changes)),
          @rframe,
          VSpacing(@space),
          @bframe,
          VStretch()
        )
      )


      # help on suggested partitioning
      help_text = _(
        "<p>\n" +
          "Your hard disks have been checked. The partition setup\n" +
          "displayed is proposed for your hard drive.</p>"
      )

      # help text continued
      # %1 is replaced by button text
      help_text +=
        Builtins.sformat(
          _(
            "<p>\n" +
              "To make only small adjustments to the proposed\n" +
              "setup (like changing filesystem types), choose\n" +
              "<b>%1</b> and modify the settings in the expert\n" +
              "partitioner dialog.</p>\n"
          ),
          Builtins.deletechars(@modify_str, "&")
        )

      # help text continued
      help_text +=
        Builtins.sformat(
          _(
            "<p>\n" +
              "If the suggestion does not fit your needs, create\n" +
              "your own partition setup starting with the partitions \n" +
              "currently present on the disks. Select\n" +
              "<b>%1</b>.\n" +
              "This is also the option to choose for\n" +
              "advanced configurations like RAID and encryption.</p>\n"
          ),
          Builtins.deletechars(@detailed_str, "&")
        )

      @ret = nil

      # Attention! besides the testsuite, AutoYaST is using this to turn off
      # the proposal screen too. See inst_autosetup.ycp
      #
      if !Storage.GetTestsuite
        StorageProposal.SetCreateVg(false)
        @enab = Convert.to_map(WFM.Args(0))
        Wizard.SetContents(
          @title,
          @contents,
          help_text,
          Ops.get_boolean(@enab, "enable_back", false),
          Ops.get_boolean(@enab, "enable_next", false)
        )
        Wizard.SetTitleIcon("yast-partitioning") if Stage.initial

        begin
          @val = false
          Wizard.SetFocusToNextButton
          @ret = Convert.to_symbol(Wizard.UserInput)
          Builtins.y2milestone("USERINPUT %1", @ret)

          return :abort if @ret == :abort && Popup.ReallyAbort(true)

          if @ret == :settings
            if AskOverwriteChanges() && StorageProposal.CommonWidgetsPopup()
              @target_is = "SUGGESTION"
              Storage.ResetOndiskTarget
              Storage.AddMountPointsForWin(Storage.GetTargetMap)
              @prop = StorageProposal.get_inst_prop(Storage.GetTargetMap)
              if !Ops.get_boolean(@prop, "ok", false)
                Popup.Error(_("Impossible to create the requested proposal."))
                Storage.SetPartProposalMode("impossible")
              else
                if CouldNotDoSeparateHome(Ops.get_map(@prop, "target", {}))
                  @reason = _(
                    "Not enough space available to propose separate /home."
                  )
                  Popup.Error(@reason)
                  StorageProposal.SetProposalHome(false)
                end
                @targetMap = Ops.get_map(@prop, "target", {})
                Storage.SetPartProposalMode("accept")
                Storage.SetPartProposalActive(true)
              end
              Storage.SetPartMode(@target_is)
              Storage.SetTargetMap(@targetMap)
              Storage.HandleProposalPackages()
              @changes = Storage.ChangeText
              UI.ChangeWidget(Id(:richtext), :Value, @changes)
            end
          elsif [:modify, :detailed].include?(@ret)
            Storage.SetPartProposalFirst(false)
            Storage.SetPartProposalActive(false)

            case @ret
              when :modify
                @target_is = "PROP_MODIFY"
                Storage.SetPartProposalMode("modify")
              when :detailed
                if Storage.GetPartMode != "CUSTOM"
                  @target_is = "NORMAL"
                else
                  @target_is = "CUSTOM"
                end
                Storage.SetPartDisk("")
                Storage.SetPartProposalMode("detailed")
            end

            Storage.SetPartMode(@target_is)
            execSubscreens(@ret)
            @changes = Storage.ChangeText
            UI.ChangeWidget(Id(:richtext), :Value, @changes)
          end
        end until @ret == :next || @ret == :back || @ret == :cancel
      end
      Storage.SaveExitKey(@ret)

      @ret
    end

    def CouldNotDoSeparateHome(prop)
      prop = deep_copy(prop)
      ret = false
      if StorageProposal.GetProposalHome
        ls = []
        Builtins.foreach(prop) do |k, d|
          ls = Convert.convert(
            Builtins.union(
              ls,
              Builtins.filter(Ops.get_list(d, "partitions", [])) do |p|
                !Ops.get_boolean(p, "delete", false) &&
                  Ops.greater_than(
                    Builtins.size(Ops.get_string(p, "mount", "")),
                    0
                  )
              end
            ),
            :from => "list",
            :to   => "list <map>"
          )
        end
        ret = Builtins.size(Builtins.filter(ls) do |p|
          Ops.get_string(p, "mount", "") == "/home"
        end) == 0
        Builtins.y2milestone("CouldNotDoSeparateHome ls:%1", ls)
      end
      Builtins.y2milestone("CouldNotDoSeparateHome ret:%1", ret)
      ret
    end


    def AskOverwriteChanges
      ret = true
      target_is = Storage.GetPartMode
      Builtins.y2milestone("AskOverwriteChanges target_is %1", target_is)
      if target_is == "USE_DISK" || target_is == "CUSTOM" ||
          target_is == "PROP_MODIFY"
        ret = Popup.YesNo(
          _(
            "Computing this proposal will overwrite manual changes \ndone so far. Continue with computing proposal?"
          )
        )
      end
      Builtins.y2milestone("AskOverwriteChanges ret:%1", ret)
      ret
    end


    def execSubscreens(mode)
      Builtins.y2milestone("execSubscreens mode:%1", mode)

      if Mode.autoinst
        Storage.SetPartMode("PROP_MODIFY")
      else
        aliases = {
          "disk"        => lambda { WFM.CallFunction("inst_disk", [true, true]) },
          "target_sel"  => lambda do
            WFM.CallFunction("inst_target_selection", [true, true])
          end,
          "target_part" => lambda do
            WFM.CallFunction("inst_target_part", [true, true])
          end,
          "resize_ui"   => lambda do
            WFM.CallFunction("inst_resize_ui", [true, true])
          end
        }

        seq = {}
        Ops.set(
          seq,
          "disk",
          { :abort => :abort, :cancel => :cancel, :next => :next }
        )

        case mode
          when :detailed, :modify
            Builtins.y2milestone(
              "ProposalActive %1 ProposalMode %2 PartMode %3",
              Storage.GetPartProposalActive,
              Storage.GetPartProposalMode,
              Storage.GetPartMode
            )
            Ops.set(
              seq,
              "target_sel",
              { :abort => :abort, :cancel => :cancel, :next => "target_part" }
            )
            Ops.set(
              seq,
              "target_part",
              { :abort => :abort, :cancel => :cancel, :next => "disk" }
            )
            if Arch.i386
              Ops.set(
                seq,
                "resize_ui",
                { :abort => :abort, :cancel => :cancel, :next => "disk" }
              )
              Ops.set(seq, ["target_part", :next], "resize_ui")
            end
            Ops.set(
              seq,
              "disk",
              { :abort => :abort, :cancel => :cancel, :next => :next }
            )
            Builtins.y2milestone(
              "execSubscreens GetPartMode %1",
              Storage.GetPartMode
            )
            if mode == :detailed && Storage.GetPartMode != "CUSTOM"
              Ops.set(seq, "ws_start", "target_sel")
            else
              Ops.set(seq, "ws_start", "disk")
            end
            if Storage.CheckBackupState("disk")
              Storage.DisposeTargetBackup("disk")
            end
            Builtins.y2milestone("execSubscreens sequence %1", seq)
            Wizard.OpenNextBackDialog
            result = Sequencer.Run(aliases, seq)
            Wizard.CloseDialog
        end

        Storage.HandleProposalPackages
      end

      nil
    end

  end
end

Yast::InstDiskProposalClient.new.main
