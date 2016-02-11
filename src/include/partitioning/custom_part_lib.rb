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
module Yast
  module PartitioningCustomPartLibInclude
    def initialize_partitioning_custom_part_lib(include_target)
      textdomain "storage"
      Yast.import "Mode"
      Yast.import "Arch"
      Yast.import "Partitions"
      Yast.import "Product"
      Yast.import "FileSystems"
      Yast.import "Greasemonkey"

      Yast.include include_target, "partitioning/partition_defines.rb"

    end

    # Check lvm mount points
    # @param [String] mount mount point
    # @return [Boolean]
    def check_lvm_mount_points(mount)
      not_allowed_lvm_mount_points = [Partitions.BootMount]
      Builtins.y2milestone("check lvm mount")
      if Builtins.contains(not_allowed_lvm_mount_points, mount)
        # error popup text
        Popup.Error(
          Builtins.sformat(
            _("You cannot use the mount point \"%1\" for LVM.\n"),
            Partitions.BootMount
          )
        )
        return false
      end
      true
    end


    # Check raid mount points
    # @param [String] mount mount point
    # @return [Boolean]
    #
    def check_raid_mount_points(mount, raid_level)
      not_allowed_raid_mount_points = []
      if (Arch.ppc && raid_level != "raid1") || Arch.s390
        not_allowed_raid_mount_points = Builtins.add(
          not_allowed_raid_mount_points,
          Partitions.BootMount
        )
      end
      Builtins.y2milestone("check raid mount")
      if Builtins.contains(not_allowed_raid_mount_points, mount)
        # error popup text
        Popup.Error(
          Builtins.sformat(
            _("You cannot use the mount point %1 for RAID."),
            Partitions.BootMount
          )
        )
        return false
      end
      true
    end


    # Check if the noauto option is permitted for this mount point.
    # @param [String] mount mount point
    # @return [Boolean]
    #
    def check_noauto_mount(mount)
      ret = true
      if FileSystems.IsSystemMp(mount, true)
        # error popup text
        ret = Popup.YesNo(
          _(
            "You have selected to not automatically mount at start-up a file system\n" +
              "that may contain files that the system needs to work properly.\n" +
              "\n" +
              "This may cause problems.\n" +
              "\n" +
              "Really do this?\n"
          )
        )
        Builtins.y2milestone("ret %1", ret)
      end
      ret
    end

    # Check crypted mount points and return true if the mount point is ok.
    # @param [String] mount mount point
    # @param [Boolean] crypt_fs boolean
    # @return [Boolean]
    #
    def check_crypt_fs_mount_points(mount, crypt_fs)
      if crypt_fs && FileSystems.IsCryptMp(mount, false)
        # error popup text
        Popup.Error(
          _(
            "You have assigned an encrypted file system to a partition\n" +
              "with one of the following mount points: \"/\", \"/usr\", \"/boot\",\n" +
              "/var\".  This is not possible. Change the mount point or use a\n" +
              "nonloopbacked file system.\n"
          )
        )
        return false
      end
      true
    end
    def check_unique_label(targetMap, part)
      targetMap = deep_copy(targetMap)
      part = deep_copy(part)
      unique = true

      # check if the label is already in use
      Builtins.foreach(targetMap) do |disk, diskinfo|
        Builtins.foreach(Ops.get_list(diskinfo, "partitions", [])) do |p|
          if Ops.get_string(p, "device", "") !=
              Ops.get_string(part, "device", "")
            # all valid partitions
            if Ops.get_string(p, "label", "") ==
                Ops.get_string(part, "label", "")
              unique = false
            end
          end
        end
      end
      unique
    end
    def CheckFstabOptions(part)
      part = deep_copy(part)
      ret = true
      if FileSystems.IsSystemMp(Ops.get_string(part, "mount", ""), true) &&
          FileSystems.HasFstabOption(part, "user", false)
        # error popup text
        ret = Popup.YesNo(
          _(
            "You have set a file system as mountable by users. The file system\n" +
              "may contain files that need to be executable.\n" +
              "\n" +
              "This usually causes problems.\n" +
              "\n" +
              "Really do this?\n"
          )
        )
        Builtins.y2milestone("system mp user ret %1", ret)
      end
      if ret && Ops.get_boolean(part, "noauto", false)
        ret = check_noauto_mount(Ops.get_string(part, "mount", "")) && ret
      end
      Builtins.y2milestone("CheckFstabOptions ret %1 part %2", ret, part)
      ret
    end

    # Check all mount points and return true if the mount point is ok.
    # @param [Hash{String => map}] targetMap the TargetMap
    # @param mount mount point
    # @return [Boolean]
    #
    def check_mount_point(targetMap, dev, part)
      targetMap = deep_copy(targetMap)
      part = deep_copy(part)
      mount = Ops.get_string(part, "mount", "")
      used_fs = Ops.get_symbol(part, "used_fs", :unknown)
      Builtins.y2milestone("check_mount_point part:%1", part)

      allowed = true

      not_allowed_system_mount_points = [
        "/proc",
        "/sys",
        "/dev",
        "/mnt",
        "/var/adm/mnt",
        "/lost+found",
        "/lib",
        "/lib64",
        "/bin",
        "/etc",
        "/sbin"
      ]

      if Builtins.isempty(mount)
        Popup.Error(_("Mount point must not be empty."))
        allowed = false
      elsif used_fs == :swap && mount != "swap"
        allowed = false
        # error popup
        Popup.Error(_("Swap devices must have swap as mount point."))
      elsif used_fs != :swap && mount == "swap"
        allowed = false
        # error popup
        Popup.Error(_("Only swap devices may have swap as mount point."))
      elsif mount != "swap" # || part["type"]:`unknown == `loop)
        # check if the mount point is already in use
        Builtins.foreach(targetMap) do |disk, diskinfo|
          Builtins.foreach(Ops.get_list(diskinfo, "partitions", [])) do |part2|
            if Ops.get_string(part2, "device", "") != dev
              # all valid partitions
              allowed = false if Ops.get_string(part2, "mount", "") == mount
            end
          end
        end

        if allowed == false # && mount!="swap" )
          # error popup text
          Popup.Error(
            _("This mount point is already in use. Select a different one.")
          )
        # check if a dos filesystem is used for system purposes
        elsif used_fs == :vfat &&
            (mount == "/" || mount == "/usr" || mount == "/opt" ||
              mount == "/var" ||
              mount == "/home")
          allowed = false
          # error popup text
          Popup.Error(
            _(
              "FAT filesystem used for system mount point (/, /usr, /opt, /var, /home).\nThis is not possible."
            )
          )
        # check if the mount countains chars making trouble
        elsif Builtins.findfirstof(mount, " `'!\"%#") != nil
          allowed = false
          # error popup text
          Popup.Error(
            _(
              "Invalid character in mount point. Do not use \"`'!\"%#\" in a mount point."
            )
          )
        # check if the mount point is a system mount point
        elsif Builtins.contains(not_allowed_system_mount_points, mount)
          allowed = false
          # error popup text
          Popup.Error(
            _(
              "You cannot use any of the following mount points:\n" +
                "/bin, /dev, /etc, /lib, /lib64, /lost+found, /mnt, /proc, /sbin, /sys,\n" +
                "/var/adm/mnt\n"
            )
          )
        elsif Builtins.substring(mount, 0, 1) != "/"
          allowed = false
          # error popup text
          Popup.Error(_("Your mount point must start with a \"/\" "))
        end
      elsif !Ops.get_boolean(part, "format", false) &&
          Ops.get_symbol(part, "detected_fs", :none) != :swap
        allowed = false
        # error popup text
        Popup.Error(_("It is not allowed to assign the mount point swap\nto a device without a swap file system."));
      end

      allowed = CheckFstabOptions(part) if allowed
      allowed
    end



    def check_ok_fssize(size_k, volume)
      volume = deep_copy(volume)
      ret = true

      fs = Ops.get_symbol(volume, "used_fs", :unknown)
      min_size_k = FileSystems.MinFsSizeK(fs)
      Builtins.y2milestone(
        "check_ok_fssize fs:%1 size_k:%2 min_size_k:%3",
        fs,
        size_k,
        min_size_k
      )

      if Ops.less_than(size_k, min_size_k)
        # warning message, %1 is replaced by fs name (e.g. Ext3)
        # %2 is prelaced by a size (e.g. 10 MB)
        Popup.Warning(
          Builtins.sformat(
            _(
              "Your partition is too small to use %1.\nThe minimum size for this file system is %2.\n"
            ),
            FileSystems.GetName(fs, ""),
            Storage.KByteToHumanString(min_size_k)
          )
        )

        ret = false
      end

      ret
    end


    # Do all checks concerning mount points, uuid, volume labels and
    # fstab options
    # @param targetMap the TargetMap
    # @param mount mount point
    # @return [Hash]
    #
    def CheckOkMount(dev, old, new)
      old = deep_copy(old)
      new = deep_copy(new)
      Builtins.y2milestone("CheckOkMount old:%1 new:%2", old, new)
      ret = {}
      Ops.set(ret, "ok", true)
      Ops.set(new, "mount", UI.QueryWidget(Id(:mount_point), :Value))
      if Ops.get_string(old, "mount", "") != Ops.get_string(new, "mount", "")
        Ops.set(new, "inactive", true)
      end
      if Ops.get_boolean(ret, "ok", false)
        crypt_fs = false
        if !check_mount_point(Storage.GetTargetMap, dev, new)
          Ops.set(ret, "ok", false)
          Ops.set(ret, "field", :mount_point)
        end
        if UI.WidgetExists(Id(:crypt_fs))
          crypt_fs = Convert.to_boolean(UI.QueryWidget(Id(:crypt_fs), :Value))
        end
        if !check_crypt_fs_mount_points(
            Ops.get_string(new, "mount", ""),
            crypt_fs
          )
          Ops.set(ret, "ok", false)
          Ops.set(ret, "field", :mount_point)
        end
        if Ops.get_boolean(new, "noauto", false) &&
            !check_noauto_mount(Ops.get_string(new, "mount", ""))
          Ops.set(ret, "ok", false)
          Ops.set(ret, "field", :mount_point)
        end
        if Ops.get_symbol(new, "type", :primary) == :sw_raid
          if !check_raid_mount_points(Ops.get_string(new, "mount", ""), Ops.get_string(new, "raid_type", ""))
            Ops.set(ret, "ok", false)
            Ops.set(ret, "field", :mount_point)
          end
        elsif Ops.get_symbol(new, "type", :primary) == :lvm
          if !check_lvm_mount_points(Ops.get_string(new, "mount", ""))
            Ops.set(ret, "ok", false)
            Ops.set(ret, "field", :mount_point)
          end
        end
        if !Ops.get_boolean(new, "format", false) && !crypt_fs &&
            Builtins.contains(
              [:unknown, :none],
              Ops.get_symbol(new, "detected_fs", :unknown)
            )
          # error popup text
          Popup.Error(
            _(
              "It is not allowed to assign a mount point\nto a device with nonexistent or unknown file system."
            )
          )
          Ops.set(ret, "ok", false)
          Ops.set(ret, "field", :mount_point)
        end
      end
      new = Builtins.filter(new) { |key, value| key != "fs_options" } if !Ops.get_boolean(
        new,
        "format",
        false
      )
      Builtins.y2milestone("ret:%1 new:%2", ret, new)
      Ops.set(ret, "map", new)
      deep_copy(ret)
    end

    def EmptyCryptPwdAllowed(p)
      p = deep_copy(p)
      ret = Ops.get_boolean(p, "format", false) &&
        Builtins.contains(
          Builtins.union(FileSystems.tmp_m_points, FileSystems.swap_m_points),
          Ops.get_string(p, "mount", "")
        )
      ret = ret && Storage.IsPersistent(p)
      Builtins.y2milestone("EmptyCryptPwdAllowed ret:%1", ret)
      ret
    end

    def SubvolPart(can_do_subvol)
      subvol = Empty()
      if can_do_subvol
        subvol = term(
          :FrameWithMarginBox,
          "",
          PushButton(
            Id(:subvol),
            Opt(:hstretch),
            # button text
            _("Subvolume Handling")
          )
        )
      end
      Greasemonkey.Transform(subvol)
    end


    # Handles btrfs subvolumes for root (/)
    #
    # If the partition is going to be formatted, it enforces the default list of
    # subvolumes. Otherwise, it withdraws any previous change in the list of
    # subvolumes.
    def HandleSubvol(data)
      ret = data.dup
      if ret["mount"] == "/"
        Builtins.y2milestone("before HandleSubvol fs:%1", ret['used_fs'])
        Builtins.y2milestone(
          "before HandleSubvol subvol:%1 userdata:%2",
          ret['subvol'],
          ret['userdata']
        )
        if ret["used_fs"] == :btrfs
          ret["subvol"] ||= []
          if ret["format"]
            ret = Storage.AddSubvolRoot(ret)
            ret["userdata"] = { "/" => "snapshots" }
            Builtins.y2milestone(
              "HandleSubvol AddSubvolRoot subvol:%1 userdata:%2",
              ret["subvol"],
              ret["userdata"]
            )
          else
            ret["subvol"].reject! {|s| s["create"] || s["delete"] }
          end
        else
          ret["subvol"] = []
        end
        Builtins.y2milestone(
          "after HandleSubvol subvol:%1 userdata:%2",
          ret['subvol'],
          ret['userdata']
        )
      else
        ret["subvol"] = []
      end
      ret
    end


    def HandleFsChanged(init, new, old_fs, file_systems)
      new = deep_copy(new)
      file_systems = deep_copy(file_systems)
      apply_change = true
      not_used_mp = []
      used_fs = Ops.get_symbol(new, "used_fs", :unknown)
      selected_fs = Ops.get_map(file_systems, used_fs, {})
      Builtins.y2milestone(
        "HandleFsChanged init:%1 used_fs:%2 old_fs:%3 new:%4",
        init,
        used_fs,
        old_fs,
        new
      )

      if !init && used_fs != old_fs
        Builtins.y2milestone(
          "HandleFsChanged IsUnsupported:%1",
          FileSystems.IsUnsupported(used_fs)
        )
        if FileSystems.IsUnsupported(Ops.get_symbol(new, "used_fs", :unknown))
          # warning message, %1 is replaced by fs name (e.g. Ext3)
          message = Builtins.sformat(
            _(
              "\n" +
                "WARNING:\n" +
                "\n" +
                "This file system is not supported in %1;.\n" +
                "It is completely untested and might not be well-integrated \n" +
                "in the system.  Do not report bugs against this file system \n" +
                "if it does not work properly or at all.\n" +
                "\n" +
                "Really use this file system?\n"
            ),
            Product.name
          )

          apply_change = Popup.YesNo(message)
        end

        if !apply_change
          Ops.set(new, "used_fs", old_fs)
          UI.ChangeWidget(Id(:fs), :Value, old_fs)
        end
      end

      if apply_change && UI.WidgetExists(Id(:crypt_fs))
        cr = Ops.get_boolean(selected_fs, :crypt, true) &&
          Ops.get_symbol(new, "used_fs", :unknown) != :btrfs &&
          !Ops.get_boolean(new, "pool", false)
        Builtins.y2milestone("HandleFsChanged cr:%1", cr)

        UI.ChangeWidget(Id(:crypt_fs), :Enabled, cr)
        if !cr
          Builtins.y2milestone("HandleFsChanged crypt set to false")
          UI.ChangeWidget(Id(:crypt_fs), :Value, false)
        end
      end

      if !init && apply_change && UI.WidgetExists(Id(:subvol_rp))
        sv = Ops.get_symbol(new, "used_fs", :unknown) == :btrfs
        Builtins.y2milestone("HandleFsChanged sv:%1", sv)
        UI.ReplaceWidget(Id(:subvol_rp), SubvolPart(sv))
        if UI.WidgetExists(Id(:subvol))
          UI.ChangeWidget(Id(:subvol), :Enabled, sv)
        end
      end

      if apply_change
        #//////////////////////////////////////////////
        # switch between swap and other mountpoints
        mount = Convert.to_string(UI.QueryWidget(Id(:mount_point), :Value))
        Ops.set(new, "mount", mount)
        if used_fs == :swap
          not_used_mp = Ops.get_list(selected_fs, :mountpoints, [])
          if mount != "swap" &&
              (Ops.get_symbol(new, "type", :primary) != :lvm || mount != "")
            Ops.set(new, "mount", "swap")
            Ops.set(new, "inactive", true)
          end
        else
          not_used_mp = notUsedMountpoints(
            Storage.GetTargetMap,
            Ops.get_list(selected_fs, :mountpoints, [])
          )
          if Ops.get_symbol(new, "type", :primary) == :lvm ||
              Ops.get_symbol(new, "type", :primary) == :sw_raid &&
                Ops.get_string(new, "raid_type", "raid0") != "raid1"
            not_used_mp = Builtins.filter(not_used_mp) do |mp|
              mp != Partitions.BootMount
            end
          elsif Ops.get_symbol(new, "type", :primary) == :loop
            not_used_mp = Builtins.filter(not_used_mp) do |mp|
              !Builtins.contains(FileSystems.system_m_points, mp)
            end
          end
          Ops.set(new, "mount", "") if mount == "swap"
        end
        # UI::ReplaceWidget(`id(`mount_dlg_rp), MountDlg( new, not_used_mp));
        UI.ChangeWidget(
          Id(:mount_point),
          :Value,
          Ops.get_string(new, "mount", "")
        )
        if !init
          UI.ChangeWidget(
            Id(:fstab_options),
            :Enabled,
            Ops.greater_than(Builtins.size(Ops.get_string(new, "mount", "")), 0)
          )
        end
        if UI.WidgetExists(Id(:fs_options))
          UI.ChangeWidget(
            Id(:fs_options),
            :Enabled,
            Ops.get_boolean(new, "format", false) &&
              Ops.get_list(selected_fs, :options, []) != []
          )
        end
        fstopt = FileSystems.DefaultFstabOptions(new)
        if Ops.greater_than(Builtins.size(fstopt), 0) &&
            Builtins.size(Ops.get_string(new, "fstopt", "")) == 0
          Ops.set(new, "fstopt", fstopt)
        end
        if !init
          Ops.set(new, "fs_options", FileSystems.DefaultFormatOptions(new))
          Ops.set(new, "fstopt", fstopt)
          Builtins.y2milestone(
            "HandleFsChanged fstopt:%1 new[\"fstopt\"]:%2",
            fstopt,
            Ops.get_string(new, "fstopt", "")
          )

          max_len = FileSystems.LabelLength(used_fs)
          if Ops.greater_than(
              Builtins.size(Ops.get_string(new, "label", "")),
              max_len
            )
            Ops.set(
              new,
              "label",
              Builtins.substring(Ops.get_string(new, "label", ""), 0, max_len)
            )
          end
          mountby = Ops.get_symbol(new, "mountby", :device)
          if mountby == :uuid && !FileSystems.MountUuid(used_fs) ||
              mountby == :label && !FileSystems.MountLabel(used_fs)
            Ops.set(new, "mountby", :device)
          end
          if !FileSystems.MountLabel(used_fs) &&
              Ops.greater_than(
                Builtins.size(Ops.get_string(new, "label", "")),
                0
              )
            Ops.set(new, "label", "")
          end
          Ops.set(new, "subvol", []) if used_fs != :btrfs
        end
      end
      Builtins.y2milestone("HandleFsChanged new %1", new)
      deep_copy(new)
    end


    # Handles the widgets with information about a partition and updates the
    # partition information according
    #
    # @param init [Boolean] whether this is the initialization call (i.e.
    #   setting the initial values in the dialog and the partition information)
    #   or a refresh (i.e. a call resulting from an change in some widget)
    # @param ret [Symbol] id of the widget that triggered the action (expected
    #   to be nil if init == true)
    # @param file_systems [Hash] definitions of the supported filesystems
    # @param old [Hash] map with original partition
    # @param new [Hash] map with changes filled in
    def HandlePartWidgetChanges(init, ret, file_systems, old, new)
      ret = deep_copy(ret)
      file_systems = deep_copy(file_systems)
      old = deep_copy(old)
      new = deep_copy(new)
      Builtins.y2milestone(
        "HandlePartWidgetChanges init:%1 ret:%2 new:%3",
        init,
        ret,
        new
      )
      used_fs = Ops.get_symbol(new, "used_fs", :unknown)
      selected_fs = Ops.get_map(file_systems, used_fs, {})
      if init && old["mount"] && !old["mount"].empty? && old["ignore_fstab"]
        UI.ChangeWidget(Id(:fstab_options), :Enabled, false)
      end
      #///////////////////////////////////////////////////////
      # configure main dialog and modify map new
      if !init &&
          Ops.get_string(new, "mount", "") != Ops.get_string(old, "mount", "")
        if Arch.ia64 && Ops.get_string(new, "mount", "") == Partitions.BootMount
          new = Builtins.filter(new) { |key, value| key != "fstopt" }
        end
      end
      if !init && ret == :mount_point
        mp = Convert.to_string(UI.QueryWidget(Id(:mount_point), :Value))
        if Ops.get_string(new, "mount", "") != mp
          oldfst = FileSystems.DefaultFstabOptions(new)
          Ops.set(new, "mount", mp)
          newfst = FileSystems.DefaultFstabOptions(new)
          if oldfst != newfst
            # Default fstab options have changed, set new default, bnc#774499
            Ops.set(new, "fstopt", newfst)
          end
          new = HandleSubvol(new)
        end
        if UI.WidgetExists(Id(:fstab_options))
          UI.ChangeWidget(Id(:fstab_options), :Enabled, !Builtins.isempty(mp))
        end
      end

      # set btrfs subvolumes (bnc#872210)
      if init && new.fetch("mount", "") == "/"
        new = HandleSubvol(new)
      end

      if init && UI.WidgetExists(Id(:format)) || ret == :do_format ||
          ret == :do_not_format
        format = UI.QueryWidget(Id(:format), :Value) == :do_format

        old_format = Ops.get_boolean(new, "format", false)

        #//////////////////////////////////////////////
        # format partition
        Ops.set(new, "format", format)

        if old_format != format
          dfs = :unknown
          if format
            dfs = Convert.to_symbol(UI.QueryWidget(Id(:fs), :Value))
          else
            if Ops.get_symbol(new, "detected_fs", :unknown) != :unknown
              dfs = Ops.get_symbol(new, "detected_fs") { Partitions.DefaultFs }
            else
              dfs = Ops.get_symbol(new, "used_fs") { Partitions.DefaultFs }
            end
            UI.ChangeWidget(Id(:fs), :Value, dfs)
          end
          selected_fs2 = Ops.get_map(file_systems, dfs, {})
          Ops.set(new, "used_fs", dfs)
          Builtins.y2milestone("HandlePartWidgetChanges used_fs %1", dfs)
          if Ops.get_symbol(new, "used_fs", :unknown) !=
              Ops.get_symbol(old, "used_fs", :unknown)
            new = HandleFsChanged(
              init,
              new,
              Ops.get_symbol(old, "used_fs", :unknown),
              file_systems
            )
          end
          new = HandleSubvol(new)
          if format
            Ops.set(new, "fs_options", FileSystems.DefaultFormatOptions(new))
            if !Builtins.contains(
                Ops.get_list(selected_fs2, :alt_fsid, []),
                Ops.get_integer(new, "fsid", 0)
              )
              Ops.set(
                new,
                "fsid",
                Ops.get_integer(selected_fs2, :fsid, Partitions.fsid_native)
              )
            end
          else
            if Builtins.haskey(new, "ori_fsid")
              Ops.set(new, "fsid", Ops.get_integer(new, "ori_fsid", 0))
            else
              Ops.set(new, "fsid", Ops.get_integer(old, "fsid", 0))
            end
          end
          if UI.WidgetExists(Id(:fsid_point))
            if Ops.greater_than(Builtins.size(selected_fs2), 0) &&
                Ops.get_integer(new, "fsid", 0) !=
                  Ops.get_integer(selected_fs2, :fsid, 0) &&
                !Builtins.contains(
                  Ops.get_list(selected_fs2, :alt_fsid, []),
                  Ops.get_integer(new, "fsid", 0)
                )
              UI.ChangeWidget(
                Id(:fsid_point),
                :Value,
                Ops.get_string(selected_fs2, :fsid_item, "")
              )
            end
          end
          Ops.set(new, "fs_options", {}) if !format
          Ops.set(new, "fstopt", FileSystems.DefaultFstabOptions(new))
        end
      end
      if init || ret == :fs
        new_fs = used_fs
        if UI.WidgetExists(Id(:fs))
          new_fs = Convert.to_symbol(UI.QueryWidget(Id(:fs), :Value))
        end
        if init
          if !Ops.get_boolean(new, "format", false) &&
              Ops.get_symbol(new, "detected_fs", :unknown) != :unknown
            new_fs = Ops.get_symbol(new, "detected_fs", :unknown)
          elsif Ops.get_integer(new, "fsid", 0) == Partitions.fsid_gpt_boot
            new_fs = :vfat
          end
          UI.ChangeWidget(Id(:fs), :Value, new_fs) if used_fs != new_fs
        end
        Builtins.y2milestone(
          "HandlePartWidgetChanges init=%1 used_fs:%2 new_fs:%3",
          init,
          used_fs,
          new_fs
        )
        if init || used_fs != new_fs
          selected_fs2 = Ops.get_map(file_systems, new_fs, {})
          Ops.set(new, "used_fs", new_fs)

          new = HandleFsChanged(init, new, used_fs, file_systems)

          if !init
            if !Builtins.contains(
                Ops.get_list(selected_fs2, :alt_fsid, []),
                Ops.get_integer(new, "fsid", 0)
              )
              Ops.set(
                new,
                "fsid",
                Ops.get_integer(selected_fs2, :fsid, Partitions.fsid_native)
              )
            end
            Builtins.y2milestone(
              "HandlePartWidgetChanges fsid %1",
              Ops.get_integer(new, "fsid", 0)
            )
            if UI.WidgetExists(Id(:fsid_point))
              UI.ChangeWidget(
                Id(:fsid_point),
                :Value,
                Ops.get_string(selected_fs2, :fsid_item, "")
              )
            end
            new = HandleSubvol(new)
          end
        end
      end
      if init && UI.WidgetExists(Id(:fsid_point)) || ret == :fsid_point
        #//////////////////////////////////////////////
        # modify map new
        fs_string = Convert.to_string(UI.QueryWidget(Id(:fsid_point), :Value))
        Builtins.y2milestone("HandlePartWidgetChanges fs_string:%1", fs_string)
        fs_int = FileSystems.FindFsid(fs_string)
        old_id = Ops.get_integer(new, "fsid", 0)
        Builtins.y2milestone(
          "HandlePartWidgetChanges fs_int:%1 old_id:%2",
          fs_int,
          old_id
        )
        if fs_int != nil && fs_int != old_id
          Ops.set(new, "fsid", fs_int)
          no_fs = Builtins.contains(
            [
              Partitions.fsid_lvm,
              Partitions.fsid_raid,
              Partitions.fsid_hibernation,
              Partitions.fsid_bios_grub,
              Partitions.fsid_prep_chrp_boot,
              Partitions.fsid_gpt_prep
            ],
            fs_int
          )

          UI.ChangeWidget(Id(:fstab_options), :Enabled, !no_fs)
          UI.ChangeWidget(Id(:do_format), :Enabled, !no_fs)
          UI.ChangeWidget(Id(:do_mount_attachment), :Enabled, !no_fs)
          UI.ChangeWidget(Id(:mount), :Enabled, !no_fs)
          if no_fs
            UI.ChangeWidget(Id(:do_not_mount), :Value, true)
            ChangeExistingSymbolsState([:fs_options, :fs], false)
            ChangeExistingSymbolsState(
              [:crypt_fs],
              fs_int == Partitions.fsid_lvm
            )
          elsif fs_int == Partitions.fsid_native
            Ops.set(new, "used_fs", Partitions.DefaultFs)
            UI.ChangeWidget(
              Id(:fs),
              :Value,
              Ops.get_symbol(new, "used_fs", :unknown)
            )
            new = HandleFsChanged(init, new, Partitions.DefaultFs, file_systems)
          elsif fs_int == Partitions.fsid_swap
            Ops.set(new, "used_fs", :swap)
            UI.ChangeWidget(
              Id(:fs),
              :Value,
              Ops.get_symbol(new, "used_fs", :unknown)
            )
            new = HandleFsChanged(init, new, :swap, file_systems)
          elsif Builtins.contains(Partitions.fsid_wintypes, fs_int) ||
              fs_int == Partitions.fsid_gpt_boot
            Ops.set(new, "mount", "")
            Ops.set(new, "used_fs", :vfat)
            UI.ChangeWidget(
              Id(:fs),
              :Value,
              Ops.get_symbol(new, "used_fs", :unknown)
            )
            new = HandleFsChanged(init, new, :vfat, file_systems)
          elsif fs_int == Partitions.fsid_mac_hfs
            Ops.set(new, "mount", "")
            Ops.set(new, "used_fs", :hfs)
            UI.ChangeWidget(
              Id(:fs),
              :Value,
              Ops.get_symbol(new, "used_fs", :unknown)
            )
            new = HandleFsChanged(init, new, :hfs, file_systems)
          end
        end
      end
      new = FstabOptions(old, new) if ret == :fstab_options
      new = SubvolHandling(old, new) if ret == :subvol
      if ret == :crypt_fs
        val = Convert.to_boolean(UI.QueryWidget(Id(:crypt_fs), :Value))
        Ops.set(
          new,
          "enc_type",
          val ? Ops.get_boolean(new, "format", false) ? :luks : :twofish : :none
        )
        if val
          Ops.set(new, "mountby", :device)
          Ops.set(new, "label", "")
          Ops.set(new, "ori_label", "")
        else
          new = Builtins.remove(new, "mountby")
        end
      end
      if ret == :fs_options
        Ops.set(
          new,
          "fs_options",
          FileSystemOptions(Ops.get_map(new, "fs_options", {}), selected_fs)
        )
      end

      Builtins.y2milestone("HandlePartWidgetChanges old:%1", old)
      Builtins.y2milestone("HandlePartWidgetChanges new:%1", new)
      deep_copy(new)
    end


    def TryUmount(device, text, allow_ignore)
      while true
        mountpoint = Storage.DeviceMounted(device)
        return true if Builtins.isempty(mountpoint)

        if allow_ignore
          full_text = Ops.add(
            Ops.add(
              Builtins.sformat(
                _("The file system is currently mounted on %1."),
                mountpoint
              ),
              "\n\n"
            ),
            _(
              "You can try to unmount it now, continue without unmounting or cancel.\nClick Cancel unless you know exactly what you are doing."
            )
          )

          ret = Popup.AnyQuestion3(
            Label.WarningMsg,
            full_text,
            Label.ContinueButton,
            Label.CancelButton,
            # button text
            _("Unmount"),
            :focus_no
          )

          return false if ret == :no

          return true if ret == :yes
        else
          full_text = Ops.add(
            Ops.add(
              Builtins.sformat(
                _("The file system is currently mounted on %1."),
                mountpoint
              ),
              "\n\n"
            ),
            _(
              "You can try to unmount it now or cancel.\nClick Cancel unless you know exactly what you are doing."
            )
          )

          ret = Popup.AnyQuestion(
            Label.WarningMsg,
            full_text,
            # button text
            _("Unmount"),
            Label.CancelButton,
            :focus_no
          )

          return false if ret == false
        end

        return true if Storage.Umount(device, true)
      end

      nil
    end



    def CheckResizePossible(device, ask, lvm, resize, fsys)
      poss = FileSystems.IsResizable(fsys)
      mountpoint = Storage.DeviceMounted(device)

      ret = true

      Builtins.y2milestone(
        "CheckResizePossible device:%1 ask:%2 lvm:%3 resize:%4 fsys:%5",
        device,
        ask,
        lvm,
        resize,
        fsys
      )

      if !Builtins.isempty(mountpoint) && !Stage.initial &&
          Ops.less_than(resize, 0) &&
          !Ops.get(poss, "mount_shrink", false) &&
          Ops.get(poss, "shrink", false)
        if !TryUmount(
            device,
            _(
              "It is not possible to shrink the file system while it is mounted."
            ),
            true
          )
          ret = false
        end
      elsif !Builtins.isempty(mountpoint) && !Stage.initial &&
          Ops.greater_than(resize, 0) &&
          !Ops.get(poss, "mount_extend", false) &&
          Ops.get(poss, "extend", false)
        if !TryUmount(
            device,
            _(
              "It is not possible to extend the file system while it is mounted."
            ),
            true
          )
          ret = false
        end
      elsif !Builtins.isempty(mountpoint) && !Stage.initial && resize != 0 &&
          !lvm
        if !TryUmount(
            device,
            _(
              "It is not possible to resize the file system while it is mounted."
            ),
            true
          )
          ret = false
        end
      elsif Ops.less_than(resize, 0) && !Ops.get(poss, "shrink", false)
        ret = FsysCannotShrinkPopup(ask, lvm)
      elsif Ops.less_than(resize, 0) && fsys == :reiser
        ret = FsysShrinkReiserWarning(lvm)
      elsif Ops.greater_than(resize, 0) && !Ops.get(poss, "extend", false)
        ret = FsysCannotGrowPopup(ask, lvm)
      end
      Builtins.y2milestone("ret %1", ret)
      ret
    end
  end
end
