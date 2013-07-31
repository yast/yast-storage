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
  module PartitioningRaidLibInclude
    def initialize_partitioning_raid_lib(include_target)
      Yast.import "Partitions"

      textdomain "storage"
    end

    # Get all partitions, we can probably use as raid devices
    # Add needed information: is_raid, disksize
    def get_possible_rds(targetMap)
      targetMap = deep_copy(targetMap)
      ret = []

      #////////////////////////////////////////////////////////////////////
      # add the devicename i.e /dev/hda1 or /dev/system/usr to partition list
      # and the device key  <subdevice>/<maindevice> i.e. 1//dev/hda

      targetMap = Builtins.mapmap(targetMap) do |dev, devmap|
        partitions = Builtins.maplist(Ops.get_list(devmap, "partitions", [])) do |part|
          Ops.set(part, "maindev", dev)
          deep_copy(part)
        end
        { dev => Builtins.add(devmap, "partitions", partitions) }
      end

      #//////////////////////////////////////////////////////////
      # Look for all partitions:
      # not LVM ( here I mean /dev/<lvm_volumegroup>/<lv> entrys!
      #           there are only the lv's in the targetMap under
      #           /dev/<lvm_volumegroup>/<lv> !)
      # no mountpoint
      # id 0x83 or 0x8e or 0xfd
      # no RAID devices (this is for experts only, by hand)

      allret = []

      allowed_ctypes = [:CT_DISK, :CT_DMRAID, :CT_DMMULTIPATH]
      types_no = [:lvm, :sw_raid]
      fsids = [
        Partitions.fsid_lvm,
        Partitions.fsid_raid,
        Partitions.fsid_native,
        Partitions.fsid_swap
      ]
      allowed_enc_types = [:none]

      Builtins.foreach(targetMap) do |dev, devmap|
        if Builtins.contains(
            allowed_ctypes,
            Ops.get_symbol(devmap, "type", :CT_UNKNOWN)
          )
          ret = Builtins.filter(Ops.get_list(devmap, "partitions", [])) do |p|
            Builtins.size(Ops.get_string(p, "mount", "")) == 0 &&
              !Builtins.contains(types_no, Ops.get_symbol(p, "type", :primary)) &&
              Builtins.contains(
                allowed_enc_types,
                Ops.get_symbol(p, "enc_type", :none)
              ) &&
              (!Storage.IsUsedBy(p) ||
                Ops.get_symbol(p, "used_by_type", :UB_NONE) == :UB_MD) &&
              (!Builtins.haskey(p, "fsid") ||
                Builtins.contains(fsids, Ops.get_integer(p, "fsid", 0)))
          end
          allret = Convert.convert(
            Builtins.merge(allret, ret),
            :from => "list",
            :to   => "list <map>"
          )
        end
      end
      deep_copy(allret)
    end
  end
end
