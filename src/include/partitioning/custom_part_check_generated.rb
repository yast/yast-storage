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

# File:        ep-main.ycp
# Package:     yast2-storage
# Summary:     Expert Partitioner
# Authors:     Arvin Schnell <aschnell@suse.de>

require "storage/shadowed_vol_list"
require "storage/target_map_formatter"

module Yast
  module PartitioningCustomPartCheckGeneratedInclude

    include Yast::Logger
    include Yast::StorageHelpers::TargetMapFormatter

    POPUP_LINE_LENGTH = 70
    private_constant :POPUP_LINE_LENGTH

    def initialize_partitioning_custom_part_check_generated(include_target)
      Yast.import "Arch"
      Yast.import "Storage"
      Yast.import "StorageProposal"
      Yast.import "Partitions"
      Yast.import "Label"
      Yast.import "Mode"
      Yast.import "Product"
      Yast.import "AutoinstData"
      Yast.import "FileSystems"
      Yast.import "Stage"
      Yast.import "Region"

      Yast.include include_target, "partitioning/custom_part_helptexts.rb"

      textdomain "storage"
    end


    #---------------------------------------------------------------------
    # Set partition id (fsid) in a partition.
    #---------------------------------------------------------------------
    def adjust_fsid(partition, fsid)
      partition["fsid"] = fsid
      partition["fstype"] = Partitions.FsIdToString(fsid)
      Builtins.y2milestone("#{partition["device"]}: fsid adjusted to #{fsid} (#{partition["fstype"]})")
    end


    #---------------------------------------------------------------------
    # Fix trivial inconsistencies in the target map.
    #
    # - adjust prep types to match partition label
    #---------------------------------------------------------------------
    def sanitize_created_partition_table(targetMap)
      Builtins.y2milestone("target map to sanitize: %1", format_target_map(targetMap))

      adjusted = false

      targetMap.each_value do |disk|
        label = disk["label"]
        partitions = disk["partitions"]
        if label && partitions
          partitions.each do |partition|
            fsid = partition["fsid"]
            fstype = partition["fstype"]
            if fsid == Partitions.fsid_gpt_prep && label == "msdos"
              adjust_fsid(partition, Partitions.fsid_prep_chrp_boot)
              adjusted = true
            end
            if fsid == Partitions.fsid_prep_chrp_boot && label == "gpt"
              adjust_fsid(partition, Partitions.fsid_gpt_prep)
              adjusted = true
            end
          end
        end
      end

      if adjusted
        Builtins.y2milestone("target map sanitized: %1", format_target_map(targetMap))
      else
        Builtins.y2milestone("target map was perfect")
      end
    end


    #---------------------------------------------------------------------
    # Checks the generated partition table.
    #---------------------------------------------------------------------
    # Checkpoints:
    # - popup if unformated mounted partitions exist
    #   - detect the fs on this partition
    # - checks if / mountpoint is set
    # - check if the boot partition ends in a bootable cylinder (/or/boot)

    def check_created_partition_table(targetMap, installation)
      sanitize_created_partition_table(targetMap)
      targetMap = deep_copy(targetMap)
      Builtins.y2milestone(
        "Now checking generated target map. installation: %1",
        installation
      )

      show_all_popups = false

      diskless = true

      partition_mounted_but_not_formated = false
      swap_found = false
      boot_found = false
      prep_found = false
      boot_mount_point = ""
      root_found = false
      gpt_boot_ia64 = false
      boot_end = 0
      root_end = 0
      root_raid = false
      root_dmraid = false
      boot_raid = false
      root_lvm = false
      root_fs = :unknown
      snapshots_size_warning = false
      boot_fs = :unknown
      boot_fsid = 0
      boot_size_k = 0
      boot_size_check = !(Arch.board_chrp || Arch.board_prep ||
        Arch.board_iseries ||
        Arch.board_mac)
      fat_system_mount = false
      fat_system_boot = false
      raid_type = ""
      rootdlabel = ""
      shadowed_root_subvols = []

      Builtins.foreach(targetMap) do |disk, diskinfo|
        part_info = Ops.get_list(diskinfo, "partitions", [])
        cyl_size = Ops.get_integer(diskinfo, "cyl_size", 1000000)
        if Builtins.contains(
            [:CT_DISK, :CT_DMRAID, :CT_DMMULTIPATH, :CT_MDPART],
            Ops.get_symbol(diskinfo, "type", :CT_UNKNOWN)
          )
          diskless = false
        end
        Builtins.foreach(part_info) do |part|
          # All valid partitions ...
          fsid = Ops.get_integer(part, "fsid", 0)
          mountpoint = Ops.get_string(part, "mount", "")
          #////////////////////////////////////////////////////////////
          # look for root and boot
          #////////////////////////////////////////////////////////////
          if mountpoint == "/"
            root_found = true
            root_dmraid = Ops.get_symbol(diskinfo, "type", :CT_UNKNOWN) == :CT_DMRAID
            root_end = Region.End(Ops.get_list(part, "region", []))
            if !Builtins.contains(
                [:primary, :logical],
                Ops.get_symbol(part, "type", :unknown)
              )
              # root_end does not have anything to do with physical cylinders
              root_end = 0
            end
            root_fs = Ops.get_symbol(part, "used_fs", :unknown)

            if Ops.get_symbol(part, "type", :unknown) == :sw_raid
              root_raid = true
            end
            raid_type = Ops.get_string(part, "raid_type", "") if !boot_raid
            root_lvm = true if Ops.get_symbol(part, "type", :unknown) == :lvm
            if diskinfo.fetch( "type", :CT_UNKNOWN ) == :CT_DISK
               rootdlabel = diskinfo.fetch( "label", "" )
            end
            snapshots_size_warning = !check_root_for_snapshot_size(part)

            # search for shadowed subvolumes of root filesystem
            targetMap.each do |dev, disk|
              parts = disk.fetch("partitions", [])
              parts.each do |other_part|
                if other_part.has_key?("mount")
                  shadowed = ShadowedVolList.new(partition: part, mount_point: other_part["mount"])
                  shadowed_root_subvols += shadowed.to_a
                end
              end
            end

          elsif mountpoint == Partitions.BootMount
            if (Partitions.EfiBoot || Arch.ia64) &&
                Ops.get_string(diskinfo, "label", "gpt") != "gpt"
              gpt_boot_ia64 = true
            end
            boot_found = true
            boot_mount_point = mountpoint
            if Ops.get_symbol(diskinfo, "type", :CT_UNKNOWN) == :CT_DISK
              boot_end = Region.End(Ops.get_list(part, "region", []))
            else
              boot_end = 0
            end
            boot_fs = Ops.get_symbol(part, "used_fs", :unknown)
            boot_size_k = Ops.get_integer(part, "size_k", 0)
            if Ops.get_symbol(part, "type", :unknown) == :sw_raid
              boot_raid = true
            end
            raid_type = Ops.get_string(part, "raid_type", "")
          elsif mountpoint == ""
            dlabel = diskinfo["label"]
            if Partitions.PrepBoot &&
                (fsid == Partitions.FsidBoot(dlabel) || fsid == 6)
              boot_found = true
              prep_found = true
              boot_mount_point = mountpoint
              boot_end = Region.End(Ops.get_list(part, "region", []))
              boot_fs = Ops.get_symbol(part, "used_fs", :unknown)
              boot_size_k = Ops.get_integer(part, "size_k", 0)
              boot_fsid = Partitions.FsidBoot(dlabel)
            elsif Arch.board_mac &&
                Ops.get_symbol(part, "used_fs", :unknown) == :hfs
              boot_found = true
              boot_mount_point = mountpoint
              boot_end = Region.End(Ops.get_list(part, "region", []))
              boot_fs = Ops.get_symbol(part, "used_fs", :unknown)
              boot_size_k = Ops.get_integer(part, "size_k", 0)
            elsif !Partitions.EfiBoot() && fsid == Partitions.fsid_bios_grub
              boot_found = true
              boot_mount_point = mountpoint
              boot_end = Region.End(Ops.get_list(part, "region", []))
              boot_fs = :none
              boot_size_k = Ops.get_integer(part, "size_k", 0)
              boot_fsid = Partitions.fsid_bios_grub
            end
          end
          #////////////////////////////////////////////////////////////
          # look for swap partition and check:
          # - is there any
          #
          # check only "swap" not fsid cause for example on pdisk fsid = 0
          #
          #////////////////////////////////////////////////////////////
          swap_found = true if mountpoint == "swap"
          if Ops.get_symbol(part, "used_fs", :unknown) == :vfat &&
              Ops.get_boolean(part, "format", false)
            # uses a mountpoint like /usr / /var /home /opt with fat
            if !fat_system_mount &&
                Builtins.contains(
                  ["/usr", "/", "/home", "/var", "/opt"],
                  mountpoint
                )
              fat_system_mount = true
            end
          end
          if !(Partitions.EfiBoot || Arch.ia64) &&
              Ops.get_symbol(part, "used_fs", :unknown) == :vfat &&
              Ops.get_boolean(part, "format", false)
            # uses mountpoint /boot with fat
            fat_system_boot = true if !fat_system_boot && mountpoint == "/boot"
          end
          if !Ops.get_boolean(part, "format", false) &&
              Ops.get_symbol(part, "used_fs", :unknown) != :nfs &&
              FileSystems.IsSystemMp(Ops.get_string(part, "mount", ""), false) &&
              Ops.get_string(part, "mount", "") != "/boot/efi"
            partition_mounted_but_not_formated = true
          end
        end
      end
      if rootdlabel.empty?
        targetMap.values do |diskinfo|
          if diskinfo.fetch( "type", :CT_UNKNOWN ) == :CT_DISK &&
             rootdlabel.empty?
            rootdlabel = diskinfo.fetch( "label", "" )
          end
        end
      end

      log.info("diskless:#{diskless}")
      log.info("root_found:#{root_found} root_fs:#{root_fs} rootdlabel:#{rootdlabel}")
      # Note to the uninitiated:
      #   While 'boot_fs' *is* the fs of the boot partition, 'boot_fsid' is *not* its fsid.
      #   Nope.
      log.info("boot_found:#{boot_found} boot_fs:#{boot_fs} boot_fsid:#{boot_fsid}")
      log.info("root_dmraid:#{root_dmraid} root_raid:#{root_raid} boot_raid:#{boot_raid} raid_type:#{raid_type}")

      ok = true

      if !root_found && installation || show_all_popups
        # popup text
        message = _(
          "You have not assigned a root partition for\n" +
            "installation. This does not work. Assign the root mount point \"/\" to a\n" +
            "partition.\n" +
            "\n" +
            "Really use this setup?\n"
        )

        ok = false if !Popup.YesNo(message)
      end

      if fat_system_mount || show_all_popups
        # popup text
        message = _(
          "You tried to mount a FAT partition to one of the following mount\n" +
            "points: /, /usr, /home, /opt or /var. This will very likely cause problems.\n" +
            "Use a Linux file system, such as ext3 or ext4, for these mount points.\n" +
            "\n" +
            "Really use this setup?\n"
        )

        ok = false if !Popup.YesNo(message)
      end

      if fat_system_boot || show_all_popups
        # popup text
        message = _(
          "You tried to mount a FAT partition to the\n" +
            "mount point /boot. This will very likely cause problems. Use a Linux file\n" +
            "system, such as ext3 or ext4, for this mount point.\n" +
            "\n" +
            "Really use this setup?\n"
        )

        ok = false if !Popup.YesNo(message)
      end

      if boot_found && boot_fsid != Partitions.fsid_bios_grub &&
          Builtins.contains([:btrfs], boot_fs) || show_all_popups
        # popup text
        message = _(
          "You have mounted a partition with Btrfs to the\n" +
            "mount point /boot. This will very likely cause problems. Use a Linux file\n" +
            "system, such as ext3 or ext4, for this mount point.\n" +
            "\n" +
            "Really use this setup?\n"
        )

        ok = false if !Popup.YesNo(message)
      end

      # A PReP/CHRP partition is not supposed to be mounted. So if we find any
      # other /boot partition, we should warn the user.
      #
      # Note:
      #   This covers the case *with* /boot but no prep. There's a similar blob below
      #   covering the case *without* /boot.
      if boot_found && Partitions.prep_boot_needed? && !prep_found && installation || show_all_popups
        message = _(
          "Warning:\n" \
          "Your system needs a boot partition, either with type 0x41 PReP/CHRP\n" \
          "on MS-DOS or type 0x00 GPT PReP Boot on GPT.\n" \
          "Please, consider creating one.\n" \
          "\n" \
          "Really use this setup?\n"
        )

        ok = false if !Popup.YesNo(message)
      end

      if boot_found && boot_fsid!=Partitions.fsid_bios_grub && installation || show_all_popups
        if Ops.greater_or_equal(boot_end, Partitions.BootCyl) || show_all_popups
          # popup text, %1 is a number
          message = Builtins.sformat(
            _(
              "Warning:\n" +
                "Your boot partition ends above cylinder %1.\n" +
                "Your BIOS does not seem able to boot\n" +
                "partitions above cylinder %1.\n" +
                "With the current setup, your %2\n" +
                "installation might not be directly bootable.\n" +
                "\n" +
                "Really use this setup?\n"
            ),
            Partitions.BootCyl,
            Product.name
          )

          ok = false if !Popup.YesNo(message)
        end

        if Ops.less_than(boot_size_k, 12 * 1024) && boot_size_check || show_all_popups
          # popup text, %1 is a size
          message = Builtins.sformat(
            _(
              "Warning:\n" +
                "Your boot partition is smaller than %1.\n" +
                "We recommend to increase the size of /boot.\n" +
                "\n" +
                "Really keep this size of the boot partition?\n"
            ),
            Storage.KByteToHumanStringOmitZeroes(12 * 1024)
          )

          ok = false if !Popup.YesNo(message)
        end
      end

      #/////////////////////////// NO BOOT ///////////////////////////
      if (!boot_found && installation &&
          !Partitions.EfiBoot && rootdlabel=="gpt") || show_all_popups
        message = _(
          "Warning: There is no partition of type bios_grub present.\n" \
          "Such a partition is recommended (required with Btrfs) when Grub2 is\n" \
          "installed in the MBR of a GPT disk. It must be unformatted and\n" \
          "approximately 1MB large." \
          "\n" \
          "Really use this setup?\n"
          )

        ok = false if !Popup.YesNo(message)
        # set it to true to avoid further possible boot warnings
        boot_found = true
      end

      if !boot_found && installation || show_all_popups
        if Partitions.prep_boot_needed? && !diskless || show_all_popups
          # popup text
          # If the user chooses 'no' here, the system will not be able to
          # boot from the hard drive!
          message = Builtins.sformat(
            _(
              "Warning: There is no partition mounted as /boot.\n" +
                "To boot from your hard disk, a small /boot partition\n" +
                "(approx. %1) is required.  Consider creating one\n" +
                "with type 0x41 PReP/CHRP on MS-DOS or type 0x00 GPT\n" +
                "PReP Boot on GPT.\n" +
                "\n" +
                "Really use the setup without /boot partition?\n"
            ),
            Storage.KByteToHumanStringOmitZeroes(4 * 1024)
          )

          ok = false if !Popup.YesNo(message)
        end

        # no boot but root
        if (Ops.greater_or_equal(root_end, Partitions.BootCyl) || show_all_popups) &&
            AutoinstData.BootCylWarning
          # popup text
          message = Builtins.sformat(
            _(
              "Warning: According to your setup, you intend to\n" +
                "boot your machine from the root partition (/), which, unfortunately,\n" +
                "has an end cylinder above %1. Your BIOS does not seem capable\n" +
                "of booting partitions beyond the %1 cylinder boundary,\n" +
                "which means your %2 installation will not be\n" +
                "directly bootable.\n" +
                "\n" +
                "Really use this setup?\n"
            ),
            Partitions.BootCyl,
            Product.name
          )

          ok = false if !Popup.YesNo(message)
        end

      end

      if !shadowed_root_subvols.empty? || show_all_popups
        if shadowed_root_subvols.empty?
          subvol_list = ""
        else
          subvols = shadowed_root_subvols.map { |vol| vol["name"] }
          subvol_list = format_subvols(subvols)
        end
        message = _(
          "Warning: Some subvolumes of the root filesystem are shadowed by\n" +
          "mount points of other filesystem. This could lead to problems.\n" +
          "%s" +
          "\n" +
          "Really use this setup?\n"
        ) % subvol_list

        ok = false if !Popup.YesNo(message)
      end

      ok = show_snapshots_size_warning if snapshots_size_warning || show_all_popups

      # iSeries has no problems with this configuration
      # an initrd will be created and you can boot from a kernel slot
      if installation && !Arch.board_iseries &&
          ((root_raid && !boot_found || boot_raid) && raid_type != "raid1" || show_all_popups) &&
          AutoinstData.BootRaidWarning
        # popup text
        message = Builtins.sformat(
          _(
            "Warning: With your current setup, your %1\n" +
              "installation might not be directly bootable, because\n" +
              "your files below \"/boot\" are on a software RAID device.\n" +
              "The boot loader setup sometimes fails in this configuration.\n" +
              "\n" +
              "Really use this setup?\n"
          ),
          Product.name
        )

        ok = false if !Popup.YesNo(message)
      end

      if (Partitions.EfiBoot || Arch.ia64) && installation &&
          (!boot_found || boot_fs != :vfat) || show_all_popups
        # popup text
        message = Builtins.sformat(
          _(
            "Warning: With your current setup, your %2 installation\n" +
              "will encounter problems when booting, because you have no\n" +
              "FAT partition mounted on %1.\n" +
              "\n" +
              "This will cause severe problems with the normal boot setup.\n" +
              "\n" +
              "If you do not know exactly what you are doing, use a normal\n" +
              "FAT partition for your files below %1.\n" +
              "\n" +
              "Really use this setup?\n"
          ),
          Partitions.BootMount,
          Product.name
        )

        ok = false if !Popup.YesNo(message)
      end

      if root_dmraid && !boot_found || show_all_popups
        # popup text
        message = Builtins.sformat(
          _(
            "Warning: With your current setup, your %2 installation will\n" +
              "encounter problems when booting, because you have no \n" +
              "separate %1 partition on your RAID disk.\n" +
              "\n" +
              "This will cause severe problems with the normal boot setup.\n" +
              "\n" +
              "If you do not know exactly what you are doing, use a normal\n" +
              "partition for your files below %1.\n" +
              "\n" +
              "Really use this setup?\n"
          ),
          Partitions.BootMount,
          Product.name
        )

        ok = false if !Popup.YesNo(message)
      end

      if (Partitions.EfiBoot || Arch.ia64) && installation && boot_found && gpt_boot_ia64 || show_all_popups
        # popup text
        message = Ops.add(
          Ops.add(ia64_gpt_text, "\n"),
          _("Really use this setup?")
        )

        ok = false if !Popup.YesNo(message)
      end

      if !swap_found && Stage.initial && root_fs != :nfs || show_all_popups
        # popup text
        message = _(
          "\n" +
            "You have not assigned a swap partition. In most cases, we highly recommend \n" +
            "to create and assign a swap partition.\n" +
            "Swap partitions on your system are listed in the main window with the\n" +
            "type \"Linux Swap\". An assigned swap partition has the mount point \"swap\".\n" +
            "You can assign more than one swap partition, if desired.\n" +
            "\n" +
            "Really use the setup without swap partition?\n"
        )

        ok = false if !Popup.YesNo(message)
      end

      if partition_mounted_but_not_formated && installation || show_all_popups
        # popup text
        message = _(
          "\n" +
            "You chose to install onto an existing partition that will not be\n" +
            "formatted. YaST cannot guarantee your installation will succeed,\n" +
            "particularly in any of the following cases:\n"
        ) +
          # continued popup text
          _(
            "- if this is an existing ReiserFS partition\n" +
              "- if this partition already contains a Linux distribution that will be\n" +
              "overwritten\n" +
              "- if this partition does not yet contain a file system\n"
          ) +
          # continued popup text
          _(
            "If in doubt, better go back and mark this partition for\n" +
              "formatting, especially if it is assigned to one of the standard mount points\n" +
              "like /, /boot, /opt or /var.\n"
          ) +
          # continued popup text
          _(
            "If you decide to format the partition, all data on it will be lost.\n" +
              "\n" +
              "Really keep the partition unformatted?\n"
          )

        ok = false if !Popup.YesNo(message)
      end

      ok
    end

    def format_subvols(subvols)
      # Extra space needed for the regexp
      all = subvols.join(', ') + " "
      lines = all.scan(/.{1,#{POPUP_LINE_LENGTH}}\s/).map(&:strip)
      "\n#{lines.join("\n")}\n"
    end

    def check_devices_used(partitions, not_cr)
      partitions = deep_copy(partitions)
      ret = :UB_NONE
      pl = Builtins.filter(partitions) { |p| Storage.IsUsedBy(p) }
      if not_cr && Ops.greater_than(Builtins.size(pl), 0)
        tg = Storage.GetTargetMap
        ppl = []
        Builtins.foreach(pl) do |p|
          if Ops.get_symbol(p, "used_by_type", :UB_NONE) == :UB_MD ||
              Ops.get_symbol(p, "used_by_type", :UB_NONE) == :UB_DM
            dev = Ops.get_string(p, "used_by_device", "")
            pa = Storage.GetPartition(tg, dev)
            if Builtins.size(pa) == 0 || !Ops.get_boolean(pa, "create", false)
              ppl = Builtins.add(ppl, p)
            end
          elsif Ops.get_symbol(p, "used_by_type", :UB_NONE) == :UB_LVM
            if !Ops.get_boolean(
                tg,
                [Ops.get_string(p, "used_by_device", ""), "create"],
                false
              )
              ppl = Builtins.add(ppl, p)
            end
          end
        end
        pl = deep_copy(ppl)
      end
      if Ops.greater_than(Builtins.size(pl), 0)
        ret = Ops.get_symbol(pl, [0, "used_by_type"], :UB_NONE)
      end
      ret
    end


    def check_device_edit(curr_part)
      curr_part = deep_copy(curr_part)
      used = check_devices_used([curr_part], false)

      if used == :UB_MD
        # popup text %1 is replaced by a raid name e.g. md0
        Popup.Message(
          Builtins.sformat(
            _(
              "The selected device belongs to the RAID (%1).\nRemove it from the RAID before editing it.\n"
            ),
            Ops.get_string(curr_part, "used_by_device", "")
          )
        )
        return false
      elsif used == :UB_LVM
        # popup text %1 is replaced by a name e.g. system
        Popup.Message(
          Builtins.sformat(
            _(
              "The selected device belongs to a volume group (%1).\nRemove it from the volume group before editing it.\n"
            ),
            Ops.get_string(curr_part, "used_by_device", "")
          )
        )
      elsif used != :UB_NONE
        # popup text %1 is replaced by a name e.g. system
        Popup.Message(
          Builtins.sformat(
            _(
              "The selected device is used by volume (%1).\nRemove the volume before editing it.\n"
            ),
            Ops.get_string(curr_part, "used_by_device", "")
          )
        )
      end
      ret = used == :UB_NONE
      ret = Storage.CanEdit(curr_part, true) if ret
      ret
    end


    def check_device_delete(curr_part, installation, disk)
      curr_part = deep_copy(curr_part)
      disk = deep_copy(disk)
      part_name = Ops.get_string(curr_part, "device", "")

      used = check_devices_used([curr_part], false)

      if used != :UB_NONE
        # if( used == `UB_LVM)
        #     {
        #     // popup text %2 is a device name, %1 is the volume group name
        #     Popup::Error(sformat(_("The device (%2) belongs to a volume group (%1).
        # Remove it from the volume group before deleting it.
        # "),curr_part["used_by_device"]:"" , part_name) );
        #     }

        if used == :UB_MD
          # popup text %2 is a device name, %1 is the raid name
          Popup.Message(
            Builtins.sformat(
              _(
                "The device (%2) belongs to the RAID (%1).\nRemove it from the RAID before deleting it.\n"
              ),
              Ops.get_string(curr_part, "used_by_device", ""),
              part_name
            )
          )
        else
          # popup text, %1 and %2 are device names
          Popup.Message(
            Builtins.sformat(
              _(
                "The device (%2) is used by %1.\nRemove %1 before deleting it.\n"
              ),
              Ops.get_string(curr_part, "used_by_device", ""),
              part_name
            )
          )
        end
        return false
      end

      if !installation
        if !TryUmount(part_name, _("It cannot be deleted while mounted."), true)
          return false
        end
      end

      if !installation &&
          Ops.get_symbol(curr_part, "type", :unknown) == :logical
        ok = true
        ppl = Builtins.filter(Ops.get_list(disk, "partitions", [])) do |p|
          Ops.greater_than(
            Ops.get_integer(p, "nr", 0),
            Ops.get_integer(curr_part, "nr", 0)
          )
        end
        if Ops.greater_than(Builtins.size(ppl), 0) &&
            check_devices_used(ppl, true) != :UB_NONE
          ok = false
        end
        if ok && !installation && Ops.greater_than(Builtins.size(ppl), 0)
          i = 0
          while Ops.less_than(i, Builtins.size(ppl)) && ok
            if Ops.greater_than(
                Builtins.size(
                  Storage.DeviceMounted(Ops.get_string(ppl, [i, "device"], ""))
                ),
                0
              )
              ok = false
            end
            i = Ops.add(i, 1)
          end
        end
        if !ok
          # popup text, %1 is a device name
          Popup.Message(
            Builtins.sformat(
              _(
                "The device (%1) cannot be removed since it is a logical partition and \nanother logical partition with a higher number is in use.\n"
              ),
              part_name
            )
          )
          return false
        end
      end
      ret = used == :UB_NONE
      ret = Storage.CanDelete(curr_part, disk, true) if ret
      ret
    end


    def check_extended_delete(curr_disk, installation)
      curr_disk = deep_copy(curr_disk)
      #///////////////////////////////////////////////
      # filter delete partitions
      partitions = Ops.get_list(curr_disk, "partitions", [])
      del_dev = Ops.get_string(curr_disk, "device", "")

      #///////////////////////////////////////////////
      # get logical partitions
      logical_parts = Builtins.filter(partitions) do |part|
        Ops.get_symbol(part, "type", :primary) == :logical
      end
      Builtins.y2milestone(
        "check_extended_delete logical_parts %1",
        logical_parts
      )
      logical_parts_names = []
      logical_parts_names = Builtins.maplist(logical_parts) do |p|
        Ops.get_string(p, "device", "")
      end
      Builtins.y2milestone(
        "check_extended_delete logical_parts_names %1",
        logical_parts_names
      )

      return true if logical_parts_names == []

      #///////////////////////////////////////////////
      # check mounted partitions
      if !installation
        mounts = Storage.mountedPartitionsOnDisk(del_dev)
        Builtins.y2milestone("check_extended_delete mounts:%1", mounts)
        mounts = Builtins.filter(mounts) do |mount|
          Builtins.contains(
            logical_parts_names,
            Ops.get_string(mount, "device", "")
          )
        end
        Builtins.y2milestone("check_extended_delete mounts:%1", mounts)
        if Builtins.size(mounts) != 0
          #///////////////////////////////////////////////////////////////////////////////////////
          # mount points found

          mounted_parts = ""
          Builtins.foreach(mounts) do |mount|
            #  %1 is replaced by device name, %1 by directory e.g /dev/hdd1 on /opt
            mounted_parts = Ops.add(
              Ops.add(
                mounted_parts,
                Builtins.sformat(
                  "%1 --> %2",
                  Ops.get_string(mount, "device", ""),
                  Ops.get_string(mount, "mount", "")
                )
              ),
              "\n"
            )
          end

          # popup text
          message = Builtins.sformat(
            _(
              "The selected extended partition contains partitions which are currently mounted:\n" +
                "%1\n" +
                "We *strongly* recommend to unmount these partitions before you delete the extended partition.\n" +
                "Choose Cancel unless you know exactly what you are doing.\n"
            ),
            mounted_parts
          )

          return false if !Popup.ContinueCancel(message)
        end
      end

      used = check_devices_used(logical_parts, false)

      if used == :UB_LVM
        # popup text, Do not translate LVM.
        Popup.Message(
          _(
            "\n" +
              "The selected extended partition contains at least one LVM partition\n" +
              "assigned to a volume group. Remove all\n" +
              "partitions from their respective volume groups\n" +
              "before deleting the extended partition.\n"
          )
        )
      elsif used == :UB_MD
        # popup text, Do not translate RAID.
        Popup.Message(
          _(
            "\n" +
              "The selected extended partition contains at least one partition\n" +
              "that is part of a RAID system. Unassign the\n" +
              "partitions from their respective RAID systems before\n" +
              "deleting the extended partition.\n"
          )
        )
      elsif used != :UB_NONE
        # popup text
        Popup.Message(
          _(
            "\n" +
              "The selected extended partition contains at least one partition\n" +
              "that is in use. Remove the used volume before\n" +
              "deleting the extended partition.\n"
          )
        )
      end
      ret = used == :UB_NONE
      if ret
        extd = Builtins.find(partitions) do |p|
          Ops.get_symbol(p, "type", :primary) == :extended
        end
        if extd != nil && Ops.greater_than(Builtins.size(extd), 0)
          ret = Storage.CanDelete(extd, curr_disk, true)
        end
      end
      ret
    end

    # Check if a Btrfs root filesystem is large enough for snapshots (if it has
    # snapshots enabled).
    #
    # @param part [Hash] hash representing the partition
    # @return [Boolean] true if ok, false if a warning should be shown
    #
    def check_root_for_snapshot_size(part)
      return true unless Mode.installation
      return true unless part["mount"] == "/"
      return true unless part["used_fs"] == :btrfs
      return true unless part.has_key?("userdata")
      userdata = part["userdata"]
      return true unless userdata["/"] == "snapshots"
      root_size_k = part["size_k"].to_i || 0
      min_root_size_k = recommended_root_size_k_for_snapshots
      log.info("check_root_for_snapshot_size: root: #{format_size_k(root_size_k)}; " +
               "recommended min: #{format_size_k(min_root_size_k)}")
      root_size_k >= min_root_size_k
    end

    # Format a size_k (kiB) human readable
    #
    # @param size_k [Fixnum]
    # @return [String]
    #
    def format_size_k(size_k)
      Storage.KByteToHumanStringOmitZeroes(size_k.to_i)
    end

    # Calculate the recommended minimum root filesystem size in kiB if
    # snapshots are enabled.
    #
    # @return [Integer] size_k
    #
    def recommended_root_size_k_for_snapshots
      proposal_settings = StorageProposal.GetControlCfg()
      1024 * (proposal_settings["root_base"] || 0)
    end

    # Show a warning that the root partition is too small.
    #
    # @return [Boolean] true: user confirmed with "Yes", false: "No"
    #
    def show_snapshots_size_warning
      recommended_k = recommended_root_size_k_for_snapshots
      # popup text, %1 is a size
      message = Builtins.sformat(
        _(
          "Warning:\n" +
          "\n" +
          "Your root partition is very small for snapshots.\n" +
          "We recommend to increase the size of the root partition\n" +
          "to %1 or more or to disable snapshots.\n" +
          "\n" +
          "Really keep the current setup?\n"
        ),
        format_size_k(recommended_k)
      )
      Popup.YesNo(message)
    end
  end
end
