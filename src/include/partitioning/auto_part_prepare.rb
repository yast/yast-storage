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

# Module:		inst_target_part.ycp
#
# Authors:		Andreas Schwab (schwab@suse.de)
#			Klaus Kämpf (kkaempf@suse.de)
#
# Purpose:		This module ask the user which partition to use:
#			-Determing possible partitions.
#			-Ask the user which partition to use.
#			-Check the input and return error-messages.
#
# $Id$
module Yast
  module PartitioningAutoPartPrepareInclude
    def initialize_partitioning_auto_part_prepare(include_target)
      textdomain "storage"

      Yast.import "Partitions"
    end

    def prepare_partitions(target, partitions)
      target = deep_copy(target)
      partitions = deep_copy(partitions)
      # --------------------------------------------------------------
      # The size of a unit (eg. one cylinder)
      bytes_per_unit = Ops.get_integer(target, "cyl_size", 1)
      # The size of the disk in units
      disk_size = Ops.get_integer(target, "cyl_count", 1)
      Builtins.y2milestone(
        "prepare_partitions bytes_per_unit: %1 disk_size:%2",
        bytes_per_unit,
        disk_size
      )

      size_of_boot = Partitions.ProposedBootsize
      size_of_swap = Ops.multiply(
        1024 * 1024,
        Partitions.SwapSizeMb(0, StorageProposal.GetProposalSuspend)
      )

      # The minimum size needed to install a default system
      required_size = Ops.add(
        Ops.add(1500 * 1024 * 1024, size_of_boot),
        size_of_swap
      )

      # filter out all "create" paritions, they will be re-created at exit
      #   (this ensures a 'clean' partition list if this dialogue is re-entered

      partitions = Builtins.filter(partitions) do |pentry|
        !Ops.get_boolean(pentry, "create", false)
      end

      # reset all "delete" paritions, they will be re-created at exit
      #   (this ensures a 'clean' partition list if this dialogue is re-entered

      partitions = Builtins.maplist(partitions) do |pentry|
        Builtins.add(pentry, "delete", false)
      end

      # The region that describes the full disk
      full_region = [0, disk_size]

      #-------------------------------------------------------------------------
      # The action
      #-------------------------------------------------------------------------

      # First sort the partitions on the starting cylinder
      partitions = Builtins.sort(partitions) do |p1, p2|
        Ops.less_than(
          start_of_region(Ops.get_list(p1, "region", [])),
          start_of_region(Ops.get_list(p2, "region", []))
        )
      end

      # now check if automatic partitioning if feasible

      # unpartitioned disk -> yes

      @can_do_auto = false

      if Builtins.size(partitions) == 0
        # No partitions -> use the entire disk
        @can_do_auto = true
        @unused_region = deep_copy(full_region)
      end

      # extended region with enough free space -> yes

      if !@can_do_auto && contains_extended(partitions)
        # Extended partition already exists -> look for free space at
        # the end of it
        @unused_region = unused_extended_region(partitions)

        # check if this is enough
        if Ops.greater_than(
            size_of_region(@unused_region, bytes_per_unit),
            required_size
          ) &&
            can_create_logical(
              partitions,
              5,
              Ops.get_integer(target, "max_logical", 15)
            )
          @can_do_auto = true
        end
      end

      # no extended region, but primaries left
      #   if there is enough space after the last defined primary -> yes

      if !@can_do_auto && !contains_extended(partitions) &&
          num_primary(partitions) != @max_primary
        last_partition = Ops.get(
          partitions,
          Ops.subtract(Builtins.size(partitions), 1),
          {}
        )
        if ignored_partition(target, last_partition)
          last_partition = Ops.get(
            partitions,
            Ops.subtract(Builtins.size(partitions), 2),
            {}
          )
        end
        last_region = Ops.get_list(last_partition, "region", [])
        last_used = end_of_region(last_region)

        if Ops.less_than(last_used, disk_size)
          @unused_region = [last_used, Ops.subtract(disk_size, last_used)]
          if Ops.greater_than(
              size_of_region(@unused_region, bytes_per_unit),
              required_size
            )
            @can_do_auto = true
          end
        end
      end


      #-------------------------------------------------------------------------
      # Augment the partition list with a description for holes

      last_end = 0
      free_nr = 0

      last_end = 1 if Ops.get_string(target, "label", "") == "sun"

      # first the mid-disk holes

      partitions = Builtins.flatten(Builtins.maplist(partitions) do |pentry|
        ret = []
        region = Ops.get_list(pentry, "region", [])
        if !ignored_partition(target, pentry) &&
            Ops.greater_than(start_of_region(region), last_end)
          free_nr = Ops.add(free_nr, 1)
          ret = Builtins.add(
            ret,
            {
              "type"   => :free,
              "region" => [
                last_end,
                Ops.subtract(start_of_region(region), last_end)
              ]
            }
          )
          # if free space is directly located before extended partition
          last_end = start_of_region(region)
        end
        # if this partition is not the extended partition or a ignored
        #    use its end_of_region as last_end
        # on BSD-like partitions, partition # 3 is handled similary
        if Ops.get_symbol(pentry, "type", :unknown) != :extended &&
            !ignored_partition(target, pentry)
          last_end = end_of_region(Ops.get_list(pentry, "region", []))
        end
        Builtins.add(ret, pentry)
      end)

      # then the end-disk hole

      if Ops.less_than(last_end, disk_size)
        free_nr = Ops.add(free_nr, 1)
        partitions = Builtins.add(
          partitions,
          {
            "type"   => :free,
            "region" => [last_end, Ops.subtract(disk_size, last_end)]
          }
        )
      end

      # now the partitions list spans the whole disk

      #-------------------------------------------------------------------------
      # Create a checkbox for every real (primary or logical) partition
      # and any free space

      # give each partition a unique id

      ui_id = 0
      partitions = Builtins.maplist(partitions) do |p|
        ui_id = Ops.add(ui_id, 1)
        Ops.set(p, "ui_id", ui_id)
        if Ops.get_symbol(p, "type", :unknown) == :free
          Ops.set(
            p,
            "size_k",
            Ops.divide(
              size_of_region(
                Convert.convert(
                  Ops.get(p, "region") { [0, 0] },
                  :from => "any",
                  :to   => "list <const integer>"
                ),
                bytes_per_unit
              ),
              1024
            )
          )
        end
        if Builtins.haskey(p, "mount") &&
            Ops.get_string(p, "mount", "") != "swap" &&
            !Ops.get_boolean(p, "inactive", false)
          p = Builtins.remove(p, "mount")
        end
        deep_copy(p)
      end

      # now the partitions list spans the whole disk
      Builtins.y2milestone("prepare_partitions partitions: %1", partitions)

      deep_copy(partitions)
    end
  end
end
