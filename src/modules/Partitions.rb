# encoding: utf-8

# Copyright (c) [2012-2014] Novell, Inc.
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

# Module:	Partitions.ycp
#
# Authors:	Thomas Fehr <fehr@suse.de>
#		Arvin Schnell <aschnell@suse.de>
#
# Purpose:	Provides information about partitions
#
# $Id$
require "storage"
require "yast"

module Yast
  class PartitionsClass < Module


    include Yast::Logger


    def main

      textdomain "storage"

      Yast.import "Arch"
      Yast.import "Mode"
      Yast.import "Stage"
      Yast.import "AsciiFile"
      Yast.import "StorageInit"

      # The filesystem ids for the partitions
      @fsid_empty = 0
      @fsid_native = 131
      @fsid_swap = 130
      @fsid_lvm = 142
      @fsid_raid = 253
      @fsid_hibernation = 160
      @fsid_extended = 5
      @fsid_extended_win = 15
      @fsid_fat16 = 6
      @fsid_fat32 = 12
      @fsid_prep_chrp_boot = 65
      @fsid_mac_hidden = 257
      @fsid_mac_hfs = 258
      @fsid_mac_ufs = 262
      @fsid_gpt_boot = 259
      @fsid_gpt_service = 260
      @fsid_gpt_msftres = 261
      @fsid_bios_grub = 263
      @fsid_gpt_prep = 264
      @fsid_freebsd = 165
      @fsid_openbsd = 166
      @fsid_netbsd = 169
      @fsid_beos = 235
      @fsid_solaris = 191
      @fsid_root = @fsid_native

      @boot_cyl = 0
      @boot_mount_point = ""
      @memory_size = 0

      @no_fsid_menu = Arch.s390

      @raid_name = "MD RAID"
      @lv_name = "LV"
      @dm_name = "DM"
      @loop_name = "Loop Device"
      @dmraid_name = "DM RAID"
      @dmmultipath_name = "DM Multipath"
      @nfs_name = "NFS"
      @btrfs_name = "BTRFS"
      @tmpfs_name = "TMPFS"

      # filesystems for /win
      @fsid_wintypes = [6, 11, 12, 14] # FAT32, Win95-Fat32, Win95LBA, Win95-Fat16

      # filesystems for /dos
      @fsid_dostypes = [1, 4] # FAT12, FAT16

      # filesystems for /windows
      @fsid_ntfstypes = [7, 23] # NTFS

      # filesystems mounted read-only
      @fsid_readonly = [7, 23]

      # filesystems skipped on sparc and axp
      @fsid_skipped = [0, 5]

      # partition ids not to delete when suggesting to use whole disk
      @do_not_delete = [18, 222, @fsid_mac_hfs, @fsid_gpt_service]

      # partition ids not to display as windows when fat32 is on it
      @no_windows = [
        18,
        130,
        222,
        @fsid_gpt_boot,
        @fsid_gpt_service,
        @fsid_gpt_msftres
      ]

      @boot_size_k = {}

      @default_fs = :unknown
      @default_boot_fs = :unknown
      @default_home_fs = :xfs

      @sint = nil

      @prep_boot_first = true
    end

    def InitSlib(value)
      @sint = value
      nil
    end

    def assertInit
      if @sint == nil
        @sint = StorageInit.CreateInterface(false)
        Builtins.y2error("StorageInit::CreateInterface failed") if @sint == nil
      end

      nil
    end


    def EfiBoot
      assertInit
      ret = @sint.getEfiBoot
      Builtins.y2milestone("EfiBoot ret:%1", ret)
      ret
    end


    def SetDefaultFs(new_default_fs)
      @default_fs = new_default_fs
      @default_boot_fs = :unknown

      nil
    end


    def DefaultFs
      if @default_fs == :unknown
        tmp = Convert.to_string(SCR.Read(path(".sysconfig.storage.DEFAULT_FS")))
        if tmp == nil ||
            !Builtins.contains(
              ["ext2", "ext3", "ext4", "reiser", "xfs", "btrfs"],
              Builtins.tolower(tmp)
            )
          tmp = "ext4"
        end

        @default_fs = Builtins.tosymbol(Builtins.tolower(tmp))
      end
      @default_fs
    end


    def DefaultBootFs
      if @default_boot_fs == :unknown
        if DefaultFs() != :btrfs
          @default_boot_fs = DefaultFs()
        else
          @default_boot_fs = :ext4
        end
        if EfiBoot()
          @default_boot_fs = :vfat
        elsif Arch.board_mac
          @default_boot_fs = :hfs
        elsif Arch.s390
          @default_boot_fs = :ext2
        end
      end
      @default_boot_fs
    end


    def DefaultHomeFs()
      @default_home_fs
    end


    def SetDefaultHomeFs(new_default_home_fs)
      @default_home_fs = new_default_home_fs
    end


    def BootMount
      if @boot_mount_point == ""
        @boot_mount_point = "/boot"
        @boot_mount_point = "/boot/efi" if EfiBoot()
        @boot_mount_point = "/boot/zipl" if Arch.s390
      end
      @boot_mount_point
    end


    def BootSizeK
      if Builtins.isempty(@boot_size_k)
        @boot_size_k = {
          :proposed => 400 * 1024,
          :minimal  => 90 * 1024,
          :maximal  => 750 * 1024
        }
        Ops.set(@boot_size_k, :proposed, 150 * 1024) if EfiBoot()

        if Arch.ia64
          Ops.set(@boot_size_k, :proposed, 200 * 1024)
          Ops.set(@boot_size_k, :minimal, 180 * 1024)
        elsif Arch.board_chrp || Arch.board_prep || Arch.board_iseries
          Ops.set(@boot_size_k, :proposed, 8032 )
          Ops.set(@boot_size_k, :minimal, 8032 )
        elsif Arch.board_mac
          Ops.set(@boot_size_k, :proposed, 32 * 1024)
          Ops.set(@boot_size_k, :minimal, 800)
        elsif Arch.s390
          Ops.set(@boot_size_k, :proposed, 200 * 1024)
          Ops.set(@boot_size_k, :minimal, 100 * 1024)
        end

        Builtins.y2milestone("BootSizeK boot_size_k:%1", @boot_size_k)
      end

      deep_copy(@boot_size_k)
    end


    def MinimalNeededBootsize
      Ops.multiply(1024, Ops.get(BootSizeK(), :proposed, 0))
    end

    def ProposedBootsize
      Ops.multiply(1024, Ops.get(BootSizeK(), :proposed, 0))
    end

    def MinimalBootsize
      Ops.multiply(1024, Ops.get(BootSizeK(), :minimal, 0))
    end

    def MaximalBootsize
      Ops.multiply(1024, Ops.get(BootSizeK(), :maximal, 0))
    end


    def BootCyl
      if @boot_cyl == 0
        @boot_cyl = 1024
        if !Arch.i386
          # Assume on non-i386 archs machine can boot from every cylinder
          @boot_cyl = 4 * 1024 * 1024 * 1024
        else
          internal_bios = Convert.convert(
            SCR.Read(path(".probe.bios")),
            :from => "any",
            :to   => "list <map>"
          )
          lba = Ops.get_boolean(internal_bios, [0, "lba_support"], false)
          Builtins.y2milestone("BootCyl lba_support %1", lba)
          if !lba
            st = Convert.to_map(
              SCR.Read(path(".target.stat"), "/proc/xen/capabilities")
            )
            Builtins.y2milestone("BootCyl /proc/xen/capabilities %1", st)
            if Ops.greater_than(Builtins.size(st), 0)
              lba = Ops.greater_than(
                Convert.to_integer(
                  SCR.Execute(
                    path(".target.bash"),
                    "grep control_d /proc/xen/capabilities"
                  )
                ),
                0
              )
            end
            Builtins.y2milestone("BootCyl lba_support %1", lba)
          end
          @boot_cyl = 4 * 1024 * 1024 * 1024 if lba
        end
      end
      @boot_cyl
    end


    def PrepBoot
      ret = Arch.ppc &&
        (Arch.board_chrp || Arch.board_prep || Arch.board_iseries)
      if ret && @prep_boot_first
        Builtins.y2milestone("PrepBoot ret:%1", ret)
        @prep_boot_first = false
      end
      ret
    end


    # @return [boolean] true iff the boot partition must be a primary partition
    #   (with MSDOS disk label)
    def BootPrimary()
      return PrepBoot()
    end


    def FsidBoot(dlabel)
      fsid_boot = @fsid_native
      if EfiBoot() || Arch.ia64()
        fsid_boot = @fsid_gpt_boot
      elsif PrepBoot()
        fsid_boot = dlabel == "gpt" ? @fsid_gpt_prep : @fsid_prep_chrp_boot
      elsif Arch.board_mac()
        fsid_boot = @fsid_mac_hfs
      end
      return fsid_boot
    end


    def NeedBoot
      ret = false
      if EfiBoot() || Arch.ia64 || Arch.ppc || Arch.sparc || Arch.alpha || Arch.s390
        ret = true
      end
      Builtins.y2milestone("NeedBoot ret:%1", ret)
      ret
    end


    def IsDosPartition(fsid)
      Builtins.contains(@fsid_dostypes, fsid) ||
        Builtins.contains(@fsid_wintypes, fsid)
    end

    def IsDosWinNtPartition(fsid)
      IsDosPartition(fsid) || Builtins.contains(@fsid_ntfstypes, fsid)
    end

    def IsExtendedPartition(fsid)
      fsid == @fsid_extended || fsid == @fsid_extended_win
    end

    def IsSwapPartition(fsid)
      !IsDosWinNtPartition(fsid) && fsid == @fsid_swap
    end

    def IsPrepPartition(fsid)
      return fsid == @fsid_prep_chrp_boot || fsid == @fsid_gpt_prep
    end


    def SwapSizeMbforSwap(slot_size)
      swap_size = 0

      if slot_size == 0
        if Ops.less_or_equal(@memory_size, 256)
          swap_size = Ops.multiply(@memory_size, 2)
        else
          swap_size = Ops.add(@memory_size, Ops.divide(@memory_size, 2))
        end
      else
        if Ops.less_than(Ops.multiply(@memory_size, 9), slot_size)
          swap_size = Ops.multiply(@memory_size, 2)
        elsif Ops.less_than(Ops.multiply(@memory_size, 5), slot_size)
          swap_size = @memory_size
        elsif Ops.less_than(Ops.multiply(@memory_size, 3), slot_size)
          swap_size = Ops.divide(@memory_size, 2)
        elsif Ops.less_than(Ops.multiply(@memory_size, 2), slot_size)
          swap_size = Ops.divide(@memory_size, 3)
        else
          swap_size = Ops.divide(@memory_size, 4)
        end
      end

      swap_size = 2048 if Ops.greater_than(swap_size, 2048)
      swap_size = 0 if Ops.less_than(swap_size, 0)


      # look for a min size
      # 1G    -> 128MB
      # 2G    -> 256MB
      # 10G   -> 512MB
      # 40G   -> 1GB

      if Ops.greater_than(slot_size, 40 * 1024) &&
          Ops.less_than(Ops.add(swap_size, @memory_size), 1024)
        swap_size = Ops.subtract(1024, @memory_size)
      elsif Ops.greater_than(slot_size, 10 * 1024) &&
          Ops.less_than(Ops.add(swap_size, @memory_size), 512)
        swap_size = Ops.subtract(512, @memory_size)
      elsif Ops.greater_than(slot_size, 2 * 1024) &&
          Ops.less_than(Ops.add(swap_size, @memory_size), 256)
        swap_size = Ops.subtract(256, @memory_size)
      elsif Ops.greater_than(slot_size, 1 * 1024) &&
          Ops.less_than(Ops.add(swap_size, @memory_size), 128)
        swap_size = Ops.subtract(128, @memory_size)
      end

      swap_size = -1 if swap_size == 0
      Builtins.y2milestone(
        "SwapSizeMbforSwap mem %1 slot_size %2 swap_size %3",
        @memory_size,
        slot_size,
        swap_size
      )
      swap_size
    end

    def SwapSizeMbforSuspend
      ret = Ops.multiply(Ops.divide(Ops.add(@memory_size, 511), 512), 512)
      Builtins.y2milestone("SwapSizeMbforSuspend %1", ret)
      ret
    end

    def SwapSizeMb(slot_size, suspend)
      if @memory_size == 0
        mem_info_map = Convert.to_map(SCR.Read(path(".proc.meminfo")))
        @memory_size = Ops.divide(
          Ops.get_integer(mem_info_map, "memtotal", 0),
          1024
        )
        Builtins.y2milestone(
          "mem_info_map:%1 mem:%2",
          mem_info_map,
          @memory_size
        )
      end
      sw = SwapSizeMbforSwap(slot_size)
      if suspend
        news = SwapSizeMbforSuspend()
        sw = news if Ops.greater_than(news, sw)
      end
      Builtins.y2milestone("SwapSizeMb suspend:%1 ret:%2", suspend, sw)
      sw
    end


    def IsResizable(fsid)
      ret = [@fsid_swap, @fsid_native, @fsid_gpt_boot].include?(fsid) ||
        IsDosWinNtPartition(fsid) || IsExtendedPartition(fsid)
      log.info("IsResizable fsid:#{fsid} ret:#{ret}")
      return ret
    end


    def IsLinuxPartition(fsid)
      fsid == @fsid_native || fsid == @fsid_swap || fsid == @fsid_lvm ||
        fsid == @fsid_raid ||
        fsid == @fsid_gpt_boot
    end

    def GetLoopOn(device)
      ret = {}
      cmd = Builtins.sformat("/sbin/losetup %1", device)
      bash_call = Convert.to_map(
        SCR.Execute(path(".target.bash_output"), cmd, {})
      )
      if Ops.get_integer(bash_call, "exit", 1) == 0
        text = Ops.get_string(bash_call, "stdout", "")
        fi = Builtins.search(text, ")")
        if fi != nil && Ops.greater_than(fi, 0)
          text = Builtins.substring(text, 0, fi)
          fi = Builtins.search(text, "(")
          if fi != nil && Ops.greater_than(fi, 0)
            text = Builtins.substring(text, Ops.add(fi, 1))
            Ops.set(ret, "file", text)
            stat = Convert.to_map(SCR.Read(path(".target.stat"), text))
            Ops.set(ret, "blockdev", Ops.get_boolean(stat, "isblock", false))
          end
        end
      end
      Builtins.y2milestone("dev %1 ret %2", device, ret)
      deep_copy(ret)
    end

    def TranslateMapperName(device)
      ret = device
      regex = "[^-](--)*-[^-]"
      if Builtins.search(device, "/dev/mapper/") == 0
        pos = Builtins.regexppos(device, regex)
        Builtins.y2milestone("pos=%1", pos)
        if Ops.greater_than(Builtins.size(pos), 0)
          ret = Ops.add(
            Ops.add(
              Ops.add(
                "/dev/",
                Builtins.substring(
                  device,
                  12,
                  Ops.subtract(
                    Ops.add(Ops.get(pos, 0, 0), Ops.get(pos, 1, 0)),
                    14
                  )
                )
              ),
              "/"
            ),
            Builtins.substring(
              device,
              Ops.subtract(Ops.add(Ops.get(pos, 0, 0), Ops.get(pos, 1, 0)), 1)
            )
          )
          spos = 4
          newpos = Builtins.search(Builtins.substring(ret, spos), "--")
          if newpos != nil
            spos = Ops.add(spos, newpos)
          else
            spos = -1
          end
          while Ops.greater_or_equal(spos, 0)
            ret = Ops.add(
              Builtins.substring(ret, 0, Ops.add(spos, 1)),
              Builtins.substring(ret, Ops.add(spos, 2))
            )
            spos = Ops.add(spos, 1)
            newpos = Builtins.search(Builtins.substring(ret, spos), "--")
            if newpos != nil
              spos = Ops.add(spos, newpos)
            else
              spos = -1
            end
          end
        end
        Builtins.y2milestone("TranslateMapperName %1 -> %2", device, ret)
      end
      ret
    end

    #	Return a list with all mounted partition
    #  @return [Array<Hash>]
    def CurMounted
      SCR.UnmountAgent(path(".proc.mounts"))
      SCR.UnmountAgent(path(".proc.swaps"))
      SCR.UnmountAgent(path(".etc.mtab"))
      mounts = Convert.convert(
        SCR.Read(path(".proc.mounts")),
        :from => "any",
        :to   => "list <map>"
      )
      swaps = Convert.convert(
        SCR.Read(path(".proc.swaps")),
        :from => "any",
        :to   => "list <map>"
      )
      mtab = Convert.convert(
        SCR.Read(path(".etc.mtab")),
        :from => "any",
        :to   => "list <map>"
      )

      if mounts == nil || swaps == nil || mtab == nil
        Builtins.y2error(
          "failed to read .proc.mounts or .proc.swaps or .etc.mtab"
        )
        return []
      end

      Builtins.foreach(swaps) do |swap|
        swap_entry = {
          "file" => "swap",
          "spec" => Ops.get_string(swap, "file", "")
        }
        mounts = Builtins.add(mounts, swap_entry)
      end

      mtab_root = Builtins.find(mtab) do |mount|
        Ops.get_string(mount, "file", "") == "/"
      end
      root_map = Builtins.find(mounts) do |mount|
        Ops.get_string(mount, "spec", "") == "/dev/root"
      end
      root_map = Builtins.find(mounts) do |mount|
        Ops.get_string(mount, "spec", "") != "rootfs" &&
          Ops.get_string(mount, "file", "") == "/"
      end if root_map == nil
      Builtins.y2milestone("mtab_root %1 root_map %2", mtab_root, root_map)
      #    root_map = add (root_map, "spec", mtab_root["spec"]:"");
      if Ops.get_string(root_map, "spec", "") == "/dev/root"
        Ops.set(root_map, "spec", Ops.get_string(mtab_root, "spec", ""))
      end
      if (Builtins.search(Ops.get_string(root_map, "spec", ""), "LABEL=") == 0 ||
          Builtins.search(Ops.get_string(root_map, "spec", ""), "UUID=") == 0) &&
          !Stage.initial
        bo = Convert.to_map(
          SCR.Execute(path(".target.bash_output"), "fsck -N /", {})
        )
        Builtins.y2milestone("CurMounted bo:%1", bo)
        dev = ""
        if Ops.get_integer(bo, "exit", 1) == 0
          tmp = Builtins.filter(
            Builtins.splitstring(Ops.get_string(bo, "stdout", ""), " \n")
          ) { |k| Ops.greater_than(Builtins.size(k), 0) }
          if Ops.greater_than(Builtins.size(tmp), 0)
            dev = Ops.get_string(tmp, Ops.subtract(Builtins.size(tmp), 1), "")
          end
          Builtins.y2milestone("CurMounted LABEL/UUID dev:%1", dev)
        end
        if Ops.greater_than(Builtins.size(dev), 0)
          Ops.set(root_map, "spec", dev)
        end
      end
      Builtins.y2milestone("root_map %1", root_map)
      #    this version makes some problems with interpreter, above lookup/add is OK
      mounts = Builtins.filter(mounts) do |mount|
        Ops.get_string(mount, "file", "") != "/"
      end
      mounts = Builtins.add(mounts, root_map)
      ret = []
      Builtins.foreach(mounts) do |p|
        if Builtins.search(Ops.get_string(p, "spec", ""), "/dev/loop") != nil
          r = GetLoopOn(Ops.get_string(p, "spec", ""))
          if Ops.get_boolean(r, "blockdev", false)
            Ops.set(p, "loop_on", Ops.get_string(r, "file", ""))
          end
        end
        ret = Builtins.add(ret, p)
      end
      ret = Builtins.maplist(ret) do |p|
        Ops.set(p, "spec", TranslateMapperName(Ops.get_string(p, "spec", "")))
        deep_copy(p)
      end
      Builtins.y2milestone("CurMounted all mounts %1", ret)
      deep_copy(ret)
    end


    def GetFstab(pathname)
      file = {}
      file_ref = arg_ref(file)
      AsciiFile.SetComment(file_ref, "^[ \t]*#")
      file = file_ref.value
      file_ref = arg_ref(file)
      AsciiFile.SetDelimiter(file_ref, " \t")
      file = file_ref.value
      file_ref = arg_ref(file)
      AsciiFile.SetListWidth(file_ref, [20, 20, 10, 21, 1, 1])
      file = file_ref.value
      file_ref = arg_ref(file)
      AsciiFile.ReadFile(file_ref, pathname)
      file = file_ref.value
      deep_copy(file)
    end

    def GetCrypto(pathname)
      file = {}
      file_ref = arg_ref(file)
      AsciiFile.SetComment(file_ref, "^[ \t]*#")
      file = file_ref.value
      file_ref = arg_ref(file)
      AsciiFile.SetDelimiter(file_ref, " \t")
      file = file_ref.value
      file_ref = arg_ref(file)
      AsciiFile.SetListWidth(file_ref, [11, 15, 20, 10, 10, 1])
      file = file_ref.value
      file_ref = arg_ref(file)
      AsciiFile.ReadFile(file_ref, pathname)
      file = file_ref.value
      deep_copy(file)
    end


    def ToHexString(num)
      sprintf("0x%02X", num)
    end


    def FsIdToString(fs_id)
      case fs_id
        when 0
          return "empty"
        when 1
          return "FAT12"
        when 2
          return "XENIX root"
        when 3
          return "XENIX usr"
        when 4
          return "FAT16 <32M"
        when 5
          return "Extended"
        when 6
          return "FAT16"
        when 7
          return "HPFS/NTFS"
        when 8
          return "AIX"
        when 9
          return "AIX boot"
        when 10
          return "OS/2 boot manager"
        when 11
          return "Win95 FAT32"
        when 12
          return "Win95 FAT32 LBA"
        when 14
          return "Win95 FAT16"
        when 15
          return "Extended"
        when 167
          return "NeXTSTEP"
        when 183
          return "BSDI fs"
        when 184
          return "BSDI swap"
        when 193
          return "DRDOS/sec"
        when 196
          return "DRDOS/sec"
        when 198
          return "DRDOS/sec"
        when 199
          return "Syrinx"
        when 218
          return "Non-Fs data"
        when 219
          return "CP/M / CTOS"
        when 222
          return "Dell Utility"
        when 225
          return "DOS access"
        when 227
          return "DOS R/O"
        when 228
          return "SpeedStor"
        when 235
          return "BeOS fs"
        when 238
          return "EFI GPT"
        when 239
          return "EFI (FAT-12/16)"
        when 241
          return "SpeedStor"
        when 244
          return "SpeedStor"
        when 242
          return "DOS secondary"
        when 253
          return "Linux RAID"
        when 254
          return "LANstep"
        when 255
          return "BBT or NBO reserved"
        when 16
          return "OPUS"
        when 17
          return "Hidden FAT12"
        when 18
          return "Vendor diag"
        when 20
          return "Hidden FAT16"
        when 22
          return "Hidden FAT16"
        when 23
          return "Hidden HPFS/NTFS"
        when 24
          return "AST Windows"
        when 27
          return "Hidden Win95"
        when 28
          return "Hidden Win95"
        when 30
          return "Hidden Win95"
        when 36
          return "NEC DOS"
        when 57
          return "Plan 9"
        when 60
          return "PartitionMagic"
        when 64
          return "Venix 80286"
        when 65
          return "PPC PReP Boot"
        when 66
          return "SFS"
        when 77
          return "QNX4.x"
        when 78
          return "QNX4.x 2nd par"
        when 79
          return "QNX4.x 3rd par"
        when 80
          return "OnTrack DM"
        when 81
          return "OnTrack DM6"
        when 82
          return "CP/M"
        when 83
          return "OnTrack DM6"
        when 84
          return "OnTrack DM6"
        when 85
          return "EZ-Drive"
        when 86
          return "Golden Bow"
        when 92
          return "Priam Edisk"
        when 97
          return "SpeedStor"
        when 99
          return "GNU HURD"
        when 100
          return "Novell NetWare"
        when 101
          return "Novell NetWare"
        when 112
          return "DiskSecure"
        when 117
          return "PC/IX"
        when 128
          return "Old Minix"
        when 129
          return "Minix"
        when 130
          return "Linux swap"
        when 131
          return "Linux native"
        when 132
          return "OS/2 hidden"
        when 133
          return "Linux extended"
        when 134
          return "NTFS volume"
        when 135
          return "NTFS volume"
        when 142
          return "Linux LVM"
        when 147
          return "Amoeba"
        when 148
          return "Amoeba BBT"
        when 159
          return "BSD/OS"
        when 160
          return "Hibernation"
        when 165
          return "FreeBSD"
        when 166
          return "OpenBSD"
        when 169
          return "NetBSD"
        when 258
          return "Apple_HFS"
        when 259
          return "EFI boot"
        when 260
          return "Service"
        when 261
          return "Microsoft reserved"
        when 262
          return "Apple_UFS"
        when 263
          return "BIOS Grub"
        when 264
          return "GPT PReP"
        else
          return "unknown"
      end
    end


    def MaxPrimary(dlabel)
      ret = 0
      assertInit
      caps = ::Storage::DlabelCapabilities.new()
      if( @sint.getDlabelCapabilities(dlabel, caps))
        ret = caps.maxPrimary
      end
      Builtins.y2milestone("MaxPrimary dlabel:%1 ret:%2", dlabel, ret)
      ret
    end


    def HasExtended(dlabel)
      ret = false
      assertInit
      caps = ::Storage::DlabelCapabilities.new()
      if( @sint.getDlabelCapabilities( dlabel, caps))
        ret = caps.extendedPossible
      end
      Builtins.y2milestone("HasExtended dlabel:%1 ret:%2", dlabel, ret)
      ret
    end


    def MaxLogical(dlabel)
      ret = 0
      assertInit
      caps = ::Storage::DlabelCapabilities.new()
      if( @sint.getDlabelCapabilities( dlabel, caps))
        ret = caps.maxLogical
      end
      Builtins.y2milestone("MaxLogical dlabel:%1 ret:%2", dlabel, ret)
      ret
    end


    def MaxSectors(dlabel)
      ret = 0
      assertInit
      caps = ::Storage::DlabelCapabilities.new()
      if( @sint.getDlabelCapabilities( dlabel, caps))
        ret = caps.maxSectors
      end
      Builtins.y2milestone("MaxSizeK dlabel:%1 ret:%2", dlabel, ret)
      ret
    end


    def RdonlyText(disk, expert_partitioner)
      disk = deep_copy(disk)
      text = ""
      if expert_partitioner
        text = Builtins.sformat(
          _("Operation not permitted on disk %1.\n"),
          Ops.get_string(disk, "device", "")
        )
      end

      if !Ops.get_boolean(disk, "has_fake_partition", false)
        # popup text %1 is replaced by disk name e.g. /dev/hda
        text = Ops.add(
          text,
          Builtins.sformat(
            _(
              "\n" +
                "The partitioning on your disk %1 is either not readable or not \n" +
                "supported by the partitioning tool parted used to change the\n" +
                "partition table.\n" +
                "\n" +
                "You can use the partitions on disk %1 as they are or\n" +
                "format them and assign mount points, but you cannot add, edit, \n" +
                "resize, or remove partitions from that disk here.\n"
            ),
            Ops.get_string(disk, "device", "")
          )
        )
      else
        # popup text %1 is replaced by disk name e.g. /dev/dasda
        text = Ops.add(
          text,
          Builtins.sformat(
            _(
              "\n" +
                "The disk %1 does not contain a partition table but for\n" +
                "compatibility the kernel has automatically generated a\n" +
                "partition spanning almost the entire disk.\n" +
                "\n" +
                "You can use the partition on disk %1 as it is or\n" +
                "format it and assign a mount point, but you cannot resize\n" +
                "or remove the partition from that disk here.\n"
            ),
            Ops.get_string(disk, "device", "")
          )
        )
      end

      if expert_partitioner
        # popup text
        text = Ops.add(
          text,
          _(
            "\n" +
              "\n" +
              "You can initialize the disk partition table to a sane state in the Expert\n" +
              "Partitioner by selecting \"Expert\"->\"Create New Partition Table\", \n" +
              "but this will destroy all data on all partitions of this disk.\n"
          )
        )
      else
        # popup text
        text = Ops.add(
          text,
          _(
            "\n" +
              "\n" +
              "Safely ignore this message if you do not intend to use \n" +
              "this disk during installation.\n"
          )
        )
      end
      text
    end

    publish :variable => :fsid_empty, :type => "const integer"
    publish :variable => :fsid_native, :type => "const integer"
    publish :variable => :fsid_swap, :type => "const integer"
    publish :variable => :fsid_lvm, :type => "const integer"
    publish :variable => :fsid_raid, :type => "const integer"
    publish :variable => :fsid_hibernation, :type => "const integer"
    publish :variable => :fsid_extended, :type => "const integer"
    publish :variable => :fsid_extended_win, :type => "const integer"
    publish :variable => :fsid_fat16, :type => "const integer"
    publish :variable => :fsid_fat32, :type => "const integer"
    publish :variable => :fsid_prep_chrp_boot, :type => "const integer"
    publish :variable => :fsid_gpt_prep, :type => "const integer"
    publish :variable => :fsid_mac_hidden, :type => "const integer"
    publish :variable => :fsid_mac_hfs, :type => "const integer"
    publish :variable => :fsid_mac_ufs, :type => "const integer"
    publish :variable => :fsid_gpt_boot, :type => "const integer"
    publish :variable => :fsid_gpt_service, :type => "const integer"
    publish :variable => :fsid_gpt_msftres, :type => "const integer"
    publish :variable => :fsid_bios_grub, :type => "const integer"
    publish :variable => :fsid_freebsd, :type => "const integer"
    publish :variable => :fsid_openbsd, :type => "const integer"
    publish :variable => :fsid_netbsd, :type => "const integer"
    publish :variable => :fsid_beos, :type => "const integer"
    publish :variable => :fsid_solaris, :type => "const integer"
    publish :variable => :fsid_root, :type => "const integer"
    publish :variable => :no_fsid_menu, :type => "boolean"
    publish :variable => :raid_name, :type => "string"
    publish :variable => :lv_name, :type => "string"
    publish :variable => :dm_name, :type => "string"
    publish :variable => :loop_name, :type => "string"
    publish :variable => :dmraid_name, :type => "string"
    publish :variable => :dmmultipath_name, :type => "string"
    publish :variable => :nfs_name, :type => "string"
    publish :variable => :btrfs_name, :type => "string"
    publish :variable => :tmpfs_name, :type => "string"
    publish :variable => :fsid_wintypes, :type => "const list <integer>"
    publish :variable => :fsid_dostypes, :type => "const list <integer>"
    publish :variable => :fsid_ntfstypes, :type => "const list <integer>"
    publish :variable => :fsid_readonly, :type => "const list <integer>"
    publish :variable => :fsid_skipped, :type => "const list <integer>"
    publish :variable => :do_not_delete, :type => "const list <integer>"
    publish :variable => :no_windows, :type => "const list <integer>"
    publish :function => :InitSlib, :type => "void (any)"
    publish :function => :EfiBoot, :type => "boolean ()"
    publish :function => :SetDefaultFs, :type => "void (symbol)"
    publish :function => :DefaultFs, :type => "symbol ()"
    publish :function => :DefaultBootFs, :type => "symbol ()"
    publish :function => :BootMount, :type => "string ()"
    publish :function => :MinimalNeededBootsize, :type => "integer ()"
    publish :function => :ProposedBootsize, :type => "integer ()"
    publish :function => :MinimalBootsize, :type => "integer ()"
    publish :function => :MaximalBootsize, :type => "integer ()"
    publish :function => :BootCyl, :type => "integer ()"
    publish :function => :PrepBoot, :type => "boolean ()"
    publish :function => :BootPrimary, :type => "boolean ()"
    publish :function => :FsidBoot, :type => "integer (string)"
    publish :function => :NeedBoot, :type => "boolean ()"
    publish :function => :IsDosPartition, :type => "boolean (integer)"
    publish :function => :IsDosWinNtPartition, :type => "boolean (integer)"
    publish :function => :IsExtendedPartition, :type => "boolean (integer)"
    publish :function => :IsSwapPartition, :type => "boolean (integer)"
    publish :function => :IsPrepPartition, :type => "boolean (integer)"
    publish :function => :SwapSizeMb, :type => "integer (integer, boolean)"
    publish :function => :IsResizable, :type => "boolean (integer)"
    publish :function => :IsLinuxPartition, :type => "boolean (integer)"
    publish :function => :GetLoopOn, :type => "map (string)"
    publish :function => :TranslateMapperName, :type => "string (string)"
    publish :function => :CurMounted, :type => "list <map> ()"
    publish :function => :GetFstab, :type => "map (string)"
    publish :function => :GetCrypto, :type => "map (string)"
    publish :function => :ToHexString, :type => "string (integer)"
    publish :function => :FsIdToString, :type => "string (integer)"
    publish :function => :MaxPrimary, :type => "integer (string)"
    publish :function => :HasExtended, :type => "boolean (string)"
    publish :function => :MaxLogical, :type => "integer (string)"
    publish :function => :MaxSectors, :type => "integer (string)"
    publish :function => :RdonlyText, :type => "string (map <string, any>, boolean)"
  end

  Partitions = PartitionsClass.new
  Partitions.main
end
