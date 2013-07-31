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

# Module: 		inst_resize_ui.ycp
#
# Authors: 		Thomas Roelz <tom@suse.de>
#			Stefan Hundhammer <sh@suse.de>
#
# Purpose: 		UI for partition resizing
#
#
# $Id$
module Yast
  class InstResizeUiClient < Client
    def main
      Yast.import "UI"
      textdomain "storage"

      Yast.import "Mode"
      Yast.import "Storage"
      Yast.import "Popup"
      Yast.import "Partitions"
      Yast.import "Wizard"
      Yast.import "Product"
      Yast.import "Installation"

      Yast.include self, "partitioning/partition_defines.rb"

      # Automatically return if resizing is not requested
      #
      @do_resize = Storage.GetDoResize # minor number (e.g. "1" for /dev/sda1 or "NO")

      if Storage.GetCustomDisplay || @do_resize == "NO" || @do_resize == "no" ||
          @do_resize == ""
        return Storage.GetExitKey
      end

      #///////////////////////////////////////////////////////////////////////
      # START: Initialize
      #///////////////////////////////////////////////////////////////////////

      @test_mode = Mode.test
      @demo_mode = Mode.test
      @targets = Storage.GetTargetMap
      @target_is = Storage.GetPartDisk

      # store
      #
      @win_device = "" # will be assigned later with e.g. /dev/sda1

      @target = {}
      @partitions = []
      @partitions_new = []
      @win_partition = {}
      @region = []


      @ret = :next
      @local_ret = nil

      @win_used = -1
      @win_free = -1
      @min_win_free = -1
      @new_win_size = -1
      @linux_size = -1
      @cyl_size = -1
      @linux_min = 400 # this is the base value for space calculations (minimum installation)

      if @test_mode # not just in demo mode! no HW probe in test mode!
        @win_used = 350
        @win_free = 1500
        @min_win_free = 50
        @linux_size = 800
        @linux_min = 400
      end

      #///////////////////////////////////////////////////////////////////////
      # END: Initialize
      #///////////////////////////////////////////////////////////////////////

      Yast.include self, "partitioning/auto_part_functions.rb"
      Yast.include self, "partitioning/auto_part_create.rb"

      #///////////////////////////////////////////////////////////////////////
      # END: Functions
      #///////////////////////////////////////////////////////////////////////

      #///////////////////////////////////////////////////////////////////////
      # START: Preliminary action
      #///////////////////////////////////////////////////////////////////////

      if !@test_mode
        # get the selected target device from the target map
        #
        @target = Ops.get(@targets, @target_is, {})

        if @target == {}
          Builtins.y2error(
            "Current device <%1> not found in targets.",
            @target_is
          )
          internal_error
          return :abort # abort installation
        else
          Builtins.y2milestone(
            "Current device <%1> found in targets.",
            @target_is
          )
        end

        # create full device name e.g. /dev/sda1
        #
        @win_device = Storage.GetDeviceName(
          @target_is,
          Builtins.tointeger(@do_resize)
        )

        # get the cylinder size of this device (used later for region calculation)
        #
        @cyl_size = Ops.get_integer(@target, "cyl_size", -1)

        if @cyl_size == -1
          Builtins.y2error("Cylinder size not found in target_data struct.")
          internal_error
          return :abort # abort installation
        else
          Builtins.y2milestone("Cylinder size of target: <%1>", @cyl_size)
        end

        # get the partition list from the target map
        #
        @partitions = Ops.get_list(@target, "partitions", [])

        if @partitions == []
          Builtins.y2error("Partition list not found in target.")
          internal_error
          return :abort # abort installation
        else
          Builtins.y2milestone("Partition list found in target.")
        end

        # Now filter out all "create" and "resize" paritions, they will be re-created.
        # (this ensures a 'clean' partition list if this dialogue is re-entered.
        # This is actually obsolete since the invention of the targets-restore-mechanism
        # but left in for safeness reasons.
        #
        @partitions = Builtins.filter(@partitions) do |pentry|
          !Ops.get_boolean(pentry, "create", false) &&
            !Ops.get_boolean(pentry, "resize", false)
        end

        Builtins.y2milestone(
          "Old partition list after cleaning: <%1>",
          @partitions
        )

        # Filter out the windows partition. It will be reinserted after being modified.
        # This is the start of the new partitions list.
        #
        @partitions_new = Builtins.filter(@partitions) do |pentry|
          Ops.get_integer(pentry, "nr", -1) != Builtins.tointeger(@do_resize)
        end

        Builtins.y2milestone(
          "New partition list without windows partition: <%1>",
          @partitions_new
        )

        # get the windows partition from the old list
        #
        @p_list = Builtins.filter(@partitions) do |pentry|
          Ops.get_integer(pentry, "nr", -1) == Builtins.tointeger(@do_resize)
        end

        if Builtins.size(@p_list) != 1 # there should be only one
          Builtins.y2error(
            "There was not exactly one partition with minor <%1> in the partition list <%2>",
            @do_resize,
            @partitions
          )
          internal_error
          return :abort # abort installation
        else
          Builtins.y2milestone(
            "Partition minor <%1> found in partition list.",
            @do_resize
          )
        end

        # assign the windows partition map
        #
        @win_partition = Ops.get_map(@p_list, 0, {})

        # check if this partition is the right one
        #
        if Storage.GetDeviceName(
            @target_is,
            Ops.get_integer(@win_partition, "nr", -1)
          ) != @win_device
          Builtins.y2error(
            "Partition from the list <%1> is not the assigned windows device <%2>.",
            Storage.GetDeviceName(
              @target_is,
              Ops.get_integer(@win_partition, "nr", -1)
            ),
            @win_device
          )
          internal_error
          return :abort # abort installation
        else
          Builtins.y2milestone(
            "Found the Windows partition in the partition list."
          )
        end

        # Check file system type of windows partition
        #
        if !Partitions.IsDosPartition(
            Ops.get_integer(@win_partition, "fsid", 0)
          )
          Builtins.y2error(
            "Windows partition <%1> has wrong file system type.",
            @win_device
          )
          internal_error
          return :abort # abort installation
        else
          Builtins.y2milestone(
            "Windows partition <%1> has valid file system type - OK.",
            @win_device
          )
        end

        # Get region from win partition
        #
        @region = Ops.get_list(@win_partition, "region", [])

        if Builtins.size(@region) != 2
          Builtins.y2error(
            "Invalid region <%1> in Windows partition data struct.",
            @region
          )
          internal_error
          return :abort # abort installation
        else
          Builtins.y2milestone(
            "Old region <%1> OK in Windows partition data struct.",
            @region
          )
        end

        # mount the partition to execute some checks
        #

        @mount_result = Convert.to_boolean(
          SCR.Execute(
            path(".target.mount"),
            [@win_device, Installation.scr_destdir, Installation.mountlog]
          )
        )
        if !@mount_result
          Builtins.y2error(
            "Current Windows device <%1> could not be mounted. Canceled",
            @win_device
          )
          @local_ret = -1
          internal_error
          return :abort # abort installation
        else
          Builtins.y2milestone(
            "Current Windows device <%1> mounted on %2.",
            @win_device,
            Installation.scr_destdir
          )
          @local_ret = 0
        end

        # get usage information for the partition via df
        #
        @df_result = Convert.convert(
          SCR.Read(path(".run.df")),
          :from => "any",
          :to   => "list <map>"
        )

        SCR.Execute(path(".target.umount"), @win_device)

        Builtins.y2debug(".run.df: %1", @df_result)

        # filter out headline and other invalid entries
        @df_result = Builtins.filter(@df_result) do |part|
          Builtins.substring(Ops.get_string(part, "spec", ""), 0, 1) == "/"
        end

        Builtins.foreach(@df_result) do |part|
          if Ops.get_string(part, "spec", "") == @win_device # find right entry
            # get the usage values
            #
            @win_used = Builtins.tointeger(Ops.get_string(part, "used", "-1"))
            @win_free = Builtins.tointeger(Ops.get_string(part, "free", "-1"))

            if @win_used != -1 && @win_free != -1
              @win_used = Ops.divide(@win_used, 1024) # MB
              @win_free = Ops.divide(@win_free, 1024) # MB

              Builtins.y2milestone(
                ".run.df: win_used: <%1> win_free:<%2>",
                @win_used,
                @win_free
              )
            end
          end
        end

        if @win_used == -1 || @win_free == -1
          Builtins.y2error(
            "The sizes for device <%1> could not be examined in df_result <%2>. Canceled",
            @win_device,
            @df_result
          )

          internal_error
          return :abort # abort installation
        else
          # Apply some checks to determine if installing Linux is feasible at all.
          #
          @feasible = true

          # Set minimal free Windows size to 200 MB. Running Windows with
          # less disk space is no fun.
          #
          @min_win_free = 200 if Ops.less_than(@min_win_free, 200)

          # If this is more than the free space on the device Windows is already
          # overcrowded and Linux shouldn't be installed.
          #
          @feasible = false if Ops.greater_than(@min_win_free, @win_free)

          # Now see if the so calculated Linux space is big enough
          #
          if @feasible
            if Ops.less_than(Ops.subtract(@win_free, @min_win_free), @linux_min)
              @feasible = false
            else
              # Try to reserve 1.5 GB for linux (default installation).
              # Otherwise get as much as possible
              #
              if Ops.greater_than(Ops.subtract(@win_free, @min_win_free), 1500)
                @linux_size = 1500
              else
                @linux_size = Ops.subtract(@win_free, @min_win_free)
              end
            end
          end
          if !@feasible
            Builtins.y2error(
              "Current Windows device <%1> has not enough room for Linux. Canceled",
              @win_device
            )
            Builtins.y2error(
              "Space calculation: win_used: <%1> win_free: <%2> min_win_free: <%3> linux_min: <%4> linux_size: <%5>",
              @win_used,
              @win_free,
              @min_win_free,
              @linux_min,
              @linux_size
            )

            # The Windows partition has not enough free space for Linux. Tell the user the needed amount
            # of free space and that he should terminate the installation now.
            @explanation = Builtins.sformat(
              _(
                "An error has occurred.\n" +
                  "\n" +
                  "The space available on the Windows partition is not sufficient for\n" +
                  "the minimum Linux installation.\n" +
                  "\n" +
                  "To install Linux, boot Windows first and uninstall some \n" +
                  "applications or delete data to free space.\n" +
                  "\n" +
                  "You need at least %1 MB of free space on the\n" +
                  "Windows device, including Windows workspace and\n" +
                  "space for %2.\n"
              ),
              Ops.add(Ops.add(@linux_min, @min_win_free), 10),
              Product.name
            ) # 10 MB safety overhead

            return allow_back_abort_only(@explanation)
          else
            Builtins.y2milestone(
              "Space calculation: win_used: <%1> win_free:<%2> min_win_free: <%3> linux_min: <%4> linux_size: <%5>",
              @win_used,
              @win_free,
              @min_win_free,
              @linux_min,
              @linux_size
            )
          end
        end

        # Do a dosfsck on this partition to assure the file system is clean.
        # Do this only if not yet checked.
        #
        if !Storage.GetWinDevice # not yet checked
          # Inform the user that his Windows partition is being checked.
          @explanation = _(
            "Checking the file system of your Windows partition\n" +
              "for consistency.\n" +
              "\n" +
              "Depending on the size of your Windows partition\n" +
              "and the amount of space used, this may take a while.\n" +
              "\n"
          )

          UI.OpenDialog(Opt(:decorated), VBox(Label(@explanation)))
          @cmd = Ops.add(
            Ops.add(Ops.add("/usr/sbin/parted -s ", @target_is), " check "),
            @do_resize
          )

          Builtins.y2milestone("running: %1", @cmd)
          @local_ret = SCR.Execute(path(".target.bash"), @cmd)

          UI.CloseDialog

          if @local_ret != 0
            Builtins.y2error(
              "Current Windows device <%1> had errors with parted check. Canceled",
              @win_device
            )

            # The file system on the device is faulty. Tell the user he should correct those errors.
            @explanation2 = _(
              "An error has occurred.\n" +
                "\n" +
                "Your Windows partition has errors in the file system.\n" +
                "\n" +
                "Boot Windows and clear those errors by running\n" +
                "scandisk and defrag.\n" +
                "\n" +
                "If the problem occurs again next time, resize your\n" +
                "Windows partition by other means.\n"
            )

            return allow_back_abort_only(@explanation2) # OK
          else
            Builtins.y2milestone(
              "Current Windows device <%1> was OK with parted check.",
              @win_device
            )
            Storage.SetWinDevice(true)
          end
        end # end of not yet checked
      end # not test mode


      #///////////////////////////////////////////////////////////////////////
      # END: Preliminary action
      #///////////////////////////////////////////////////////////////////////

      #///////////////////////////////////////////////////////////////////////
      # START: GUI
      #///////////////////////////////////////////////////////////////////////

      @test_simple_ui = false # set to "true" to test non-graphical version

      # Unit for parition resizing - currently Megabytes
      @unit = _("MB")

      # Labels for bar graph. "%1" will be replace with a numeric value.
      @bargraph_label_win_used = Ops.add(_("Windows\nUsed\n%1 "), @unit)
      # Labels for bar graph. "%1" will be replace with a numeric value.
      @bargraph_label_win_free = Ops.add(_("Windows\nFree\n%1 "), @unit)
      # Labels for bar graph. "%1" will be replace with a numeric value.
      @bargraph_label_linux = Ops.add(_("Linux\n%1 "), @unit)

      # Labels for input fields. "%1" will be replaced with the current unit (MB).
      @field_label_win_free = Builtins.sformat(_("Windows Free (%1)"), @unit)
      # Labels for input fields. "%1" will be replaced with the current unit (MB).
      @field_label_linux = Builtins.sformat(_("Linux (%1)"), @unit)

      @contents = Empty()



      # Help text for Windows partition resizing -
      # common part for both graphical mode (with bar graphs)
      # and non-graphical mode (text only).
      @helptext = _(
        "<p>\n" +
          "Choose the new size for your Windows partition.\n" +
          "</p>"
      )

      # help text (common to both modes), continued
      @helptext = Ops.add(
        @helptext,
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
      @helptext = Ops.add(
        @helptext,
        _(
          "\n" +
            "<p>\n" +
            "To skip resizing your Windows partition, press\n" +
            "<b>Back</b>.\n" +
            "</p>\n"
        )
      )


      if UI.HasSpecialWidget(:Slider) && UI.HasSpecialWidget(:BarGraph) &&
          !@test_simple_ui
        @contents = VBox(
          VStretch(),
          # Headline above bar graph that displays current windows partition size
          Left(Label(_("Now"))),
          BarGraph(
            [@win_used, @win_free],
            [@bargraph_label_win_used, @bargraph_label_win_free]
          ),
          VStretch(),
          # Headline above bar graph that displays future windows and linux partitions
          Left(Label(_("After Installation"))),
          PartitionSplitter(
            Id(:linux_size),
            @win_used,
            @win_free,
            @linux_size,
            @linux_min,
            @min_win_free,
            @bargraph_label_win_used,
            @bargraph_label_win_free,
            @bargraph_label_linux,
            @field_label_win_free,
            @field_label_linux
          ),
          VStretch()
        )


        # help text, continued - graphical mode only
        # this help text will be appended to the help text common to both modes.
        @helptext = Ops.add(
          @helptext,
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
        @helptext = Ops.add(
          @helptext,
          _(
            "\n" +
              "<p>\n" +
              "Drag the slider or enter a numeric value in either\n" +
              "input field to adjust the suggested values.\n" +
              "</p>\n"
          )
        )

        # help text (graphical mode), continued
        @helptext = Ops.add(
          @helptext,
          _(
            "\n" +
              "<p>\n" +
              "Within the space you reserve for Linux, partitions will automatically be\n" +
              "created as necessary.\n" +
              "</p>"
          )
        ) # no special widgets -> simple fallback UI
      else
        @contents = HVSquash(
          VBox(
            HBox(
              # Label for used part of the Windows partition in non-graphical mode
              HWeight(3, Right(Label(_("Windows Used")))),
              HWeight(
                2,
                Label(Opt(:outputField), Builtins.sformat("%1", @win_used))
              ),
              HWeight(3, Left(Label(@unit)))
            ),
            VSpacing(0.5),
            HBox(
              # Label for free part of the Windows partition in non-graphical mode
              HWeight(3, Right(Label(_("Free")))),
              HWeight(
                2,
                Label(Opt(:outputField), Builtins.sformat("%1", @win_free))
              ),
              HWeight(3, Left(Label(@unit)))
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
                  @linux_min,
                  Ops.subtract(@win_free, @min_win_free), # max
                  @linux_size
                )
              ),
              HWeight(3, Left(Bottom(Label(@unit))))
            )
          )
        )

        # help text, continued - non-graphical mode only
        # this help text will be appended to the help text common to both modes.
        @helptext = Ops.add(
          @helptext,
          _(
            "\n" +
              "<p>Enter a value for the size of your <b>Linux</b> installation.\n" +
              "The partitions will automatically be created within this range\n" +
              "as required for &product;.\n" +
              "</p>\n"
          )
        )

        # help text (non-graphical mode), continued
        @helptext = Ops.add(
          @helptext,
          _(
            "\n" +
              "<p>\n" +
              "<b>Windows Used</b> is the size of the space your Windows partition uses.\n" +
              "</p>\n"
          )
        )

        # help text (non-graphical mode), continued
        @helptext = Ops.add(
          @helptext,
          _(
            "\n" +
              "<p><b>Free</b> indicates the current free space (before the Linux\n" +
              "installation) on the partition.\n" +
              "</p>"
          )
        )
      end


      Wizard.SetContents(
        _("Resizing the Windows Partition"),
        @contents,
        @helptext,
        Convert.to_boolean(WFM.Args(0)),
        Convert.to_boolean(WFM.Args(1))
      )
      begin
        @ret = Convert.to_symbol(Wizard.UserInput)

        return :abort if @ret == :abort && Popup.ReallyAbort(true)

        if @ret == :next
          # Get the value the user adjusted. If s/he entered a value
          # too big or too small this is automatically adjusted to the
          # biggest/smallest value possible (by Qt).
          #
          @linux_size = Convert.to_integer(
            UI.QueryWidget(Id(:linux_size), :Value)
          )
          @new_win_size = Ops.subtract(
            Ops.add(@win_used, @win_free),
            @linux_size
          )

          Builtins.y2milestone(
            "Linux size: <%1> - New Win size: <%2>",
            @linux_size,
            @new_win_size
          )
        end

        if @ret == :back
          # reset resize flag
          Storage.SetDoResize("NO")
          return :back
        end
      end until @ret == :next || @ret == :back || @ret == :cancel
      Storage.SaveExitKey(@ret)

      #///////////////////////////////////////////////////////////////////////
      # END: Main loop
      #///////////////////////////////////////////////////////////////////////

      #///////////////////////////////////////////////////////////////////////
      # START: Final action
      #///////////////////////////////////////////////////////////////////////

      # Now update the target map to the new situation
      #
      if !@test_mode
        # adjust the partition entry in the target map to reflect the new size

        # add flag and new size to the windows partition
        #
        @win_partition = Builtins.add(@win_partition, "resize", true)

        # adjust the region list in the windows partition to reflect the new size
        #
        @win_start = Ops.get(@region, 0, 0) # same as before resize
        @new_length_i = PartedSizeToCly(
          Ops.multiply(
            Ops.multiply(Builtins.tofloat(@new_win_size), 1024.0),
            1024.0
          ),
          @cyl_size
        )

        @region = [@win_start, @new_length_i]
        @win_partition = Builtins.add(@win_partition, "region", @region)

        Builtins.y2milestone(
          "New region of Windows partition after resize: <%1>",
          @region
        )

        # Insert the altered windows partition into the new cleaned partition list.
        #
        @partitions_new = Builtins.add(@partitions_new, @win_partition)

        Builtins.y2milestone(
          "New partition list with altered windows partition: <%1>",
          @partitions_new
        )

        # now let the automatic partitioner do its work
        @ok = create_partitions(@targets, @target, @partitions_new)
        if !@ok
          Popup.Message(
            _("The available space is not sufficient for an installation.")
          )
          @ret = :cancel
        end
      end

      #///////////////////////////////////////////////////////////////////////
      # END: final action
      #///////////////////////////////////////////////////////////////////////

      @ret
    end

    #///////////////////////////////////////////////////////////////////////
    # START: Functions
    #///////////////////////////////////////////////////////////////////////

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

      # To avoid an empty screen behind the popup display the
      # message also on the main window
      #
      contents = VBox(VStretch(), Left(Label(message)), VStretch())

      Wizard.SetContents(
        "", # no header in this case
        contents,
        "",
        Convert.to_boolean(WFM.Args(0)), # no help text in this case
        Convert.to_boolean(WFM.Args(1))
      )
      begin
        Popup.Message(message) # Display the message

        ret = Convert.to_symbol(UI.UserInput) # get user input

        if ret == :abort
          if !Popup.ReallyAbort(true)
            # user didn't want to abort ==> stay in loop
            ret = :dummy
          end
        elsif ret == :back
          # reset resize flag
          Storage.SetDoResize("NO")
        end
      end until ret == :abort || ret == :back

      ret
    end

    # Displays a popup with the message (can be dismissed with OK).
    # After that only `abort is allowed
    # Every other user action ==> redisplay message
    # Parameter: message to be displayed
    # Return   : nothing
    #
    def allow_abort_only(message)
      ret = :next

      # Enable back and next buttons independent of the settings
      # in installation.ycp so the user has a chance to see the
      # popup more than only once.
      #
      Wizard.EnableNextButton
      Wizard.EnableBackButton

      # To avoid an empty screen behind the popup display the
      # message also on the main window
      #
      contents = VBox(VStretch(), Left(Label(message)), VStretch())

      Wizard.SetContents(
        "", # no header in this case
        contents,
        "",
        Convert.to_boolean(WFM.Args(0)), # no help text in this case
        Convert.to_boolean(WFM.Args(1))
      )
      begin
        Popup.Message(message) # Display the message

        ret = Convert.to_symbol(UI.UserInput) # get user input

        if ret == :abort
          if !Popup.ReallyAbort(false)
            # user didn't want to abort ==> stay in loop
            ret = :dummy
          end
        end
      end until ret == :abort

      nil
    end

    # Displays an error message and waits for the user to press OK
    # Parameter : nothing
    # Return    : nothing
    #
    def internal_error
      # An internal error has occured. Tell the user that the installation should
      # be  terminated now and that his hard disk has not been altered yet.
      explanation = _(
        "An internal error has occurred.\n" +
          "\n" +
          "\t      You cannot shrink your Windows partition during\n" +
          "\t      installation. Your hard disk has not been altered.\n" +
          "\n" +
          "\t      Abort the installation now and shrink your\n" +
          "\t      Windows partition by other means.\n" +
          "\t      "
      )

      allow_abort_only(explanation)

      nil
    end

    # Calculate the free space within an extended partition that lies behind
    # a certain cylinder value (including this cylinder).
    # Parameter : List of partitions containing the extended partition.
    #             Start cylinder within an extended partition.
    # Return    : OK    -   Number of cylinders within the extended partition behind
    #                       the given start cylinder (including it).
    #		 Error -   -1
    #
    def get_extended_free(partitions, start_cylinder)
      partitions = deep_copy(partitions)
      # First get all extended partitions from the list.
      #
      mother_part = Builtins.filter(partitions) do |pentry|
        Ops.get_symbol(pentry, "type", :dummy) == :extended
      end

      # Next from this subset get the partition where the region includes
      # the given start cylinder.
      #
      mother_part = Builtins.filter(partitions) do |pentry|
        p_start2 = Ops.get_integer(pentry, ["region", 0], 0)
        p_length2 = Ops.get_integer(pentry, ["region", 1], 1)
        if Ops.less_than(p_start2, start_cylinder) &&
            Ops.greater_than(
              Ops.subtract(Ops.add(p_start2, p_length2), 1),
              start_cylinder
            )
          next true
        else
          next false
        end
      end

      return -1 if Builtins.size(mother_part) != 1 # should be exactly one

      ext_part = Ops.get_map(mother_part, 0, {}) # the extended partition
      p_start = Ops.get_integer(ext_part, ["region", 0], 0)
      p_length = Ops.get_integer(ext_part, ["region", 1], 0)

      ext_free = Ops.subtract(Ops.add(p_start, p_length), start_cylinder)

      ext_free
    end
  end
end

Yast::InstResizeUiClient.new.main
