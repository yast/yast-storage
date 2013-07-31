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
  module PartitioningLvmPvLibInclude
    def initialize_partitioning_lvm_pv_lib(include_target)
      textdomain "storage"
      Yast.import "Storage"
      Yast.import "Partitions"

      Yast.include include_target, "partitioning/lvm_lib.rb"
      Yast.include include_target, "partitioning/lvm_lv_lib.rb"
    end

    #////////////////////////////////////////////////////////////////////
    # add a partition to the current volume group
    #
    # 	   $[ 1 : $[  "use_module" : "lvm_ll"
    # 		      "type"       : "create_pv",
    # 		      "vgname"     : "system"     -- optional, wenn da dann vgextend nach pvcreate
    # 		      "device"     : "/dev/sda1"
    #
    #   !!!!!!! changes targetMap by reference !!!!!!
    #
    #////////////////////////////////////////////////////////////////////

    # used by autoyast
    def addPhysicalVolume(targetMap, id, current_vg)
      targetMap = deep_copy(targetMap)
      partition = Storage.GetPartition(targetMap, id)
      Builtins.y2milestone("partition %1", partition)

      if Ops.get_integer(partition, "fsid", 0) != Partitions.fsid_lvm &&
          Builtins.contains(
            [:primary, :logical],
            Ops.get_symbol(partition, "type", :none)
          )
        Storage.SetPartitionId(id, Partitions.fsid_lvm)
      end
      Storage.SetPartitionMount(id, "")
      Storage.SetPartitionFormat(id, false, :none)
      ret = Storage.ExtendLvmVg(current_vg, id)
      ret
    end


    #///////////////////////////////////////////////////////////////
    # Get all partitions, we can probably use as physical volumes
    # Add needed information: disksize
    def get_possible_pvs(targetMap)
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
      # not LVM ( here I mean /dev/<lvm_volumegroup>/<lv> entries!
      #           there are only the lv's in the targetMap under /dev/<lvm_volumegroup>/<lv> !)
      # no mountpoint
      # id 0x83 or 0x8e or 0xfe

      types_no = [:lvm, :extended]
      fsids = [
        Partitions.fsid_lvm,
        Partitions.fsid_raid,
        Partitions.fsid_native
      ]
      allowed_enc_types = [:none, :luks]

      Builtins.foreach(targetMap) do |dev, devmap|
        Builtins.y2milestone(
          "get_possible_pvs parts:%1",
          Ops.get_list(devmap, "partitions", [])
        )
        parts = Builtins.filter(Ops.get_list(devmap, "partitions", [])) do |part|
          Builtins.size(Ops.get_string(part, "mount", "")) == 0 &&
            !Builtins.contains(types_no, Ops.get_symbol(part, "type", :primary)) &&
            Builtins.contains(
              allowed_enc_types,
              Ops.get_symbol(part, "enc_type", :none)
            ) &&
            (!Storage.IsUsedBy(part) ||
              Ops.get_symbol(part, "used_by_type", :UB_NONE) == :UB_LVM) &&
            (Ops.get_symbol(part, "type", :primary) == :sw_raid ||
              Ops.get_symbol(part, "type", :primary) == :dm ||
              Builtins.contains(fsids, Ops.get_integer(part, "fsid", 0)))
        end
        Builtins.y2milestone("get_possible_pvs filter:%1", parts)
        if Ops.get_symbol(devmap, "used_by_type", :UB_NONE) != :UB_NONE
          parts = []
          Builtins.y2milestone(
            "get_possible_pvs no parts, disk used by %1 %2",
            Ops.get_symbol(devmap, "used_by_type", :UB_NONE),
            Ops.get_string(devmap, "used_by_device", "")
          )
        end
        if Builtins.size(Ops.get_list(devmap, "partitions", [])) == 0 &&
            Storage.IsPartType(Ops.get_symbol(devmap, "type", :CT_UNKNOWN)) &&
            (!Storage.IsUsedBy(devmap) ||
              Ops.get_symbol(devmap, "used_by_type", :UB_NONE) == :UB_LVM)
          p = {
            "device"  => dev,
            "maindev" => dev,
            "size_k"  => Ops.get_integer(devmap, "size_k", 0)
          }
          if Ops.get_symbol(devmap, "used_by_type", :UB_NONE) != :UB_NONE
            Ops.set(
              p,
              "used_by_type",
              Ops.get_symbol(devmap, "used_by_type", :UB_NONE)
            )
            Ops.set(
              p,
              "used_by_device",
              Ops.get_string(devmap, "used_by_device", "")
            )
          end
          if Builtins.haskey(devmap, "used_by")
            Ops.set(p, "used_by", Ops.get_list(devmap, "used_by", []))
          end
          parts = [p]
        end
        ret = Convert.convert(
          Builtins.merge(ret, parts),
          :from => "list",
          :to   => "list <map>"
        )
      end
      Builtins.y2milestone("get_possible_pvs ret %1", ret)
      deep_copy(ret)
    end


    def check_vgname_dev(vgname)
      ret = true
      devdir = Ops.add("/dev/", vgname)
      stat = Convert.to_map(SCR.Read(path(".target.stat"), devdir))
      Builtins.y2milestone("check_vgname_dev stat %1", stat)
      if Ops.greater_than(Builtins.size(stat), 0)
        ret = Ops.get_boolean(stat, "isdir", false)
        if ret
          out = Convert.to_map(
            SCR.Execute(
              path(".target.bash_output"),
              Ops.add(Ops.add("find ", devdir), " ! -type l | sed 1d")
            )
          )
          ret = Builtins.size(Ops.get_string(out, "stdout", "")) == 0
        end
      end
      Builtins.y2milestone("check_vgname_dev %1 ret %2", vgname, ret)
      ret
    end
  end
end
