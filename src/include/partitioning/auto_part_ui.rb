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
  module PartitioningAutoPartUiInclude
    def initialize_partitioning_auto_part_ui(include_target)
      textdomain "storage"

      Yast.import "Wizard"
      Yast.import "Partitions"
      Yast.import "Popup"
      Yast.import "Product"
      Yast.import "StorageProposal"
    end

    # --------------------------------------------------------------
    # warning and pop-ups

    def display_error_box(reason)
      # There is a consistency check for the selection. Next is the message, that
      # is displayed. The reason is determined within this consistency check and
      # then the message is passed through this interface transparently
      text = Builtins.sformat(
        _("The current selection is invalid:\n%1"),
        reason
      )
      Popup.Message(text)

      nil
    end


    # Return a text that describes a partition

    def partition_text(nr, pentry, bps)
      pentry = deep_copy(pentry)
      size_str = Storage.ByteToHumanString(
        size_of_region(Ops.get_list(pentry, "region", []), bps)
      )
      if Ops.get_symbol(pentry, "type", :unknown) == :free
        # list of partition checkboxes: show partition as unassigned
        # e.g. "1:    2 GB, unassigned"
        return Builtins.sformat(_("&%1:    %2, unassigned"), nr, size_str)
      # list of partition checkboxes: show partition as assigned
      elsif Ops.get_string(pentry, "label", "") == ""
        return Builtins.sformat(
          "&%1:    %2, %3 (%4)",
          nr,
          size_str,
          Ops.get_string(pentry, "fstype", ""),
          Ops.get_string(pentry, "device", "")
        )
      else
        return Builtins.sformat(
          "&%1:    %2, %3 (%4, LABEL=%5)",
          nr,
          size_str,
          Ops.get_string(pentry, "fstype", ""),
          Ops.get_string(pentry, "device", ""),
          Ops.get_string(pentry, "label", "")
        )
      end
    end



    def construct_partition_dialog(partitions, ptype, bps)
      partitions = deep_copy(partitions)
      vbox_contents = VBox(
        # and the "Use entire hard disk" button
        # - please avoid excessively long lines - rather, include a newline
        Left(
          Label(
            Builtins.sformat(
              _("Disk Areas to Use\nto Install %1\n"),
              Product.name
            )
          )
        ),
        VSpacing(0.3)
      ) # Message between the full name of the hard disk to use

      # Add option to select the entire disk at once
      vbox_contents = Builtins.add(
        vbox_contents,
        # pushbutton to choose the entire disk, erasing all data on
        # the disk this is an easy way to select all partitions on
        # the target disk
        Left(PushButton(Id(:full), _("Use &Entire Hard Disk")))
      )

      vbox_contents = Builtins.add(vbox_contents, VSpacing(0.5))

      i = 0
      ui_id = 0
      Builtins.foreach(partitions) do |pentry|
        ptype2 = Ops.get_symbol(pentry, "type", :unknown)
        if ptype2 != :extended
          # skip #3 on AlphaBSD and SparcBSD
          if Ops.get_integer(pentry, "fsid", 0) != Partitions.fsid_mac_hidden &&
              (ptype2 != :bsd && ptype2 != :sun ||
                Ops.get_integer(pentry, "nr", 0) != 3) &&
              !Ops.get_boolean(pentry, "create", false)
            ui_id = Ops.get_integer(pentry, "ui_id", 0)
            i = Ops.add(i, 1)
            sel = Ops.get_boolean(pentry, "delete", false) || ptype2 == :free
            vbox_contents = Builtins.add(
              vbox_contents,
              Left(CheckBox(Id(ui_id), partition_text(i, pentry, bps), sel))
            )
          end
        end
      end
      { "term" => vbox_contents, "high_id" => ui_id }
    end

    def create_whole_disk_dialog
      # There were no prior partitions on this disk.
      # No partitions to choose from will be displayed.
      VBox(
        Left(
          Label(
            Builtins.sformat(
              _(
                "There are no partitions on this disk yet.\nThe entire disk will be used for %1."
              ),
              Product.name
            )
          )
        )
      )
    end

    def create_resize_dialog(partitions, bps)
      partitions = deep_copy(partitions)
      # popup text
      explanation = _(
        "This disk appears to be used by Windows.\nThere is not enough space to install Linux."
      )

      VBox(
        RadioButtonGroup(
          HBox(
            HSpacing(1.5),
            VBox(
              Left(Label(explanation)),
              VSpacing(0.5),
              Left(
                RadioButton(
                  Id(:part_id),
                  # Radio button for using an entire (Windows) partition for Linux
                  _("&Delete Windows Completely")
                )
              ),
              VSpacing(0.5),
              Left(
                RadioButton(
                  Id(:resize),
                  # Radio button for resizing a (Windows) partition
                  _("&Shrink Windows Partition"),
                  true
                )
              )
            )
          )
        )
      )
    end

    # --------------------------------------------------------------


    # normal case
    #
    def open_auto_dialog(targetname, targetbox)
      targetbox = deep_copy(targetbox)

      # TRANSLATORS: helptext, part 1 of 4
      helptext = _(
        "<p>\n" +
          "Select where on your hard disk to install &product;.\n" +
          "</p>\n"
      )

      # TRANSLATORS: helptext, part 2 of 4
      helptext +=
        _(
          "<p>\n" +
            "Use either the <b>entire hard disk</b> or one or more of the\n" +
            "partitions or free regions shown.\n" +
            "</p>\n"
        )

      # TRANSLATORS: helptext, part 3 of 4
      helptext +=
        _(
          "<p>\n" +
            "Notice: If you select a region that is not shown as <i>free</i>, you\n" +
            "might loose existing data on your hard disk. This could also affect\n" +
            "other operating systems.\n" +
            "</p>"
        )

      # TRANSLATORS: helptext, part 4 of 4
      helptext +=
        _(
          "<p>\n" +
            "<b><i>The marked regions will be deleted. All data there will be\n" +
            "lost. </i></b> There will be no way to recover this data.\n" +
            "</p>\n"
        )

      # Information what to do, background information
      Wizard.SetContents(
        _("Preparing Hard Disk"),
        HCenter(
          HSquash(
            Frame(
              # Frame title for installation target hard disk / partition(s)
              _("Installing on:"),
              HBox(
                HSpacing(),
                VBox(
                  VSpacing(0.5),
                  HBox(HSpacing(2), Left(Label(Opt(:outputField), targetname))),
                  VSpacing(0.5),
                  # All partitions are listed that are found on the target (hard disk).
                  VSquash(targetbox),
                  VSpacing(0.5)
                ),
                HSpacing()
              )
            )
          )
        ),
        helptext,
        Convert.to_boolean(WFM.Args(0)),
        Convert.to_boolean(WFM.Args(1))
      )

      nil
    end


    # resize case
    #
    def open_auto_dialog_resize(targetname, targetbox)
      targetbox = deep_copy(targetbox)
      # helptext for semi-automatic partitioning
      # part 1 of 2
      helptext = _(
        "<p>\n" +
          "The selected hard disk is probably used by Windows. There is not enough\n" +
          "space for &product;. You can either <b>delete Windows completely</b> or\n" +
          "<b>shrink</b> it to get enough free space.\n" +
          "</p>"
      )
      # helptext, part 2 of 2
      helptext = Ops.add(
        helptext,
        _(
          "<p>\n" +
            "If you delete Windows, all data on this partition will be <b>irreversibly\n" +
            "lost</b> in the installation. When shrinking Windows, we <b>strongly\n" +
            "recommend a data backup</b>, because the data must be reorganized.\n" +
            "This may fail under rare circumstances.\n" +
            "</p>\n"
        )
      )

      # Information what to do, background information
      Wizard.SetContents(
        _("Preparing Hard Disk"),
        HCenter(
          Frame(
            # Frame title for installation target hard disk / partition(s)
            _("Installing on:"),
            HBox(
              HSpacing(),
              VBox(
                VSpacing(0.5),
                HBox(HSpacing(2), Left(Label(Opt(:outputField), targetname))),
                VSpacing(0.5),
                # All partitions are listed that are found on the target (hard disk).
                VSquash(targetbox),
                VSpacing(0.5)
              ),
              HSpacing()
            )
          )
        ),
        helptext,
        Convert.to_boolean(WFM.Args(0)),
        Convert.to_boolean(WFM.Args(1))
      )

      nil
    end

    def add_common_widgets(vbox)
      vbox = deep_copy(vbox)
      cfg = StorageProposal.GetControlCfg
      vb = VBox()
      vb = Builtins.add(
        vb,
        Left(
          HBox(
            HSpacing(3),
            CheckBox(
              Id(:home),
              # Label text
              _("Propose Separate &Home Partition"),
              Ops.get_boolean(cfg, "home", false)
            )
          )
        )
      )
      vb = Builtins.add(vb, VSpacing(1))
      vb = Builtins.add(
        vb,
        Left(
          HBox(
            HSpacing(3),
            CheckBox(
              Id(:lvm),
              Opt(:notify),
              # Label text
              _("Create &LVM Based Proposal"),
              Ops.get_boolean(cfg, "prop_lvm", false)
            )
          )
        )
      )
      vb = Builtins.add(
        vb,
        Left(
          HBox(
            HSpacing(7),
            CheckBox(Id(:encrypt), Opt(:notify), _("Encrypt Volume Group"))
          )
        )
      )
      vbox = Builtins.add(vbox, VSpacing(1.5))
      frame = HVCenter(Frame(_("Proposal type"), HVCenter(vb)))
      vbox = Builtins.add(vbox, frame)
      deep_copy(vbox)
    end
  end
end
