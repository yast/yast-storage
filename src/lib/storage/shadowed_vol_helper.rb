# Copyright (c) 2016 Novell, Inc.
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
# with this program; if not, contact SUSE.
#
# To contact SUSE about this file by physical or electronic mail, you may
# find current contact information at www.suse.com.

require "yast"
require "storage/shadowed_vol_list"

module Yast
  # Singleton class implementing user-friendly subvolumes handling for the
  # expert partitioner as described in fate#320296
  #
  # This is a singleton class (use .instance instead of .new) holding a global
  # list of deleted subvolumes to make possible to restore them during the same
  # execution of the expert partitioner.
  # @see .reset
  class ShadowedVolHelper
    include Yast::Logger
    include Singleton

    # Cleans the list of deleted subvolumes
    #
    # Expected to be called between subsequent executions of the expert
    # partitioner.
    def reset
      @aborted_subvols = []
    end

    # Copy of the root partition with all the shadowed subvolumes marked for
    # deletion and with the previously deleted subvolumes restored if they are
    # not shadowed anymore
    #
    # In order to make the recovery of previously deleted subvolumes possible,
    # it stores the deleted volumes in a list.
    # @see #reset
    #
    # @param target_map [Hash] map with the partitions layout
    def root_partition(target_map: Storage.GetTargetMap)
      return unless doable?(target_map)
      root_copy = deep_dup(root_part(target_map))
      restore_aborted_subvols(root_copy)
      abort_shadowed_subvols(root_copy, target_map)
      log.info "New list of subvolumes: #{root_copy["subvol"]}"
      root_copy
    end

    def initialize
      # Performing this import at the top of the file is dangerous because
      # the Storage module requires this file
      Yast.import "Storage"
    end

  protected

    def deep_dup(hash)
      Marshal.load(Marshal.dump(hash))
    end

    def partitions(target_map)
      target_map.values.each_with_object([]) do |disk, list|
        list.concat(disk.fetch("partitions", []))
      end
    end

    def root_part(target_map)
      partitions(target_map).detect {|p| p["mount"] == "/" }
    end

    def is_root?(partition)
      partition["mount"] == "/"
    end

    def doable?(target_map)
      if root_part(target_map).nil?
        log.info "No root partition found, skipping shadowed volumes update"
        false
      else
        true
      end
    end

    def aborted_subvols
      @aborted_subvols ||= []
    end

    def abort_shadowed_subvols(target_part, target_map)
      partitions(target_map).each do |part|
        if !is_root?(part) && part.has_key?("mount")
          abort_shadowed_subvols_for(target_part, part["mount"])
        end
      end
    end

    # Aborts creation of shadowed subvolumes
    def abort_shadowed_subvols_for(target_part, mount_point)
      shadowed = ShadowedVolList.new(partition: target_part, mount_point: mount_point)
      shadowed.each do |subvol|
        log.debug "Subvol to abort: #{subvol}"
        # Only abort planned volumes (don't delete pre-existing ones)
        if !subvol["create"]
          log.info "Skipping subvolume #{subvol["name"]}"
          next
        end

        log.info "Deleting subvolume #{subvol["name"]}"
        # Store it, so we can restore it
        memorize(subvol)
        # Mark it for removal ("delete" takes precedence over "create")
        subvol["delete"] = true
      end
      log.debug "Aborted subvols: #{aborted_subvols}"
    end

    def memorize(subvol)
      aborted_subvols << subvol.dup
    end

    def restore_aborted_subvols(target_part)
      aborted_subvols.each do |subvol|
        name = subvol["name"]
        log.info "Restore subvol #{name}?"
        log.debug "subvol: #{subvol}"
        subvols = target_part["subvol"] || []
        existing_subvol = subvols.detect { |s| s["name"] == name}
        if existing_subvol.nil?
          log.info "Restoring subvol"
          target_part["subvol"] ||= []
          target_part["subvol"] << subvol
        elsif existing_subvol["delete"]
          log.info "Rejecting subvol deletion"
          existing_subvol["delete"] = false
        end
      end
      reset
    end
  end
end
