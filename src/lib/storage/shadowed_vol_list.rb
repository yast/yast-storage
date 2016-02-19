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
Yast.import "FileSystems"

module Yast
  class ShadowedVolList
    include Enumerable
    include Yast::Logger

    attr_reader :partition, :mount_point

    def initialize(partition: nil, mount_point: nil)
      raise ArgumentError unless partition && mount_point
      @partition = partition
      @mount_point = mount_point
      @volumes = selected_volumes
    end

    def each(&block)
      @volumes.each(&block)
    end

  protected

    def selected_volumes
      subvols = partition.fetch("subvol", [])
      log.debug "Full list of subvolumes: #{subvols}"
      subvols.select do |subvol|
        name = full_name(subvol)
        shadowed?(name)
      end
    end

    def shadowed?(name)
      (name == mount_point) || name.start_with?("#{mount_point}/")
    end

    def full_name(subvol)
      if FileSystems.default_subvol.empty?
        "/" + subvol.fetch("name")
      else
        subvol.fetch("name")[FileSystems.default_subvol.size..-1]
      end
    end
  end
end
