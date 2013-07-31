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
  module PartitioningPartitionDefinesInclude
    def initialize_partitioning_partition_defines(include_target)
      Yast.import "Mode"
      Yast.import "FileSystems"

      textdomain "storage"
    end

    #---------------------------------------------------------------------
    # get a list of not used mountpoints
    #------------------------------------
    # in:  targetMap
    # out: list of mountpoints for a combobox  ["/usr","/opt", ...]
    #---------------------------------------------------------------------

    def notUsedMountpoints(targetMap, all_mountpoints)
      targetMap = deep_copy(targetMap)
      all_mountpoints = deep_copy(all_mountpoints)
      if all_mountpoints == [] || all_mountpoints == nil
        all_mountpoints = FileSystems.SuggestMPoints
      end


      mountpoints = Builtins.maplist(targetMap) do |dev, devmap|
        Builtins.maplist(Ops.get_list(devmap, "partitions", [])) do |part|
          Ops.get_string(part, "mount", "")
        end
      end

      mountpoints = Builtins.flatten(
        Convert.convert(mountpoints, :from => "list", :to => "list <list>")
      )
      mountpoints = Builtins.union(mountpoints, []) # remove double entrys "" and swap

      not_used_mountpoints = Builtins.filter(all_mountpoints) do |mnt|
        !Builtins.contains(mountpoints, mnt)
      end

      deep_copy(not_used_mountpoints)
    end


    #//////////////////////////////////////////////////////////////////////
    # input:
    # win_size_f: new size of wimdows partion in bytes as float
    # cyl_size  : cylinder size
    #
    # output: lentgh of win-region in cylinder

    def PartedSizeToCly(win_size_f, cyl_size)
      win_size_f = deep_copy(win_size_f)
      new_length_f = Ops.divide(win_size_f, Builtins.tofloat(cyl_size))
      new_length_i = Builtins.tointeger(new_length_f)

      Builtins.y2debug(
        "new_length_f: <%1> - new_length_i: <%2>",
        new_length_f,
        new_length_i
      )

      if Builtins.tofloat(new_length_f) != Builtins.tofloat(new_length_i)
        new_length_i = Ops.add(new_length_i, 1) # add 1 cylinder if there is a residual
      end

      new_length_i
    end


    # Make a proposal for a single mountpoint
    # (first free on the list in installation,
    # empty string otherwise)
    #
    def SingleMountPointProposal
      if Mode.normal
        return ""
      else
        free_list = notUsedMountpoints(
          Storage.GetTargetMap,
          FileSystems.SuggestMPoints
        ) # = filter( string point, base,
        return Ops.get_string(free_list, 0, "")
      end
    end
  end
end
