# encoding: utf-8

require "yast"

module Yast

  module EP


    def self.EpContextMenuDevice(device)
      target_map = Storage.GetTargetMap

      disk = nil
      part = nil

      if Builtins.substring(device, 0, 5) == "tmpfs"
        disk = Ops.get(target_map, "/dev/tmpfs", {})
      else
        disk_ref = arg_ref(disk)
        part_ref = arg_ref(part)
        SplitDevice(target_map, device, disk_ref, part_ref)
        disk = disk_ref.value
        part = part_ref.value
      end

      case Ops.get_symbol(disk, "type", :unknown)
        when :CT_DISK, :CT_DMMULTIPATH, :CT_DMRAID, :CT_MDPART
          if part == nil
            EpContextMenuHdDisk(device)
          else
            EpContextMenuHdPartition(device)
          end
        when :CT_MD
          EpContextMenuRaid(device) if part != nil
        when :CT_LOOP
          EpContextMenuLoop(device) if part != nil
        when :CT_LVM
          if part == nil
            EpContextMenuLvmVg(device)
          else
            EpContextMenuLvmLv(device)
          end
        when :CT_DM
          EpContextMenuDm(device) if part != nil
        when :CT_BTRFS
          EpContextMenuBtrfs(device) if part != nil
        when :CT_TMPFS
          EpContextMenuTmpfs(device)
      end

      nil
    end


    def self.RescanDisks()
      UI.OpenDialog(
        Opt(:decorated),
        # popup text
        MarginBox(2, 1, Label(_("Rescanning disks...")))
      )

      Storage.ReReadTargetMap

      UI.CloseDialog
    end


  end

end
