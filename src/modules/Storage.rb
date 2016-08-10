# encoding: utf-8

# Copyright (c) [2012-2015] Novell, Inc.
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

require "yast"
require "dbus"
require "storage"
require "storage/target_map_formatter"
require "storage/used_storage_features"
require "storage/shadowed_vol_helper"

module Yast
  class StorageClass < Module


    include Yast::Logger
    include Yast::StorageHelpers::TargetMapFormatter


    def main
      Yast.import "Pkg"
      Yast.import "UI"

      textdomain "storage"

      Yast.import "Arch"
      Yast.import "Directory"
      Yast.import "FileSystems"
      Yast.import "FileUtils"
      Yast.import "Installation"
      Yast.import "Label"
      Yast.import "Icon"
      Yast.import "Mode"
      Yast.import "Partitions"
      Yast.import "Popup"
      Yast.import "Report"
      Yast.import "Misc"
      Yast.import "HTML"
      Yast.import "StorageInit"
      Yast.import "StorageDevices"
      Yast.import "StorageClients"
      Yast.import "StorageSnapper"
      Yast.import "Stage"
      Yast.import "String"
      Yast.import "Hotplug"
      Yast.import "ProductFeatures"
      Yast.import "Service"
      Yast.import "Package"

      # simple resize functionality - dialog to set size of Linux and Windows before proposal

      @resize_partition = nil

      @resize_partition_data = nil

      @resize_cyl_size = nil

      @default_multipathing = false

      # end of resizing functions


      @conv_ctype = {
        "def_sym" => :CT_UNKNOWN,
        "def_int" => ::Storage::CUNKNOWN,
        "m"       => {
          ::Storage::DISK        => :CT_DISK,
          ::Storage::MD          => :CT_MD,
          ::Storage::LOOP        => :CT_LOOP,
          ::Storage::LVM         => :CT_LVM,
          ::Storage::DMRAID      => :CT_DMRAID,
          ::Storage::DMMULTIPATH => :CT_DMMULTIPATH,
          ::Storage::DM          => :CT_DM,
          ::Storage::MDPART      => :CT_MDPART,
          ::Storage::NFSC        => :CT_NFS,
          ::Storage::BTRFSC      => :CT_BTRFS,
          ::Storage::TMPFSC      => :CT_TMPFS
        }
      }

      @conv_usedby = {
        "def_sym" => :UB_NONE,
        "def_int" => ::Storage::UB_NONE,
        "m"       => {
          ::Storage::UB_LVM         => :UB_LVM,
          ::Storage::UB_MD          => :UB_MD,
          ::Storage::UB_DMRAID      => :UB_DMRAID,
          ::Storage::UB_DMMULTIPATH => :UB_DMMULTIPATH,
          ::Storage::UB_MDPART      => :UB_MDPART,
          ::Storage::UB_DM          => :UB_DM,
          ::Storage::UB_BTRFS       => :UB_BTRFS
        }
      }

      @conv_ptype = {
        "def_sym" => :primary,
        "def_int" => ::Storage::PRIMARY,
        "m"       => {
          ::Storage::LOGICAL  => :logical,
          ::Storage::EXTENDED => :extended
        }
      }

      @conv_mountby = {
        "def_sym" => :device,
        "def_int" => ::Storage::MOUNTBY_DEVICE,
        "m"       => {
          ::Storage::MOUNTBY_UUID  => :uuid,
          ::Storage::MOUNTBY_LABEL => :label,
          ::Storage::MOUNTBY_ID    => :id,
          ::Storage::MOUNTBY_PATH  => :path
        }
      }

      @conv_encryption = {
        "def_sym" => :none,
        "def_int" => ::Storage::ENC_NONE,
        "m"       => {
          ::Storage::ENC_TWOFISH        => :twofish,
          ::Storage::ENC_TWOFISH_OLD    => :twofish_old,
          ::Storage::ENC_TWOFISH256_OLD => :twofish_256_old,
          ::Storage::ENC_LUKS           => :luks,
          ::Storage::ENC_UNKNOWN        => :unknown
        }
      }

      @conv_mdtype = {
        "def_sym" => :raid_unknown,
        "def_int" => ::Storage::RAID_UNK,
        "m"       => {
          ::Storage::RAID0     => :raid0,
          ::Storage::RAID1     => :raid1,
          ::Storage::RAID5     => :raid5,
          ::Storage::RAID6     => :raid6,
          ::Storage::RAID10    => :raid10,
          ::Storage::MULTIPATH => :multipath
        }
      }

      @conv_mdstring = {
        "raid0"     => ::Storage::RAID0,
        "raid1"     => ::Storage::RAID1,
        "raid5"     => ::Storage::RAID5,
        "raid6"     => ::Storage::RAID6,
        "raid10"    => ::Storage::RAID10,
        "multipath" => ::Storage::MULTIPATH
      }

      @conv_mdparity = {
        "def_sym" => :par_default,
        "def_int" => ::Storage::PAR_DEFAULT,
        "m"       => {
          ::Storage::LEFT_ASYMMETRIC    => :left_asymmetric,
          ::Storage::LEFT_SYMMETRIC     => :left_symmetric,
          ::Storage::RIGHT_ASYMMETRIC   => :right_asymmetric,
          ::Storage::RIGHT_SYMMETRIC    => :right_symmetric,
          ::Storage::PAR_FIRST          => :par_first,
          ::Storage::PAR_LAST           => :par_last,
          ::Storage::LEFT_ASYMMETRIC_6  => :left_asymmetric_6,
          ::Storage::LEFT_SYMMETRIC_6   => :left_symmetric_6,
          ::Storage::RIGHT_ASYMMETRIC_6 => :right_asymmetric_6,
          ::Storage::RIGHT_SYMMETRIC_6  => :right_symmetric_6,
          ::Storage::PAR_FIRST_6        => :par_first_6,
          ::Storage::PAR_NEAR_2         => :par_near_2,
          ::Storage::PAR_OFFSET_2       => :par_offset_2,
          ::Storage::PAR_FAR_2          => :par_far_2,
          ::Storage::PAR_NEAR_3         => :par_near_3,
          ::Storage::PAR_OFFSET_3       => :par_offset_3,
          ::Storage::PAR_FAR_3          => :par_far_3
        }
      }

      @conv_parstring = {
        "default"            => ::Storage::PAR_DEFAULT,
        "left_asymmetric"    => ::Storage::LEFT_ASYMMETRIC,
        "left_symmetric"     => ::Storage::LEFT_SYMMETRIC,
        "right_asymmetric"   => ::Storage::RIGHT_ASYMMETRIC,
        "right_symmetric"    => ::Storage::RIGHT_SYMMETRIC,
        "parity_first"       => ::Storage::PAR_FIRST,
        "parity_last"        => ::Storage::PAR_LAST,
        "left_asymmetric_6"  => ::Storage::LEFT_ASYMMETRIC_6,
        "left_symmetric_6"   => ::Storage::LEFT_SYMMETRIC_6,
        "right_asymmetric_6" => ::Storage::RIGHT_ASYMMETRIC_6,
        "right_symmetric_6"  => ::Storage::RIGHT_SYMMETRIC_6,
        "parity_first_6"     => ::Storage::PAR_FIRST_6,
        "n2"                 => ::Storage::PAR_NEAR_2,
        "o2"                 => ::Storage::PAR_OFFSET_2,
        "f2"                 => ::Storage::PAR_FAR_2,
        "n3"                 => ::Storage::PAR_NEAR_3,
        "o3"                 => ::Storage::PAR_OFFSET_3,
        "f3"                 => ::Storage::PAR_FAR_3
      }

      @rev_conv_parstring = Builtins.mapmap(@conv_parstring) do |s, i|
        { i => s }
      end

      @conv_partalign = {
        "def_sym" => :align_optimal,
        "def_int" => ::Storage::ALIGN_OPTIMAL,
        "m"       => {
          ::Storage::ALIGN_OPTIMAL  => :align_optimal,
          ::Storage::ALIGN_CYLINDER => :align_cylinder
        }
      }

      @conv_transport = {
        "def_sym" => :unknown,
        "def_int" => ::Storage::TUNKNOWN,
        "m"       => {
          ::Storage::SBP   => :sbp,
          ::Storage::ATA   => :ata,
          ::Storage::FC    => :fc,
          ::Storage::ISCSI => :iscsi,
          ::Storage::SAS   => :sas,
          ::Storage::SATA  => :sata,
          ::Storage::SPI   => :spi,
          ::Storage::USB   => :usb,
          ::Storage::FCOE  => :fcoe
        }
      }


      @DiskMapVersion = {}
      @DiskMap = {}

      @type_order = {
        :CT_DISK        => 0,
        :CT_DMRAID      => 1,
        :CT_DMMULTIPATH => 2,
        :CT_MDPART      => 3,
        :CT_MD          => 4,
        :CT_DM          => 5,
        :CT_LVM         => 6,
        :CT_LOOP        => 7,
        :CT_NFS         => 8,
        :CT_BTRFS       => 9,
        :CT_TMPFS       => 10
      }

      @hw_packages = []

      @part_insts = nil


      # Storage = TargetMap
      # /* Storage = $[ "targets" 			: $[],
      # 		    "must_reread_partitions"   	: false,
      # 		    "win_device"   		: false,
      # 		    "testsuite"   		: false,
      # 		    "do_resize"    		: "",
      # 		    "part_proposal_mode"        : "",
      # 		    "part_proposal_first"       : true,
      # 		    "focus"		       	: key
      # 		    ]


      @StorageMap = {}

      # stringkeys for access  to the Storage map
      @targets_key = "targets"
      @part_mode_key = "part_mode"
      @part_disk_key = "part_disk"
      @testsuite_key = "testsuite"
      @do_resize_key = "do_resize"
      @win_device_key = "win_device"
      @custom_display_key = "custom_display"
      @part_proposal_mode_key = "part_proposal_mode"
      @part_proposal_first_key = "part_proposal_first"
      @part_proposal_active_key = "part_proposal_active"

      @probe_done = false
      @exit_key = :next
      @sint = nil
      @conts = []

      @count = 0

      @save_chtxt = ""


      @dbus_cookie = nil
      Storage()
    end


    def IsKernelDeviceName(device)
      Builtins.substring(device, 0, 6) != "LABEL=" &&
        Builtins.substring(device, 0, 5) != "UUID=" &&
        Builtins.substring(device, 0, 13) != "/dev/disk/by-"
    end


    def DeviceNameMightNeedAdaption(device)

      if IsKernelDeviceName(device)
        return true
      end

      if device.start_with?("/dev/disk/by-id/raid-") ||
          device.start_with?("/dev/disk/by-id/dm-name-") ||
          device.start_with?("/dev/disk/by-id/dm-uuid-DMRAID-")
        return true
      end

      return false

    end


    def InitLibstorage(readonly)
      return true if @sint != nil

      log.info("InitLibstorage")

      @sint = StorageInit.CreateInterface(readonly)
      if @sint == nil
        log.error("StorageInit::CreateInterface failed")
        return false
      end

      StorageClients.InstallCallbacks(@sint)

      btrfs_default_subvolume = ProductFeatures.GetStringFeature("partitioning",
                                                                 "btrfs_default_subvolume")
      @sint.setDefaultSubvolName(btrfs_default_subvolume) if btrfs_default_subvolume

      if Stage.initial
        @sint.setDetectMountedVolumes(false)
        @sint.setRootPrefix(Installation.destdir)

        if skip_activation_popup?
          val = @default_multipathing ? ::Storage::MPAS_ON : ::Storage::MPAS_OFF
          @sint.setMultipathAutostart(val)
        end
      end

      @conts = getContainers
      log.info("InitLibstorage conts:#{@conts}")

      FileSystems.InitSlib(@sint)
      Partitions.InitSlib(@sint)

      true
    end


    def FinishLibstorage
      return if @sint == nil

      log.info("FinishLibstorage")
      ::Storage::destroyStorageInterface(@sint)
      @sint = nil

      nil
    end


    def default_subvolume_name()
      return @sint.getDefaultSubvolName()
    end


    def ClassicStringToByte(str)
      ret, bytes = ::Storage::humanStringToByte(str,true)
      if( !ret )
        ts = Ops.add(str, "b")
	ret, bytes = ::Storage::humanStringToByte(ts,true)
	if( !ret )
	  bytes = 0
          Builtins.y2error("cannot parse %1 or %2", str, ts)
        end
      end
      bytes
    end


    def ByteToHumanString(bytes)
      return ::Storage::byteToHumanString(bytes, false, 2, false).force_encoding("UTF-8")
    end


    def KByteToHumanString(bytes_k)
      return ::Storage::byteToHumanString(bytes_k*1024, false, 2, false).force_encoding("UTF-8")
    end


    def ByteToHumanStringOmitZeroes(bytes)
      return ::Storage::byteToHumanString(bytes, false, 2, true).force_encoding("UTF-8")
    end


    def KByteToHumanStringOmitZeroes(bytes_k)
      return ::Storage::byteToHumanString(bytes_k*1024, false, 2, true).force_encoding("UTF-8")
    end


    def HumanStringToByte(str, bytes)
      i = 0
      bytes.value = i # bnc #408829 and #408891
      ret, bytes.value = ::Storage::humanStringToByte( str, false )
      Builtins.y2milestone(
        "HumanStringToByte ret: %1 str: %2 bytes: %3",
        ret,
        str,
        bytes.value
      )
      ret
    end


    def HumanStringToKByte(str, bytes_k)
      ret, bytes = ::Storage::humanStringToByte( str, false )
      bytes = 0 if !ret  # bnc #408829
      bytes_k.value = bytes.div(1024)
      Builtins.y2milestone(
        "HumanStringToKByte ret: %1 str: %2 bytes_k: %3",
        ret,
        str,
        bytes_k.value
      )
      ret
    end


    # Converts a string into a integer and checks the allowed range for the
    # integer. The range check is a bit sloppy to compensate rounding issues but
    # it's guaranteed that the result lies within the allowed range.
    def HumanStringToKByteWithRangeCheck(str, bytes_k, min_k, max_k)
      if !(
          bytes_k_ref = arg_ref(bytes_k.value);
          _HumanStringToKByte_result = HumanStringToKByte(str, bytes_k_ref);
          bytes_k.value = bytes_k_ref.value;
          _HumanStringToKByte_result
        )
        return false
      end

      if min_k != nil && Ops.less_than(bytes_k.value, min_k)
        if KByteToHumanString(bytes_k.value) != KByteToHumanString(min_k)
          return false
        end
        bytes_k.value = min_k
      end

      if max_k != nil && Ops.greater_than(bytes_k.value, max_k)
        if KByteToHumanString(bytes_k.value) != KByteToHumanString(max_k)
          return false
        end
        bytes_k.value = max_k
      end

      true
    end


    # Returns Device Name
    #
    # @param string Disk
    # @param [Object] partition
    # @return [String] device name
    #
    # @example Storage::GetDeviceName("/dev/md", 1)
    # @example Storage::GetDeviceName("/dev/system", "root")
    def GetDeviceName(disk, partition)
      ret = disk
      if Ops.is_integer?(partition)
        ret = @sint.getPartitionName(disk, Convert.to_integer(partition));
      elsif !Builtins.isempty(Convert.to_string(partition))
        ret = Ops.add(Ops.add(ret, "/"), Convert.to_string(partition))
      end
      ret
    end


    def SetIgnoreFstab(device, val)
      @sint.setIgnoreFstab(device, val)==0
    end


    def GetIgnoreFstab(device, val)
      ret, val.value = @sint.getIgnoreFstab(device);
      ret == 0
    end

    def toSymbol(conv, val)
      conv = deep_copy(conv)
      Ops.get_symbol(
        conv,
        ["m", val],
        Ops.get_symbol(conv, "def_sym", :invalid_conv_map)
      )
    end


    def fromSymbol(conv, val)
      conv = deep_copy(conv)
      ret = Ops.get_integer(conv, "def_int", -1)
      Builtins.foreach(Ops.get_map(conv, "m", {})) { |i, s| ret = i if s == val }
      ret
    end


    def GetContVolInfo(device, info)
      tmp = ::Storage::ContVolInfo.new()
      if @sint.getContVolInfo(device, tmp) != 0
        return false
      end

      info.value = {
        "ctype"   => toSymbol(@conv_ctype, tmp.ctype),
        "cname"   => tmp.cname,
        "cdevice" => tmp.cdevice,
        "vname"   => tmp.vname,
        "vdevice" => tmp.vdevice,
        "num"     => tmp.num
      }

      Builtins.y2milestone(
        "GetContVolInfo device: %1 info: %2",
        device,
        info.value
      )
      true
    end


    def GetDiskPartitionTg(inpdev, tg)
      tg = deep_copy(tg)
      device = inpdev
      ret = []
      dlen = 0
      as_string = false
      ls = Builtins.filter(Builtins.splitstring(device, "/")) do |s|
        !Builtins.isempty(s)
      end
      if Builtins.search(device, "LABEL=") == 0 ||
          Builtins.search(device, "UUID=") == 0
        tl = Builtins.splitstring(device, "=")
        ls = ["dev", "disk", "", Ops.get(tl, 1, "")]
        Ops.set(
          ls,
          2,
          Builtins.search(device, "LABEL=") == 0 ? "by-label" : "by-uuid"
        )
        Builtins.y2milestone("GetDiskPartitionTg ls: %1", ls)
      end
      Builtins.y2debug(
        "GetDiskPartitionTg size: %1 ls: %2",
        Builtins.size(ls),
        ls
      )

      if device == "/dev/tmpfs"
        ret = [ { "disk" => "/dev/tmpfs", "nr" => "" } ]
      elsif device == "tmpfs"
        # TODO multiple mount points issues unfixable
        ret = [ { "disk" => "/dev/tmpfs", "nr" => "tmpfs" } ]
      elsif Ops.greater_or_equal(Builtins.size(ls), 4) &&
          Ops.get(ls, 1, "") == "disk" &&
          Builtins.contains(
            ["by-id", "by-path", "by-uuid", "by-label"],
            Ops.get(ls, 2, "")
          )
        part = {}
        regex = "-part[0-9]+$"
        if Ops.get(ls, 2, "") == "by-label"
          Builtins.foreach(tg) do |dev, disk|
            part = Builtins.find(Ops.get_list(disk, "partitions", [])) do |p|
              Ops.get_string(p, "label", "") == Ops.get(ls, 3, "")
            end
            if part != nil
              tmp = {}
              Ops.set(tmp, "disk", dev)
              if Builtins.haskey(part, "nr")
                Ops.set(tmp, "nr", Ops.get(part, "nr", 0))
              else
                Ops.set(tmp, "nr", Ops.get_string(part, "name", ""))
              end
              ret = Builtins.add(ret, tmp)
            end
          end
        elsif Ops.get(ls, 2, "") == "by-uuid"
          Builtins.foreach(tg) do |dev, disk|
            part = Builtins.find(Ops.get_list(disk, "partitions", [])) do |p|
              Ops.get_string(p, "uuid", "") == Ops.get(ls, 3, "")
            end
            if part != nil
              tmp = {}
              Ops.set(tmp, "disk", dev)
              if Builtins.haskey(part, "nr")
                Ops.set(tmp, "nr", Ops.get(part, "nr", 0))
              else
                Ops.set(tmp, "nr", Ops.get_string(part, "name", ""))
              end
              ret = Builtins.add(ret, tmp)
            end
          end
        elsif Ops.get(ls, 2, "") == "by-id"
          id = Ops.get(ls, 3, "")
          num = 0
          l = Builtins.regexppos(id, regex)
          if Ops.greater_than(Builtins.size(l), 0)
            num = Builtins.tointeger(
              Builtins.substring(id, Ops.add(Ops.get_integer(l, 0, 0), 5))
            )
            id = Builtins.substring(id, 0, Ops.get_integer(l, 0, 0))
            Builtins.y2debug("GetDiskPartitionTg id: %1 num: %2", id, num)
          end
          Builtins.foreach(tg) do |dev, disk|
            if Builtins.size(ret) == 0 &&
                Builtins.find(Ops.get_list(disk, "udev_id", [])) { |s| s == id } != nil
              part = Builtins.find(Ops.get_list(disk, "partitions", [])) do |p|
                Ops.get_integer(p, "nr", 0) == num
              end
              if num == 0 || part != nil
                tmp = {}
                Ops.set(tmp, "disk", dev)
                if Ops.greater_than(num, 0)
                  Ops.set(tmp, "nr", num)
                else
                  Ops.set(tmp, "nr", "")
                end
                ret = [tmp]
              end
            end
          end
        elsif Ops.get(ls, 2, "") == "by-path"
          id = Ops.get(ls, 3, "")
          num = 0
          l = Builtins.regexppos(id, regex)
          if Ops.greater_than(Builtins.size(l), 0)
            num = Builtins.tointeger(
              Builtins.substring(id, Ops.add(Ops.get_integer(l, 0, 0), 5))
            )
            id = Builtins.substring(id, 0, Ops.get_integer(l, 0, 0))
            Builtins.y2debug("GetDiskPartitionTg id: %1 num: %2", id, num)
          end
          Builtins.foreach(tg) do |dev, disk|
            if Builtins.size(ret) == 0 &&
                Ops.get_string(disk, "udev_path", "") == id
              part = Builtins.find(Ops.get_list(disk, "partitions", [])) do |p|
                Ops.get_integer(p, "nr", 0) == num
              end
              if num == 0 || part != nil
                tmp = {}
                Ops.set(tmp, "disk", dev)
                if Ops.greater_than(num, 0)
                  Ops.set(tmp, "nr", num)
                else
                  Ops.set(tmp, "nr", "")
                end
                ret = [tmp]
              end
            end
          end
        end
      elsif Builtins.search(device, "/") == 0
        if Builtins.search(device, "/dev/hd") == 0 ||
            Builtins.search(device, "/dev/sd") == 0 ||
            Builtins.search(device, "/dev/ed") == 0 ||
            Builtins.search(device, "/dev/iseries/vd") == 0
          dlen = Builtins.findfirstof(device, "0123456789")
          dlen = Builtins.size(device) if dlen == nil
        elsif Builtins.search(device, "/dev/md") == 0 && Builtins.size(ls) == 2
          pos = Builtins.search(device, "p")
          if pos != nil
            dlen = pos
          else
            dlen = 7
          end
        elsif Builtins.search(device, "/dev/loop") == 0
          dlen = 9
        elsif Builtins.search(device, "/dev/i2o/hd") == 0
          dlen = 12
        elsif @sint.getPartitionPrefix(device)=="p"
          pos = Builtins.findlastof(device, "p")
          dlen = Builtins.size(device)
          dlen = pos if pos != nil
        elsif Builtins.search(device, "/dev/dasd") == 0
          dlen = Builtins.size(device)
          if Builtins.findfirstof(device, "0123456789") != nil
            dlen = Ops.subtract(dlen, 1)
          end
        elsif Builtins.search(device, "/dev/mapper/") == 0
          regex = "[_-]part[0-9]+$"
          l = Builtins.regexppos(device, regex)
          if Ops.greater_than(Builtins.size(l), 0)
            dlen = Ops.get_integer(l, 0, 0)
          else
            dlen = Builtins.size(device)
          end
        else
          as_string = true
          if Ops.greater_or_equal(Builtins.size(ls), 3)
            pos = Builtins.findlastof(device, "/")
            dlen = pos if pos != nil
          else
            dlen = Builtins.size(device)
            nonzero = Builtins.findlastnotof(device, "0123456789")
            if nonzero != nil && Ops.less_than(nonzero, Ops.subtract(dlen, 1))
              dlen = Ops.add(nonzero, 1)
              as_string = false
            end
          end
        end
        tmp = {}
        Ops.set(tmp, "disk", Builtins.substring(device, 0, dlen))
        device = Builtins.substring(device, dlen)
        if Builtins.search(device, "-part") == 0
          device = Builtins.substring(device, 5)
        end
        if Ops.greater_than(Builtins.size(device), 0) &&
            Builtins.findfirstof(device, "/p") == 0
          device = Builtins.substring(device, 1)
        end
        Ops.set(tmp, "nr", -1)
        if as_string
          Ops.set(tmp, "nr", device)
        else
          if Ops.greater_than(Builtins.size(device), 0)
            Ops.set(tmp, "nr", Builtins.tointeger(device))
          end
        end
        if Ops.greater_than(Builtins.size(Ops.get_string(tmp, "disk", "")), 0) &&
            Ops.get(tmp, "nr", 1) == -1
          Ops.set(tmp, "nr", "")
        end
        if Ops.greater_than(Builtins.size(tg), 0) &&
            !Builtins.haskey(tg, Ops.get_string(tmp, "disk", ""))
          Builtins.y2milestone("GetDiskPartitionTg tmp: %1", tmp)
          r = {}
          if (
              r_ref = arg_ref(r);
              _GetContVolInfo_result = GetContVolInfo(inpdev, r_ref);
              r = r_ref.value;
              _GetContVolInfo_result
            )
            Builtins.y2milestone("GetDiskPartitionTg rtmp: %1", r)
            if Builtins.haskey(tg, Ops.get_string(r, "cdevice", ""))
              Ops.set(tmp, "disk", Ops.get_string(r, "cdevice", ""))
              if Ops.get_integer(r, "num", -1) != -1
                Ops.set(tmp, "nr", Ops.get_integer(r, "num", -1))
              else
                Ops.set(tmp, "nr", Ops.get_string(r, "vname", ""))
              end
            end
          end
        end
        ret = [tmp]
      else
        ret = [{ "disk" => "/dev/nfs", "nr" => device }]
      end
      Builtins.y2debug("GetDiskPartitionTg device: %1 ret: %2", device, ret)
      deep_copy(ret)
    end


    # Returns map describing the disk partition
    #
    # @param [String] device
    # @return [Hash] DiskPartition
    #
    # Examples:
    #   "/dev/sda"            ->  $[ "disk" : "/dev/sda", "nr" : "" ]
    #   "/dev/sda2"           ->  $[ "disk" : "/dev/sda", "nr" : 2 ]
    #   "/dev/system"         ->  $[ "disk" : "/dev/system", "nr" : "" ]
    #   "/dev/system/abuild"  ->  $[ "disk" : "/dev/system", "nr" : "abuild" ]
    def GetDiskPartition(device)
      Ops.get(GetDiskPartitionTg(device, GetTargetMap()), 0, {})
    end


    def UpdateChangeTime
      change_time = ::Time.now.to_i
      Builtins.y2milestone("UpdateChangeTime time %1", change_time)
      Ops.set(@StorageMap, "targets_time", change_time)

      nil
    end


    # return list of partitions of map <tg>
    def GetPartitionLst(tg, device)
      tg = deep_copy(tg)
      ret = []
      tmp = GetDiskPartitionTg(device, tg)
      Builtins.y2milestone("GetPartitionLst tmp: %1", tmp)
      Builtins.foreach(tmp) do |m|
        disk = Ops.get_string(m, "disk", "")
        if Builtins.search(device, "/dev/evms") == 0 &&
            !Builtins.haskey(tg, disk)
          disk = "/dev/evms"
        end
        Builtins.y2debug("GetPartitionLst device=%1 disk=%2", device, disk)
        part = Builtins.filter(Ops.get_list(tg, [disk, "partitions"], [])) do |p|
          Ops.get_string(p, "device", "") == device
        end
        part = Builtins.filter(part) { |p| !Ops.get_boolean(p, "delete", false) }
        if Builtins.size(part) == 0 && Ops.is_integer?(Ops.get(m, "nr", 0))
          part = Builtins.filter(Ops.get_list(tg, [disk, "partitions"], [])) do |p|
            Ops.get_integer(p, "nr", -1) == Ops.get_integer(m, "nr", 0)
          end
          part = Builtins.filter(part) do |p|
            !Ops.get_boolean(p, "delete", false)
          end
        end
        if Builtins.size(part) == 0
          part = Builtins.filter(Ops.get_list(tg, [disk, "partitions"], [])) do |p|
            Ops.get_string(p, "name", "") == Ops.get_string(m, "nr", "")
          end
          part = Builtins.filter(part) do |p|
            !Ops.get_boolean(p, "delete", false)
          end
        end
        pa = Ops.get(part, 0, {})
        if Builtins.size(pa) == 0 &&
            Builtins.search(device, "/dev/mapper/") == 0
          part = Builtins.filter(
            Ops.get_list(tg, ["/dev/mapper", "partitions"], [])
          ) { |p| Ops.get_string(p, "device", "") == device }
          pa = Ops.get(part, 0, {})
        end
        if Builtins.size(pa) == 0 &&
            Builtins.search(device, "/dev/mapper/") == 0
          part = Builtins.filter(
            Ops.get_list(tg, ["/dev/loop", "partitions"], [])
          ) { |p| Ops.get_string(p, "device", "") == device }
          pa = Ops.get(part, 0, {})
        end
        ret = Builtins.add(ret, pa) if Ops.greater_than(Builtins.size(pa), 0)
      end
      Builtins.y2debug("GetPartitionLst ret=%1", ret)
      deep_copy(ret)
    end


    def GetPartition(tg, device)
      tg = deep_copy(tg)
      Convert.convert(
        Ops.get(GetPartitionLst(tg, device), 0, {}),
        :from => "map",
        :to   => "map <string, any>"
      )
    end


    # Returns disk identified by 'device' taken from the 'tg' (target) map
    #
    # @param [Hash{String => map}] tg (target map)
    # @param [String] device
    def GetDisk(tg, device)
      tg = deep_copy(tg)
      ret = {}
      tmp = Ops.get(GetDiskPartitionTg(device, tg), 0, {})
      disk = Ops.get_string(tmp, "disk", "")
      if Builtins.search(device, "/dev/evms") == 0 && !Builtins.haskey(tg, disk)
        disk = "/dev/evms"
      end
      Builtins.y2debug("GetDisk disk=%1", disk)
      Convert.convert(
        Ops.get(tg, disk, {}),
        :from => "map",
        :to   => "map <string, any>"
      )
    end


    # Get List of swap partitions
    # @return [Array] List of swap partitions
    def SwappingPartitions
      SCR.UnmountAgent(path(".proc.swaps"))
      swaps = Convert.convert(
        SCR.Read(path(".proc.swaps")),
        :from => "any",
        :to   => "list <map>"
      )
      if swaps == nil
        Builtins.y2error("SCR::Read(.proc.swaps) returned nil")
        Builtins.y2milestone(
          "/proc/swaps is %1",
          SCR.Execute(path(".target.bash_output"), "cat /proc/swaps")
        )
        swaps = []
      end
      swaps = Builtins.filter(swaps) do |e|
        Ops.get_string(e, "type", "") == "partition"
      end
      ret = Builtins.maplist(swaps) do |e|
        Partitions.TranslateMapperName(Ops.get_string(e, "file", ""))
      end
      Builtins.y2milestone("SwappingPartitions %1", ret)
      deep_copy(ret)
    end


    def GetFreeInfo(device, get_resize, resize_info, get_content, content_info, use_cache)
      resize_info.value = {}
      content_info.value = {}

      tmp1 = ::Storage::ResizeInfo.new()
      tmp2 = ::Storage::ContentInfo.new()

      ret = @sint.getFreeInfo(device, get_resize, tmp1, get_content,
          tmp2, use_cache)

      if ret
        if get_resize
          resize_info.value = {
            :df_free_k     => tmp1.df_freeK,
            :resize_free_k => tmp1.resize_freeK,
            :used_k        => tmp1.usedK,
            :resize_ok     => tmp1.resize_ok
          }
        end

        if get_content
          content_info.value = {
            :windows => tmp2.windows,
            :efi     => tmp2.efi,
            :homes   => tmp2.homes
          }
        end
      end

      Builtins.y2milestone("GetFreeInfo device: %1 ret: %2", device, ret)
      ret
    end


    # Returns map of free space per partition
    #
    # @param [String] device
    # @param integer testsize
    # @param [Symbol] used_fs
    # @param [Boolean] verbose
    def GetFreeSpace(device, used_fs, verbose)
      resize_info = {}
      content_info = {}

      r = (
        resize_info_ref = arg_ref(resize_info);
        content_info_ref = arg_ref(content_info);
        _GetFreeInfo_result = GetFreeInfo(
          device,
          true,
          resize_info_ref,
          true,
          content_info_ref,
          used_fs == :ntfs
        );
        resize_info = resize_info_ref.value;
        content_info = content_info_ref.value;
        _GetFreeInfo_result
      )

      used = 1024*Ops.get_integer(resize_info, :used_k, 0)
      resize_free = 1024*Ops.get_integer(resize_info, :resize_free_k, 0)
      df_free = 1024*Ops.get_integer(resize_info, :df_free_k, 0)
      resize_ok = Ops.get_boolean(resize_info, :resize_ok, false)

      win_disk = Ops.get_boolean(content_info, :windows, false)
      efi = Ops.get_boolean(content_info, :efi, false)

      if used_fs == :ntfs && (!r || !resize_ok) && verbose
        cmd = Builtins.sformat("/usr/sbin/ntfsresize -f -i '%1'", device)
        Builtins.y2milestone("GetFreeSpace Executing cmd: %1", cmd)
        bcall = Convert.to_map(
          SCR.Execute(
            path(".target.bash_output"),
            cmd,
            { "LC_MESSAGES" => "POSIX" }
          )
        )
        Builtins.y2milestone("GetFreeSpace Executing ret: %1", bcall)
        tmp = _("Resize Not Possible:") + "\n\n"
        tmp = Ops.add(
          Ops.add(tmp, Ops.get_string(bcall, "stdout", "")),
          Ops.get_string(bcall, "stderr", "")
        )
        Popup.Error(tmp)
        return {}
      end

      linux_size = 0
      min_linux_size = 0
      add_free = Ops.subtract(df_free, resize_free)

      Builtins.y2milestone(
        "GetFreeSpace resize_free %1 add_free %2",
        resize_free,
        add_free
      )

      if Ops.less_than(resize_free, 300 * 1024 * 1024) || !r
        linux_size = 0
        min_linux_size = 0
      elsif Ops.less_than(resize_free, 600 * 1024 * 1024)
        linux_size = resize_free
        if Ops.less_than(add_free, 75 * 1024 * 1024)
          linux_size = Ops.add(
            Ops.subtract(linux_size, 75 * 1024 * 1024),
            add_free
          )
        end
        min_linux_size = linux_size
      elsif Ops.less_than(resize_free, 1024 * 1024 * 1024)
        linux_size = resize_free
        if Ops.less_than(add_free, 200 * 1024 * 1024)
          linux_size = Ops.add(
            Ops.subtract(linux_size, 200 * 1024 * 1024),
            add_free
          )
        end
        min_linux_size = 300 * 1024 * 1024
      elsif Ops.less_than(resize_free, 2 * 1024 * 1024 * 1024)
        linux_size = resize_free
        if Ops.less_than(add_free, 300 * 1024 * 1024)
          linux_size = Ops.add(
            Ops.subtract(linux_size, 300 * 1024 * 1024),
            add_free
          )
        end
        min_linux_size = 500 * 1024 * 1024
      elsif Ops.less_than(resize_free, 3 * 1024 * 1024 * 1024)
        linux_size = resize_free
        if Ops.less_than(add_free, 800 * 1024 * 1024)
          linux_size = Ops.add(
            Ops.subtract(linux_size, 800 * 1024 * 1024),
            add_free
          )
        end
        min_linux_size = 500 * 1024 * 1024
      else
        linux_size = resize_free
        if Ops.less_than(add_free, Ops.divide(resize_free, 3))
          linux_size = Ops.add(
            Ops.subtract(linux_size, Ops.divide(resize_free, 3)),
            add_free
          )
        end
        min_linux_size = 500 * 1024 * 1024
      end

      new_size = Ops.subtract(
        Ops.add(Ops.add(used, add_free), resize_free),
        linux_size
      )

      ret = {
        "ok"           => r,
        "resize_ok"    => resize_ok,
        "free"         => (resize_free>0) ? resize_free : 0,
        "df_free"      => df_free,
        "used"         => used,
        "win_disk"     => win_disk,
        "efi"          => efi,
        "linux_size"   => linux_size,
        "max_win_size" => Ops.subtract(
          Ops.add(Ops.add(used, resize_free), add_free),
          min_linux_size
        ),
        "ntfs"         => used_fs == :ntfs,
        "new_size"     => new_size
      }

      Builtins.y2milestone("GetFreeSpace %1 ret %2", device, ret)
      ret
    end


    def GetUnusedPartitionSlots(device, slots)
      swig_slots = ::Storage::ListPartitionSlotInfo.new()
      ret = @sint.getUnusedPartitionSlots(device, swig_slots)
      slots.value = []
      swig_slots.each do |swig_slot|
        m = {
          :region => [ swig_slot.cylRegion.start, swig_slot.cylRegion.len ],
          :nr => swig_slot.nr,
          :device => swig_slot.device,
          :primary_slot => swig_slot.primarySlot,
          :primary_possible => swig_slot.primaryPossible,
          :extended_slot => swig_slot.extendedSlot,
          :extended_possible => swig_slot.extendedPossible,
          :logical_slot => swig_slot.logicalSlot,
          :logical_possible => swig_slot.logicalPossible
        }
	slots.value.push( m )
      end
      ret
    end


    def SaveDumpPath(name)
      ret = Ops.add(Ops.add(Directory.tmpdir, "/"), name)
      ret
    end


    def convertFsOptionMapToString(fsopt, cmd)
      fsopt = deep_copy(fsopt)
      ret = ""

      # do nothing
      if fsopt != nil || fsopt != {}
        ignore = ["auto", "default", "none", ""]

        Builtins.foreach(fsopt) do |option_key, option|
          option_str = Ops.get_string(option, "option_str", "")
          option_value = Ops.get(option, "option_value", "")
          option_blank = Ops.get_boolean(option, "option_blank", false)
          option_cmd = Ops.get_symbol(option, "option_cmd", :mkfs)
          Builtins.y2milestone(
            "convertFsOptionMapToString k: %1 opt: %2 val: %3 cmd: %4",
            option_key,
            option,
            option_value,
            option_cmd
          )
          if cmd == option_cmd
            if Ops.is_string?(option_value) && option_value != nil
              if !Builtins.contains(ignore, option_value)
                if Ops.greater_than(Builtins.size(ret), 0)
                  ret = Ops.add(ret, " ")
                end
                ret = Ops.add(ret, option_str)
                ret = Ops.add(ret, " ") if option_blank
                ret = Ops.add(ret, Convert.to_string(option_value))
              end
            elsif Ops.is_boolean?(option_value) && option_value != nil
              if Ops.greater_than(Builtins.size(option_str), 0)
                if Ops.greater_than(Builtins.size(ret), 0)
                  ret = Ops.add(ret, " ")
                end
                ret = Ops.add(ret, option_str)
              end
            elsif Ops.is_integer?(option_value) && option_value != nil
              ret = Ops.add(ret, " ") if Ops.greater_than(Builtins.size(ret), 0)
              ret = Ops.add(ret, option_str)
              ret = Ops.add(ret, " ") if option_blank
              ret = Ops.add(ret, Builtins.sformat("%1", option_value))
            end
          end
        end
      end
      if Ops.greater_than(Builtins.size(fsopt), 0) ||
          Ops.greater_than(Builtins.size(ret), 0)
        Builtins.y2milestone(
          "convertFsOptionMapToString fsopt: %1 ret: %2",
          fsopt,
          ret
        )
      end
      ret
    end


    def convertStringToFsOptionMap(opts, fs, cmd)
      ret = {}
      Builtins.y2milestone(
        "convertStringToFsOptionMap opts:\"%1\" fs: %2 cmd: %3",
        opts,
        fs,
        cmd
      )
      pos = Builtins.findfirstnotof(opts, " \t")
      opts = Builtins.substring(opts, pos) if Ops.greater_than(pos, 0)

      op = Convert.convert(
        FileSystems.GetOptions(fs),
        :from => "list",
        :to   => "list <map>"
      )
      op = Builtins.filter(op) do |o|
        Ops.get_symbol(o, :option_cmd, :mkfs) == cmd
      end

      while Ops.greater_than(Builtins.size(opts), 0)
        found = false
        Builtins.foreach(op) do |o|
          m = {}
          os = Ops.get_string(o, :option_str, "")
          nos = Ops.get_string(o, :option_false, "")
          se_ok = false
          found_os = false
          if Ops.greater_than(Builtins.size(os), 0) &&
              Builtins.search(opts, os) == 0
            found_os = true
            se_ok = true
          elsif Ops.greater_than(Builtins.size(nos), 0) &&
              Builtins.search(opts, nos) == 0
            found_os = false
            se_ok = true
          end
          if !found && se_ok
            found = true
            Ops.set(m, "option_str", found_os ? os : nos)
            Ops.set(m, "option_cmd", Ops.get_symbol(o, :option_cmd, :mkfs))
            if Ops.get_symbol(o, :type, :text) == :boolean
              Ops.set(m, "option_value", found_os)
              Ops.set(ret, Ops.get_string(o, :query_key, ""), m)
            end
            opts = Builtins.substring(
              opts,
              found_os ? Builtins.size(os) : Builtins.size(nos)
            )
            pos = Builtins.findfirstnotof(opts, " \t")
            opts = Builtins.substring(opts, pos) if Ops.greater_than(pos, 0)
            if Ops.get_symbol(o, :type, :text) != :boolean &&
                Ops.greater_than(Builtins.size(opts), 0) &&
                Builtins.search(opts, "-") != 0
              Ops.set(m, "option_blank", true) if Ops.greater_than(pos, 0)
              pos = Builtins.findfirstof(opts, " \t")
              if pos == nil
                Ops.set(m, "option_value", opts)
                opts = ""
              else
                Ops.set(m, "option_value", Builtins.substring(opts, 0, pos))
                opts = Builtins.substring(opts, pos)
              end
              Ops.set(ret, Ops.get_string(o, :query_key, ""), m)
            end
            pos = Builtins.findfirstnotof(opts, " \t")
            opts = Builtins.substring(opts, pos) if Ops.greater_than(pos, 0)
          end
        end
        if !found
          pos = Builtins.findfirstnotof(opts, " \t")
          if Ops.greater_than(pos, 0)
            opts = Builtins.substring(opts, pos)
          else
            opts = ""
          end
        end
        Builtins.y2milestone(
          "convertStringToFsOptionMap opts: %1 ret: %2",
          opts,
          ret
        )
      end
      Builtins.y2milestone("convertStringToFsOptionMap ret: %1", ret)
      deep_copy(ret)
    end


    def CheckBackupState(who)
      Builtins.y2milestone("CheckBackupStates who: %1", who)
      return nil if !InitLibstorage(false)
      ret = @sint.checkBackupState(who)
      Builtins.y2milestone("CheckBackupStates ret: %1", ret)
      ret
    end


    def diskMap(dinfo, d)
      d = deep_copy(d)
      Ops.set(d, "size_k", dinfo.sizeK)
      Ops.set(d, "cyl_size", dinfo.cylSize)
      Ops.set(d, "cyl_count", dinfo.cyl)
      Ops.set(d, "sector_size", dinfo.sectorSize)
      Ops.set(d, "label", dinfo.disklabel)
      tmp = dinfo.orig_disklabel
      Ops.set(d, "orig_label", tmp) if Ops.greater_than(Builtins.size(tmp), 0)
      Ops.set(d, "max_logical", dinfo.maxLogical)
      Ops.set(d, "max_primary", dinfo.maxPrimary)
      Ops.set(d, "dasd_format", dinfo.dasd_format)
      Ops.set(d, "dasd_type", dinfo.dasd_type)

      t = dinfo.transport
      Ops.set(d, "transport", toSymbol(@conv_transport, t))
      if t == ::Storage::ISCSI
        Ops.set(d, "iscsi", true)
      elsif Builtins.haskey(d, "iscsi")
        d = Builtins.remove(d, "iscsi")
      end

      bt = dinfo.has_fake_partition
      if bt
        Ops.set(d, "has_fake_partition", true)
      elsif Builtins.haskey(d, "has_fake_partition")
        d = Builtins.remove(d, "has_fake_partition")
      end

      bt = dinfo.initDisk
      if bt
        Ops.set(d, "dasdfmt", true)
      elsif Builtins.haskey(d, "dasdfmt")
        d = Builtins.remove(d, "dasdfmt")
      end
      Builtins.y2milestone("diskMap ret: %1", d)
      deep_copy(d)
    end


    def dmPartCoMap(infos, d)
      d = deep_copy(d)
      dinfo = infos.d
      d = diskMap(dinfo, d)
      d["devices"] = infos.devices.to_a
      Ops.set(d, "minor", infos.minor)
      Builtins.y2milestone("dmPartCoMap ret: %1", d)
      deep_copy(d)
    end


    def deviceMap(info)

      ret = {
        "device" => info.device,
        "name" => info.name
      }

      tmp = []
      info.usedBy.each do |used_by|
        tmp.push({ "type" => toSymbol(@conv_usedby, used_by.type), "device" => used_by.device })
      end

      if tmp.empty?
        ret["used_by_type"] = :UB_NONE
        ret["used_by_device"] = ""
      else
        ret["used_by"] = tmp
        ret["used_by_type"] = tmp[0]["type"]
        ret["used_by_device"] = tmp[0]["device"]
      end

      ret["udev_path"] = info.udevPath if !info.udevPath.empty?
      ret["udev_id"] = info.udevId.to_a if !info.udevId.empty?

      if !info.userdata.empty?
        # there's no to_h for the swig stl map object
        tmp = {}
        info.userdata.each do |a, b|
          tmp[a] = b
        end
        ret["userdata"] = tmp
      end

      return ret

    end


    def volumeMap(vinfo, p)
      p = deep_copy(p)
      p.merge!(deviceMap(vinfo))
      tmp = vinfo.crypt_device
      Ops.set(p, "crypt_device", tmp) if !Builtins.isempty(tmp)
      Ops.set(p, "size_k", vinfo.sizeK)
      fs = toSymbol(FileSystems.conv_fs, vinfo.fs)
      Ops.set(p, "used_fs", fs) if fs != :unknown
      fs = toSymbol(FileSystems.conv_fs, vinfo.detected_fs)
      Ops.set(p, "detected_fs", fs)
      Ops.set(p, "format", true) if vinfo.format
      Ops.set(p, "create", true) if vinfo.create
      tmp = vinfo.mount
      if !Builtins.isempty(tmp)
        Ops.set(p, "mount", tmp)
        Ops.set(p, "inactive", true) if !vinfo.is_mounted
        Ops.set(p, "mountby", toSymbol(@conv_mountby, vinfo.mount_by))
      end

      tmp = vinfo.fstab_options
      if !Builtins.isempty(tmp)
        Ops.set(p, "fstopt", tmp)
        if Builtins.find(Builtins.splitstring(tmp, ",")) { |s| s == "noauto" } != nil
          Ops.set(p, "noauto", true)
        end
      end
      tmp = vinfo.mkfs_options
      if !Builtins.isempty(tmp)
        Ops.set(p, "mkfs_opt", tmp)
        Ops.set(
          p,
          "fs_options",
          convertStringToFsOptionMap(
            tmp,
            Ops.get_symbol(p, "used_fs", :unknown),
            :mkfs
          )
        )
      else
        p = Builtins.remove(p, "fs_options") if Builtins.haskey(p, "fs_options")
      end
      tmp = vinfo.tunefs_options
      if !Builtins.isempty(tmp)
        Ops.set(p, "tunefs_opt", tmp)
        Ops.set(
          p,
          "fs_options",
          Builtins.union(
            Ops.get_map(p, "fs_options", {}),
            convertStringToFsOptionMap(
              tmp,
              Ops.get_symbol(p, "used_fs", :unknown),
              :tunefs
            )
          )
        )
      end
      tmp = vinfo.dtxt
      Ops.set(p, "dtxt", tmp) if !Builtins.isempty(tmp)
      tmp = vinfo.uuid
      Ops.set(p, "uuid", tmp) if !Builtins.isempty(tmp)
      tmp = vinfo.label
      Ops.set(p, "label", tmp) if !Builtins.isempty(tmp)
      t = vinfo.encryption
      if t != ::Storage::ENC_NONE
        Ops.set(p, "enc_type", toSymbol(@conv_encryption, t))
      end
      tbool = vinfo.resize
      if tbool
        Ops.set(p, "resize", true)
        Ops.set(p, "orig_size_k", vinfo.origSizeK)
      end
      Ops.set(p, "ignore_fs", true) if vinfo.ignore_fs
      Ops.set(p, "ignore_fstab", true) if vinfo.ignore_fstab
      tmp = vinfo.loop
      Ops.set(p, "loop", tmp) if !Builtins.isempty(tmp)

      deep_copy(p)
    end


    def partAddMap(info, p)
      p = deep_copy(p)
      Ops.set(p, "nr", info.nr)
      Ops.set(p, "fsid", info.id)
      Ops.set(
        p,
        "fstype",
        Partitions.FsIdToString(Ops.get_integer(p, "fsid", 0))
      )
      p["region"] = [ info.cylRegion.start, info.cylRegion.len ]
      Ops.set(p, "type", toSymbol(@conv_ptype, info.partitionType))
      Ops.set(p, "boot", true) if info.boot
      Builtins.y2milestone("partAddMap ret: %1", p)
      deep_copy(p)
    end


    def dmPartMap(info, p)
      p = deep_copy(p)
      vinfo = info.v
      p = volumeMap(vinfo, p)
      Ops.set(p, "nr", 0)
      part = info.part
      if part
        pinfo = info.p
        p = partAddMap(pinfo, p)
      end
      Builtins.y2milestone("dmPartMap ret: %1", p)
      deep_copy(p)
    end


    def mdPartMap(info, p)
      p = deep_copy(p)
      vinfo = info.v
      p = volumeMap(vinfo, p)
      Ops.set(p, "nr", 0)
      part = info.part
      if part
        pinfo = info.p
        p = partAddMap(pinfo, p)
      end
      Builtins.y2milestone("mdPartMap ret: %1", p)
      deep_copy(p)
    end


    def HasRaidParity(rt)
      Builtins.contains(["raid5", "raid6", "raid10"], rt)
    end


    def getContainerInfo(c)
      Builtins.y2milestone("getContainerInfo %1", c)
      ret = 0
      t = 0
      vinfo = ::Storage::VolumeInfo.new()
      if Ops.get_symbol(c, "type", :CT_UNKNOWN) == :CT_DISK
        pinfos = ::Storage::DequePartitionInfo.new()
        infos = ::Storage::DiskInfo.new()
        d = Ops.get_string(c, "device", "")
        ret = @sint.getDiskInfo( d, infos)
        if ret == 0
          c = diskMap(infos, c)
        else
          Builtins.y2warning(
            "disk \"%1\" ret: %2",
            Ops.get_string(c, "device", ""),
            ret
          )
        end
        Ops.set(c, "partitions", [])
        ret = @sint.getPartitionInfo(d, pinfos)
        pinfos.each do |info|
          tmp = ""
          p = {}
          vinfo = info.v
          p = volumeMap(vinfo, p)
          Ops.set(p, "nr", info.nr)
          Ops.set(p, "fsid", info.id)
          Ops.set(
            p,
            "fstype",
            Partitions.FsIdToString(Ops.get_integer(p, "fsid", 0))
          )
          p["region"] = [ info.cylRegion.start, info.cylRegion.len ]
          t = info.partitionType
          Ops.set(p, "type", toSymbol(@conv_ptype, t))
          boot = info.boot
          Ops.set(p, "boot", true) if boot
          Ops.set(
            c,
            "partitions",
            Builtins.add(Ops.get_list(c, "partitions", []), p)
          )
        end
      elsif Ops.get_symbol(c, "type", :CT_UNKNOWN) == :CT_DMRAID
        pinfos = ::Storage::DequeDmraidInfo.new()
        infos = ::Storage::DmraidCoInfo.new()
        d = Ops.get_string(c, "device", "")
        ret = @sint.getDmraidCoInfo(d,infos)
        if ret == 0
          pinfo = infos.p
          c = dmPartCoMap(pinfo, c)
        else
          Builtins.y2warning(
            "disk \"%1\" ret: %2",
            Ops.get_string(c, "device", ""),
            ret)
        end
        Ops.set(c, "partitions", [])
        ret = @sint.getDmraidInfo( d, pinfos)
        pinfos.each do |info|
          pinfo = info.p
          p = {}
          p = dmPartMap(pinfo, p)
          Ops.set(p, "fstype", Partitions.dmraid_name)
          if Ops.get_integer(p, "nr", -1) != 0
            Ops.set(
              c,
              "partitions",
              Builtins.add(Ops.get_list(c, "partitions", []), p)
            )
          end
        end
      elsif Ops.get_symbol(c, "type", :CT_UNKNOWN) == :CT_DMMULTIPATH
        pinfos = ::Storage::DequeDmmultipathInfo.new()
        infos = ::Storage::DmmultipathCoInfo.new()
        d = Ops.get_string(c, "device", "")
        ret = @sint.getDmmultipathCoInfo(d, infos)
        if ret == 0
          pinfo = infos.p
          c = dmPartCoMap(pinfo, c)
        else
          Builtins.y2warning(
            "disk \"%1\" ret: %2",
            Ops.get_string(c, "device", ""),
            ret
          )
        end
        Ops.set(c, "partitions", [])
        ret = @sint.getDmmultipathInfo( d, pinfos )
        pinfos.each do |info|
          pinfo = info.p
          p = {}
          p = dmPartMap(pinfo, p)
          Ops.set(p, "fstype", Partitions.dmmultipath_name)
          if Ops.get_integer(p, "nr", -1) != 0
            Ops.set(
              c,
              "partitions",
              Builtins.add(Ops.get_list(c, "partitions", []), p)
            )
          end
        end
      elsif Ops.get_symbol(c, "type", :CT_UNKNOWN) == :CT_MDPART
        pinfos = ::Storage::DequeMdPartInfo.new()
        infos = ::Storage::MdPartCoInfo.new()
        d = Ops.get_string(c, "device", "")
        ret = @sint.getMdPartCoInfo( d, infos)
        if ret == 0
          dinfo = infos.d
          c = diskMap(dinfo, c)
        else
          Builtins.y2warning(
            "disk \"%1\" ret: %2",
            Ops.get_string(c, "device", ""),
            ret
          )
        end

        c["devices"] = infos.devices.to_a
        c["spares" ] = infos.spares.to_a if !infos.spares.empty?

        t2 = infos.type
        Ops.set(
          c,
          "raid_type",
          Builtins.substring(
            Builtins.sformat("%1", toSymbol(@conv_mdtype, t2)),
            1
          )
        )
        if HasRaidParity(Ops.get_string(c, "raid_type", ""))
          t2 = infos.parity
          pt = toSymbol(@conv_mdparity, t2)
          if pt != :par_default
            Ops.set(c, "parity_algorithm", Ops.get(@rev_conv_parstring, t2, ""))
          end
        end
        t2 = infos.chunkSizeK
        Ops.set(c, "chunk_size", t2) if t2>0
        Ops.set(c, "sb_ver", infos.sb_ver)

        Ops.set(c, "partitions", [])
        ret = @sint.getMdPartInfo(d, pinfos)
        pinfos.each do |info|
          p = {}
          p = mdPartMap(info, p)
          Ops.set(p, "fstype", Partitions.raid_name)
          if Ops.get_integer(p, "nr", -1) != 0
            Ops.set(
              c,
              "partitions",
              Builtins.add(Ops.get_list(c, "partitions", []), p)
            )
          end
        end
      elsif Ops.get_symbol(c, "type", :CT_UNKNOWN) == :CT_LVM
        pinfos = ::Storage::DequeLvmLvInfo.new()
        infos = ::Storage::LvmVgInfo.new()
        n = Ops.get_string(c, "name", "")
        ret = @sint.getLvmVgInfo(n, infos)
        if ret == 0
          Ops.set(c, "create", infos.create)
          Ops.set(c, "size_k", infos.sizeK)
          Ops.set(c, "cyl_size", 1024*infos.peSizeK)
          Ops.set(c, "pesize", 1024*infos.peSizeK)
          Ops.set(c, "cyl_count", infos.peCount)
          Ops.set(c, "pe_free", infos.peFree)
          Ops.set(c, "lvm2", infos.lvm2)

          c["devices"] = infos.devices.to_a
          c["devices_add"] = infos.devices_add.to_a if !infos.devices_add.empty?
          c["devices_rem"] = infos.devices_rem.to_a if !infos.devices_rem.empty?
        else
          Builtins.y2warning(
            "LVM Vg \"%1\" ret: %2",
            Ops.get_string(c, "name", ""),
            ret
          )
        end
        ret = @sint.getLvmLvInfo(n, pinfos)
        pinfos.each do |info|
          p = {}
          vinfo = info.v
          p = volumeMap(vinfo, p)
          Ops.set(p, "stripes", info.stripes)
          t = info.stripeSizeK
          Ops.set(p, "stripesize", t) if t>0
          s = info.origin
          Ops.set(p, "origin", s) if !Builtins.isempty(s)
          s = info.used_pool
          Ops.set(p, "used_pool", s) if !Builtins.isempty(s)
          Ops.set(p, "pool", true) if info.pool
          Ops.set(p, "type", :lvm)
          Ops.set(p, "fstype", Partitions.lv_name)
          Ops.set(
            c,
            "partitions",
            Builtins.add(Ops.get_list(c, "partitions", []), p)
          )
        end
      elsif Ops.get_symbol(c, "type", :CT_UNKNOWN) == :CT_MD
        pinfos = ::Storage::DequeMdInfo.new()
        ret = @sint.getMdInfo(pinfos)
        Builtins.y2warning("getMdInfo ret: %1", ret) if ret<0
        pinfos.each do |info|
          p = {}
          vinfo = info.v
          p = volumeMap(vinfo, p)
          Ops.set(p, "nr", info.nr)
          t2 = info.type
          Ops.set(
            p,
            "raid_type",
            Builtins.substring(
              Builtins.sformat("%1", toSymbol(@conv_mdtype, t2)),
              1
            )
          )
          if HasRaidParity(Ops.get_string(p, "raid_type", ""))
            pt = toSymbol(@conv_mdparity, info.parity)
            if pt != :par_default
              Ops.set(
                p,
                "parity_algorithm",
                Ops.get(@rev_conv_parstring, info.parity, "")
              )
            end
          end
          Ops.set(p, "type", :sw_raid)
          Ops.set(p, "fstype", Partitions.raid_name)
          t2 = info.chunkSizeK
          Ops.set(p, "chunk_size", t2) if t2>0
          Ops.set(p, "sb_ver", info.sb_ver)
          Ops.set(p, "raid_inactive", true) if info.inactive

          p["devices"] = info.devices.to_a
          p["spares"] = info.spares.to_a if !info.spares.empty?

          Ops.set(
            c,
            "partitions",
            Builtins.add(Ops.get_list(c, "partitions", []), p)
          )
        end
      elsif Ops.get_symbol(c, "type", :CT_UNKNOWN) == :CT_LOOP
        pinfos = ::Storage::DequeLoopInfo.new()
        ret = @sint.getLoopInfo(pinfos)
        Builtins.y2warning("getLoopInfo ret: %1", ret) if ret<0
        pinfos.each do |info|
          p = {}
          vinfo = info.v
          p = volumeMap(vinfo, p)
          Ops.set(p, "nr", info.nr)
          Ops.set(p, "type", :loop)
          Ops.set(p, "fstype", Partitions.loop_name)
          Ops.set(p, "fpath", info.file)
          Ops.set(p, "create_file", !info.reuseFile)
          if Ops.get_symbol(p, "enc_type", :unknown) != :luks &&
              !Builtins.isempty(Ops.get_string(p, "loop", ""))
            Ops.set(p, "device", Ops.get_string(p, "loop", ""))
          end
          Ops.set(
            c,
            "partitions",
            Builtins.add(Ops.get_list(c, "partitions", []), p)
          )
        end
      elsif Ops.get_symbol(c, "type", :CT_UNKNOWN) == :CT_DM
        pinfos = ::Storage::DequeDmInfo.new()
        ret = @sint.getDmInfo(pinfos)
        Builtins.y2warning("getDmInfo ret: %1", ret) if ret<0
        pinfos.each do |info|
          p = {}
          vinfo = info.v
          p = volumeMap(vinfo, p)
          Ops.set(p, "nr", info.nr)
          Ops.set(p, "type", :dm)
          Ops.set(p, "fstype", Partitions.dm_name)
          Ops.set(
            c,
            "partitions",
            Builtins.add(Ops.get_list(c, "partitions", []), p)
          )
        end
      elsif Ops.get_symbol(c, "type", :CT_UNKNOWN) == :CT_NFS
        pinfos = ::Storage::DequeNfsInfo.new()
        Builtins.y2milestone("before getNfsInfo")
        ret = @sint.getNfsInfo(pinfos)
        Builtins.y2milestone("after getNfsInfo")
        Builtins.y2warning("getNfsInfo ret: %1", ret) if ret<0
        pinfos.each do |info|
          p = {}
          vinfo = info.v
          p = volumeMap(vinfo, p)
          Ops.set(p, "type", :nfs)
          Ops.set(p, "fstype", Partitions.nfs_name)
          Ops.set(
            c,
            "partitions",
            Builtins.add(Ops.get_list(c, "partitions", []), p)
          )
        end
      elsif Ops.get_symbol(c, "type", :CT_UNKNOWN) == :CT_BTRFS
        pinfos = ::Storage::DequeBtrfsInfo.new()
        Builtins.y2milestone("before getBtrfsInfo")
        ret = @sint.getBtrfsInfo(pinfos)
        Builtins.y2milestone("after getBtrfsInfo")
        Builtins.y2warning("getBtrfsInfo ret: %1", ret) if ret<0
        pinfos.each do |info|
          p = {}
          vinfo = info.v
          p = volumeMap(vinfo, p)
          Ops.set(p, "type", :btrfs)
          Ops.set(p, "fstype", Partitions.btrfs_name)

          p["devices"] = info.devices.to_a
          p["devices_add"] = info.devices_add.to_a if !info.devices_add.empty?
          p["devices_rem"] = info.devices_rem.to_a if !info.devices_rem.empty?

          if !info.subvolumes.empty?
            p["subvol"] = info.subvolumes.map do |subvolume|
              tmp = { "name" => subvolume.path }
              tmp["nocow"] = subvolume.nocow if subvolume.nocow
              tmp["create"] = subvolume.created if subvolume.created
              tmp["delete"] = subvolume.deleted if subvolume.deleted
              tmp
            end
          end

	  vols = 0;
	  vols += p["devices"].size if( p.has_key?("devices") )
	  vols += p["devices_add"].size if( p.has_key?("devices_add") )
          if vols>1
             !Builtins.isempty(Ops.get_list(p, "devices_add", []))
            Ops.set(
              p,
              "device",
              Ops.add("UUID=", Ops.get_string(p, "uuid", ""))
            )
          end
          Ops.set(
            c,
            "partitions",
            Builtins.add(Ops.get_list(c, "partitions", []), p)
          )
        end
      elsif Ops.get_symbol(c, "type", :CT_UNKNOWN) == :CT_TMPFS
        pinfos = ::Storage::DequeTmpfsInfo.new()
        Builtins.y2milestone("before getTmpfsInfo")
        ret = @sint.getTmpfsInfo(pinfos)
        Builtins.y2milestone("after getTmpfsInfo")
        Builtins.y2warning("getTmpfsInfo ret: %1", ret) if ret<0
        pinfos.each do |info|
          p = {}
          vinfo = info.v
          p = volumeMap(vinfo, p)
          Ops.set(p, "type", :tmpfs)
          Ops.set(p, "fstype", Partitions.tmpfs_name)
          Ops.set(p, "device", "tmpfs")
          Ops.set(
            c,
            "partitions",
            Builtins.add(Ops.get_list(c, "partitions", []), p)
          )
        end
      end
      #y2milestone ("getContainerInfo container %1", remove( c, "partitions" ) );
      Builtins.y2milestone("getContainerInfo container\n%1", format_target_map(c))
      deep_copy(c)
    end


    def toDiskMap(disk, cinfo)
      disk = deep_copy(disk)
      cinfo = deep_copy(cinfo)
      l = [
        "size_k",
        "cyl_size",
        "cyl_count",
        "sector_size",
        "label",
        "orig_label",
        "name",
        "device",
        "max_logical",
        "max_primary",
        "type",
        "readonly",
        "transport",
        "iscsi",
        "used_by",
        "used_by_type",
        "used_by_device",
        "partitions",
        "dasdfmt",
        "udev_id",
        "udev_path",
        "has_fake_partition",
        "dasd_format",
        "dasd_type",
        "userdata"
      ]
      Builtins.foreach(l) do |s|
        if Builtins.haskey(cinfo, s)
          Ops.set(disk, s, Ops.get(cinfo, s, 0))
        elsif Builtins.haskey(disk, s)
          disk = Builtins.remove(disk, s)
        end
      end
      deep_copy(disk)
    end


    def getContainers
      ret = []
      cinfos = ::Storage::DequeContainerInfo.new()
      @sint.getContainers(cinfos)
      cinfos.each do |info|
        c = deviceMap(info)
        c["type"] = toSymbol(@conv_ctype, info.type)
	Builtins.y2milestone("c: %1",c)
        c["readonly"] = true if info.readonly
        ret = Builtins.add(ret, c)
      end
      Builtins.y2milestone("getContainers ret: %1", ret)
      deep_copy(ret)
    end


    def IsDiskType(t)
      Builtins.contains([:CT_DISK, :CT_DMRAID, :CT_DMMULTIPATH, :CT_MDPART], t)
    end


    def HandleBtrfsSimpleVolumes(tg)
      tg = deep_copy(tg)
      if Builtins.haskey(tg, "/dev/btrfs")
        btrfs_partitions = Ops.get_list(tg, ["/dev/btrfs", "partitions"], [])
        simple = Builtins.filter(btrfs_partitions) do |p|
          p["devices"].nil? || p["devices"].size <= 1
        end
        tg["/dev/btrfs"]["partitions"] = Builtins.filter(btrfs_partitions) do |p|
          p["devices"] &&  p["devices"].size > 1
        end
        Builtins.y2milestone("HandleBtrfsSimpleVolumes simple\n%1", format_target_map(simple))
        keys = [
          "subvol",
          "uuid",
          "label",
          "format",
          "inactive",
          "mount",
          "mountby",
          "used_fs",
          "fstopt",
          "userdata"
        ]
        Builtins.foreach(simple) do |p|
          mp = GetPartition(tg, p["device"])
          Builtins.y2milestone("HandleBtrfsSimpleVolumes before %1", mp)
          Builtins.foreach(keys) do |k|
            if Ops.get(p, k) != nil
              Builtins.y2milestone("HandleBtrfsSimpleVolumes set key %1", k)
              tg = SetPartitionData(
                tg,
                Ops.get_string(p, "device", ""),
                k,
                Ops.get(p, k)
              )
            else
              if Builtins.haskey(mp, k)
                Builtins.y2milestone(
                  "HandleBtrfsSimpleVolumes remove key %1",
                  k
                )
                tg = DelPartitionData(tg, Ops.get_string(p, "device", ""), k)
              end
            end
          end
          Builtins.y2milestone(
            "HandleBtrfsSimpleVolumes after  %1",
            GetPartition(tg, Ops.get_string(p, "device", ""))
          )
        end
      end
      deep_copy(tg)
    end


    # Updates target map
    #
    # @see #GetTargetMap()
    def UpdateTargetMap
      @conts = getContainers
      rem_keys = []
      tg = Ops.get_map(@StorageMap, @targets_key, {})
      #SCR::Write(.target.ycp, "/tmp/upd_all_bef_"+sformat("%1",count), StorageMap[targets_key]:$[] );
      Builtins.foreach(tg) do |dev, disk|
        c = {}
        c = Builtins.find(@conts) do |c2|
          Ops.get_string(c2, "device", "") == dev
        end
        if c == nil
          rem_keys = Builtins.add(rem_keys, dev)
        elsif IsDiskType(Ops.get_symbol(c, "type", :CT_UNKNOWN))
          Ops.set(tg, dev, toDiskMap(Ops.get(tg, dev, {}), getContainerInfo(c)))
        else
          Ops.set(tg, dev, getContainerInfo(c))
        end
        Builtins.y2milestone(
          "UpdateTargetMap dev: %1 is:\n%2",
          dev,
          format_target_map(Ops.get(tg, dev, {}))
        )
      end
      tg = HandleBtrfsSimpleVolumes(tg)
      if Builtins.haskey(tg, "/dev/btrfs")
        simple = Builtins.filter(
          Ops.get_list(tg, ["/dev/btrfs", "partitions"], [])
        ) do |p|
          Ops.less_or_equal(Builtins.size(Ops.get_list(p, "devices", [])), 1)
        end
        Ops.set(
          tg,
          ["/dev/btrfs", "partitions"],
          Builtins.filter(Ops.get_list(tg, ["/dev/btrfs", "partitions"], [])) do |p|
            Ops.greater_than(Builtins.size(Ops.get_list(p, "devices", [])), 1)
          end
        )
        Builtins.y2milestone("simple %1", simple)
        Builtins.foreach(simple) do |p|
          tg = SetPartitionData(
            tg,
            Ops.get_string(p, "device", ""),
            "subvol",
            Ops.get_list(p, "subvol", [])
          )
          tg = SetPartitionData(
            tg,
            Ops.get_string(p, "device", ""),
            "userdata",
            Ops.get_map(p, "userdata", {})
          )
        end
      end
      Builtins.y2milestone("UpdateTargetMap rem_keys: %1", rem_keys)
      Builtins.foreach(rem_keys) { |dev| tg = Builtins.remove(tg, dev) }
      Builtins.foreach(@conts) do |c|
        if Ops.get_symbol(c, "type", :CT_UNKNOWN) != :CT_DISK &&
            !Builtins.haskey(tg, Ops.get_string(c, "device", ""))
          Ops.set(tg, Ops.get_string(c, "device", ""), getContainerInfo(c))
          Builtins.y2milestone(
            "UpdateTargetMap dev: %1 is: %2",
            Ops.get_string(c, "device", ""),
            Ops.get(tg, Ops.get_string(c, "device", ""), {})
          )
        end
      end
      Ops.set(@StorageMap, @targets_key, tg)
      #SCR::Write(.target.ycp, "/tmp/upd_all_aft_"+sformat("%1",count), StorageMap[targets_key]:$[] );
      #count = count+1;

      nil
    end


    def UpdateTargetMapDisk(dev)
      Builtins.y2milestone("UpdateTargetMapDisk")
      @conts = getContainers
      c = {}
      c = Builtins.find(@conts) { |c2| Ops.get_string(c2, "device", "") == dev }
      tg = Ops.get_map(@StorageMap, @targets_key, {})
      #SCR::Write(.target.ycp, "/tmp/upd_disk_bef_"+sformat("%1",count), StorageMap[targets_key]:$[] );
      if c == nil
        tg = Builtins.remove(tg, dev) if Builtins.haskey(tg, dev)
      elsif IsDiskType(Ops.get_symbol(c, "type", :CT_UNKNOWN))
        Ops.set(tg, dev, toDiskMap(Ops.get(tg, dev, {}), getContainerInfo(c)))
      else
        Ops.set(tg, dev, getContainerInfo(c))
      end
      numbt = Builtins.size(
        Builtins.filter(Ops.get_list(tg, [dev, "partitions"], [])) do |p|
          Ops.get_symbol(p, "used_fs", :unknown) == :btrfs
        end
      )
      Builtins.y2milestone("UpdateTargetMapDisk btrfs: %1", numbt)
      if Ops.greater_than(numbt, 0) && dev != "/dev/btrfs"
        bt = Ops.get(tg, "/dev/btrfs", {})
        Ops.set(bt, "type", :CT_BTRFS) if Builtins.size(bt) == 0
        Ops.set(tg, "/dev/btrfs", getContainerInfo(bt))
      end
      if Ops.greater_than(numbt, 0) || dev == "/dev/btrfs"
        tg = HandleBtrfsSimpleVolumes(tg)
      end
      Ops.set(@StorageMap, @targets_key, tg)
      #SCR::Write(.target.ycp, "/tmp/upd_disk_aft_"+sformat("%1",count), StorageMap[targets_key]:$[] );
      #count = count+1;

      nil
    end


    def UpdateTargetMapDev(dev)
      Builtins.y2milestone("UpdateTargetMapDev %1", dev)
      tg = Ops.get_map(@StorageMap, @targets_key, {})
      #SCR::Write(.target.ycp, "/tmp/upd_dev_bef_"+sformat("%1",count), tg );
      cdev = ""
      mdev = GetPartition(tg, dev)
      Builtins.y2milestone("UpdateTargetMapDev mdev %1", mdev)
      btrfs = Ops.get_symbol(mdev, "used_fs", :unknown) == :btrfs
      Builtins.y2milestone("UpdateTargetMapDev btrfs %1", btrfs)
      Builtins.foreach(tg) do |key, d|
        if Builtins.size(cdev) == 0 &&
            Builtins.find(Ops.get_list(d, "partitions", [])) do |p|
              Ops.get_string(p, "device", "") == dev
            end != nil
          cdev = Ops.get_string(d, "device", "")
        end
      end
      Builtins.y2milestone("UpdateTargetMapDev cdev %1", cdev)
      c = {}
      c = Builtins.find(@conts) { |c2| Ops.get_string(c2, "device", "") == cdev }
      disk = {}
      disk = getContainerInfo(c) if c != nil
      if c != nil && Builtins.haskey(tg, cdev)
        partitions = Ops.get_list(tg, [cdev, "partitions"], [])
        found = false
        partitions = Builtins.maplist(partitions) do |p|
          if Ops.get_string(p, "device", "") == dev
            pp = Builtins.find(Ops.get_list(disk, "partitions", [])) do |q|
              Ops.get_string(q, "device", "") == dev
            end
            if pp != nil
              found = true
              p = deep_copy(pp)
              mdev = deep_copy(pp)
            end
          end
          deep_copy(p)
        end
        Ops.set(
          tg,
          [Ops.get_string(disk, "device", ""), "partitions"],
          partitions
        )
        Builtins.y2error("UpdateTargetMapDev not found %1", dev) if !found
      else
        Builtins.y2error(
          "UpdateTargetMapDev key %1 not found in target",
          Ops.get_string(disk, "device", "")
        )
      end
      Builtins.y2milestone("UpdateTargetMapDev mdev\n%1", format_target_map(mdev))
      btrfs = btrfs || Ops.get_symbol(mdev, "used_fs", :unknown) == :btrfs
      Builtins.y2milestone("UpdateTargetMapDev btrfs %1", btrfs)
      if btrfs
        bt = Ops.get(tg, "/dev/btrfs", {})
        Ops.set(bt, "type", :CT_BTRFS) if Builtins.size(bt) == 0
        Ops.set(tg, "/dev/btrfs", getContainerInfo(bt))
        tg = HandleBtrfsSimpleVolumes(tg)
      end
      Ops.set(@StorageMap, @targets_key, tg)
      #SCR::Write(.target.ycp, "/tmp/upd_dev_aft_"+sformat("%1",count), StorageMap[targets_key]:$[] );
      #count = count+1;

      nil
    end


    # Returns map with disk info
    #
    # @param [String] device
    # @param [Hash] disk
    # @return [Hash] disk info
    def getDiskInfo(device, disk)
      disk = deep_copy(disk)
      c = {}
      c = Builtins.find(@conts) { |p| Ops.get_string(p, "device", "") == device }
      if c == nil
        tmp = GetDiskPartition(device)
        Builtins.y2milestone("getDiskInfo map %1", tmp)
        c = Builtins.find(@conts) do |p|
          Ops.get_string(p, "device", "") == Ops.get_string(tmp, "disk", "")
        end if Ops.get_string(
          tmp,
          "disk",
          ""
        ) != device
      end
      Builtins.y2milestone("getDiskInfo c: %1", c)
      if c != nil
        disk = toDiskMap(disk, getContainerInfo(c))
        Builtins.y2milestone(
          "getDiskInfo ret: %1",
          Builtins.haskey(disk, "partitions") ?
            Builtins.remove(disk, "partitions") :
            disk
        )
      end
      deep_copy(disk)
    end


    def SaveExitKey(key)
      if key == :next || key == :back
        @exit_key = key
        Builtins.y2milestone("Exit Key %1", @exit_key)
      end

      nil
    end


    def GetExitKey
      @exit_key
    end


    # Returns map describing the disk target
    #
    # @return [Hash{String => map}]
    def GetOndiskTarget
      keys = ["mount", "enc_type", "mountby", "fstopt", "used_fs", "format"]
      ret = GetTargetMap()
      Builtins.foreach(ret) do |d, disk|
        pl = Builtins.maplist(Ops.get_list(disk, "partitions", [])) do |p|
          Builtins.filter(p) { |k, e| !Builtins.contains(keys, k) }
        end
        pl = Builtins.maplist(pl) do |p|
          if Ops.get_symbol(p, "detected_fs", :unknown) != :unknown
            Ops.set(p, "used_fs", Ops.get_symbol(p, "detected_fs", :unknown))
          end
          deep_copy(p)
        end
        Ops.set(ret, [d, "partitions"], pl)
      end
      deep_copy(ret)
    end


    def CreateTargetBackup(who)
      t = Ops.add(
        Ops.add(Ops.add("targetMap_s_", who), "_"),
        Builtins.sformat("%1", @count)
      )
      @count = Ops.add(@count, 1)
      SCR.Write(path(".target.ycp"), SaveDumpPath(t), GetTargetMap())
      Builtins.y2milestone("CreateTargetBackup who: %1", who)
      ret = @sint.createBackupState(who)
      if ret<0
        Builtins.y2error("CreateTargetBackup sint ret: %1", ret)
      end

      nil
    end


    def DisposeTargetBackup(who)
      Builtins.y2milestone("DisposeTargetBackup who: %1", who)
      ret = @sint.removeBackupState(who)
      if ret<0
        Builtins.y2error("DisposeTargetBackup sint ret: %1", ret)
      end

      nil
    end


    def EqualBackupStates(s1, s2, vb)
      Builtins.y2milestone(
        "EqualBackupStates s1:\"%1\" s2:\"%2\" verbose: %3",
        s1, s2, vb)
      ret = @sint.equalBackupStates(s1, s2, vb)
      Builtins.y2milestone("EqualBackupStates ret: %1", ret)
      ret
    end


    def RestoreTargetBackup(who)
      Builtins.y2milestone("RestoreTargetBackup who: %1", who)
      ret = @sint.restoreBackupState(who)
      if ret<0
        Builtins.y2error("RestoreTargetBackup sint ret: %1", ret)
      end
      UpdateTargetMap()
      t = Ops.add("targetMap_r_", who)
      SCR.Write(path(".target.ycp"), SaveDumpPath(t), GetTargetMap())

      # Cleanup memory about deleted shadowed subvolumes
      ShadowedVolHelper.instance.reset

      nil
    end


    def ResetOndiskTarget
      RestoreTargetBackup("initial")

      nil
    end


    def GetTargetChangeTime
      Ops.get_integer(@StorageMap, "targets_time", 0)
    end


    def GetPartProposalActive
      Ops.get_boolean(@StorageMap, @part_proposal_active_key, true)
    end


    def SetPartProposalActive(value)
      Ops.set(@StorageMap, @part_proposal_active_key, value)

      nil
    end


    def GetPartMode
      Builtins.y2milestone(
        "GetPartMode %1",
        Ops.get_string(@StorageMap, @part_mode_key, "")
      )
      Ops.get_string(@StorageMap, @part_mode_key, "")
    end


    def SetPartMode(value)
      Builtins.y2milestone("SetPartMode %1", value)
      Ops.set(@StorageMap, @part_mode_key, value)

      nil
    end


    def GetCustomDisplay
      Ops.get_boolean(@StorageMap, @custom_display_key, false)
    end


    def SetCustomDisplay(value)
      Ops.set(@StorageMap, @custom_display_key, value)

      nil
    end


    def GetPartDisk
      Ops.get_string(@StorageMap, @part_disk_key, "")
    end


    def SetPartDisk(value)
      Ops.set(@StorageMap, @part_disk_key, value)

      nil
    end


    def GetTestsuite
      Ops.get_boolean(@StorageMap, @testsuite_key, false)
    end


    def SetTestsuite(value)
      @StorageMap = Builtins.add(@StorageMap, @testsuite_key, value)

      nil
    end


    def GetDoResize
      Ops.get_string(@StorageMap, @do_resize_key, "NO")
    end


    def SetDoResize(value)
      @StorageMap = Builtins.add(@StorageMap, @do_resize_key, value)

      nil
    end


    def GetPartProposalMode
      Ops.get_string(@StorageMap, @part_proposal_mode_key, "accept")
    end


    def SetPartProposalMode(value)
      @StorageMap = Builtins.add(@StorageMap, @part_proposal_mode_key, value)

      nil
    end


    def GetPartProposalFirst
      Ops.get_boolean(@StorageMap, @part_proposal_first_key, true)
    end


    def SetPartProposalFirst(value)
      @StorageMap = Builtins.add(@StorageMap, @part_proposal_first_key, value)

      nil
    end


    def GetWinDevice
      Ops.get_boolean(@StorageMap, @win_device_key, false)
    end


    def SetWinDevice(value)
      @StorageMap = Builtins.add(@StorageMap, @win_device_key, value)

      nil
    end


    # Storage Constructor
    def Storage
      if Mode.normal
        SetPartMode("CUSTOM")
        SetPartProposalActive(false)
      end
      if Stage.initial
        SetPartMode("CUSTOM")
        SetPartProposalActive(false)
      end

      nil
    end


    def IsInstallationSource(device)
      if @part_insts == nil
        @part_insts = ""

        if Stage.initial
          tmp = Convert.to_string(SCR.Read(path(".etc.install_inf.Partition")))
          if tmp != nil && !Builtins.isempty(tmp)
            Builtins.y2milestone(
              "IsInstallationSource .etc.install_inf.Partition:\"%1\"",
              tmp
            )

            info = {}
            if (
                info_ref = arg_ref(info);
                _GetContVolInfo_result = GetContVolInfo(
                  Ops.add("/dev/", tmp),
                  info_ref
                );
                info = info_ref.value;
                _GetContVolInfo_result
              )
              @part_insts = Ops.get_string(info, "vdevice", "")
            end
          end
        end

        Builtins.y2milestone(
          "IsInstallationSource part_insts:\"%1\"",
          @part_insts
        )
      end

      !Builtins.isempty(@part_insts) && device == @part_insts
    end


    def NextPartition(disk, ptype)
      Builtins.y2milestone("NextPartition disk: %1 ptype: %2", disk, ptype)
      pt = fromSymbol(@conv_ptype, ptype)
      Builtins.y2milestone("NextPartition type: %1 pt: %2", ptype, pt)
      r, num, dev = @sint.nextFreePartition(disk, pt)
      Builtins.y2error("NextPartition ret %1", r) if r<0
      num = 0 if r<0
      dev = "" if r<0
      ret = { "device" => dev, "nr" => num }
      Builtins.y2milestone("NextPartition sint ret: %1 map: %2", r, ret)
      deep_copy(ret)
    end


    def NextMd
      Builtins.y2milestone("NextMd")
      r, num, dev = @sint.nextFreeMd()
      Builtins.y2error("NextMd ret %1", r) if r<0
      num = 0 if r<0
      dev = "" if r<0
      ret = { "device" => dev, "nr" => num }
      Builtins.y2milestone("NextMd sint ret: %1 map: %2", r, ret)
      deep_copy(ret)
    end


    def MaxCylLabel(disk, start_cyl)
      disk = deep_copy(disk)
      ret = Ops.divide(
        Ops.multiply(
          Partitions.MaxSectors(Ops.get_string(disk, "label", "")),
          Ops.get_integer(disk, "sector_size", 512)
        ),
        1024
      )
      Builtins.y2milestone(
        "MaxCylLabel val_k: %1 cyl_size: %2",
        ret,
        Ops.get_integer(disk, "cyl_size", 1)
      )
      cylk2 = Ops.divide(Ops.get_integer(disk, "cyl_size", 1), 512)
      cylk2 = 2 if Ops.less_than(cylk2, 2)
      Builtins.y2milestone("MaxCylLabel val_k: %1 cylk2: %2", ret, cylk2)
      ret = Ops.subtract(Ops.divide(Ops.multiply(ret, 2), cylk2), 1)
      ret = Ops.add(ret, start_cyl)
      Builtins.y2milestone("MaxCylLabel ret: %1", ret)
      ret
    end


    # Creates a new partition
    #
    # @param [String] disk
    # @param [String] device
    # @param [Symbol] ptype (types?)
    # @param [Fixnum] id
    # @param [Fixnum] start
    # @param [Fixnum] len (bytes|cyls?)
    # @param [Symbol] mby (one of?)
    # @return [Boolean] if successful
    def CreatePartition(disk, device, ptype, id, start, len, mby)
      log.info("CreatePartition disk:#{disk} device:#{device} ptype:#{ptype} id:#{id} " +
               "start:#{start} len:#{len} mby:#{mby}")
      pt = fromSymbol(@conv_ptype, ptype)
      log.info("CreatePartition ptype:#{ptype} pt:#{pt}")
      region = ::Storage::RegionInfo.new(start, len)
      ret, cdev = @sint.createPartition(disk, pt, region)
      cdev = "" if ret<0
      if device != cdev
        log.error("CreatePartition device:#{device} cdev:#{cdev}")
      end
      log.error("CreatePartition ret #{ret}") if ret<0
      ret = @sint.changePartitionId(device, id)
      log.error("CreatePartition ret #{ret}") if ret<0
      tmp = fromSymbol(@conv_mountby, mby)
      @sint.changeMountBy(device, tmp)
      log.info("CreatePartition sint ret:#{ret}")
      UpdateTargetMap()
      ret == 0
    end


    def UpdatePartition(device, start, len)
      log.info("UpdatePartition device:#{device} start:#{start} len:#{len}")
      region = ::Storage::RegionInfo.new(start, len)
      ret = @sint.updatePartitionArea(device, region)
      if ret<0
        log.error("UpdatePartition sint ret:#{ret}")
      end
      UpdateTargetMapDev(device)
      ret == 0
    end


    # Sets a mountpoint for partition
    #
    # @param [String] device name
    # @param string mount point
    # @return [Boolean] if successful
    def SetPartitionMount(device, mp)
      Builtins.y2milestone("SetPartitionMount device: %1 mp: %2", device, mp)
      ret = @sint.changeMountPoint(device, mp)
      if ret<0
        Builtins.y2error("SetPartitionMount sint ret: %1", ret)
      end
      UpdateTargetMapDev(device)
      ret == 0
    end


    # Sets whether a partition should be formatted
    #
    # @param [String] device name
    # @param [Boolean] format (yes,no)
    # @param symbol filesystem
    # @return [Boolean] if successful
    def SetPartitionFormat(device, format, fs)
      Builtins.y2milestone(
        "SetPartitionFormat device: %1 format: %2 fs: %3",
        device,
        format,
        fs
      )
      tmp = fromSymbol(FileSystems.conv_fs, fs)
      Builtins.y2milestone("SetPartitionFormat fs: %1", tmp)
      ret = @sint.changeFormatVolume(device, format, tmp)
      if ret<0
        Builtins.y2error("SetPartitionFormat sint ret: %1", ret)
      end
      UpdateTargetMapDev(device)
      ret == 0
    end


    # Sets partition ID
    #
    # @param [String] device name
    # @param integer ID
    # @return [Boolean] if successful
    #
    # @see #UnchangePartitionId()
    def SetPartitionId(device, id)
      Builtins.y2milestone("SetPartitionId device: %1 id: %2", device, id)
      ret = @sint.changePartitionId(device, id)
      if ret<0
        Builtins.y2error("SetPartitionId sint ret: %1", ret)
      end
      UpdateTargetMapDev(device)
      ret == 0
    end


    # Restores the original partition ID
    #
    # @param [String] device name
    # @return [Boolean] if succesful
    #
    # @see #SetPartitionId()
    def UnchangePartitionId(device)
      Builtins.y2milestone("UnchangePartitionId device: %1", device)
      ret = @sint.forgetChangePartitionId(device)
      if ret<0
        Builtins.y2error("UnchangePartitionId sint ret: %1", ret)
      end
      UpdateTargetMapDev(device)
      ret == 0
    end


    # Sets a new size for volume
    #
    # @param [String] device name
    # @param [String] disk
    # @param [Fixnum] new_cyls (in cylinders)
    # @return [Boolean] if successful
    def ResizePartition(device, disk, new_cyls)
      Builtins.y2milestone(
        "ResizePartition device: %1 disk: %2 new_cyls: %3",
        device,
        disk,
        new_cyls
      )
      ret = @sint.resizePartition(device, new_cyls)
      if ret<0
        Builtins.y2error("ResizePartition sint ret: %1", ret)
      end
      UpdateTargetMapDisk(disk)
      ret == 0
    end


    # Sets a new size for volume
    #
    # @param [String] device name
    # @param [String] disk
    # @param integer new_size (in kBytes)
    # @return [Boolean] if successful
    def ResizeVolume(device, disk, new_size_k)
      Builtins.y2milestone(
        "ResizeVolume device: %1 disk: %2 new_size_k: %3",
        device,
        disk,
        new_size_k
      )
      ret = @sint.resizeVolume(device, new_size_k)
      Builtins.y2error("ResizeVolume sint ret: %1", ret) if ret<0
      UpdateTargetMapDisk(disk)
      ret == 0
    end


    def SetCrypt(device, crpt, format)
      Builtins.y2milestone(
        "SetCrypt device: %1 val: %2 format: %3",
        device,
        crpt,
        format
      )
      ret, is_crypt = @sint.getCrypt(device)
      is_crypt = false if ret<0
      if ret == 0 && !format && is_crypt == crpt
        Builtins.y2milestone("SetCrypt crypt already set")
      else
        ret = @sint.setCrypt(device, crpt)
        if ret<0
          Builtins.y2error("SetCrypt sint ret: %1", ret)
          if !format && crpt
            Popup.Error(
              Builtins.sformat(
                _(
                  "Could not set encryption.\n" +
                    "System error code is %1.\n" +
                    "\n" +
                    "The encryption password provided could be incorrect.\n"
                ),
                ret
              )
            )
          end
          @sint.forgetCryptPassword(device)
        else
          Builtins.y2milestone("SetCrypt sint ret: %1", ret)
        end
      end
      ret == 0
    end


    def ChangeDescText(device, text)
      @sint.changeDescText(device, text)
    end


    def SetUserdata(device, userdata)
      tmp = ::Storage::MapStringString.new()
      userdata.each do |a, b|
        tmp[a]= b
      end
      ret = @sint.setUserdata(device, tmp)
      UpdateTargetMap()
      return ret
    end


    def ChangeVolumeProperties(part)
      part = deep_copy(part)
      ret = 0
      tmp = 0
      changed = false
      ts = ""
      dev = Ops.get_string(part, "device", "")
      vinfo = ::Storage::VolumeInfo.new()
      ret = @sint.getVolume(dev, vinfo)
      if ret != 0
        Builtins.y2error("ChangeVolumeProperties device: %1 not found", dev)
      end
      curr = {}
      curr = volumeMap(vinfo, curr) if ret == 0

      if ret == 0 && Ops.get_symbol(part, "type", :unknown) != :extended &&
          (Ops.get_boolean(part, "format", false) !=
            Ops.get_boolean(curr, "format", false) ||
            Ops.get_symbol(part, "used_fs", :none) !=
              Ops.get_symbol(curr, "used_fs", :none))
        changed = true
        tmp = fromSymbol(
          FileSystems.conv_fs,
          Ops.get_symbol(part, "used_fs", :none)
        )
        Builtins.y2milestone(
          "ChangeVolumeProperties fs: %1 symbol: %2",
          tmp,
          Ops.get_symbol(part, "used_fs", :none)
        )
        ret = @sint.changeFormatVolume(dev,
            Ops.get_boolean(part, "format", false),
            tmp
          );
        if ret<0
          Builtins.y2error("ChangeVolumeProperties sint ret: %1", ret)
        else
          Builtins.y2milestone("ChangeVolumeProperties sint ret: %1", ret)
        end
      end

      if ret == 0 &&
          Ops.get_string(part, "mount", "") != Ops.get_string(curr, "mount", "")
        changed = true
        ts = Ops.get_string(part, "mount", "")
        ret = @sint.changeMountPoint(dev, ts)
        if ret<0
          Builtins.y2error("ChangeVolumeProperties sint ret: %1", ret)
        else
          Builtins.y2milestone("ChangeVolumeProperties sint ret: %1", ret)
        end
      end

      if ret == 0 &&
          Ops.greater_than(Builtins.size(Ops.get_string(part, "mount", "")), 0) &&
          Ops.get_string(part, "fstopt", "") !=
            Ops.get_string(curr, "fstopt", "")
        changed = true
        ts = Ops.get_string(part, "fstopt", "")
        ret = @sint.changeFstabOptions(dev, ts)
        if ret<0
          Builtins.y2error("ChangeVolumeProperties sint ret: %1", ret)
        else
          Builtins.y2milestone("ChangeVolumeProperties sint ret: %1", ret)
        end
      end
      defmb = GetMountBy(dev)
      if ret == 0 &&
          Ops.greater_than(Builtins.size(Ops.get_string(part, "mount", "")), 0) &&
          Ops.get_symbol(part, "mountby", defmb) !=
            Ops.get_symbol(curr, "mountby", defmb)
        changed = true
        tmp = fromSymbol(
          @conv_mountby,
          Ops.get_symbol(part, "mountby", :device)
        )
        Builtins.y2milestone("ChangeVolumeProperties mby: %1", tmp)
        ret = @sint.changeMountBy(dev, tmp)
        if ret<0
          Builtins.y2error("ChangeVolumeProperties sint ret: %1", ret)
        else
          Builtins.y2milestone("ChangeVolumeProperties sint ret: %1", ret)
        end
      end
      if ret == 0 &&
          Ops.get_string(part, "label", "") != Ops.get_string(curr, "label", "")
        changed = true
        ts = Ops.get_string(part, "label", "")
        ret = @sint.changeLabelVolume(dev, ts)
        if ret<0
          Builtins.y2error("ChangeVolumeProperties sint ret: %1", ret)
        else
          Builtins.y2milestone("ChangeVolumeProperties sint ret: %1", ret)
        end
      end
      if ret == 0 && Ops.get_boolean(part, "format", false) &&
          convertFsOptionMapToString(Ops.get_map(part, "fs_options", {}), :mkfs) !=
            Ops.get_string(curr, "mkfs_opt", "")
        changed = true
        ts = convertFsOptionMapToString(
          Ops.get_map(part, "fs_options", {}),
          :mkfs
        )
        Builtins.y2milestone("FsOption ts: %1", ts)
        ret = @sint.changeMkfsOptVolume(dev, ts)
        if ret<0
          Builtins.y2error("ChangeVolumeProperties sint ret: %1", ret)
        else
          Builtins.y2milestone("ChangeVolumeProperties sint ret: %1", ret)
        end
      end
      if ret == 0 && Ops.get_boolean(part, "format", false) &&
          !Builtins.isempty(Ops.get_string(part, "mkfs_options", "")) &&
          Ops.get_string(part, "mkfs_options", "") !=
            Ops.get_string(curr, "mkfs_opt", "")
        changed = true
        ts = Ops.get_string(part, "mkfs_options", "")
        Builtins.y2milestone("FsOption ts: %1", ts)
        ret = @sint.changeMkfsOptVolume(dev, ts)
        if ret<0
          Builtins.y2error("ChangeVolumeProperties sint ret: %1", ret)
        else
          Builtins.y2milestone("ChangeVolumeProperties sint ret: %1", ret)
        end
      end
      if ret == 0 && Ops.get_boolean(part, "format", false) &&
          convertFsOptionMapToString(
            Ops.get_map(part, "fs_options", {}),
            :tunefs
          ) !=
            Ops.get_string(curr, "tunefs_opt", "")
        changed = true
        ts = convertFsOptionMapToString(
          Ops.get_map(part, "fs_options", {}),
          :tunefs
        )
        Builtins.y2milestone("FsOption ts: %1", ts)
        ret = @sint.changeTunefsOptVolume(dev, ts)
        if ret<0
          Builtins.y2error("ChangeVolumeProperties sint ret: %1", ret)
        else
          Builtins.y2milestone("ChangeVolumeProperties sint ret: %1", ret)
        end
      end
      if ret == 0 &&
          Ops.get_symbol(part, "enc_type", :none) !=
            Ops.get_symbol(curr, "enc_type", :none)
        changed = true
        SetCrypt(
          dev,
          Ops.get_symbol(part, "enc_type", :none) != :none,
          Ops.get_boolean(part, "format", false)
        )
      end
      if ret == 0 &&
          Ops.get_string(part, "dtxt", "") != Ops.get_string(curr, "dtxt", "")
        changed = true
        ret = ChangeDescText(dev, Ops.get_string(part, "dtxt", ""))
      end
      if ret == 0 &&
          (Ops.get_boolean(part, "resize", false) &&
            Ops.get_integer(part, ["region", 1], 0) !=
              Ops.get_integer(curr, ["region", 1], 0) ||
            Ops.get_boolean(part, "resize", false) !=
              Ops.get_boolean(curr, "resize", false))
        changed = true
        d = Ops.get_string(part, "device", "")
        i = Ops.get_integer(part, ["region", 1], 0)
        if Ops.get_boolean(part, "resize", false)
          Builtins.y2milestone("ChangeVolumeProperties resize to %1 cyl", i)
          if Ops.get_boolean(part, "ignore_fs", false)
            ret = @sint.resizePartitionNoFs(d, i)
          else
            ret = @sint.resizePartition(d, i)
          end
        else
          ret = @sint.forgetResizeVolume(d)
        end
        if ret<0
          Builtins.y2error("ChangeVolumeProperties sint ret: %1", ret)
        else
          Builtins.y2milestone("ChangeVolumeProperties sint ret: %1", ret)
        end
      end
      if ret == 0 && Ops.get_boolean(part, "change_fsid", false) &&
          Ops.get_integer(part, "fsid", 0) != Ops.get_integer(curr, "fsid", 0)
        changed = true
        d = Ops.get_string(part, "device", "")
        i = Ops.get_integer(part, "fsid", 0)
        Builtins.y2milestone("ChangeVolumeProperties fsid to %1", i)
        ret = @sint.changePartitionId(d, i)
        if ret<0
          Builtins.y2error("ChangeVolumeProperties sint ret: %1", ret)
        else
          Builtins.y2milestone("ChangeVolumeProperties sint ret: %1", ret)
        end
      end
      if ret == 0 && !part.fetch("subvol",[]).empty?
        d = part.fetch("device","")
        fmt = part.fetch("format",false)
        rem = part["subvol"].select { |p| p.fetch("delete",false) }
        cre = part["subvol"].select { |p| !p.fetch("delete",false)&&(p.fetch("create",false)||fmt) }
        Builtins.y2milestone("ChangeVolumeProperties rem: %1", rem)
        Builtins.y2milestone("ChangeVolumeProperties cre: %1", cre)
        while ret == 0 && !rem.empty?
          pth = rem.first.fetch("name","")
          if @sint.existSubvolume(d, pth)
            changed = true
            ret = @sint.removeSubvolume(d, pth)
            if ret<0
              Builtins.y2error("ChangeVolumeProperties sint ret: %1", ret)
            else
              Builtins.y2milestone("ChangeVolumeProperties sint ret: %1", ret)
            end
          end
          rem = rem.drop(1)
        end
        while ret == 0 && !cre.empty?
          subvol = cre.first
          pth   = subvol.fetch("name", "")
          nocow = subvol.fetch("nocow", false)
          log.info "subvolume to create: #{subvol}"
          if ! @sint.existSubvolume(d, pth)
            changed = true
            log.info "creating subvolume #{d} #{pth} nocow: #{nocow}"
            ret = @sint.createSubvolume(d, pth, nocow)
            if ret<0
              Builtins.y2error("ChangeVolumeProperties sint ret: %1", ret)
            else
              Builtins.y2milestone("ChangeVolumeProperties sint ret: %1", ret)
            end
          end
          cre = cre.drop(1)
        end
      end

      if ret == 0 && part.fetch("userdata", {}) != curr.fetch("userdata", {})
        changed = true
        d = part.fetch("device", "")
        userdata = ::Storage::MapStringString.new()
        part.fetch("userdata", {}).each do |a, b|
          userdata[a]= b
        end
        Builtins.y2milestone("ChangeVolumeProperties userdata to %1", userdata.to_s)
        ret = @sint.setUserdata(d, userdata)
        if ret < 0
          Builtins.y2error("ChangeVolumeProperties sint ret: %1", ret)
        else
          Builtins.y2milestone("ChangeVolumeProperties sint ret: %1", ret)
        end
      end

      UpdateTargetMapDev(dev) if changed
      if ret != 0
        Builtins.y2milestone("ChangeVolumeProperties ret: %1", ret)
        Builtins.y2milestone("ChangeVolumeProperties part: %1", part)
        Builtins.y2milestone("ChangeVolumeProperties curr: %1", curr)
      end
      ret == 0
    end


    def DeleteDevice(device)
      Builtins.y2milestone("DeleteDevice device: %1", device)
      ret = @sint.removeVolume(device)
      Builtins.y2error("DeleteDevice sint ret: %1", ret) if ret<0
      UpdateTargetMap()
      ret == 0
    end


    def DeleteLvmVg(name)
      Builtins.y2milestone("DeleteLvmVg name: %1", name)
      ret = @sint.removeLvmVg(name)
      Builtins.y2error("DeleteLvmVg sint ret: %1", ret) if ret<0
      UpdateTargetMap()
      ret == 0
    end


    def DeleteDmraid(name)
      Builtins.y2milestone("DeleteDmraid name: %1", name)
      ret = @sint.removeDmraid(name)
      Builtins.y2error("DeleteDmraid sint ret: %1", ret) if ret<0
      UpdateTargetMap()
      ret == 0
    end


    def DeleteMdPartCo(name)
      Builtins.y2milestone("DeleteMdPartCo name: %1", name)
      ret = @sint.removeMdPartCo(name, true)
      if ret<0
        Builtins.y2error("DeleteMdPartCo sint ret: %1", ret)
      end
      UpdateTargetMap()
      ret == 0
    end


    def CreateLvmVg(name, pesize, lvm2)
      Builtins.y2milestone(
        "CreateLvmVg name: %1 pesize: %2 lvm2: %3",
        name,
        pesize,
        lvm2
      )
      devs = ::Storage::DequeString.new()
      ret = @sint.createLvmVg(name, pesize.div(1024), !lvm2, devs)
      Builtins.y2error("CreateLvmVg sint ret: %1", ret) if ret<0
      UpdateTargetMap()
      ret == 0
    end


    def StringDequeFromList(devs)
      devd = ::Storage::DequeString.new()
      Builtins.foreach(devs) do |s|
        devd.push(s)
      end
      devd
    end


    def CreateLvmVgWithDevs(name, pesize, lvm2, devs)
      devd = StringDequeFromList(devs)
      Builtins.y2milestone(
        "CreateLvmVgWithDevs name: %1 pesize: %2 lvm2: %3 devs: %4",
        name,
        pesize,
        lvm2,
        devs
      )
      ret = @sint.createLvmVg(name, pesize.div(1024), !lvm2, devd)
      if ret<0
        Builtins.y2error("CreateLvmVgWithDevs sint ret: %1", ret)
      end
      UpdateTargetMap()
      ret == 0
    end


    def ExtendLvmVg(name, device)
      Builtins.y2milestone("ExtendLvmVg name: %1 device: %2", name, device)
      devd = ::Storage::DequeString.new()
      devd.push(device)
      ret = @sint.extendLvmVg(name, devd)
      Builtins.y2error("ExtendLvmVg sint ret: %1", ret) if ret<0
      UpdateTargetMap()
      ret == 0
    end


    def ReduceLvmVg(name, device)
      Builtins.y2milestone("ReduceLvmVg name: %1 device: %2", name, device)
      devd = ::Storage::DequeString.new()
      devd.push(device)
      ret = @sint.shrinkLvmVg(name, devd)
      Builtins.y2error("ReduceLvmVg sint ret: %1", ret) if ret<0
      UpdateTargetMap()
      ret == 0
    end


    def CreateLvmLv(vgname, lvname, sizeK, stripes)
      Builtins.y2milestone(
        "CreateLvmLv vg: %1 name: %2 sizeK: %3 stripes: %4",
        vgname,
        lvname,
        sizeK,
        stripes
      )
      ret, dummy = @sint.createLvmLv(vgname, lvname, sizeK, stripes)
      dummy = "" if ret<0
      Builtins.y2error("CreateLvmLv sint ret: %1", ret) if ret<0
      UpdateTargetMapDisk(Ops.add("/dev/", vgname))
      ret == 0
    end


    def CreateLvmThin(vgname, lvname, pool, sizeK)
      Builtins.y2milestone(
        "CreateLvmThin vg: %1 name: %2 pool: %3 sizeK: %4",
        vgname,
        lvname,
        pool,
        sizeK
      )
      ret, dummy = @sint.createLvmLvThin(vgname, lvname, pool, sizeK)
      dummy = "" if ret<0
      Builtins.y2error("CreateLvmLv sint ret: %1", ret) if ret<0
      UpdateTargetMapDisk(Ops.add("/dev/", vgname))
      ret == 0
    end


    def ChangeLvStripeSize(vgname, lvname, stripeSize)
      Builtins.y2milestone(
        "ChangeLvStripeSize vg: %1 name: %2 stripeSize: %3",
        vgname,
        lvname,
        stripeSize
      )
      ret = @sint.changeLvStripeSize(vgname, lvname, stripeSize)
      if ret<0
        Builtins.y2error("ChangeLvStripeSize sint ret: %1", ret)
      end
      UpdateTargetMapDisk(Ops.add("/dev/", vgname))
      ret == 0
    end


    def ChangeLvStripeCount(vgname, lvname, stripes)
      Builtins.y2milestone(
        "ChangeLvStripeCount vg: %1 name: %2 stripes: %3",
        vgname,
        lvname,
        stripes
      )
      ret = @sint.changeLvStripeCount(vgname, lvname, stripes)
      if ret<0
        Builtins.y2error("ChangeLvStripeCount sint ret: %1", ret)
      end
      UpdateTargetMapDisk(Ops.add("/dev/", vgname))
      ret == 0
    end


    def CreateLvmPool(vgname, lvname, sizeK, stripes)
      Builtins.y2milestone(
        "CreateLvmPool vg: %1 name: %2 sizeK: %3 stripes: %4",
        vgname,
        lvname,
        sizeK,
        stripes
      )
      ret, dummy = @sint.createLvmLvPool(vgname, lvname, sizeK)
      dummy = "" if ret<0
      if ret<0
        Builtins.y2error("CreateLvmPool sint ret: %1", ret)
      elsif Ops.greater_than(stripes, 1) &&
          !ChangeLvStripeCount(vgname, lvname, stripes)
        ret = -1
      end
      UpdateTargetMapDisk(Ops.add("/dev/", vgname))
      ret == 0
    end


    def ExtendBtrfsVolume(uuid, device)
      Builtins.y2milestone("ExtendBtrfsVolume uuid: %1 device: %2", uuid, device)
      ret = 0
      devd = ::Storage::DequeString.new()
      devd.push(device)
      ret = @sint.extendBtrfsVolume(uuid, devd)
      if ret<0
        Builtins.y2error("ExtendBtrfsVolume sint ret: %1", ret)
      end
      UpdateTargetMap()
      ret == 0
    end


    def ReduceBtrfsVolume(uuid, device)
      Builtins.y2milestone("ReduceBtrfsVolume uuid: %1 device: %2", uuid, device)
      ret = 0
      devd = ::Storage::DequeString.new()
      devd.push(device)
      ret = @sint.shrinkBtrfsVolume(uuid, devd)
      if ret<0
        Builtins.y2error("ReduceBtrfsVolume sint ret: %1", ret)
      end
      UpdateTargetMap()
      ret == 0
    end


    def AddNfsVolume(nfsdev, opts, sz, mp, nfs4)
      Builtins.y2milestone(
        "AddNfsVolume dev: %1 opts: %2 size: %3 mp: %4 nfs4: %5",
        nfsdev,
        opts,
        sz,
        mp,
        nfs4
      )
      ret = @sint.addNfsDevice(nfsdev, opts, sz, mp, nfs4)
      Builtins.y2error("AddNfsVolume sint ret: %1", ret) if ret<0
      UpdateTargetMapDisk("/dev/nfs")
      ret == 0
    end


    def CheckNfsVolume(nfsdev, opts, nfs4)
      Builtins.y2milestone(
        "CheckNfsVolume dev: %1 opts: %2 nfs4: %3",
        nfsdev,
        opts,
        nfs4
      )
      ret, sz = @sint.checkNfsDevice(nfsdev, opts, nfs4)
      sz = 0 if ret<0
      if ret<0
        Builtins.y2error("CheckNfsVolume sint ret: %1", ret)
      else
        ret = sz
      end
      Builtins.y2milestone("CheckNfsVolume ret: %1", ret)
      ret
    end


    def AddTmpfsVolume(mount, opts)
      Builtins.y2milestone("AddTmpfsVolume mount: %1 opts: %2", mount, opts)
      ret = @sint.addTmpfsMount(mount, opts)
      if ret<0
        Builtins.y2error("AddTmpfsVolume sint ret: %1", ret)
      end
      UpdateTargetMapDisk("/dev/tmpfs")
      ret == 0
    end


    def DelTmpfsVolume(mount)
      Builtins.y2milestone("DelTmpfsVolume mount: %1", mount)
      ret = @sint.removeTmpfsMount(mount)
      if ret<0
        Builtins.y2error("DelTmpfsVolume sint ret: %1", ret)
      end
      UpdateTargetMapDisk("/dev/tmpfs")
      ret == 0
    end


    def MdToDev(nr_or_string)
      Builtins.y2milestone("MdToDev nr_or: %1", nr_or_string)
      if Ops.is_string?(nr_or_string)
         ret = nr_or_string
      else
         ret = "/dev/md"+nr_or_string.to_s
      end
      Builtins.y2milestone("MdToDev ret: %1", ret)
      ret
    end


    def CreateMd(nr, type)
      Builtins.y2milestone("CreateMd nr: %1 type: %2", nr, type)
      tmp = Ops.get(@conv_mdstring, type, 0)
      empty = ::Storage::ListString.new()
      rd = MdToDev(nr)
      ret = @sint.createMd(rd, tmp, empty, empty)
      Builtins.y2error("CreateMd sint ret: %1", ret) if ret<0
      UpdateTargetMapDisk("/dev/md")
      ret == 0
    end


    def StringListFromList(devs)
      ret = ::Storage::ListString.new()
      Builtins.foreach(devs) do |s|
        ret.push(s)
      end
      ret
    end


    def CreateMdWithDevs(nr, type, devices)
      Builtins.y2milestone(
        "CreateMdWithDevs nr: %1 type: %2 devices: %3",
        nr,
        type,
        devices
      )
      tmp = ::Storage::RAID_UNK
      Builtins.foreach(Ops.get_map(@conv_mdtype, "m", {})) do |k, v|
        tmp = k if v == type
      end
      empty = ::Storage::ListString.new()
      devs = StringListFromList(devices);
      rd = MdToDev(nr)
      ret = @sint.createMd(rd, tmp, devs, empty)
      if ret<0
        Builtins.y2error("CreateMdWithDevs sint ret: %1", ret)
      end
      UpdateTargetMap()
      ret == 0
    end


    def ReplaceMd(nr, devs)
      Builtins.y2milestone("ReplaceMd nr: %1 devs: %2", nr, devs)
      empty = ::Storage::ListString.new()
      devices = StringListFromList(devs);
      rd = MdToDev(nr)
      ret = @sint.updateMd(rd, devices, empty)
      Builtins.y2error("ReplaceMd sint ret: %1", ret) if ret<0
      UpdateTargetMap()
      ret == 0
    end


    def ExtendMd(nr, devs)
      Builtins.y2milestone("ExtendMd nr: %1 devs: %2", nr, devs)
      empty = ::Storage::ListString.new()
      devices = StringListFromList(devs);
      rd = MdToDev(nr)
      ret = @sint.extendMd(rd, devices, empty)
      Builtins.y2error("ExtendMd sint ret: %1", ret) if ret<0
      UpdateTargetMap()
      ret == 0
    end


    def ShrinkMd(nr, devs)
      Builtins.y2milestone("ShrinkMd nr: %1 devs: %2", nr, devs)
      empty = ::Storage::ListString.new()
      devices = StringListFromList(devs);
      rd = MdToDev(nr)
      ret = @sint.shrinkMd(rd, devices, empty)
      Builtins.y2error("ShrinkMd sint ret: %1", ret) if ret<0
      UpdateTargetMap()
      ret == 0
    end


    def ChangeMdType(nr, mdtype)
      Builtins.y2milestone("ChangeMdType nr: %1 mdtype: %2", nr, mdtype)
      rd = MdToDev(nr)
      tmp = Ops.get(@conv_mdstring, mdtype, 0)
      ret = @sint.changeMdType(rd, tmp)
      Builtins.y2error("ChangeMdType sint ret: %1", ret) if ret<0
      UpdateTargetMapDev(rd)
      ret == 0
    end


    def ChangeMdParity(nr, ptype)
      Builtins.y2milestone("ChangeMdParity nr: %1 parity: %2", nr, ptype)
      rd = MdToDev(nr)
      tmp = Ops.get(@conv_parstring, ptype, 0)
      ret = @sint.changeMdParity(rd, tmp)
      if ret<0
        Builtins.y2error("ChangeMdParity sint ret: %1", ret)
      end
      UpdateTargetMapDev(rd)
      ret == 0
    end


    def ChangeMdParitySymbol(nr, ptype)
      Builtins.y2milestone("ChangeMdParitySymbol nr: %1 parity: %2", nr, ptype)
      rd = MdToDev(nr)
      tmp = fromSymbol(@conv_mdparity, ptype)
      ret = @sint.changeMdParity(rd, tmp)
      if ret<0
        Builtins.y2error("ChangeMdParitySymbol sint ret: %1", ret)
      end
      UpdateTargetMapDev(rd)
      ret == 0
    end


    def ChangeMdChunk(nr, chunk)
      Builtins.y2milestone("ChangeMdChunk nr: %1 chunk: %2", nr, chunk)
      rd = MdToDev(nr)
      ret = @sint.changeMdChunk(rd, chunk)
      if ret<0
        Builtins.y2error("ChangeMdChunk sint ret: %1", ret)
      end
      UpdateTargetMapDev(rd)
      ret == 0
    end


    def CheckMd(nr)
      Builtins.y2milestone("CheckMd nr: %1", nr)
      ret = 0
      rd = MdToDev(nr)
      ret = @sint.checkMd(rd)
      Builtins.y2milestone("CheckMd sint ret: %1", ret) if ret != 0
      ret
    end


    def ComputeMdSize(md_type, devices, sizeK)
      tmp = ::Storage::RAID_UNK
      Builtins.foreach(Ops.get_map(@conv_mdtype, "m", {})) do |k, v|
        tmp = k if v == md_type
      end
      Builtins.y2milestone("ComputeMdSize devices: %1", devices)
      empty = ::Storage::ListString.new()
      devs = StringListFromList(devices);
      ret, s = @sint.computeMdSize(tmp, devs, empty)
      sizeK.value=s if ret==0
      Builtins.y2milestone("ComputeMdSize sint ret: %1", ret) if ret != 0
      Builtins.y2milestone("ComputeMdSize sizeK: %1", sizeK)
      ret
    end


    def GetCryptPwd(device)
      Builtins.y2milestone("GetCryptPwd device: %1", device)
      ret, pwd = @sint.getCryptPassword(device)
      pwd = "" if ret<0
      if ret<0
        Builtins.y2error("GetCryptPwd sint ret: %1", ret)
      else
        Builtins.y2milestone("GetCryptPwd empty: %1", Builtins.size(pwd) == 0)
      end
      pwd
    end


    def SetCryptPwd(device, pwd)
      Builtins.y2milestone("SetCryptPwd device: %1", device)
      ret = @sint.setCryptPassword(device, pwd)
      if ret<0
        Builtins.y2error("SetCryptPwd sint ret: %1", ret)
      else
        Builtins.y2milestone("SetCryptPwd sint ret: %1", ret)
      end
      ret == 0
    end


    def ActivateCrypt(device, on)
      Builtins.y2milestone("ActivateCrypt device: %1 on: %2", device, on)
      ret = @sint.activateEncryption(device, on)
      if ret<0
        Builtins.y2error("ActivateCrypt ret: %1", ret)
      else
        Builtins.y2milestone("ActivateCrypt ret: %1", ret)
      end
      ret == 0
    end


    def NeedCryptPwd(device)
      ret = @sint.needCryptPassword(device)
      Builtins.y2milestone("NeedCryptPwd device: %1 ret: %2", device, ret)
      ret
    end


    def IsVgEncrypted(tg, vg_key)
      ret = false
      devs = Ops.get_list(tg, [vg_key, "devices"], [])
      Builtins.foreach(devs) do |s|
        p = GetPartition(tg, s)
        ret = Ops.get_symbol(p, "enc_type", :none) == :luks if !ret
        Builtins.y2milestone("IsVgEncrypted ret: %1 p: %2", ret, p)
      end
      Builtins.y2milestone("IsVgEncrypted key: %1 ret: %2", vg_key, ret)
      ret
    end


    def NeedVgPassword(tg, vg_key)
      ret = IsVgEncrypted(tg, vg_key)
      Builtins.y2milestone("NeedVgPassword vg: %1", Ops.get(tg, vg_key, {}))
      if ret
        devs = Ops.get_list(tg, [vg_key, "devices"], [])
        Builtins.foreach(devs) do |s|
          ret = ret && NeedCryptPwd(s)
          Builtins.y2milestone("NeedVgPassword ret: %1 s: %2", ret, s)
        end
      else
        ret = !Builtins.haskey(tg, vg_key)
      end
      Builtins.y2milestone("NeedVgPassword key: %1 ret: %2", vg_key, ret)
      ret
    end


    def CreateLoop(file, create, sizeK, mp)
      Builtins.y2milestone(
        "CreateLoop file: %1 create: %2 sizeK: %3 mp: %4",
        file,
        create,
        sizeK,
        mp
      )
      pwd = GetCryptPwd(file)
      ret, dev = @sint.createFileLoop(file, !create, sizeK, mp, pwd)
      dev = "" if ret<0
      Builtins.y2error("CreateLoop sint ret: %1", ret) if ret<0
      @sint.forgetCryptPassword(file)
      UpdateTargetMapDisk("/dev/loop")
      Builtins.y2milestone("CreateLoop dev: %1", dev)
      dev
    end


    def UpdateLoop(dev, file, create, sizeK)
      Builtins.y2milestone(
        "UpdateLoop device: %1 file: %2 create: %3 sizeK: %4",
        dev,
        file,
        create,
        sizeK
      )
      ret = @sint.modifyFileLoop(dev, file, !create, sizeK)
      Builtins.y2error("UpdateLoop sint ret: %1", ret) if ret<0
      UpdateTargetMapDisk("/dev/loop")
      ret == 0
    end


    def DeleteLoop(disk, file, remove_file)
      Builtins.y2milestone(
        "DeleteLoop disk: %1 file: %2 remove_file: %3",
        disk,
        file,
        remove_file
      )
      ret = @sint.removeFileLoop(file, remove_file)
      Builtins.y2error("DeleteLoop sint ret: %1", ret) if ret<0
      UpdateTargetMapDisk(disk)
      ret == 0
    end


    def DefaultDiskLabel(disk)
      label = @sint.defaultDiskLabel(disk)
      Builtins.y2milestone("DefaultDiskLabel disk: %1 label: %2", disk, label)
      label
    end


    # Delete the partition table and disk label of device
    # @param string the disk to deleted the partition table from
    # @return [Boolean]
    def DeletePartitionTable(disk, label)
      Builtins.y2milestone("DeletePartitionTable disk: %1 label: %2", disk, label)
      label = DefaultDiskLabel(disk) if Builtins.isempty(label)
      ret = @sint.destroyPartitionTable(disk, label)
      if ret<0
        Builtins.y2error("DeletePartitionTable sint ret: %1", ret)
      end
      UpdateTargetMap()
      ret == 0
    end


    def CreatePartitionTable(disk, label)
      Builtins.y2milestone("CreatePartitionTable %1 label: %2", disk, label)
      ret = @sint.destroyPartitionTable(disk, label)
      if ret<0
        Builtins.y2error("CreatePartitionTable sint ret: %1", ret)
      end
      UpdateTargetMap()
      ret == 0
    end


    # Set the flag if a disk needs to be initialized
    # @param string the disk to be changed
    # @return [Boolean]
    def InitializeDisk(disk, value)
      rbool = true
      Builtins.y2milestone("InitializeDisk %1 value %2", disk, value)
      ret = @sint.initializeDisk(disk, value)
      if ret<0
        Builtins.y2error("InitializeDisk sint ret: %1", ret)
        rbool = false
      end
      if rbool && value
        d = GetDisk(GetTargetMap(), disk)
        Builtins.y2milestone("d: %1", d)
        rbool = CreatePartition(
          disk,
          Ops.add(disk, "1"),
          :primary,
          Partitions.fsid_native,
          0,
          Ops.get_integer(d, "cyl_count", 1),
          GetMountBy(Ops.add(disk, "1"))
        )
        Builtins.y2error("InitializeDisk create failed") if !rbool
      end
      UpdateTargetMapDisk(disk)
      rbool
    end


    def IsPartType(t)
      t == :CT_DMRAID || t == :CT_DMMULTIPATH || t == :CT_DISK ||
        t == :CT_MDPART
    end


    def CreateAny(ctype, d, p)
      ret = true
      if IsPartType(ctype)
        mby = GetMountBy(Ops.get_string(p.value, "device", ""))
        mby = :uuid if Ops.get_symbol(p.value, "used_fs", :unknown) == :btrfs
        ret = CreatePartition(
          Ops.get_string(d, "device", ""),
          Ops.get_string(p.value, "device", ""),
          Ops.get_symbol(p.value, "type", :primary),
          Ops.get_integer(p.value, "fsid", Partitions.fsid_native),
          Ops.get_integer(p.value, ["region", 0], 0),
          Ops.get_integer(p.value, ["region", 1], 0),
          Ops.get_symbol(p.value, "mountby", mby)
        )
        if !Builtins.haskey(p.value, "mountby") && mby != :device
          Ops.set(p.value, "mountby", mby)
        end
      elsif ctype == :CT_MD
        ret = CreateMd( p.value["device"], p.value.fetch("raid_type","raid1") )
        if ret && p.value.has_key?("chunk_size")
          ChangeMdChunk( p.value["device"], p.value.fetch("chunk_size",4) )
        end
        if ret && HasRaidParity(p.value.fetch("raid_type","")) &&
            p.value.has_key?("parity_algorithm")
          ChangeMdParity( p.value["device"], p.value.fetch("parity_algorithm",""))
        end
        if ret
          ret = ExtendMd( p.value["device"], p.value.fetch("devices",[]))
        end
      elsif ctype == :CT_LOOP
        Builtins.y2milestone("CreateAny Loop p: %1", p.value)
        dev = CreateLoop(
          Ops.get_string(p.value, "fpath", ""),
          Ops.get_boolean(p.value, "create_file", false),
          Ops.get_integer(p.value, "size_k", 0),
          Ops.get_string(p.value, "mount", "")
        )
        ret = Ops.greater_than(Builtins.size(dev), 0)
        Ops.set(p.value, "device", dev) if ret
      elsif ctype == :CT_LVM
        if Ops.get_boolean(p.value, "pool", false)
          ret = CreateLvmPool(
            Ops.get_string(d, "name", ""),
            Ops.get_string(p.value, "name", ""),
            Ops.get_integer(p.value, "size_k", 0),
            Ops.get_integer(p.value, "stripes", 1)
          )
        elsif !Builtins.isempty(Ops.get_string(p.value, "used_pool", ""))
          ret = CreateLvmThin(
            Ops.get_string(d, "name", ""),
            Ops.get_string(p.value, "name", ""),
            Ops.get_string(p.value, "used_pool", ""),
            Ops.get_integer(p.value, "size_k", 0)
          )
        else
          ret = CreateLvmLv(
            Ops.get_string(d, "name", ""),
            Ops.get_string(p.value, "name", ""),
            Ops.get_integer(p.value, "size_k", 0),
            Ops.get_integer(p.value, "stripes", 1)
          )
        end
        if ret && Ops.greater_than(Ops.get_integer(p.value, "stripes", 1), 1) &&
            Ops.greater_than(Ops.get_integer(p.value, "stripesize", 0), 0)
          ChangeLvStripeSize(
            Ops.get_string(d, "name", ""),
            Ops.get_string(p.value, "name", ""),
            Ops.get_integer(p.value, "stripesize", 0)
          )
        end
      elsif ctype == :CT_NFS
        ret = AddNfsVolume(
          Ops.get_string(p.value, "device", ""),
          Ops.get_string(p.value, "fstopt", ""),
          Ops.get_integer(p.value, "size_k", 0),
          Ops.get_string(p.value, "mount", ""),
          Ops.get_symbol(p.value, "used_fs", :nfs) == :nfs4
        )
      end
      Builtins.y2milestone("CreateAny ret: %1", ret)
      ret
    end


    def IsEfiPartition(p)
      p = deep_copy(p)
      ret = false

      resize_info = {}
      content_info = {}
      if (
          resize_info_ref = arg_ref(resize_info);
          content_info_ref = arg_ref(content_info);
          _GetFreeInfo_result = GetFreeInfo(
            Ops.get_string(p, "device", ""),
            false,
            resize_info_ref,
            true,
            content_info_ref,
            true
          );
          resize_info = resize_info_ref.value;
          content_info = content_info_ref.value;
          _GetFreeInfo_result
        ) &&
          Ops.get_boolean(content_info, :efi, false)
        ret = true
      end

      Builtins.y2milestone("IsEfiPartition ret: %1", ret)
      ret
    end


    # Search in the list partitions for windows partitions and add the key
    # "mount" to the found windows partitions.
    # @parm partitions the partitions list
    # @parm primary handle primary or logical partitions
    # @return [Array] new partitions with windows mountpoints
    def AddMountPointsForWinParts(partitions, primary, max_prim, foreign_nr)
      partitions = deep_copy(partitions)
      return if !Arch.i386 && !Arch.ia64 && !Arch.x86_64

      foreign_ids = "CDEFGHIJKLMNOPQRSTUVW"

      Builtins.foreach(partitions) do |partition|
        new_partition = deep_copy(partition)
        fsid = Ops.get_integer(partition, "fsid", Partitions.fsid_native)
        partnum = 0
        if Builtins.haskey(partition, "nr") &&
            Ops.is_integer?(Ops.get(partition, "nr", 0))
          partnum = Ops.get_integer(partition, "nr", 0)
        end
        if !Builtins.haskey(partition, "mount") &&
            !Ops.get_boolean(partition, "delete", false) &&
            Ops.less_or_equal(partnum, max_prim) == primary &&
            Ops.less_than(foreign_nr.value, 24) &&
            Partitions.IsDosWinNtPartition(fsid) &&
            !Arch.ia64 &&
            !IsEfiPartition(partition) &&
            Ops.greater_or_equal(
              Ops.get_integer(partition, "size_k", 0),
              1024 * 1024
            ) &&
            Builtins.contains(
              [:vfat, :ntfs],
              Ops.get_symbol(partition, "used_fs", :none)
            )
          Ops.set(
            new_partition,
            "fstopt",
            FileSystems.DefaultFstabOptions(partition)
          )
          if Builtins.contains(Partitions.fsid_dostypes, fsid)
            Ops.set(
              new_partition,
              "mount",
              Ops.add(
                "/dos/",
                Builtins.substring(foreign_ids, foreign_nr.value, 1)
              )
            )
            foreign_nr.value = Ops.add(foreign_nr.value, 1)
          else
            Ops.set(
              new_partition,
              "mount",
              Ops.add(
                "/windows/",
                Builtins.substring(foreign_ids, foreign_nr.value, 1)
              )
            )
            foreign_nr.value = Ops.add(foreign_nr.value, 1)
          end
          ChangeVolumeProperties(new_partition)
          Builtins.y2milestone("win part %1", new_partition)
        end
      end

      nil
    end


    def AddMountPointsForWin(targets)
      targets = deep_copy(targets)
      if false # no mount points for windows any more bnc#763630
        Builtins.y2milestone("AddMountPointsForWin called")
        foreign_nr = 0

        Builtins.foreach(targets) do |disk, data|
          if !Ops.get_boolean(data, "hotpluggable", false) &&
              Ops.get_symbol(data, "used_by_type", :UB_NONE) == :UB_NONE
            foreign_nr_ref = arg_ref(foreign_nr)
            AddMountPointsForWinParts(
              Ops.get_list(data, "partitions", []),
              true,
              Ops.get_integer(data, "max_primary", 4),
              foreign_nr_ref
            )
            foreign_nr = foreign_nr_ref.value
          end
        end
        Builtins.foreach(targets) do |disk, data|
          if !Ops.get_boolean(data, "hotpluggable", false) &&
              Ops.get_symbol(data, "used_by_type", :UB_NONE) == :UB_NONE
            foreign_nr_ref = arg_ref(foreign_nr)
            AddMountPointsForWinParts(
              Ops.get_list(data, "partitions", []),
              false,
              Ops.get_integer(data, "max_primary", 4),
              foreign_nr_ref
            )
            foreign_nr = foreign_nr_ref.value
          end
        end
      end

      nil
    end


    # Removes ... maps to ...
    #
    # @param [String] device name
    def RemoveDmMapsTo(device)
      Builtins.y2milestone("RemoveDmMapsTo device: %1", device)
      return if !InitLibstorage(false)
      @sint.removeDmTableTo(device)
      nil
    end


    def CheckSwapable(dev)
      return true if Mode.test

      cmd = Ops.add("/sbin/swapon --fixpgsz ", dev)
      ok = Convert.to_integer(SCR.Execute(path(".target.bash"), cmd)) == 0
      if ok
        cmd = Ops.add("/sbin/swapoff ", dev)
        SCR.Execute(path(".target.bash"), cmd)
      end
      Builtins.y2milestone("CheckSwapable dev: %1 ret: %2", dev, ok)
      ok
    end


    # mark swap-partitions with pseudo Mountpoint swap in targetMap
    # @param [Hash{String => map}] target Disk map
    # @return [Hash{String => map}] modified target
    def AddSwapMp(target)
      target = deep_copy(target)
      swaps = SwappingPartitions()
      Builtins.y2milestone("AddSwapMp swaps %1", swaps)
      Builtins.foreach(target) do |diskdev, disk|
        Ops.set(
          disk,
          "partitions",
          Builtins.maplist(Ops.get_list(disk, "partitions", [])) do |part|
            if Stage.initial &&
                !Partitions.IsDosWinNtPartition(
                  Ops.get_integer(part, "fsid", 0)
                ) &&
                Ops.get_symbol(part, "detected_fs", :unknown) == :swap &&
                !Ops.get_boolean(part, "old_swap", false) &&
                Builtins.search(diskdev, "/dev/evms") != 0 ||
                Builtins.contains(swaps, Ops.get_string(part, "device", ""))
              Builtins.y2milestone("AddSwapMp %1", part)
              ok = true
              if !Builtins.contains(swaps, Ops.get_string(part, "device", ""))
                dev = Ops.get_string(part, "device", "")
                if !Builtins.isempty(Ops.get_string(part, "crypt_device", ""))
                  dev = Ops.get_string(part, "crypt_device", "")
                end
                ok = CheckSwapable(dev)
                Builtins.y2milestone("AddSwapMp initial ok: %1", ok)
              end
              if ok
                Ops.set(part, "mount", "swap")
                ChangeVolumeProperties(part)
                Builtins.y2milestone("AddSwapMp %1", part)
              end
            end
            deep_copy(part)
          end
        )
        Ops.set(target, diskdev, disk)
      end
      deep_copy(target)
    end


    def CheckCryptOk(dev, fs_passwd, silent, erase)
      i = @sint.verifyCryptPassword(dev, fs_passwd, erase)
      if i != 0 && !silent
        Popup.Error(
          Builtins.sformat(
            _(
              "Could not set encryption.\n" +
                "System error code is %1.\n" +
                "\n" +
                "The encryption password provided could be incorrect.\n"
            ),
            i
          )
        )
      end
      Builtins.y2milestone(
        "CheckCryptOk dev: %1 pwlen: %2 ret: %3",
        dev,
        Builtins.size(fs_passwd),
        i == 0
      )
      i == 0
    end


    def RescanCrypted
      ret = @sint.rescanCryptedObjects()
      Builtins.y2milestone("RescanCrypted ret: %1", ret)
      ret
    end


    def CheckEncryptionPasswords(pw1, pw2, min_length, empty_allowed)
      if pw1 != pw2
        # popup text
        Popup.Message(
          _(
            "The first and the second version\n" +
              "of the password do not match.\n" +
              "Try again."
          )
        )
        return false
      end

      if Builtins.isempty(pw1)
        if !empty_allowed
          # popup text
          Popup.Message(_("You did not enter a password.\nTry again.\n"))
          return false
        end
      else
        if Ops.less_than(Builtins.size(pw1), min_length)
          # popup text
          Popup.Message(
            Builtins.sformat(
              _("The password must have at least %1 characters.\nTry again.\n"),
              min_length
            )
          )
          return false
        end

        allowed_chars = "0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ#* ,.;:._-+=!$%&/|?{[()]}@^\\<>"
        if Builtins.findfirstnotof(pw1, allowed_chars) != nil
          # popup text
          Popup.Message(
            _(
              "The password may only contain the following characters:\n" +
                "0..9, a..z, A..Z, and any of \"@#* ,.;:._-+=!$%&/|?{[()]}^\\<>\".\n" +
                "Try again."
            )
          )
          return false
        end
      end

      true
    end


    def PasswdPopup(helptxt, header, label, pw2, minpwlen, tmpcrypt)
      ad = Empty()
      if pw2
        ad = VBox(
          VSpacing(0.5),
          HBox(
            Password(
              Id(:pw2),
              Opt(:hstretch),
              # Label: get same password again for verification
              # Please use newline if label is longer than 40 characters
              _("Reenter the Password for &Verification:"),
              ""
            ),
            HSpacing(13)
          )
        )
      end
      UI.OpenDialog(
        Opt(:decorated),
        HBox(
          HWeight(3, RichText(helptxt)),
          HWeight(
            6,
            VBox(
              VSpacing(0.3),
              HBox(HSpacing(1), Heading(header), HSpacing(1)),
              VSpacing(1),
              HBox(
                HSpacing(4),
                VBox(
                  # label text
                  Label(label),
                  VSpacing(),
                  HBox(
                    Password(
                      Id(:pw1),
                      Opt(:hstretch),
                      # Label: get password for encrypted volume
                      # Please use newline if label is longer than 40 characters
                      _("&Enter Encryption Password:"),
                      ""
                    ),
                    HSpacing(13)
                  ),
                  ad
                ),
                HSpacing(4)
              ),
              VSpacing(2),
              ButtonBox(
                PushButton(Id(:ok), Opt(:default), Label.OKButton),
                PushButton(Id(:cancel), Label.CancelButton)
              ),
              VSpacing(0.5)
            )
          )
        )
      )

      ret = ""
      password = ""
      widget = nil
      begin
        # Clear password fields on every round.
        UI.ChangeWidget(Id(:pw1), :Value, "")
        UI.ChangeWidget(Id(:pw2), :Value, "") if pw2

        UI.SetFocus(Id(:pw1))

        widget = Convert.to_symbol(UI.UserInput)

        case widget
          when :ok
            password = Convert.to_string(UI.QueryWidget(Id(:pw1), :Value))

            if pw2
              tmp = Convert.to_string(UI.QueryWidget(Id(:pw2), :Value))
              if !CheckEncryptionPasswords(password, tmp, minpwlen, tmpcrypt)
                widget = :again
              else
                ret = password
              end
            else
              ret = password
            end
        end
      end until widget == :cancel || widget == :ok

      UI.CloseDialog
      ret = password if widget == :ok
      ret
    end


    def CryptVolPopup(dev1, dev2)
      dev1 = deep_copy(dev1)
      dev2 = deep_copy(dev2)
      button_box = ButtonBox(
        PushButton(Id(:yes), Opt(:okButton), _("Provide Password")),
        PushButton(
          Id(:no_button),
          Opt(:default, :cancelButton),
          Label.CancelButton
        )
      )

      display_info = UI.GetDisplayInfo
      has_image_support = Ops.get_boolean(
        display_info,
        "HasImageSupport",
        false
      )

      ad = Empty()
      if Ops.greater_than(Builtins.size(dev2), 0)
        ad = VBox(
          Left(
            Label(_("The following encrypted volumes are already available."))
          ),
          Left(RichText(HTML.List(Builtins.sort(dev2)))),
          VSpacing(0.2)
        )
      end

      icon = has_image_support ? Top(Image(Icon.IconPath("question"))) : Empty()

      layout = VBox(
        VSpacing(0.4),
        HBox(
          icon,
          HSpacing(1),
          VBox(
            Left(Heading(_("Encrypted Volume Activation"))),
            VSpacing(0.2),
            Left(
              Label(
                _(
                  "The following volumes contain an encryption signature but the \n" +
                    "passwords are not yet known.\n" +
                    "The passwords need to be known if the volumes are needed either \n" +
                    "during an update or if they contain an encrypted LVM physical volume."
                )
              )
            ),
            VSpacing(0.2),
            Left(RichText(HTML.List(Builtins.sort(dev1)))),
            VSpacing(0.2),
            ad,
            Left(Label(_("Do you want to provide encryption passwords?"))),
            button_box
          )
        )
      )

      UI.OpenDialog(layout)
      ret = Convert.to_symbol(UI.UserInput)
      UI.CloseDialog
      Builtins.y2milestone("symbol: %1", ret)
      ret == :yes
    end


    def GetCryptLists(target)
      target = deep_copy(target)
      ac_cr = []
      in_cr = []
      Builtins.foreach(target) do |k, m|
        tmp = Builtins.filter(Ops.get_list(m, "partitions", [])) do |p|
          Ops.get_symbol(p, "enc_type", :none) == :luks
        end
        in_cr = Convert.convert(
          Builtins.merge(in_cr, Builtins.filter(tmp) do |p|
            Builtins.isempty(Ops.get_string(p, "crypt_device", ""))
          end),
          :from => "list",
          :to   => "list <map>"
        )
        ac_cr = Convert.convert(
          Builtins.merge(ac_cr, Builtins.filter(tmp) do |p|
            !Builtins.isempty(Ops.get_string(p, "crypt_device", ""))
          end),
          :from => "list",
          :to   => "list <map>"
        )
      end
      Builtins.y2milestone("GetCryptLists inactive: %1", in_cr)
      Builtins.y2milestone("GetCryptLists active: %1", ac_cr)
      ret = {}
      Ops.set(ret, "active", Builtins.maplist(ac_cr) do |p|
        Ops.get_string(p, "device", "")
      end)
      Ops.set(ret, "inactive", Builtins.maplist(in_cr) do |p|
        Ops.get_string(p, "device", "")
      end)
      Builtins.y2milestone("ret: %1", ret)
      deep_copy(ret)
    end


    def AskCryptPasswords(target)
      target = deep_copy(target)
      crvol = GetCryptLists(target)
      ret = true
      rescan_done = false
      # text in help field
      helptext = _(
        "Enter encryption password for any of the\n" +
          "devices in the locked devices list.\n" +
          "Password will be tried for all devices."
      )
      # header text
      header = _("Enter Encryption Password")

      if Mode.normal && Builtins.size(Ops.get_list(crvol, "inactive", [])) == 0
        Popup.Error(_("There are no encrypted volume to unlock."))
      end
      while Ops.greater_than(
          Builtins.size(Ops.get_list(crvol, "inactive", [])),
          0
        ) && ret
        ret = CryptVolPopup(
          Ops.get_list(crvol, "inactive", []),
          Ops.get_list(crvol, "active", [])
        )
        Builtins.y2milestone("ret: %1", ret)
        if ret
          # label text, multiple device names follow
          label = _("Provide password for any of the following devices:")
          if Builtins.size(Ops.get_list(crvol, "inactive", [])) == 1
            # label text, one device name follows
            label = _("Provide password for the following device:")
          end
          Builtins.foreach(Ops.get_list(crvol, "inactive", [])) do |s|
            label = Ops.add(label, Builtins.sformat("\n%1", s))
          end
          pw = PasswdPopup(helptext, header, label, false, 1, false)
          if Ops.greater_than(Builtins.size(pw), 0)
            UI.OpenDialog(
              Opt(:decorated),
              VBox(
                VSpacing(1),
                HBox(
                  HSpacing(1),
                  Label(_("Trying to unlock encrypted volumes...")),
                  HSpacing(1)
                ),
                VSpacing(1)
              )
            )
            unlock = false
            rl = []
            Builtins.foreach(Ops.get_list(crvol, "inactive", [])) do |d|
              if CheckCryptOk(d, pw, true, false) && SetCryptPwd(d, pw) &&
                  SetCrypt(d, true, false) &&
                  ActivateCrypt(d, true)
                Builtins.y2milestone("AskCryptPasswords activated %1", d)
                unlock = true
                Ops.set(
                  crvol,
                  "active",
                  Builtins.add(Ops.get_list(crvol, "active", []), d)
                )
                rl = Builtins.add(rl, d)
              end
            end
            UI.CloseDialog
            if !unlock
              Popup.Error(_("Password did not unlock any volume."))
            else
              Ops.set(
                crvol,
                "inactive",
                Builtins.filter(Ops.get_list(crvol, "inactive", [])) do |s|
                  !Builtins.contains(rl, s)
                end
              )
              RescanCrypted()
              rescan_done = true
            end
          end
        end
      end
      if rescan_done
        Ops.set(@StorageMap, @targets_key, target)
        UpdateTargetMap()
        target = Ops.get_map(@StorageMap, @targets_key, {})
      end
      deep_copy(target)
    end


    def ChangeDmNamesFromCrypttab(crfile)
      st = Convert.to_map(SCR.Read(path(".target.stat"), crfile))
      Builtins.y2milestone(
        "ChangeDmNamesFromCrypttab crfile: %1 st: %2",
        crfile,
        st
      )
      if Ops.greater_than(Ops.get_integer(st, "size", 0), 0)
        Yast.import "AsciiFile"
        cr = {}
        cr_ref = arg_ref(cr)
        AsciiFile.SetDelimiter(cr_ref, " \t")
        cr = cr_ref.value
        cr_ref = arg_ref(cr)
        AsciiFile.ReadFile(cr_ref, crfile)
        cr = cr_ref.value
        i = 1
        r = 0
        while Ops.less_or_equal(i, AsciiFile.NumLines(cr))
          l = (
            cr_ref = arg_ref(cr);
            _GetLine_result = AsciiFile.GetLine(cr_ref, i);
            cr = cr_ref.value;
            _GetLine_result
          )
          Builtins.y2milestone("ChangeDmNamesFromCrypttab line: %1 is: %2", i, l)
          dev = Ops.get_string(l, ["fields", 1], "")
          nm = Ops.get_string(l, ["fields", 0], "")
          if !Builtins.isempty(dev) && !Builtins.isempty(nm)
            r = @sint.renameCryptDm(dev, nm)
            Builtins.y2milestone(
              "ChangeDmNamesFromCrypttab rename dm of %1 to %2 ret: %3",
              dev, nm, r)
          end
          i = Ops.add(i, 1)
        end
        @sint.dumpObjectList()
      end

      nil
    end


    def AddProposalName(target_map)
      target_map = deep_copy(target_map)
      ide_disk_count = 0
      scsi_disk_count = 0
      generic_disk_count = 0
      dm_raid_count = 0
      md_raid_count = 0

      Builtins.mapmap(target_map) do |device, disk|
        s = KByteToHumanString(Ops.get_integer(disk, "size_k", 0))
        case Ops.get_symbol(disk, "type", :CT_UNKNOWN)
          when :CT_DISK
            proposal_name = ""

            bus = Ops.get_string(disk, "bus", "")
            if bus == "IDE"
              ide_disk_count = Ops.add(ide_disk_count, 1)
              proposal_name = Ops.add(
                Builtins.sformat("%1. ", ide_disk_count),
                _("IDE Disk")
              )
            elsif bus == "SCSI"
              scsi_disk_count = Ops.add(scsi_disk_count, 1)
              proposal_name = Ops.add(
                Builtins.sformat("%1. ", scsi_disk_count),
                _("SCSI Disk")
              )
            else
              generic_disk_count = Ops.add(generic_disk_count, 1)
              proposal_name = Ops.add(
                Builtins.sformat("%1. ", generic_disk_count),
                _("Disk")
              )
            end

            proposal_name = Ops.add(
              Ops.add(
                Ops.add(Ops.add(Ops.add(proposal_name, ", "), s), ", "),
                device
              ),
              ", "
            )

            if !Builtins.isempty(Ops.get_string(disk, "vendor", ""))
              proposal_name = Ops.add(
                Ops.add(proposal_name, Ops.get_string(disk, "vendor", "")),
                "-"
              )
            end
            proposal_name = Ops.add(
              proposal_name,
              Ops.get_string(disk, "model", "")
            )

            Ops.set(disk, "proposal_name", proposal_name)
          when :CT_DMRAID
            dm_raid_count = Ops.add(dm_raid_count, 1)
            proposal_name = Ops.add(
              Builtins.sformat("%1. ", dm_raid_count),
              _("DM RAID")
            )

            proposal_name = Ops.add(
              Ops.add(Ops.add(Ops.add(proposal_name, ", "), s), ", "),
              device
            )

            Ops.set(disk, "proposal_name", proposal_name)
          when :CT_MDPART
            md_raid_count = Ops.add(md_raid_count, 1)
            proposal_name = Ops.add(
              Builtins.sformat("%1. ", md_raid_count),
              _("MD RAID")
            )

            proposal_name = Ops.add(
              Ops.add(Ops.add(Ops.add(proposal_name, ", "), s), ", "),
              device
            )

            Ops.set(disk, "proposal_name", proposal_name)
        end
        { device => disk }
      end
    end


    # Returns a system target map.
    #
    # @return [Hash{String => map}] target map
    #
    #
    # **Structure:**
    #
    #
    #      $[
    #         ... ?
    #      ]
    def GetTargetMap
      return nil if !InitLibstorage(false)

      tmp = {}
      changed = false

      if Mode.test
        Builtins.foreach(@conts) do |c|
          Ops.set(tmp, Ops.get_string(c, "device", ""), getContainerInfo(c))
        end
        Ops.set(@StorageMap, @targets_key, tmp)
        if !@probe_done
          @probe_done = true
          changed = true
        end
      elsif !@probe_done && !Mode.config
        bios_id_raid = {}
        Builtins.y2milestone("probing StorageDevices")
        rename = {}
        tmp = StorageDevices.Probe(true)
        Builtins.foreach(tmp) do |dev, disk|
          dtmp = Ops.get(GetDiskPartitionTg(dev, {}), 0, {})
          Builtins.y2milestone("probing dev %1 disk %2", dev, dtmp)
          if Builtins.search(dev, "/dev/dm-") == 0 ||
              Builtins.search(dev, "/dev/md") == 0
            if Ops.greater_than(
                Builtins.size(Ops.get_string(disk, "bios_id", "")),
                0
              )
              Ops.set(bios_id_raid, dev, Ops.get_string(disk, "bios_id", ""))
            end
          elsif Ops.greater_than(
              Builtins.size(Ops.get_string(dtmp, "disk", "")),
              0
            ) &&
              dev != Ops.get_string(dtmp, "disk", "")
            Ops.set(rename, dev, Ops.get_string(dtmp, "disk", ""))
            Builtins.y2milestone("probing rename %1", rename)
          end
        end
        tmp = Builtins.filter(tmp) do |dev, disk|
          Builtins.search(dev, "/dev/dm-") != 0
        end
        tmp = Builtins.filter(tmp) do |dev, disk|
          Builtins.search(dev, "/dev/md") != 0
        end
        Builtins.foreach(rename) do |old, new|
          if Builtins.haskey(tmp, old)
            Ops.set(tmp, new, Ops.get(tmp, old, {}))
            tmp = Builtins.remove(tmp, old)
            Ops.set(tmp, [new, "device"], new)
            Builtins.y2milestone(
              "probing old: %1 new: %2",
              old,
              Ops.get(tmp, new, {})
            )
          end
        end if Ops.greater_than(
          Builtins.size(rename),
          0
        )

        # remove all devices unknown to libstorage, otherwise the target-map
        # has containers without container-type
        tmp.select! do |dev, disk|
          @conts.any? { |c| c["device"] == dev }
        end

        Builtins.y2milestone("probing done")
        @probe_done = true
        changed = true
        Builtins.foreach(tmp) do |dev, disk|
          Ops.set(tmp, dev, getDiskInfo(dev, disk))
          InitializeDisk(dev, true) if Ops.get_boolean(disk, "dasdfmt", false)
        end
        Builtins.foreach(@conts) do |c|
          if Ops.get_symbol(c, "type", :CT_UNKNOWN) != :CT_DISK
            Ops.set(tmp, Ops.get_string(c, "device", ""), getContainerInfo(c))
          end
        end
        tmp = HandleBtrfsSimpleVolumes(tmp)
        if !Builtins.isempty(bios_id_raid)
          Builtins.y2milestone("bios_id_raid: %1", bios_id_raid)
          Builtins.foreach(bios_id_raid) do |dm, bios|
            pos = Builtins.findfirstof(dm, "0123456789")
            minor = Builtins.tointeger(Builtins.substring(dm, pos))
            Builtins.y2milestone("pos: %1 minor: %2", pos, minor)
            Builtins.foreach(tmp) do |dev, c|
              if Ops.get_symbol(c, "type", :CT_UNKNOWN) == :CT_DMRAID &&
                  Ops.get_integer(c, "minor", 0) == minor
                Builtins.y2milestone("adding bios_id %1 to %2", bios, dev)
                Ops.set(tmp, [dev, "bios_id"], bios)
              end
              if Ops.get_symbol(c, "type", :CT_UNKNOWN) == :CT_MDPART &&
                  Ops.get_string(c, "device", "") == dm
                Builtins.y2milestone("adding bios_id %1 to %2", bios, dev)
                Ops.set(tmp, [dev, "bios_id"], bios)
              end
            end
          end
        end
        if Stage.initial
          tmp = AddProposalName(tmp)
          tmp = AskCryptPasswords(tmp) unless skip_activation_popup?
        end
        Ops.set(@StorageMap, @targets_key, tmp)
      end
      if changed
        tmp = Ops.get_map(@StorageMap, @targets_key, {})
        SCR.Write(path(".target.ycp"), SaveDumpPath("targetMap_i"), tmp)
        if !Mode.autoinst
          Builtins.y2milestone("AddSwapMp")
          tmp = AddSwapMp(tmp)
        end
        CreateTargetBackup("initial")
        if Stage.initial && !Mode.autoinst
          AddMountPointsForWin(tmp)
        end
        Ops.set(@StorageMap, @targets_key, GetTargetMap())
        SCR.Write(path(".target.ycp"), SaveDumpPath("targetMap_ii"), tmp)
        Builtins.y2milestone("changed done")
      end

      ret = Ops.get_map(@StorageMap, @targets_key, {})
      if changed
        Builtins.y2milestone("GetTargetMap changed: %1", changed)
      else
        Builtins.y2debug("GetTargetMap changed: %1", changed)
      end
      Builtins.foreach(ret) do |k, m|
        if changed
          Builtins.y2milestone("GetTargetMap %1: %2", k, m)
        else
          Builtins.y2debug("GetTargetMap %1: %2", k, m)
        end
      end
      deep_copy(ret)
    end


    def GetAffectedDevices(dev)
      devs = ::Storage::ListString.new();
      devs.push(dev)
      r = ::Storage::ListString.new();
      res = @sint.getRecursiveUsing(devs, false, r);
      Builtins.y2milestone("GetAffectedDevices dev: %1 ret: %2", dev, res)
      ret = r.to_a
      Builtins.y2milestone("GetAffectedDevices ret: %1", ret)
      ret
    end


    def SetRecursiveRemoval(val)
      Builtins.y2milestone("SetRecursiveRemoval val: %1", val)
      @sint.setRecursiveRemoval(val)
      nil
    end


    def GetRecursiveRemoval
      @sint.getRecursiveRemoval()
    end


    # Sets the target map.
    # This function should not be used since it is very fragile. Error
    # handling is basically non-existing. Instead use individual functions to
    # modify devices.
    def SetTargetMap(target)
      target = deep_copy(target)
      save_crypt = {}
      Builtins.y2milestone("SetTargetMap")
      SetRecursiveRemoval(true) if !GetRecursiveRemoval()
      #SCR::Write(.target.ycp, Storage::SaveDumpPath("targetMap_set_"+sformat("%1",count)), target );
      #count = count+1;
      CreateTargetBackup("tmp_set")
      tg = GetTargetMap()
      keys = Builtins.maplist(target) { |k, e| k }
      Builtins.foreach(keys) do |k|
        if Ops.get_boolean(target, [k, "delete"], false) &&
            Builtins.haskey(tg, k)
          if Ops.get_symbol(target, [k, "type"], :CT_UNKNOWN) == :CT_LVM
            DeleteLvmVg(Ops.get_string(target, [k, "name"], ""))
            Ops.set(target, [k, "delete"], false)
          elsif Ops.get_symbol(target, [k, "type"], :CT_UNKNOWN) == :CT_DMRAID
            DeleteDmraid(k)
            Ops.set(target, [k, "delete"], false)
          end
        end
      end
      keys = Builtins.maplist(target) { |k, e| k }
      Builtins.y2milestone("SetTargetMap keys %1", keys)
      t1 = Builtins.filter(keys) do |k|
        !Ops.get_boolean(target, [k, "delete"], false) &&
          !Ops.get_boolean(target, [k, "create"], false)
      end
      Builtins.foreach(t1) do |k|
        dps = Builtins.filter(Ops.get_list(target, [k, "partitions"], [])) do |p|
          !Ops.get_boolean(p, "create", false) &&
            !Ops.get_boolean(p, "delete", false)
        end
        Builtins.foreach(dps) do |p|
          if Ops.get_symbol(p, "type", :primary) != :extended ||
              Ops.get_boolean(p, "resize", false)
            ChangeVolumeProperties(p)
          end
        end if Ops.greater_than(
          Builtins.size(dps),
          0
        )
      end
      keys = Builtins.maplist(tg) { |k, e| k }
      keys = Builtins.sort(keys) do |a, b|
        Ops.greater_than(
          Ops.get(@type_order, Ops.get_symbol(tg, [a, "type"], :CT_UNKNOWN), 9),
          Ops.get(@type_order, Ops.get_symbol(tg, [b, "type"], :CT_UNKNOWN), 9)
        )
      end
      Builtins.y2milestone("SetTargetMap keys %1", keys)
      Builtins.foreach(keys) do |k|
        dps = Builtins.filter(Ops.get_list(tg, [k, "partitions"], [])) do |p|
          Ops.get_boolean(p, "create", false)
        end
        if Ops.greater_than(Builtins.size(dps), 1) &&
            Builtins.haskey(Ops.get(dps, 0, {}), "nr")
          dps = Builtins.sort(dps) do |a, b|
            Ops.greater_than(
              Ops.get_integer(a, "nr", 0),
              Ops.get_integer(b, "nr", 0)
            )
          end
          Builtins.y2milestone("SetTargetMap dps: %1", dps)
        end
        Builtins.foreach(dps) do |p|
          tdev = Ops.get_string(p, "device", "")
          if Ops.get_symbol(p, "enc_type", :none) != :none
            Ops.set(save_crypt, tdev, GetCryptPwd(tdev))
          end
          DeleteDevice(tdev)
        end
        if Ops.get_boolean(tg, [k, "create"], false)
          if Ops.get_symbol(tg, [k, "type"], :CT_UNKNOWN) == :CT_LVM
            DeleteLvmVg(Ops.get_string(tg, [k, "name"], ""))
          end
        elsif !Ops.get_boolean(tg, [k, "delete"], false)
          if Ops.get_symbol(tg, [k, "type"], :CT_UNKNOWN) == :CT_LVM &&
              Ops.greater_than(
                Builtins.size(Ops.get_list(target, [k, "devices_add"], [])),
                0
              )
            ls = Ops.get_list(target, [k, "devices_add"], [])
            Builtins.foreach(ls) do |d|
              ReduceLvmVg(Ops.get_string(target, [k, "name"], ""), d)
            end
          end
        end
      end
      keys = Builtins.maplist(target) { |k, e| k }
      keys = Builtins.sort(keys) do |a, b|
        Ops.greater_than(
          Ops.get(
            @type_order,
            Ops.get_symbol(target, [a, "type"], :CT_UNKNOWN),
            9
          ),
          Ops.get(
            @type_order,
            Ops.get_symbol(target, [b, "type"], :CT_UNKNOWN),
            9
          )
        )
      end
      Builtins.y2milestone("SetTargetMap keys %1", keys)
      Builtins.foreach(keys) do |k|
        dps = Builtins.filter(Ops.get_list(target, [k, "partitions"], [])) do |p|
          Ops.get_boolean(p, "delete", false)
        end
        if Ops.greater_than(Builtins.size(dps), 1) &&
            Builtins.haskey(Ops.get(dps, 0, {}), "nr")
          dps = Builtins.sort(dps) do |a, b|
            Ops.greater_than(
              Ops.get_integer(a, "nr", 0),
              Ops.get_integer(b, "nr", 0)
            )
          end
        end
        Builtins.foreach(dps) do |p|
          if Ops.greater_than(Builtins.size(Ops.get_string(p, "dtxt", "")), 0)
            ChangeDescText(
              Ops.get_string(p, "device", ""),
              Ops.get_string(p, "dtxt", "")
            )
          end
          DeleteDevice(Ops.get_string(p, "device", ""))
        end
        if Ops.get_boolean(target, [k, "delete"], false)
          if Ops.get_symbol(target, [k, "type"], :CT_UNKNOWN) == :CT_LVM
            DeleteLvmVg(Ops.get_string(target, [k, "name"], ""))
          elsif Ops.get_symbol(target, [k, "type"], :CT_UNKNOWN) == :CT_DISK ||
                Ops.get_symbol(target, [k, "type"], :CT_UNKNOWN) == :CT_DMMULTIPATH
            DeletePartitionTable(
              k,
              Ops.get_string(target, [k, "disklabel"], "")
            )
          elsif Ops.get_symbol(target, [k, "type"], :CT_UNKNOWN) == :CT_DMRAID
            DeleteDmraid(k)
          end
        end
        if Ops.get_boolean(target, [k, "del_ptable"], false) &&
            IsPartType(Ops.get_symbol(target, [k, "type"], :CT_UNKNOWN))
          DeletePartitionTable(k, Ops.get_string(target, [k, "disklabel"], ""))
        end
      end
      keys = Builtins.maplist(target) { |k, e| k }
      keys = Builtins.sort(keys) do |a, b|
        Ops.less_than(
          Ops.get(
            @type_order,
            Ops.get_symbol(target, [a, "type"], :CT_UNKNOWN),
            9
          ),
          Ops.get(
            @type_order,
            Ops.get_symbol(target, [b, "type"], :CT_UNKNOWN),
            9
          )
        )
      end
      Builtins.y2milestone("SetTargetMap keys %1", keys)
      Builtins.foreach(keys) do |k|
        if Ops.get_boolean(target, [k, "create"], false)
          if Ops.get_symbol(target, [k, "type"], :CT_UNKNOWN) == :CT_LVM
            CreateLvmVg(
              Ops.get_string(target, [k, "name"], ""),
              Ops.get_integer(target, [k, "pesize"], 0),
              Ops.get_boolean(target, [k, "lvm2"], true)
            )
            ls = Convert.convert(
              Builtins.union(
                Ops.get_list(target, [k, "devices"], []),
                Ops.get_list(target, [k, "devices_add"], [])
              ),
              :from => "list",
              :to   => "list <string>"
            )
            Builtins.foreach(ls) do |d|
              ExtendLvmVg(Ops.get_string(target, [k, "name"], ""), d)
            end
          end
        end
        if !Ops.get_boolean(target, [k, "delete"], false) &&
            !Ops.get_boolean(target, [k, "create"], false)
          if Ops.get_symbol(target, [k, "type"], :CT_UNKNOWN) == :CT_LVM &&
              Ops.greater_than(
                Builtins.size(Ops.get_list(target, [k, "devices_add"], [])),
                0
              )
            ls = Ops.get_list(target, [k, "devices_add"], [])
            Builtins.foreach(ls) do |d|
              ExtendLvmVg(Ops.get_string(target, [k, "name"], ""), d)
            end
          end
        end
        dps = Builtins.filter(Ops.get_list(target, [k, "partitions"], [])) do |p|
          !Ops.get_boolean(p, "delete", false) &&
            Ops.get_boolean(p, "create", false)
        end
        if dps.size>1
	  Builtins.y2milestone("SetTargetMap dps:\n%1", format_target_map(dps))
	  if dps.fetch(0,{}).has_key?("nr")
	    dps.sort! { |a, b| a.fetch("nr",0)<=>b.fetch("nr",0) }
	  elsif dps.fetch(0,{}).fetch("type",:none)==:lvm
	    dps = dps.partition { |a| a.fetch("pool",false) }
          end
	  Builtins.y2milestone("SetTargetMap dps:\n%1", format_target_map(dps))
        end
        Builtins.foreach(dps) do |p|
          p_ref = arg_ref(p)
          CreateAny(
            Ops.get_symbol(target, [k, "type"], :CT_UNKNOWN),
            Ops.get(target, k, {}),
            p_ref
          )
          p = p_ref.value
          tdev = Ops.get_string(p, "device", "")
          if Ops.get_symbol(p, "enc_type", :none) != :none &&
              !Builtins.isempty(Ops.get(save_crypt, tdev, "")) &&
              Builtins.isempty(GetCryptPwd(tdev))
            SetCryptPwd(tdev, Ops.get(save_crypt, tdev, ""))
          end
          if Ops.get_symbol(p, "type", :primary) != :extended
            ChangeVolumeProperties(p)
          end
        end
      end
      changed = !EqualBackupStates("tmp_set", "", true)
      Builtins.y2milestone("SetTargetMap changed: %1", changed)
      UpdateChangeTime() if changed
      DisposeTargetBackup("tmp_set")
      Builtins.y2milestone("SetTargetMap ChangeTime %1", GetTargetChangeTime())

      nil
    end

    # Rereads the system target map and returns it
    #
    # @return [Hash{String => map}] target map
    #
    # @see #GetTargetMap();
    def ReReadTargetMap
      need_reread = @sint != nil

      return nil if !InitLibstorage(false)

      Builtins.y2milestone("start reread need_reread: %1", need_reread)
      @probe_done = false
      @sint.rescanEverything() if need_reread
      @conts = getContainers
      GetTargetMap()
    end


    class MyCommitCallbacks < ::Storage::CommitCallbacks

      def initialize()
        super()
      end

      def post_root_filesystem_create()
        StorageSnapper::configure_snapper_step1()
      end

      def post_root_mount()
        StorageSnapper::configure_snapper_step2()
      end

      def post_root_fstab_add()
        StorageSnapper::configure_snapper_step3()
      end

    end


    # return list of missing packages in the running system
    def missing_packages
      used_features = Yast::StorageHelpers::UsedStorageFeatures.new(@sint)
      features = used_features.collect_features
      packages = used_features.feature_packages(features)
      packages = packages.delete_if { |package| Package.Installed(package) }
    end


    # Apply storage changes
    #
    # @return [Fixnum]
    def CommitChanges
      Builtins.y2milestone("CommitChanges")

      if Mode.installation && StorageSnapper.configure_snapper?
        my_commit_callbacks = MyCommitCallbacks.new()
        @sint.setCommitCallbacks(my_commit_callbacks)
      end

      if !Mode.installation
        packages = missing_packages
        if !packages.empty? && !Package.DoInstall(packages)
          # TODO: more informative error message, but the Package module does
          # not provide anything
          # TRANSLATORS: error popup
          text = _("Installing required packages failed.") + "\n" +
                 _("Continue despite the error?")
          if !Report.ErrorAnyQuestion(Popup.NoHeadline, text,
            Label.ContinueButton, Label.AbortButton, :focus_no)
            return -1
          end
        end
      end

      ret = @sint.commit()
      if ret<0
        Builtins.y2error("CommitChanges sint ret: %1", ret)
      end
      UpdateTargetMap()

      env = ENV["YAST2_STORAGE_SLEEP_AFTER_COMMIT"]
      SCR.Execute(path(".target.bash"), "sleep " + env) if env != nil

      ret
    end


    def DeviceMounted(dev)
      ret = ::Storage::ListString.new()
      @sint.checkDeviceMounted(dev, ret)
      if !ret.empty?
        Builtins.y2milestone("DeviceMounted %1 at %2", dev, ret.front())
      end
      if !ret.empty?
         ret.front()
      else
	 ""
      end
    end


    # Umounts a device
    #
    # @param string device name
    # @return [Boolean] if successful
    #
    # @see #Mount()
    def Umount(dev, unsetup)
      ret = @sint.umountDeviceUns(dev, unsetup)
      Builtins.y2milestone("Umount %1 unsetup %2 ret %3", dev, unsetup, ret)
      ret
    end


    # Mounts a device
    #
    # @param string device name
    # @param string mount point
    # @param [String] fstopt mount options
    # @return [Boolean] if successful
    #
    # @see #Umount()
    def MountOpt(dev, mp, fstopt)
      ret = @sint.mountDeviceRo(dev, mp, fstopt)
      Builtins.y2milestone(
        "MountOpt %1 to %2 with %3 ret %4",
        dev,
        mp,
        fstopt,
        ret
      )
      ret
    end


    # Mounts a device
    #
    # @param string device name
    # @param string mount point
    # @return [Boolean] if successful
    #
    # @see #Umount()
    def Mount(dev, mp)
      MountOpt(dev, mp, "")
    end


    def DetectHomeFs(p)
      p = deep_copy(p)
      Builtins.y2milestone("DetectHomeFs p: %1", p)
      ret = false
      poss_fs = [:ext2, :ext3, :ext4, :btrfs, :reiser, :xfs, :jfs]
      device = Ops.get_string(p, "device", "")
      if !Ops.get_boolean(p, "create", false) &&
          Builtins.contains(poss_fs, Ops.get_symbol(p, "detected_fs", :unknown)) &&
          !Builtins.isempty(device)
        resize_info = {}
        content_info = {}

        if (
            resize_info_ref = arg_ref(resize_info);
            content_info_ref = arg_ref(content_info);
            _GetFreeInfo_result = GetFreeInfo(
              device,
              false,
              resize_info_ref,
              true,
              content_info_ref,
              true
            );
            resize_info = resize_info_ref.value;
            content_info = content_info_ref.value;
            _GetFreeInfo_result
          ) &&
            Ops.greater_than(Ops.get_integer(content_info, :homes, 0), 0)
          ret = true
        end
      end
      Builtins.y2milestone("DetectHomeFs device: %1 ret: %2", device, ret)
      ret
    end


    # Adds the list of subvolumes to a partition meant to be used as root (/)
    #
    # If the partition is going to be formatted, it deletes all existing
    # subvolumes, leaving only the ones defined by this function.
    def AddSubvolRoot(part)
      part = deep_copy(part)

      subvol_names = [
        "home",
        "opt",
        "srv",
        "tmp",
        "usr/local",
        "var/cache",
        "var/crash",
        "var/lib/libvirt/images",
        "var/lib/mailman",
        "var/lib/mariadb",
        "var/lib/mysql",
        "var/lib/named",
        "var/lib/pgsql",
        "var/log",
        "var/opt",
        "var/spool",
        "var/tmp"
      ]

      # No Copy On Write for SQL databases and libvirt virtual disks to
      # minimize performance impact
      nocow_subvols = [
        "var/lib/libvirt/images",
        "var/lib/mariadb",
        "var/lib/mysql",
        "var/lib/pgsql"
      ]

      if Arch.i386 || Arch.x86_64
        subvol_names.push("boot/grub2/i386-pc")
      end

      if Arch.x86_64
        subvol_names.push("boot/grub2/x86_64-efi")
      end

      if Arch.ppc and !Arch.board_powernv
        subvol_names.push("boot/grub2/powerpc-ieee1275")
      end

      if Arch.s390
        subvol_names.push("boot/grub2/s390x-emu")
      end

      subvol_names.sort!()

      subvol_prepend = ""
      part["subvol"] ||= []
      Builtins.y2milestone("AddSubvolRoot subvol: %1", part["subvol"])
      if FileSystems.default_subvol != ""
        subvol_prepend = FileSystems.default_subvol+"/"
      end
      fmt = part.fetch("format",false)
      names = []
      if !fmt
        names = part["subvol"].select { |s| !s.fetch("delete", false) }.each { |s| s.fetch("name", "") }
      else
        part["subvol"] = []
      end
      Builtins.y2milestone("AddSubvolRoot subvol names: %1 subvol: %2", names, part["subvol"])
      subvol_names.each do |subvol|
        subvol_full_name = subvol_prepend + subvol
        if !names.include?( subvol_full_name )
          subvol_entry = { "create" => true, "name" => subvol_full_name }
          if nocow_subvols.include?( subvol )
            subvol_entry["nocow"] = true
            Builtins.y2milestone("AddSubvolRoot: NoCOW for %1", subvol_full_name)
          end
          part["subvol"].push(subvol_entry)
        end
      end
      Builtins.y2milestone("AddSubvolRoot subvol:\n%1", format_target_map(part["subvol"]))
      Builtins.y2milestone("AddSubvolRoot part: \n%1", format_target_map(part))
      part
    end


    def SetVolOptions(p, mnt, fs, fs_opts, fstab_opts, label)
      p = deep_copy(p)
      Builtins.y2milestone("SetVolOptions p: %1", p)
      Builtins.y2milestone(
        "SetVolOptions mount: %1 fs: %2 fs_opt: %3 fst_opt: %4 label: %5",
        mnt,
        fs,
        fs_opts,
        fstab_opts,
        label
      )
      ret = deep_copy(p)
      Ops.set(ret, "mount", mnt) if Ops.greater_than(Builtins.size(mnt), 0)
      if fs != nil && fs != :unknown
        Ops.set(ret, "used_fs", fs)
      else
        if mnt == Partitions.BootMount
          Ops.set(ret, "used_fs", Partitions.DefaultBootFs)
        else
          Ops.set(ret, "used_fs", Partitions.DefaultFs)
        end
      end
      if Ops.get_symbol(ret, "used_fs", :unknown) == :unknown ||
          Ops.get_symbol(ret, "used_fs", :unknown) == :none ||
          Ops.get_symbol(ret, "used_fs", :unknown) == :hfs ||
          Ops.get_symbol(ret, "used_fs", :unknown) == :hfsplus
        Ops.set(ret, "format", false)
      else
        Ops.set(ret, "format", true)
      end
      if Ops.get_boolean(ret, "format", false) &&
          !Ops.get_boolean(ret, "create", false) &&
          Ops.get_symbol(ret, "detected_fs", :unknown) != :unknown &&
          mnt == "/home"
        lvm = Ops.get_symbol(p, "type", :primary) == :lvm
        if lvm && Ops.get_string(ret, "name", "") == "home" ||
            !lvm && DetectHomeFs(ret)
          Ops.set(ret, "format", false)
          if Ops.get_symbol(ret, "used_fs", :unknown) !=
              Ops.get_symbol(ret, "detected_fs", :unknown)
            Ops.set(
              ret,
              "used_fs",
              Ops.get_symbol(ret, "detected_fs", :unknown)
            )
            fstab_opts = FileSystems.DefaultFstabOptions(ret)
          end
        end
      end
      if Ops.get_boolean(ret, "format", false) &&
          !Ops.get_boolean(ret, "create", false) &&
          Ops.get_symbol(ret, "detected_fs", :unknown) == :vfat &&
          Ops.get_integer(ret, "fsid", 0) == Partitions.fsid_gpt_boot &&
          mnt == Partitions.BootMount
        Ops.set(ret, "format", false)
      end
      if Ops.get_boolean(ret, "format", false) &&
          !Ops.get_boolean(ret, "create", false) &&
          Ops.get_symbol(ret, "detected_fs", :unknown) == :swap &&
          mnt == "swap"
        Ops.set(ret, "format", false)
        Ops.set(ret, "used_fs", :swap)
      end
      if Ops.get_symbol(ret, "used_fs", :unknown) == :btrfs && mnt == "/"
        ret = AddSubvolRoot(ret)
      end
      if Ops.greater_than(Builtins.size(fstab_opts), 0)
        Ops.set(ret, "fstopt", fstab_opts)
      else
        Ops.set(ret, "fstopt", FileSystems.DefaultFstabOptions(ret))
      end

      if Ops.greater_than(Builtins.size(fs_opts), 0)
        Ops.set(
          ret,
          "fs_options",
          convertStringToFsOptionMap(
            fs_opts,
            Ops.get_symbol(ret, "used_fs", :unknown),
            :mkfs
          )
        )
      else
        Ops.set(ret, "fs_options", FileSystems.DefaultFormatOptions(ret))
      end

      if Ops.greater_than(Builtins.size(label), 0)
        Ops.set(ret, "label", label)
      elsif Ops.greater_than(Builtins.size(Ops.get_string(ret, "label", "")), 0) &&
          Ops.get_boolean(ret, "format", false)
        Ops.set(ret, "label", "")
      end

      Builtins.y2milestone("SetVolOptions ret: \n%1", format_target_map(ret))
      deep_copy(ret)
    end


    def FindBtrfsUuid(uuid)
      btrfs = Ops.get(GetTargetMap(), "/dev/btrfs", {})
      ret = Ops.get(
        Builtins.filter(Ops.get_list(btrfs, "partitions", [])) do |p|
          Ops.get_string(p, "uuid", "") == uuid
        end,
        0,
        {}
      )
      Builtins.y2milestone("FindBtrfsUuid uuid: %1 ret: %2", uuid, ret)
      deep_copy(ret)
    end


    def IsUsedBy(p)
      p = deep_copy(p)
      ret = !Builtins.isempty(Ops.get_list(p, "used_by", []))
      if ret && Ops.get_symbol(p, ["used_by", 0, "type"], :UB_NONE) == :UB_BTRFS
        b = FindBtrfsUuid(Ops.get_string(p, ["used_by", 0, "device"], ""))
        if Ops.less_or_equal(Builtins.size(Ops.get_list(b, "devices", [])), 1)
          ret = false
        end
      end
      Builtins.y2milestone(
        "IsUsedBy %1 by %2 ret: %3",
        Ops.get_string(p, "device", ""),
        Ops.get_list(p, "used_by", []),
        ret
      )
      ret
    end


    # Tries to umount given device if mounted
    #
    # @param [String] device to umount
    # @return [Boolean] if successful
    def TryUnaccessSwap(device)
      ret = Builtins.isempty(DeviceMounted(device))
      ret = Umount(device, true) if !ret && Mode.live_installation
      Builtins.y2milestone("TryUnaccessSwap device %1 ret: %2", device, ret)
      ret
    end


    def CanCreate(disk, verbose)

      ret = true

      if ret && IsUsedBy(disk)
        if verbose
          # TRANSLATORS: error popup
          txt = _("The disk is in use and cannot be modified.")
          Popup.Message(txt)
        end
        ret = false
      end

      if ret && disk.fetch("label", "") == "dasd"
        if disk.fetch("partitions", []).any? do |partition|
            !DeviceMounted(partition["device"]).empty? || IsUsedBy(partition)
          end
          if verbose
            # TRANSLATORS: error popup
            txt = _("Partitions cannot be created since other partitions on the disk are used.")
            Popup.Message(txt)
          end
          ret = false
        end
      end

      log.info("CanCreate device:#{disk["device"]} verbose:#{verbose} ret:#{ret}")

      return ret

    end


    def CanEdit(p, verbose)
      p = deep_copy(p)
      ret = true
      if Stage.initial
        if !Ops.get_boolean(p, "create", false) &&
            !Ops.get_boolean(p, "inactive", false) &&
            Ops.get_string(p, "mount", "") == "swap"
          ret = false
          ret = TryUnaccessSwap(Ops.get_string(p, "device", "")) if verbose
          Builtins.y2milestone("CanEdit ret: %1 p: %2", ret, p)
          if verbose && !ret
            txt = Builtins.sformat(
              _(
                "\n" +
                  "Device %1 cannot be modified because it contains activated swap\n" +
                  "that is needed to run the installation.\n"
              ),
              Ops.get_string(p, "device", "")
            )
            Popup.Message(txt)
          end
        end
        if IsInstallationSource(Ops.get_string(p, "device", ""))
          ret = false
          if verbose
            txt = Builtins.sformat(
              _(
                "\n" +
                  "Device %1 cannot be modified because it contains the installation\n" +
                  "data needed to perform the installation.\n"
              ),
              Ops.get_string(p, "device", "")
            )
            Popup.Message(txt)
          end
        end
      end

      log.info("CanEdit device:#{p["device"]} verbose:#{verbose} ret:#{ret}")

      return ret
    end


    def CanDelete(p, disk, verbose)
      p = deep_copy(p)
      disk = deep_copy(disk)
      txt = ""
      ret = CanEdit(p, false)
      if !ret && verbose && Ops.get_string(p, "mount", "") == "swap"
        ret = TryUnaccessSwap(Ops.get_string(p, "device", ""))
      end
      if !ret && verbose
        if Ops.get_string(p, "mount", "") == "swap"
          txt = Builtins.sformat(
            _(
              "\n" +
                "Device %1 cannot be removed because it contains activated swap\n" +
                "that is needed to run the installation.\n"
            ),
            Ops.get_string(p, "device", "")
          )
        else
          txt = Builtins.sformat(
            _(
              "\n" +
                "Device %1 cannot be removed because it contains the installation\n" +
                "data needed to perform the installation.\n"
            ),
            Ops.get_string(p, "device", "")
          )
        end
        Popup.Message(txt)
      end
      if ret &&
          (Ops.get_symbol(p, "type", :unknown) == :logical ||
            Ops.get_symbol(p, "type", :unknown) == :extended)
        num = Ops.get_symbol(p, "type", :unknown) == :extended ?
          4 :
          Ops.get_integer(p, "nr", 4)
        pl = Builtins.filter(Ops.get_list(disk, "partitions", [])) do |q|
          Ops.get_symbol(q, "type", :unknown) == :logical &&
            Ops.greater_than(Ops.get_integer(q, "nr", 0), num)
        end
        Builtins.y2milestone("CanDelete pl: %1", pl)
        pos = 0
        while ret && Ops.less_than(pos, Builtins.size(pl))
          ret = CanEdit(Ops.get(pl, pos, {}), false)
          pos = Ops.add(pos, 1) if ret
        end
        if !ret && verbose
          if Ops.get_string(p, "mount", "") == "swap"
            txt = Builtins.sformat(
              _(
                "\n" +
                  "Device %1 cannot be removed because this would indirectly change\n" +
                  "device %2, which contains activated swap that is needed to run \n" +
                  "the installation.\n"
              ),
              Ops.get_string(p, "device", ""),
              Ops.get_string(pl, [pos, "device"], "")
            )
          else
            txt = Builtins.sformat(
              _(
                "\n" +
                  "Device %1 cannot be removed because this would indirectly change\n" +
                  "device %2, which contains data needed to perform the installation.\n"
              ),
              Ops.get_string(p, "device", ""),
              Ops.get_string(pl, [pos, "device"], "")
            )
          end
          Popup.Message(txt)
        end
      end

      # the check for verbose is needed for calls from StorageProposal (see bnc#871779)
      if ret && disk.fetch("label", "") == "dasd" && verbose
        if disk.fetch("partitions", []).any? do |partition|
            Ops.get_string(partition, "device", "") !=
              Ops.get_string(p, "device", "") &&
              !DeviceMounted(partition["device"]).empty? || IsUsedBy(partition)
          end
          if verbose
            txt = Builtins.sformat(
              _(
                "\n" +
                  "Partition %1 cannot be removed since other partitions on the\n" +
                  "disk %2 are used.\n"
                ),
              Ops.get_string(p, "device", ""),
              Ops.get_string(disk, "device", "")
            )
          Popup.Message(txt)
          end
          ret = false
        end
      end

      log.info("CanDelete device:#{p["device"]} verbose:#{verbose} ret:#{ret}")

      return ret
    end


    # Reads and returns fstab from directory
    #
    # FIXME: please, add description of the list that is returned by this function.
    #
    #
    # **Structure:**
    #
    #     [...unknown...]
    #
    # @param string directory
    # @return [Array] fstab?
    def ReadFstab(dir)
      ret = []
      vinfos = ::Storage::DequeVolumeInfo.new()
      r = @sint.readFstab(dir, vinfos)
      if !r
        Builtins.y2error("ReadFstab sint dir %1 ret %2", dir, r)
      else
        vinfos.each do |info|
          p = {}
          p = volumeMap(info, p)
          ret = Builtins.add(ret, p)
        end
      end
      Builtins.y2milestone("ReadFstab from %1 ret %2", dir, ret)
      ret
    end

    def mountedPartitionsOnDisk(disk)
      d = GetDisk(GetTargetMap(), disk)
      ret = Builtins.filter(Ops.get_list(d, "partitions", [])) do |p|
        Ops.greater_than(
          Builtins.size(DeviceMounted(Ops.get_string(p, "device", ""))),
          0
        )
      end
      deep_copy(ret)
    end


    # FIXME: please, add description of the list that is returned by this function.
    def GetCommitInfos
      infos = ::Storage::ListCommitInfo.new()
      @sint.getCommitInfos(infos)
      ret = []
      infos.each do |info|
        m = {
          :destructive => info.destructive,
          :text => info.text.force_encoding("UTF-8")
        }
	ret.push(m)
      end
      ret
    end


    def ChangeText
      texts = Builtins.maplist(GetCommitInfos()) do |info|
        text = String.EscapeTags(Ops.get_string(info, :text, ""))
        if Ops.get_boolean(info, :destructive, false)
          text = HTML.Colorize(text, "red")
        end
        text
      end

      ret = Builtins.isempty(texts) ? "" : HTML.List(texts)

      if Stage.initial && Builtins.isempty(GetEntryForMountpoint("/"))
        wroot = Ops.add(
          Ops.add(_("Nothing assigned as root filesystem!"), HTML.Newline),
          _("Installation will most certainly fail fatally!")
        )
        ret = Ops.add(ret, HTML.Para(HTML.Colorize(wroot, "red")))
      end

      if ret != @save_chtxt
        @sint.dumpObjectList()
        @sint.dumpCommitInfos()
      end

      ret
    end


    def LastAction
      return @sint.getLastAction().force_encoding("UTF-8")
    end


    def ExtendedErrorMsg
      return @sint.getExtendedErrorMessage().force_encoding("UTF-8")
    end


    def SetZeroNewPartitions(val)
      Builtins.y2milestone("SetZeroNewPartitions val: %1", val)
      @sint.setZeroNewPartitions(val)

      nil
    end


    def SetPartitionAlignment(pal)
      Builtins.y2milestone("SetPartitionAlignment val: %1", pal)
      val = fromSymbol(@conv_partalign, pal)
      @sint.setPartitionAlignment(val)

      nil
    end


    def GetPartitionAlignment
      val = @sint.getPartitionAlignment()
      pal = toSymbol(@conv_partalign, val)
      Builtins.y2milestone("GetPartitionAlignment val: %1", pal)
      pal
    end


    # GetMountPoints()
    # collect mountpoint:device as map to get a sorted list
    #
    # @return [Hash] of lists, the map key is the mount point,
    #		usually starting with a "/". Exception is "swap"
    #	For directory mount points (key starting with /) the value
    #  is a list [partitionName, fsid, targetdevice, raid_type]
    #  For swap mount points, the value is a list of lists:
    #  [[partitionName, fsid, targetdevice, raid_type], ...]
    #
    # FIXME: please, add more detailed description of the 'map of lists'
    # with examples if possible.
    #
    #
    # **Structure:**
    #
    #     $[ [...], [...], ... ]
    def GetMountPoints
      mountPoints = {}
      swapPoints = []
      tg = GetTargetMap()
      Builtins.foreach(tg) do |targetdevice, target|
        partitions = Ops.get_list(target, "partitions", [])
        Builtins.foreach(partitions) do |partition|
          partitionName = Ops.get_string(partition, "device", "")
          mountPoint = Ops.get_string(partition, "mount", "")
          fsid = Ops.get_integer(partition, "fsid", 0)
          if mountPoint != ""
            raid_type = ""
            if Ops.get_symbol(partition, "type", :undefined) == :sw_raid
              raid_type = Ops.get_string(partition, "raid_type", "")
            end
            # partition has a mount point
            if mountPoint == "swap"
              swapPoints = Builtins.add(
                swapPoints,
                [partitionName, fsid, targetdevice, raid_type]
              )
            else
              mountPoints = Builtins.add(
                mountPoints,
                mountPoint,
                [partitionName, fsid, targetdevice, raid_type]
              )
            end
          end
        end
      end
      if Ops.greater_than(Builtins.size(swapPoints), 0)
        mountPoints = Builtins.add(mountPoints, "swap", swapPoints)
      end
      if !Stage.initial
        cm = Builtins.filter(Partitions.CurMounted) do |e|
          Builtins.search(Ops.get_string(e, "spec", ""), "/dev/") == 0
        end
        Builtins.foreach(cm) do |e|
          if !Builtins.haskey(mountPoints, Ops.get_string(e, "file", ""))
            p = GetPartition(tg, Ops.get_string(e, "spec", ""))
            if Ops.greater_than(Builtins.size(p), 0)
              raid_type = ""
              if Ops.get_symbol(p, "type", :undefined) == :sw_raid
                raid_type = Ops.get_string(p, "raid_type", "")
              end
              d = GetDiskPartition(Ops.get_string(e, "spec", ""))
              Ops.set(
                mountPoints,
                Ops.get_string(e, "file", ""),
                [
                  Ops.get_string(p, "device", ""),
                  Ops.get_integer(p, "fsid", 0),
                  Ops.get_string(d, "disk", ""),
                  raid_type
                ]
              )
            end
          end
        end
      end
      Builtins.y2milestone("ret %1", mountPoints)
      deep_copy(mountPoints)
    end


    # Set <key> in partition <device> to the given <value> and return changed map <tg>
    #
    # @param [Hash{String => map}] tg
    # @param [String] device name
    # @string key
    # @string value
    # @return [Hash{String => map}] changed target map
    def SetPartitionData(tg, device, key, value)
      tg = deep_copy(tg)
      value = deep_copy(value)
      Builtins.y2milestone(
        "SetPartitionData device=%1 key=%2 value=%3",
        device,
        key,
        value
      )
      tmp = Ops.get(GetDiskPartitionTg(device, tg), 0, {})
      disk = Ops.get_string(tmp, "disk", "")
      dev = GetDeviceName(
        Ops.get_string(tmp, "disk", ""),
        Ops.get(tmp, "nr", 0)
      )
      Ops.set(
        tg,
        [disk, "partitions"],
        Builtins.maplist(Ops.get_list(tg, [disk, "partitions"], [])) do |p|
          Ops.set(p, key, value) if Ops.get_string(p, "device", "") == dev
          deep_copy(p)
        end
      )
      deep_copy(tg)
    end


    # remove <key> in partition <device> and return changed map <tg>
    def DelPartitionData(tg, device, key)
      tg = deep_copy(tg)
      Builtins.y2debug("device=%1, key=%2", device, key)
      tmp = Ops.get(GetDiskPartitionTg(device, tg), 0, {})
      disk = Ops.get_string(tmp, "disk", "")
      dev = GetDeviceName(
        Ops.get_string(tmp, "disk", ""),
        Ops.get(tmp, "nr", 0)
      )
      Ops.set(
        tg,
        [disk, "partitions"],
        Builtins.maplist(Ops.get_list(tg, [disk, "partitions"], [])) do |p|
          if Ops.get_string(p, "device", "") == dev
            p = Builtins.filter(
              Convert.convert(p, :from => "map", :to => "map <string, any>")
            ) { |k, e| k != key }
          end
          deep_copy(p)
        end
      )
      deep_copy(tg)
    end


    # Check if a disk is a real disk and not RAID or LVM
    #
    # @param [Hash] entry (disk)
    # @return [Boolean] true if real disk
    #
    #
    # **Structure:**
    #
    #     entry ~ $[
    #        "type":`CT_DISK,
    #        "driver" : "?",
    #        "readonly" : false / true,
    #      ]
    def IsRealDisk(entry)
      entry = deep_copy(entry)
      Ops.get_symbol(entry, "type", :CT_UNKNOWN) == :CT_DISK &&
        !(Ops.get_symbol(entry, "type", :CT_UNKNOWN) == :CT_DISK &&
          Ops.get_boolean(entry, "readonly", false) &&
          Ops.get_string(entry, "driver", "") == "vbd")
    end


    # Checks if a container is partitionable
    #
    # @param [Hash] entry
    # @return [Boolean] true if partitionable
    #
    #
    # **Structure:**
    #
    #     entry ~ $[ "type" : ... ? ]
    def IsPartitionable(entry)
      entry = deep_copy(entry)
      Ops.get_symbol(entry, "type", :CT_UNKNOWN) == :CT_DMRAID ||
        Ops.get_symbol(entry, "type", :CT_UNKNOWN) == :CT_DMMULTIPATH ||
        Ops.get_symbol(entry, "type", :CT_UNKNOWN) == :CT_MDPART ||
        IsRealDisk(entry)
    end


    def DeviceRealDisk(device)
      ret = false

      if Builtins.search(device, "LABEL") != 0 &&
          Builtins.search(device, "UUID") != 0
        dev = {}
        dev = GetDiskPartition(device)
        ret = Ops.get_string(dev, "disk", "") != "/dev/md" &&
          Ops.get_string(dev, "disk", "") != "/dev/loop" &&
          Builtins.search(Ops.get_string(dev, "disk", ""), "/dev/evms") != 0 &&
          Ops.is_integer?(Ops.get(dev, "nr", 0))
        if !ret && Ops.get_string(dev, "disk", "") != "/dev/md"
          st = Convert.to_map(
            SCR.Read(path(".target.stat"), Ops.get_string(dev, "disk", ""))
          )
          ret = !Ops.get_boolean(st, "isdir", false)
        end
      end
      Builtins.y2milestone("DeviceRealDisk %1 ret %2", device, ret)
      ret
    end


    #**
    # Determine if there is any Linux partition on this system.
    #
    # If there is none, we don't need to ask if the user wants to update or
    # boot an installed system - he can only do a new installation anyway.
    # No time-consuming or dangerous operations should be performed here,
    # only simple checks for existence of a Linux (type 83) partition.
    #
    # @return boolean true if there is anything that might be a Linux partition
    #
    def HaveLinuxPartitions
      ret = false
      Builtins.foreach(GetTargetMap()) do |dev, disk|
        if !ret
          Builtins.y2milestone(
            "HaveLinuxPartitions %1 typ: %2 pbl: %3 ro: %4 driver: %5",
            dev,
            Ops.get_symbol(disk, "type", :CT_UNKNOWN),
            IsPartitionable(disk),
            Ops.get_boolean(disk, "readonly", false),
            Ops.get_string(disk, "driver", "")
          )
          if IsPartitionable(disk)
            Builtins.foreach(Ops.get_list(disk, "partitions", [])) do |e|
              ret = ret ||
                Partitions.IsLinuxPartition(
                  Ops.get_integer(e, "fsid", Partitions.fsid_native)
                )
            end
          elsif Ops.get_symbol(disk, "type", :CT_UNKNOWN) == :CT_DISK &&
              Ops.get_boolean(disk, "readonly", false) &&
              Ops.get_string(disk, "driver", "") == "vbd"
            ret = true
          end
        end
      end
      Builtins.y2milestone("HaveLinuxPartitions ret=%1", ret)
      ret
    end


    # Get list of all Linux Partitions on all real disks
    # @return [Array] Partition list
    def GetOtherLinuxPartitions
      ret = []
      Builtins.foreach(GetTargetMap()) do |dev, disk|
        if IsPartitionable(disk)
          l = Builtins.filter(Ops.get_list(disk, "partitions", [])) do |p|
            !Ops.get_boolean(p, "format", false) &&
              Partitions.IsLinuxPartition(Ops.get_integer(p, "fsid", 0))
          end
          l = Builtins.filter(l) do |p|
            Builtins.contains(
              [:xfs, :ext2, :ext3, :ext4, :btrfs, :jfs, :reiser],
              Ops.get_symbol(p, "used_fs", :unknown)
            )
          end
          l = Builtins.filter(l) do |p|
            !FileSystems.IsSystemMp(Ops.get_string(p, "mount", ""), false)
          end
          ret = Builtins.union(ret, l) if Ops.greater_than(Builtins.size(l), 0)
        end
      end
      Builtins.y2milestone("GetOtherLinuxPartitions ret=%1", ret)
      deep_copy(ret)
    end


    # Check if swap paritition is availbe on a disk
    # @param [String] disk Disk to be checked
    # @return [Boolean] true if swap available.
    def CheckSwapOn(disk)
      swaps = SwappingPartitions()
      ret = Builtins.contains(SwappingPartitions(), disk)
      Builtins.y2milestone("CheckSwapOn disk: %1 ret: %2", disk, ret)
      ret
    end


    # Returns list of primary partitions found
    #
    # @param [Hash{String => map}] targets
    # @param [Boolean] foreign_os
    # @return [Array] of primary partitions
    def GetPrimPartitions(targets, foreign_os)
      targets = deep_copy(targets)
      ret = []
      num_dos = 0
      num_win = 0
      num_os2 = 0
      num_linux = 0
      linux_text = "Linux other"
      dos_text = "dos"
      win_text = "windows"
      os2_text = "OS/2 Boot Manager"

      Builtins.foreach(targets) do |disk, data|
        Builtins.foreach(Ops.get_list(data, "partitions", [])) do |part|
          device = Ops.get_string(part, "device", "")
          if Ops.get_symbol(part, "type", :unknown) == :primary &&
              !Ops.get_boolean(part, "create", false) &&
              SCR.Execute(
                path(".target.bash"),
                Ops.add("/usr/lib/YaST2/bin/check.boot ", device)
              ) == 0
            text = ""
            if Partitions.IsDosWinNtPartition(Ops.get_integer(part, "fsid", 0)) &&
                !IsUsedBy(data)
              resize_info = {}
              content_info = {}

              if (
                  resize_info_ref = arg_ref(resize_info);
                  content_info_ref = arg_ref(content_info);
                  _GetFreeInfo_result = GetFreeInfo(
                    device,
                    false,
                    resize_info_ref,
                    true,
                    content_info_ref,
                    true
                  );
                  resize_info = resize_info_ref.value;
                  content_info = content_info_ref.value;
                  _GetFreeInfo_result
                ) &&
                  Ops.get_boolean(content_info, :windows, false)
                if Builtins.contains(
                    Partitions.fsid_dostypes,
                    Ops.get_integer(part, "fsid", 0)
                  )
                  num_dos = Ops.add(num_dos, 1)
                  text = dos_text
                else
                  num_win = Ops.add(num_win, 1)
                  text = win_text
                end
              end
            elsif Ops.get_integer(part, "fsid", 0) == 18 && !foreign_os
              text = "Vendor diagnostic"
            elsif Ops.get_integer(part, "fsid", 0) == 10
              text = os2_text
              num_os2 = Ops.add(num_os2, 1)
            elsif Ops.get_integer(part, "fsid", 0) == Partitions.fsid_native &&
                Builtins.size(Ops.get_string(part, "mount", "")) == 0 &&
                !foreign_os
              text = linux_text
              num_linux = Ops.add(num_linux, 1)
            end
            if !Builtins.isempty(text)
              entry = { "device" => device, "string" => text }
              Builtins.y2milestone("new entry %1", entry)
              ret = Builtins.add(ret, entry)
            end
          end
        end
      end
      Builtins.y2milestone(
        "GetPrimPartitions foreign_os: %5 num_linux %1 num_win %2 num_dos %3 num_os2 %4",
        num_linux,
        num_win,
        num_dos,
        num_os2,
        foreign_os
      )

      num = 1
      ret = Builtins.maplist(ret) do |entry|
        if Ops.get_string(entry, "string", "") == linux_text
          Ops.set(
            entry,
            "string",
            Ops.add(linux_text, Builtins.sformat(" %1", num))
          )
          num = Ops.add(num, 1)
        end
        deep_copy(entry)
      end if Ops.greater_than(
        num_linux,
        1
      )
      num = 1
      ret = Builtins.maplist(ret) do |entry|
        if Ops.get_string(entry, "string", "") == dos_text
          Ops.set(
            entry,
            "string",
            Ops.add(dos_text, Builtins.sformat(" %1", num))
          )
          num = Ops.add(num, 1)
        end
        deep_copy(entry)
      end if Ops.greater_than(
        num_dos,
        1
      )
      num = 1
      ret = Builtins.maplist(ret) do |entry|
        if Ops.get_string(entry, "string", "") == win_text
          Ops.set(
            entry,
            "string",
            Ops.add(win_text, Builtins.sformat(" %1", num))
          )
          num = Ops.add(num, 1)
        end
        deep_copy(entry)
      end if Ops.greater_than(
        num_win,
        1
      )
      num = 1
      ret = Builtins.maplist(ret) do |entry|
        if Ops.get_string(entry, "string", "") == os2_text
          Ops.set(
            entry,
            "string",
            Ops.add(os2_text, Builtins.sformat(" %1", num))
          )
          num = Ops.add(num, 1)
        end
        deep_copy(entry)
      end if Ops.greater_than(
        num_os2,
        1
      )
      Builtins.y2milestone("GetPrimPartitions ret %1", ret)
      deep_copy(ret)
    end


    def GetWinPrimPartitions(targets)
      targets = deep_copy(targets)
      ret = GetPrimPartitions(targets, true)
      Builtins.y2milestone("GetWinPrimPartitions ret %1", ret)
      deep_copy(ret)
    end


    def GetUsedFs
      return nil if !InitLibstorage(false)

      r = @sint.getAllUsedFs()
      ret = r.to_a
      Builtins.y2milestone( "GetUsedFs ret: %1", ret )
      ret
    end


    def SaveUsedFs
      Builtins.y2milestone("SaveUsedFs")
      SCR.Write(
        path(".sysconfig.storage.USED_FS_LIST"),
        Builtins.mergestring(GetUsedFs(), " ")
      )
      SCR.Write(path(".sysconfig.storage"), nil)

      nil
    end


    def AddPackageList
      packages = @hw_packages.dup # start with packages suggested by hwinfo

      used_features = Yast::StorageHelpers::UsedStorageFeatures.new(@sint)
      features = used_features.collect_features
      packages += used_features.feature_packages(features)

      log.info("AddPackageList(): packages: #{packages}")
      packages
    end


    # Takes care of selecting packages needed by storage
    # in installation
    # (replacement for HandlePackages in *_proposal clients)

    def HandleProposalPackages
      #Use PackagesProposal to ensure that package selection
      #does not get reset by this module (#433001)
      Yast.import "PackagesProposal"

      proposal_ID = "storage_proposal"
      pkgs = AddPackageList()

      #Set rather than Add, there might be some packs left over
      #from previous 'MakeProposal' we don't need now
      #This also covers the case when AddPackagesList returns [] or nil
      if !PackagesProposal.SetResolvables(proposal_ID, :package, pkgs)
        Builtins.y2error(
          "PackagesProposal::SetResolvables() for %1 failed",
          pkgs
        )
        Report.Error(
          Builtins.sformat(
            _("Adding the following resolvables failed: %1"),
            pkgs
          )
        )
      end

      SaveUsedFs() if Stage.initial
      Pkg.PkgSolve(true)

      nil
    end


    def GetForeignPrimary
      ret = []
      if Arch.i386 || Arch.ia64 || Arch.x86_64
        Builtins.foreach(GetPrimPartitions(GetTargetMap(), false)) do |e|
          ret = Builtins.add(
            ret,
            Builtins.sformat(
              "%1 %2",
              Ops.get_string(e, "device", ""),
              Ops.get_string(e, "string", "")
            )
          )
        end
      end
      Builtins.y2milestone("ret=%1", ret)
      deep_copy(ret)
    end


    # Returns whether a partition is resizable
    #
    # @param map partition
    # @return [Hash] resizable ?
    def IsResizable(part)
      part = deep_copy(part)
      ret = FileSystems.IsResizable(:unknown)
      if !Arch.s390 && Partitions.IsResizable(Ops.get_integer(part, "fsid", 0)) ||
          Ops.get_symbol(part, "type", :none) == :lvm
        if Ops.get_integer(part, "fsid", 0) == Partitions.fsid_swap
          ret = FileSystems.IsResizable(:swap)
        else
          if !(Ops.get_symbol(part, "type", :none) == :lvm &&
              Ops.get_symbol(part, "used_fs", :unknown) == :vfat)
            ret = FileSystems.IsResizable(
              Ops.get_symbol(part, "used_fs", :unknown)
            )
          end
        end
      end
      ret["device"] = (Partitions.IsResizable(part.fetch("fsid",0)) &&
                       !part.fetch("device","").start_with?("/dev/dasd")) ||
		      part.fetch("type",:none)==:lvm
      Builtins.y2milestone("IsResizable part: %1 ret: %2", part, ret)
      deep_copy(ret)
    end


    def FreeCylindersAroundPartition(device, free_before, free_after)
      r, free_before.value, free_after.value =
	@sint.freeCylindersAroundPartition(device)
      ret = r==0
      Builtins.y2milestone(
        "FreeCylindersAfterPartition ret: %1 free_before: %2 free_after: %3",
        ret,
        free_before.value,
        free_after.value
      )
      ret
    end


    def PathToDestdir(p)
      if Installation.scr_destdir != "/"
        p = Ops.add(Installation.scr_destdir, p)
      end
      p
    end


    # Adds an entry into the fstab
    #
    # @param map entry
    # @return [Fixnum] (0 and higher == OK, otherwise error)
    def AddFstabEntry(e)
      e = deep_copy(e)
      Builtins.y2milestone("AddFstabEntry entry: %1", e)
      ret = 0
      freq = Ops.get_integer(e, "freq", 0)
      passno = Ops.get_integer(e, "passno", 0)
      dev = Ops.get_string(e, "spec", "")
      m = Ops.get_string(e, "mount", "")
      vfs = Ops.get_string(e, "vfstype", "auto")
      opts = Ops.get_string(e, "mntops", "defaults")
      ret = @sint.addFstabEntry(dev, m, vfs, opts, freq, passno)
      Builtins.y2error("ret: %1 entry: %2", ret, e) if ret<0
      ret
    end


    def ActivateHld(val)
      Builtins.y2milestone("ActivateHld val: %1", val)
      @sint.activateHld(val)

      nil
    end


    def ActivateMultipath(val)
      Builtins.y2milestone("ActivateMultipath val: %1", val)
      @sint.activateMultipath(val)

      nil
    end


    def SetMultipathStartup(val)
      Builtins.y2milestone("SetMultipathStartup val: %1", val)
      if( @default_multipathing != val )
	  @default_multipathing = val
	  ActivateMultipath(val) if @sint
      end
      nil
    end


    def SpecialBootHandling(tg)
      tg = deep_copy(tg)
      have_ppc_boot = false
      Builtins.foreach(tg) do |dev, disk|
        dlabel = disk.fetch("label", "")
        disk.fetch("partitions",[]).each do |part|
          if !have_ppc_boot &&
             part.fetch("fsid", 0) == Partitions.FsidBoot(dlabel) &&
             part.fetch("mount","").empty? &&
             part.fetch("create",false)
            have_ppc_boot = true
          end
        end
      end
      Builtins.y2milestone( "SpecialBootHandling: ppc_boot: %1", have_ppc_boot)
      Builtins.foreach(tg) do |dev, disk|
        new_part = []
        dlabel = disk.fetch("label", "")
        disk.fetch("partitions",[]).each do |part|
          # convert a mount point of /boot to a 41 PReP boot partition
          if Partitions.PrepBoot &&
             part.fetch("mount","") == Partitions.BootMount &&
             !have_ppc_boot
            id = Partitions.FsidBoot(dlabel)
            part["format"]=false
            part["mount"]=""
            part["prep_install"]=true
            propose_new_fsid(part, id)
            Builtins.y2milestone( "SpecialBootHandling modified Prep part=%1", part)
          end
          if Arch.board_mac &&
             part.fetch("mount","") == Partitions.BootMount
            id = Partitions.fsid_mac_hfs
            part["mount"] = ""
            propose_new_fsid(part, id)
            part["used_fs"] = :hfs
            part["detected_fs"] = :hfs
            Builtins.y2milestone( "SpecialBootHandling modified hfs part=%1", part)
          end
          if Arch.ia64 &&
             part.fetch("mount","") == Partitions.BootMount
            id = Partitions.fsid_gpt_boot
            propose_new_fsid(part, id)
            if !part.fetch("create",false) &&
               part.fetch("detected_fs",:none)==:vfat
              part["format"] = false
            end
            Builtins.y2milestone( "SpecialBootHandling modified GPT boot part=%1", part)
          end
          if !Partitions.EfiBoot && (Arch.i386||Arch.x86_64) &&
            dlabel == "gpt" &&
             part.fetch("mount","") == Partitions.BootMount
            id = Partitions.fsid_bios_grub
            propose_new_fsid(part, id)
	    part["format"] = false
	    part["mount"] = ""
            Builtins.y2milestone( "SpecialBootHandling modified BIOS grub part=%1", part)
          end
          new_part.push(part)
        end
        Ops.set(tg, [dev, "partitions"], new_part)
      end
      deep_copy(tg)
    end


    def PerformLosetup(loop, format)
      crypt_ok = false
      pwd = Ops.get_string(loop.value, "passwd", "")
      device = Ops.get_string(loop.value, "partitionName", "")
      mdir = SaveDumpPath("tmp_mp")
      Builtins.y2milestone("PerformLosetup mdir: %1", mdir)
      if Ops.greater_or_equal(
          Convert.to_integer(SCR.Read(path(".target.size"), mdir)),
          0
        )
        SCR.Execute(path(".target.bash"), Ops.add("rm -f ", mdir))
      end
      SCR.Execute(path(".target.mkdir"), mdir)
      crypt_ok = SetCryptPwd(device, pwd) && SetCrypt(device, true, false) &&
        Mount(device, mdir)
      if crypt_ok
        vinfo = ::Storage::VolumeInfo.new()
        ret = @sint.getVolume(device, vinfo)
        if ret != 0
          Builtins.y2error(
            "PerformLosetup device: %1 not found (ret: %2)",
            device,
            ret
          )
          crypt_ok = false
        else
          Ops.set(
            loop.value,
            "loop_dev",
            Ops.add(
              "/dev/mapper/cr_",
              Builtins.substring(
                device,
                Ops.add(Builtins.findlastof(device, "/"), 1)
              )
            )
          )
          Builtins.y2milestone(
            "PerformLosetup crdev: %1",
            Ops.get_string(loop.value, "loop_dev", "")
          )
        end
        SCR.Execute(path(".target.bash"), Ops.add("umount ", mdir))
      end
      Builtins.y2milestone("PerformLosetup ret %1", crypt_ok)
      crypt_ok
    end


    # Detects a filesystem on a device
    #
    # @param [String] device name
    # @return [Symbol] filesystem
    def DetectFs(device)
      ret = :unknown
      Builtins.y2milestone("DetectFs: %1", device)
      vinfo = ::Storage::VolumeInfo.new()
      r = @sint.getVolume(device, vinfo)
      if r != 0
        Builtins.y2error("DetectFs device: %1 not found (ret: %2)", device, r)
      else
        curr = {}
        curr = volumeMap(vinfo, curr)
        ret = Ops.get_symbol(curr, "detected_fs", :unknown)
      end
      Builtins.y2milestone("DetectFs ret %1", ret)
      ret
    end


    def GetBootPartition(disk)
      ret = {}
      tg = GetTargetMap()
      ret = Ops.get(
        Builtins.filter(Ops.get_list(tg, [disk, "partitions"], [])) do |p|
          Ops.get_boolean(p, "boot", false)
        end,
        0,
        {}
      )
      Builtins.y2milestone("disk: %1 ret: %2", disk, ret)
      deep_copy(ret)
    end


    def HdToIseries(input)
      ret = input
      regex = "/dev/hd[a-z][0-9]*"
      if Builtins.regexpmatch(input, regex)
        ret = Ops.add("/dev/iseries/vd", Builtins.substring(ret, 7))
      end
      Builtins.y2milestone("HdToIseries input: %1 ret: %2", input, ret)
      ret
    end


    def SLES9PersistentDevNames(input)
      ret = input
      regex1 = "/dev/disk/by-id/.*"
      regex2 = "/dev/disk/by-path/.*"
      prefix = "scsi-"
      tmpdev = ""

      return input if Builtins.regexpmatch(input, ".*-part[0-9]*$")

      if Builtins.regexpmatch(input, ".*/by-id/(scsi|ccw|usb|ata)-.*$")
        return input
      end

      if Builtins.regexpmatch(input, regex1)
        if Builtins.regexpmatch(input, ".*/by-id/0X.{4}p?[0-9]?$")
          prefix = "ccw-"
        end
        tmpdev = Ops.add(
          Ops.add("/dev/disk/by-id/", prefix),
          Builtins.substring(input, Ops.add(Builtins.findlastof(input, "/"), 1))
        )
        Builtins.y2milestone("by id tmp %1", tmpdev)
        ret = tmpdev
      elsif Builtins.regexpmatch(input, regex2)
        tmpdev = input
        Builtins.y2milestone("by path tmp %1", tmpdev)
      end

      if Ops.greater_than(Builtins.size(tmpdev), 0)
        if Builtins.regexpmatch(tmpdev, ".*p[0-9]*$")
          ret = Builtins.regexpsub(tmpdev, "(.*)p([0-9]*)$", "\\1-part\\2")
        else
          ret = Builtins.regexpsub(
            tmpdev,
            "(.*[[:alpha:][:punct:]])([0-9]*)$",
            "\\1-part\\2"
          )
        end
      end
      Builtins.y2milestone(
        "SLES9PersistentDevNames input: %1 ret: %2",
        input,
        ret
      )
      ret
    end


    def HdDiskMap(input, diskmap)
      diskmap = deep_copy(diskmap)
      ret = input
      if IsKernelDeviceName(input)
        d = GetDiskPartition(input)
        if Builtins.haskey(diskmap, Ops.get_string(d, "disk", ""))
          ret = GetDeviceName(
            Ops.get_string(diskmap, Ops.get_string(d, "disk", ""), ""),
            Ops.get(d, "nr", 0)
          )
        end
      end
      Builtins.y2milestone("HdDiskMap input: %1 ret: %2", input, ret)
      ret
    end


    def BuildDiskmap(oldv)
      oldv = deep_copy(oldv)
      d = Convert.to_map(
        SCR.Read(
          path(".target.stat"),
          Ops.add(Installation.destdir, "/var/lib/hardware")
        )
      )
      Builtins.y2milestone(
        "BuildDiskmap oldv: %1 Vers: %2",
        oldv,
        @DiskMapVersion
      )
      Builtins.y2milestone(
        "dir: %1 d: %2",
        Ops.add(Installation.destdir, "/var/lib/hardware"),
        d
      )
      if Ops.get_boolean(d, "isdir", false) &&
          (oldv != @DiskMapVersion || Builtins.size(oldv) == 0)
        @DiskMap = {}
        cmd = ""
        cmd = Ops.add(
          Ops.add(
            Ops.add("LIBHD_HDDB_DIR=", Installation.destdir),
            "/var/lib/hardware "
          ),
          "hwinfo --verbose --map"
        )
        Builtins.y2milestone("BuildDiskmap cmd %1", cmd)
        bo = Convert.to_map(SCR.Execute(path(".target.bash_output"), cmd))
        Builtins.y2milestone("BuildDiskmap bo %1", bo)
        if Ops.get_integer(bo, "exit", 1) == 0 &&
            Ops.greater_than(Builtins.size(Ops.get_string(bo, "stdout", "")), 0)
          lines = Builtins.splitstring(Ops.get_string(bo, "stdout", ""), "\n")
          Builtins.foreach(lines) do |line|
            disks = Builtins.filter(Builtins.splitstring(line, " \t")) do |d2|
              Ops.greater_than(Builtins.size(d2), 0)
            end
            if Ops.greater_than(Builtins.size(disks), 1)
              index = 1
              while Ops.less_than(index, Builtins.size(disks))
                Ops.set(
                  @DiskMap,
                  Ops.get(disks, index, ""),
                  Ops.get(disks, 0, "")
                )
                index = Ops.add(index, 1)
              end
            end
          end
        end
        if Ops.get_integer(bo, "exit", 1) == 0
          @DiskMapVersion = deep_copy(oldv)
        else
          @DiskMapVersion = {}
        end
      end
      Builtins.y2milestone("BuildDiskmap DiskMap %1", @DiskMap)
      Builtins.y2milestone("BuildDiskmap DiskMapVersion %1", @DiskMapVersion)
      deep_copy(@DiskMap)
    end


    def TranslateDeviceDmraidToMdadm(device, mapping)
      ret = device
      mapping.each do |name, uuid|
        ret = ret.sub("/dev/disk/by-id/raid-" + name, "/dev/disk/by-id/md-uuid-" + uuid)
        ret = ret.sub("/dev/disk/by-id/dm-name-" + name, "/dev/disk/by-id/md-uuid-" + uuid)
        ret = ret.sub("/dev/disk/by-id/dm-uuid-DMRAID-" + name, "/dev/disk/by-id/md-uuid-" + uuid)
      end
      return ret
    end


    def GetTranslatedDevices(oldv, newv, names)
      oldv = deep_copy(oldv)
      newv = deep_copy(newv)
      names = deep_copy(names)
      Builtins.y2milestone("GetTranslatedDevices old: %1 new: %2", oldv, newv)
      Builtins.y2milestone("GetTranslatedDevices names %1", names)
      ret = deep_copy(names)
      dm = BuildDiskmap(oldv)
      ret = Builtins.maplist(ret) { |n| HdDiskMap(n, dm) } if Ops.greater_than(
        Builtins.size(dm),
        0
      )
      if (Ops.less_than(Ops.get_integer(oldv, "major", 0), 9) ||
          Ops.get_integer(oldv, "major", 0) == 9 &&
            Ops.get_integer(oldv, "minor", 0) == 0) &&
          Arch.board_iseries
        ret = Builtins.maplist(ret) { |n| HdToIseries(n) }
      end
      ret = Builtins.maplist(ret) { |n| SLES9PersistentDevNames(n) } if Ops.get_integer(
        oldv,
        "major",
        0
      ) == 9

      # convert dmraid names to mdadm names
      mapping = GetDmraidToMdadm()
      if !mapping.empty?
        ret.map! { |name| TranslateDeviceDmraidToMdadm(name, mapping) }
      end

      Builtins.y2milestone("GetTranslatedDevices ret %1", ret)
      deep_copy(ret)
    end


    def CallInsserv(on, name)
      Builtins.y2milestone("CallInsserv on: %1 name: %2", on, name)
      scrname = Ops.add("/etc/init.d/", name)
      if Ops.greater_than(SCR.Read(path(".target.size"), scrname), 0)
        cmd = "cd / && /sbin/insserv "
        cmd = Ops.add(cmd, "-r ") if !on
        cmd = Ops.add(cmd, scrname)
        Builtins.y2milestone("CallInsserv cmd %1", cmd)
        bo = Convert.to_map(SCR.Execute(path(".target.bash_output"), cmd))
        Builtins.y2milestone("CallInsserv bo %1", bo)
      end

      nil
    end


    def FinishInstall
      Builtins.y2milestone("FinishInstall initial: %1", Stage.initial)

      target_map = GetTargetMap()

      need_crypt = false
      need_md = false
      need_lvm = false
      need_dmraid = false
      need_dmmultipath = false

      Builtins.foreach(target_map) do |k, e|
        if Builtins.find(Ops.get_list(e, "partitions", [])) do |part|
            Ops.get_symbol(part, "enc_type", :none) != :none
          end != nil
          need_crypt = true
        end
        if Ops.get_symbol(e, "type", :CT_UNKNOWN) == :CT_MD &&
            !Builtins.isempty(Ops.get_list(e, "partitions", []))
          need_md = true
        end
        need_md = true if Ops.get_symbol(e, "type", :CT_UNKNOWN) == :CT_MDPART
        need_lvm = true if Ops.get_symbol(e, "type", :CT_UNKNOWN) == :CT_LVM
        if Ops.get_symbol(e, "type", :CT_UNKNOWN) == :CT_DMRAID
          need_dmraid = true
        end
        if Ops.get_symbol(e, "type", :CT_UNKNOWN) == :CT_DMMULTIPATH
          need_dmmultipath = true
        end
      end

      Builtins.y2milestone(
        "FinishInstall need crypto: %1 md: %2 lvm: %3 dmraid: %4 dmmultipath: %5",
        need_crypt,
        need_md,
        need_lvm,
        need_dmraid,
        need_dmmultipath
      )

      CallInsserv(need_md, "boot.md")
      CallInsserv(need_dmraid, "boot.dmraid")
      Service.Enable("multipathd") if need_dmmultipath

      Builtins.y2milestone("FinishInstall done")

      nil
    end


    def GetEntryForMountpoint(mp)
      partitions = []

      Builtins.foreach(GetTargetMap()) do |dev, disk|
        tmp = Builtins.filter(Ops.get_list(disk, "partitions", [])) do |part|
          Ops.get_string(part, "mount", "") == mp
        end
        partitions = Convert.convert(
          Builtins.union(partitions, tmp),
          :from => "list",
          :to   => "list <map>"
        )
      end

      Ops.get(partitions, 0, {})
    end


    def GetRootInitrdModules
      partition = GetEntryForMountpoint("/")
      Builtins.y2milestone("GetRootInitrdModules root partition %1", partition)

      tg = GetTargetMap()
      disk = {}
      Builtins.foreach(tg) do |k, d|
        if Builtins.size(disk) == 0 &&
            Builtins.find(Ops.get_list(d, "partitions", [])) do |p|
              !Ops.get_boolean(p, "delete", false) &&
                Ops.get_string(p, "device", "") ==
                  Ops.get_string(partition, "device", "")
            end != nil
          disk = deep_copy(d)
        end
      end
      Builtins.y2milestone(
        "GetRootInitrdModules disk %1",
        Builtins.haskey(disk, "partitions") ?
          Builtins.remove(disk, "partitions") :
          disk
      )

      initrdmodules = FileSystems.GetNeededModules(
        Ops.get_symbol(partition, "used_fs", :ext2)
      )

      if Ops.get_symbol(partition, "type", :unknown) == :sw_raid
        t = Ops.get_string(partition, "raid_type", "")
        if !Builtins.contains(initrdmodules, t)
          initrdmodules = Builtins.add(initrdmodules, t)
        end
      end
      if Ops.get_symbol(partition, "type", :unknown) == :lvm
        vgdevice = Builtins.substring(
          Ops.get_string(partition, "device", ""),
          5
        )
        vgdevice = Ops.add(
          "/dev/",
          Builtins.substring(vgdevice, 0, Builtins.findfirstof(vgdevice, "/"))
        )
        mod = Builtins.maplist(
          Builtins.filter(Ops.get_list(tg, ["/dev/md", "partitions"], [])) do |e|
            Ops.get_string(e, "used_by_device", "") == vgdevice
          end
        ) { |k| Ops.get_string(k, "raid_type", "") }
        Builtins.y2milestone("GetRootInitrdModules mod %1", mod)
        Builtins.foreach(mod) do |e|
          if Ops.greater_than(Builtins.size(e), 0) &&
              !Builtins.contains(initrdmodules, e)
            initrdmodules = Builtins.add(initrdmodules, e)
          end
        end
        if !Builtins.contains(initrdmodules, "dm_mod")
          initrdmodules = Builtins.add(initrdmodules, "dm_mod")
        end
      end
      if Ops.greater_than(Builtins.size(Ops.get_list(disk, "modules", [])), 0)
        Builtins.y2milestone(
          "adding disk modules %1",
          Ops.get_list(disk, "modules", [])
        )
        Builtins.foreach(Ops.get_list(disk, "modules", [])) do |m|
          if !Builtins.contains(initrdmodules, m)
            initrdmodules = Builtins.add(initrdmodules, m)
          end
        end
      end
      if Ops.greater_than(
          Builtins.size(Ops.get_string(disk, "driver_module", "")),
          0
        )
        m = Ops.get_string(disk, "driver_module", "")
        Builtins.y2milestone("adding driver modules %1", m)
        if !Builtins.contains(initrdmodules, m)
          initrdmodules = Builtins.add(initrdmodules, m)
        end
      end
      SCR.UnmountAgent(path(".proc.modules"))
      lmod = Convert.to_map(SCR.Read(path(".proc.modules")))
      Builtins.y2milestone("GetRootInitrdModules lmod: %1", lmod)
      if Ops.greater_than(Builtins.size(Ops.get_map(lmod, "edd", {})), 0)
        initrdmodules = Builtins.add(initrdmodules, "edd")
      end
      Builtins.y2milestone("GetRootInitrdModules ret %1", initrdmodules)
      deep_copy(initrdmodules)
    end


    def CheckForLvmRootFs
      part = GetEntryForMountpoint("/")
      ret = Ops.get_symbol(part, "type", :primary) == :lvm
      Builtins.y2milestone("CheckForLvmRootFs root: %1 ret: %2", part, ret)
      ret
    end


    def CheckForMdRootFs
      part = GetEntryForMountpoint("/")
      ret = Ops.get_symbol(part, "type", :primary) == :sw_raid
      Builtins.y2milestone("CheckForMdRootFs root: %1 ret: %2", part, ret)
      ret
    end


    def NumLoopDevices
      bo = Convert.to_map(WFM.Execute(path(".local.bash_output"), "losetup -a"))
      sl = Builtins.splitstring(Ops.get_string(bo, "stdout", ""), "\n")
      sl = Builtins.filter(sl) { |s| Builtins.search(s, "/dev/loop") == 0 }
      sl = Builtins.maplist(sl) do |s|
        Builtins.substring(s, 0, Builtins.search(s, ":"))
      end
      sl = Builtins.maplist(sl) { |s| Builtins.substring(s, 9) }
      il = Builtins.sort(Builtins.maplist(sl) { |s| Builtins.tointeger(s) })
      ret = Ops.add(Ops.get(il, Ops.subtract(Builtins.size(sl), 1), -1), 1)
      Builtins.y2milestone("NumLoopDevices ret: %1", ret)
      ret
    end


    #-----------------------------------------------------
    # convert partitions to fstab entries
    # return map (might be empty)
    def onepartition2fstab(part, other_nr)
      part = deep_copy(part)
      Builtins.y2milestone("onepartition2fstab part=%1", part)
      if Ops.get_boolean(part, "delete", false) ||
          Ops.get_symbol(part, "type", :unknown) == :extended ||
          Builtins.contains(
            [:lvm, :sw_raid, :evms],
            Ops.get_symbol(part, "type", :unknown)
          ) &&
            Builtins.size(Ops.get_string(part, "mount", "")) == 0 ||
          Ops.get_symbol(part, "enc_type", :none) != :none &&
            !Ops.get_boolean(part, "noauto", false) ||
          !IsUsedBy(part) ||
          Builtins.contains(
            [
              Partitions.fsid_prep_chrp_boot,
              Partitions.fsid_gpt_prep,
              Partitions.fsid_lvm,
              Partitions.fsid_raid
            ],
            Ops.get_integer(part, "fsid", 0)
          ) &&
            Builtins.size(Ops.get_string(part, "mount", "")) == 0
        return {}
      end

      spec = Ops.get_string(part, "device", "")
      if Ops.get_symbol(part, "mountby", :device) == :label &&
          Ops.greater_than(Builtins.size(Ops.get_string(part, "label", "")), 0)
        spec = Builtins.sformat("LABEL=%1", Ops.get_string(part, "label", ""))
      elsif Ops.get_symbol(part, "mountby", :device) == :uuid &&
          Ops.greater_than(Builtins.size(Ops.get_string(part, "uuid", "")), 0)
        spec = Builtins.sformat("UUID=%1", Ops.get_string(part, "uuid", ""))
      end
      Builtins.y2debug("onepartition2fstab spec=%1", spec)
      mount_point = Ops.get_string(part, "mount", "")
      fsid = Ops.get_integer(part, "fsid", 0)

      used_fs = Ops.get_symbol(part, "used_fs", :ext2)
      format = Ops.get_boolean(part, "format", false)

      vfstype = "unknown" # keep "unknown", used again below
      freq = 0
      passno = 0
      mntops = Ops.get_string(part, "fstopt", "")

      if mount_point == "swap"
        vfstype = "swap"
        if Builtins.isempty(mntops)
          mntops = Ops.get_string(
            FileSystems.GetFstabDefaultMap("swap"),
            "mntops",
            ""
          )
        end
        passno = 0
      elsif fsid == Partitions.fsid_native || fsid == Partitions.fsid_lvm ||
          Ops.get_symbol(part, "type", :unknown) == :evms &&
            Ops.get_symbol(part, "detected_fs", :none) != :unknown
        vfstype = FileSystems.GetMountString(used_fs, format ? "ext2" : "auto")

        freq = 1
        if mount_point == "/"
          passno = 1
        elsif mount_point != ""
          passno = 2
        elsif Stage.initial && !Arch.s390
          mount_point = Ops.add("/data", other_nr.value)
          # Don't mount and fsck this filesystem during boot, its
          # state is unknown.
          mntops = "noauto,user"
          vfstype = "auto"
          freq = 0
          passno = 0
          other_nr.value = Ops.add(other_nr.value, 1)
          Builtins.y2milestone("TT add MountPoint %1", mount_point)
        end
      elsif (Arch.i386 || Arch.ia64 || Arch.x86_64) &&
          Ops.greater_than(Builtins.size(mount_point), 0) &&
          (used_fs == :vfat || used_fs == :ntfs) &&
          (Builtins.contains(
            Builtins.union(
              Builtins.union(
                Partitions.fsid_dostypes,
                Partitions.fsid_ntfstypes
              ),
              Partitions.fsid_wintypes
            ),
            fsid
          ) ||
            fsid == Partitions.fsid_gpt_boot)
        freq = 0
        passno = 0
        lower_point = Builtins.tolower(mount_point)
        if lower_point != "" && mount_point != lower_point
          lower_point = PathToDestdir(lower_point)
          Builtins.y2milestone(
            "symlink %1 -> %2",
            Builtins.substring(
              mount_point,
              Ops.add(Builtins.findlastof(mount_point, "/"), 1)
            ),
            lower_point
          )
          SCR.Execute(
            path(".target.symlink"),
            Builtins.substring(
              mount_point,
              Ops.add(Builtins.findlastof(mount_point, "/"), 1)
            ),
            lower_point
          )
        end
        vfstype = FileSystems.GetMountString(used_fs, "auto")
      elsif (Arch.sparc || Arch.alpha) &&
          Builtins.contains(Partitions.fsid_skipped, fsid)
        return {} # skip "whole disk" partition
      else
        return {} # unknown type
      end
      if Ops.get_symbol(part, "detected_fs", :unknown) == :unknown ||
          Ops.get_boolean(part, "noauto", false)
        passno = 0
      end

      ret = {
        "spec"    => spec,
        "mount"   => mount_point,
        "vfstype" => vfstype,
        "mntops"  => mntops,
        "freq"    => freq,
        "device"  => Ops.get_string(part, "device", ""),
        "passno"  => passno
      }

      if Builtins.size(Ops.get_string(ret, "mntops", "")) == 0
        Ops.set(ret, "mntops", "defaults")
      end

      Builtins.y2milestone("onepartition2fstab ret=%1", ret)
      deep_copy(ret)
    end


    def AddHwPackages(names)
      names = deep_copy(names)
      Builtins.y2milestone(
        "AddHwPackages names: %1 list: %2",
        names,
        @hw_packages
      )
      @hw_packages = Convert.convert(
        Builtins.union(@hw_packages, names),
        :from => "list",
        :to   => "list <string>"
      )
      Builtins.y2milestone("AddHwPackages list: %1", @hw_packages)

      nil
    end


    def SwitchUiAutomounter(on)
      Builtins.y2milestone("SwitchUiAutomounter on: %1", on)

      begin

        system_bus = DBus::SystemBus.instance
        service = system_bus.service("org.freedesktop.UDisks")
        dbus_object = service.object("/org/freedesktop/UDisks")
        dbus_object.default_iface = "org.freedesktop.UDisks"
        dbus_object.introspect

        if !on
          @dbus_cookie = dbus_object.Inhibit().first
        else
          dbus_object.Uninhibit(@dbus_cookie)
          @dbus_cookie = nil
        end

      rescue Exception => e
        Builtins.y2error("SwitchUiAutomounter failed %1", e.message)

      end

      nil
    end


    def DumpObjectList
      return if !InitLibstorage(false)
      @sint.dumpObjectList()
      nil
    end


    def SetDefaultMountBy(mby)
      val = fromSymbol(@conv_mountby, mby)
      @sint.setDefaultMountBy(val)

      nil
    end


    def GetDefaultMountBy
      val = @sint.getDefaultMountBy()
      ret = toSymbol(@conv_mountby, val)
      ret
    end


    def GetMountBy(device)
      r, val = @sint.getMountBy(device)
      val = 0 if r<0
      ret = toSymbol(@conv_mountby, val)
      ret
    end


    def SaveDeviceGraph(filename)
      ret = ::Storage::saveDeviceGraph(@sint, filename)
      Builtins.y2milestone("SaveDeviceGraph filename: %1 ret: %2", filename, ret)
      ret
    end


    def SaveMountGraph(filename)
      ret = ::Storage::saveMountGraph(@sint, filename);
      Builtins.y2milestone("SaveMountGraph filename: %1 ret: %2", filename, ret)
      ret
    end


    def DeviceMatchFstab(device, fstab_spec)
      ret = false
      tg = GetTargetMap()
      ts = fstab_spec
      if DeviceNameMightNeedAdaption(fstab_spec)
        # translate fstab_spec from old to new kernel device name
        ts = Ops.get(GetTranslatedDevices({}, {}, [fstab_spec]), 0, "")
        if ts != fstab_spec
          Builtins.y2milestone(
            "DeviceMatchFstab translate %1 --> %2",
            fstab_spec,
            ts
          )
        end
      end
      pl = GetPartitionLst(tg, ts)
      ret = Builtins.find(pl) { |p| Ops.get_string(p, "device", "") == device } != nil
      Builtins.y2milestone(
        "DeviceMatchFstab device: %1 fstab: %2 ret: %3",
        device,
        fstab_spec,
        ret
      )
      ret
    end


    def IsPersistent(p)
      p = deep_copy(p)
      ret = Builtins.contains(
        [:lvm, :sw_raid, :dm],
        Ops.get_symbol(p, "type", :unknown)
      )
      if !ret &&
          Builtins.contains(
            [:primary, :logical, :extended],
            Ops.get_symbol(p, "type", :unknown)
          )
        d = GetDisk(GetTargetMap(), Ops.get_string(p, "device", ""))
        ret = Ops.get_symbol(d, "type", :CT_UNKNONW) == :CT_DMRAID ||
          Ops.get_symbol(d, "type", :CT_UNKNONW) == :CT_DMMULTIPATH ||
          Ops.greater_than(Builtins.size(Ops.get_list(d, "udev_id", [])), 0)
      end
      Builtins.y2milestone(
        "IsPersistent device: %1 ret: %2",
        Ops.get_string(p, "device", ""),
        ret
      )
      ret
    end


    def AllowedParity(mdtype, sz)
      mdt = Ops.get(@conv_mdstring, mdtype, 0)
      pars = @sint.getMdAllowedParity(mdt, sz)
      ret = []
      pars.each do |i|
        l = [toSymbol(@conv_mdparity, i), Ops.get(@rev_conv_parstring, i, "")]
	ret.push(l)
      end
      Builtins.y2milestone("ret: %1", ret)
      ret
    end


    def GetUsedDisks(device)
      Builtins.y2milestone("GetUsedDisks device: %1", device)
      ret = []
      tg = GetTargetMap()
      info = {}
      if ( info_ref = arg_ref(info);
          _GetContVolInfo_result = GetContVolInfo(device, info_ref);
          info = info_ref.value;
          _GetContVolInfo_result
        )
        Builtins.y2milestone("GetUsedDisks info: %1", info)
        to_visit = [device]
        visited_devs = []
        begin
          visited_devs = Builtins.add(visited_devs, Ops.get(to_visit, 0, ""))
          to_visit = Builtins.remove(to_visit, 0)
          add_list = []
          if Ops.get_symbol(info, "ctype", :CT_UNKNOWN) == :CT_DISK
            if !Builtins.contains(ret, Ops.get_string(info, "cdevice", ""))
              ret = Builtins.add(ret, Ops.get_string(info, "cdevice", ""))
            end
          elsif Ops.get_symbol(info, "ctype", :CT_UNKNOWN) == :CT_NFS
            ret = Builtins.add(ret, "/dev/nfs")
          elsif Ops.get_symbol(info, "ctype", :CT_UNKNOWN) == :CT_BTRFS
            bt = Builtins.find(
              Ops.get_list(tg, ["/dev/btrfs", "partitions"], [])
            ) do |p|
              Builtins.contains(
                Ops.get_list(p, "devices", []),
                Ops.get_string(info, "vdevice", "")
              )
            end
            Builtins.y2milestone("GetUsedDisks bt: %1", bt)
            add_list = Ops.get_list(bt, "devices", []) if bt != nil
          else
            add_list = Ops.get_list(
              tg,
              [Ops.get_string(info, "cdevice", ""), "devices"],
              []
            )
          end
          if Ops.greater_than(Builtins.size(add_list), 0)
            Builtins.y2milestone("GetUsedDisks add_list: %1", add_list)
          end
          Builtins.foreach(add_list) do |s|
            if !Builtins.contains(visited_devs, s) &&
                !Builtins.contains(to_visit, s) &&
                !Builtins.contains(ret, s)
              to_visit = Builtins.add(to_visit, s)
            end
          end
          Builtins.y2milestone("GetUsedDisks to_visit: %1", to_visit)
          while Ops.greater_than(Builtins.size(to_visit), 0) &&
              !(
                info_ref = arg_ref(info);
                _GetContVolInfo_result = GetContVolInfo(
                  Ops.get(to_visit, 0, ""),
                  info_ref
                );
                info = info_ref.value;
                _GetContVolInfo_result
              )
            visited_devs = Builtins.add(visited_devs, Ops.get(to_visit, 0, ""))
            to_visit = Builtins.remove(to_visit, 0)
          end
          if Ops.greater_than(Builtins.size(to_visit), 0)
            Builtins.y2milestone("GetUsedDisks info: %1", info)
          end
        end while Ops.greater_than(Builtins.size(to_visit), 0)
        ret = Builtins.sort(ret) if Ops.greater_than(Builtins.size(ret), 1)
      elsif Builtins.substring(device, 0, 1) != "/" &&
          Ops.greater_than(Builtins.search(device, ":"), 0)
        ret = ["/dev/nfs"]
      end
      Builtins.y2milestone("GetUsedDisks ret: %1", ret)
      deep_copy(ret)
    end


    def IsDeviceOnNetwork(device)
      ret = :no
      tg = GetTargetMap()

      disks = GetUsedDisks(device)
      if Ops.get(disks, 0, "") == "/dev/nfs"
        ret = :nfs
      else
        Builtins.foreach(disks) do |s|
          if ret == :no
            Builtins.y2milestone(
              "disk: %1 transport: %2",
              s,
              Ops.get_symbol(tg, [s, "transport"], :unknown)
            )
            if Builtins.contains(
                [:fcoe, :iscsi],
                Ops.get_symbol(tg, [s, "transport"], :unknown)
              )
              ret = Ops.get_symbol(tg, [s, "transport"], :unknown)
            end
          end
        end
      end
      Builtins.y2milestone("IsDeviceOnNetwork device: %1 ret: %2", device, ret)
      ret
    end


    def GetCreatedSwaps
      tg = GetTargetMap()
      ret = []
      Builtins.foreach(tg) do |k, d|
        ret = Builtins.union(
          ret,
          Builtins.filter(Ops.get_list(d, "partitions", [])) do |p|
            Ops.get_boolean(p, "create", false) &&
              Ops.get_string(p, "mount", "") == "swap"
          end
        )
      end
      deep_copy(ret)
    end


    def GetDetectedDiskPaths
      disks = ::Storage::getPresentDisks
      ret = disks.to_a
      Builtins.y2milestone("disks: %1", ret)
      ret
    end


    def GetDmraidToMdadm()
      mapping = {}
      tmp = ::Storage::DmraidToMdadm()
      tmp.each do |a, b|
        mapping[a] = b
      end
      Builtins.y2milestone("dmraid to mdadm mapping %1", mapping)
      return mapping
    end

    # Checks if activation of multipath has been explicitly disabled
    #
    # @return [Boolean]
    def multipath_off?
      @sint.getMultipathAutostart == ::Storage::MPAS_OFF
    end

  protected

    def skip_activation_popup?
      Mode.autoinst || Mode.autoupgrade || Installation.restarting?
    end

    def propose_new_fsid(part, id)
      if !part.fetch("create", false) && part.fetch("fsid", 0) != id
        part["ori_fsid"] = part.fetch("fsid", 0)
        part["change_fsid"] = true
      end
      part["fstype"] = Partitions.FsIdToString(id)
      part["fsid"] = id
    end

    publish :variable => :resize_partition, :type => "string"
    publish :variable => :resize_partition_data, :type => "map"
    publish :variable => :resize_cyl_size, :type => "integer"
    publish :function => :ReReadTargetMap, :type => "map <string, map> ()"
    publish :function => :IsKernelDeviceName, :type => "boolean (string)"
    publish :function => :InitLibstorage, :type => "boolean (boolean)"
    publish :function => :FinishLibstorage, :type => "void ()"
    publish :function => :ClassicStringToByte, :type => "integer (string)"
    publish :function => :ByteToHumanString, :type => "string (integer)"
    publish :function => :KByteToHumanString, :type => "string (integer)"
    publish :function => :ByteToHumanStringOmitZeroes, :type => "string (integer)"
    publish :function => :KByteToHumanStringOmitZeroes, :type => "string (integer)"
    publish :function => :HumanStringToByte, :type => "boolean (string, integer &)"
    publish :function => :HumanStringToKByte, :type => "boolean (string, integer &)"
    publish :function => :HumanStringToKByteWithRangeCheck, :type => "boolean (string, integer &, integer, integer)"
    publish :function => :GetDeviceName, :type => "string (string, any)"
    publish :function => :SetIgnoreFstab, :type => "boolean (string, boolean)"
    publish :function => :GetIgnoreFstab, :type => "boolean (string, boolean &)"
    publish :function => :GetContVolInfo, :type => "boolean (string, map <string, any> &)"
    publish :function => :GetTargetMap, :type => "map <string, map> ()"
    publish :function => :SetTargetMap, :type => "void (map <string, map>)"
    publish :function => :SetPartitionData, :type => "map <string, map> (map <string, map>, string, string, any)"
    publish :function => :DelPartitionData, :type => "map <string, map> (map <string, map>, string, string)"
    publish :function => :GetDiskPartition, :type => "map (string)"
    publish :function => :UpdateChangeTime, :type => "void ()"
    publish :function => :GetPartition, :type => "map <string, any> (map <string, map>, string)"
    publish :function => :GetDisk, :type => "map <string, any> (map <string, map>, string)"
    publish :function => :SwappingPartitions, :type => "list <string> ()"
    publish :function => :GetFreeInfo, :type => "boolean (string, boolean, map <symbol, any> &, boolean, map <symbol, any> &, boolean)"
    publish :function => :GetFreeSpace, :type => "map (string, symbol, boolean)"
    publish :function => :GetUnusedPartitionSlots, :type => "integer (string, list <map> &)"
    publish :function => :SaveDumpPath, :type => "string (string)"
    publish :function => :CheckBackupState, :type => "boolean (string)"
    publish :function => :HasRaidParity, :type => "boolean (string)"
    publish :function => :IsDiskType, :type => "boolean (symbol)"
    publish :function => :SaveExitKey, :type => "void (symbol)"
    publish :function => :GetExitKey, :type => "symbol ()"
    publish :function => :GetOndiskTarget, :type => "map <string, map> ()"
    publish :function => :CreateTargetBackup, :type => "void (string)"
    publish :function => :DisposeTargetBackup, :type => "void (string)"
    publish :function => :EqualBackupStates, :type => "boolean (string, string, boolean)"
    publish :function => :RestoreTargetBackup, :type => "void (string)"
    publish :function => :ResetOndiskTarget, :type => "void ()"
    publish :function => :GetTargetChangeTime, :type => "integer ()"
    publish :function => :GetPartProposalActive, :type => "boolean ()"
    publish :function => :SetPartProposalActive, :type => "void (boolean)"
    publish :function => :GetPartMode, :type => "string ()"
    publish :function => :SetPartMode, :type => "void (string)"
    publish :function => :GetCustomDisplay, :type => "boolean ()"
    publish :function => :SetCustomDisplay, :type => "void (boolean)"
    publish :function => :GetPartDisk, :type => "string ()"
    publish :function => :SetPartDisk, :type => "void (string)"
    publish :function => :GetTestsuite, :type => "boolean ()"
    publish :function => :SetTestsuite, :type => "void (boolean)"
    publish :function => :GetDoResize, :type => "string ()"
    publish :function => :SetDoResize, :type => "void (string)"
    publish :function => :GetPartProposalMode, :type => "string ()"
    publish :function => :SetPartProposalMode, :type => "void (string)"
    publish :function => :GetPartProposalFirst, :type => "boolean ()"
    publish :function => :SetPartProposalFirst, :type => "void (boolean)"
    publish :function => :GetWinDevice, :type => "boolean ()"
    publish :function => :SetWinDevice, :type => "void (boolean)"
    publish :function => :Storage, :type => "void ()"
    publish :function => :IsInstallationSource, :type => "boolean (string)"
    publish :function => :NextPartition, :type => "map <string, any> (string, symbol)"
    publish :function => :NextMd, :type => "map <string, any> ()"
    publish :function => :MaxCylLabel, :type => "integer (map, integer)"
    publish :function => :CreatePartition, :type => "boolean (string, string, symbol, integer, integer, integer, symbol)"
    publish :function => :UpdatePartition, :type => "boolean (string, integer, integer)"
    publish :function => :SetPartitionMount, :type => "boolean (string, string)"
    publish :function => :SetPartitionFormat, :type => "boolean (string, boolean, symbol)"
    publish :function => :SetPartitionId, :type => "boolean (string, integer)"
    publish :function => :UnchangePartitionId, :type => "boolean (string)"
    publish :function => :ResizePartition, :type => "boolean (string, string, integer)"
    publish :function => :ResizeVolume, :type => "boolean (string, string, integer)"
    publish :function => :SetCrypt, :type => "boolean (string, boolean, boolean)"
    publish :function => :GetMountBy, :type => "symbol (string)"
    publish :function => :ChangeVolumeProperties, :type => "boolean (map)"
    publish :function => :DeleteDevice, :type => "boolean (string)"
    publish :function => :DeleteLvmVg, :type => "boolean (string)"
    publish :function => :DeleteDmraid, :type => "boolean (string)"
    publish :function => :DeleteMdPartCo, :type => "boolean (string)"
    publish :function => :CreateLvmVg, :type => "boolean (string, integer, boolean)"
    publish :function => :CreateLvmVgWithDevs, :type => "boolean (string, integer, boolean, list <string>)"
    publish :function => :ExtendLvmVg, :type => "boolean (string, string)"
    publish :function => :ReduceLvmVg, :type => "boolean (string, string)"
    publish :function => :CreateLvmLv, :type => "boolean (string, string, integer, integer)"
    publish :function => :CreateLvmThin, :type => "boolean (string, string, string, integer)"
    publish :function => :ChangeLvStripeSize, :type => "boolean (string, string, integer)"
    publish :function => :ChangeLvStripeCount, :type => "boolean (string, string, integer)"
    publish :function => :CreateLvmPool, :type => "boolean (string, string, integer, integer)"
    publish :function => :ExtendBtrfsVolume, :type => "boolean (string, string)"
    publish :function => :ReduceBtrfsVolume, :type => "boolean (string, string)"
    publish :function => :AddNfsVolume, :type => "boolean (string, string, integer, string, boolean)"
    publish :function => :CheckNfsVolume, :type => "integer (string, string, boolean)"
    publish :function => :AddTmpfsVolume, :type => "boolean (string, string)"
    publish :function => :DelTmpfsVolume, :type => "boolean (string)"
    publish :function => :CreateMd, :type => "boolean (integer, string)"
    publish :function => :CreateMdWithDevs, :type => "boolean (integer, symbol, list <string>)"
    publish :function => :ReplaceMd, :type => "boolean (integer, list <string>)"
    publish :function => :ExtendMd, :type => "boolean (integer, list <string>)"
    publish :function => :ShrinkMd, :type => "boolean (integer, list <string>)"
    publish :function => :ChangeMdType, :type => "boolean (integer, string)"
    publish :function => :ChangeMdParity, :type => "boolean (integer, string)"
    publish :function => :ChangeMdParitySymbol, :type => "boolean (integer, symbol)"
    publish :function => :ChangeMdChunk, :type => "boolean (integer, integer)"
    publish :function => :CheckMd, :type => "integer (integer)"
    publish :function => :ComputeMdSize, :type => "integer (symbol, list <string>, integer &)"
    publish :function => :GetCryptPwd, :type => "string (string)"
    publish :function => :SetCryptPwd, :type => "boolean (string, string)"
    publish :function => :ActivateCrypt, :type => "boolean (string, boolean)"
    publish :function => :NeedCryptPwd, :type => "boolean (string)"
    publish :function => :IsVgEncrypted, :type => "boolean (map <string, map>, string)"
    publish :function => :NeedVgPassword, :type => "boolean (map <string, map>, string)"
    publish :function => :CreateLoop, :type => "string (string, boolean, integer, string)"
    publish :function => :UpdateLoop, :type => "boolean (string, string, boolean, integer)"
    publish :function => :DeleteLoop, :type => "boolean (string, string, boolean)"
    publish :function => :DefaultDiskLabel, :type => "string (string)"
    publish :function => :DeletePartitionTable, :type => "boolean (string, string)"
    publish :function => :CreatePartitionTable, :type => "boolean (string, string)"
    publish :function => :InitializeDisk, :type => "boolean (string, boolean)"
    publish :function => :IsPartType, :type => "boolean (symbol)"
    publish :function => :AddMountPointsForWin, :type => "void (map <string, map>)"
    publish :function => :RemoveDmMapsTo, :type => "void (string)"
    publish :function => :CheckSwapable, :type => "boolean (string)"
    publish :function => :CheckCryptOk, :type => "boolean (string, string, boolean, boolean)"
    publish :function => :RescanCrypted, :type => "boolean ()"
    publish :function => :CheckEncryptionPasswords, :type => "boolean (string, string, integer, boolean)"
    publish :function => :PasswdPopup, :type => "string (string, string, string, boolean, integer, boolean)"
    publish :function => :AskCryptPasswords, :type => "map <string, map> (map <string, map>)"
    publish :function => :ChangeDmNamesFromCrypttab, :type => "void (string)"
    publish :function => :GetAffectedDevices, :type => "list <string> (string)"
    publish :function => :SetRecursiveRemoval, :type => "void (boolean)"
    publish :function => :GetRecursiveRemoval, :type => "boolean ()"
    publish :function => :CommitChanges, :type => "integer ()"
    publish :function => :DeviceMounted, :type => "string (string)"
    publish :function => :Umount, :type => "boolean (string, boolean)"
    publish :function => :MountOpt, :type => "boolean (string, string, string)"
    publish :function => :Mount, :type => "boolean (string, string)"
    publish :function => :DetectHomeFs, :type => "boolean (map)"
    publish :function => :AddSubvolRoot, :type => "map (map)"
    publish :function => :SetVolOptions, :type => "map (map, string, symbol, string, string, string)"
    publish :function => :IsUsedBy, :type => "boolean (map)"
    publish :function => :TryUnaccessSwap, :type => "boolean (string)"
    publish :function => :CanCreate, :type => "boolean (map, boolean)"
    publish :function => :CanEdit, :type => "boolean (map, boolean)"
    publish :function => :CanDelete, :type => "boolean (map, map, boolean)"
    publish :function => :ReadFstab, :type => "list <map> (string)"
    publish :function => :mountedPartitionsOnDisk, :type => "list <map> (string)"
    publish :function => :GetCommitInfos, :type => "list <map> ()"
    publish :function => :GetEntryForMountpoint, :type => "map (string)"
    publish :function => :ChangeText, :type => "string ()"
    publish :function => :LastAction, :type => "string ()"
    publish :function => :ExtendedErrorMsg, :type => "string ()"
    publish :function => :SetZeroNewPartitions, :type => "void (boolean)"
    publish :function => :SetPartitionAlignment, :type => "void (symbol)"
    publish :function => :GetPartitionAlignment, :type => "symbol ()"
    publish :function => :GetMountPoints, :type => "map ()"
    publish :function => :IsRealDisk, :type => "boolean (map)"
    publish :function => :IsPartitionable, :type => "boolean (map)"
    publish :function => :DeviceRealDisk, :type => "boolean (string)"
    publish :function => :HaveLinuxPartitions, :type => "boolean ()"
    publish :function => :GetOtherLinuxPartitions, :type => "list ()"
    publish :function => :CheckSwapOn, :type => "boolean (string)"
    publish :function => :GetWinPrimPartitions, :type => "list <map> (map <string, map>)"
    publish :function => :GetUsedFs, :type => "list <string> ()"
    publish :function => :SaveUsedFs, :type => "void ()"
    publish :function => :AddPackageList, :type => "list <string> ()"
    publish :function => :HandleProposalPackages, :type => "void ()"
    publish :function => :GetForeignPrimary, :type => "list <string> ()"
    publish :function => :IsResizable, :type => "map <string, boolean> (map <string, any>)"
    publish :function => :FreeCylindersAroundPartition, :type => "boolean (string, integer &, integer &)"
    publish :function => :PathToDestdir, :type => "string (string)"
    publish :function => :ActivateHld, :type => "void (boolean)"
    publish :function => :ActivateMultipath, :type => "void (boolean)"
    publish :function => :SpecialBootHandling, :type => "map <string, map> (map <string, map>)"
    publish :function => :PerformLosetup, :type => "boolean (map &, boolean)"
    publish :function => :DetectFs, :type => "symbol (string)"
    publish :function => :GetBootPartition, :type => "map (string)"
    publish :function => :HdToIseries, :type => "string (string)"
    publish :function => :SLES9PersistentDevNames, :type => "string (string)"
    publish :function => :HdDiskMap, :type => "string (string, map)"
    publish :function => :BuildDiskmap, :type => "map (map)"
    publish :function => :TranslateDeviceDmraidToMdadm, :type => "string (string, map<string, string>)"
    publish :function => :GetTranslatedDevices, :type => "list <string> (map, map, list <string>)"
    publish :function => :FinishInstall, :type => "void ()"
    publish :function => :GetRootInitrdModules, :type => "list ()"
    publish :function => :CheckForLvmRootFs, :type => "boolean ()"
    publish :function => :CheckForMdRootFs, :type => "boolean ()"
    publish :function => :NumLoopDevices, :type => "integer ()"
    publish :function => :onepartition2fstab, :type => "map (map, integer &)"
    publish :function => :AddHwPackages, :type => "void (list <string>)"
    publish :function => :SwitchUiAutomounter, :type => "void (boolean)"
    publish :function => :DumpObjectList, :type => "void ()"
    publish :function => :SetDefaultMountBy, :type => "void (symbol)"
    publish :function => :GetDefaultMountBy, :type => "symbol ()"
    publish :function => :SaveDeviceGraph, :type => "boolean (string)"
    publish :function => :SaveMountGraph, :type => "boolean (string)"
    publish :function => :DeviceMatchFstab, :type => "boolean (string, string)"
    publish :function => :IsPersistent, :type => "boolean (map)"
    publish :function => :AllowedParity, :type => "list <list> (string, integer)"
    publish :function => :IsDeviceOnNetwork, :type => "symbol (string)"
    publish :function => :GetCreatedSwaps, :type => "list ()"
    publish :function => :GetDetectedDiskPaths, :type => "list <string> ()"
  end

  Storage = StorageClass.new
  Storage.main
end
