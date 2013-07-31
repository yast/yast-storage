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
  module PartitioningLvmUiDialogsInclude
    def initialize_partitioning_lvm_ui_dialogs(include_target)
      textdomain "storage"


      Yast.import "Storage"
      Yast.import "Popup"

      Yast.include include_target, "partitioning/custom_part_dialogs.rb"
      Yast.include include_target, "partitioning/custom_part_lib.rb"
      Yast.include include_target, "partitioning/lvm_lv_lib.rb"
    end

    def HandleRemoveLv(targetMap, id)
      targetMap = deep_copy(targetMap)
      ret = false
      disk = Storage.GetDisk(targetMap, id)
      _Lv = Storage.GetPartition(targetMap, id)
      if Builtins.size(_Lv) == 0 || _Lv == nil ||
          Ops.get_symbol(_Lv, "type", :primary) != :lvm
        # Popup text
        Popup.Error(_("You can only remove logical volumes."))
      elsif Builtins.find(Ops.get_list(disk, "partitions", [])) do |p|
          Ops.get_string(p, "origin", "") == Ops.get_string(_Lv, "name", "")
        end != nil
        # Popup text
        Popup.Error(
          _(
            "There is at least one snapshot active for this volume.\nRemove the snapshot first."
          )
        )
      elsif Builtins.find(Ops.get_list(disk, "partitions", [])) do |p|
          Ops.get_string(p, "used_pool", "") == Ops.get_string(_Lv, "name", "")
        end != nil
        # Popup text
        Popup.Error(
          _(
            "There is at least one thin volume using this pool.\nRemove the thin volume first."
          )
        )
      else
        # Popup text
        message = Builtins.sformat(_("Remove the logical volume %1?"), id)

        ret = Storage.DeleteDevice(id) if Popup.YesNo(message)
      end
      Builtins.y2milestone("HandleRemoveLv ret:%1", ret)
      ret
    end
  end
end
