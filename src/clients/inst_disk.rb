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
#   inst_disk.ycp
#
# Module:
#   Configuration of disk
#   - schedular for partitioning lvm and raid modules
#
# Summary:
#   Main file
#
# Authors:
#   Michael Hager <mike@suse.de>
#
# $Id$
#
# Main file for disk configuration. Uses all other files.
#
module Yast
  class InstDiskClient < Client
    def main
      textdomain "storage"


      Yast.import "Wizard"
      Yast.import "Mode"
      Yast.import "Storage"
      Yast.import "StorageClients"


      Builtins.y2milestone("start inst_disk")

      Builtins.y2milestone(
        "PartMode %1 ProposalActive %2 ",
        Storage.GetPartMode,
        Storage.GetPartProposalActive
      )


      if !Storage.GetCustomDisplay && Storage.GetPartMode != "CUSTOM" &&
          Storage.GetPartMode != "PROP_MODIFY"
        @ret2 = Storage.GetExitKey
        Builtins.y2milestone("end inst_disk ret:%1", @ret2)
        return @ret2
      end


      Storage.CreateTargetBackup("disk") if !Storage.CheckBackupState("disk")


      @handle_dialog = Mode.normal || Mode.repair


      if @handle_dialog
        Wizard.CreateDialog
        Wizard.SetDesktopIcon("disk")
        StorageClients.EnablePopup
      end

      #***********************************************
      #   Let's do the work ...
      #***********************************************
      @ret = Convert.to_symbol(
        WFM.CallFunction("inst_custom_part", [true, true])
      )

      if @handle_dialog
        Wizard.CloseDialog
      else
        if @ret == :back || @ret == :abort
          Storage.RestoreTargetBackup("disk")
        elsif @ret == :next
          Storage.DisposeTargetBackup("disk")
          Storage.SetPartProposalActive(false)
        end
      end

      Storage.SaveExitKey(@ret)
      Builtins.y2milestone("end inst_disk ret:%1", @ret)
      @ret
    end
  end
end

Yast::InstDiskClient.new.main
