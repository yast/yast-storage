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
#   lvm_lib.ycp
#
# Module:
#   LVM
#
# Summary:
#  main lib for defines, which are not lv or pv specific
#
# Authors:
#   mike <mike@suse.de>
#
# $Id$
#
module Yast
  module PartitioningLvmLibInclude
    def initialize_partitioning_lvm_lib(include_target)
      textdomain "storage"
    end

    #////////////////////////////////////////////////////////////////////
    # get a list of all volume groups in the targetMap

    def get_vgs(targetMap)
      targetMap = deep_copy(targetMap)
      lvm_vg = []

      Builtins.foreach(targetMap) do |dev, devmap|
        if Ops.get_symbol(devmap, "type", :CT_UNKNOWN) == :CT_LVM
          # add a found volume group
          lvm_vg = Builtins.add(lvm_vg, Builtins.substring(dev, 5))
        end
      end
      deep_copy(lvm_vg)
    end
  end
end
