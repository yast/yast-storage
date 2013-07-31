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
  module PartitioningLvmLvLibInclude
    def initialize_partitioning_lvm_lv_lib(include_target)
      textdomain "storage"
      Yast.import "Storage"
      Yast.import "Popup"

      Yast.include include_target, "partitioning/lvm_lib.rb"
      Yast.include include_target, "partitioning/lvm_pv_lib.rb"
    end

    def popupText(stripe)
      txt = _(
        "A logical volume with the requested size could \nnot be created.\n"
      )
      if Ops.greater_than(stripe, 1)
        txt = Ops.add(txt, _("Try reducing the stripe count of the volume."))
      end
      Popup.Error(txt)

      nil
    end

    def addLogicalVolume(_Lv, current_vg)
      _Lv = deep_copy(_Lv)
      ret = true
      if Ops.get_boolean(_Lv, "pool", false)
        ret = Storage.CreateLvmPool(
          current_vg,
          Ops.get_string(_Lv, "name", ""),
          Ops.get_integer(_Lv, "size_k", 0),
          Ops.get_integer(_Lv, "stripes", 1)
        )
      elsif !Builtins.isempty(Ops.get_string(_Lv, "used_pool", ""))
        ret = Storage.CreateLvmThin(
          current_vg,
          Ops.get_string(_Lv, "name", ""),
          Ops.get_string(_Lv, "used_pool", ""),
          Ops.get_integer(_Lv, "size_k", 0)
        )
      else
        ret = Storage.CreateLvmLv(
          current_vg,
          Ops.get_string(_Lv, "name", ""),
          Ops.get_integer(_Lv, "size_k", 0),
          Ops.get_integer(_Lv, "stripes", 1)
        )
      end
      if !ret
        popupText(Ops.get_integer(_Lv, "stripes", 1))
      else
        ret = Storage.ChangeVolumeProperties(_Lv)
        if Ops.greater_than(Ops.get_integer(_Lv, "stripes", 1), 1) &&
            Ops.greater_than(Ops.get_integer(_Lv, "stripesize", 0), 0)
          ret = Storage.ChangeLvStripeSize(
            current_vg,
            Ops.get_string(_Lv, "name", ""),
            Ops.get_integer(_Lv, "stripesize", 0)
          ) && ret
        end
      end
      ret
    end


    #//////////////////////////////////////////////////////////////////////////////
    # Get all existing lv names of a volume group

    def get_lv_names(target_map, vg_name)
      target_map = deep_copy(target_map)
      parts = Ops.get_list(
        target_map,
        [Ops.add("/dev/", vg_name), "partitions"],
        []
      )
      ret = Builtins.maplist(parts) { |part| Ops.get_string(part, "name", "") }
      deep_copy(ret)
    end
  end
end
