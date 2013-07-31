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

# File:
#   disk.ycp
#
# Module:
#   Configuration of disk
#
# Summary:
#   Main file
#
# Authors:
#   Michael Hager <mike@suse.de>
#
# $Id$
#
# Wrapper file for inst_disk.ycp
#
module Yast
  class DiskClient < Client
    def main
      textdomain "storage"

      Yast.import "Popup"
      Yast.import "Wizard"
      Yast.import "Misc"
      Yast.import "Label"


      # popup text
      @msg = _(
        "Only use this program if you are familiar with partitioning hard disks.\n" +
          "\n" +
          "Never partition disks that may, in any way, be in use\n" +
          "(mounted, swap, etc.) unless you know exactly what you are\n" +
          "doing. Otherwise, the partitioning table will not be forwarded to the\n" +
          "kernel, which will most likely lead to data loss.\n" +
          "\n" +
          "To continue despite this warning, click Yes.\n"
      )


      # no params == UI, some params == commandline
      if Builtins.isempty(WFM.Args)
        Wizard.CreateDialog
        Wizard.SetContents(
          # dialog heading
          _("Expert Partitioner"),
          # text show during initialization
          Label(_("Initializing...")),
          # helptext
          _("<p>Volumes are being detected.</p>"),
          false,
          false
        )
        Wizard.SetDesktopTitleAndIcon("disk")

        # popup headline
        @warn = Builtins.tointeger(
          Misc.SysconfigRead(path(".sysconfig.storage.WARN_EXPERT"), "1")
        )
        Builtins.y2milestone("warn:%1", @warn)
        @warn = 1 if @warn == nil
        if @warn == 0 || Popup.YesNoHeadline(Label.WarningMsg, @msg) == true
          Builtins.y2milestone("--- Calling disk_worker %1 ---", WFM.Args)
          @ret = WFM.call("disk_worker", WFM.Args)
          Builtins.y2milestone("--- Returned: %1 ---", @ret)
        else
          Builtins.y2milestone("User decided not to run disk...")
        end

        Wizard.CloseDialog
      else
        Builtins.y2milestone("--- Calling disk_worker %1 ---", WFM.Args)
        @ret = WFM.call("disk_worker", WFM.Args)
        Builtins.y2milestone("--- Returned: %1 ---", @ret)
      end

      true
    end
  end
end

Yast::DiskClient.new.main
