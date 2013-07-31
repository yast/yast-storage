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

# Module: 		inst_resize_dialog.ycp
#
# Authors: 		Thomas Roelz <tom@suse.de>
#			Stefan Hundhammer <sh@suse.de>
#                      Jiri Srain
#
# Purpose: 		UI for setting how to split the disk between existing Windows and Linux
#
# FIXME:		Get rid of code duplication between here and inst_resize_ui (resizing partition from a proposal)
#
#
# $Id: inst_resize_dialog.ycp 52739 2008-10-30 13:59:13Z aschnell $
module Yast
  class InstResizeDialogClient < Client
    def main
      Yast.import "UI"
      textdomain "storage"

      Yast.import "Mode"
      Yast.import "Storage"
      Yast.import "Popup"
      Yast.import "Partitions"
      Yast.import "Wizard"
      Yast.import "Installation"
      Yast.import "StorageProposal"

      Yast.include self, "partitioning/partition_defines.rb"

      @_resize_result = nil

      # main function
      if Storage.resize_partition == nil
        Storage.ResetOndiskTarget
        Storage.AddMountPointsForWin(Storage.GetTargetMap)
        StorageProposal.get_inst_prop(Storage.GetTargetMap)
        if Storage.resize_partition == nil # no resize
          Storage.ResetOndiskTarget
          Storage.resize_partition = ""
          return :auto
        end
      end
      return :auto if Storage.resize_partition == ""
      @ret = ResizeDialog(
        Storage.resize_partition,
        Storage.resize_cyl_size,
        Storage.resize_partition_data
      )
      if @ret == :next
        # store info about partition resize needed for the proposal
        Storage.resize_partition_data = ResizeResult()
        # reset proposal, recreate it
        Storage.ResetOndiskTarget
        Storage.AddMountPointsForWin(Storage.GetTargetMap)
        @prop = {}
        @prop = StorageProposal.get_inst_prop(Storage.GetTargetMap)
        Builtins.y2milestone("prop ok:%1", Ops.get_boolean(@prop, "ok", false))
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
      @ret
    end

    def DiskUsage(win_device)
      win_used = -1
      win_free = -1
      mount_result = Convert.to_boolean(
        SCR.Execute(
          path(".target.mount"),
          [win_device, Installation.scr_destdir, Installation.mountlog]
        )
      )
      if !mount_result
        Builtins.y2error(
          "Current Windows device <%1> could not be mounted. Canceled",
          win_device
        )
      else
        Builtins.y2milestone(
          "Current Windows device <%1> mounted on %2.",
          win_device,
          Installation.scr_destdir
        )
      end

      # get usage information for the partition via df
      df_result = Convert.convert(
        SCR.Read(path(".run.df")),
        :from => "any",
        :to   => "list <map>"
      )
      SCR.Execute(path(".target.umount"), win_device)
      Builtins.y2debug(".run.df: %1", df_result)

      # filter out headline and other invalid entries
      df_result = Builtins.filter(df_result) do |part|
        Builtins.substring(Ops.get_string(part, "spec", ""), 0, 1) == "/"
      end

      Builtins.foreach(df_result) do |part|
        if Ops.get_string(part, "spec", "") == win_device # find right entry
          # get the usage values
          #
          win_used = Builtins.tointeger(Ops.get_string(part, "used", "-1"))
          win_free = Builtins.tointeger(Ops.get_string(part, "free", "-1"))

          if win_used != -1 && win_free != -1
            win_used = Ops.divide(win_used, 1024) # MB
            win_free = Ops.divide(win_free, 1024) # MB
            Builtins.y2milestone(
              ".run.df: win_used: <%1> win_free:<%2>",
              win_used,
              win_free
            )
          end
        end
      end
      [win_used, win_free]
    end

    def ResizeResult
      deep_copy(@_resize_result)
    end

    def ResizeDialog(win_device, cyl_size, win_partition)
      win_partition = deep_copy(win_partition)
      #///////////////////////////////////////////////////////////////////////
      # START: Initialize
      #///////////////////////////////////////////////////////////////////////

      test_mode = Mode.test
      demo_mode = Mode.test

      # store
      #

      win_used = -1
      win_free = -1
      min_win_free = -1
      new_win_size = -1
      linux_size = -1
      linux_min = 400 # this is the base value for space calculations (minimum installation)

      if test_mode # not just in demo mode! no HW probe in test mode!
        win_used = 350
        win_free = 1500
        min_win_free = 50
        linux_size = 800
        linux_min = 400
      end

      #///////////////////////////////////////////////////////////////////////
      # END: Initialize
      #///////////////////////////////////////////////////////////////////////


      Builtins.y2milestone("Cylinder size of target: <%1>", cyl_size)
      # Get region from win partition
      #
      region = Ops.get_list(win_partition, "region", [])

      if Builtins.size(region) != 2
        Builtins.y2error(
          "Invalid region <%1> in Windows partition data struct.",
          region
        )
        return nil
      else
        Builtins.y2milestone(
          "Old region <%1> OK in Windows partition data struct.",
          region
        )
      end

      # mount the partition to execute some checks
      #
      usage = DiskUsage(win_device)
      win_used = Ops.get(usage, 0, -1)
      win_free = Ops.get(usage, 1, -1)
      if win_used == -1 || win_free == -1
        Builtins.y2error(
          "The sizes for device <%1> could not be examined.",
          win_device
        )
        return nil
      else
        # Apply some checks to determine if installing Linux is feasible at all.
        #
        feasible = true

        # Set minimal free Windows size to 200 MB. Running Windows with
        # less disk space is no fun.
        #
        min_win_free = 200 if Ops.less_than(min_win_free, 200)

        # If this is more than the free space on the device Windows is already
        # overcrowded and Linux shouldn't be installed.
        #
        return nil if Ops.greater_than(min_win_free, win_free)

        if Ops.less_than(Ops.subtract(win_free, min_win_free), linux_min)
          return nil
        end

        # Try to reserve 1.5 GB for linux (default installation).
        # Otherwise get as much as possible
        #
        if Ops.greater_than(Ops.subtract(win_free, min_win_free), 1500)
          linux_size = 1500
        else
          linux_size = Ops.subtract(win_free, min_win_free)
        end
      end

      if Storage.resize_partition != nil # already resized
        win_size = Ops.get_integer(
          Storage.resize_partition_data,
          ["region", 1],
          -1
        )
        Builtins.y2internal("Win size read: %1", win_size)
        Builtins.y2internal("Part info: %1", Storage.resize_partition_data)
        Builtins.y2internal("Cyl size: %1", Storage.resize_cyl_size)
        if win_size != -1
          win_size = Ops.divide(
            Ops.multiply(win_size, Storage.resize_cyl_size),
            1024 * 1024
          )
          linux_size = Ops.subtract(Ops.add(win_used, win_free), win_size)
        end
      end

      #///////////////////////////////////////////////////////////////////////
      # END: Preliminary action
      #///////////////////////////////////////////////////////////////////////

      #///////////////////////////////////////////////////////////////////////
      # START: GUI
      #///////////////////////////////////////////////////////////////////////

      test_simple_ui = false # set to "true" to test non-graphical version

      # Unit for parition resizing - currently Megabytes
      unit = _("MB")

      # Labels for bar graph. "%1" will be replace with a numeric value.
      bargraph_label_win_used = Ops.add(_("Windows\nUsed\n%1 "), unit)
      # Labels for bar graph. "%1" will be replace with a numeric value.
      bargraph_label_win_free = Ops.add(_("Windows\nFree\n%1 "), unit)
      # Labels for bar graph. "%1" will be replace with a numeric value.
      bargraph_label_linux = Ops.add(_("Linux\n%1 "), unit)

      # Labels for input fields. "%1" will be replaced with the current unit (MB).
      field_label_win_free = Builtins.sformat(_("Windows Free (%1)"), unit)
      # Labels for input fields. "%1" will be replaced with the current unit (MB).
      field_label_linux = Builtins.sformat(_("Linux (%1)"), unit)

      contents = Empty()



      # Help text for Windows partition resizing -
      # common part for both graphical mode (with bar graphs)
      # and non-graphical mode (text only).
      helptext = _(
        "<p>\n" +
          "Choose the new size for your Windows partition.\n" +
          "</p>"
      )

      # help text (common to both modes), continued
      helptext = Ops.add(
        helptext,
        _(
          "\n" +
            "<p>\n" +
            "The actual resizing will not be performed until after you confirm all your\n" +
            "settings in the last installation dialog. Until then your Windows\n" +
            "partition will remain untouched.\n" +
            "</p>\n"
        )
      )

      # help text (common to both modes), continued
      helptext = Ops.add(
        helptext,
        _(
          "\n" +
            "<p>\n" +
            "To skip resizing your Windows partition, press\n" +
            "<b>Back</b>.\n" +
            "</p>\n"
        )
      )


      if UI.HasSpecialWidget(:Slider) && UI.HasSpecialWidget(:BarGraph) &&
          !test_simple_ui
        contents = VBox(
          VStretch(),
          # Headline above bar graph that displays current windows partition size
          Left(Label(_("Now"))),
          BarGraph(
            [win_used, win_free],
            [bargraph_label_win_used, bargraph_label_win_free]
          ),
          VStretch(),
          # Headline above bar graph that displays future windows and linux partitions
          Left(Label(_("After Installation"))),
          PartitionSplitter(
            Id(:linux_size),
            win_used,
            win_free,
            linux_size,
            linux_min,
            min_win_free,
            bargraph_label_win_used,
            bargraph_label_win_free,
            bargraph_label_linux,
            field_label_win_free,
            field_label_linux
          ),
          VStretch()
        )


        # help text, continued - graphical mode only
        # this help text will be appended to the help text common to both modes.
        helptext = Ops.add(
          helptext,
          _(
            "\n" +
              "<p>\n" +
              "The upper bar graph displays the current situation.\n" +
              "The lower bar graph displays the situation after the installation (after\n" +
              "the partition resize).\n" +
              "</p>\n"
          )
        )

        # help text (graphical mode), continued
        helptext = Ops.add(
          helptext,
          _(
            "\n" +
              "<p>\n" +
              "Drag the slider or enter a numeric value in either\n" +
              "input field to adjust the suggested values.\n" +
              "</p>\n"
          )
        )

        # help text (graphical mode), continued
        helptext = Ops.add(
          helptext,
          _(
            "\n" +
              "<p>\n" +
              "Within the space you reserve for Linux, partitions will automatically be\n" +
              "created as necessary.\n" +
              "</p>"
          )
        ) # no special widgets -> simple fallback UI
      else
        contents = HVSquash(
          VBox(
            HBox(
              # Label for used part of the Windows partition in non-graphical mode
              HWeight(3, Right(Label(_("Windows Used")))),
              HWeight(
                2,
                Label(Opt(:outputField), Builtins.sformat("%1", win_used))
              ),
              HWeight(3, Left(Label(unit)))
            ),
            VSpacing(0.5),
            HBox(
              # Label for free part of the Windows partition in non-graphical mode
              HWeight(3, Right(Label(_("Free")))),
              HWeight(
                2,
                Label(Opt(:outputField), Builtins.sformat("%1", win_free))
              ),
              HWeight(3, Left(Label(unit)))
            ),
            VSpacing(0.5),
            HBox(
              # Edit field label for linux partition size in non-graphical mode
              HWeight(3, Right(Bottom(Label(_("Linux"))))),
              HWeight(
                2,
                IntField(
                  Id(:linux_size), # initial
                  "", # label (above)
                  linux_min,
                  Ops.subtract(win_free, min_win_free), # max
                  linux_size
                )
              ),
              HWeight(3, Left(Bottom(Label(unit))))
            )
          )
        )

        # help text, continued - non-graphical mode only
        # this help text will be appended to the help text common to both modes.
        helptext = Ops.add(
          helptext,
          _(
            "\n" +
              "<p>Enter a value for the size of your <b>Linux</b> installation.\n" +
              "The partitions will automatically be created within this range\n" +
              "as required for &product;.\n" +
              "</p>\n"
          )
        )

        # help text (non-graphical mode), continued
        helptext = Ops.add(
          helptext,
          _(
            "\n" +
              "<p>\n" +
              "<b>Windows Used</b> is the size of the space your Windows partition uses.\n" +
              "</p>\n"
          )
        )

        # help text (non-graphical mode), continued
        helptext = Ops.add(
          helptext,
          _(
            "\n" +
              "<p><b>Free</b> indicates the current free space (before the Linux\n" +
              "installation) on the partition.\n" +
              "</p>"
          )
        )
      end


      Builtins.y2internal("Opening dialog")
      Wizard.SetContents(
        _("Resizing the Windows Partition"),
        contents,
        helptext,
        true,
        true
      )


      #///////////////////////////////////////////////////////////////////////
      # END: GUI
      #///////////////////////////////////////////////////////////////////////

      #///////////////////////////////////////////////////////////////////////
      # START: Main loop
      #///////////////////////////////////////////////////////////////////////

      ret = nil
      begin
        ret = Convert.to_symbol(Wizard.UserInput)

        return :abort if ret == :abort && Popup.ReallyAbort(true)

        if ret == :next
          # Get the value the user adjusted. If s/he entered a value
          # too big or too small this is automatically adjusted to the
          # biggest/smallest value possible (by Qt).
          #
          linux_size = Convert.to_integer(
            UI.QueryWidget(Id(:linux_size), :Value)
          )
          new_win_size = Ops.subtract(Ops.add(win_used, win_free), linux_size)

          Builtins.y2milestone(
            "Linux size: <%1> - New Win size: <%2>",
            linux_size,
            new_win_size
          )
        end

        return :back if ret == :back
      end until ret == :next || ret == :back || ret == :cancel

      #///////////////////////////////////////////////////////////////////////
      # END: Main loop
      #///////////////////////////////////////////////////////////////////////

      #///////////////////////////////////////////////////////////////////////
      # START: Final action
      #///////////////////////////////////////////////////////////////////////

      # Now update the target map to the new situation
      #
      if !test_mode
        # adjust the partition entry in the target map to reflect the new size

        # add flag and new size to the windows partition
        #
        win_partition = Builtins.add(win_partition, "resize", true)

        # adjust the region list in the windows partition to reflect the new size
        #
        win_start = Ops.get(region, 0, 0) # same as before resize
        Builtins.y2internal("Win size: %1", new_win_size)
        Builtins.y2internal("Cylinder: %1", cyl_size)
        new_length_i = PartedSizeToCly(
          Ops.multiply(
            Ops.multiply(Builtins.tofloat(new_win_size), 1024.0),
            1024.0
          ),
          cyl_size
        )

        region = [win_start, new_length_i]
        win_partition = Builtins.add(win_partition, "region", region)

        Builtins.y2milestone(
          "New region of Windows partition after resize: <%1>",
          region
        )
        @_resize_result = deep_copy(win_partition)
        return :next
      end
      #///////////////////////////////////////////////////////////////////////
      # END: final action
      #///////////////////////////////////////////////////////////////////////

      ret
    end
  end
end

Yast::InstResizeDialogClient.new.main
