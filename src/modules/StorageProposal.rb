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

#************************************************************
#
#     YaST2      SuSE Labs                        -o)
#     --------------------                        /\\
#                                                _\_v
#           www.suse.de / www.suse.com
# ----------------------------------------------------------
#
# Author:        Thomas Fehr <fehr@suse.de>
#
# Description:   Make a proposal for partitioning
#
#***********************************************************
require "yast"

module Yast
  class StorageProposalClass < Module


    include Yast::Logger


    def main

      textdomain "storage"

      Yast.import "UI"
      Yast.import "FileSystems"
      Yast.import "Partitions"
      Yast.import "Label"
      Yast.import "Storage"
      Yast.import "ProductFeatures"
      Yast.import "Arch"
      Yast.import "Stage"

      @cur_mode = :free
      @cur_weight = -10000
      @cur_gap = {}
      @big_cyl = 4 * 1024 * 1024 * 1024

      @no_propose_disks = nil

      @proposal_home = false
      @proposal_home_fs = :xfs
      @proposal_lvm = false
      @proposal_encrypt = false
      @proposal_root_fs = :btrfs
      @proposal_snapshots = false
      @proposal_suspend = false
      @proposal_password = ""
      @proposal_create_vg = false

      @cfg_xml = {}

      @swapable = {}
      @ishome = {}
    end


    def SetCreateVg(val)
      @proposal_create_vg = val
      Builtins.y2milestone("SetCreateVg val:%1", @proposal_create_vg)
    end


    def GetProposalHome
      @proposal_home
    end

    def SetProposalHome(val)
      @proposal_home = val
      Builtins.y2milestone("SetProposalHome val:%1", @proposal_home)
    end

    def GetProposalHomeFs
      @proposal_home_fs
    end

    def SetProposalHomeFs(val)
      @proposal_home_fs = val
      Builtins.y2milestone("SetProposalHomeFs val:%1", @proposal_home_fs)
    end


    def GetProposalLvm
      @proposal_lvm
    end

    def SetProposalLvm(val)
      @proposal_lvm = val
      Builtins.y2milestone("SetProposalLvm val:%1", val)
    end

    def GetProposalEncrypt
      @proposal_encrypt
    end

    def SetProposalEncrypt(val)
      @proposal_encrypt = val
      Builtins.y2milestone("SetProposalEncrypt val:%1", val)
    end


    def GetProposalRootFs
      @proposal_root_fs
    end

    def SetProposalRootFs(val)
      @proposal_root_fs = val
      Builtins.y2milestone("SetProposalRootFs val:%1", @proposal_root_fs)
    end

    def GetProposalSnapshots()
      @proposal_snapshots
    end

    def SetProposalSnapshots(val)
      @proposal_snapshots = val
      Builtins.y2milestone("SetProposalSnapshots val:%1", val)
    end


    def GetProposalSuspend
      @proposal_suspend
    end

    def SetProposalSuspend(val)
      @proposal_suspend = val
      Builtins.y2milestone("SetProposalSuspend val:%1", val)
    end


    def GetProposalPassword
      @proposal_password
    end

    def SetProposalPassword(val)
      @proposal_password = val
      Builtins.y2milestone("SetProposalPassword")
    end


    def SetProposalDefault(home_only)
      # on S/390 there is no space for dedicated /home partition
      # to be possibly improved - as applies only for DASD (TODO)
      if Arch.s390
        SetProposalHome(false)
      else
        SetProposalHome(Ops.get_boolean(@cfg_xml, "home", false))
      end
      if !home_only
        SetProposalLvm(Ops.get_boolean(@cfg_xml, "prop_lvm", false))
        SetProposalEncrypt(false)
        SetProposalPassword("")
        SetProposalSuspend(Ops.get_boolean(@cfg_xml, "suspend", false))
        SetProposalRootFs(Partitions.DefaultFs())
        SetProposalHomeFs(Partitions.DefaultHomeFs())
        SetProposalSnapshots(Ops.get_boolean(@cfg_xml, "prop_snapshots", false))
      end
      Builtins.y2milestone(
        "SetProposalDefault home:%1 lvm:%2 encypt:%3 home_only:%4 snapshots:%5 suspend:%6 root_fs:%7 home_fs:%8",
        @proposal_home,
        @proposal_lvm,
        @proposal_encrypt,
        home_only,
        @proposal_snapshots,
        @proposal_suspend,
        @proposal_root_fs,
        @proposal_home_fs
      )

      nil
    end


    def GetControlCfg
      if Builtins.isempty(@cfg_xml)
        btmp = ProductFeatures.GetBooleanFeature(
          "partitioning",
          "try_separate_home"
        )
        Ops.set(@cfg_xml, "home", btmp)

        itmp = ProductFeatures.GetIntegerFeature(
          "partitioning",
          "root_space_percent"
        )
        Ops.set(@cfg_xml, "root_percent", itmp)
        if Ops.get_integer(@cfg_xml, "root_percent", 0) == nil ||
            Ops.less_or_equal(Ops.get_integer(@cfg_xml, "root_percent", 0), 0)
          Ops.set(@cfg_xml, "root_percent", 40)
        end

        stmp = ProductFeatures.GetStringFeature(
          "partitioning",
          "limit_try_home"
        )
        Ops.set(
          @cfg_xml,
          "home_limit",
          Ops.divide(Storage.ClassicStringToByte(stmp), 1024 * 1024)
        )
        if Ops.less_or_equal(Ops.get_integer(@cfg_xml, "home_limit", 0), 0)
          Ops.set(@cfg_xml, "home_limit", 5 * 1024)
        end

        stmp = ProductFeatures.GetStringFeature(
          "partitioning",
          "root_base_size"
        )
        Ops.set(
          @cfg_xml,
          "root_base",
          Ops.divide(Storage.ClassicStringToByte(stmp), 1024 * 1024)
        )
        if Ops.less_or_equal(Ops.get_integer(@cfg_xml, "root_base", 0), 0)
          Ops.set(@cfg_xml, "root_base", 3 * 1024)
        end

        stmp = ProductFeatures.GetStringFeature("partitioning", "root_max_size")
        Ops.set(
          @cfg_xml,
          "root_max",
          Ops.divide(Storage.ClassicStringToByte(stmp), 1024 * 1024)
        )
        if Ops.less_or_equal(Ops.get_integer(@cfg_xml, "root_max", 0), 0)
          Ops.set(@cfg_xml, "root_max", 10 * 1024)
        end

        btmp = ProductFeatures.GetBooleanFeature(
          "partitioning",
          "vm_keep_unpartitioned_region"
        )
        Ops.set(@cfg_xml, "vm_keep_unpartitioned_region", btmp)

        stmp = ProductFeatures.GetStringFeature(
          "partitioning",
          "vm_desired_size"
        )
        Ops.set(
          @cfg_xml,
          "vm_want",
          Ops.divide(Storage.ClassicStringToByte(stmp), 1024 * 1024)
        )
        if Ops.less_or_equal(Ops.get_integer(@cfg_xml, "vm_want", 0), 0)
          Ops.set(@cfg_xml, "vm_want", 15 * 1024)
        end

        stmp = ProductFeatures.GetStringFeature(
          "partitioning",
          "vm_home_max_size"
        )
        Ops.set(
          @cfg_xml,
          "home_max",
          Ops.divide(Storage.ClassicStringToByte(stmp), 1024 * 1024)
        )
        if Ops.less_or_equal(Ops.get_integer(@cfg_xml, "home_max", 0), 0)
          Ops.set(@cfg_xml, "home_max", 25 * 1024)
        end

        btmp = ProductFeatures.GetBooleanFeature("partitioning", "proposal_lvm")
        Ops.set(@cfg_xml, "prop_lvm", btmp ? true : false)

        # GetBooleanFeature cannot distinguish between missing and false
        tmp = ProductFeatures.GetFeature("partitioning", "proposal_snapshots")
        Ops.set(@cfg_xml, "prop_snapshots", tmp == "" || tmp == true ? true : false)

        itmp = ProductFeatures.GetIntegerFeature(
          "partitioning",
          "btrfs_increase_percentage"
        )
        Ops.set(@cfg_xml, "btrfs_increase_percentage", itmp)
        if Ops.get_integer(@cfg_xml, "btrfs_increase_percentage", 0) == nil ||
            Ops.less_than(
              Ops.get_integer(@cfg_xml, "btrfs_increase_percentage", 0),
              0
            )
          Ops.set(@cfg_xml, "btrfs_increase_percentage", 100)
        end

        btmp = ProductFeatures.GetBooleanFeature(
          "partitioning",
          "swap_for_suspend"
        )
        Ops.set(@cfg_xml, "suspend", btmp ? true : false)

        SetProposalDefault(false)
        Builtins.y2milestone("GetControlCfg cfg_xml:%1", @cfg_xml)
      end
      ret = deep_copy(@cfg_xml)
      Builtins.y2milestone(
        "GetControlCfg GetProposalSnapshots:%1",
        GetProposalSnapshots()
      )
      if PropDefaultFs() == :btrfs && GetProposalSnapshots()
        Builtins.y2milestone("GetControlCfg before:%1", ret)
        keys = ["home_limit", "root_max", "root_base", "home_max", "vm_want"]
        Builtins.foreach(keys) do |k|
          if Builtins.haskey(ret, k)
            ret[k] *= 1.0 + @cfg_xml["btrfs_increase_percentage"] / 100.0
          else
            Builtins.y2warning("GetControlCfg no key:%1", k)
          end
        end
        Builtins.y2milestone("GetControlCfg after :%1", ret)
      end

      deep_copy(ret)
    end


    def GetProposalVM
      ret = ""
      ret = "system" if @proposal_lvm
      Builtins.y2milestone("ProposalVM lvm:%1 ret:%2", @proposal_lvm, ret)
      ret
    end


    def PropDefaultFs()
      @proposal_root_fs
    end


    def PropDefaultHomeFs()
      @proposal_home_fs
    end


    def EncryptDevices(target, vg)
      target = deep_copy(target)
      return deep_copy(target) if !GetProposalLvm() || !GetProposalEncrypt()

      devices = Ops.get_list(target, [vg, "devices_add"], [])

      Builtins.y2milestone("vg:%1 devices:%2", vg, devices)

      # go through target map and set enc_type and password for all devices used by
      # our volume group
      target = Builtins.mapmap(target) do |disk_device, data|
        partitions = Ops.get_list(data, "partitions", [])
        partitions = Builtins.maplist(partitions) do |partition|
          part_device = Ops.get_string(partition, "device", "")
          if Builtins.contains(devices, part_device)
            Builtins.y2debug("setting encryption for %1", part_device)
            Ops.set(partition, "enc_type", :luks)
            Storage.SetCryptPwd(part_device, @proposal_password)
          end
          deep_copy(partition)
        end
        Ops.set(data, "partitions", partitions)
        { disk_device => data }
      end

      Builtins.y2milestone("target:%1", target)

      deep_copy(target)
    end


    def GetDestroyedLvmVgs(target)
      target = deep_copy(target)
      vgs = []
      Builtins.foreach(target) do |diskdev, disk|
        Builtins.foreach(Ops.get_list(disk, "partitions", [])) do |p|
          if Ops.get_symbol(p, "used_by_type", :UB_NONE) == :UB_LVM &&
              Ops.get_boolean(p, "format", false)
            vgs = Builtins.add(vgs, Ops.get_string(p, "used_by_device", ""))
          end
        end
      end
      vgs = Builtins.toset(vgs)
      Builtins.y2milestone("GetDestroyedLvmVgs %1", vgs)
      deep_copy(vgs)
    end


    def DeleteDestroyedLvmVgs(target)
      target = deep_copy(target)
      vgs = GetDestroyedLvmVgs(target)
      Builtins.y2milestone("DeleteDestroyedLvmVgs %1", vgs)
      Builtins.foreach(vgs) do |dev|
        Ops.set(target, [dev, "delete"], true) if Builtins.haskey(target, dev)
        Ops.set(
          target,
          [dev, "partitions"],
          Builtins.maplist(Ops.get_list(target, [dev, "partitions"], [])) do |p|
            p = Builtins.remove(p, "mount") if Builtins.haskey(p, "mount")
            deep_copy(p)
          end
        )
        Builtins.y2milestone(
          "DeleteDestroyedLvmVgs %1: %2",
          dev,
          Ops.get(target, dev, {})
        )
      end
      deep_copy(target)
    end


    def NoProposeDisks
      if @no_propose_disks == nil
        @no_propose_disks = []
        if Stage.initial &&
            Ops.greater_than(
              SCR.Read(path(".target.size"), "/etc/install.inf"),
              0
            )
          inst = Convert.to_string(SCR.Read(path(".etc.install_inf.Partition")))
          Builtins.y2milestone(
            "NoProposeDisks .etc.install_inf.Partition \"%1\"",
            inst
          )
          if inst != nil && Ops.greater_than(Builtins.size(inst), 0)
            inst = Ops.add("/dev/", inst) if Builtins.search(inst, "/dev/") != 0
            d = Storage.GetDiskPartition(inst)
            Builtins.y2milestone("NoProposeDisks inst:%1 disk:%2", inst, d)
            if Ops.greater_than(Builtins.size(Ops.get_string(d, "disk", "")), 0)
              @no_propose_disks = Builtins.add(
                @no_propose_disks,
                Ops.get_string(d, "disk", "")
              )
            end
          end
          inst = Convert.to_string(SCR.Read(path(".etc.install_inf.Cdrom")))
          Builtins.y2milestone(
            "NoProposeDisks .etc.install_inf.Cdrom \"%1\"",
            inst
          )
          if inst != nil && Ops.greater_than(Builtins.size(inst), 0)
            inst = Ops.add("/dev/", inst) if Builtins.search(inst, "/dev/") != 0
            d = Storage.GetDiskPartition(inst)
            Builtins.y2milestone("NoProposeDisks inst:%1 disk:%2", inst, d)
            if Ops.greater_than(Builtins.size(Ops.get_string(d, "disk", "")), 0)
              @no_propose_disks = Builtins.add(
                @no_propose_disks,
                Ops.get_string(d, "disk", "")
              )
            end
          end
        end
        if Stage.initial
          env = Builtins.getenv("YAST2_STORAGE_NO_PROPOSE_DISKS")
          Builtins.y2milestone("NoProposeDisks env:\"%1\"", env)
          if env != nil
            ls = Builtins.filter(Builtins.splitstring(env, " \t\n")) do |e|
              Ops.greater_than(Builtins.size(e), 0)
            end
            @no_propose_disks = Convert.convert(
              Builtins.merge(@no_propose_disks, ls),
              :from => "list",
              :to   => "list <string>"
            )
          end
        end
        @no_propose_disks = Builtins.toset(Builtins.sort(@no_propose_disks))
        Builtins.y2milestone("NoProposeDisks \"%1\"", @no_propose_disks)
      end
      deep_copy(@no_propose_disks)
    end


    def NeedNewDisklabel(entry)
      entry = deep_copy(entry)
      ret = Partitions.EfiBoot
      if ret
        lab = Ops.get_string(entry, "orig_label", "")
        lab = Ops.get_string(entry, "label", "gpt") if Builtins.size(lab) == 0
        ret = lab != "gpt"
      end
      Builtins.y2milestone(
        "NeedNewDisklabel dev:%1 ret:%2",
        Ops.get_string(entry, "device", ""),
        ret
      )
      ret
    end


    def ignore_disk(dev, entry, soft)
      entry = deep_copy(entry)
      ret = !Storage.IsPartitionable(entry) ||
        Ops.get_boolean(entry, "readonly", false)
      # GPT is not required for uEFI on x86_64
      if !ret && Arch.ia64 && Ops.get_string(entry, "label", "gpt") != "gpt"
        ret = true
      end
      if !ret && soft && NeedNewDisklabel(entry) &&
          !Builtins.isempty(
            Builtins.filter(Ops.get_list(entry, "partitions", [])) do |p|
              !Ops.get_boolean(p, "delete", false)
            end
          )
        ret = true
      end
      if !ret && soft && Arch.board_iseries &&
          Builtins.search(dev, "/dev/sd") == 0
        ret = true
      end
      if !ret && soft &&
          (Ops.get_boolean(entry, "softraiddisk", false) ||
            Ops.get_boolean(entry, "hotpluggable", false))
        ret = true
      end
      ret = true if !ret && soft && Builtins.contains(NoProposeDisks(), dev)
      ret = Storage.IsUsedBy(entry) if !ret && soft
      Builtins.y2milestone("ignoring disk %1 soft:%2", dev, soft) if ret
      ret
    end


    def AddWinInfo(targets)
      targets = deep_copy(targets)
      Builtins.y2milestone("AddWinInfo called")
      Builtins.foreach(targets) do |disk, data|
        Ops.set(
          targets,
          [disk, "partitions"],
          Builtins.maplist(Ops.get_list(data, "partitions", [])) do |p|
            if Partitions.IsDosWinNtPartition(Ops.get_integer(p, "fsid", 0)) &&
                Builtins.contains(
                  [:ntfs, :vfat],
                  Ops.get_symbol(p, "used_fs", :none)
                )
              Ops.set(
                p,
                "winfo",
                Storage.GetFreeSpace(
                  Ops.get_string(p, "device", ""),
                  Ops.get_symbol(p, "used_fs", :none),
                  false
                )
              )
              Builtins.y2milestone("AddWinInfo %1", p)
            end
            deep_copy(p)
          end
        )
      end
      deep_copy(targets)
    end


    def fill_ishome(pl)
      pl = deep_copy(pl)
      Builtins.foreach(pl) do |p|
        if !Builtins.haskey(@ishome, Ops.get_string(p, "device", ""))
          Ops.set(
            @ishome,
            Ops.get_string(p, "device", ""),
            Storage.DetectHomeFs(p)
          )
        end
      end

      nil
    end


    def flex_init_swapable(tg)
      tg = deep_copy(tg)
      @swapable = {}
      swaps = Storage.SwappingPartitions
      Builtins.foreach(tg) do |dev, disk|
        if !Storage.IsUsedBy(disk)
          sw = Builtins.filter(Ops.get_list(disk, "partitions", [])) do |p|
            Ops.get_symbol(p, "type", :unknown) != :extended &&
              !Ops.get_boolean(p, "delete", false) &&
              Ops.get_symbol(p, "detected_fs", :unknown) == :swap
          end
          sw = Builtins.filter(sw) do |p|
            Builtins.contains(swaps, Ops.get_string(p, "device", "")) ||
              Storage.CheckSwapable(Ops.get_string(p, "device", ""))
          end
          Builtins.foreach(sw) do |p|
            Ops.set(@swapable, Ops.get_string(p, "device", ""), true)
          end
        end
      end
      Builtins.y2milestone("flex_init_swapable %1", @swapable)

      nil
    end


    def check_swapable(dev)
      Ops.get(@swapable, dev, false)
    end


    def pinfo_name()
      return "/part.info"
    end


    def has_flex_proposal
      ret = SCR.Read(path(".target.size"), pinfo_name) > 0
      if !ret
        t = ProductFeatures.GetBooleanFeature(
          "partitioning",
          "use_flexible_partitioning"
        )
        Builtins.y2milestone("ProductFeatures::GetBooleanFeature %1", t)
        ret = true if Ops.is_boolean?(t) && Convert.to_boolean(t)
      end
      Builtins.y2milestone("has_flex_proposal ret:%1", ret)
      ret
    end


    def need_boot(disk)
      log.info("need_boot NeedBoot:#{Partitions.NeedBoot()} " +
               "type:#{disk.fetch("type", :CT_UNKNOWN)}")
      ret = Partitions.NeedBoot ||
        disk.fetch("type",:CT_UNKNOWN) == :CT_DMRAID ||
	(disk.fetch("label","")=="gpt" && !Partitions.EfiBoot)
      log.info("need_boot ret:#{ret}")
      return ret
    end


    def try_add_boot(conf, disk, force)
      pl = conf.fetch("partitions", [])
      boot = pl.index { |e| e.fetch("mount","")==Partitions.BootMount }!=nil
      root = pl.index { |e| e.fetch("mount","")=="/" }!=nil
      tc = deep_copy(conf)

      log.info("try_add_boot conf:#{conf}")
      log.info("try_add_boot boot:#{boot} root:#{root} force:#{force} need_boot:#{need_boot(disk)}")

      if !boot && (root || force) &&
          ( disk.fetch("cyl_count", 0) > Partitions.BootCyl || need_boot(disk) )
        dlabel = disk.fetch("label", "")
        pb = {}
	pb["mount"] = Partitions.BootMount
	pb["size"] = Partitions.ProposedBootsize
	if disk.fetch("label","")=="gpt" && !Partitions.EfiBoot
	  sz = disk.fetch("cyl_size",0)-1024
	  sz = 200*1024 if sz<200*1024
	  pb["size"] = sz
	end
	pb["fsys"] = Partitions.DefaultBootFs
	pb["id"] = Partitions.FsidBoot(dlabel)
        pb["auto_added"] = true
        pb["max_cyl"] = Partitions.BootCyl
        pb["primary"] = Partitions.BootPrimary
        pb["maxsize"] = Partitions.MaximalBootsize
        tc["partitions"].push( pb )
        Builtins.y2milestone(
          "try_add_boot disk_cyl %1 boot_cyl %2 need_boot %3 typ %4",
          disk.fetch("cyl_count",0), Partitions.BootCyl,
          Partitions.NeedBoot, disk.fetch("type",:CT_UNKNOWN))
        Builtins.y2milestone("try_add_boot boot added automagically pb %1", pb)
      end
      deep_copy(tc)
    end


    def do_flexible_disk(disk)
      disk = deep_copy(disk)
      dev = Ops.get_string(disk, "device", "")
      Builtins.y2milestone("do_flexible_disk dev %1", dev)
      Builtins.y2milestone(
        "do_flexible_disk parts %1",
        Ops.get_list(disk, "partitions", [])
      )
      ret = {}
      Ops.set(ret, "ok", false)
      conf = read_partition_config(pinfo_name)
      solutions = {}

      if Ops.greater_than(Builtins.size(conf), 0) &&
          Storage.IsPartitionable(disk)
        Builtins.y2milestone("do_flexible_disk processing disk %1", dev)
        tc = try_add_boot(conf, disk, false)
        @cur_mode = :free
        @cur_gap = {}
        gap = get_gap_info(disk, false)
        tc = add_cylinder_info(tc, gap)
        sol = get_perfect_list(Ops.get_list(tc, "partitions", []), gap)
        if Ops.greater_than(Builtins.size(sol), 0)
          Ops.set(sol, "disk", Builtins.eval(disk))
          Ops.set(ret, "ok", true)
          Ops.set(ret, "disk", process_partition_data(dev, sol, ""))
          Ops.set(ret, "weight", Ops.get_integer(sol, "weight", -1))
        end
      end
      Builtins.y2milestone(
        "do_flexible_disk ret %1",
        Ops.get_boolean(ret, "ok", false)
      )
      if Ops.get_boolean(ret, "ok", false)
        Builtins.y2milestone(
          "do_flexible_disk weight %1",
          Ops.get_integer(ret, "weight", -2)
        )
        Builtins.y2milestone(
          "do_flexible_disk disk %1",
          Ops.get_map(ret, "disk", {})
        )
      end
      deep_copy(ret)
    end


    def do_flexible_disk_conf(disk, co, ignore_boot, reuse)
      disk = deep_copy(disk)
      co = deep_copy(co)
      dev = Ops.get_string(disk, "device", "")
      Builtins.y2milestone(
        "do_flexible_disk_conf dev %1 ignore_boot %2 reuse %3",
        dev,
        ignore_boot,
        reuse
      )
      conf = deep_copy(co)
      conf = try_add_boot(conf, disk, true) if !ignore_boot
      Builtins.y2milestone(
        "do_flexible_disk_conf parts %1",
        Ops.get_list(disk, "partitions", [])
      )
      Builtins.y2milestone("do_flexible_disk_conf conf %1", conf)
      ret = {}
      Ops.set(ret, "ok", false)
      solutions = {}

      if Ops.greater_than(Builtins.size(conf), 0) &&
          Ops.greater_than(
            Builtins.size(Ops.get_list(conf, "partitions", [])),
            0
          ) &&
          Storage.IsPartitionable(disk)
        Builtins.y2milestone("do_flexible_disk_conf processing disk %1", dev)
        @cur_mode = reuse ? :reuse : :free
        @cur_gap = {}
        gap = get_gap_info(disk, reuse)
        tc = add_cylinder_info(conf, gap)
        sol = get_perfect_list(Ops.get_list(tc, "partitions", []), gap)
        if Ops.greater_than(Builtins.size(sol), 0)
          Ops.set(sol, "disk", Builtins.eval(disk))
          Ops.set(ret, "ok", true)
          Ops.set(ret, "disk", process_partition_data(dev, sol, ""))
          Ops.set(ret, "weight", Ops.get_integer(sol, "weight", -1))
        end
      elsif Storage.IsPartitionable(disk)
        Ops.set(ret, "ok", true)
        Ops.set(ret, "disk", disk)
      end
      Builtins.y2milestone(
        "do_flexible_disk_conf ret %1",
        Ops.get_boolean(ret, "ok", false)
      )
      if Ops.get_boolean(ret, "ok", false) &&
          Ops.greater_than(Builtins.size(conf), 0)
        Builtins.y2milestone(
          "do_flexible_disk_conf weight %1",
          Ops.get_integer(ret, "weight", -2)
        )
        Builtins.y2milestone(
          "do_flexible_disk_conf parts %1",
          Ops.get_list(ret, ["disk", "partitions"], [])
        )
      end
      deep_copy(ret)
    end


    def do_vm_disk_conf(disk, boot, boot2, vmkey, key)
      disk = deep_copy(disk)
      boot = deep_copy(boot)
      boot2 = deep_copy(boot2)
      dev = Ops.get_string(disk, "device", "")
      Builtins.y2milestone(
        "do_vm_disk_conf dev %1 vmkey %2 key %3 boot %4 boot2:%5",
        dev,
        vmkey,
        key,
        boot,
        boot2
      )
      Builtins.y2milestone(
        "do_vm_disk_conf parts %1",
        Ops.get_list(disk, "partitions", [])
      )
      conf = {}
      if Ops.greater_than(Builtins.size(boot), 0)
        Ops.set(
          conf,
          "partitions",
          Builtins.add(Ops.get_list(conf, "partitions", []), boot)
        )
      end
      if Ops.greater_than(Builtins.size(boot2), 0)
        Ops.set(
          conf,
          "partitions",
          Builtins.add(Ops.get_list(conf, "partitions", []), boot2)
        )
      end
      if Builtins.isempty(vmkey)
        Ops.set(
          conf,
          "partitions",
          Builtins.add(
            Ops.get_list(conf, "partitions", []),
            { "id" => Partitions.fsid_lvm }
          )
        )
      end
      Builtins.y2milestone("do_vm_disk_conf conf %1", conf)
      ret = {}
      Ops.set(ret, "ok", false)

      fsid = Partitions.fsid_lvm
      if Storage.IsPartitionable(disk)
        Builtins.y2milestone("do_vm_disk_conf processing disk %1", dev)
        @cur_mode = :free
        @cur_gap = {}
        gap = get_gap_info(disk, true)
        Builtins.y2milestone("do_vm_disk_conf gap %1", gap)
        Builtins.y2milestone("do_vm_disk_conf conf %1", conf)
        tc = add_cylinder_info(conf, gap)
        Builtins.y2milestone("do_vm_disk_conf tc %1", tc)
        Builtins.y2milestone(
          "do_vm_disk_conf gap %1",
          Ops.get_list(gap, "gap", [])
        )
        if Ops.greater_than(Builtins.size(Ops.get_list(gap, "gap", [])), 1)
          Ops.set(gap, "gap", Builtins.sort(Ops.get_list(gap, "gap", [])) do |a, b|
            if Ops.get_boolean(a, "extended", false) ==
                Ops.get_boolean(b, "extended", false)
              next Ops.less_than(
                Ops.get_integer(a, "start", 0),
                Ops.get_integer(b, "start", 0)
              )
            else
              next !Ops.get_boolean(a, "extended", false)
            end
          end)
          Builtins.y2milestone(
            "do_vm_disk_conf gap %1",
            Ops.get_list(gap, "gap", [])
          )
        end
        ok = true
        count = 0
        smallp = Builtins.filter(Ops.get_list(tc, "partitions", [])) do |p|
          Ops.get_integer(p, "id", 0) != Partitions.fsid_lvm
        end
        Builtins.y2milestone("do_vm_disk_conf smallp %1", smallp)
        Builtins.foreach(smallp) do |bo|
          Builtins.y2milestone("do_vm_disk_conf bo %1", bo)
          cyl_num = Ops.get_integer(bo, "cylinders", 1)
          found = false
          Ops.set(gap, "gap", Builtins.maplist(Ops.get_list(gap, "gap", [])) do |g|
            if !Ops.get_boolean(g, "exists", false) &&
                Ops.greater_or_equal(
                  Ops.get_integer(g, "cylinders", 0),
                  cyl_num
                ) &&
                (Ops.get_boolean(g, "extended", false) &&
                  Ops.greater_than(
                    Builtins.size(Ops.get_list(gap, "ext_pnr", [])),
                    0
                  ) ||
                  !Ops.get_boolean(g, "extended", false) &&
                    Ops.greater_than(
                      Builtins.size(Ops.get_list(gap, "free_pnr", [])),
                      0
                    ))
              found = true
              key2 = Ops.get_boolean(g, "extended", false) ? "ext_pnr" : "free_pnr"
              Ops.set(
                g,
                "added",
                Builtins.add(
                  Ops.get_list(g, "added", []),
                  [count, Ops.get_integer(gap, [key2, 0], 0), cyl_num]
                )
              )
              Ops.set(
                g,
                "cylinders",
                Ops.subtract(Ops.get_integer(g, "cylinders", 0), cyl_num)
              )
              Ops.set(
                gap,
                key2,
                Builtins.remove(Ops.get_list(gap, key2, []), 0)
              )
            end
            deep_copy(g)
          end)
          ok = false if !found
          count = Ops.add(count, 1)
        end
        Builtins.y2milestone(
          "do_vm_disk_conf ok:%1 gap %2",
          ok,
          Ops.get_list(gap, "gap", [])
        )
        gap = {} if !Builtins.isempty(vmkey)
        sol = {}
        Ops.set(sol, "solution", gap)
        Ops.set(sol, "partitions", Ops.get_list(conf, "partitions", []))
        Ops.set(sol, "disk", disk)
        Ops.set(ret, "ok", ok)
        Ops.set(ret, "weight", 0)
        if ok && Builtins.size(vmkey) == 0
          if Ops.greater_than(
              Builtins.size(Ops.get_list(gap, "ext_reg", [])),
              0
            )
            ext_end = Ops.subtract(
              Ops.add(
                Ops.get_integer(gap, ["ext_reg", 0], 0),
                Ops.get_integer(gap, ["ext_reg", 1], 0)
              ),
              1
            )
            aext = Builtins.find(Ops.get_list(gap, "gap", [])) do |g|
              Builtins.size(Ops.get_list(g, "added", [])) == 0 &&
                !Ops.get_boolean(g, "exists", false) &&
                Ops.greater_or_equal(Ops.get_integer(g, "start", 0), ext_end) &&
                Ops.less_or_equal(
                  Ops.subtract(Ops.get_integer(g, "start", 0), ext_end),
                  1
                )
            end
            Builtins.y2milestone("do_vm_disk_conf ee:%1 ae:%2", ext_end, aext)
            if aext != nil
              Ops.set(gap, "resize_ext", Ops.get_integer(aext, "end", 0))
              Ops.set(gap, "gap", Builtins.filter(Ops.get_list(gap, "gap", [])) do |g|
                Ops.get_integer(g, "start", 0) !=
                  Ops.get_integer(aext, "start", 0)
              end)
              aext = Builtins.find(Ops.get_list(gap, "gap", [])) do |g|
                !Ops.get_boolean(g, "exists", false) &&
                  Ops.get_boolean(g, "extended", false) &&
                  Ops.get_integer(g, "end", 0) == ext_end
              end
              Builtins.y2milestone("do_vm_disk_conf aext %1", aext)
              if aext != nil
                Ops.set(
                  gap,
                  "gap",
                  Builtins.maplist(Ops.get_list(gap, "gap", [])) do |g|
                    if Ops.get_integer(g, "end", 0) ==
                        Ops.get_integer(aext, "end", 0)
                      Ops.set(
                        g,
                        "cylinders",
                        Ops.subtract(
                          Ops.add(
                            Ops.get_integer(g, "cylinders", 0),
                            Ops.get_integer(gap, "resize_ext", 0)
                          ),
                          Ops.get_integer(g, "end", 0)
                        )
                      )
                      Ops.set(g, "end", Ops.get_integer(gap, "resize_ext", 0))
                    end
                    deep_copy(g)
                  end
                )
              else
                a = {
                  "extended" => true,
                  "start"    => Ops.add(
                    Ops.get_integer(gap, ["ext_reg", 0], 0),
                    Ops.get_integer(gap, ["ext_reg", 1], 0)
                  ),
                  "end"      => Ops.get_integer(gap, "resize_ext", 0)
                }
                Ops.set(
                  a,
                  "cylinders",
                  Ops.add(
                    Ops.subtract(
                      Ops.get_integer(a, "end", 0),
                      Ops.get_integer(a, "start", 0)
                    ),
                    1
                  )
                )
                Builtins.y2milestone("do_vm_disk_conf add gap %1", a)
                Builtins.y2milestone(
                  "do_vm_disk_conf add gap %1",
                  Ops.get_list(gap, "gap", [])
                )
                Ops.set(
                  gap,
                  "gap",
                  Builtins.add(Ops.get_list(gap, "gap", []), a)
                )
                Builtins.y2milestone(
                  "do_vm_disk_conf add gap %1",
                  Ops.get_list(gap, "gap", [])
                )
              end
            end
            Builtins.y2milestone("do_vm_disk_conf aext gap %1", gap)
          end
          Ops.set(gap, "gap", Builtins.maplist(Ops.get_list(gap, "gap", [])) do |g|
            if Ops.get_boolean(g, "exists", false)
              acur = Builtins.find(Ops.get_list(gap, "gap", [])) do |gg|
                Builtins.size(Ops.get_list(gg, "added", [])) == 0 &&
                  !Ops.get_boolean(gg, "exists", false) &&
                  Ops.get_boolean(gg, "extended", false) ==
                    Ops.get_boolean(g, "extended", false) &&
                  Ops.greater_or_equal(
                    Ops.get_integer(gg, "start", 0),
                    Ops.get_integer(g, "end", 0)
                  ) &&
                  Ops.less_or_equal(
                    Ops.subtract(
                      Ops.get_integer(gg, "start", 0),
                      Ops.get_integer(g, "end", 0)
                    ),
                    1
                  )
              end
              Builtins.y2milestone(
                "do_vm_disk_conf ee:%1 ae:%2",
                Ops.get_integer(g, "end", 0),
                acur
              )
              if acur != nil
                Ops.set(g, "resize", Ops.get_integer(acur, "end", 0))
                Ops.set(g, "fsid", Partitions.fsid_lvm)
              end
            end
            deep_copy(g)
          end)
          sl = Builtins.maplist(Ops.get_list(gap, "gap", [])) do |g|
            Ops.get_integer(g, "resize", -1)
          end
          Builtins.y2milestone("do_vm_disk_conf sl %1", sl)
          Ops.set(gap, "gap", Builtins.filter(Ops.get_list(gap, "gap", [])) do |g|
            !Builtins.contains(sl, Ops.get_integer(g, "end", 0))
          end)
          Ops.set(gap, "gap", Builtins.sort(Ops.get_list(gap, "gap", [])) do |a, b|
            Ops.greater_than(
              Ops.get_integer(a, "cylinders", 0),
              Ops.get_integer(b, "cylinders", 0)
            )
          end)
          Builtins.y2milestone(
            "do_vm_disk_conf sorted gap %1",
            Ops.get_list(gap, "gap", [])
          )
          vg_size = Ops.get_integer(GetControlCfg(), "vm_want", 15 * 1024)
          keep_unpart = Ops.get_boolean(
            GetControlCfg(),
            "vm_keep_unpartitioned_region",
            false
          )
          Ops.set(gap, "gap", Builtins.maplist(Ops.get_list(gap, "gap", [])) do |g|
            if !Ops.get_boolean(g, "exists", false) &&
                Ops.greater_than(Ops.get_integer(g, "cylinders", 0), 0) &&
                (Ops.get_boolean(g, "extended", false) &&
                  Ops.greater_than(
                    Builtins.size(Ops.get_list(gap, "ext_pnr", [])),
                    0
                  ) ||
                  !Ops.get_boolean(g, "extended", false) &&
                    Ops.greater_than(
                      Builtins.size(Ops.get_list(gap, "free_pnr", [])),
                      0
                    ))
              cyl_num = Ops.get_integer(g, "cylinders", 0) # whole partition as default
              if vg_size != nil && Ops.greater_than(vg_size, 0) && keep_unpart
                # get only limited amount of the gap so that there is free
                # space left (fate #303594)
                Builtins.y2milestone(
                  "do_vm_disk_conf maximum volume group size from control file: %1",
                  vg_size
                )
                cyl_size = Ops.divide(
                  Ops.get_integer(g, "size", 0),
                  Ops.get_integer(g, "cylinders", 0)
                )
                cyl_num = Ops.divide(
                  Ops.multiply(Ops.multiply(vg_size, 1024), 1024),
                  cyl_size
                )
                if Ops.greater_than(cyl_num, Ops.get_integer(g, "cylinders", 0))
                  cyl_num = Ops.get_integer(g, "cylinders", 0)
                end
              end
              key2 = Ops.get_boolean(g, "extended", false) ? "ext_pnr" : "free_pnr"
              Ops.set(
                g,
                "added",
                Builtins.add(
                  Ops.get_list(g, "added", []),
                  [
                    Ops.subtract(
                      Builtins.size(Ops.get_list(conf, "partitions", [])),
                      1
                    ),
                    Ops.get_integer(gap, [key2, 0], 0),
                    cyl_num
                  ]
                )
              )
              Builtins.y2milestone("do_vm_disk_conf added new partition: %1", g)
              Ops.set(
                gap,
                key2,
                Builtins.remove(Ops.get_list(gap, key2, []), 0)
              )
            end
            deep_copy(g)
          end)
          Builtins.y2milestone("do_vm_disk_conf gap %1", gap)
          Ops.set(gap, "gap", Builtins.maplist(Ops.get_list(gap, "gap", [])) do |g|
            if Ops.get_boolean(g, "exists", false) &&
                Ops.get_integer(g, "fsid", 0) != Partitions.fsid_lvm
              Ops.set(g, "fsid", Partitions.fsid_lvm)
            end
            deep_copy(g)
          end)
          Builtins.y2milestone(
            "do_vm_disk_conf end gap %1",
            Ops.get_list(gap, "gap", [])
          )
          Ops.set(sol, "solution", gap)
        end
        Ops.set(ret, "disk", process_partition_data(dev, sol, key))
      end
      Builtins.y2milestone(
        "do_vm_disk_conf ret %1",
        Ops.get_boolean(ret, "ok", false)
      )
      if Ops.get_boolean(ret, "ok", false)
        Builtins.y2milestone(
          "do_vm_disk_conf parts %1",
          Ops.get_list(ret, ["disk", "partitions"], [])
        )
      end
      deep_copy(ret)
    end


    def restrict_disk_names(disks)
      disks = deep_copy(disks)
      helper = lambda do |s|
        count = 0
        disks = Builtins.filter(disks) do |dist|
          next true if Builtins.search(dist, s) != 0
          count = Ops.add(count, 1)
          Ops.less_or_equal(count, 16)
        end

        nil
      end

      helper.call("/dev/sd")
      helper.call("/dev/hd")
      helper.call("/dev/cciss/")
      helper.call("/dev/dasd")

      Builtins.y2milestone("restrict_disk_names: ret %1", disks)
      deep_copy(disks)
    end


    def do_pflex(target, conf)
      target = deep_copy(target)
      conf = deep_copy(conf)
      ret = {}
      Ops.set(ret, "ok", false)
      solutions = []
      @cur_mode = :free
      if Ops.greater_than(Builtins.size(conf), 0)
        ddev = Builtins.maplist(Builtins.filter(target) do |l, f|
          !ignore_disk(l, f, false)
        end) { |k, e| k }
        ddev = Builtins.sort(ddev)
        Builtins.y2milestone("do_pflex ddev %1", ddev)
        tc = {}
        dtmp = {}
        Builtins.foreach(Ops.get_list(conf, "partitions", [])) do |p|
          dprio = Ops.get_integer(p, "disk", 0)
          if Builtins.haskey(dtmp, dprio)
            Ops.set(dtmp, dprio, Builtins.add(Ops.get_list(dtmp, dprio, []), p))
          else
            Ops.set(dtmp, dprio, [p])
          end
        end
        Builtins.y2milestone("do_pflex dlist %1", dtmp)
        dlist = Builtins.maplist(dtmp) { |k, e| e }
        Builtins.y2milestone("do_pflex dlist %1", dlist)
        if Ops.greater_than(Builtins.size(dlist), Builtins.size(ddev))
          idx = Builtins.size(ddev)
          while Ops.less_than(idx, Builtins.size(dlist))
            Ops.set(
              dlist,
              Ops.subtract(Builtins.size(ddev), 1),
              Builtins.union(
                Ops.get_list(dlist, Ops.subtract(Builtins.size(ddev), 1), []),
                Ops.get_list(dlist, idx, [])
              )
            )
            idx = Ops.add(idx, 1)
          end
          while Ops.greater_than(Builtins.size(dlist), Builtins.size(ddev))
            dlist = Builtins.remove(dlist, Builtins.size(ddev))
          end
          Builtins.y2milestone("do_pflex dlist %1", dlist)
        end
        save_dlist = Builtins.eval(dlist)
        begin
          count = 0
          begin
            td = Builtins.eval(ddev)
            idx = 0
            Builtins.y2milestone("do_pflex start while count %1", count)
            while Ops.less_than(idx, Builtins.size(dlist)) &&
                Ops.less_than(count, Builtins.size(dlist))
              Builtins.y2milestone("do_pflex in while idx %1", idx)
              tc = Builtins.eval(conf)
              Ops.set(
                tc,
                "partitions",
                Builtins.eval(Ops.get_list(dlist, idx, []))
              )
              md = find_matching_disk(td, target, tc)
              Builtins.y2milestone("do_pflex size(md) %1", Builtins.size(md))
              if Ops.greater_than(Builtins.size(md), 0)
                solutions = Builtins.add(solutions, md)
                td = Builtins.filter(td) do |e|
                  e != Ops.get_string(md, "device", "")
                end
                Builtins.y2milestone("do_pflex new td %1", td)
                idx = Ops.add(idx, 1)
              else
                Builtins.y2milestone("do_pflex no solution")
                idx = Builtins.size(dlist)
                td = Builtins.eval(ddev)
                solutions = []
                count = Ops.add(count, 1)
                if Ops.greater_than(Builtins.size(dlist), 1)
                  tfi = Ops.get_list(dlist, 0, [])
                  dlist = Builtins.remove(dlist, 0)
                  dlist = Builtins.add(dlist, tfi)
                  Builtins.y2milestone("do_pflex new rot dlist %1", dlist)
                end
              end
            end
          end until Ops.greater_than(Builtins.size(solutions), 0) ||
            Ops.greater_or_equal(count, Builtins.size(dlist))
          if Builtins.size(solutions) == 0 &&
              Ops.greater_than(Builtins.size(dlist), 1)
            dlist = Builtins.eval(save_dlist)
            Ops.set(
              dlist,
              Ops.subtract(Builtins.size(dlist), 2),
              Builtins.union(
                Ops.get_list(dlist, Ops.subtract(Builtins.size(dlist), 2), []),
                Ops.get_list(dlist, Ops.subtract(Builtins.size(dlist), 1), [])
              )
            )
            dlist = Builtins.remove(
              dlist,
              Ops.subtract(Builtins.size(dlist), 1)
            )
            Builtins.y2milestone("do_pflex new truncated dlist %1", dlist)
            save_dlist = Builtins.eval(dlist)
          end
        end until Ops.greater_than(Builtins.size(solutions), 0) ||
          Ops.less_or_equal(Builtins.size(dlist), 1)
        if Builtins.size(solutions) == 0 &&
            (Ops.greater_than(
              Builtins.size(Ops.get_list(conf, "keep_partition_fsys", [])),
              0
            ) ||
              Ops.greater_than(
                Builtins.size(Ops.get_list(conf, "keep_partition_id", [])),
                0
              ) ||
              Ops.greater_than(
                Builtins.size(Ops.get_list(conf, "keep_partition_num", [])),
                0
              ) ||
              !Ops.get_boolean(conf, "prefer_remove", false))
          Builtins.y2milestone("do_pflex desperate mode")
          tc = Builtins.eval(conf)
          @cur_mode = :desperate
          Ops.set(tc, "keep_partition_fsys", [])
          Ops.set(tc, "keep_partition_id", [])
          Ops.set(tc, "keep_partition_num", [])
          Ops.set(tc, "prefer_remove", true)
          md = find_matching_disk(ddev, target, tc)
          if Ops.greater_than(Builtins.size(md), 0)
            solutions = Builtins.add(solutions, md)
          end
        end
        if Ops.greater_than(Builtins.size(solutions), 0)
          Builtins.foreach(solutions) do |e|
            disk = Ops.get_string(e, "device", "")
            Ops.set(target, disk, process_partition_data(disk, e, ""))
            Builtins.y2milestone(
              "do_pflex solution disk %1 %2",
              disk,
              Ops.get(target, disk, {})
            )
          end
          Ops.set(ret, "ok", true)
          target = Storage.SpecialBootHandling(target)
          Ops.set(ret, "target", DeleteDestroyedLvmVgs(target))
        end
      end
      deep_copy(ret)
    end


    def do_proposal_flexible(target)
      target = deep_copy(target)
      conf = {}
      if ProductFeatures.GetBooleanFeature(
          "partitioning",
          "use_flexible_partitioning"
        )
        conf = read_partition_xml_config
      else
        conf = read_partition_config(pinfo_name)
      end
      Builtins.y2milestone("conf:%1", conf)
      do_pflex(target, conf)
    end


    def find_matching_disk(disks, target, conf)
      disks = deep_copy(disks)
      target = deep_copy(target)
      conf = deep_copy(conf)
      solutions = {}

      @cur_weight = -100000
      @cur_gap = {}
      Builtins.foreach(disks) do |k|
        e = Ops.get_map(target, k, {})
        Builtins.y2milestone("find_matching_disk processing disk %1", k)
        Builtins.y2milestone(
          "find_matching_disk parts %1",
          Ops.get_list(conf, "partitions", [])
        )
        tc = try_add_boot(conf, e, false)
        @cur_mode = :free if @cur_mode != :desperate
        if !Ops.get_boolean(tc, "prefer_remove", false)
          gap = get_gap_info(e, false)
          tc = add_cylinder_info(tc, gap)
          l = get_perfect_list(Ops.get_list(tc, "partitions", []), gap)
          if Ops.greater_than(Builtins.size(l), 0)
            Ops.set(solutions, k, Builtins.eval(l))
            Ops.set(solutions, [k, "disk"], Builtins.eval(e))
          end
          @cur_mode = :reuse
          egap = get_gap_info(e, true)
          if Ops.greater_than(
              Builtins.size(Ops.get_list(egap, "gap", [])),
              Builtins.size(Ops.get_list(gap, "gap", []))
            )
            tc = add_cylinder_info(tc, egap)
            l = get_perfect_list(Ops.get_list(tc, "partitions", []), egap)
            if Ops.greater_than(Builtins.size(l), 0) &&
                (!Builtins.haskey(solutions, k) ||
                  Builtins.haskey(l, "weight") &&
                    Ops.greater_than(
                      Ops.get_integer(l, "weigth", 0),
                      Ops.get_integer(solutions, [k, "weigth"], 0)
                    ))
              Builtins.y2milestone("find_matching_disk solution reuse existing")
              Ops.set(solutions, k, Builtins.eval(l))
              Ops.set(solutions, [k, "disk"], Builtins.eval(e))
            end
          end
          @cur_mode = :resize
          rw = try_resize_windows(e)
          if Builtins.find(Ops.get_list(rw, "partitions", [])) do |p|
              Ops.get_boolean(p, "resize", false)
            end != nil
            egap = get_gap_info(rw, true)
            tc = add_cylinder_info(tc, egap)
            l = get_perfect_list(Ops.get_list(tc, "partitions", []), egap)
            if Ops.greater_than(Builtins.size(l), 0) &&
                (!Builtins.haskey(solutions, k) ||
                  Builtins.haskey(l, "weight") &&
                    Ops.greater_than(
                      Ops.get_integer(l, "weigth", 0),
                      Ops.get_integer(solutions, [k, "weigth"], 0)
                    ))
              Builtins.y2milestone(
                "find_matching_disk solution resizing windows"
              )
              Ops.set(solutions, k, Builtins.eval(l))
              Ops.set(solutions, [k, "disk"], Builtins.eval(rw))
            end
          end
        else
          rp = remove_possible_partitions(e, tc)
          gap = get_gap_info(rp, false)
          tc = add_cylinder_info(tc, gap)
          l = get_perfect_list(Ops.get_list(tc, "partitions", []), gap)
          if Ops.greater_than(Builtins.size(l), 0)
            Ops.set(solutions, k, Builtins.eval(l))
            Ops.set(solutions, [k, "disk"], Builtins.eval(rp))
          end
        end
      end
      ret = {}
      if Ops.greater_than(Builtins.size(solutions), 0)
        Builtins.foreach(solutions) do |k, e|
          Builtins.y2milestone(
            "find_matching_disk disk %1 weight %2",
            k,
            Ops.get_integer(e, "weight", 0)
          )
        end
        disks2 = Builtins.maplist(solutions) { |k, e| k }
        disks2 = Builtins.sort(disks2) do |a, b|
          Ops.greater_than(
            Ops.get_integer(solutions, [a, "weight"], 0),
            Ops.get_integer(solutions, [b, "weight"], 0)
          )
        end
        Builtins.y2milestone("find_matching_disk sorted disks %1", disks2)
        ret = Ops.get(solutions, Ops.get(disks2, 0, ""), {})
        Ops.set(ret, "device", Ops.get(disks2, 0, ""))
      end
      deep_copy(ret)
    end


    def process_partition_data(dev, solution, vgname)
      solution = deep_copy(solution)
      disk = Ops.get_map(solution, "disk", {})
      partitions = []
      value = ""
      remove_boot = false
      if Ops.greater_than(
          Builtins.size(
            Builtins.filter(Ops.get_list(solution, "partitions", [])) do |e|
              Ops.get_string(e, "mount", "") == Partitions.BootMount &&
                Ops.get_boolean(e, "auto_added", false)
            end
          ),
          0
        )
        Builtins.foreach(Ops.get_list(solution, ["solution", "gap"], [])) do |e|
          Builtins.foreach(Ops.get_list(e, "added", [])) do |a|
            pindex = Ops.get_integer(a, 0, 0)
            if Ops.get_string(solution, ["partitions", pindex, "mount"], "") == "/" &&
                Ops.greater_than(
                  Ops.get_integer(disk, "cyl_count", 0),
                  Partitions.BootCyl
                ) &&
                Ops.less_or_equal(
                  Ops.get_integer(e, "end", 0),
                  Partitions.BootCyl
                ) &&
                !need_boot(disk)
              remove_boot = true
            end
          end
        end
      end
      index = 0
      if remove_boot
        Builtins.foreach(Ops.get_list(solution, ["solution", "gap"], [])) do |e|
          nlist = []
          Builtins.foreach(Ops.get_list(e, "added", [])) do |a|
            pindex = Ops.get_integer(a, 0, 0)
            if Ops.get_string(solution, ["partitions", pindex, "mount"], "") ==
                Partitions.BootMount
              rest = Ops.get_integer(a, 2, 0)
              Builtins.y2milestone(
                "process_partition_data remove unneeded %3 %1 cyl %2",
                Ops.get_list(e, "added", []),
                rest,
                Partitions.BootMount
              )
              nlist2 = Builtins.filter(Ops.get_list(e, "added", [])) do |l|
                Ops.get_integer(l, 0, 0) != pindex
              end
              if Ops.greater_than(Builtins.size(nlist2), 0) &&
                  !Ops.get_boolean(e, "exists", false)
                weight = Builtins.maplist(nlist2) do |l|
                  Ops.get_integer(l, 2, 0)
                end
                r = {}
                r = distribute_space(
                  rest,
                  weight,
                  nlist2,
                  Ops.get_list(solution, "partitions", [])
                )
                nlist2 = Builtins.eval(Ops.get_list(r, "added", []))
                Ops.set(
                  solution,
                  ["solution", "gap", index, "cylinders"],
                  Ops.subtract(
                    Ops.get_integer(e, "cylinders", 0),
                    Ops.get_integer(r, "diff", 0)
                  )
                )
              end
              Ops.set(
                solution,
                ["solution", "gap", index, "added"],
                Builtins.eval(nlist2)
              )
            end
            pindex = Ops.add(pindex, 1)
          end
          index = Ops.add(index, 1)
        end
      end
      if Ops.greater_than(
          Ops.get_integer(solution, ["solution", "resize_ext"], 0),
          0
        )
        Ops.set(
          disk,
          "partitions",
          Builtins.maplist(Ops.get_list(disk, "partitions", [])) do |p|
            if Ops.get_symbol(p, "type", :unknown) == :extended
              Ops.set(p, "resize", true)
              Ops.set(p, "ignore_fs", true)
              Ops.set(
                p,
                ["region", 1],
                Ops.add(
                  Ops.subtract(
                    Ops.get_integer(solution, ["solution", "resize_ext"], 0),
                    Ops.get_integer(p, ["region", 0], 0)
                  ),
                  1
                )
              )
              Ops.set(
                p,
                "size_k",
                Ops.divide(
                  Ops.multiply(
                    Ops.get_integer(p, ["region", 1], 0),
                    Ops.get_integer(disk, "cyl_size", 0)
                  ),
                  1024
                )
              )
              Builtins.y2milestone("process_partition_data resize ext %1", p)
            end
            deep_copy(p)
          end
        )
      end
      Builtins.foreach(Ops.get_list(solution, ["solution", "gap"], [])) do |e|
        Builtins.y2milestone("process_partition_data e %1", e)
        if Ops.get_boolean(e, "exists", false)
          index2 = 0
          pindex = Ops.get_integer(e, ["added", 0, 0], 0)
          mount = Ops.get_string(solution, ["partitions", pindex, "mount"], "")
          fsid = Partitions.fsid_native
          fsid = Partitions.fsid_swap if mount == "swap"
          if Ops.get_integer(solution, ["partitions", pindex, "id"], 0) != 0
            fsid = Ops.get_integer(solution, ["partitions", pindex, "id"], 0)
          end
          Builtins.foreach(Ops.get_list(disk, "partitions", [])) do |p|
            if Ops.get_integer(p, "nr", 0) ==
                Ops.get_integer(e, ["added", 0, 1], 0)
              Builtins.y2milestone("process_partition_data reuse part %1", p)
              if Ops.get_string(p, "mount", "") != mount
                Ops.set(p, "inactive", true)
              end
              p = Storage.SetVolOptions(
                p,
                mount,
                Ops.get_symbol(
                  solution,
                  ["partitions", pindex, "fsys"],
                  :unknown
                ),
                Ops.get_string(solution, ["partitions", pindex, "fopt"], ""),
                Ops.get_string(solution, ["partitions", pindex, "fstopt"], ""),
                Ops.get_string(solution, ["partitions", pindex, "label"], "")
              )
              if Ops.get_integer(p, "fsid", 0) != fsid
                Ops.set(p, "change_fsid", true)
                Ops.set(p, "ori_fsid", Ops.get_integer(p, "fsid", 0))
                Ops.set(p, "fsid", fsid)
              end
              if Builtins.size(mount) == 0 &&
                  Ops.greater_than(Builtins.size(vgname), 0) &&
                  Ops.get_symbol(p, "type", :unknown) != :extended
                Ops.set(p, "vg", vgname)
              end
              Ops.set(disk, ["partitions", index2], p)
              Builtins.y2milestone(
                "process_partition_data reuse auto part %1",
                p
              )
            elsif (Ops.greater_than(Builtins.size(vgname), 0) ||
                Ops.greater_than(Ops.get_integer(e, "resize", 0), 0)) &&
                Ops.get_integer(p, "nr", 0) == Ops.get_integer(e, "nr", 0)
              if Ops.get_integer(e, "fsid", 0) != 0 &&
                  Ops.get_integer(e, "fsid", 0) != Ops.get_integer(p, "fsid", 0)
                Ops.set(p, "change_fsid", true)
                Ops.set(p, "ori_fsid", Ops.get_integer(p, "fsid", 0))
                Ops.set(p, "fsid", Ops.get_integer(e, "fsid", 0))
              end
              if Ops.greater_than(Ops.get_integer(e, "resize", 0), 0)
                Ops.set(p, "resize", true)
                Ops.set(p, "ignore_fs", true)
                Ops.set(
                  p,
                  ["region", 1],
                  Ops.add(
                    Ops.subtract(
                      Ops.get_integer(e, "resize", 0),
                      Ops.get_integer(p, ["region", 0], 0)
                    ),
                    1
                  )
                )
                Ops.set(
                  p,
                  "size_k",
                  Ops.divide(
                    Ops.multiply(
                      Ops.get_integer(p, ["region", 1], 0),
                      Ops.get_integer(disk, "cyl_size", 0)
                    ),
                    1024
                  )
                )
              end
              if Ops.greater_than(Builtins.size(vgname), 0)
                Ops.set(p, "vg", vgname)
              end
              Ops.set(disk, ["partitions", index2], p)
              Builtins.y2milestone("process_partition_data resize part %1", p)
            end
            index2 = Ops.add(index2, 1)
          end
        else
          region = [
            Ops.get_integer(e, "start", 0),
            Ops.add(
              Ops.subtract(
                Ops.get_integer(e, "end", 0),
                Ops.get_integer(e, "start", 0)
              ),
              1
            )
          ]
          part = {}
          if Ops.get_boolean(e, "extended", false) &&
              Ops.greater_than(Ops.get_integer(e, "created", 0), 0)
            while Ops.less_or_equal(
                Ops.get_integer(
                  e,
                  ["added", 0, 1],
                  Ops.add(Ops.get_integer(disk, "max_primary", 4), 1)
                ),
                Ops.get_integer(disk, "max_primary", 4)
              )
              pindex = Ops.get_integer(e, ["added", 0, 0], 0)
              mount = Ops.get_string(
                solution,
                ["partitions", pindex, "mount"],
                ""
              )
              fsid = Partitions.fsid_native
              fsid = Partitions.fsid_swap if mount == "swap"
              Ops.set(part, "create", true)
              Ops.set(part, "nr", Ops.get_integer(e, "created", 0))
              Ops.set(
                part,
                "device",
                Storage.GetDeviceName(dev, Ops.get_integer(part, "nr", -1))
              )
              Ops.set(part, "region", region)
              Ops.set(
                part,
                ["region", 1],
                Ops.get_integer(e, ["added", 0, 2], 0)
              )
              Ops.set(
                region,
                0,
                Ops.add(
                  Ops.get_integer(region, 0, 0),
                  Ops.get_integer(part, ["region", 1], 0)
                )
              )
              Ops.set(
                region,
                1,
                Ops.subtract(
                  Ops.get_integer(region, 1, 0),
                  Ops.get_integer(part, ["region", 1], 0)
                )
              )
              Ops.set(part, "type", :primary)
              Ops.set(part, "inactive", true)
              part = Storage.SetVolOptions(
                part,
                mount,
                Ops.get_symbol(
                  solution,
                  ["partitions", pindex, "fsys"],
                  :unknown
                ),
                Ops.get_string(solution, ["partitions", pindex, "fopt"], ""),
                Ops.get_string(solution, ["partitions", pindex, "fstopt"], ""),
                Ops.get_string(solution, ["partitions", pindex, "label"], "")
              )
              if Ops.get_integer(solution, ["partitions", pindex, "id"], 0) != 0
                fsid = Ops.get_integer(
                  solution,
                  ["partitions", pindex, "id"],
                  0
                )
                if !Builtins.haskey(
                    Ops.get_map(solution, ["partitions", pindex], {}),
                    "fsys"
                  )
                  Ops.set(part, "format", false)
                end
              end
              Ops.set(
                part,
                "size_k",
                Ops.divide(
                  Ops.multiply(
                    Ops.get_integer(part, ["region", 1], 0),
                    Ops.get_integer(disk, "cyl_size", 0)
                  ),
                  1024
                )
              )
              Ops.set(part, "fsid", fsid)
              Ops.set(part, "fstype", Partitions.FsIdToString(fsid))
              if Builtins.size(mount) == 0 &&
                  Ops.greater_than(Builtins.size(vgname), 0)
                Ops.set(part, "vg", vgname)
              end
              Builtins.y2milestone(
                "process_partition_data auto partition %1",
                part
              )
              partitions = Builtins.add(partitions, part)
              Ops.set(e, "created", Ops.get_integer(e, ["added", 0, 1], 0))
              Ops.set(
                e,
                "added",
                Builtins.remove(Ops.get_list(e, "added", []), 0)
              )
              part = {}
            end
            Ops.set(part, "create", true)
            Ops.set(part, "nr", Ops.get_integer(e, "created", 0))
            Ops.set(
              part,
              "device",
              Storage.GetDeviceName(dev, Ops.get_integer(part, "nr", -1))
            )
            Ops.set(part, "region", Builtins.eval(region))
            Ops.set(part, "type", :extended)
            Ops.set(part, "fsid", Partitions.fsid_extended_win)
            Ops.set(
              part,
              "fstype",
              Partitions.FsIdToString(Ops.get_integer(part, "fsid", 0))
            )
            Ops.set(
              part,
              "size_k",
              Ops.divide(
                Ops.multiply(
                  Ops.get_integer(region, 1, 0),
                  Ops.get_integer(disk, "cyl_size", 0)
                ),
                1024
              )
            )
            Builtins.y2milestone(
              "process_partition_data extended auto partition %1",
              part
            )
            partitions = Builtins.add(partitions, Builtins.eval(part))
          end
          Builtins.foreach(Ops.get_list(e, "added", [])) do |a|
            part = {}
            pindex = Ops.get_integer(a, 0, 0)
            mount = Ops.get_string(
              solution,
              ["partitions", pindex, "mount"],
              ""
            )
            fsid = Partitions.fsid_native
            fsid = Partitions.fsid_swap if mount == "swap"
            Ops.set(part, "create", true)
            Ops.set(part, "nr", Ops.get_integer(a, 1, 0))
            Ops.set(
              part,
              "device",
              Storage.GetDeviceName(dev, Ops.get_integer(part, "nr", 0))
            )
            Ops.set(region, 1, Ops.get_integer(a, 2, 0))
            Ops.set(part, "region", Builtins.eval(region))
            Ops.set(
              region,
              0,
              Ops.add(
                Ops.get_integer(region, 0, 0),
                Ops.get_integer(region, 1, 0)
              )
            )
            Ops.set(
              part,
              "size_k",
              Ops.divide(
                Ops.multiply(
                  Ops.get_integer(region, 1, 0),
                  Ops.get_integer(disk, "cyl_size", 0)
                ),
                1024
              )
            )
            Ops.set(part, "type", :primary)
            if Ops.get_boolean(e, "extended", false)
              Ops.set(part, "type", :logical)
            end
            Ops.set(part, "inactive", true)
            part = Storage.SetVolOptions(
              part,
              mount,
              Ops.get_symbol(solution, ["partitions", pindex, "fsys"], :unknown),
              Ops.get_string(solution, ["partitions", pindex, "fopt"], ""),
              Ops.get_string(solution, ["partitions", pindex, "fstopt"], ""),
              Ops.get_string(solution, ["partitions", pindex, "label"], "")
            )
            if Ops.get_integer(solution, ["partitions", pindex, "id"], 0) != 0
              fsid = Ops.get_integer(solution, ["partitions", pindex, "id"], 0)
              if !Builtins.haskey(
                  Ops.get_map(solution, ["partitions", pindex], {}),
                  "fsys"
                )
                Ops.set(part, "format", false)
              end
              Builtins.y2milestone(
                "process_partition_data partition id %1 format %2 part %3",
                fsid,
                Ops.get_boolean(part, "format", false),
                Ops.get_map(solution, ["partitions", pindex], {})
              )
            end
            Ops.set(part, "fsid", fsid)
            Ops.set(part, "fstype", Partitions.FsIdToString(fsid))
            if Builtins.size(mount) == 0 &&
                Ops.greater_than(Builtins.size(vgname), 0)
              Ops.set(part, "vg", vgname)
            end
            Builtins.y2milestone(
              "process_partition_data auto partition %1",
              part
            )
            partitions = Builtins.add(partitions, Builtins.eval(part))
          end
          partitions = Builtins.sort(partitions) do |a, b|
            Ops.less_than(
              Ops.get_integer(a, "nr", 0),
              Ops.get_integer(b, "nr", 0)
            )
          end
        end
      end
      Ops.set(
        disk,
        "partitions",
        Builtins.union(Ops.get_list(disk, "partitions", []), partitions)
      )
      Builtins.y2milestone("process_partition_data disk %1", disk)
      deep_copy(disk)
    end


    def add_cylinder_info(conf, gap)
      conf = deep_copy(conf)
      gap = deep_copy(gap)
      cyl_size = Ops.get_integer(gap, "cyl_size", 1)
      Ops.set(
        conf,
        "partitions",
        Builtins.sort(Ops.get_list(conf, "partitions", [])) do |a, b|
          if Ops.get_boolean(a, "primary", false) !=
              Ops.get_boolean(b, "primary", false)
            next true
          elsif Ops.get_integer(a, "max_cyl", @big_cyl) !=
              Ops.get_integer(b, "max_cyl", @big_cyl)
            next Ops.less_than(
              Ops.get_integer(a, "max_cyl", @big_cyl),
              Ops.get_integer(b, "max_cyl", @big_cyl)
            )
          else
            next Ops.less_than(
              Ops.get_integer(a, "size", 0),
              Ops.get_integer(b, "size", 0)
            )
          end
        end
      )
      Builtins.y2milestone(
        "add_cylinder_info parts %1",
        Ops.get_list(conf, "partitions", [])
      )
      sum = 0
      Ops.set(
        conf,
        "partitions",
        Builtins.maplist(Ops.get_list(conf, "partitions", [])) do |p|
          sum = Ops.add(sum, Ops.get_integer(p, "pct", 0))
          Ops.set(
            p,
            "cylinders",
            Ops.divide(
              Ops.subtract(Ops.add(Ops.get_integer(p, "size", 0), cyl_size), 1),
              cyl_size
            )
          )
          Ops.set(p, "cylinders", 1) if Ops.get_integer(p, "cylinders", 0) == 0
          deep_copy(p)
        end
      )
      Builtins.y2milestone("add_cylinder_info sum %1", sum)
      Builtins.y2milestone(
        "add_cylinder_info parts %1",
        Ops.get_list(conf, "partitions", [])
      )
      if Ops.greater_than(sum, 100)
        rest = Ops.subtract(sum, 100)
        Ops.set(
          conf,
          "partitions",
          Builtins.maplist(Ops.get_list(conf, "partitions", [])) do |p|
            if Builtins.haskey(p, "pct")
              pct = Ops.get_integer(p, "pct", 0)
              diff = Ops.divide(
                Ops.add(Ops.multiply(rest, pct), Ops.divide(sum, 2)),
                sum
              )
              sum = Ops.subtract(sum, pct)
              rest = Ops.subtract(rest, diff)
              Ops.set(p, "pct", Ops.subtract(pct, diff))
            end
            deep_copy(p)
          end
        )
      end
      Ops.set(
        conf,
        "partitions",
        Builtins.maplist(Ops.get_list(conf, "partitions", [])) do |p|
          if Builtins.haskey(p, "pct")
            cyl = Ops.multiply(
              Ops.divide(Ops.get_integer(gap, "sum", 0), 100),
              Ops.get_integer(p, "pct", 0)
            )
            cyl = Ops.divide(Ops.add(cyl, Ops.divide(cyl_size, 2)), cyl_size)
            cyl = 1 if cyl == 0
            Ops.set(p, "want_cyl", cyl)
          end
          if Ops.greater_than(Ops.get_integer(p, "maxsize", 0), 0)
            cyl = Ops.divide(
              Ops.subtract(
                Ops.add(Ops.get_integer(p, "maxsize", 0), cyl_size),
                1
              ),
              cyl_size
            )
            Ops.set(p, "size_max_cyl", cyl)
            if Ops.greater_than(Ops.get_integer(p, "want_cyl", 0), cyl)
              Ops.set(p, "want_cyl", cyl)
            end
          end
          deep_copy(p)
        end
      )
      Builtins.y2milestone(
        "add_cylinder_info parts %1",
        Ops.get_list(conf, "partitions", [])
      )
      deep_copy(conf)
    end


    def get_perfect_list(ps, g)
      ps = deep_copy(ps)
      g = deep_copy(g)
      Builtins.y2milestone("get_perfect_list ps %1", ps)
      Builtins.y2milestone("get_perfect_list gap %1", g)
      if Ops.greater_than(Builtins.size(Ops.get_list(g, "gap", [])), 0) &&
          (Ops.get_boolean(g, "extended_possible", false) &&
            Ops.greater_than(Builtins.size(Ops.get_list(g, "free_pnr", [])), 0) &&
            Ops.less_or_equal(
              Ops.add(Builtins.size(ps), 1),
              Ops.add(
                Builtins.size(Ops.get_list(g, "ext_pnr", [])),
                Builtins.size(Ops.get_list(g, "free_pnr", []))
              )
            ) ||
            !Ops.get_boolean(g, "extended_possible", false) &&
              Ops.less_or_equal(
                Builtins.size(ps),
                Ops.add(
                  Builtins.size(Ops.get_list(g, "ext_pnr", [])),
                  Builtins.size(Ops.get_list(g, "free_pnr", []))
                )
              ))
        lg = Builtins.eval(g)
        Ops.set(lg, "gap", Builtins.maplist(Ops.get_list(lg, "gap", [])) do |e|
          Ops.set(e, "orig_cyl", Ops.get_integer(e, "cylinders", 0))
          Ops.set(e, "added", [])
          deep_copy(e)
        end)
        Ops.set(lg, "procpart", 0)
        lp = Builtins.eval(ps)
        if Ops.get_boolean(g, "extended_possible", false) &&
            !Partitions.BootPrimary() &&
            Ops.greater_than(
              Ops.add(Builtins.size(ps), 1),
              Builtins.size(Ops.get_list(g, "free_pnr", []))
            )
          Builtins.y2milestone("get_perfect_list creating extended")
          index = 0
          Builtins.foreach(Ops.get_list(lg, "gap", [])) do |e|
            if !Ops.get_boolean(e, "exists", false)
              gap = Builtins.eval(lg)
              Ops.set(
                gap,
                ["gap", index, "created"],
                Ops.get_integer(gap, ["free_pnr", 0], 1)
              )
              Ops.set(
                gap,
                "free_pnr",
                Builtins.remove(
                  Convert.convert(
                    Ops.get(gap, "free_pnr") { [1] },
                    :from => "any",
                    :to   => "list <const integer>"
                  ),
                  0
                )
              )
              Ops.set(gap, ["gap", index, "extended"], true)
              add_part_recursive(ps, gap)
            end
            index = Ops.add(index, 1)
          end
        else
          Builtins.y2milestone("get_perfect_list not creating extended")
          add_part_recursive(ps, lg)
        end
      end
      ret = {}
      if Ops.greater_than(Builtins.size(@cur_gap), 0)
        Ops.set(ret, "weight", @cur_weight)
        Ops.set(ret, "solution", Builtins.eval(@cur_gap))
        Ops.set(ret, "partitions", Builtins.eval(ps))
      end
      Builtins.y2milestone(
        "get_perfect_list ret weight %1",
        Ops.get_integer(ret, "weight", -1000000)
      )
      Builtins.y2milestone(
        "get_perfect_list ret solution %1",
        Ops.get_list(ret, ["solution", "gap"], [])
      )
      deep_copy(ret)
    end


    def add_part_recursive(ps, g)
      ps = deep_copy(ps)
      g = deep_copy(g)
      Builtins.y2milestone(
        "add_part_recursive pindex %1",
        Ops.get_integer(g, "procpart", 0)
      )
      Builtins.y2milestone("add_part_recursive ps %1", ps)
      Builtins.y2milestone("add_part_recursive gap %1", g)
      lg = Builtins.eval(g)
      gindex = 0
      pindex = Ops.get_integer(lg, "procpart", 0)
      part = Ops.get_map(ps, pindex, {})
      Ops.set(lg, "procpart", Ops.add(pindex, 1))
      Builtins.y2milestone("add_part_recursive p %1", part)
      Builtins.foreach(Ops.get_list(lg, "gap", [])) do |e|
        Builtins.y2milestone("add_part_recursive e %1", e)
        max_cyl_ok = !Builtins.haskey(part, "max_cyl") ||
          Ops.greater_or_equal(
            Ops.get_integer(part, "max_cyl", 0),
            Ops.get_integer(e, "end", 0)
          )
        if !max_cyl_ok
          cyl = 0
          Builtins.foreach(Ops.get_list(lg, ["gap", gindex, "added"], [])) do |a|
            cyl = Ops.add(
              cyl,
              Ops.get_integer(ps, [Ops.get_integer(a, 0, 0), "cylinders"], 0)
            )
          end
          cyl = Ops.add(cyl, Ops.get_integer(part, "cylinders", 0))
          Builtins.y2milestone("max_cyl_ok cyl %1", cyl)
          max_cyl_ok = Ops.less_or_equal(
            Ops.add(Ops.get_integer(e, "start", 0), cyl),
            Ops.get_integer(part, "max_cyl", 0)
          )
        end
        Builtins.y2milestone("add_part_recursive max_cyl_ok %1", max_cyl_ok)
        if max_cyl_ok &&
            Ops.less_or_equal(
              Ops.get_integer(part, "cylinders", 0),
              Ops.get_integer(e, "cylinders", 0)
            ) &&
            (!Ops.get_boolean(e, "extended", false) &&
              Ops.greater_than(
                Builtins.size(Ops.get_list(lg, "free_pnr", [])),
                0
              ) ||
              Ops.get_boolean(part, "primary", false) &&
                Ops.greater_than(Ops.get_integer(e, "created", 0), 0) &&
                Ops.get_boolean(e, "extended", false) &&
                Ops.greater_than(
                  Builtins.size(Ops.get_list(lg, "free_pnr", [])),
                  0
                ) ||
              !Ops.get_boolean(part, "primary", false) &&
                Ops.get_boolean(e, "extended", false) &&
                Ops.greater_than(
                  Builtins.size(Ops.get_list(lg, "ext_pnr", [])),
                  0
                ))
          llg = Builtins.eval(lg)
          if Ops.get_boolean(e, "exists", false)
            Ops.set(llg, ["gap", gindex, "cylinders"], 0)
          else
            Ops.set(
              llg,
              ["gap", gindex, "cylinders"],
              Ops.subtract(
                Ops.get_integer(llg, ["gap", gindex, "cylinders"], 0),
                Ops.get_integer(part, "cylinders", 0)
              )
            )
          end
          addl = [pindex]
          if Ops.get_boolean(e, "exists", false)
            addl = Builtins.add(addl, Ops.get_integer(e, "nr", 0))
          elsif Ops.get_boolean(e, "extended", false) &&
              !Ops.get_boolean(part, "primary", false)
            addl = Builtins.add(addl, Ops.get_integer(llg, ["ext_pnr", 0], 5))
            Ops.set(
              llg,
              "ext_pnr",
              Builtins.remove(
                Convert.convert(
                  Ops.get(llg, "ext_pnr") { [0] },
                  :from => "any",
                  :to   => "list <const integer>"
                ),
                0
              )
            )
          else
            addl = Builtins.add(addl, Ops.get_integer(llg, ["free_pnr", 0], 1))
            Ops.set(
              llg,
              "free_pnr",
              Builtins.remove(
                Convert.convert(
                  Ops.get(llg, "free_pnr") { [0] },
                  :from => "any",
                  :to   => "list <const integer>"
                ),
                0
              )
            )
          end
          Ops.set(
            llg,
            ["gap", gindex, "added"],
            Builtins.add(Ops.get_list(llg, ["gap", gindex, "added"], []), addl)
          )
          if Ops.less_than(Ops.add(pindex, 1), Builtins.size(ps))
            add_part_recursive(ps, llg)
          else
            ng = normalize_gaps(ps, llg)
            val = do_weighting(ps, ng)
            Builtins.y2milestone(
              "add_part_recursive val %1 cur_weight %2 size %3",
              val,
              @cur_weight,
              Builtins.size(@cur_gap)
            )
            if Ops.greater_than(val, @cur_weight) ||
                Builtins.size(@cur_gap) == 0
              @cur_weight = val
              @cur_gap = Builtins.eval(ng)
            end
          end
        end
        gindex = Ops.add(gindex, 1)
      end

      nil
    end


    def normalize_gaps(ps, g)
      ps = deep_copy(ps)
      g = deep_copy(g)
      Builtins.y2milestone("normalize_gaps gap %1", g)
      gindex = 0
      pindex = 0
      Builtins.foreach(Ops.get_list(g, "gap", [])) do |e|
        Builtins.y2milestone("normalize_gaps e %1", e)
        if Ops.get_boolean(e, "exists", false)
          if Ops.greater_than(Builtins.size(Ops.get_list(e, "added", [])), 0) &&
              Builtins.size(Ops.get_list(e, ["added", 0], [])) == 2
            Ops.set(
              g,
              ["gap", gindex, "added", 0],
              Builtins.add(
                Ops.get_list(e, ["added", 0], []),
                Ops.get_integer(e, "orig_cyl", 1)
              )
            )
          end
        else
          rest = Ops.get_integer(e, "cylinders", 0)
          needed = 0
          tidx = 0
          Builtins.foreach(Ops.get_list(e, "added", [])) do |p|
            tidx = Ops.get_integer(p, 0, 0)
            if Ops.greater_than(
                Ops.get_integer(ps, [tidx, "want_cyl"], 0),
                Ops.get_integer(ps, [tidx, "cylinders"], 0)
              )
              needed = Ops.subtract(
                Ops.add(needed, Ops.get_integer(ps, [tidx, "want_cyl"], 0)),
                Ops.get_integer(ps, [tidx, "cylinders"], 0)
              )
            end
          end
          Builtins.y2milestone("normalize_gaps needed %1 rest %2", needed, rest)
          if Ops.greater_than(needed, rest)
            tr = []
            weight = Builtins.maplist(Ops.get_list(e, "added", [])) do |l|
              idx = Ops.get_integer(l, 0, 0)
              d = Ops.subtract(
                Ops.get_integer(ps, [idx, "want_cyl"], 0),
                Ops.get_integer(ps, [idx, "cylinders"], 0)
              )
              if Ops.greater_than(d, 0)
                l = Builtins.add(l, Ops.get_integer(ps, [idx, "cylinders"], 0))
              end
              tr = Builtins.add(tr, l)
              Ops.greater_than(d, 0) ? d : 0
            end
            Builtins.y2milestone("normalize_gaps tr %1", tr)
            r = {}
            r = distribute_space(rest, weight, tr, ps)
            Ops.set(
              g,
              ["gap", gindex, "added"],
              Builtins.eval(Ops.get_list(r, "added", []))
            )
            Ops.set(
              g,
              ["gap", gindex, "cylinders"],
              Ops.subtract(
                Ops.get_integer(e, "cylinders", 0),
                Ops.get_integer(r, "diff", 0)
              )
            )
            Builtins.y2milestone(
              "normalize_gaps partly satisfy %1 cyl %2",
              Ops.get_list(g, ["gap", gindex, "added"], []),
              Ops.get_integer(g, ["gap", gindex, "cylinders"], 0)
            )
          else
            Ops.set(
              g,
              ["gap", gindex, "cylinders"],
              Ops.subtract(Ops.get_integer(e, "cylinders", 0), needed)
            )
          end

          pindex = 0
          Builtins.foreach(Ops.get_list(g, ["gap", gindex, "added"], [])) do |p|
            if Ops.less_than(Builtins.size(p), 3)
              tidx = Ops.get_integer(p, 0, 0)
              if Ops.greater_than(
                  Ops.get_integer(ps, [tidx, "want_cyl"], 0),
                  Ops.get_integer(ps, [tidx, "cylinders"], 0)
                )
                p = Builtins.add(p, Ops.get_integer(ps, [tidx, "want_cyl"], 0))
              else
                p = Builtins.add(p, Ops.get_integer(ps, [tidx, "cylinders"], 0))
              end
              Ops.set(g, ["gap", gindex, "added", pindex], p)
              Builtins.y2milestone(
                "normalize_gaps satisfy p %1 cyl %2",
                p,
                Ops.get_integer(e, "cylinders", 0)
              )
            end
            pindex = Ops.add(pindex, 1)
          end
          Builtins.y2milestone(
            "normalize_gaps added %1",
            Ops.get_list(g, ["gap", gindex, "added"], [])
          )
        end
        gindex = Ops.add(gindex, 1)
      end
      gindex = 0
      Builtins.foreach(Ops.get_list(g, "gap", [])) do |e|
        if !Ops.get_boolean(e, "exists", false) &&
            Ops.greater_than(Ops.get_integer(e, "cylinders", 0), 0)
          weight = Builtins.maplist(Ops.get_list(e, "added", [])) do |l|
            Ops.get_integer(ps, [Ops.get_integer(l, 0, 0), "size"], 0) == 0 ? 1 : 0
          end
          if Builtins.find(weight) { |l| Ops.greater_than(l, 0) } != nil
            r = {}
            r = distribute_space(
              Ops.get_integer(e, "cylinders", 0),
              weight,
              Ops.get_list(e, "added", []),
              ps
            )
            Ops.set(
              g,
              ["gap", gindex, "added"],
              Builtins.eval(Ops.get_list(r, "added", []))
            )
            Ops.set(
              g,
              ["gap", gindex, "cylinders"],
              Ops.subtract(
                Ops.get_integer(e, "cylinders", 0),
                Ops.get_integer(r, "diff", 0)
              )
            )
            Builtins.y2milestone(
              "normalize_gaps increase max p %1 cyl %2",
              Ops.get_list(g, ["gap", gindex, "added"], []),
              Ops.get_integer(g, ["gap", gindex, "cylinders"], 0)
            )
          end
        end
        gindex = Ops.add(gindex, 1)
      end
      gindex = 0
      Builtins.foreach(Ops.get_list(g, "gap", [])) do |e|
        if !Ops.get_boolean(e, "exists", false) &&
            Ops.greater_than(Ops.get_integer(e, "cylinders", 0), 0) &&
            Ops.less_than(
              Ops.get_integer(e, "cylinders", 0),
              Ops.divide(Ops.get_integer(g, "disk_cyl", 0), 20)
            )
          weight = Builtins.maplist(Ops.get_list(e, "added", [])) do |l|
            Ops.get_integer(l, 2, 0)
          end
          r = {}
          r = distribute_space(
            Ops.get_integer(e, "cylinders", 0),
            weight,
            Ops.get_list(e, "added", []),
            ps
          )
          Ops.set(
            g,
            ["gap", gindex, "added"],
            Builtins.eval(Ops.get_list(r, "added", []))
          )
          Ops.set(
            g,
            ["gap", gindex, "cylinders"],
            Ops.subtract(
              Ops.get_integer(e, "cylinders", 0),
              Ops.get_integer(r, "diff", 0)
            )
          )
          Builtins.y2milestone(
            "normalize_gaps close small gap p %1 cyl %2",
            Ops.get_list(g, ["gap", gindex, "added"], []),
            Ops.get_integer(g, ["gap", gindex, "cylinders"], 0)
          )
        end
        gindex = Ops.add(gindex, 1)
      end
      gindex = 0
      Builtins.foreach(Ops.get_list(g, "gap", [])) do |e|
        if !Ops.get_boolean(e, "exists", false) &&
            Ops.greater_than(Ops.get_integer(e, "cylinders", 0), 0)
          weight = []
          weight = Builtins.maplist(Ops.get_list(e, "added", [])) do |l|
            Ops.get_boolean(
              ps,
              [Ops.get_integer(l, 0, 0), "increasable"],
              false
            ) ? 1 : 0
          end
          Builtins.y2milestone("normalize_gaps w %1", weight)
          if Builtins.find(weight) { |l| Ops.greater_than(l, 0) } != nil
            r = {}
            r = distribute_space(
              Ops.get_integer(e, "cylinders", 0),
              weight,
              Ops.get_list(e, "added", []),
              ps
            )
            Ops.set(
              g,
              ["gap", gindex, "added"],
              Builtins.eval(Ops.get_list(r, "added", []))
            )
            Ops.set(
              g,
              ["gap", gindex, "cylinders"],
              Ops.subtract(
                Ops.get_integer(e, "cylinders", 0),
                Ops.get_integer(r, "diff", 0)
              )
            )
            Ops.set(
              e,
              "cylinders",
              Ops.get_integer(g, ["gap", gindex, "cylinders"], 0)
            )
            Builtins.y2milestone(
              "normalize_gaps increase increasable p %1 cyl %2",
              Ops.get_list(g, ["gap", gindex, "added"], []),
              Ops.get_integer(g, ["gap", gindex, "cylinders"], 0)
            )
          end
        end
        gindex = Ops.add(gindex, 1)
      end
      gindex = 0
      Builtins.foreach(Ops.get_list(g, "gap", [])) do |e|
        if !Ops.get_boolean(e, "exists", false) &&
            Ops.get_boolean(e, "extended", false) &&
            Ops.greater_than(Ops.get_integer(e, "created", 0), 0) &&
            Builtins.size(Ops.get_list(e, "added", [])) == 1 &&
            Ops.get_integer(e, "cylinders", 0) == 0
          Ops.set(g, ["gap", gindex, "extended"], false)
          Ops.set(
            g,
            ["gap", gindex, "added", 0, 1],
            Ops.get_integer(e, "created", 0)
          )
          Builtins.y2milestone(
            "normalize_gaps changed extended %1",
            Ops.get_map(g, ["gap", gindex], {})
          )
        end
        gindex = Ops.add(gindex, 1)
      end
      gindex = 0
      sort_map = {
        "/boot"     => 0,
        "/boot/efi" => 0,
        "/boot/zipl" => 0,
        "swap"      => 1,
        "/"         => 5,
        "/home"     => 6
      }
      Builtins.foreach(Ops.get_list(g, "gap", [])) do |e|
        if !Ops.get_boolean(e, "exists", false) &&
            Ops.greater_than(Builtins.size(Ops.get_list(e, "added", [])), 1)
          Builtins.y2milestone(
            "normalize_gaps old  added %1",
            Ops.get_list(e, "added", [])
          )
          nums = Builtins.maplist(Ops.get_list(e, "added", [])) do |l|
            Ops.get_integer(l, 1, -1)
          end
          Builtins.y2milestone("normalize_gaps old nums %1", nums)
          sdd = Builtins.sort(Ops.get_list(e, "added", [])) do |a, b|
            ai = Ops.get_integer(a, 0, 0)
            bi = Ops.get_integer(b, 0, 0)
            if Ops.get_boolean(ps, [ai, "primary"], false) !=
                Ops.get_boolean(ps, [bi, "primary"], false)
              next Ops.get_boolean(ps, [ai, "primary"], false)
            elsif Ops.get_integer(ps, [ai, "max_cyl"], @big_cyl) !=
                Ops.get_integer(ps, [bi, "max_cyl"], @big_cyl)
              next Ops.less_than(
                Ops.get_integer(ps, [ai, "max_cyl"], @big_cyl),
                Ops.get_integer(ps, [bi, "max_cyl"], @big_cyl)
              )
            else
              next Ops.less_than(
                Ops.get_integer(
                  sort_map,
                  Ops.get_string(ps, [ai, "mount"], ""),
                  3
                ),
                Ops.get_integer(
                  sort_map,
                  Ops.get_string(ps, [bi, "mount"], ""),
                  3
                )
              )
            end
          end
          idx = 0
          Builtins.foreach(
            Convert.convert(sdd, :from => "list", :to => "list <list>")
          ) do |e2|
            Ops.set(sdd, [idx, 1], Ops.get_integer(nums, idx, 0))
            idx = Ops.add(idx, 1)
          end
          Ops.set(g, ["gap", gindex, "added"], sdd)
          Builtins.y2milestone(
            "normalize_gaps sort added %1",
            Ops.get_list(g, ["gap", gindex, "added"], [])
          )
        end
        gindex = Ops.add(gindex, 1)
      end
      Builtins.y2milestone("normalize_gaps gap %1", g)
      deep_copy(g)
    end


    def distribute_space(rest, weights, added, ps)
      weights = deep_copy(weights)
      added = deep_copy(added)
      ps = deep_copy(ps)
      diff_sum = 0
      sum = 0
      index = 0
      pindex = 0
      scount = 0
      Builtins.y2milestone(
        "distribute_space rest %1 weights %2 added %3",
        rest,
        weights,
        added
      )
      loopcount = 0
      begin
        loopcount = Ops.add(loopcount, 1)
        index = 0
        sum = 0
        scount = 0
        Builtins.foreach(
          Convert.convert(added, :from => "list", :to => "list <list>")
        ) do |p|
          pindex = Ops.get_integer(p, 0, 0)
          if Ops.get_integer(ps, [pindex, "size_max_cyl"], 0) == 0 ||
              Ops.greater_than(
                Ops.get_integer(ps, [pindex, "size_max_cyl"], 0),
                Ops.get_integer(p, 2, 0)
              )
            sum = Ops.add(sum, Ops.get_integer(weights, index, 0))
            Builtins.y2milestone(
              "sum %1 weight %2 pindex %3",
              sum,
              Ops.get_integer(weights, index, 0),
              pindex
            )
            scount = Ops.add(scount, 1)
          end
          index = Ops.add(index, 1)
        end
        index = 0
        Builtins.y2milestone(
          "distribute_space sum %1 rest %2 scount %3 added %4 lc %5",
          sum,
          rest,
          scount,
          added,
          loopcount
        )
        Builtins.foreach(
          Convert.convert(added, :from => "list", :to => "list <list>")
        ) do |p|
          pindex = Ops.get_integer(p, 0, 0)
          if Builtins.size(p) == 3 && Ops.greater_than(sum, 0) &&
              (Ops.get_integer(ps, [pindex, "size_max_cyl"], 0) == 0 ||
                Ops.greater_than(
                  Ops.get_integer(ps, [pindex, "size_max_cyl"], 0),
                  Ops.get_integer(p, 2, 0)
                ))
            diff = Ops.divide(
              Ops.add(
                Ops.multiply(rest, Ops.get_integer(weights, index, 0)),
                Ops.divide(sum, 2)
              ),
              sum
            )
            if Ops.greater_than(
                Ops.get_integer(ps, [pindex, "size_max_cyl"], 0),
                0
              ) &&
                Ops.greater_than(
                  diff,
                  Ops.subtract(
                    Ops.get_integer(ps, [pindex, "size_max_cyl"], 0),
                    Ops.get_integer(p, 2, 0)
                  )
                )
              diff = Ops.subtract(
                Ops.get_integer(ps, [pindex, "size_max_cyl"], 0),
                Ops.get_integer(p, 2, 0)
              )
            end
            sum = Ops.subtract(sum, Ops.get_integer(weights, index, 0))
            rest = Ops.subtract(rest, diff)
            Ops.set(
              added,
              [index, 2],
              Ops.add(Ops.get_integer(added, [index, 2], 0), diff)
            )
            diff_sum = Ops.add(diff_sum, diff)
            Builtins.y2milestone(
              "distribute_space sum %1 rest %2 diff %3 added %4",
              sum,
              rest,
              diff,
              Ops.get_list(added, index, [])
            )
          end
          index = Ops.add(index, 1)
        end
      end while Ops.greater_than(rest, 0) && Ops.greater_than(scount, 0) &&
        Ops.less_than(loopcount, 3)
      ret = { "added" => added, "diff" => diff_sum }
      Builtins.y2milestone("distribute_space ret %1", ret)
      deep_copy(ret)
    end


    def do_weighting(ps, g)
      ps = deep_copy(ps)
      g = deep_copy(g)
      Builtins.y2milestone("do_weighting gap %1", Ops.get_list(g, "gap", []))
      ret = 0
      index = 0
      diff = 0
      if @cur_mode == :reuse
        ret = Ops.subtract(ret, 100)
      elsif @cur_mode == :resize
        ret = Ops.subtract(ret, 1000)
      elsif @cur_mode == :desperate
        ret = Ops.subtract(ret, 1000000)
      end
      Builtins.y2milestone("do_weighting after mode ret %1", ret)
      Builtins.foreach(Ops.get_list(g, "gap", [])) do |e|
        Builtins.y2milestone("do_weighting e %1", e)
        if !Ops.get_boolean(e, "exists", false) &&
            Ops.greater_than(Ops.get_integer(e, "cylinders", 0), 0)
          diff = -5
          if Ops.less_than(
              Ops.get_integer(e, "cylinders", 0),
              Ops.divide(Ops.get_integer(g, "disk_cyl", 0), 20)
            )
            diff = Ops.subtract(diff, 10)
          end
          ret = Ops.add(ret, diff)
          Builtins.y2milestone(
            "do_weighting after gaps diff %1 ret %2",
            diff,
            ret
          )
        end
        Builtins.foreach(Ops.get_list(e, "added", [])) do |p|
          index = Ops.get_integer(p, 0, 0)
          if Ops.get_boolean(e, "exists", false) &&
              Ops.get_string(ps, [index, "mount"], "") == "swap" &&
              Ops.get_boolean(e, "swap", false)
            diff = 100
            ret = Ops.add(ret, diff)
            Builtins.y2milestone(
              "do_weighting after swap reuse diff %1 ret %2",
              diff,
              ret
            )
          end
          if Ops.greater_than(Ops.get_integer(ps, [index, "want_cyl"], 0), 0)
            diff = Ops.subtract(
              Ops.get_integer(ps, [index, "want_cyl"], 0),
              Ops.get_integer(p, 2, 0)
            )
            normdiff = Ops.divide(
              Ops.multiply(diff, 100),
              Ops.get_integer(p, 2, 0)
            )
            if Ops.less_than(diff, 0)
              normdiff = Ops.unary_minus(normdiff)
            elsif Ops.greater_than(diff, 0)
              normdiff = Ops.divide(normdiff, 10)
            end
            diff = Ops.subtract(
              Ops.divide(
                Ops.multiply(
                  Ops.get_integer(ps, [index, "want_cyl"], 0),
                  Ops.get_integer(g, "cyl_size", 1)
                ),
                100 * 1024 * 1024
              ),
              normdiff
            )
            ret = Ops.add(ret, diff)
            Builtins.y2milestone(
              "do_weighting after pct parts diff %1 ret %2",
              diff,
              ret
            )
          end
          if Ops.get_integer(ps, [index, "size"], 0) == 0
            diff = Ops.divide(
              Ops.multiply(
                Ops.get_integer(p, 2, 0),
                Ops.get_integer(g, "cyl_size", 1)
              ),
              200 * 1024 * 1024
            )
            ret = Ops.add(ret, diff)
            Builtins.y2milestone(
              "do_weighting after maximizes parts diff %1 ret %2",
              diff,
              ret
            )
          end
          if Ops.greater_than(
              Ops.get_integer(ps, [index, "size_max_cyl"], 0),
              0
            ) &&
              Ops.less_than(
                Ops.get_integer(ps, [index, "size_max_cyl"], 0),
                Ops.get_integer(p, 2, 0)
              )
            diff = Ops.subtract(
              Ops.get_integer(p, 2, 0),
              Ops.get_integer(ps, [index, "size_max_cyl"], 0)
            )
            normdiff = Ops.divide(
              Ops.multiply(diff, 100),
              Ops.get_integer(ps, [index, "size_max_cyl"], 0)
            )
            ret = Ops.subtract(ret, normdiff)
            Builtins.y2milestone(
              "do_weighting after maximal size diff %1 ret %2",
              Ops.unary_minus(normdiff),
              ret
            )
          end
        end
        if Ops.greater_than(Builtins.size(Ops.get_list(e, "added", [])), 0) &&
            Ops.greater_than(Ops.get_integer(e, "cylinders", 0), 0)
          diff2 = Ops.divide(
            Ops.multiply(
              Ops.get_integer(e, "cylinders", 0),
              Ops.get_integer(g, "cyl_size", 1)
            ),
            1024 * 1024 * 1024
          )
          ret = Ops.subtract(ret, diff2)
          Builtins.y2milestone(
            "do_weighting after gap size diff %1 ret %2",
            Ops.unary_minus(diff2),
            ret
          )
        end
        ret = Ops.subtract(ret, 1) if Ops.get_boolean(e, "extended", false)
        Builtins.y2milestone("do_weighting %1", ret)
      end
      Builtins.y2milestone("do_weighting ret %1", ret)
      ret
    end


    def try_remove_sole_extended(parts)
      parts = deep_copy(parts)
      ret = deep_copy(parts)
      if Builtins.find(ret) do |p|
          Ops.get_symbol(p, "type", :unknown) == :extended &&
            !Ops.get_boolean(p, "delete", false)
        end != nil && Builtins.find(
          ret
        ) do |p|
          Ops.get_symbol(p, "type", :unknown) == :logical &&
            !Ops.get_boolean(p, "delete", false)
        end == nil
        ret = Builtins.maplist(ret) do |p|
          if Ops.get_symbol(p, "type", :unknown) == :extended
            Ops.set(p, "delete", true)
          end
          deep_copy(p)
        end
        Builtins.y2milestone(
          "try_remove_sole_extended delete extended p:%1",
          ret
        )
      end
      deep_copy(ret)
    end


    def remove_possible_partitions(disk, conf)
      disk = deep_copy(disk)
      conf = deep_copy(conf)
      ret = Builtins.eval(disk)
      Ops.set(
        ret,
        "partitions",
        Builtins.maplist(Ops.get_list(ret, "partitions", [])) do |p|
          fsid = Ops.get_integer(p, "fsid", 0)
          if (Ops.get_boolean(conf, "remove_special_partitions", false) ||
              !Builtins.contains(Partitions.do_not_delete, fsid)) &&
              Ops.get_symbol(p, "type", :primary) != :extended &&
              !Builtins.contains(
                Ops.get_list(conf, "keep_partition_num", []),
                Ops.get_integer(p, "nr", 0)
              ) &&
              !Builtins.contains(
                Ops.get_list(conf, "keep_partition_id", []),
                fsid
              ) &&
              !Builtins.contains(
                Ops.get_list(conf, "keep_partition_fsys", []),
                Ops.get_symbol(p, "used_fs", :none)
              ) &&
              Storage.CanDelete(p, disk, false)
            Ops.set(p, "delete", true)
          end
          deep_copy(p)
        end
      )
      Ops.set(
        ret,
        "partitions",
        try_remove_sole_extended(Ops.get_list(ret, "partitions", []))
      )
      deep_copy(ret)
    end


    def try_resize_windows(disk)
      disk = deep_copy(disk)
      cyl_size = Ops.get_integer(disk, "cyl_size", 1)
      win = {}
      ret = Builtins.eval(disk)

      Ops.set(
        ret,
        "partitions",
        Builtins.maplist(Ops.get_list(ret, "partitions", [])) do |p|
          fsid = Ops.get_integer(p, "fsid", 0)
          if Partitions.IsDosWinNtPartition(fsid)
            win = Ops.get_map(p, "winfo", {})
            Builtins.y2milestone("try_resize_windows win=%1", win)
            if win != nil && Ops.get_boolean(win, "resize_ok", false) &&
                Ops.greater_than(Ops.get_integer(p, "size_k", 0), 1024 * 1024) &&
                !Ops.get_boolean(win, "efi", false)
              Ops.set(p, "winfo", win)
              Ops.set(p, "resize", true)
              Ops.set(
                p,
                ["region", 1],
                Ops.divide(
                  Ops.subtract(
                    Ops.add(Ops.get_integer(win, "new_size", 0), cyl_size),
                    1
                  ),
                  cyl_size
                )
              )
              Ops.set(
                p,
                "win_max_length",
                Ops.divide(
                  Ops.subtract(
                    Ops.add(Ops.get_integer(win, "max_win_size", 0), cyl_size),
                    1
                  ),
                  cyl_size
                )
              )
              Builtins.y2milestone("try_resize_windows win part %1", p)
            end
          end
          deep_copy(p)
        end
      )
      deep_copy(ret)
    end


    def get_gaps(start, _end, part, add_exist_linux)
      part = deep_copy(part)
      Builtins.y2milestone(
        "get_gaps start %1 end %2 add_exist %3",
        start,
        _end,
        add_exist_linux
      )
      ret = []
      entry = {}
      Builtins.foreach(part) do |p|
        s = Ops.get_integer(p, ["region", 0], 0)
        e = Ops.subtract(Ops.add(s, Ops.get_integer(p, ["region", 1], 1)), 1)
        entry = {}
        if Ops.less_than(start, s)
          Ops.set(entry, "start", start)
          Ops.set(entry, "end", Ops.subtract(s, 1))
          ret = Builtins.add(ret, Builtins.eval(entry))
        end
        if add_exist_linux && Builtins.size(Ops.get_string(p, "mount", "")) == 0 &&
            (Ops.get_integer(p, "fsid", 0) == Partitions.fsid_native ||
              Ops.get_integer(p, "fsid", 0) == Partitions.fsid_swap)
          Ops.set(
            entry,
            "swap",
            Ops.get_integer(p, "fsid", 0) == Partitions.fsid_swap
          )
          Ops.set(entry, "start", s)
          Ops.set(entry, "end", e)
          Ops.set(entry, "exists", true)
          Ops.set(entry, "nr", Ops.get_integer(p, "nr", 0))
          ret = Builtins.add(ret, entry)
        end
        start = Ops.add(e, 1)
      end
      if Ops.less_than(start, _end)
        entry = {}
        Ops.set(entry, "start", start)
        Ops.set(entry, "end", _end)
        ret = Builtins.add(ret, entry)
      end
      Builtins.y2milestone("get_gaps ret %1", ret)
      deep_copy(ret)
    end


    def get_gap_info(disk, add_exist_linux)
      disk = deep_copy(disk)
      ret = {}
      gap = []
      plist = Builtins.filter(Ops.get_list(disk, "partitions", [])) do |p|
        !Ops.get_boolean(p, "delete", false)
      end
      plist = Builtins.sort(plist) do |a, b|
        Ops.less_than(
          Ops.get_integer(a, ["region", 0], 0),
          Ops.get_integer(b, ["region", 0], 0)
        )
      end
      exist_pnr = Builtins.sort(Builtins.maplist(plist) do |e|
        Ops.get_integer(e, "nr", 0)
      end)
      if Ops.get_string(disk, "label", "") == "mac" &&
          !Builtins.contains(exist_pnr, 1)
        exist_pnr = Builtins.add(exist_pnr, 1)
      end
      max_prim = Partitions.MaxPrimary(Ops.get_string(disk, "label", "msdos"))
      has_ext = Partitions.HasExtended(Ops.get_string(disk, "label", "msdos"))
      max_pos_cyl = Storage.MaxCylLabel(disk, 0)
      _end = 0
      if has_ext
        ext = Ops.get(Builtins.filter(plist) do |p|
          Ops.get_symbol(p, "type", :primary) == :extended
        end, 0, {})
        Ops.set(ret, "extended_possible", Builtins.size(ext) == 0)
        Ops.set(ret, "ext_reg", Ops.get_list(ext, "region", []))
        if Ops.greater_than(Builtins.size(ext), 0)
          _end = Ops.subtract(
            Ops.add(
              Ops.get_integer(ext, ["region", 0], 0),
              Ops.get_integer(ext, ["region", 1], 1)
            ),
            1
          )
          if Ops.greater_than(
              _end,
              Ops.add(Ops.get_integer(ext, ["region", 0], 0), max_pos_cyl)
            )
            _end = Ops.add(Ops.get_integer(ext, ["region", 0], 0), max_pos_cyl)
          end
          gap = get_gaps(
            Ops.get_integer(ext, ["region", 0], 0),
            _end,
            Builtins.filter(plist) do |p|
              Ops.greater_than(Ops.get_integer(p, "nr", 0), max_prim)
            end,
            add_exist_linux
          )
          gap = Builtins.maplist(gap) do |e|
            Ops.set(e, "extended", true)
            deep_copy(e)
          end
          plist = Builtins.filter(plist) do |p|
            Ops.less_or_equal(Ops.get_integer(p, "nr", 0), max_prim)
          end
        end
      else
        Ops.set(ret, "extended_possible", false)
      end
      _end = Ops.subtract(Ops.get_integer(disk, "cyl_count", 1), 1)
      _end = max_pos_cyl if Ops.greater_than(_end, max_pos_cyl)
      start = 0
      start = 1 if Ops.get_string(disk, "label", "") == "sun"
      gap = Convert.convert(
        Builtins.union(gap, get_gaps(start, _end, plist, add_exist_linux)),
        :from => "list",
        :to   => "list <map>"
      )
      av_size = 0
      gap = Builtins.maplist(gap) do |e|
        Ops.set(
          e,
          "cylinders",
          Ops.add(
            Ops.subtract(
              Ops.get_integer(e, "end", 0),
              Ops.get_integer(e, "start", 0)
            ),
            1
          )
        )
        Ops.set(
          e,
          "size",
          Ops.multiply(
            Ops.get_integer(e, "cylinders", 0),
            Ops.get_integer(disk, "cyl_size", 1)
          )
        )
        av_size = Ops.add(av_size, Ops.get_integer(e, "size", 0))
        deep_copy(e)
      end
      gap = Builtins.maplist(gap) do |e|
        Ops.set(
          e,
          "sizepct",
          Ops.divide(
            Ops.divide(Ops.multiply(Ops.get_integer(e, "size", 0), 201), 2),
            av_size
          )
        )
        Ops.set(e, "sizepct", 1) if Ops.get_integer(e, "sizepct", 0) == 0
        deep_copy(e)
      end
      Ops.set(ret, "cyl_size", Ops.get_integer(disk, "cyl_size", 1))
      Ops.set(ret, "disk_cyl", Ops.get_integer(disk, "cyl_count", 1))
      Ops.set(ret, "sum", av_size)
      max_pnr = max_prim
      pnr = 1
      free_pnr = []
      Builtins.y2milestone("get_gap_info exist_pnr %1", exist_pnr)
      while Ops.less_or_equal(pnr, max_pnr)
        if !Builtins.contains(exist_pnr, pnr)
          free_pnr = Builtins.add(free_pnr, pnr)
        end
        pnr = Ops.add(pnr, 1)
      end
      Ops.set(ret, "free_pnr", free_pnr)
      ext_pnr = [
        5,
        6,
        7,
        8,
        9,
        10,
        11,
        12,
        13,
        14,
        15,
        16,
        17,
        18,
        19,
        20,
        21,
        22,
        23,
        24,
        25,
        26,
        27,
        28,
        29,
        30,
        31,
        32,
        33,
        34,
        35,
        36,
        37,
        38,
        39,
        40,
        41,
        42,
        43,
        44,
        45,
        46,
        47,
        48,
        49,
        50,
        51,
        52,
        53,
        54,
        55,
        56,
        57,
        58,
        59,
        60,
        61,
        62,
        63
      ]
      max_logical = Ops.get_integer(disk, "max_logical", 15)
      ext_pnr = Builtins.filter(ext_pnr) do |i|
        Ops.less_or_equal(i, max_logical)
      end if Ops.less_than(
        max_logical,
        63
      )
      if !has_ext
        ext_pnr = []
      else
        maxlog = Ops.add(Builtins.size(Builtins.filter(exist_pnr) do |i|
          Ops.greater_than(i, max_pnr)
        end), 4)
        ext_pnr = Builtins.filter(ext_pnr) { |i| Ops.greater_than(i, maxlog) }
      end
      Ops.set(ret, "ext_pnr", ext_pnr)
      Ops.set(ret, "gap", gap)
      Builtins.y2milestone("get_gap_info ret %1", ret)
      deep_copy(ret)
    end


    def read_partition_xml_config
      xmlflex = Convert.to_map(
        ProductFeatures.GetFeature("partitioning", "flexible_partitioning")
      )
      Builtins.y2milestone("xml input: %1", xmlflex)

      conf = {}
      Ops.set(
        conf,
        "prefer_remove",
        Ops.get_boolean(xmlflex, "prefer_remove", true)
      )
      Ops.set(
        conf,
        "remove_special_partitions",
        Ops.get_boolean(xmlflex, "remove_special_partitions", false)
      )
      Ops.set(conf, "keep_partition_id", [])
      Ops.set(conf, "keep_partition_num", [])
      Ops.set(conf, "keep_partition_fsys", [])

      Builtins.foreach(["keep_partition_id", "keep_partition_num"]) do |key|
        num = []
        nlist2 = Builtins.splitstring(Ops.get_string(xmlflex, key, ""), ",")
        Builtins.foreach(nlist2) do |n|
          num = Builtins.union(num, [Builtins.tointeger(n)])
        end
        Ops.set(conf, key, num)
      end

      fsys = []
      nlist = Builtins.splitstring(
        Ops.get_string(xmlflex, "keep_partition_fsys", ""),
        ","
      )
      Builtins.foreach(nlist) do |n|
        fs = FileSystems.FsToSymbol(n)
        fsys = Builtins.union(fsys, [fs]) if fs != :none
      end
      Ops.set(conf, "keep_partition_fsys", fsys)
      partitions = []
      Builtins.foreach(Ops.get_list(xmlflex, "partitions", [])) do |p|
        partition = {}
        if Ops.get_integer(p, "disk", 0) != 0
          Ops.set(partition, "disk", Ops.get_integer(p, "disk", 0))
        end
        if Ops.get_integer(p, "id", 0) != 0
          Ops.set(partition, "id", Ops.get_integer(p, "id", 0))
        end
        if Ops.get_string(p, "fstopt", "") != ""
          Ops.set(partition, "fstopt", Ops.get_string(p, "fstopt", ""))
        end
        if Ops.get_string(p, "formatopt", "") != ""
          Ops.set(partition, "fopt", Ops.get_string(p, "formatopt", ""))
        end
        Ops.set(
          partition,
          "increasable",
          Ops.get_boolean(p, "increasable", false)
        )
        if Ops.get_string(p, "mount", "") != ""
          Ops.set(partition, "mount", Ops.get_string(p, "mount", ""))
        end
        if Ops.get_integer(p, "percent", -1) != -1
          Ops.set(partition, "pct", Ops.get_integer(p, "percent", 100))
        end
        if Ops.get_string(p, "label", "") != ""
          Ops.set(partition, "label", Ops.get_string(p, "label", ""))
        end
        if Ops.get_string(p, "maxsize", "") != ""
          Ops.set(
            partition,
            "maxsize",
            Storage.ClassicStringToByte(Ops.get_string(p, "maxsize", ""))
          )
        end
        if Ops.get_string(p, "fsys", "") != ""
          fs = FileSystems.FsToSymbol(Ops.get_string(p, "fsys", ""))
          Ops.set(partition, "fsys", fs) if fs != :none
        end
        if Ops.get_string(p, "size", "") != ""
          s = Ops.get_string(p, "size", "")
          if Builtins.tolower(s) == "auto"
            Ops.set(partition, "size", -1)
          elsif Builtins.tolower(s) == "max"
            Ops.set(partition, "size", 0)
          else
            Ops.set(partition, "size", Storage.ClassicStringToByte(s))
          end
        end
        if Ops.get_integer(partition, "size", 0) == -1 &&
            Ops.get_string(partition, "mount", "") == "swap"
          Ops.set(
            partition,
            "size",
            Ops.multiply(
              1024 * 1024,
              Partitions.SwapSizeMb(0, GetProposalSuspend())
            )
          )
        end
        if Ops.get_string(partition, "mount", "") == Partitions.BootMount
          if Ops.get_integer(partition, "size", 0) == -1
            Ops.set(partition, "size", Partitions.ProposedBootsize)
          end
          if Ops.get_symbol(partition, "fsys", :none) == :none
            Ops.set(partition, "fsys", Partitions.DefaultBootFs)
          end
          if Ops.get_integer(partition, "id", 0) == 0
            # TODO: The empty dlabel for FsidBoot is wrong on PPC but
            # partitions without a mount point are ignored anyway. See
            # flex-info-empty-ppc64le2.rb.
            Ops.set(partition, "id", Partitions.FsidBoot(""))
          end
          Ops.set(partition, "max_cyl", Partitions.BootCyl)
        end
        if Ops.get_integer(partition, "size", 0) == -1
          Ops.set(partition, "size", 0)
        end
        Builtins.y2milestone("partition: %1", partition)
        if Ops.greater_than(
            Builtins.size(Ops.get_string(partition, "mount", "")),
            0
          ) ||
            Ops.greater_than(Ops.get_integer(partition, "id", 0), 0)
          partitions = Builtins.add(partitions, partition)
        end
      end
      Ops.set(conf, "partitions", partitions)
      if Builtins.size(partitions) == 0
        conf = {}
      else
        Ops.set(conf, "partitions", partitions)
      end
      log.info("conf:#{conf}")
      deep_copy(conf)
    end


    def read_partition_config(fpath)
      pos = 0
      line = ""
      rex = ""
      conf = {}

      Ops.set(conf, "prefer_remove", true)
      Ops.set(conf, "remove_special_partitions", false)
      Ops.set(conf, "keep_partition_id", [])
      Ops.set(conf, "keep_partition_num", [])
      Ops.set(conf, "keep_partition_fsys", [])

      cstring = Convert.to_string(SCR.Read(path(".target.string"), fpath))
      lines = Builtins.filter(Builtins.splitstring(cstring, "\n")) do |e|
        Ops.greater_than(Builtins.size(e), 0)
      end
      rex = "[ \t]*#.*"
      Builtins.y2milestone("lines %1", lines)
      lines = Builtins.filter(lines) do |e|
        !Builtins.regexpmatch(e, "[ \t]*#.*")
      end
      Builtins.y2milestone("lines %1", lines)
      fnd = []
      Builtins.foreach(["PREFER_REMOVE", "REMOVE_SPECIAL_PARTITIONS"]) do |key|
        rex = Ops.add(Ops.add("[ \t]*", key), "[ \t]*=")
        fnd = Builtins.filter(lines) { |e| Builtins.regexpmatch(e, rex) }
        Builtins.y2milestone("rex %1 fnd %2", rex, fnd)
        if Ops.greater_than(Builtins.size(fnd), 0)
          line = Builtins.deletechars(
            Ops.get_string(fnd, Ops.subtract(Builtins.size(fnd), 1), ""),
            "\t "
          )
          pos = Builtins.findlastof(line, "=")
          if Ops.greater_than(pos, 0)
            Ops.set(
              conf,
              Builtins.tolower(key),
              Ops.greater_than(
                Builtins.tointeger(Builtins.substring(line, Ops.add(pos, 1))),
                0
              )
            )
          end
        end
      end
      Builtins.foreach(["KEEP_PARTITION_ID", "KEEP_PARTITION_NUM"]) do |key|
        rex = Ops.add(Ops.add("[ \t]*", key), "[ \t]*=")
        Builtins.y2milestone("rex %1", rex)
        Builtins.foreach(Builtins.filter(lines) do |e|
          Builtins.regexpmatch(e, rex)
        end) do |l|
          Builtins.y2milestone("line %1", l)
          line = Builtins.deletechars(l, "\t ")
          pos = Builtins.findlastof(line, "=")
          if Ops.greater_than(pos, 0)
            num = []
            nlist = Builtins.splitstring(
              Builtins.substring(line, Ops.add(pos, 1)),
              ","
            )
            Builtins.foreach(nlist) do |n|
              num = Builtins.union(num, [Builtins.tointeger(n)])
            end
            Ops.set(
              conf,
              Builtins.tolower(key),
              Builtins.union(Ops.get_list(conf, Builtins.tolower(key), []), num)
            )
          end
        end
      end
      fsys = []
      rex = "[ \t]*" + "KEEP_PARTITION_FSYS" + "[ \t]*="
      Builtins.foreach(Builtins.filter(lines) { |e| Builtins.regexpmatch(e, rex) }) do |l|
        Builtins.y2milestone("line %1", l)
        line = Builtins.deletechars(l, "\t ")
        pos = Builtins.findlastof(line, "=")
        if Ops.greater_than(pos, 0)
          nlist = Builtins.splitstring(
            Builtins.substring(line, Ops.add(pos, 1)),
            ","
          )
          Builtins.foreach(nlist) do |n|
            fs = FileSystems.FsToSymbol(n)
            fsys = Builtins.union(fsys, [fs]) if fs != :none
          end
        end
      end
      Ops.set(conf, "keep_partition_fsys", fsys)
      partitions = []
      part = {}
      rex = "[ \t]*" + "PARTITION" + "[ \t][ \t]*"
      Builtins.foreach(Builtins.filter(lines) { |e| Builtins.regexpmatch(e, rex) }) do |l|
        Builtins.y2milestone("line %1", l)
        par = ""
        key = ""
        pos2 = Builtins.search(l, "PARTITION")
        line = Builtins.substring(l, Ops.add(pos2, 10))
        Builtins.y2milestone("line %1", line)
        pos2 = Builtins.search(line, "=")
        part = {}
        while pos2 != nil
          key = Builtins.deletechars(Builtins.substring(line, 0, pos2), " \t")
          line = Builtins.substring(line, Ops.add(pos2, 1))
          if Builtins.substring(line, 0, 1) == "\""
            line = Builtins.substring(line, 1)
            pos2 = Builtins.search(line, "\"")
            par = Builtins.substring(line, 0, pos2)
            line = Builtins.substring(line, Ops.add(pos2, 1))
          else
            pos2 = Builtins.findfirstof(line, " \t")
            if pos2 == nil
              par = line
            else
              par = Builtins.substring(line, 0, pos2)
              line = Builtins.substring(line, Ops.add(pos2, 1))
            end
          end
          log.debug("key:'#{key}' par:'#{par}'")
          if key == "id"
            Ops.set(part, key, Builtins.tointeger(par))
          elsif key == "mount"
            Ops.set(part, key, par)
          elsif key == "increasable"
            Ops.set(
              part,
              "increasable",
              Ops.greater_than(Builtins.tointeger(par), 0) ? true : false
            )
          elsif key == "size"
            if Builtins.tolower(par) == "auto"
              Ops.set(part, "size", -1)
            elsif Builtins.tolower(par) == "max"
              Ops.set(part, "size", 0)
            else
              Ops.set(part, "size", Storage.ClassicStringToByte(par))
            end
          elsif key == "label"
            Ops.set(part, key, par)
          elsif key == "maxsize"
            Ops.set(part, key, Storage.ClassicStringToByte(par))
          elsif key == "sizepct"
            Ops.set(part, "pct", Builtins.tointeger(par))
          elsif key == "disk"
            Ops.set(part, key, Builtins.tointeger(par))
          elsif key == "fsys"
            fs = FileSystems.FsToSymbol(par)
            Ops.set(part, key, fs) if fs != :none
          elsif key == "fstopt"
            Ops.set(part, key, par)
          elsif key == "formatopt"
            Ops.set(part, "fopt", par)
          end
          pos2 = Builtins.search(line, "=")
        end
        Builtins.y2milestone("part %1", part)
        if Ops.get_integer(part, "size", 0) == -1 &&
            Ops.get_string(part, "mount", "") == "swap"
          Ops.set(
            part,
            "size",
            Ops.multiply(
              1024 * 1024,
              Partitions.SwapSizeMb(0, GetProposalSuspend())
            )
          )
        end
        if Ops.get_string(part, "mount", "") == Partitions.BootMount
          if Ops.get_integer(part, "size", 0) == -1
            Ops.set(part, "size", Partitions.ProposedBootsize)
          end
          if Ops.get_symbol(part, "fsys", :none) == :none
            Ops.set(part, "fsys", Partitions.DefaultBootFs)
          end
          if Ops.get_integer(part, "id", 0) == 0
            # TODO: The empty dlabel for FsidBoot is wrong on PPC but
            # partitions without a mount point are ignored anyway. See
            # flex-info-empty-ppc64le2.rb.
            Ops.set(part, "id", Partitions.FsidBoot(""))
          end
          Ops.set(part, "max_cyl", Partitions.BootCyl)
        end
        Ops.set(part, "size", 0) if Ops.get_integer(part, "size", 0) == -1
        if Ops.greater_than(Builtins.size(Ops.get_string(part, "mount", "")), 0) ||
            Ops.greater_than(Ops.get_integer(part, "id", 0), 0)
          partitions = Builtins.add(partitions, part)
        end
      end
      Ops.set(conf, "partitions", partitions)
      if Builtins.size(partitions) == 0
        conf = {}
      else
        Ops.set(conf, "partitions", partitions)
      end
      log.info("conf:#{conf}")
      deep_copy(conf)
    end


    def can_swap_reuse(disk, partitions, tgmap)
      partitions = deep_copy(partitions)
      tgmap = deep_copy(tgmap)
      ret = {}
      Builtins.y2milestone(
        "can_swap_reuse disk %1 partitions %2",
        disk,
        partitions
      )
      swaps = Builtins.filter(partitions) do |p|
        Ops.get_symbol(p, "type", :unknown) != :free &&
          !Ops.get_boolean(p, "delete", false) &&
          Ops.get_symbol(p, "detected_fs", :unknown) == :swap &&
          [ "", "swap" ].include?(p.fetch("mount", ""))
      end
      swaps = Builtins.filter(swaps) do |p|
        check_swapable(Ops.get_string(p, "device", ""))
      end
      swaps = Builtins.sort(swaps) do |a, b|
        Ops.greater_than(
          Ops.get_integer(a, "size_k", 0),
          Ops.get_integer(b, "size_k", 0)
        )
      end
      Builtins.y2milestone("can_swap_reuse swaps %1", swaps)
      if Ops.greater_or_equal(
          Ops.get_integer(swaps, [0, "size_k"], 0),
          128 * 1024
        )
        Ops.set(ret, "partitions", Builtins.maplist(partitions) do |p|
          if !Ops.get_boolean(p, "delete", false) &&
              Ops.get_string(p, "device", "") ==
                Ops.get_string(swaps, [0, "device"], "")
            if Ops.get_string(p, "mount", "") != "swap"
              Ops.set(p, "inactive", true)
            end
            Ops.set(p, "mount", "swap")
            if Builtins.haskey(p, "vg")
              p = Builtins.remove(p, "vg")
              if Ops.get_boolean(p, "change_fsid", false)
                Ops.set(
                  p,
                  "fsid",
                  Ops.get_integer(p, "ori_fsid", Partitions.fsid_swap)
                )
              end
            end
          end
          deep_copy(p)
        end)
      else
        swaps = []
        tg = Builtins.filter(tgmap) { |k, d| Storage.IsPartitionable(d) }
        tg = Builtins.remove(tg, disk) if Builtins.haskey(tg, disk)
        Builtins.y2milestone("can_swap_reuse tg wo %1", tg)
        Builtins.foreach(tg) do |dev, disk2|
          sw = Builtins.filter(Ops.get_list(disk2, "partitions", [])) do |p|
            Ops.get_symbol(p, "type", :unknown) != :extended &&
              !Ops.get_boolean(p, "delete", false) &&
              Ops.get_symbol(p, "detected_fs", :unknown) == :swap
          end
          sw = Builtins.filter(sw) do |p|
            check_swapable(Ops.get_string(p, "device", ""))
          end
          Builtins.y2milestone("can_swap_reuse disk %1 sw %2", dev, sw)
          swaps = Convert.convert(
            Builtins.union(swaps, sw),
            :from => "list",
            :to   => "list <map>"
          )
        end
        swaps = Builtins.sort(swaps) do |a, b|
          Ops.greater_than(
            Ops.get_integer(a, "size_k", 0),
            Ops.get_integer(b, "size_k", 0)
          )
        end
        Builtins.y2milestone("can_swap_reuse swaps %1", swaps)
        if Ops.greater_or_equal(
            Ops.get_integer(swaps, [0, "size_k"], 0),
            256 * 1024
          )
          Ops.set(
            ret,
            "targets",
            Storage.SetPartitionData(
              tgmap,
              Ops.get_string(swaps, [0, "device"], ""),
              "mount",
              "swap"
            )
          )
          Ops.set(
            ret,
            "targets",
            Storage.DelPartitionData(
              Ops.get_map(ret, "targets", {}),
              Ops.get_string(swaps, [0, "device"], ""),
              "vg"
            )
          )
        end
      end
      Builtins.y2milestone("can_swap_reuse ret %1", ret)
      deep_copy(ret)
    end


    def can_boot_reuse(disk, label, boot, max_prim, partitions)
      ret = []
      Builtins.y2milestone("can_boot_reuse boot:%1", boot)
      if boot && !Partitions.PrepBoot
        Builtins.y2milestone(
          "can_boot_reuse disk:%1 max_prim:%2 label:%3 part:%4",
          disk, max_prim, label, partitions)
        pl = partitions.select do |p|
          !p.fetch("delete",false) &&
          (p.fetch("size_k",0)*1024>=Partitions.MinimalBootsize||
	   p.fetch("fsid",0)==Partitions.fsid_bios_grub)
        end
        Builtins.y2milestone( "can_boot_reuse pl:%1", pl )
        boot2 = Builtins.find(pl) do |p|
          p.fetch("fsid",0) == Partitions.fsid_gpt_boot ||
	  p.fetch("fsid", 0) == Partitions.FsidBoot(label) &&
	    p.fetch("size_k",0)*1024<=Partitions.MaximalBootsize ||
	  p.fetch("detected_fs",:unknown) == :hfs &&
	    p.fetch("boot",false) &&
	    label == "mac" ||
	  p.fetch("fsid", 0) == Partitions.FsidBoot(label) &&
	    p.fetch("nr",0)<=max_prim &&
	    Partitions.PrepBoot ||
	  p.fetch("fsid",0) == Partitions.fsid_bios_grub &&
	    label=="gpt" &&
	    !Partitions.EfiBoot
        end
	Builtins.y2milestone("can_boot_reuse boot2:%1", boot2)
	if boot2 != nil
	  ret = partitions.map do |p|
	    if !p.fetch("delete",false) &&
		p.fetch("device","") == boot2.fetch("device","") &&
		Storage.CanEdit(p, false)
	      p = Storage.SetVolOptions( p, Partitions.BootMount,
		Partitions.DefaultBootFs, "", "", "")
	    end
          p
	  end
	end
        Builtins.y2milestone("can_boot_reuse ret:%1", ret)
      end
      deep_copy(ret)
    end


    def can_rboot_reuse(disk, label, boot, max_prim, partitions)
      partitions = deep_copy(partitions)
      ret = []
      Builtins.y2milestone("can_rboot_reuse boot:%1", boot)
      if boot
        Builtins.y2milestone(
          "can_rboot_reuse disk:%1 max_prim:%2 label:%3 part:%4",
          disk,
          max_prim,
          label,
          partitions
        )
        pl = []
        pl = Builtins.filter(partitions) do |p|
          !Ops.get_boolean(p, "delete", false) &&
            Ops.greater_or_equal(
              Ops.multiply(Ops.get_integer(p, "size_k", 0), 1024),
              Partitions.MinimalBootsize
            )
        end
        boot2 = Builtins.find(pl) do |p|
          Ops.get_integer(p, "fsid", 0) == Partitions.fsid_native &&
            Ops.less_or_equal(
              Ops.multiply(Ops.get_integer(p, "size_k", 0), 1024),
              Partitions.MaximalBootsize
            ) &&
            FileSystems.IsSupported(Ops.get_symbol(p, "used_fs", :unknown))
        end
        ret = Builtins.maplist(partitions) do |p|
          if !Ops.get_boolean(p, "delete", false) &&
              Ops.get_string(p, "device", "") ==
                Ops.get_string(boot2, "device", "") &&
              Storage.CanEdit(p, false)
            p = Storage.SetVolOptions(
              p,
              "/boot",
              Partitions.DefaultFs,
              "",
              "",
              ""
            )
          end
          deep_copy(p)
        end if boot2 != nil
        Builtins.y2milestone("can_rboot_reuse ret:%1", ret)
      end
      deep_copy(ret)
    end


    def can_home_reuse(min, max, partitions)
      partitions = deep_copy(partitions)
      ret = []
      max = Ops.add(max, Ops.divide(max, 10)) if Ops.greater_than(max, 0)
      Builtins.y2milestone("can_home_reuse min %1 max %2", min, max)
      pl = []
      pl = Builtins.filter(partitions) do |p|
        !Ops.get_boolean(p, "delete", false) &&
          Ops.get_integer(p, "fsid", Partitions.fsid_native) ==
            Partitions.fsid_native &&
          !Storage.IsUsedBy(p) &&
          Builtins.size(Ops.get_string(p, "mount", "")) == 0 &&
          Ops.greater_or_equal(
            Ops.divide(Ops.get_integer(p, "size_k", 0), 1024),
            min
          ) &&
          (max == 0 ||
            Ops.less_or_equal(
              Ops.divide(Ops.get_integer(p, "size_k", 0), 1024),
              max
            )) &&
          Storage.CanEdit(p, false)
      end
      Builtins.y2milestone("can_home_reuse normal %1", pl)
      if Ops.greater_than(Builtins.size(pl), 0)
        pl = Builtins.sort(pl) do |a, b|
          Ops.greater_than(
            Ops.get_integer(a, "size_k", 0),
            Ops.get_integer(b, "size_k", 0)
          )
        end
        fill_ishome(pl)
        pl = Convert.convert(
          Builtins.union(Builtins.filter(pl) do |p|
            Ops.get(@ishome, Ops.get_string(p, "device", ""), false)
          end, Builtins.filter(
            pl
          ) do |p|
            !Ops.get(@ishome, Ops.get_string(p, "device", ""), false)
          end),
          :from => "list",
          :to   => "list <map>"
        )
        Builtins.y2milestone("can_home_reuse sorted %1", pl)
        ret = Builtins.maplist(partitions) do |p|
          if !Ops.get_boolean(p, "delete", false) &&
              Ops.get_string(p, "device", "") ==
                Ops.get_string(pl, [0, "device"], "")
            p = Storage.SetVolOptions(p, "/home", PropDefaultHomeFs(), "", "", "")
          end
          deep_copy(p)
        end
      end
      Builtins.y2milestone("can_home_reuse ret %1", ret)
      deep_copy(ret)
    end


    def can_root_reuse(min, max, partitions)
      partitions = deep_copy(partitions)
      ret = []
      max = Ops.add(max, Ops.divide(max, 10)) if Ops.greater_than(max, 0)
      Builtins.y2milestone("can_root_reuse min %1 max %2", min, max)
      pl = []
      pl = Builtins.filter(partitions) do |p|
        !Ops.get_boolean(p, "delete", false) &&
          Ops.get_integer(p, "fsid", Partitions.fsid_native) ==
            Partitions.fsid_native &&
          !Storage.IsUsedBy(p) &&
          Builtins.size(Ops.get_string(p, "mount", "")) == 0 &&
          Ops.greater_or_equal(
            Ops.divide(Ops.get_integer(p, "size_k", 0), 1024),
            min
          ) &&
          Storage.CanEdit(p, false)
      end
      Builtins.y2milestone("can_root_reuse normal %1", pl)
      if Ops.greater_than(Builtins.size(pl), 0)
        fill_ishome(pl)
        p1 = Builtins.sort(Builtins.filter(pl) do |p|
          Ops.get(@ishome, Ops.get_string(p, "device", ""), false)
        end) do |a, b|
          Ops.less_than(
            Ops.get_integer(a, "size_k", 0),
            Ops.get_integer(b, "size_k", 0)
          )
        end
        Builtins.y2milestone("can_root_reuse p1 %1", p1)
        p2 = Builtins.sort(Builtins.filter(pl) do |p|
          !Ops.get(@ishome, Ops.get_string(p, "device", ""), false) &&
            Ops.greater_than(
              Ops.divide(Ops.get_integer(p, "size_k", 0), 1024),
              max
            )
        end) do |a, b|
          Ops.less_than(
            Ops.get_integer(a, "size_k", 0),
            Ops.get_integer(b, "size_k", 0)
          )
        end
        Builtins.y2milestone("can_root_reuse p2 %1", p2)
        p3 = Builtins.sort(Builtins.filter(pl) do |p|
          !Ops.get(@ishome, Ops.get_string(p, "device", ""), false) &&
            Ops.less_or_equal(
              Ops.divide(Ops.get_integer(p, "size_k", 0), 1024),
              max
            )
        end) do |a, b|
          Ops.greater_than(
            Ops.get_integer(a, "size_k", 0),
            Ops.get_integer(b, "size_k", 0)
          )
        end
        Builtins.y2milestone("can_root_reuse p3 %1", p3)
        pl = Convert.convert(
          Builtins.union(p2, p1),
          :from => "list",
          :to   => "list <map>"
        )
        pl = Convert.convert(
          Builtins.union(p3, pl),
          :from => "list",
          :to   => "list <map>"
        )
        Builtins.y2milestone("can_root_reuse sorted %1", pl)
        ret = Builtins.maplist(partitions) do |p|
          if !Ops.get_boolean(p, "delete", false) &&
              Ops.get_string(p, "device", "") ==
                Ops.get_string(pl, [0, "device"], "")
            p = Storage.SetVolOptions(p, "/", PropDefaultFs(), "", "", "")
          end
          deep_copy(p)
        end
      end
      Builtins.y2milestone("can_root_reuse ret %1", ret)
      deep_copy(ret)
    end


    def get_avail_size_mb(parts)
      parts = deep_copy(parts)
      ret = 0
      Builtins.foreach(Builtins.filter(parts) do |p|
        Ops.get_boolean(p, "delete", false) &&
          Ops.get_symbol(p, "type", :unknown) != :extended
      end) do |pp|
        ret = Ops.add(ret, Ops.divide(Ops.get_integer(pp, "size_k", 0), 1024))
      end
      Builtins.y2milestone("get_avail_size_mb ret %1", ret)
      ret
    end


    def get_swap_sizes(space)
      l = [
        Partitions.SwapSizeMb(0, GetProposalSuspend()),
        Partitions.SwapSizeMb(space, GetProposalSuspend())
      ]
      Builtins.y2milestone("get_swap_sizes space %1 ret %2", space, l)
      deep_copy(l)
    end


    def get_proposal(have_swap, disk)
      disk = deep_copy(disk)
      ret = []
      Builtins.y2milestone("get_proposal have_swap:%1 disk %2", have_swap, disk)
      root = {
        "mount"       => "/",
        "increasable" => true,
        "fsys"        => PropDefaultFs(),
        "size"        => 0
      }
      opts = GetControlCfg()
      conf = { "partitions" => [] }
      swap_sizes = []
      avail_size = get_avail_size_mb(Ops.get_list(disk, "partitions", []))
      if !have_swap
        swap_sizes = get_swap_sizes(avail_size)
        swap = {
          "mount"       => "swap",
          "increasable" => true,
          "fsys"        => :swap,
          "maxsize"     => 2 * 1024 * 1024 * 1024,
          "size"        => Ops.multiply(
            Ops.multiply(Ops.get(swap_sizes, 0, 256), 1024),
            1024
          )
        }
        Ops.set(
          conf,
          "partitions",
          Builtins.add(Ops.get_list(conf, "partitions", []), swap)
        )
      end
      Ops.set(
        conf,
        "partitions",
        Builtins.add(Ops.get_list(conf, "partitions", []), root)
      )
      old_root = {}
      if GetProposalHome() &&
          Ops.less_than(Ops.get_integer(opts, "home_limit", 0), avail_size)
        home = {
          "mount"       => "/home",
          "increasable" => true,
          "fsys"        => PropDefaultHomeFs(),
          "size"        => 512 * 1024 * 1024,
          "pct"         => Ops.subtract(
            100,
            Ops.get_integer(opts, "root_percent", 40)
          )
        }
        Ops.set(
          conf,
          "partitions",
          Builtins.maplist(Ops.get_list(conf, "partitions", [])) do |p|
            if Ops.get_string(p, "mount", "") == "/"
              old_root = deep_copy(p)
              Ops.set(p, "pct", Ops.get_integer(opts, "root_percent", 40))
              Ops.set(
                p,
                "maxsize",
                Ops.multiply(
                  Ops.multiply(Ops.get_integer(opts, "root_max", 0), 1024),
                  1024
                )
              )
              Ops.set(
                p,
                "size",
                Ops.multiply(
                  Ops.multiply(Ops.get_integer(opts, "root_base", 0), 1024),
                  1024
                )
              )
            end
            deep_copy(p)
          end
        )
        Ops.set(
          conf,
          "partitions",
          Builtins.add(Ops.get_list(conf, "partitions", []), home)
        )
      end
      ps1 = do_flexible_disk_conf(disk, conf, false, false)
      if Ops.greater_than(Builtins.size(old_root), 0) &&
          !Ops.get_boolean(ps1, "ok", false)
        Ops.set(
          conf,
          "partitions",
          Builtins.filter(Ops.get_list(conf, "partitions", [])) do |p|
            Ops.get_string(p, "mount", "") != "/home" &&
              Ops.get_string(p, "mount", "") != "/"
          end
        )
        Ops.set(
          conf,
          "partitions",
          Builtins.add(Ops.get_list(conf, "partitions", []), old_root)
        )
        ps1 = do_flexible_disk_conf(disk, conf, false, false)
      end
      if !have_swap
        diff = Ops.subtract(
          Ops.get(swap_sizes, 0, 256),
          Ops.get(swap_sizes, 1, 256)
        )
        diff = Ops.unary_minus(diff) if Ops.less_than(diff, 0)
        Builtins.y2milestone(
          "get_proposal diff:%1 ps1 ok:%2",
          diff,
          Ops.get_boolean(ps1, "ok", false)
        )
        if !Ops.get_boolean(ps1, "ok", false) && Ops.greater_than(diff, 0) ||
            Ops.greater_than(diff, 100)
          Ops.set(
            conf,
            ["partitions", 0, "size"],
            Ops.multiply(Ops.multiply(Ops.get(swap_sizes, 1, 256), 1024), 1024)
          )
          ps2 = do_flexible_disk_conf(disk, conf, false, false)
          Builtins.y2milestone(
            "get_proposal ps2 ok:%1",
            Ops.get_boolean(ps2, "ok", false)
          )
          if Ops.get_boolean(ps2, "ok", false)
            rp1 = Builtins.find(Ops.get_list(ps1, ["disk", "partitions"], [])) do |p|
              !Ops.get_boolean(p, "delete", false) &&
                Ops.get_string(p, "mount", "") == "/"
            end
            rp2 = Builtins.find(Ops.get_list(ps2, ["disk", "partitions"], [])) do |p|
              !Ops.get_boolean(p, "delete", false) &&
                Ops.get_string(p, "mount", "") == "/"
            end
            Builtins.y2milestone("get_proposal rp1:%1", rp1)
            Builtins.y2milestone("get_proposal rp2:%1", rp2)
            if rp1 == nil ||
                rp2 != nil &&
                  Ops.greater_than(
                    Ops.get_integer(rp2, "size_k", 0),
                    Ops.get_integer(rp1, "size_k", 0)
                  )
              ps1 = deep_copy(ps2)
            end
          end
        end
      end
      if Ops.get_boolean(ps1, "ok", false)
        ret = Ops.get_list(ps1, ["disk", "partitions"], [])
      end

      post_processor = PostProcessor.new()
      ret = post_processor.process_partitions(ret)

      Builtins.y2milestone("get_proposal ret:%1", ret)
      deep_copy(ret)
    end


    def get_usable_size_mb(disk, reuse_linux)
      disk = deep_copy(disk)
      ret = 0
      cyl_size = Ops.get_integer(disk, "cyl_size", 0)
      disk_cyl = Ops.get_integer(disk, "cyl_count", 0)
      partitions = Builtins.filter(Ops.get_list(disk, "partitions", [])) do |p|
        !Ops.get_boolean(p, "create", false)
      end
      partitions = Builtins.sort(partitions) do |p1, p2|
        Ops.less_than(
          Ops.get_integer(p1, ["region", 0], 0),
          Ops.get_integer(p2, ["region", 0], 0)
        )
      end
      last_end = 0
      Builtins.foreach(partitions) do |p|
        if Ops.greater_than(Ops.get_integer(p, ["region", 0], 0), last_end)
          ret = Ops.add(
            ret,
            Ops.multiply(
              Ops.subtract(Ops.get_integer(p, ["region", 0], 0), last_end),
              cyl_size
            )
          )
        end
        if Ops.get_symbol(p, "type", :unknown) != :extended &&
            (Ops.get_boolean(p, "delete", false) ||
              reuse_linux && Ops.get_boolean(p, "linux", false))
          ret = Ops.add(
            ret,
            Ops.multiply(Ops.get_integer(p, "size_k", 0), 1024)
          )
        end
        last_end = Ops.get_integer(p, ["region", 0], 0)
        if Ops.get_symbol(p, "type", :unknown) != :extended
          last_end = Ops.add(last_end, Ops.get_integer(p, ["region", 1], 0))
        end
      end
      if Ops.less_than(last_end, disk_cyl)
        ret = Ops.add(
          ret,
          Ops.multiply(Ops.subtract(disk_cyl, last_end), cyl_size)
        )
      end
      ret = Ops.divide(ret, 1024 * 1024)
      ret
    end


    def get_mb_sol(sol, mp)
      sol = deep_copy(sol)
      pa = Builtins.find(Ops.get_list(sol, ["disk", "partitions"], [])) do |p|
        Ops.get_string(p, "mount", "") == mp
      end
      Builtins.y2milestone("get_mb_sol pa %1", pa)
      ret = pa != nil ? Ops.divide(Ops.get_integer(pa, "size_k", 0), 1024) : 0
      Builtins.y2milestone("get_mb_sol ret %1", ret)
      ret
    end


    def get_vm_sol(sol)
      sol = deep_copy(sol)
      ret = 0
      Builtins.foreach(Ops.get_list(sol, ["disk", "partitions"], [])) do |p|
        if !Ops.get_boolean(p, "delete", false) &&
            (Ops.greater_than(Builtins.size(Ops.get_string(p, "mount", "")), 0) ||
              Ops.greater_than(Builtins.size(Ops.get_string(p, "vg", "")), 0))
          ret = Ops.add(ret, Ops.divide(Ops.get_integer(p, "size_k", 0), 1024))
        end
      end
      Builtins.y2milestone("get_vm_sol ret %1", ret)
      ret
    end


    def special_boot_proposal_prepare(partitions)
      partitions = deep_copy(partitions)
      ret = deep_copy(partitions)
      if Partitions.PrepBoot
        ret = Builtins.maplist(partitions) do |p|
          if Builtins.size(Ops.get_string(p, "mount", "")) == 0 &&
              (Ops.get_integer(p, "fsid", 0) == 6 ||
               Partitions.IsPrepPartition(Ops.get_integer(p, "fsid", 0)))
            Ops.set(p, "delete", true)
          end
          deep_copy(p)
        end
        log.info("special_boot_proposal_prepare part:#{partitions}")
        log.info("special_boot_proposal_prepare ret:#{ret}")
      end
      deep_copy(ret)
    end


    def prepare_part_lists(ddev, tg)
      ddev = deep_copy(ddev)
      tg = deep_copy(tg)
      linux_pid = [
        Partitions.fsid_native,
        Partitions.fsid_swap,
        Partitions.fsid_lvm,
        Partitions.fsid_raid,
        Partitions.fsid_bios_grub
      ]
      remk = ["del_ptable", "disklabel"]
      Builtins.foreach(ddev) do |s|
        dlabel = Ops.get_string(tg, [s, "label"])
        Ops.set(
          tg,
          [s, "partitions"],
          Builtins.maplist(Ops.get_list(tg, [s, "partitions"], [])) do |p|
            if Builtins.contains(linux_pid, Ops.get_integer(p, "fsid", 0)) ||
                Ops.get_integer(p, "fsid", 0) == Partitions.FsidBoot(dlabel) &&
                  !Partitions.EfiBoot &&
                  Ops.less_or_equal(
                    Ops.multiply(Ops.get_integer(p, "size_k", 0), 1024),
                    Partitions.MaximalBootsize
                  ) ||
                Partitions.PrepBoot &&
                  (Ops.get_integer(p, "fsid", 0) == Partitions.FsidBoot(dlabel) ||
                    Ops.get_integer(p, "fsid", 0) == 6)
              Ops.set(p, "linux", true)
            else
              Ops.set(p, "linux", false)
            end
            deep_copy(p)
          end
        )
        Builtins.foreach(remk) do |k|
          if Builtins.haskey(Ops.get(tg, s, {}), k)
            Ops.set(tg, s, Builtins.remove(Ops.get(tg, s, {}), k))
          end
        end
      end
      deep_copy(tg)
    end


    def get_disk_try_list(tg, soft)
      tg = deep_copy(tg)
      ret = []
      ret = Builtins.maplist(Builtins.filter(tg) do |l, f|
        !ignore_disk(l, f, soft)
      end) { |k, e| k }
      ret = Builtins.sort(ret)
      ret = restrict_disk_names(ret) if Ops.greater_than(Builtins.size(ret), 4)
      Builtins.y2milestone("get_disk_try_list soft:%1 ret:%2", soft, ret)
      deep_copy(ret)
    end


    def usable_for_win_resize(p, assert_cons_fs)
      p = deep_copy(p)
      ret = Partitions.IsDosWinNtPartition(Ops.get_integer(p, "fsid", 0)) &&
        Ops.greater_than(Ops.get_integer(p, "size_k", 0), 1024 * 1024) &&
        !Ops.get_boolean(p, "resize", false) &&
        !Ops.get_boolean(p, "delete", false)
      if ret
        if assert_cons_fs
          ret = Ops.get_boolean(p, ["winfo", "resize_ok"], false) &&
            !Ops.get_boolean(p, ["winfo", "efi"], false)
        else
          ret = Ops.greater_than(Builtins.size(Ops.get_map(p, "winfo", {})), 0)
        end
      end
      ret
    end


    def remove_p_settings(parts, mp)
      parts = deep_copy(parts)
      mp = deep_copy(mp)
      rems = [
        "resize",
        "used_fs",
        "win_max_length",
        "mount",
        "format",
        "ignore_fs",
        "vg"
      ]
      parts = Builtins.maplist(parts) do |p|
        if (Builtins.size(mp) == 0 ||
            Builtins.contains(mp, Ops.get_string(p, "mount", ""))) &&
            !(Ops.get_string(p, "mount", "") == "swap" &&
              !Ops.get_boolean(p, "inactive", false))
          Builtins.foreach(rems) do |s|
            p = Builtins.remove(p, s) if Builtins.haskey(p, s)
          end
        end
        deep_copy(p)
      end
      deep_copy(parts)
    end


    def remove_one_partition(disk)
      disk = deep_copy(disk)
      partitions = Ops.get_list(disk, "partitions", [])
      pl = Builtins.filter(partitions) do |p|
        Ops.get_boolean(p, "linux", false) &&
          Builtins.size(Ops.get_string(p, "mount", "")) == 0 &&
          !Ops.get_boolean(p, "delete", false) &&
          Storage.CanDelete(p, disk, false)
      end
      if Ops.greater_than(Builtins.size(pl), 0)
        fill_ishome(pl)
        pl = Builtins.sort(pl) do |a, b|
          Ops.greater_than(
            Ops.get_integer(a, "size_k", 0),
            Ops.get_integer(b, "size_k", 0)
          )
        end
        l1 = Builtins.filter(pl) { |p| !Storage.IsUsedBy(p) }
        l1 = Convert.convert(
          Builtins.union(Builtins.filter(l1) do |p|
            !Ops.get(@ishome, Ops.get_string(p, "device", ""), false)
          end, Builtins.filter(
            l1
          ) do |p|
            Ops.get(@ishome, Ops.get_string(p, "device", ""), false)
          end),
          :from => "list",
          :to   => "list <map>"
        )

        pl = Convert.convert(
          Builtins.union(l1, Builtins.filter(pl) { |p| Storage.IsUsedBy(p) }),
          :from => "list",
          :to   => "list <map>"
        )

        partitions = Builtins.maplist(partitions) do |p|
          if Ops.get_boolean(p, "linux", false) &&
              !Ops.get_boolean(p, "delete", false) &&
              Builtins.size(Ops.get_string(p, "mount", "")) == 0 &&
              Ops.get_string(p, "device", "") ==
                Ops.get_string(pl, [0, "device"], "") &&
              Storage.CanDelete(p, disk, false)
            Ops.set(p, "delete", true)
            Builtins.y2milestone("remove_one_partition p %1", p)
          end
          deep_copy(p)
        end
        partitions = try_remove_sole_extended(partitions)
      end
      deep_copy(partitions)
    end


    def remove_one_partition_vm(disk)
      disk = deep_copy(disk)
      partitions = Ops.get_list(disk, "partitions", [])
      pl = Builtins.filter(partitions) do |p|
        Ops.get_boolean(p, "linux", false) &&
          Builtins.size(Ops.get_string(p, "mount", "")) == 0 &&
          !Ops.get_boolean(p, "delete", false) &&
          Storage.CanDelete(p, disk, false)
      end
      if Ops.greater_than(Builtins.size(pl), 0)
        pl = Builtins.sort(pl) do |a, b|
          Ops.less_than(
            Ops.get_integer(a, "size_k", 0),
            Ops.get_integer(b, "size_k", 0)
          )
        end
        pl = Convert.convert(
          Builtins.union(Builtins.filter(pl) do |p|
            Ops.get_symbol(p, "type", :primary) == :logical
          end, Builtins.filter(
            pl
          ) do |p|
            Ops.get_symbol(p, "type", :primary) != :logical
          end),
          :from => "list",
          :to   => "list <map>"
        )
        pl = Convert.convert(
          Builtins.union(Builtins.filter(pl) { |p| !Storage.IsUsedBy(p) }, Builtins.filter(
            pl
          ) do |p|
            Storage.IsUsedBy(p)
          end),
          :from => "list",
          :to   => "list <map>"
        )
        Builtins.y2milestone("remove_one_partition_vm pl %1", pl)

        nr = 0

        partitions = Builtins.maplist(partitions) do |p|
          if Ops.get_boolean(p, "linux", false) &&
              !Ops.get_boolean(p, "delete", false) &&
              Builtins.size(Ops.get_string(p, "mount", "")) == 0 &&
              Ops.get_string(p, "device", "") ==
                Ops.get_string(pl, [0, "device"], "") &&
              Storage.CanDelete(p, disk, false)
            Ops.set(p, "delete", true)
            nr = Ops.get_integer(p, "nr", 0)
            Builtins.y2milestone("remove_one_partition_vm p %1", p)
          end
          deep_copy(p)
        end
        if Ops.greater_than(nr, Ops.get_integer(disk, "max_primary", 4))
          partitions = Builtins.maplist(partitions) do |p|
            if !Ops.get_boolean(p, "delete", false) &&
                Ops.greater_than(Ops.get_integer(p, "nr", 0), nr)
              Ops.set(p, "nr", Ops.subtract(Ops.get_integer(p, "nr", 0), 1))
              Ops.set(
                p,
                "device",
                Storage.GetDeviceName(
                  Ops.get_string(disk, "device", ""),
                  Ops.get_integer(p, "nr", 0)
                )
              )
              Builtins.y2milestone("remove_one_partition_vm ren %1", p)
            end
            deep_copy(p)
          end
        end
        partitions = try_remove_sole_extended(partitions)
      end
      deep_copy(partitions)
    end


    def remove_used_by(tg, disk)
      tg = deep_copy(tg)
      uby = Ops.get_string(tg, [disk, "used_by_device"], "")
      Builtins.y2milestone("remove_used_by disk %1 uby %2", disk, uby)
      if Ops.greater_than(Builtins.size(uby), 0)
        if Builtins.haskey(tg, uby)
          Ops.set(tg, [uby, "delete"], true)
          Builtins.y2milestone(
            "remove_used_by uby %1",
            Ops.get_map(tg, uby, {})
          )
        end
      end
      deep_copy(tg)
    end


    class PostProcessor

      public

      def process_partitions(partitions)

        @have_boot_partition = false
        @have_home_partition = false

        analyse(partitions)

        return modify(partitions)

      end

      def process_target(target)

        @have_boot_partition = false
        @have_home_partition = false

        target.each do |device, container|
          analyse(container["partitions"])
        end

        target.each do |device, container|
          container["partitions"] = modify(container["partitions"])
        end

        return target

      end

      private

      def analyse(partitions)

        partitions.each do |volume|

          # check whether we have a boot partition
          if volume["mount"] == "/boot"
            @have_boot_partition = true
          end

          # check whether we have a home partition
          if volume["mount"] == "/home"
            @have_home_partition = true
          end

        end

      end

      def modify(partitions)

        partitions.each do |volume|

          # if we have a boot volume remove the boot subvolumes
          if StorageProposal.PropDefaultFs() == :btrfs && @have_boot_partition
            if volume["mount"] == "/"
              if FileSystems.default_subvol.empty?
                boot = "boot"
              else
                boot = FileSystems.default_subvol + "/" + "boot"
              end
              volume["subvol"].delete_if { |subvol| subvol["name"].start_with?(boot) }
            end
          end

          # if we have a home volume remove the home subvolume
          if StorageProposal.PropDefaultFs() == :btrfs && @have_home_partition
            if volume["mount"] == "/"
              if FileSystems.default_subvol.empty?
                home = "home"
              else
                home = FileSystems.default_subvol + "/" + "home"
              end
              volume["subvol"].delete_if { |subvol| subvol["name"] == home }
            end
          end

          # enable snapshots for root volume if desired
          if StorageProposal.PropDefaultFs() == :btrfs && StorageProposal.GetProposalSnapshots()
            opts = StorageProposal.GetControlCfg()
            size_limit_k = 1024 * opts["root_base"]
            if volume["mount"] == "/" && volume["size_k"] >= size_limit_k
              volume["userdata"] = { "/" => "snapshots" }
            end
          end

        end

        return partitions

      end

    end


    def get_inst_proposal(target)
      target = deep_copy(target)
      Builtins.y2milestone("get_inst_proposal start")
      flex_init_swapable(target)
      ret = {}
      target = AddWinInfo(target)
      Ops.set(ret, "target", target)
      root = {
        "mount"       => "/",
        "increasable" => true,
        "fsys"        => PropDefaultFs(),
        "size"        => 0
      }
      opts = GetControlCfg()
      ddev = get_disk_try_list(target, true)
      sol_disk = ""
      valid = {}
      size_mb = Builtins.listmap(ddev) { |s| { s => [] } }
      solution = Builtins.listmap(ddev) { |s| { s => [] } }
      target = prepare_part_lists(ddev, target)
      mode = :free
      while mode != :end && Builtins.size(sol_disk) == 0
        if mode == :free || mode == :desperate
          valid = Builtins.listmap(ddev) { |s| { s => true } }
          if mode == :desperate
            ddev = get_disk_try_list(target, false)
            valid = Builtins.listmap(ddev) { |s| { s => true } }
            target = prepare_part_lists(ddev, target)
            Builtins.foreach(ddev) do |s|
              Ops.set(
                target,
                [s, "partitions"],
                remove_p_settings(
                  Ops.get_list(target, [s, "partitions"], []),
                  []
                )
              )
              if NeedNewDisklabel(Ops.get(target, s, {}))
                Ops.set(target, [s, "disklabel"], "gpt")
                Ops.set(
                  target,
                  [s, "orig_label"],
                  Ops.get_string(target, [s, "label"], "msdos")
                )
                Ops.set(target, [s, "label"], "gpt")
                Ops.set(target, [s, "del_ptable"], true)
              end
              Ops.set(
                target,
                [s, "partitions"],
                Builtins.maplist(Ops.get_list(target, [s, "partitions"], [])) do |p|
                  if (NeedNewDisklabel(Ops.get(target, s, {})) ||
                      !Builtins.contains(
                        Partitions.do_not_delete,
                        Ops.get_integer(p, "fsid", 0)
                      )) &&
                      Storage.CanDelete(p, Ops.get(target, s, {}), false)
                    if usable_for_win_resize(p, false) && !NeedNewDisklabel(Ops.get(target, s, {}))
                      Ops.set(
                        p,
                        "dtxt",
                        _(
                          "Resize impossible due to inconsistent file system. Try checking file system under Windows."
                        )
                      )
                    end
                    Ops.set(p, "delete", true)
                  end
                  deep_copy(p)
                end
              )
            end
          end
        elsif mode == :reuse
          valid = Builtins.listmap(ddev) do |s|
            if Builtins.find(Ops.get_list(target, [s, "partitions"], [])) do |p|
                Ops.get_boolean(p, "linux", false) &&
                  Builtins.size(Ops.get_string(p, "mount", "")) == 0 &&
                  !Ops.get_boolean(p, "delete", false) &&
                  Storage.CanEdit(p, false)
              end != nil
              next { s => true }
            else
              next { s => false }
            end
          end
        elsif mode == :remove
          valid = Builtins.listmap(ddev) do |s|
            if Builtins.find(Ops.get_list(target, [s, "partitions"], [])) do |p|
                Ops.get_boolean(p, "linux", false) &&
                  Builtins.size(Ops.get_string(p, "mount", "")) == 0 &&
                  !Ops.get_boolean(p, "delete", false) &&
                  Storage.CanDelete(p, Ops.get(target, s, {}), false)
              end != nil
              next { s => true }
            else
              next { s => false }
            end
          end
          Builtins.foreach(ddev) do |s|
            Ops.set(
              target,
              [s, "partitions"],
              remove_p_settings(
                Ops.get_list(target, [s, "partitions"], []),
                ["/", "/home"]
              )
            )
          end
          Builtins.foreach(Builtins.filter(ddev) { |d| Ops.get(valid, d, false) }) do |s|
            Ops.set(
              target,
              [s, "partitions"],
              remove_one_partition(Ops.get(target, s, {}))
            )
          end
        elsif mode == :resize
          valid = Builtins.listmap(ddev) do |s|
            if Builtins.find(Ops.get_list(target, [s, "partitions"], [])) do |p|
                usable_for_win_resize(p, true)
              end != nil
              next { s => true }
            else
              next { s => false }
            end
          end
          Builtins.foreach(Builtins.filter(ddev) { |d| Ops.get(valid, d, false) }) do |s|
            pl = Builtins.filter(Ops.get_list(target, [s, "partitions"], [])) do |p|
              usable_for_win_resize(p, true)
            end
            if Ops.greater_than(Builtins.size(pl), 0)
              pl = Builtins.sort(pl) do |a, b|
                Ops.greater_than(
                  Ops.get_integer(a, "size_k", 0),
                  Ops.get_integer(b, "size_k", 0)
                )
              end
              Ops.set(
                target,
                [s, "partitions"],
                Builtins.maplist(Ops.get_list(target, [s, "partitions"], [])) do |p|
                  if usable_for_win_resize(p, true) &&
                      Ops.get_string(p, "device", "") ==
                        Ops.get_string(pl, [0, "device"], "")
                    cs = Ops.get_integer(target, [s, "cyl_size"], 1)
                    Ops.set(p, "resize", true)
                    Ops.set(
                      p,
                      ["region", 1],
                      Ops.divide(
                        Ops.subtract(
                          Ops.add(
                            Ops.get_integer(p, ["winfo", "new_size"], 0),
                            cs
                          ),
                          1
                        ),
                        cs
                      )
                    )
                    Ops.set(
                      p,
                      "win_max_length",
                      Ops.divide(
                        Ops.subtract(
                          Ops.add(
                            Ops.get_integer(p, ["winfo", "max_win_size"], 0),
                            cs
                          ),
                          1
                        ),
                        cs
                      )
                    )
                    # nil means partition to be defined
                    if Storage.resize_partition == nil
                      Storage.resize_partition = Ops.get_string(p, "device", "")
                      Storage.resize_partition_data = deep_copy(p)
                      Storage.resize_cyl_size = cs
                    # if partitions match, override proposal with stored data
                    elsif Storage.resize_partition ==
                        Ops.get_string(p, "device", "") &&
                        Storage.resize_partition != ""
                      p = deep_copy(Storage.resize_partition_data)
                    end
                  end
                  deep_copy(p)
                end
              )
              Builtins.y2milestone(
                "get_inst_proposal res parts %1",
                Ops.get_list(target, [s, "partitions"], [])
              )
            end
          end
        end
        Builtins.y2milestone("get_inst_proposal mode %1 valid %2", mode, valid)
        Builtins.foreach(Builtins.filter(ddev) { |d| Ops.get(valid, d, false) }) do |s|
          conf = { "partitions" => [] }
          disk = Ops.get(target, s, {})
          p = can_boot_reuse(
            s,
            Ops.get_string(disk, "label", "msdos"),
            need_boot(disk),
            Ops.get_integer(disk, "max_primary", 4),
            Ops.get_list(disk, "partitions", [])
          )
          Ops.set(
            disk,
            "partitions",
            special_boot_proposal_prepare(Ops.get_list(disk, "partitions", []))
          )
          have_home = false
          have_root = false
          have_boot = (mode != :free || Partitions.EfiBoot) &&
            Ops.greater_than(Builtins.size(p), 0)
          Ops.set(disk, "partitions", p) if have_boot
          r = can_swap_reuse(s, Ops.get_list(disk, "partitions", []), target)
          have_swap = Ops.greater_than(Builtins.size(r), 0)
          Builtins.y2milestone(
            "get_inst_proposal have_boot %1 have_swap %2",
            have_boot,
            have_swap
          )
          if Builtins.haskey(r, "partitions")
            Ops.set(disk, "partitions", Ops.get_list(r, "partitions", []))
          elsif Builtins.haskey(r, "targets")
            target = Ops.get_map(r, "targets", {})
          end
          swap_sizes = []
          avail_size = get_usable_size_mb(disk, mode == :reuse)
          Builtins.y2milestone(
            "get_inst_proposal disk %1 mode %2 avail %3",
            s,
            mode,
            avail_size
          )
          if Ops.greater_than(avail_size, 0)
            if mode == :reuse
              parts = Ops.get_list(disk, "partitions", [])
              tmp = []
              if GetProposalHome() &&
                  Ops.greater_than(
                    avail_size,
                    Ops.get_integer(opts, "home_limit", 0)
                  )
                tmp = can_home_reuse(4 * 1024, 0, parts)
                if Ops.greater_than(Builtins.size(tmp), 0)
                  have_home = true
                  parts = deep_copy(tmp)
                end
              end
              tmp = can_root_reuse(
                Ops.get_integer(opts, "root_base", 0),
                Ops.get_integer(opts, "root_max", 0),
                parts
              )
              if Ops.greater_than(Builtins.size(tmp), 0)
                have_root = true
                parts = deep_copy(tmp)
              end
              Ops.set(disk, "partitions", parts)
              Builtins.y2milestone(
                "get_inst_proposal reuse have_home %1 have_root %2",
                have_home,
                have_root
              )
              if have_home && have_root
                Builtins.y2milestone(
                  "get_inst_proposal reuse parts %1",
                  Ops.get_list(disk, "partitions", [])
                )
              end
            end
            if !have_swap
              swap_sizes = get_swap_sizes(avail_size)
              swap = {
                "mount"       => "swap",
                "increasable" => true,
                "fsys"        => :swap,
                "maxsize"     => 2 * 1024 * 1024 * 1024,
                "size"        => Ops.multiply(
                  Ops.multiply(Ops.get(swap_sizes, 0, 256), 1024),
                  1024
                )
              }
              Ops.set(
                conf,
                "partitions",
                Builtins.add(Ops.get_list(conf, "partitions", []), swap)
              )
            end
            if !have_root
              Ops.set(
                conf,
                "partitions",
                Builtins.add(Ops.get_list(conf, "partitions", []), root)
              )
            end
            old_root = {}
            if !have_home && GetProposalHome() &&
                Ops.less_than(
                  Ops.get_integer(opts, "home_limit", 0),
                  avail_size
                )
              home = {
                "mount"       => "/home",
                "increasable" => true,
                "fsys"        => PropDefaultHomeFs(),
                "size"        => 512 * 1024 * 1024,
                "pct"         => Ops.subtract(
                  100,
                  Ops.get_integer(opts, "root_percent", 40)
                )
              }
              Ops.set(
                conf,
                "partitions",
                Builtins.maplist(Ops.get_list(conf, "partitions", [])) do |p2|
                  if Ops.get_string(p2, "mount", "") == "/"
                    old_root = deep_copy(p2)
                    Ops.set(
                      p2,
                      "pct",
                      Ops.get_integer(opts, "root_percent", 40)
                    )
                    Ops.set(
                      p2,
                      "maxsize",
                      Ops.multiply(
                        Ops.multiply(Ops.get_integer(opts, "root_max", 0), 1024),
                        1024
                      )
                    )
                    Ops.set(
                      p2,
                      "size",
                      Ops.multiply(
                        Ops.multiply(
                          Ops.get_integer(opts, "root_base", 0),
                          1024
                        ),
                        1024
                      )
                    )
                  end
                  deep_copy(p2)
                end
              )
              Ops.set(
                conf,
                "partitions",
                Builtins.add(Ops.get_list(conf, "partitions", []), home)
              )
            end
            ps1 = do_flexible_disk_conf(disk, conf, have_boot, mode == :reuse)
            if Ops.greater_than(Builtins.size(old_root), 0) &&
                !Ops.get_boolean(ps1, "ok", false)
              Ops.set(
                conf,
                "partitions",
                Builtins.filter(Ops.get_list(conf, "partitions", [])) do |p2|
                  Ops.get_string(p2, "mount", "") != "/home" &&
                    Ops.get_string(p2, "mount", "") != "/"
                end
              )
              Ops.set(
                conf,
                "partitions",
                Builtins.add(Ops.get_list(conf, "partitions", []), old_root)
              )
              ps1 = do_flexible_disk_conf(disk, conf, have_boot, mode == :reuse)
            end
            if !have_swap
              diff = Ops.subtract(
                Ops.get(swap_sizes, 0, 256),
                Ops.get(swap_sizes, 1, 256)
              )
              diff = Ops.unary_minus(diff) if Ops.less_than(diff, 0)
              Builtins.y2milestone(
                "get_inst_proposal diff:%1 ps1 ok:%2",
                diff,
                Ops.get_boolean(ps1, "ok", false)
              )
              if !Ops.get_boolean(ps1, "ok", false) && Ops.greater_than(diff, 0) ||
                  Ops.greater_than(diff, 100)
                Ops.set(
                  conf,
                  ["partitions", 0, "size"],
                  Ops.multiply(
                    Ops.multiply(Ops.get(swap_sizes, 1, 256), 1024),
                    1024
                  )
                )
                ps2 = do_flexible_disk_conf(
                  disk,
                  conf,
                  have_boot,
                  mode == :reuse
                )
                Builtins.y2milestone(
                  "get_inst_proposal ps2 ok:%1",
                  Ops.get_boolean(ps2, "ok", false)
                )
                if Ops.get_boolean(ps2, "ok", false)
                  rp1 = Builtins.find(
                    Ops.get_list(ps1, ["disk", "partitions"], [])
                  ) do |p2|
                    !Ops.get_boolean(p2, "delete", false) &&
                      Ops.get_string(p2, "mount", "") == "/"
                  end
                  rp2 = Builtins.find(
                    Ops.get_list(ps2, ["disk", "partitions"], [])
                  ) do |p2|
                    !Ops.get_boolean(p2, "delete", false) &&
                      Ops.get_string(p2, "mount", "") == "/"
                  end
                  Builtins.y2milestone("get_inst_proposal rp1:%1", rp1)
                  Builtins.y2milestone("get_inst_proposal rp2:%1", rp2)
                  if rp1 == nil ||
                      rp2 != nil &&
                        Ops.greater_than(
                          Ops.get_integer(rp2, "size_k", 0),
                          Ops.get_integer(rp1, "size_k", 0)
                        )
                    ps1 = deep_copy(ps2)
                  end
                end
              end
            end
            if Ops.get_boolean(ps1, "ok", false)
              mb = [get_mb_sol(ps1, "/")]
              if GetProposalHome()
                home_mb = get_mb_sol(ps1, "/home")
                mb = Builtins.add(mb, home_mb)
                # penalty for not having separate /home
                if home_mb == 0
                  Ops.set(mb, 0, Ops.divide(Ops.get_integer(mb, 0, 0), 2))
                end
              end
              if Ops.greater_than(
                  Ops.add(Ops.get_integer(mb, 0, 0), Ops.get_integer(mb, 1, 0)),
                  Ops.add(
                    Ops.get_integer(size_mb, [s, 0], 0),
                    Ops.get_integer(size_mb, [s, 1], 0)
                  )
                )
                Ops.set(solution, s, Ops.get_map(ps1, "disk", {}))
                Ops.set(size_mb, s, mb)
                Builtins.y2milestone(
                  "get_inst_proposal sol %1 mb %2",
                  s,
                  Ops.get(size_mb, s, [])
                )
              end
            end
          end
        end
        max_mb = 0
        max_disk = ""
        Builtins.foreach(size_mb) do |s, mb|
          if (!GetProposalHome() ||
              Ops.greater_than(Ops.get_integer(mb, 1, 0), 0) ||
              mode == :resize) &&
              Ops.greater_than(
                Ops.add(Ops.get_integer(mb, 1, 0), Ops.get_integer(mb, 0, 0)),
                max_mb
              )
            max_mb = Ops.add(
              Ops.get_integer(mb, 1, 0),
              Ops.get_integer(mb, 0, 0)
            )
            max_disk = s
          end
        end
        Builtins.y2milestone(
          "get_inst_proposal max_mb %1 size_mb %2",
          max_mb,
          size_mb
        )
        if Ops.greater_than(max_mb, 0) &&
            Ops.greater_than(
              Ops.get_integer(size_mb, [max_disk, 0], 0),
              2 * 1024
            ) &&
            (!GetProposalHome() ||
              Ops.greater_than(
                Ops.get_integer(size_mb, [max_disk, 1], 0),
                1 * 1024
              ))
          sol_disk = max_disk
        end
        Builtins.y2milestone(
          "get_inst_proposal mode %1 size_mb %2",
          mode,
          size_mb
        )
        if Builtins.size(sol_disk) == 0
          lb = Builtins.maplist(valid) { |s, e| e }
          if mode == :free
            mode = :reuse
          elsif mode == :reuse
            mode = :remove
          elsif mode == :remove && Builtins.find(lb) { |v| v } == nil
            mode = :resize
          elsif mode == :resize && Builtins.find(lb) { |v| v } == nil
            mode = :desperate
          elsif mode == :desperate
            mode = :end
          end
          if mode == :desperate && Builtins.size(sol_disk) == 0
            max_mb = 0
            Builtins.foreach(size_mb) do |s, mb|
              if Ops.greater_than(
                  Ops.add(Ops.get_integer(mb, 1, 0), Ops.get_integer(mb, 0, 0)),
                  max_mb
                ) &&
                  Ops.greater_than(Ops.get_integer(mb, 0, 0), 2 * 1024)
                max_mb = Ops.add(
                  Ops.get_integer(mb, 1, 0),
                  Ops.get_integer(mb, 0, 0)
                )
                sol_disk = s
              end
            end
            Builtins.y2milestone(
              "get_inst_proposal mode %1 sol_disk %2",
              mode,
              sol_disk
            )
          end
        end
      end
      Builtins.y2milestone("get_inst_proposal sol_disk %1", sol_disk)
      if Builtins.size(sol_disk) == 0
        max_mb = 0
        Builtins.foreach(size_mb) do |s, mb|
          if Ops.greater_than(
              Ops.add(Ops.get_integer(mb, 1, 0), Ops.get_integer(mb, 0, 0)),
              max_mb
            ) &&
              Ops.greater_than(Ops.get_integer(mb, 0, 0), 512)
            max_mb = Ops.add(
              Ops.get_integer(mb, 1, 0),
              Ops.get_integer(mb, 0, 0)
            )
            sol_disk = s
          end
        end
        Builtins.y2milestone("get_inst_proposal sol_disk %1", sol_disk)
      end
      Ops.set(ret, "ok", Ops.greater_than(Builtins.size(sol_disk), 0))
      if Ops.get_boolean(ret, "ok", false)
        Ops.set(
          ret,
          "target",
          remove_used_by(Ops.get_map(ret, "target", {}), sol_disk)
        )
        Ops.set(ret, ["target", sol_disk], Ops.get_map(solution, sol_disk, {}))
        Ops.set(
          ret,
          "target",
          Storage.SpecialBootHandling(Ops.get_map(ret, "target", {}))
        )
        Builtins.y2milestone(
          "get_inst_proposal sol:%1",
          Ops.get_map(ret, ["target", sol_disk], {})
        )

        post_processor = PostProcessor.new()
        ret["target"] = post_processor.process_target(ret["target"])

      end
      Builtins.y2milestone(
        "get_inst_proposal ret[ok]:%1",
        Ops.get_boolean(ret, "ok", false)
      )
      deep_copy(ret)
    end


    def remove_keys(pl, keys)
      pl = deep_copy(pl)
      keys = deep_copy(keys)
      pl = Builtins.maplist(pl) do |p|
        Builtins.foreach(keys) do |k|
          p = Builtins.remove(p, k) if Builtins.haskey(p, k)
        end
        deep_copy(p)
      end
      deep_copy(pl)
    end


    def remove_mount_points(target)
      target = deep_copy(target)
      Builtins.foreach(target) do |s, disk|
        Ops.set(
          target,
          [s, "partitions"],
          Builtins.maplist(Ops.get_list(target, [s, "partitions"], [])) do |p|
            if Builtins.haskey(p, "mount") &&
                Builtins.search(Ops.get_string(p, "mount", ""), "/windows/") != 0 &&
                Builtins.search(Ops.get_string(p, "mount", ""), "/dos/") != 0
              p = Builtins.remove(p, "mount")
            end
            deep_copy(p)
          end
        )
        remove_keys(Ops.get_list(target, [s, "partitions"], []), ["mount"])
      end
      deep_copy(target)
    end


    def remove_vm(tg, ky)
      tg = deep_copy(tg)
      Builtins.y2milestone("remove_vm key:%1", ky)
      key = Ops.add("/dev/", ky)
      if Builtins.haskey(tg, key)
        Ops.set(tg, [key, "delete"], true)
        Ops.set(
          tg,
          [key, "partitions"],
          Builtins.maplist(Ops.get_list(tg, [key, "partitions"], [])) do |p|
            Ops.set(p, "delete", true)
            deep_copy(p)
          end
        )
        Builtins.y2milestone("remove_vm removed:%1", Ops.get(tg, key, {}))
        dl = Ops.get_list(tg, [key, "devices"], [])
        Builtins.foreach(dl) do |d|
          tg = Storage.DelPartitionData(tg, d, "used_by_type")
          tg = Storage.DelPartitionData(tg, d, "used_by_device")
        end
      end
      deep_copy(tg)
    end


    def find_vm(target, ky, min_size)
      target = deep_copy(target)
      ret = ""
      key = Ops.add("/dev/", ky)
      if GetProposalLvm() && Ops.get_boolean(target, [key, "lvm2"], false) &&
          Ops.greater_or_equal(
            Ops.get_integer(target, [key, "size_k"], 0),
            min_size
          )
        ret = key
      end
      if Ops.greater_than(Builtins.size(ret), 0) &&
          GetProposalEncrypt() != Storage.IsVgEncrypted(target, key)
        ret = ""
      end
      Builtins.y2milestone(
        "find_vm key:%1 min_size:%2 ret:%3",
        ky,
        min_size,
        ret
      )
      ret
    end


    def did_remove_vg(partitions, vg)
      partitions = deep_copy(partitions)
      ret = false
      ele = [
        Ops.add("/dev/", vg),
        Ops.add("/dev/lvm/", vg),
        Ops.add("/dev/lvm2/", vg)
      ]
      Builtins.foreach(partitions) do |p|
        if !ret && Ops.get_boolean(p, "delete", false) &&
            Builtins.contains(ele, Ops.get_string(p, "used_by_device", ""))
          ret = true
        end
      end
      Builtins.y2milestone("did_remove_vg vg:%1 ret:%2", vg, ret)
      ret
    end


    def sizek_to_pe(pek, pebyte, pvcreate)
      ret = Ops.divide(
        Ops.subtract(pek, pvcreate ? 4000 : 0),
        Ops.divide(pebyte, 1024)
      )
      Builtins.y2milestone(
        "sizek_to_pe pek %1 pebyte %2 pvcreate %3 ret %4",
        pek,
        pebyte,
        pvcreate,
        ret
      )
      ret
    end


    def pe_to_sizek(pe, pebyte)
      ret = Ops.multiply(pe, Ops.divide(pebyte, 1024))
      Builtins.y2milestone(
        "pe_to_sizek pe %1 pebyte %2 ret %3",
        pe,
        pebyte,
        ret
      )
      ret
    end


    def extend_vm(vg, key, disk)
      vg = deep_copy(vg)
      disk = deep_copy(disk)
      Builtins.y2milestone("extend_vm key %1 vg %2", key, vg)
      Builtins.y2milestone("extend_vm disk %1", disk)
      devs = []
      num_pe = Ops.get_integer(vg, "pe_free", 0)
      Builtins.foreach(Ops.get_list(disk, "partitions", [])) do |p|
        if Ops.get_string(p, "vg", "") == key
          devs = Builtins.add(devs, Ops.get_string(p, "device", ""))
          num_pe = Ops.add(
            num_pe,
            sizek_to_pe(
              Ops.get_integer(p, "size_k", 0),
              Ops.get_integer(vg, "pesize", 1024),
              true
            )
          )
        end
      end
      Builtins.y2milestone("extend_vm num_pe %1 devs %2", num_pe, devs)
      Ops.set(vg, "devices_add", devs)
      Ops.set(vg, "pe_free", num_pe)
      Ops.set(
        vg,
        "size_k",
        pe_to_sizek(num_pe, Ops.get_integer(vg, "pesize", 0))
      )
      Builtins.y2milestone("extend_vm ret %1", vg)
      deep_copy(vg)
    end


    def create_vm(key, disk)
      disk = deep_copy(disk)
      Builtins.y2milestone("create_vm key:%1 disk:%2", key, disk)
      ret = {
        "type"       => :CT_LVM,
        "name"       => key,
        "device"     => Ops.add("/dev/", key),
        "lvm2"       => true,
        "create"     => true,
        "partitions" => [],
        "pesize"     => 4 * 1024 * 1024
      }
      devs = []
      num_pe = 0
      Builtins.foreach(Ops.get_list(disk, "partitions", [])) do |p|
        if Ops.get_string(p, "vg", "") == key &&
            !Ops.get_boolean(p, "delete", false)
          devs = Builtins.add(devs, Ops.get_string(p, "device", ""))
          num_pe = Ops.add(
            num_pe,
            sizek_to_pe(
              Ops.get_integer(p, "size_k", 0),
              Ops.get_integer(ret, "pesize", 1024),
              true
            )
          )
        end
      end
      Builtins.y2milestone("create_vm num_pe %1 devs %2", num_pe, devs)
      Ops.set(ret, "devices_add", devs)
      Ops.set(ret, "pe_free", num_pe)
      Ops.set(
        ret,
        "size_k",
        pe_to_sizek(num_pe, Ops.get_integer(ret, "pesize", 0))
      )
      Builtins.y2milestone("create_vm ret %1", ret)
      deep_copy(ret)
    end


    def modify_vm(vm, opts, need_swap)
      vm = deep_copy(vm)
      opts = deep_copy(opts)
      Builtins.y2milestone("modify_vm swap %1 start %2", need_swap, vm)
      Builtins.y2milestone("modify_vm opts %1", opts)
      ret = deep_copy(vm)
      free = Ops.get_integer(ret, "pe_free", 0)
      pe = Ops.get_integer(ret, "pesize", 1024)
      swsize = 0
      swlist = []
      if need_swap
        swlist = get_swap_sizes(free)
        swsize = Ops.greater_than(Ops.get(swlist, 1, 0), Ops.get(swlist, 0, 0)) ?
          Ops.get(swlist, 1, 0) :
          Ops.get(swlist, 0, 0)
      end
      Builtins.y2milestone("modify_vm swsize %1", swsize)
      swap = Builtins.find(Ops.get_list(ret, "partitions", [])) do |p|
        Ops.get_string(p, "name", "") == "swap"
      end
      root = Builtins.find(Ops.get_list(ret, "partitions", [])) do |p|
        Ops.get_string(p, "name", "") == "root"
      end
      home = Builtins.find(Ops.get_list(ret, "partitions", [])) do |p|
        Ops.get_string(p, "name", "") == "home"
      end
      Builtins.y2milestone(
        "modify_vm swap %1 root %2 home %3",
        swap,
        root,
        home
      )
      if root != nil &&
          Ops.less_than(Ops.get_integer(root, "size_k", 0), 1024 * 1024)
        Ops.set(
          ret,
          "partitions",
          Builtins.maplist(Ops.get_list(ret, "partitions", [])) do |p|
            if Ops.get_string(p, "name", "") == "root"
              Ops.set(p, "delete", true)
              free = Ops.add(
                free,
                sizek_to_pe(Ops.get_integer(p, "size_k", 0), pe, false)
              )
              Builtins.y2milestone("modify_vm remove root %1", p)
            end
            deep_copy(p)
          end
        )
        Builtins.y2milestone("modify_vm pe free %1", free)
        root = nil
      end
      Ops.set(
        ret,
        "partitions",
        Builtins.sort(Ops.get_list(ret, "partitions", [])) do |a, b|
          Ops.greater_than(
            Ops.get_integer(a, "size_k", 0),
            Ops.get_integer(b, "size_k", 0)
          )
        end
      )
      keep = ["root", "home", "swap"]
      root_pe = sizek_to_pe(
        Ops.multiply(Ops.get_integer(opts, "root_base", 0), 1024),
        pe,
        false
      )
      Builtins.y2milestone("modify_vm pe free %1 root %2", free, root_pe)
      m = Builtins.find(Ops.get_list(ret, "partitions", [])) do |p|
        !Ops.get_boolean(p, "delete", false) &&
          !Builtins.contains(keep, Ops.get_string(p, "name", ""))
      end
      while root == nil && Ops.less_than(free, root_pe) && m != nil
        Ops.set(
          ret,
          "partitions",
          Builtins.maplist(Ops.get_list(ret, "partitions", [])) do |p|
            if Ops.get_string(p, "name", "") == Ops.get_string(m, "name", "")
              Ops.set(p, "delete", true)
              free = Ops.add(
                free,
                sizek_to_pe(Ops.get_integer(p, "size_k", 0), pe, false)
              )
            end
            deep_copy(p)
          end
        )
        Builtins.y2milestone(
          "modify_vm pe free %1 root %2 del %3",
          free,
          root_pe,
          m
        )
        m = Builtins.find(Ops.get_list(ret, "partitions", [])) do |p|
          !Ops.get_boolean(p, "delete", false) &&
            !Builtins.contains(keep, Ops.get_string(p, "name", ""))
        end
      end
      if root == nil && Ops.less_than(free, root_pe) && swap != nil &&
          swsize == 0
        Ops.set(
          ret,
          "partitions",
          Builtins.maplist(Ops.get_list(ret, "partitions", [])) do |p|
            if Ops.get_string(p, "name", "") == "swap"
              Ops.set(p, "delete", true)
              free = Ops.add(
                free,
                sizek_to_pe(Ops.get_integer(p, "size_k", 0), pe, false)
              )
            end
            deep_copy(p)
          end
        )
        swap = nil
        Builtins.y2milestone("modify_vm pe free %1 root %2", free, root_pe)
      end
      if root == nil && Ops.less_than(free, root_pe) &&
          Ops.greater_than(swsize, 0)
        swsize = Ops.less_than(Ops.get(swlist, 1, 0), Ops.get(swlist, 0, 0)) ?
          Ops.get(swlist, 1, 0) :
          Ops.get(swlist, 0, 0)
        Builtins.y2milestone("modify_vm new swsize %1", swsize)
      end
      if root == nil && Ops.less_than(free, root_pe) && swap != nil &&
          Ops.less_than(
            swsize,
            Ops.divide(Ops.get_integer(swap, "size_k", 0), 1024)
          )
        Ops.set(
          ret,
          "partitions",
          Builtins.maplist(Ops.get_list(ret, "partitions", [])) do |p|
            if Ops.get_string(p, "name", "") == "swap"
              Ops.set(p, "delete", true)
              free = Ops.add(
                free,
                sizek_to_pe(Ops.get_integer(p, "size_k", 0), pe, false)
              )
            end
            deep_copy(p)
          end
        )
        swap = nil
        Builtins.y2milestone("modify_vm pe free %1 root %2", free, root_pe)
      end
      swap_pe = 0
      home_pe = 0
      if swap == nil && Ops.greater_than(swsize, 0)
        swap_pe = sizek_to_pe(Ops.multiply(swsize, 1024), pe, false)
      end
      if Ops.less_than(free, Ops.add(root_pe, swap_pe))
        Builtins.y2milestone(
          "modify_vm pe free %1 root %2 swap %3",
          free,
          root_pe,
          swap_pe
        )
        if root == nil && Ops.greater_than(swap_pe, free)
          swap_pe = free
          free = 0
        elsif swap_pe == 0
          root_pe = free
          free = 0
        else
          swap_pe = Ops.divide(
            Ops.multiply(swap_pe, free),
            Ops.add(root_pe, swap_pe)
          )
          root_pe = Ops.subtract(free, swap_pe)
          free = 0
        end
        Builtins.y2milestone(
          "modify_vm pe free %1 root %2 swap %3",
          free,
          root_pe,
          swap_pe
        )
      else
        free = Ops.subtract(free, swap_pe)
        Builtins.y2milestone(
          "modify_vm pe free %1 root %2 swap %3",
          free,
          root_pe,
          swap_pe
        )
        if home == nil && GetProposalHome() &&
            Ops.greater_than(
              free,
              sizek_to_pe(
                Ops.multiply(Ops.get_integer(opts, "home_limit", 0), 1024),
                pe,
                false
              )
            )
          tmp = Ops.divide(
            Ops.multiply(free, Ops.get_integer(opts, "root_percent", 40)),
            100
          )
          root_pe = tmp if Ops.greater_than(tmp, root_pe)
          tmp = sizek_to_pe(
            Ops.multiply(Ops.get_integer(opts, "root_max", 0), 1024),
            pe,
            false
          )
          root_pe = tmp if Ops.greater_than(root_pe, tmp)
          free = Ops.subtract(free, root_pe)
          home_pe = free
          tmp = sizek_to_pe(
            Ops.multiply(Ops.get_integer(opts, "home_max", 0), 1024),
            pe,
            false
          )
          home_pe = tmp if Ops.greater_than(home_pe, tmp)
          free = Ops.subtract(free, home_pe)
          Builtins.y2milestone(
            "modify_vm pe free %1 root %2 home %3",
            free,
            root_pe,
            home_pe
          )
        else
          tmp = sizek_to_pe(
            Ops.multiply(Ops.get_integer(opts, "root_max", 0), 1024),
            pe,
            false
          )
          root_pe = free
          root_pe = tmp if Ops.greater_than(root_pe, tmp)
          free = Ops.subtract(free, root_pe)
        end
      end
      Builtins.y2milestone(
        "modify_vm pe free %1 root %2 swap %3 home %4",
        free,
        root_pe,
        swap_pe,
        home_pe
      )
      if root == nil && Ops.greater_than(root_pe, 0)
        p = {
          "create" => true,
          "name"   => "root",
          "device" => Ops.add(Ops.get_string(ret, "device", ""), "/root"),
          "size_k" => pe_to_sizek(root_pe, pe)
        }
        p = Storage.SetVolOptions(p, "/", PropDefaultFs(), "", "", "")
        Builtins.y2milestone("modify_vm created %1", p)
        Ops.set(
          ret,
          "partitions",
          Builtins.add(Ops.get_list(ret, "partitions", []), p)
        )
      elsif root != nil
        Ops.set(
          ret,
          "partitions",
          Builtins.maplist(Ops.get_list(ret, "partitions", [])) do |p|
            if Ops.get_string(p, "name", "") == "root"
              p = Storage.SetVolOptions(p, "/", PropDefaultFs(), "", "", "")
              Builtins.y2milestone("modify_vm reuse %1", p)
            end
            deep_copy(p)
          end
        )
      end
      if swap == nil && Ops.greater_than(swap_pe, 0)
        p = {
          "create" => true,
          "name"   => "swap",
          "device" => Ops.add(Ops.get_string(ret, "device", ""), "/swap"),
          "size_k" => pe_to_sizek(swap_pe, pe)
        }
        p = Storage.SetVolOptions(p, "swap", :swap, "", "", "")
        Builtins.y2milestone("modify_vm created %1", p)
        Ops.set(
          ret,
          "partitions",
          Builtins.add(Ops.get_list(ret, "partitions", []), p)
        )
      elsif swap != nil
        Ops.set(
          ret,
          "partitions",
          Builtins.maplist(Ops.get_list(ret, "partitions", [])) do |p|
            if Ops.get_string(p, "name", "") == "swap"
              p = Storage.SetVolOptions(p, "swap", :swap, "", "", "")
              Builtins.y2milestone("modify_vm reuse %1", p)
            end
            deep_copy(p)
          end
        )
      end
      if home == nil && Ops.greater_than(home_pe, 0)
        p = {
          "create" => true,
          "name"   => "home",
          "device" => Ops.add(Ops.get_string(ret, "device", ""), "/home"),
          "size_k" => pe_to_sizek(home_pe, pe)
        }
        p = Storage.SetVolOptions(p, "/home", PropDefaultHomeFs(), "", "", "")
        Builtins.y2milestone("modify_vm created %1", p)
        Ops.set(
          ret,
          "partitions",
          Builtins.add(Ops.get_list(ret, "partitions", []), p)
        )
      elsif home != nil
        Ops.set(
          ret,
          "partitions",
          Builtins.maplist(Ops.get_list(ret, "partitions", [])) do |p|
            if Ops.get_string(p, "name", "") == "home"
              p = Storage.SetVolOptions(p, "/home", PropDefaultHomeFs(), "", "", "")
              Builtins.y2milestone("modify_vm reuse %1", p)
            end
            deep_copy(p)
          end
        )
      end
      Builtins.y2milestone("modify_vm ret %1", ret)
      deep_copy(ret)
    end


    def get_inst_prop_vm(target, key)
      target = deep_copy(target)
      Builtins.y2milestone("get_inst_prop_vm start key %1", key)
      ret = {}
      opts = GetControlCfg()
      vg_key = find_vm(
        target,
        key,
        Ops.multiply(Ops.get_integer(opts, "root_base", 0), 1024)
      )
      target = remove_mount_points(target)
      target = remove_vm(target, key) if Builtins.size(vg_key) == 0
      target = AddWinInfo(target)
      Ops.set(ret, "target", target)

      boot2 = {}
      if GetProposalEncrypt() && Partitions.EfiBoot
        boot2 = {
          "mount" => "/boot",
          "size"  => 400 * 1024 * 1024,
          "fsys"  => Partitions.DefaultFs,
          "id"    => Partitions.fsid_native
        }
      end
      ddev = get_disk_try_list(target, true)
      sol_disk = ""
      valid = {}
      size_mb = Builtins.listmap(ddev) { |s| { s => 0 } }
      keep_vg = {}
      solution = Builtins.listmap(ddev) { |s| { s => {} } }
      target = prepare_part_lists(ddev, target)
      mode = :free
      while mode != :end && Builtins.size(sol_disk) == 0
        if mode == :free || mode == :desperate
          valid = Builtins.listmap(ddev) { |s| { s => true } }
          if mode == :desperate
            ddev = get_disk_try_list(target, false)
            valid = Builtins.listmap(ddev) { |s| { s => true } }
            target = prepare_part_lists(ddev, target)
            Builtins.foreach(ddev) do |s|
              Ops.set(
                target,
                [s, "partitions"],
                remove_p_settings(
                  Ops.get_list(target, [s, "partitions"], []),
                  []
                )
              )
              if NeedNewDisklabel(Ops.get(target, s, {}))
                Ops.set(target, [s, "disklabel"], "gpt")
                Ops.set(
                  target,
                  [s, "orig_label"],
                  Ops.get_string(target, [s, "label"], "msdos")
                )
                Ops.set(target, [s, "label"], "gpt")
                Ops.set(target, [s, "del_ptable"], true)
              end
              Ops.set(
                target,
                [s, "partitions"],
                Builtins.maplist(Ops.get_list(target, [s, "partitions"], [])) do |p|
                  if (NeedNewDisklabel(Ops.get(target, s, {})) ||
                      !Builtins.contains(
                        Partitions.do_not_delete,
                        Ops.get_integer(p, "fsid", 0)
                      )) &&
                      Storage.CanDelete(p, Ops.get(target, s, {}), false)
                    if usable_for_win_resize(p, false) && !NeedNewDisklabel(Ops.get(target, s, {}))
                      Ops.set(
                        p,
                        "dtxt",
                        _(
                          "Resize impossible due to inconsistent file system. Try checking file system under Windows."
                        )
                      )
                    end
                    Ops.set(p, "delete", true)
                  end
                  deep_copy(p)
                end
              )
            end
          end
        elsif mode == :remove
          valid = Builtins.listmap(ddev) do |s|
            if Builtins.find(Ops.get_list(target, [s, "partitions"], [])) do |p|
                Ops.get_boolean(p, "linux", false) &&
                  Builtins.size(Ops.get_string(p, "mount", "")) == 0 &&
                  !Ops.get_boolean(p, "delete", false) &&
                  Storage.CanDelete(p, Ops.get(target, s, {}), false)
              end != nil
              next { s => true }
            else
              next { s => false }
            end
          end
          Builtins.foreach(Builtins.filter(ddev) { |d| Ops.get(valid, d, false) }) do |s|
            Ops.set(
              target,
              [s, "partitions"],
              remove_one_partition_vm(Ops.get(target, s, {}))
            )
          end
        elsif mode == :resize
          valid = Builtins.listmap(ddev) do |s|
            if Builtins.find(Ops.get_list(target, [s, "partitions"], [])) do |p|
                usable_for_win_resize(p, true)
              end != nil
              next { s => true }
            else
              next { s => false }
            end
          end
          Builtins.foreach(Builtins.filter(ddev) { |d| Ops.get(valid, d, false) }) do |s|
            pl = Builtins.filter(Ops.get_list(target, [s, "partitions"], [])) do |p|
              usable_for_win_resize(p, true)
            end
            if Ops.greater_than(Builtins.size(pl), 0)
              pl = Builtins.sort(pl) do |a, b|
                Ops.greater_than(
                  Ops.get_integer(a, "size_k", 0),
                  Ops.get_integer(b, "size_k", 0)
                )
              end
              Ops.set(
                target,
                [s, "partitions"],
                Builtins.maplist(Ops.get_list(target, [s, "partitions"], [])) do |p|
                  if usable_for_win_resize(p, true) &&
                      Ops.get_string(p, "device", "") ==
                        Ops.get_string(pl, [0, "device"], "")
                    cs = Ops.get_integer(target, [s, "cyl_size"], 1)
                    Ops.set(p, "resize", true)
                    Ops.set(
                      p,
                      ["region", 1],
                      Ops.divide(
                        Ops.subtract(
                          Ops.add(
                            Ops.get_integer(p, ["winfo", "new_size"], 0),
                            cs
                          ),
                          1
                        ),
                        cs
                      )
                    )
                    Ops.set(
                      p,
                      "win_max_length",
                      Ops.divide(
                        Ops.subtract(
                          Ops.add(
                            Ops.get_integer(p, ["winfo", "max_win_size"], 0),
                            cs
                          ),
                          1
                        ),
                        cs
                      )
                    )
                    # nil means partition to be defined
                    if Storage.resize_partition == nil
                      Storage.resize_partition = Ops.get_string(p, "device", "")
                      Storage.resize_partition_data = deep_copy(p)
                      Storage.resize_cyl_size = cs
                    # if partitions match, override proposal with stored data
                    elsif Storage.resize_partition ==
                        Ops.get_string(p, "device", "") &&
                        Storage.resize_partition != ""
                      p = deep_copy(Storage.resize_partition_data)
                    end
                  end
                  deep_copy(p)
                end
              )
              Builtins.y2milestone(
                "get_inst_prop_vm res parts %1",
                Ops.get_list(target, [s, "partitions"], [])
              )
            end
          end
        end
        Builtins.y2milestone("get_inst_prop_vm mode %1 valid %2", mode, valid)
        Builtins.foreach(Builtins.filter(ddev) { |d| Ops.get(valid, d, false) }) do |s|
          disk = Ops.get(target, s, {})
          conf = { "partitions" => [] }
          p = can_boot_reuse(
            s,
            Ops.get_string(disk, "label", "msdos"),
            true,
            Ops.get_integer(disk, "max_primary", 4),
            Ops.get_list(disk, "partitions", [])
          )
          Ops.set(
            disk,
            "partitions",
            special_boot_proposal_prepare(Ops.get_list(disk, "partitions", []))
          )
          have_boot = Ops.greater_than(Builtins.size(p), 0)
          Ops.set(disk, "partitions", p) if have_boot
          if !Builtins.isempty(boot2)
            p = can_rboot_reuse(
              s,
              Ops.get_string(disk, "label", "msdos"),
              true,
              Ops.get_integer(disk, "max_primary", 4),
              Ops.get_list(disk, "partitions", [])
            )
            if Ops.greater_than(Builtins.size(p), 0)
              Ops.set(disk, "partitions", p)
              boot2 = {}
            end
          end
          vg = vg_key
          if Ops.greater_than(Builtins.size(vg), 0) &&
              did_remove_vg(Ops.get_list(disk, "partitions", []), key)
            vg = ""
          end

          if have_boot
            boot = {}
          elsif need_boot(disk) || GetProposalEncrypt()
            boot = {
              "mount"   => Partitions.BootMount,
              "size"    => Partitions.ProposedBootsize,
              "fsys"    => Partitions.DefaultBootFs,
              "id"      => Partitions.FsidBoot(disk["label"]),
              "max_cyl" => Partitions.BootCyl,
              "primary" => Partitions.BootPrimary
            }
          end

          ps = do_vm_disk_conf(disk, boot, boot2, vg, key)
          if Ops.get_boolean(ps, "ok", false)
            mb = get_vm_sol(ps)
            if Ops.greater_than(
                Ops.subtract(mb, Ops.get(size_mb, s, 0)),
                Ops.divide(Ops.get(size_mb, s, 0), 40)
              )
              Builtins.y2milestone(
                "get_inst_prop_vm new sol %1 old %2 new %3",
                s,
                Ops.get(size_mb, s, 0),
                mb
              )
              Ops.set(solution, s, Ops.get_map(ps, "disk", {}))
              Ops.set(size_mb, s, mb)
            end
            if Ops.greater_than(Builtins.size(vg), 0) &&
                !Ops.get(keep_vg, s, false)
              Ops.set(keep_vg, s, true)
            end
          end
        end
        Builtins.y2milestone(
          "get_inst_prop_vm size_mb %1 keep_vg %2",
          size_mb,
          keep_vg
        )
        max_mb = 0
        max_disk = ""
        keep_disk = ""
        Builtins.foreach(size_mb) do |s, mb|
          if Ops.greater_than(mb, max_mb)
            max_mb = mb
            max_disk = s
          end
        end
        Builtins.foreach(keep_vg) do |s, keep|
          keep_disk = s if Builtins.size(keep_disk) == 0 && keep
        end
        if Ops.greater_than(Builtins.size(keep_disk), 0)
          sol_disk = keep_disk
        elsif Ops.greater_than(max_mb, 0) &&
            Ops.greater_than(
              Ops.get(size_mb, max_disk, 0),
              Ops.get_integer(opts, "vm_want", 20 * 1024)
            )
          sol_disk = max_disk
          vg_key = ""
        end
        Builtins.y2milestone(
          "get_inst_prop_vm mode %1 sol_disk %2",
          mode,
          sol_disk
        )
        if Builtins.size(sol_disk) == 0
          lb = Builtins.maplist(valid) { |s, e| e }
          if mode == :free
            mode = :remove
          elsif mode == :remove && Builtins.find(lb) { |v| v } == nil
            mode = :resize
          elsif mode == :resize && Builtins.find(lb) { |v| v } == nil
            mode = :desperate
          elsif mode == :desperate
            mode = :end
          end
        end
      end
      Builtins.y2milestone("get_inst_prop_vm sol_disk %1", sol_disk)
      if Builtins.size(sol_disk) == 0
        max_mb = 0
        Builtins.foreach(size_mb) do |s, mb|
          if Ops.greater_than(mb, max_mb)
            max_mb = mb
            sol_disk = s
          end
        end
        Builtins.y2milestone("get_inst_prop_vm sol_disk %1", sol_disk)
      end
      Ops.set(ret, "ok", Ops.greater_than(Builtins.size(sol_disk), 0))
      if Ops.get_boolean(ret, "ok", false)
        r = can_swap_reuse(
          sol_disk,
          Ops.get_list(solution, [sol_disk, "partitions"], []),
          Ops.get_map(ret, "target", {})
        )
        if Builtins.haskey(r, "partitions")
          Ops.set(
            solution,
            [sol_disk, "partitions"],
            Ops.get_list(r, "partitions", [])
          )
        elsif Builtins.haskey(r, "targets")
          Ops.set(ret, "target", Ops.get_map(r, "targets", {}))
        end
        Ops.set(
          ret,
          "target",
          remove_used_by(Ops.get_map(ret, "target", {}), sol_disk)
        )
        if Builtins.size(vg_key) == 0
          vg_key = Ops.add("/dev/", key)
          vg = Ops.get_map(ret, ["target", vg_key], {})
          vg = Builtins.union(
            vg,
            create_vm(key, Ops.get_map(solution, sol_disk, {}))
          )
          if Ops.greater_than(Builtins.size(Ops.get_list(vg, "devices", [])), 0)
            vg = Builtins.remove(vg, "devices")
          end
          Builtins.y2milestone("get_inst_prop_vm vkey %1", vg)
          Ops.set(ret, ["target", vg_key], vg)
        else
          vg = Ops.get_map(ret, ["target", vg_key], {})
          vg = extend_vm(vg, key, Ops.get_map(solution, sol_disk, {}))
          Ops.set(ret, ["target", vg_key], vg)
        end
        Ops.set(
          ret,
          ["target", vg_key],
          modify_vm(
            Ops.get_map(ret, ["target", vg_key], {}),
            opts,
            Builtins.size(r) == 0
          )
        )
        Ops.set(ret, ["target", sol_disk], Ops.get_map(solution, sol_disk, {}))
        Ops.set(
          ret,
          "target",
          Storage.SpecialBootHandling(Ops.get_map(ret, "target", {}))
        )
        Builtins.y2milestone(
          "get_inst_prop_vm sol:%1",
          Ops.get_map(ret, ["target", sol_disk], {})
        )
      end

      post_processor = PostProcessor.new()
      ret["target"] = post_processor.process_target(ret["target"])

      Builtins.y2milestone(
        "get_inst_prop_vm ret[ok]:%1",
        Ops.get_boolean(ret, "ok", false)
      )
      deep_copy(ret)
    end


    def get_proposal_vm(target, key, disk)
      target = deep_copy(target)
      disk = deep_copy(disk)
      ddev = Ops.get_string(disk, "device", "")
      Builtins.y2milestone(
        "get_proposal_vm ddev:%1 vg:%2 home:%3 lvm:%4 encrypt:%5",
        ddev,
        key,
        GetProposalHome(),
        GetProposalLvm(),
        GetProposalEncrypt()
      )
      ret = {}
      opts = GetControlCfg()
      target = remove_mount_points(target)
      target = remove_vm(target, key)
      Ops.set(ret, "target", target)

      boot2 = {}
      if GetProposalEncrypt() && Partitions.EfiBoot
        boot2 = {
          "mount" => "/boot",
          "size"  => Partitions.ProposedBootsize,
          "fsys"  => Partitions.DefaultFs,
          "id"    => Partitions.fsid_native
        }
      end
      conf = { "partitions" => [] }
      p = can_boot_reuse(
        ddev,
        Ops.get_string(disk, "label", "msdos"),
        true,
        Ops.get_integer(disk, "max_primary", 4),
        Ops.get_list(disk, "partitions", [])
      )
      Ops.set(
        disk,
        "partitions",
        special_boot_proposal_prepare(Ops.get_list(disk, "partitions", []))
      )
      have_boot = Ops.greater_than(Builtins.size(p), 0)
      Ops.set(disk, "partitions", p) if have_boot
      if !Builtins.isempty(boot2)
        p = can_rboot_reuse(
          ddev,
          Ops.get_string(disk, "label", "msdos"),
          true,
          Ops.get_integer(disk, "max_primary", 4),
          Ops.get_list(disk, "partitions", [])
        )
        if Ops.greater_than(Builtins.size(p), 0)
          Ops.set(disk, "partitions", p)
          boot2 = {}
        end
      end

      if have_boot
        boot = {}
      elsif need_boot(disk) || GetProposalEncrypt()
        boot = {
          "mount"   => Partitions.BootMount,
          "size"    => Partitions.ProposedBootsize,
          "fsys"    => Partitions.DefaultBootFs,
          "id"      => Partitions.FsidBoot(disk["label"]),
          "max_cyl" => Partitions.BootCyl,
          "primary" => Partitions.BootPrimary
        }
      end

      ps = do_vm_disk_conf(disk, boot, boot2, "", key)
      Ops.set(ret, "ok", Ops.get_boolean(ps, "ok", false))
      if Ops.get_boolean(ret, "ok", false)
        disk = Ops.get_map(ps, "disk", {})
        r = can_swap_reuse(
          ddev,
          Ops.get_list(disk, "partitions", []),
          Ops.get_map(ret, "target", {})
        )
        if Builtins.haskey(r, "partitions")
          Ops.set(disk, "partitions", Ops.get_list(r, "partitions", []))
        elsif Builtins.haskey(r, "targets")
          Ops.set(ret, "target", Ops.get_map(r, "targets", {}))
        end
        Ops.set(
          ret,
          "target",
          remove_used_by(Ops.get_map(ret, "target", {}), ddev)
        )
        vg_key = Ops.add("/dev/", key)
        vg = Ops.get_map(ret, ["target", vg_key], {})
        vg = Builtins.union(vg, create_vm(key, disk))
        if Ops.greater_than(Builtins.size(Ops.get_list(vg, "devices", [])), 0)
          vg = Builtins.remove(vg, "devices")
        end
        Builtins.y2milestone("get_proposal_vm vkey %1", vg)
        Ops.set(
          ret,
          ["target", vg_key],
          modify_vm(vg, opts, Builtins.size(r) == 0)
        )
        Ops.set(ret, ["target", ddev], disk)
        Ops.set(
          ret,
          "target",
          EncryptDevices(Ops.get_map(ret, "target", {}), vg_key)
        )
        Ops.set(
          ret,
          "target",
          Storage.SpecialBootHandling(Ops.get_map(ret, "target", {}))
        )
        Builtins.y2milestone("get_proposal_vm sol:%1", disk)
      end
      Builtins.y2milestone("get_proposal_vm ret:%1", ret)
      deep_copy(ret)
    end


    def get_inst_prop(target)
      target = deep_copy(target)
      ret = {}
      vg = GetProposalVM()
      Builtins.y2milestone(
        "get_inst_prop vg:%1 home:%2 lvm:%3 encypt:%4",
        vg,
        GetProposalHome(),
        GetProposalLvm(),
        GetProposalEncrypt()
      )
      if Builtins.isempty(vg)
        if has_flex_proposal
          ret = do_proposal_flexible(target)
        else
          ret = get_inst_proposal(target)
        end
      else
        Builtins.y2milestone("target:%1", target)
        ret = get_inst_prop_vm(target, vg)
        Ops.set(
          ret,
          "target",
          EncryptDevices(Ops.get_map(ret, "target", {}), Ops.add("/dev/", vg))
        )
      end
      Builtins.y2milestone("get_inst_prop ret:%1", ret)
      deep_copy(ret)
    end


    def SaveHeight
      display_info = UI.GetDisplayInfo
      ret = false
      if Ops.get_boolean(display_info, "TextMode", false) &&
          Ops.less_than(Ops.get_integer(display_info, "Height", 24), 40)
        ret = true
      end
      ret
    end


    def CommonWidgets()

      filesystems = [
        Item(Id(:btrfs), "BtrFS"),
        Item(Id(:ext4), "Ext4"),
        Item(Id(:xfs), "XFS")
      ]

      vb = VBox()

      vb = Builtins.add(
        vb,
        Left(
          HBox(
            HSpacing(3),
            CheckBox(
              Id(:lvm),
              Opt(:notify),
              # TRANSLATORS: checkbox text
              _("Create &LVM-based Proposal"),
              GetProposalLvm()
            )
          )
        )
      )
      vb = Builtins.add(
        vb,
        Left(
          HBox(
            HSpacing(7),
            CheckBox(
              Id(:encrypt),
              Opt(:notify),
              # TRANSLATORS: checkbox text
              _("Encr&ypt Volume Group"),
              GetProposalEncrypt()
            )
          )
        )
      )

      vb = Builtins.add(vb, VSpacing(1))

      vb = Builtins.add(
        vb,
        Left(
          HBox(
            HSpacing(4),
            ComboBox(
              Id(:root_fs),
              Opt(:notify),
              # TRANSLATORS: combobox label
              _("File System for Root Partition"),
              filesystems
            )
          )
        )
      )
      vb = Builtins.add(
        vb,
        Left(
          HBox(
            HSpacing(7),
            CheckBox(
              Id(:snapshots),
              # TRANSLATORS: checkbox text
              _("Enable Snapshots"),
              GetProposalSnapshots()
            )
          )
        )
      )
      if ! Arch.s390

        vb = Builtins.add(vb, VSpacing(1))

        vb = Builtins.add(
          vb,
          Left(
            HBox(
              HSpacing(3),
              CheckBox(
                Id(:home),
                Opt(:notify),
                # TRANSLATORS: checkbox text
                _("Propose Separate &Home Partition"),
                GetProposalHome()
              )
            )
          )
        )
        vb = Builtins.add(
          vb,
          Left(
            HBox(
              HSpacing(7),
              ComboBox(
                Id(:home_fs),
                # TRANSLATORS: combobox label
                _("File System for Home Partition"),
                filesystems
              )
            )
          )
        )
      end

      vb = Builtins.add(vb, VSpacing(1))

      vb = Builtins.add(
        vb,
        Left(
          HBox(
            HSpacing(3),
            CheckBox(
              Id(:suspend),
              # TRANSLATORS: checkbox text
              _("Enlarge &Swap for Suspend"),
              GetProposalSuspend()
            )
          )
        )
      )

      frame = VBox(
        HVCenter(
          VBox(
            Left(Label(Opt(:boldFont), _("Proposal Settings"))),
            VSpacing(0.4),
            HVCenter(vb)
          )
        )
      )

      deep_copy(frame)
    end


    def CommonWidgetsHelp()

      # TRANSLATORS: help text
      help_text =
        _(
          "<p>To create an LVM-based proposal, choose the corresponding button. The\n" +
          "LVM-based proposal can be encrypted.</p>\n"
          )

      # TRANSLATORS: help text
      help_text +=
        _(
          "<p>The filesystem for the root partition can be selected with the\n" +
          "corresponding combo box. With the filesystem BtrFS the proposal can\n" +
          "enable automatic snapshots with snapper. This will also increase the\n" +
          "size for the root partition.</p>"
          )

      # TRANSLATORS: help text
      help_text +=
        _(
          "<p>The proposal can create a separate home partition. The filesystem for\n" +
          "the home partition can be selected with the corresponding combo box.</p>"
          )

      # TRANSLATORS: help text
      help_text +=
        _(
          "<p>The swap partition can be made large enough to be used to suspend\n" +
          "the system to disk in most cases.</p>"
          )

      return help_text

    end


    def QueryProposalPassword
      no_query = false
      Storage.CreateTargetBackup("query_prop_passwd")
      Storage.RestoreTargetBackup("initial")
      if !Builtins.isempty(GetProposalPassword()) ||
          !@proposal_create_vg &&
            !Storage.NeedVgPassword(Storage.GetTargetMap, "/dev/system")
        no_query = true
      end
      Storage.RestoreTargetBackup("query_prop_passwd")
      Storage.DisposeTargetBackup("query_prop_passwd")
      return true if no_query

      UI.OpenDialog(
        VBox(
          Label(_("Enter your password for the proposal encryption.")),
          MinWidth(
            40,
            Password(
              Id(:pw1),
              # Label: get password for user root
              # Please use newline if label is longer than 40 characters
              _("Password:"),
              ""
            )
          ),
          VSpacing(0.5),
          MinWidth(
            40,
            Password(
              Id(:pw2),
              # Label: get same password again for verification
              # Please use newline if label is longer than 40 characters
              _("Reenter the password for verification:"),
              ""
            )
          ),
          Label(_("Do not forget what you enter here!")),
          ButtonBox(
            PushButton(Id(:ok), Opt(:default), Label.OKButton),
            PushButton(Id(:cancel), Label.CancelButton)
          )
        )
      )

      password = ""
      widget = nil
      begin
        # Clear password fields on every round.
        UI.ChangeWidget(Id(:pw1), :Value, "")
        UI.ChangeWidget(Id(:pw2), :Value, "")

        UI.SetFocus(Id(:pw1))

        widget = Convert.to_symbol(UI.UserInput)

        case widget
          when :ok
            password = Convert.to_string(UI.QueryWidget(Id(:pw1), :Value))
            @tmp = Convert.to_string(UI.QueryWidget(Id(:pw2), :Value))

            if !Storage.CheckEncryptionPasswords(password, @tmp, 8, false)
              widget = :again
            end
        end
      end until widget == :cancel || widget == :ok

      UI.CloseDialog

      if widget == :ok
        SetProposalPassword(password)
        return true
      else
        return false
      end
    end


    def IsCommonWidget(id)
      return [ :lvm, :encrypt, :root_fs, :snapshots, :home, :home_fs, :suspend ].include?(id)
    end


    def HandleCommonWidgets(id)

      val = UI.QueryWidget(Id(id), :Value)

      case id

        when :lvm
          UI.ChangeWidget(Id(:encrypt), :Enabled, val)

        when :encrypt
          if val
            if !QueryProposalPassword()
              UI.ChangeWidget(Id(:encrypt), :Value, false)
            end
          end

        when :root_fs
          UI.ChangeWidget(Id(:snapshots), :Enabled, val == :btrfs)

        when :home
          UI.ChangeWidget(Id(:home_fs), :Enabled, val)

      end
    end


    def EnableSuspend
      swaps = Storage.GetCreatedSwaps
      susps = Partitions.SwapSizeMb(0, true)
      ret = Builtins.size(swaps) == 1 &&
        Ops.less_than(
          Ops.divide(Ops.get_integer(swaps, [0, "size_k"], 0), 1024),
          susps
        )
      ret = ret || GetProposalSuspend()
      Builtins.y2milestone(
        "EnableSuspend csw:%1 swsize:%2 suspsize:%3 ret:%4",
        Builtins.size(swaps),
        Ops.divide(Ops.get_integer(swaps, [0, "size_k"], 0), 1024),
        susps,
        ret
      )
      ret
    end


    def CommonWidgetsPopup()

      UI.OpenDialog(
        Opt(:decorated),
        MarginBox(2, 1,
          VBox(
            CommonWidgets(),
            VSpacing(1),
            ButtonBox(
              PushButton(Id(:help), Opt(:helpButton), Label.HelpButton),
              PushButton(Id(:ok), Opt(:default), Label.OKButton),
              PushButton(Id(:cancel), Label.CancelButton)
            )
          )
        )
      )

      UI.ChangeWidget(Id(:encrypt), :Enabled, GetProposalLvm())
      UI.ChangeWidget(Id(:root_fs), :Value, GetProposalRootFs())
      UI.ChangeWidget(Id(:snapshots), :Enabled, GetProposalRootFs() == :btrfs)
      UI.ChangeWidget(Id(:home_fs), :Enabled, GetProposalHome())
      UI.ChangeWidget(Id(:home_fs), :Value, GetProposalHomeFs())
      UI.ChangeWidget(Id(:suspend), :Enabled, EnableSuspend())

      UI.ChangeWidget(Id(:help), :HelpText, CommonWidgetsHelp())

      begin
        ret = Convert.to_symbol(UI.UserInput)
        if IsCommonWidget(ret)
          HandleCommonWidgets(ret)
        end
      end until [ :ok, :cancel ].include?(ret)

      if ret == :ok
        y2milestone("setting storage proposal settings")
        SetProposalLvm(UI.QueryWidget(Id(:lvm), :Value))
        SetProposalEncrypt(UI.QueryWidget(Id(:encrypt), :Value))
        SetProposalRootFs(UI.QueryWidget(Id(:root_fs), :Value))
        SetProposalSnapshots(UI.QueryWidget(Id(:snapshots), :Value))
        SetProposalHome(UI.QueryWidget(Id(:home), :Value))
        SetProposalHomeFs(UI.QueryWidget(Id(:home_fs), :Value))
        SetProposalSuspend(UI.QueryWidget(Id(:suspend), :Value))
      end

      UI.CloseDialog()

      return ret == :ok

    end


    def CouldNotDoSnapshots(prop_target_map)
      ret = false
      if GetProposalSnapshots()
        prop_target_map.each do |device, container|
          container["partitions"].each do |volume|
            if !volume.fetch("delete", false)
              if volume.fetch("used_fs", :none) == :btrfs && volume.fetch("mount", "") == "/"
                userdata = volume.fetch("userdata", {})
                ret = userdata.fetch("/", "") != "snapshots"
              end
            end
          end
        end
      end
      log.info("CouldNotDoSnapshots ret:#{ret}")
      return ret
    end


    def CouldNotDoSeparateHome(prop_target_map)
      ret = false
      if GetProposalHome()
        ls = []
        prop_target_map.each do |k, d|
          ls = Convert.convert(
            Builtins.union(
              ls,
              Builtins.filter(Ops.get_list(d, "partitions", [])) do |p|
                !Ops.get_boolean(p, "delete", false) &&
                  Ops.greater_than(
                    Builtins.size(Ops.get_string(p, "mount", "")),
                    0
                  )
              end
            ),
            :from => "list",
            :to   => "list <map>"
          )
        end
        ret = Builtins.size(Builtins.filter(ls) do |p|
          Ops.get_string(p, "mount", "") == "/home"
        end) == 0
        Builtins.y2milestone("CouldNotDoSeparateHome ls:%1", ls)
      end
      log.info("CouldNotDoSeparateHome ret:#{ret}")
      return ret
    end


    publish :function => :SetCreateVg, :type => "void (boolean)"
    publish :function => :GetProposalHome, :type => "boolean ()"
    publish :function => :SetProposalHome, :type => "void (boolean)"
    publish :function => :GetProposalLvm, :type => "boolean ()"
    publish :function => :SetProposalLvm, :type => "void (boolean)"
    publish :function => :GetProposalEncrypt, :type => "boolean ()"
    publish :function => :SetProposalEncrypt, :type => "void (boolean)"
    publish :function => :GetProposalSnapshots, :type => "boolean ()"
    publish :function => :SetProposalSnapshots, :type => "void (boolean)"
    publish :function => :GetProposalSuspend, :type => "boolean ()"
    publish :function => :SetProposalSuspend, :type => "void (boolean)"
    publish :function => :GetProposalPassword, :type => "string ()"
    publish :function => :SetProposalPassword, :type => "void (string)"
    publish :function => :SetProposalDefault, :type => "void (boolean)"
    publish :function => :GetControlCfg, :type => "map <string, any> ()"
    publish :function => :GetProposalVM, :type => "string ()"
    publish :function => :NeedNewDisklabel, :type => "boolean (map)"
    publish :function => :flex_init_swapable, :type => "void (map <string, map>)"
    publish :function => :has_flex_proposal, :type => "boolean ()"
    publish :function => :do_flexible_disk, :type => "map <string, any> (map)"
    publish :function => :try_remove_sole_extended, :type => "list <map> (list <map>)"
    publish :function => :can_swap_reuse, :type => "map (string, list <map>, map <string, map>)"
    publish :function => :get_proposal, :type => "list <map> (boolean, map)"
    publish :function => :get_proposal_vm, :type => "map <string, any> (map <string, map>, string, map)"
    publish :function => :get_inst_prop, :type => "map <string, any> (map <string, map>)"
    publish :function => :SaveHeight, :type => "boolean ()"
    publish :function => :CommonWidgetsPopup, :type => "boolean ()"
    publish :function => :CouldNotDoSnapshots, :type => "boolean (map <string, map>)"
    publish :function => :CouldNotDoSeparateHome, :type => "boolean (map <string, map>)"
  end

  StorageProposal = StorageProposalClass.new
  StorageProposal.main
end
