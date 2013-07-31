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

# File:	StorageIcons.ycp
# Package:	yast2-storage
# Summary:	Expert Partitioner
# Authors:	Arvin Schnell <aschnell@suse.de>
require "yast"

module Yast
  class StorageIconsClass < Module
    def main
      @all_icon = "yast-disk.png"


      @hd_icon = "yast-disk.png"
      @hd_part_icon = "yast-partitioning.png"

      @lvm_icon = "yast-lvm_config.png"
      @lvm_lv_icon = "yast-partitioning.png"

      @raid_icon = "yast-raid.png"

      @loop_icon = "yast-encrypted.png"

      @dm_icon = "yast-device-mapper.png"

      @nfs_icon = "yast-nfs.png"

      @unused_icon = "yast-unused-device.png"

      @graph_icon = "yast-device-tree.png"

      @summary_icon = "yast-disk.png"

      @settings_icon = "yast-spanner.png"

      @log_icon = "yast-messages.png"


      @encrypted_icon = "yast-encrypted.png"
    end

    def IconMap(type)
      case type
        when :CT_DMRAID, :CT_MD, :CT_MDPART, :sw_raid
          return @raid_icon
        when :CT_DM, :CT_DMMULTIPATH, :dm
          return @dm_icon
        when :CT_DISK
          return @hd_icon
        when :CT_LOOP, :loop
          return @loop_icon
        when :CT_LVM
          return @lvm_icon
        when :lvm
          return @lvm_lv_icon
        when :CT_NFS, :nfs
          return @nfs_icon
        when :extended, :logical, :primary
          return @hd_part_icon
        else
          return "yast-hdd-controller-kernel-module.png"
      end
    end

    publish :variable => :all_icon, :type => "const string"
    publish :variable => :hd_icon, :type => "const string"
    publish :variable => :hd_part_icon, :type => "const string"
    publish :variable => :lvm_icon, :type => "const string"
    publish :variable => :lvm_lv_icon, :type => "const string"
    publish :variable => :raid_icon, :type => "const string"
    publish :variable => :loop_icon, :type => "const string"
    publish :variable => :dm_icon, :type => "const string"
    publish :variable => :nfs_icon, :type => "const string"
    publish :variable => :unused_icon, :type => "const string"
    publish :variable => :graph_icon, :type => "const string"
    publish :variable => :summary_icon, :type => "const string"
    publish :variable => :settings_icon, :type => "const string"
    publish :variable => :log_icon, :type => "const string"
    publish :variable => :encrypted_icon, :type => "const string"
    publish :function => :IconMap, :type => "string (symbol)"
  end

  StorageIcons = StorageIconsClass.new
  StorageIcons.main
end
