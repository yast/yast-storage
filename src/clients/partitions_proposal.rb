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

# Module:		proposal_partitions.ycp
#
# $Id$
#
# Author:		Klaus Kaempf <kkaempf@suse.de>
#
# Purpose:		Proposal function dispatcher - partitions.
#
#			See also file proposal-API.txt for details.
module Yast
  class PartitionsProposalClient < Client
    def main
      textdomain "storage"

      Yast.import "Arch"
      Yast.import "Wizard"
      Yast.import "Mode"
      Yast.import "Sequencer"
      Yast.import "Storage"
      Yast.import "StorageProposal"


      @func = Convert.to_string(WFM.Args(0))
      @param = Convert.to_map(WFM.Args(1))
      @ret = {}

      Builtins.y2milestone("func:%1 param:%2", @func, @param)


      if @func == "MakeProposal" && Mode.autoinst
        Ops.set(@ret, "preformatted_proposal", Storage.ChangeText)
      elsif @func == "MakeProposal"
        @force_reset = Ops.get_boolean(@param, "force_reset", false)
        @language_changed = Ops.get_boolean(@param, "language_changed", false)

        Builtins.y2milestone(
          "force_reset:%1 lang_changed:%2",
          @force_reset,
          @language_changed
        )
        if @force_reset || Storage.GetPartProposalFirst
          if !Storage.GetPartProposalFirst
            Storage.ResetOndiskTarget
            Storage.AddMountPointsForWin(Storage.GetTargetMap)
          end
          @prop = {}
          @prop = StorageProposal.get_inst_prop(Storage.GetTargetMap)
          Builtins.y2milestone(
            "prop ok:%1",
            Ops.get_boolean(@prop, "ok", false)
          )
          if Ops.get_boolean(@prop, "ok", false)
            Storage.SetTargetMap(Ops.get_map(@prop, "target", {}))
            Storage.SetPartProposalMode("accept")
            Builtins.y2milestone("PROPOSAL: %1", Storage.ChangeText)
          else
            Storage.SetPartProposalMode("impossible")
          end
          Storage.SetPartProposalFirst(false)
          Storage.SetPartProposalActive(true)
          Builtins.y2milestone("prop=%1", @prop)
        end

        if Storage.GetPartProposalMode != "impossible" ||
            !Storage.GetPartProposalActive
          Ops.set(@ret, "preformatted_proposal", Storage.ChangeText)

          if unformatted_home_warning
            Ops.set(
              @ret,
              "warning",
              _(
                "The /home partition will not be formatted. After installation,\nensure that ownerships of home directories are set properly."
              )
            )
            Ops.set(@ret, "warning_level", :warning)
          end
        else
          Ops.set(@ret, "raw_proposal", [])
          # popup text
          Ops.set(
            @ret,
            "warning",
            _(
              "No automatic proposal possible.\nSpecify mount points manually in the 'Partitioner' dialog."
            )
          )
          Ops.set(@ret, "warning_level", :blocker)
        end
        Storage.HandleProposalPackages
      elsif @func == "AskUser"
        @has_next = Ops.get_boolean(@param, "has_next", false)

        # call some function that displays a user dialog
        # or a sequence of dialogs here:
        #
        # sequence = DummyMod::AskUser( has_next );

        @aliases = {
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

        @seq = {}

        if Storage.GetPartProposalMode != "impossible"
          Storage.SetPartProposalMode("accept")
        else
          #Oops, no TargetMap, there are no disks
          if Builtins.size(Storage.GetTargetMap) == 0
            #but we might still let user add nfs root
            #or mount iSCSI in expert partitioner (#421541)
            Storage.SetPartMode("CUSTOM")
          else
            Storage.SetPartMode("USE_DISK")
          end
        end

        Ops.set(
          @seq,
          "disk",
          { :abort => :abort, :cancel => :cancel, :next => :next }
        )

        if Mode.autoinst
          Storage.SetPartMode("PROP_MODIFY")
          Ops.set(@seq, "ws_start", "disk")
        else
          Builtins.y2milestone(
            "ProposalActive %1 ProposalMode %2 PartMode %3",
            Storage.GetPartProposalActive,
            Storage.GetPartProposalMode,
            Storage.GetPartMode
          )
          Ops.set(
            @seq,
            "target_sel",
            { :abort => :abort, :cancel => :cancel, :next => "target_part" }
          )
          Ops.set(
            @seq,
            "target_part",
            { :abort => :abort, :cancel => :cancel, :next => "disk" }
          )
          if Arch.i386
            Ops.set(
              @seq,
              "resize_ui",
              { :abort => :abort, :cancel => :cancel, :next => "disk" }
            )
            Ops.set(@seq, ["target_part", :next], "resize_ui")
          end
          Ops.set(
            @seq,
            "disk",
            { :abort => :abort, :cancel => :cancel, :next => :next }
          )
          if Storage.GetPartProposalMode != "impossible" &&
              Storage.GetPartProposalActive
            Ops.set(@seq, "ws_start", "target_sel")
          elsif Storage.GetPartMode == "USE_DISK"
            Ops.set(@seq, "ws_start", "target_sel")
          else
            Ops.set(@seq, "ws_start", "disk")
          end
        end
        Builtins.y2milestone("proposal sequence %1", @seq)

        Wizard.OpenNextBackDialog
        @result = Sequencer.Run(@aliases, @seq)
        Wizard.CloseDialog

        Builtins.y2milestone(
          "AskUser Mode:%1 ProActive:%2",
          Storage.GetPartMode,
          Storage.GetPartProposalActive
        )

        # Fill return map
        Storage.HandleProposalPackages
        @ret = { "workflow_sequence" => @result }
      elsif @func == "Description"
        # Fill return map.
        #
        # Static values do just nicely here, no need to call a function.

        @ret = {
          # label text
          "rich_text_title" => _("Partitioning"),
          # label text
          "menu_title"      => _("&Partitioning"),
          "id"              => "partitions_stuff"
        }
      end

      deep_copy(@ret)
    end

    # check if /home partition keeps unformatted in order to warn for
    # possible incorrectly set file ownership (fate #306325)
    def unformatted_home_warning
      part = Storage.GetEntryForMountpoint("/home")
      if !Builtins.isempty(part) && !Ops.get_boolean(part, "format", false)
        Builtins.y2milestone("/home partition will not be formatted")

        Yast.import "UsersSimple"
        if UsersSimple.AfterAuth != "users"
          Builtins.y2milestone("non-local user authentication")
          return true
        end

        device = Ops.get_string(part, "device", "")
        resize_info = {}
        content_info = {}
        if (
            resize_info_ref = arg_ref(resize_info);
            content_info_ref = arg_ref(content_info);
            _GetFreeInfo_result = Storage.GetFreeInfo(
              device,
              false,
              resize_info_ref,
              true,
              content_info_ref,
              true
            );
            resize_info = resize_info_ref.value;
            content_info = content_info_ref.value;
            _GetFreeInfo_result
          ) &&
            Ops.greater_than(Ops.get_integer(content_info, :homes, 0), 1)
          Builtins.y2milestone("multiple home directories")
          return true
        end
      end

      false
    end
  end
end

Yast::PartitionsProposalClient.new.main
