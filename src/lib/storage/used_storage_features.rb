#!/usr/bin/env ruby
#
# encoding: utf-8

# Copyright (c) [2015] SUSE LLC
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
# with this program; if not, contact SUSE LLC.
#
# To contact SUSE LLC about this file by physical or electronic mail, you may
# find current contact information at www.suse.com.

require "yast"
require "storage"
require "set"
require "pp"

# This file can be invoked separately for minimal testing.
# Use 'sudo' if you do that since it will do hardware probing with libstorage.

module Yast
  module StorageHelpers
    #
    # Class that collects information about which storage features are used
    # in the current targt machine's storage setup so add-on packages can be
    # marked for installation as needed.
    #
    class UsedStorageFeatures
      include Yast::Logger

      #======================================================================
      # Configurable part starts here
      #
      # Software packages required for storage features.
      # Any map value may be a string, a list of strings, or 'nil'.
      #
      # Packages that are part of a minimal installation (e.g., "util-linux")
      # are not listed here.
      #
      # :FT_BTRFS means Btrfs is used at all (on any volume),
      # :FT_BTRFS_ROOT means Btrfs is used for the root filesystem.
      # if :FT_BTRFS_ROOT is set, :FT_BTRFS is set, too.
      #
      FEATURE_PACKAGES =
        {
          # SUSE standard technologies
          FT_LVM:           "lvm2",
          # Btrfs needs e2fsprogs for 'lsattr' and 'chattr' to check for CoW
          FT_BTRFS:         ["btrfsprogs", "e2fsprogs"],
          FT_BTRFS_ROOT:    nil,  # use FT_SNAPSHOTS instead
          FT_SNAPSHOTS:     "snapper",
          FT_EFIBOOT:       "efibootbgr",

          # RAID technologies and related
          FT_DM:            ["device-mapper"],
          FT_DMMULTIPATH:   ["device-mapper", "multipath-tools"],
          FT_DMRAID:        ["device-mapper", "dmraid"],
          FT_MD:            "mdadm",
          FT_MDPART:        "mdadm",

          # Other filesystems
          FT_EXT2:          "e2fsprogs",
          FT_EXT3:          "e2fsprogs",
          FT_EXT4:          "e2fsprogs",
          FT_XFS:           "xfsprogs",
          FT_JFS:           "jfsutils",
          FT_REISERFS:      "reiserfs",
          FT_HFS:           "hfsutils",
          FT_NFS:           "nfsclient",
          FT_NFS4:          "nfsclient",
          FT_NTFS:          ["ntfs-3g", "ntfsprogs"],
          FT_VFAT:          "dosfstools",
          FT_LOOP:          nil, # util-linux which is always installed

          # Crypto technologies
          FT_LUKS:          "cryptsetup",
          FT_CRYPT_TWOFISH: "cryptsetup",

          # Data transport methods
          FT_ISCSI:         "open-iscsi",
          FT_FCOE:          "fcoe-utils",
          FT_FC:            nil,

          # Other
          FT_QUOTA:         "quota"
        }
      # configurable part ends here
      #======================================================================

      # Translate "used by" types to storage features
      USED_BY_FEATURES =
        {
          ::Storage::UB_LVM         => :FT_LVM,
          ::Storage::UB_MD          => :FT_MD,
          ::Storage::UB_DMRAID      => :FT_DMRAID,
          ::Storage::UB_DMMULTIPATH => :FT_DMMULTIPATH,
          ::Storage::UB_MDPART      => :FT_MDPART,
          ::Storage::UB_DM          => :FT_DM,
          ::Storage::UB_BTRFS       => :FT_BTRFS
        }

      # Translate container types to storage features
      CONTAINER_TYPE_FEATURES =
        {
          ::Storage::MD          => :FT_MD,
          ::Storage::LOOP        => :FT_LOOP,
          ::Storage::LVM         => :FT_LVM,
          ::Storage::DMRAID      => :FT_DMRAID,
          ::Storage::DMMULTIPATH => :FT_DMMULTIPATH,
          ::Storage::DM          => :FT_DM,
          ::Storage::MDPART      => :FT_MDPART,
          ::Storage::NFSC        => :FT_NFS,
          ::Storage::BTRFSC      => :FT_BTRFS
        }

      # Translate filesystem types to storage features
      # (only those that might need some add-on packages)
      FILESYSTEM_FEATURES =
        {
          ::Storage::REISERFS => :FT_REISERFS,
          ::Storage::EXT2     => :FT_EXT2,
          ::Storage::EXT3     => :FT_EXT3,
          ::Storage::EXT4     => :FT_EXT4,
          ::Storage::BTRFS    => :FT_BTRFS,
          ::Storage::VFAT     => :FT_VFAT,
          ::Storage::XFS      => :FT_XFS,
          ::Storage::JFS      => :FT_JFS,
          ::Storage::HFS      => :FT_HFS,
          ::Storage::NTFS     => :FT_NTFS,
          ::Storage::NFS      => :FT_NFS,
          ::Storage::NFS4     => :FT_NFS4
        }

      # Translate encryption methods to storage features
      ENCRYPTION_FEATURES =
        {
          ::Storage::ENC_LUKS           => :FT_LUKS,

          # No differentiation between all the old twofish crypto
          # technologies as far as we are concerned here
          ::Storage::ENC_TWOFISH        => :FT_CRYPT_TWOFISH,
          ::Storage::ENC_TWOFISH_OLD    => :FT_CRYPT_TWOFISH,
          ::Storage::ENC_TWOFISH256_OLD => :FT_CRYPT_TWOFISH
        }

      # Translate data transport methods to storage features
      TRANSPORT_FEATURES =
        {
          ::Storage::ISCSI => :FT_ISCSI,
          ::Storage::FCOE  => :FT_FCOE,
          ::Storage::FC    => :FT_FC
        }

      #
      #----------------------------------------------------------------------
      #

      def initialize(storage_interface = nil)
        @storage = storage_interface
      end

      def init_lazy
        return if @storage
        env = ::Storage::Environment.new(true)
        @storage = ::Storage.createStorageInterface(env)
      end

      # Collect storage features and return a feature list
      # (a list containing :FT_xy symbols). The list may be empty.
      #
      # @return [Array<Symbol>] feature list
      #
      def collect_features
        init_lazy
        log.info("Collecting storage features")
        features = Set.new
        containers = ::Storage::DequeContainerInfo.new
        @storage.getContainers(containers)
        containers.each { |c| features.merge(collect_container_features(c)) }

        volumes = ::Storage::DequeVolumeInfo.new
        @storage.getVolumes(volumes)
        volumes.each { |v| features.merge(collect_volume_features(v)) }

        feature_check(features, "System", "") { @storage.getEfiBoot ? :FT_EFIBOOT : nil }
        log.info("Storage features used: #{features.to_a}")

        features.to_a
      end

      # Collect storage features for one container and return a feature set.
      #
      # @param [ContainerInfo] data for one container (from libstorage)
      # @return [Set<Symbol>] feature set
      #
      def collect_container_features(cont)
        init_lazy
        features = Set.new

        # NOT using CONTAINER_TYPE_FEATURES since containers are not always
        # cleaned up properly: When all their volumes are deleted, sometimes
        # containers are left over, and then features are detected that are no
        # longer needed. If the corresponding feature is needed, there will be
        # a volume that also requests the feature either by "used by" or its
        # filesystem.
        #
        # feature_check(features, "Container", cont.name) { CONTAINER_TYPE_FEATURES[cont.type] }

        if cont.type == ::Storage::DISK
          disk = ::Storage::DiskInfo.new
          @storage.getDiskInfo(cont.name, disk)
          feature_check(features, "Disk", cont.name) { TRANSPORT_FEATURES[disk.transport] }
        end

        features
      end

      # Collect storage features for one volume (partition etc.)
      # and return a feature set.
      #
      # @param [VolumeInfo] data for one volume (from libstorage)
      # @return [Set<Symbol>] feature set
      #
      def collect_volume_features(vol)
        features = Set.new
        name = vol.name

        vol.usedBy.each do |u|
          feature_check(features, "Volume", name) { USED_BY_FEATURES[u.type] }
        end

        feature_check(features, "Volume",  name, "encryption") { ENCRYPTION_FEATURES[vol.encryption] }

        if !vol.mount.empty?
          feature_check(features, "Volume",  name, "filesystem") { FILESYSTEM_FEATURES[vol.fs] }
          feature_check(features, "Volume",  name) { snapshots?(vol) ? :FT_SNAPSHOTS : nil }
          feature_check(features, "Root FS", name) { root_btrfs?(vol) ? :FT_BTRFS_ROOT : nil }

          feature_check(features, "Volume", name, "quota") do
            vol.fstab_options.match(/(usr|grp)j?quota/i) ? :FT_QUOTA : nil
          end
        end

        features
      end

      # Generic feature check: Evaluate the supplied code block that may return
      # a storage feature symbol or 'nil'. If non-nil, the feature will be
      # added to the feature set in 'features', and a log line will be written.
      #
      # @param [Set<Symbol> feature set
      # @param [String]     object type that is being checked (Container, Disk, Volume)
      # @param [String]     name of the object that is being checked
      # @param [String]     feature type that is checked for ("feature", "filesystem", ...)
      # @param [Block]      code block that does the checking (return nil or a FT_... symbol)
      # @return [Set<Symbol>] feature set
      #
      def feature_check(features, type, name, feature_type = "feature", &block)
        feature = block.call
        if feature
          features << feature
          log.info("#{type} #{name} uses #{feature_type} #{feature}")
        end
        features
      end

      # Check if a volume is a root filesystem with Btrfs
      #
      # @param [VolumeInfo] vol
      # @return [boolean] root btrfs?
      #
      def root_btrfs?(vol)
        vol.mount == "/" && FILESYSTEM_FEATURES[vol.fs] == :FT_BTRFS
      end

      # Check if snapshots are configured for a volume.
      #
      # @param [VolumeInfo] vol
      # @return [boolean] snapshots configured?
      #
      def snapshots?(vol)
        # Checking for filesystem Btrfs because userdata might be left over
        # even if a previous Btrfs partition got changed to a RAID volume
        vol.fs == ::Storage::BTRFS && vol.userdata.to_h.value?("snapshots")
      end

      # Return a list of software packages required for the storage features.
      # Uses 'features' if non-nil, otherwise collects the features with
      # collect_features.
      #
      # @param [Array<Symbol>] feature list or nil
      # @return [Array<Symbol>] package list
      #
      def feature_packages(features = nil)
        features = collect_features unless features
        feature_packages = Set.new

        features.each do |feature|
          pkg = FEATURE_PACKAGES[feature]
          next unless pkg
          log.info("Feature #{feature} requires pkg #{pkg}")
          if pkg.respond_to?(:each)
            feature_packages.merge(pkg)
          else
            feature_packages << pkg
          end
        end

        log.info("Storage feature packages: #{feature_packages.to_a}")
        feature_packages.to_a
      end
    end
  end
end

# if used standalone, do a minimalistic test case (invoke with "sudo"!)

if $PROGRAM_NAME == __FILE__  # Called direcly as standalone command? (not via rspec or require)
  used_features = Yast::StorageHelpers::UsedStorageFeatures.new
  features = used_features.collect_features
  print("Storage features: #{features}\n")
  pkg = used_features.feature_packages(features)
  print("Need packages: #{pkg}\n")
end
