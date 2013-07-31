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

#  * Module: 		auto_part_functions.ycp
#  *
#  * Authors: 		Andreas Schwab (schwab@suse.de)
#  *			Klaus Kämpf (kkaempf@suse.de)
#  *
#  * Purpose: 		This module define functions of general use
#  *			to the automatic partitioner
#  *
#  * $Id$
#  *
#  * needs global variables:
#  *
#  * integer bytes_per_unit
#  * integer first_logical_nr
#  * integer max_partitions
#  *
#  * defined functions:
#     global define size_of_region (list region) ``{
#     global define start_of_region (list region) ``{
#     global define end_of_region (list region) ``{
#     global define num_primary (list partitions) ``{
#     global define contains_extended (list partitions) ``{
#     global define extended_region (list partitions) ``{
#     global define can_create_logical (list partitions, integer first_logical,
#                                       integer max_logical ) ``{
#     global define can_resize( list partitions ) ``{
#     global define unused_extended_region (list partitions) ``{
#     global define compute_max_partitions (map target) ``{
#  *
module Yast
  module PartitioningAutoPartFunctionsInclude
    def initialize_partitioning_auto_part_functions(include_target)
      Yast.import "Arch"

      textdomain "storage"
    end

    # --------------------------------------------------------------
    # helper functions

    # Return the size of a disk region in bytes

    def size_of_region(region, bytes_per_unit)
      region = deep_copy(region)
      Ops.multiply(Ops.get(region, 1, 0), bytes_per_unit)
    end

    # Return the start of the region.

    def start_of_region(region)
      region = deep_copy(region)
      Ops.get(region, 0, 0)
    end

    # Return the end of the region, ie. start of the next region

    def end_of_region(region)
      region = deep_copy(region)
      Ops.add(Ops.get(region, 0, 0), Ops.get(region, 1, 0))
    end

    # Return the number of primary partitions

    def num_primary(partitions)
      partitions = deep_copy(partitions)
      n = 0

      Builtins.foreach(partitions) do |pentry|
        if Ops.get_symbol(pentry, "type", :unknown) == :primary
          n = Ops.add(n, 1)
        end
      end

      n
    end

    # The maximum partition number the kernel can handle for the target
    # disk, count from 0 on, return the maximal allowed value for
    # a partition number

    def compute_max_partitions(disk)
      disk = deep_copy(disk)
      ret = Ops.subtract(Ops.get_integer(disk, "max_primary", 4), 1)
      if Ops.get_string(disk, "label", "") == "msdos"
        if Ops.get_string(disk, "bus", "") == "IDE"
          ret = 63
        else
          ret = 15
        end
      end
      ret
    end


    # Return true if an extended partition exists

    def contains_extended(partitions)
      partitions = deep_copy(partitions)
      ret = Builtins.find(partitions) do |p|
        Ops.get_symbol(p, "type", :unknown) == :extended &&
          !Ops.get_boolean(p, "delete", false)
      end != nil
      ret
    end

    def ignored_partition(disk, part)
      disk = deep_copy(disk)
      part = deep_copy(part)
      # skip #3 on AlphaBSD and SparcBSD
      ret = Ops.get_string(disk, "label", "") == "bsd" ||
        Ops.get_string(disk, "label", "") == "sun"
      ret = Ops.get_integer(part, "nr", 0) == 3 if ret
      ret
    end

    # Return the region of the extended partition

    def extended_region(partitions)
      partitions = deep_copy(partitions)
      ret = [0, 0]
      Builtins.foreach(partitions) do |pentry|
        if Ops.get_symbol(pentry, "type", :unknown) == :extended
          ret = Ops.get_list(pentry, "region", [])
        end
      end
      deep_copy(ret)
    end




    # Check whether three logical partitions can be created without
    # running past the kernel limit for the number of partitions

    def can_create_logical(partitions, first_logical_nr, max_logical)
      partitions = deep_copy(partitions)
      logicals = Builtins.filter(partitions) do |pentry|
        Ops.get_symbol(pentry, "type", :unknown) == :logical
      end
      num_logical = Builtins.size(logicals)
      Ops.less_or_equal(
        Ops.add(Ops.add(first_logical_nr, num_logical), 2),
        max_logical
      )
    end

    # Check if the given partition is a FAT partition
    # Input:  partition map to be checked (from targets)
    # Return: true if partition is FAT, false otherwise
    #
    def is_fat_partition(partition)
      partition = deep_copy(partition)
      Ops.get_integer(partition, "fsid", -1) == 6 ||
        Ops.get_integer(partition, "fsid", -1) == 11 ||
        Ops.get_integer(partition, "fsid", -1) == 12 ||
        Ops.get_integer(partition, "fsid", -1) == 14 # Win95 FAT16 LBA
    end


    # Check if the given partition is a NTFS partition
    # Input:  partition map to be checked (from targets)
    # Return: true if partition is NTFS, false otherwise
    #
    def is_ntfs_partition(partition)
      partition = deep_copy(partition)
      Ops.get_integer(partition, "fsid", -1) == 7 ||
        Ops.get_integer(partition, "fsid", -1) == 134 ||
        Ops.get_integer(partition, "fsid", -1) == 135 # NTFS-Datenträger
    end


    # Get the partition map with the highest minor number out of the given partition list
    # Input:  List of partition maps.
    # Return: Partition map if found or $[] if not.
    #
    def get_last_used_partition(partitions)
      partitions = deep_copy(partitions)
      last_partition = {}
      minor = -1

      Builtins.y2milestone("get_last_used_partition p:%1", partitions)

      Builtins.foreach(partitions) do |partition|
        if Ops.greater_than(Ops.get_integer(partition, "nr", -1), minor)
          minor = Ops.get_integer(partition, "nr", -1)
          last_partition = deep_copy(partition)
        end
      end
      Builtins.y2milestone("get_last_used_partition ret %1", last_partition)
      deep_copy(last_partition)
    end


    # Check whether the partition list has a resizable partition as the highest partition.
    # Input:  List of partition maps
    # Return: resizeable partition map or $[] if none found
    #
    def can_resize(partitions)
      partitions = deep_copy(partitions)
      last_used_partition = {}

      if !Arch.i386
        Builtins.y2warning("Wrong architecture - can't resize partitions")
        return {} # for now
      end

      # Filter out empty space that might exist behind valid partitions.
      # This space would be there as a pseudo partition of type `free.
      #
      partitions_local = Builtins.filter(partitions) do |pentry|
        Ops.get_symbol(pentry, "type", :dummy) != :free
      end

      last_used_partition = get_last_used_partition(partitions_local)

      return {} if last_used_partition == {} # no last resizeable partition found

      # Check for supported filesystem types.
      #
      if is_fat_partition(last_used_partition)
        return deep_copy(last_used_partition)
      else
        return {}
      end
    end


    # Check if the given file does exist.
    # Input:  File to be checked incl. path as string, e.g. "/usr/lib/YaST2/clients/installation.ycp"
    #         This may also point to a directory.
    # Return: true if found, false if not.
    #
    def file_exist(file_path)
      file_found = Ops.greater_or_equal(
        Convert.to_integer(SCR.Read(path(".target.size"), file_path)),
        0
      )
      Builtins.y2milestone(
        "file %1 found %2 ret:%3",
        file_path,
        file_found,
        SCR.Read(path(".target.size"), file_path)
      )
      file_found
    end


    # Check whether the partition list has a resizable partition as the highest
    # partition.
    # Input:  map of data containing the disk
    # Return: true if there is NT on the system, otherwise false
    #
    def check_win_nt_system(disk)
      disk = deep_copy(disk)
      is_nt = false
      go_on = true
      local_ret = 0
      local_err = false
      partitions = []
      partitions_local = []
      fat_partition = ""

      partitions = Ops.get_list(disk, "partitions", [])
      if !is_nt && !local_err && go_on
        # First check if there are any NTFS partitions on the system
        #
        partitions_local = Builtins.filter(partitions) do |pentry|
          is_ntfs_partition(pentry)
        end

        is_nt = true if Builtins.size(partitions_local) != 0 # is NT system
      end

      if !is_nt && !local_err && go_on
        # Then look for specific files on all FAT partitions
        #
        partitions_local = Builtins.filter(partitions) do |pentry|
          is_fat_partition(pentry)
        end

        go_on = false if Builtins.size(partitions_local) == 0 # not an NT system
      end

      # If there are FAT partitions mount them and check specific files
      #
      if !is_nt && !local_err && go_on
        Builtins.foreach(partitions_local) do |pentry|
          # Now we are looping over all partitions for the current device.
          # get some special values from the partition entry.
          if !is_nt && !local_err && go_on
            # build devicename.
            fat_partition = Ops.get_string(pentry, "device", "")

            # mount the partition
            local_ret = Convert.to_integer(
              SCR.Execute(
                path(".target.bash"),
                Ops.add(Ops.add("/bin/mount ", fat_partition), " /mnt")
              )
            )

            if local_ret != 0
              Builtins.y2error(
                "FAT partition <%1> could not be mounted. Canceled",
                fat_partition
              )
              local_err = true
            end
          end
          if !is_nt && !local_err && go_on
            if file_exist("/mnt/winnt/system32/ntoskrnl.exe") ||
                file_exist("/mnt/winnt/system32/dllcache")
              Builtins.y2error(
                "Current Windows device <%1> is NT or 2000. Canceled",
                fat_partition
              )
              is_nt = true
            end
          end
          # unmount the partition if was mounted
          if !local_err
            SCR.Execute(
              path(".target.bash"),
              Ops.add("/bin/umount ", fat_partition)
            )
          end
        end # loop over all partitions
      end

      return 2 if local_err
      if is_nt
        return 1
      else
        return 0
      end
    end # End of check_win_nt_system()


    # Find unused space at the end of the extended partition
    def unused_extended_region(partitions)
      partitions = deep_copy(partitions)
      extended = extended_region(partitions)
      logicals = Builtins.filter(partitions) do |pentry|
        Ops.get_symbol(pentry, "type", :unknown) == :logical
      end
      end_of_logicals = 0

      if Ops.greater_than(Builtins.size(logicals), 0)
        end_of_logicals = end_of_region(
          Ops.get_list(
            logicals,
            [Ops.subtract(Builtins.size(logicals), 1), "region"],
            []
          )
        )
      else
        end_of_logicals = start_of_region(extended)
      end

      if Ops.less_than(end_of_logicals, end_of_region(extended))
        return [
          end_of_logicals,
          Ops.subtract(end_of_region(extended), end_of_logicals)
        ]
      end
      [0, 0]
    end
  end
end
