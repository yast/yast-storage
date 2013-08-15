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

# File:	StorageFields.ycp
# Package:	yast2-storage
# Summary:	Expert Partitioner
# Authors:	Arvin Schnell <aschnell@suse.de>
require "yast"

module Yast
  class StorageFieldsClass < Module
    def main
      Yast.import "UI"


      textdomain "storage"


      Yast.import "Storage"
      Yast.import "StorageIcons"
      Yast.import "FileSystems"
      Yast.import "Partitions"
      Yast.import "Directory"
      Yast.import "Mode"
      Yast.import "HTML"
      Yast.import "Integer"
      Yast.import "String"
      Yast.import "Region"
    end


    # Call callback for every disk of target_map in a well defined sorted order.
    def IterateTargetMap(target_map, callback)

      disk_order = {
        :CT_DMRAID      => 0,
        :CT_DMMULTIPATH => 1,
        :CT_MDPART      => 2,
        :CT_DISK        => 3,
        :CT_MD          => 4,
        :CT_LOOP        => 5,
        :CT_LVM         => 6,
        :CT_DM          => 7,
        :CT_NFS         => 8,
        :CT_BTRFS       => 9,
        :CT_TMPFS       => 10
      }

      keys = target_map.keys()

      keys.sort! do |a, b|
        oa = disk_order.fetch(target_map.fetch(a).fetch("type", :CT_UNKNOWN))
        ob = disk_order.fetch(target_map.fetch(b).fetch("type", :CT_UNKNOWN))
        oa == ob ? a <=> b : oa <=> ob
      end

      keys.each do |dev|
        disk = target_map.fetch(dev)
        callback.call(target_map, disk)
      end

    end


    def BooleanToHumanString(value)
      if value
        # human text for Boolean value
        return _("Yes")
      else
        # human text for Boolean value
        return _("No")
      end
    end


    def UsedByString(used_by)
      used_by = deep_copy(used_by)
      type = Ops.get_symbol(used_by, "type", :UB_NONE)
      device = Ops.get_string(used_by, "device", "")

      case type
        when :UB_LVM
          return Ops.add("LVM ", device)
        when :UB_DM
          return Ops.add("DM ", device)
        when :UB_DMRAID
          return Ops.add("DM RAID ", device)
        when :UB_DMMULTIPATH
          return Ops.add("DM Multipath ", device)
        when :UB_MD, :UB_MDPART
          return Ops.add("MD RAID ", device)
        when :UB_BTRFS
          return Ops.add("BTRFS ", device)
        else
          return device
      end
    end


    def TableHeader(fields)
      fields = deep_copy(fields)
      header = Header()

      Builtins.foreach(fields) do |field|
        case field
          when :device
            # Column header
            header = Builtins.add(header, _("Device"))
          when :size
            # Column header
            header = Builtins.add(header, Right(_("Size")))
          when :type
            # Column header
            header = Builtins.add(header, _("Type"))
          when :format
            # Column header, abbreviation for "format" (to format a partition)
            header = Builtins.add(header, Center(_("F")))
          when :encrypted
            # Column header, , abbreviation for "encrypted" (an encrypted device)
            header = Builtins.add(header, Center(_("Enc")))
          when :fs_type
            # Column header, abbreviation for "Filesystem Type"
            header = Builtins.add(header, _("FS Type"))
          when :mount_point
            # Column header
            header = Builtins.add(header, _("Mount Point"))
          when :mount_by
            # Column header
            header = Builtins.add(header, _("Mount by"))
          when :used_by
            # Column header
            header = Builtins.add(header, _("Used by"))
          when :start_cyl
            # Column header
            header = Builtins.add(header, Right(_("Start")))
          when :end_cyl
            # Column header
            header = Builtins.add(header, Right(_("End")))
          when :fs_id
            # Column header
            header = Builtins.add(header, Right(_("FS ID")))
          when :uuid
            # Column header
            header = Builtins.add(header, _("UUID"))
          when :label
            # Column header
            header = Builtins.add(header, _("Label"))
          when :udev_path
            # Column header
            header = Builtins.add(header, _("Device Path"))
          when :udev_id
            # Column header
            header = Builtins.add(header, _("Device ID"))
          when :bios_id
            # Column header
            header = Builtins.add(header, _("BIOS ID"))
          when :disk_label
            # Column header
            header = Builtins.add(header, _("Disk Label"))
          when :lvm_metadata
            # Column header
            header = Builtins.add(header, _("Metadata"))
          when :pe_size
            # Column header, abbreviation for "Physical Extent"
            header = Builtins.add(header, _("PE Size"))
          when :stripes
            # Column header
            header = Builtins.add(header, _("Stripes"))
          when :raid_version
            # Column header
            header = Builtins.add(header, _("RAID Version"))
          when :raid_type
            # Column header
            header = Builtins.add(header, _("RAID Type"))
          when :chunk_size
            # Column header
            header = Builtins.add(header, _("Chunk Size"))
          when :parity_algorithm
            # Column header
            header = Builtins.add(header, _("Parity Algorithm"))
          when :vendor
            # Column header
            header = Builtins.add(header, _("Vendor"))
          when :model
            # Column header
            header = Builtins.add(header, _("Model"))
          else
            Builtins.y2error("unknown field %1", field)
            header = Builtins.add(header, "error")
        end
      end

      deep_copy(header)
    end


    def Helptext(field, style)
      ret = "<p>"

      case field
        when :bios_id
          # helptext for table column and overview entry
          ret = Ops.add(
            ret,
            _(
              "<b>BIOS ID</b> shows the BIOS ID of the hard\ndisk. This field can be empty."
            )
          )
        when :bus
          # helptext for table column and overview entry
          ret = Ops.add(
            ret,
            _(
              "<b>Bus</b> shows how the device is connected to\nthe system. This field can be empty, e.g. for multipath disks."
            )
          )
        when :chunk_size
          # helptext for table column and overview entry
          ret = Ops.add(
            ret,
            _("<b>Chunk Size</b> shows the chunk size for RAID\ndevices.")
          )
        when :cyl_size
          # helptext for table column and overview entry
          ret = Ops.add(
            ret,
            _(
              "<b>Cylinder Size</b> shows the size of the\ncylinders of the hard disk."
            )
          )
        when :sector_size
          # helptext for table column and overview entry
          ret = Ops.add(
            ret,
            _(
              "<b>Sector Size</b> shows the size of the\nsectors of the hard disk."
            )
          )
        when :device
          # helptext for table column and overview entry
          ret = Ops.add(
            ret,
            _("<b>Device</b> shows the kernel name of the\ndevice.")
          )
        when :disk_label
          # helptext for table column and overview entry
          ret = Ops.add(
            ret,
            _(
              "<b>Disk Label</b> shows the partition table\ntype of the disk, e.g <tt>MSDOS</tt> or <tt>GPT</tt>."
            )
          )
        when :encrypted
          # helptext for table column and overview entry
          ret = Ops.add(
            ret,
            _("<b>Encrypted</b> shows whether the device is\nencrypted.")
          )
        when :end_cyl
          # helptext for table column and overview entry
          ret = Ops.add(
            ret,
            _("<b>End Cylinder</b> shows the end cylinder of\nthe partition.")
          )
        when :fc_fcp_lun
          # helptext for table column and overview entry
          ret = Ops.add(
            ret,
            _(
              "<b>LUN</b> shows the Logical Unit Number for\nFibre Channel disks."
            )
          )
        when :fc_port_id
          # helptext for table column and overview entry
          ret = Ops.add(
            ret,
            _("<b>Port ID</b> shows the port id for Fibre\nChannel disks.")
          )
        when :fc_wwpn
          # helptext for table column and overview entry
          ret = Ops.add(
            ret,
            _(
              "<b>WWPN</b> shows the World Wide Port Name for\nFibre Channel disks."
            )
          )
        when :file_path
          # helptext for table column and overview entry
          ret = Ops.add(
            ret,
            _(
              "<b>File Path</b> shows the path of the file for\nan encrypted loop device."
            )
          )
        when :format
          # helptext for table column and overview entry
          ret = Ops.add(
            ret,
            _(
              "<b>Format</b> shows some flags: <tt>F</tt>\nmeans the device is selected to be formatted."
            )
          )
        when :fs_id
          # helptext for table column and overview entry
          ret = Ops.add(ret, _("<b>FS ID</b> shows the file system id."))
        when :fs_type
          # helptext for table column and overview entry
          ret = Ops.add(ret, _("<b>FS Type</b> shows the file system type."))
        when :label
          # helptext for table column and overview entry
          ret = Ops.add(
            ret,
            _("<b>Label</b> shows the label of the file\nsystem.")
          )
        when :lvm_metadata
          # helptext for table column and overview entry
          ret = Ops.add(
            ret,
            _("<b>Metadata</b> shows the LVM metadata type for\nvolume groups.")
          )
        when :model
          # helptext for table column and overview entry
          ret = Ops.add(ret, _("<b>Model</b> shows the device model."))
        when :mount_by
          # helptext for table column and overview entry
          ret = Ops.add(
            ret,
            _(
              "<b>Mount by</b> indicates how the file system\n" +
                "is mounted: (Kernel) by kernel name, (Label) by file system label, (UUID) by\n" +
                "file system UUID, (ID) by device ID, and (Path) by device path.\n"
            )
          )
          if Mode.normal
            # helptext for table column and overview entry
            ret = Ops.add(
              Ops.add(ret, " "),
              _(
                "A question mark (?) indicates that\n" +
                  "the file system is not listed in <tt>/etc/fstab</tt>. It is either mounted\n" +
                  "manually or by some automount system. When changing settings for this volume\n" +
                  "YaST will not update <tt>/etc/fstab</tt>.\n"
              )
            )
          end
        when :mount_point
          # helptext for table column and overview entry
          ret = Ops.add(
            ret,
            _("<b>Mount Point</b> shows where the file system\nis mounted.")
          )
          if Mode.normal
            # helptext for table column and overview entry
            ret = Ops.add(
              Ops.add(ret, " "),
              _(
                "An asterisk (*) after the mount point\n" +
                  "indicates a file system that is currently not mounted (for example, because it\n" +
                  "has the <tt>noauto</tt> option set in <tt>/etc/fstab</tt>)."
              )
            )
          end
        when :num_cyl
          # helptext for table column and overview entry
          ret = Ops.add(
            ret,
            _(
              "<b>Number of Cylinders</b> shows how many\ncylinders the hard disk has."
            )
          )
        when :parity_algorithm
          # helptext for table column and overview entry
          ret = Ops.add(
            ret,
            _(
              "<b>Parity Algorithm</b> shows the parity\nalgorithm for RAID devices with RAID type 5, 6 or 10."
            )
          )
        when :pe_size
          # helptext for table column and overview entry
          ret = Ops.add(
            ret,
            _(
              "<b>PE Size</b> shows the physical extent size\nfor LVM volume groups."
            )
          )
        when :raid_version
          # helptext for table column and overview entry
          ret = Ops.add(ret, _("<b>RAID Version</b> shows the RAID version."))
        when :raid_type
          # helptext for table column and overview entry
          ret = Ops.add(
            ret,
            _(
              "<b>RAID Type</b> shows the RAID type, also\ncalled RAID level, for RAID devices."
            )
          )
        when :size
          # helptext for table column and overview entry
          ret = Ops.add(ret, _("<b>Size</b> shows the size of the device."))
        when :start_cyl
          # helptext for table column and overview entry
          ret = Ops.add(
            ret,
            _(
              "<b>Start Cylinder</b> shows the start cylinder\nof the partition."
            )
          )
        when :stripes
          # helptext for table column and overview entry
          ret = Ops.add(
            ret,
            _(
              "<b>Stripes</b> shows the stripe number for LVM\nlogical volumes and, if greater than one, the stripe size  in parenthesis.\n"
            )
          )
        when :type
          # helptext for table column and overview entry
          ret = Ops.add(
            ret,
            _("<b>Type</b> gives a general overview about the\ndevice type.")
          )
        when :udev_id
          # helptext for table column and overview entry
          ret = Ops.add(
            ret,
            _(
              "<b>Device ID</b> shows the persistent device\nIDs. This field can be empty.\n"
            )
          )
        when :udev_path
          # helptext for table column and overview entry
          ret = Ops.add(
            ret,
            _(
              "<b>Device Path</b> shows the persistent device\npath. This field can be empty."
            )
          )
        when :used_by
          # helptext for table column and overview entry
          ret = Ops.add(
            ret,
            _(
              "<b>Used By</b> shows if a device is used by\ne.g. RAID or LVM. If not, this column is empty.\n"
            )
          )
        when :uuid
          # helptext for table column and overview entry
          ret = Ops.add(
            ret,
            _(
              "<b>UUID</b> shows the Universally Unique\nIdentifier of the file system."
            )
          )
        when :vendor
          # helptext for table column and overview entry
          ret = Ops.add(ret, _("<b>Vendor</b> shows the device vendor."))
        else
          Builtins.y2error("unknown field %1", field)
          ret = Ops.add(ret, "error")
      end

      ret = Ops.add(ret, "</p>")

      ret
    end


    def MakeSubInfo(disk, part, field, style)
      disk = deep_copy(disk)
      part = deep_copy(part)
      data = part == nil ? disk : part
      type = part == nil ?
        Ops.get_symbol(disk, "type", :primary) :
        Ops.get_symbol(part, "type", :CT_DISK)

      device = Ops.get_string(data, "device", "")

      case field
        when :device
          value = device
          if style == :table
            return value
          else
            # row label, %1 is replace by device name
            return Builtins.sformat(_("Device: %1"), String.EscapeTags(value))
          end
        when :size
          value = Storage.KByteToHumanString(Ops.get_integer(data, "size_k", 0))
          if style == :table
            return value
          else
            # row label, %1 is replace by size
            return Builtins.sformat(_("Size: %1"), value)
          end
        when :type
          value = ""

          if part == nil
            disk_device = Ops.get_string(disk, "device", "")
            vendor = Ops.get_string(disk, "vendor", "")
            model = Ops.get_string(disk, "model", "")

            if model != "" && vendor != ""
              value = Ops.add(Ops.add(vendor, "-"), model)
            else
              value = Ops.add(vendor, model)
            end

            if value == ""
              if Ops.get_string(disk, "bus", "") == "RAID"
                value = Ops.add("RAID ", disk_device)
              elsif Ops.get_symbol(disk, "type", :CT_UNKNOWN) == :CT_LVM
                value = Ops.add(
                  "LVM" + (Ops.get_boolean(disk, "lvm2", false) ? "2 " : " "),
                  Ops.get_string(disk, "name", "")
                )
              elsif Ops.get_symbol(disk, "type", :CT_UNKNOWN) == :CT_DMRAID
                value = Ops.add("DM RAID ", Ops.get_string(disk, "name", ""))
              elsif Ops.get_symbol(disk, "type", :CT_UNKNOWN) == :CT_DMMULTIPATH
                value = Ops.add(
                  "DM Multipath ",
                  Ops.get_string(disk, "name", "")
                )
              elsif Ops.get_symbol(disk, "type", :CT_UNKNOWN) == :CT_MDPART
                value = Ops.add("MD RAID ", Ops.get_string(disk, "name", ""))
              else
                # label text
                vendor = Builtins.sformat(
                  _("DISK %1"),
                  Builtins.substring(disk_device, 5)
                )
              end
            end
          else
            value = Ops.get_string(part, "fstype", "")
          end
          if style == :table
            return term(
              :cell,
              term(
                :icon,
                Ops.add(
                  Ops.add(Directory.icondir, "22x22/apps/"),
                  StorageIcons.IconMap(type)
                )
              ),
              value
            )
          else
            # row label
            return Builtins.sformat(_("Type: %1"), String.EscapeTags(value))
          end
        when :format
          value = ""
          if part == nil
            if Ops.get_boolean(disk, "dasdfmt", false)
              value = Ops.add(value, "X")
            end
          else
            if Ops.get_boolean(part, "format", false)
              value = Ops.add(value, "F")
            end
          end
          if style == :table
            return value
          else
            # row label
            return Builtins.sformat(_("Format: %1"), value)
          end
        when :encrypted
          value = Ops.get_symbol(data, "enc_type", :none) != :none
          if style == :table
            if value
              if Ops.get_boolean(UI.GetDisplayInfo, "HasIconSupport", false)
                return term(
                  :cell,
                  term(
                    :icon,
                    Ops.add(
                      Ops.add(Directory.icondir, "22x22/apps/"),
                      StorageIcons.encrypted_icon
                    )
                  ),
                  ""
                )
              else
                return "E"
              end
            else
              return ""
            end
          else
            # row label, %1 is replace by "Yes" or "No"
            return Builtins.sformat(
              _("Encrypted: %1"),
              BooleanToHumanString(value)
            )
          end
        when :fs_type
          value = FileSystems.GetName(
            Ops.get_symbol(data, "used_fs", :unknown),
            ""
          )
          if style == :table
            return value
          else
            # row label, %1 is replace by file system name e.g. "Ext3"
            return Builtins.sformat(_("File System: %1"), value)
          end
        when :mount_point
          value = Ops.get_string(data, "mount", "")

          if Mode.normal
            if Ops.get_boolean(data, "inactive", false)
              value = Ops.add(value, " *")
            end
          end

          if style == :table
            return value
          else
            # row label, %1 is replace by mount point e.g. "/mnt"
            return Builtins.sformat(
              _("Mount Point: %1"),
              String.EscapeTags(value)
            )
          end
        when :mount_by
          value = ""

          if Ops.get_string(data, "mount", "") != ""
            tmp = {
              :device => "Kernel",
              :uuid   => "UUID",
              :label  => "Label",
              :id     => "ID",
              :path   => "Path"
            }
            mount_by = Ops.get_symbol(data, "mountby", :device)
            value = Ops.get_string(tmp, mount_by, "")
          end

          if Mode.normal
            tmp = false
            if (
                tmp_ref = arg_ref(tmp);
                _GetIgnoreFstab_result = Storage.GetIgnoreFstab(device, tmp_ref);
                tmp = tmp_ref.value;
                _GetIgnoreFstab_result
              ) && tmp
              value = "?"
            end
          end

          if style == :table
            return value
          else
            # row label, %1 is replace by mount by method
            return Builtins.sformat(_("Mount by: %1"), value)
          end
        when :used_by
          if style == :table
            return UsedByString(Ops.get_map(data, ["used_by", 0], {}))
          else
            n = Builtins.size(Ops.get_list(data, "used_by", []))
            return Builtins.mergestring(
              Builtins.maplist(Integer.Range(n == 0 ? 1 : n)) do |i|
                Builtins.sformat(
                  _("Used by %1: %2"),
                  Ops.add(i, 1),
                  String.EscapeTags(
                    UsedByString(Ops.get_map(data, ["used_by", i], {}))
                  )
                )
              end,
              HTML.Newline
            )
          end
        when :uuid
          value = Ops.get_string(data, "uuid", "")
          if style == :table
            return value
          else
            # row label, %1 is replace by file system uuid
            return Builtins.sformat(_("UUID: %1"), value)
          end
        when :label
          value = part == nil ? "" : Ops.get_string(data, "label", "")
          if style == :table
            return value
          else
            # row label, %1 is replace by file system label
            return Builtins.sformat(_("Label: %1"), String.EscapeTags(value))
          end
        when :udev_path
          value = Ops.get_string(data, "udev_path", "")
          if style == :table
            return value
          else
            # row label, %1 is replace by udev device path
            return Builtins.sformat(_("Device Path: %1"), value)
          end
        when :udev_id
          if style == :table
            return Ops.get_string(data, ["udev_id", 0], "")
          else
            n = Builtins.size(Ops.get_list(data, "udev_id", []))
            return Builtins.mergestring(
              Builtins.maplist(Integer.Range(n == 0 ? 1 : n)) do |i|
                Builtins.sformat(
                  _("Device ID %1: %2"),
                  Ops.add(i, 1),
                  Ops.get_string(data, ["udev_id", i], "")
                )
              end,
              HTML.Newline
            )
          end
        when :bios_id
          value = Ops.get_string(data, "bios_id", "")
          if style == :table
            return value
          else
            # row label, %1 is replace by bios id
            return Builtins.sformat(_("BIOS ID: %1"), value)
          end
        when :disk_label
          value = part == nil ?
            Builtins.toupper(Ops.get_string(data, "label", "")) :
            ""
          if style == :table
            return value
          else
            # row label, %1 is replace by disk label e.g. "MSDOS" or "GPT"
            return Builtins.sformat(_("Disk Label: %1"), value)
          end
        when :vendor
          value = Ops.get_string(data, "vendor", "")
          if style == :table
            return value
          else
            # row label, %1 is replace by vendor name
            return Builtins.sformat(_("Vendor: %1"), String.EscapeTags(value))
          end
        when :model
          value = Ops.get_string(data, "model", "")
          if style == :table
            return value
          else
            # row label, %1 is replace by model string
            return Builtins.sformat(_("Model: %1"), String.EscapeTags(value))
          end
        when :bus
          names = {
            :sbp   => "Firewire",
            :ata   => "ATA",
            :fc    => "Fibre Channel",
            :iscsi => "iSCSI",
            :sas   => "SAS",
            :sata  => "SATA",
            :spi   => "SCSI",
            :usb   => "USB",
            :fcoe  => "FCoE"
          }
          value = Ops.get(
            names,
            Ops.get_symbol(data, "transport", :unknown),
            ""
          )
          if style == :table
            return value
          else
            # row label, %1 is replace by bus name e.g. "SCSI"
            return Builtins.sformat(_("Bus: %1"), value)
          end
        when :lvm_metadata
          value = ""
          if Ops.get_symbol(disk, "type", :CT_UNKNOWN) == :CT_LVM && part == nil
            value = Ops.get_boolean(disk, "lvm2", true) ? "LVM2" : "LVM1"
          end
          if style == :table
            return value
          else
            # row label, %1 is replace by metadata version string
            return Builtins.sformat(_("Metadata: %1"), value)
          end
        when :pe_size
          value = ""
          if Ops.get_symbol(disk, "type", :CT_UNKNOWN) == :CT_LVM && part == nil
            value = Storage.ByteToHumanStringOmitZeroes(
              Ops.get_integer(disk, "pesize", 0)
            )
          end
          if style == :table
            return value
          else
            # row label, %1 is replace by size
            return Builtins.sformat(_("PE Size: %1"), value)
          end
        when :stripes
          value = ""
          if Ops.get_symbol(disk, "type", :CT_UNKNOWN) == :CT_LVM && part != nil
            stripes = Ops.get_integer(data, "stripes", 1)
            stripesize = Ops.get_integer(data, "stripesize", 0)
            if stripes == 1
              value = Builtins.sformat("%1", stripes)
            else
              value = Builtins.sformat(
                "%1 (%2)",
                stripes,
                Storage.KByteToHumanStringOmitZeroes(stripesize)
              )
            end
          end
          if style == :table
            return value
          else
            # row label, %1 is replace by integer
            return Builtins.sformat(_("Stripes: %1"), value)
          end
        when :raid_version
          value = Ops.get_string(data, "sb_ver", "")
          if style == :table
            return value
          else
            # row label, %1 is replace by raid version e.g. "1.00"
            return Builtins.sformat(_("RAID Version: %1"), value)
          end
        when :raid_type
          value = Builtins.toupper(Ops.get_string(data, "raid_type", ""))
          if style == :table
            return value
          else
            # row label, %1 is replace by raid type e.g. "RAID1"
            return Builtins.sformat(_("RAID Type: %1"), value)
          end
        when :chunk_size
          value = ""
          if Ops.get_string(data, "raid_type", "") == "raid0" ||
              Storage.HasRaidParity(Ops.get_string(data, "raid_type", ""))
            chunksize = Ops.get_integer(data, "chunk_size", 0)
            value = Storage.KByteToHumanStringOmitZeroes(chunksize)
          end
          if style == :table
            return value
          else
            # row label, %1 is replace by size
            return Builtins.sformat(_("Chunk Size: %1"), value)
          end
        when :parity_algorithm
          value = ""
          if Storage.HasRaidParity(Ops.get_string(data, "raid_type", ""))
            value = Ops.get_string(data, "parity_algorithm", "")
            value = Builtins.mergestring(Builtins.splitstring(value, "_"), "-")
          end
          if style == :table
            return value
          else
            # row label, %1 is replace by algorithm name
            return Builtins.sformat(_("Parity Algorithm: %1"), value)
          end
        when :num_cyl
          value = ""
          if part == nil && Storage.IsPartitionable(disk)
            value = Builtins.tostring(Ops.get_integer(disk, "cyl_count", 0))
          end
          if style == :table
            return value
          else
            # row label, %1 is replace by integer
            return Builtins.sformat(_("Number of Cylinders: %1"), value)
          end
        when :cyl_size
          value = ""
          if part == nil && Storage.IsPartitionable(disk)
            value = Storage.ByteToHumanString(
              Ops.get_integer(disk, "cyl_size", 0)
            )
          end
          if style == :table
            return value
          else
            # row label, %1 is replace by size
            return Builtins.sformat(_("Cylinder Size: %1"), value)
          end
        when :start_cyl
          value = ""
          if Storage.IsPartitionable(disk)
            if part == nil
              value = Builtins.tostring(0)
            else
              value = Builtins.tostring(
                Region.Start(Ops.get_list(part, "region", []))
              )
            end
          end
          if style == :table
            return value
          else
            # row label, %1 is replace by integer
            return Builtins.sformat(_("Start Cylinder: %1"), value)
          end
        when :end_cyl
          value = ""
          if Storage.IsPartitionable(disk)
            if part == nil
              value = Builtins.tostring(
                Ops.subtract(Ops.get_integer(disk, "cyl_count", 0), 1)
              )
            else
              value = Builtins.tostring(
                Region.End(Ops.get_list(part, "region", []))
              )
            end
          end
          if style == :table
            return value
          else
            # row label, %1 is replace by integer
            return Builtins.sformat(_("End Cylinder: %1"), value)
          end
        when :sector_size
          value = ""
          if part == nil && Storage.IsPartitionable(disk)
            value = Storage.ByteToHumanStringOmitZeroes(
              Ops.get_integer(disk, "sector_size", 0)
            )
          end
          if style == :table
            return value
          else
            # row label, %1 is replace by size
            return Builtins.sformat(_("Sector Size: %1"), value)
          end
        when :fs_id
          fs_id = Ops.get_integer(data, "fsid", 0)
          value = Ops.add(
            Ops.add(Partitions.ToHexString(fs_id), " "),
            Partitions.FsIdToString(fs_id)
          )
          if style == :table
            return value
          else
            # row label, %1 is replace by file system id
            return Builtins.sformat(_("FS ID: %1"), value)
          end
        when :file_path
          value = Ops.get_string(data, "fpath", "")
          if style == :table
            return value
          else
            # row label, %1 is replace by file path e.g. "/data/secret"
            return Builtins.sformat(
              _("File Path: %1"),
              String.EscapeTags(value)
            )
          end
        when :fc_wwpn
          value = ""
          if Builtins.haskey(Ops.get_map(data, "fc", {}), "wwpn")
            value = Ops.add(
              "0x",
              Builtins.toupper(
                Builtins.substring(
                  Builtins.tohexstring(
                    Ops.get_integer(data, ["fc", "wwpn"], 0),
                    16
                  ),
                  2
                )
              )
            )
          end
          if style == :table
            return value
          else
            # row label, %1 is replace by wwpn
            return Builtins.sformat(_("WWPN: %1"), value)
          end
        when :fc_fcp_lun
          value = ""
          if Builtins.haskey(Ops.get_map(data, "fc", {}), "fcp_lun")
            value = Builtins.tostring(
              Ops.get_integer(data, ["fc", "fcp_lun"], 0)
            )
          end
          if style == :table
            return value
          else
            # row label, %1 is replace by lun
            return Builtins.sformat(_("LUN: %1"), value)
          end
        when :fc_port_id
          value = ""
          if Builtins.haskey(Ops.get_map(data, "fc", {}), "port_id")
            value = Ops.add(
              "0x",
              Builtins.toupper(
                Builtins.substring(
                  Builtins.tohexstring(
                    Ops.get_integer(data, ["fc", "port_id"], 0),
                    6
                  ),
                  2
                )
              )
            )
          end
          if style == :table
            return value
          else
            # row label, %1 is replace by port id
            return Builtins.sformat(_("Port ID: %1"), value)
          end
        else
          Builtins.y2error("unknown field %1", field)
          return "error"
      end
    end


    def TableRow(fields, disk, part)
      fields = deep_copy(fields)
      disk = deep_copy(disk)
      part = deep_copy(part)
      device = part == nil ?
        Ops.get_string(disk, "device", "") :
        Ops.get_string(part, "device", "")
      if Ops.get_symbol(disk, "type", :CT_UNKNOWN) == :CT_TMPFS
        device = Ops.add("tmpfs:", Ops.get_string(part, "mount", ""))
      end

      row = Builtins::List.reduce(Item(Id(device)), fields) do |tmp, field|
        Builtins.add(tmp, MakeSubInfo(disk, part, field, :table))
      end

      deep_copy(row)
    end


    def AlwaysHideDisk(target_map, disk)
      target_map = deep_copy(target_map)
      disk = deep_copy(disk)
      real_disk = Storage.IsPartitionable(disk)
      type = Ops.get_symbol(disk, "type", :CT_UNKNOWN)

      return true if type == :CT_DISK && !real_disk

      if !Builtins.contains(
          [:CT_DISK, :CT_DMRAID, :CT_DMMULTIPATH, :CT_MDPART, :CT_LVM],
          type
        )
        return true
      end

      false
    end


    def AlwaysHidePartition(target_map, disk, partition)
      target_map = deep_copy(target_map)
      disk = deep_copy(disk)
      partition = deep_copy(partition)
      if Ops.get_integer(partition, "fsid", 0) == Partitions.fsid_mac_hidden
        return true
      end

      false
    end


    # Predicate function for Table and TableContents.
    def PredicateAll(disk, partition)
      disk = deep_copy(disk)
      partition = deep_copy(partition)
      :showandfollow
    end


    # Predicate function for Table and TableContents.
    def PredicateDiskType(disk, partition, disk_types)
      disk = deep_copy(disk)
      partition = deep_copy(partition)
      disk_types = deep_copy(disk_types)
      if partition == nil
        if Builtins.contains(
            disk_types,
            Ops.get_symbol(disk, "type", :CT_UNKNOWN)
          )
          return :showandfollow
        else
          return :ignore
        end
      else
        return :show
      end
    end


    # Predicate function for Table and TableContents.
    def PredicateDiskDevice(disk, partition, disk_devices)
      disk = deep_copy(disk)
      partition = deep_copy(partition)
      disk_devices = deep_copy(disk_devices)
      if partition == nil
        if Builtins.contains(disk_devices, Ops.get_string(disk, "device", ""))
          return :follow
        else
          return :ignore
        end
      else
        return :show
      end
    end


    # Predicate function for Table and TableContents.
    def PredicateDevice(disk, partition, devices)
      disk = deep_copy(disk)
      partition = deep_copy(partition)
      devices = deep_copy(devices)
      if partition == nil
        if Builtins.contains(devices, Ops.get_string(disk, "device", ""))
          return :showandfollow
        else
          return :follow
        end
      else
        if Builtins.contains(devices, Ops.get_string(partition, "device", ""))
          return :show
        else
          return :ignore
        end
      end
    end


    # Predicate function for Table and TableContents.
    def PredicateUsedByDevice(disk, partition, devices)
      disk = deep_copy(disk)
      partition = deep_copy(partition)
      devices = deep_copy(devices)
      if partition == nil
        if Builtins.find(Ops.get_list(disk, "used_by", [])) do |used_by|
            Builtins.contains(devices, Ops.get_string(used_by, "device", ""))
          end != nil
          return :showandfollow
        else
          return :follow
        end
      else
        if Builtins.find(Ops.get_list(partition, "used_by", [])) do |used_by|
            Builtins.contains(devices, Ops.get_string(used_by, "device", ""))
          end != nil
          return :show
        else
          return :ignore
        end
      end
    end


    # Predicate function for Table and TableContents.
    def PredicateMountpoint(disk, partition)
      disk = deep_copy(disk)
      partition = deep_copy(partition)
      if partition == nil
        if !Builtins.isempty(Ops.get_string(disk, "mount", ""))
          return :showandfollow
        else
          return :follow
        end
      else
        if !Builtins.isempty(Ops.get_string(partition, "mount", ""))
          return :show
        else
          return :ignore
        end
      end
    end

    # Predicate function for Table and TableContents.
    def PredicateBtrfs(disk, partition)
      disk = deep_copy(disk)
      partition = deep_copy(partition)
      if partition == nil
        return :follow
      else
        if Ops.get_symbol(partition, "used_fs", :unknown) == :btrfs &&
            !Storage.IsUsedBy(partition) &&
            (Ops.get_symbol(partition, ["used_by", 0, "type"], :UB_NONE) == :UB_BTRFS ||
              Builtins.search(Ops.get_string(partition, "device", ""), "UUID=") == 0)
          return :show
        else
          return :ignore
        end
      end
    end

    # Predicate function for Table and TableContents.
    def PredicateTmpfs(disk, partition)
      disk = deep_copy(disk)
      partition = deep_copy(partition)
      if partition == nil
        return :follow
      else
        if Ops.get_symbol(partition, "used_fs", :unknown) == :tmpfs
          return :show
        else
          return :ignore
        end
      end
    end




    # The predicate function determines whether the disk/partition is
    # included. The predicate function takes two arguments, disk and
    # partition. For disks predicate is called with the partitions set to
    # nil.
    #
    # Possible return values for predicate:
    # `show, `follow, `showandfollow, `ignore
    def TableContents(fields, target_map, predicate)
      fields = deep_copy(fields)
      target_map = deep_copy(target_map)
      predicate = deep_copy(predicate)
      contents = []

      callback = lambda do |target_map2, disk|
        target_map2 = deep_copy(target_map2)
        disk = deep_copy(disk)
        disk_predicate = predicate.call(disk, nil)

        if !AlwaysHideDisk(target_map2, disk) &&
            Builtins.contains([:show, :showandfollow], disk_predicate)
          row = TableRow(fields, disk, nil)
          contents = Builtins.add(contents, row)
        end

        if Builtins.contains([:follow, :showandfollow], disk_predicate)
          partitions = Ops.get_list(disk, "partitions", [])

          Builtins.foreach(partitions) do |partition|
            part_predicate = predicate.call(disk, partition)
            if !AlwaysHidePartition(target_map2, disk, partition) &&
                Builtins.contains([:show, :showandfollow], part_predicate)
              row = TableRow(fields, disk, partition)
              contents = Builtins.add(contents, row)
            end
          end
        end

        nil
      end

      IterateTargetMap(
        target_map,
        fun_ref(callback, "void (map <string, map>, map)")
      )

      deep_copy(contents)
    end



    def Table(fields, target_map, predicate)
      fields = deep_copy(fields)
      target_map = deep_copy(target_map)
      predicate = deep_copy(predicate)
      header = TableHeader(fields)
      content = TableContents(fields, target_map, predicate)

      term(:Table, Opt(:keepSorting), header, content)
    end


    def TableHelptext(fields)
      fields = deep_copy(fields)
      fields = Builtins.filter(fields) do |field|
        Builtins.substring(Builtins.tostring(field), 0, 8) != "`heading"
      end

      initial = _("<p>The table contains:</p>")

      helptext = Builtins::List.reduce(initial, fields) do |tmp, field|
        Ops.add(tmp, Helptext(field, :table))
      end

      helptext
    end


    # The device must be the device entry in the target-map, e.g. "/dev/sda1",
    # not something like "LABEL=test".
    def OverviewContents(fields, target_map, device)
      fields = deep_copy(fields)
      target_map = deep_copy(target_map)
      disk = Ops.get(target_map, device)
      part = nil

      Builtins.foreach(target_map) do |s, d|
        part = Builtins.find(Ops.get_list(d, "partitions", [])) do |p|
          Ops.get_string(p, "device", "") == device
        end
        if part != nil
          disk = deep_copy(d)
          raise Break
        end
      end if disk == nil

      splitfields = lambda do |fields2|
        fields2 = deep_copy(fields2)
        ret = []

        tmp = []
        Builtins.foreach(fields2) do |field|
          if Builtins.substring(Builtins.tostring(field), 0, 8) == "`heading"
            if Ops.greater_than(Builtins.size(tmp), 1)
              ret = Builtins.add(ret, tmp)
            end
            tmp = [field]
          else
            tmp = Builtins.add(tmp, field)
          end
        end
        ret = Builtins.add(ret, tmp) if Ops.greater_than(Builtins.size(tmp), 1)

        deep_copy(ret)
      end

      _Heading = lambda do |field|
        case field
          when :heading_device
            # heading
            return _("Device:")
          when :heading_filesystem
            # heading
            return _("File System:")
          when :heading_hd
            # heading
            return _("Hard Disk:")
          when :heading_fc
            # heading
            return _("Fibre Channel:")
          when :heading_lvm
            # heading
            return _("LVM:")
          when :heading_md
            # heading
            return _("RAID:")
          else
            Builtins.y2error("unknown field %1", field)
            return "error"
        end
      end

      _List = lambda do |fields2|
        fields2 = deep_copy(fields2)
        Builtins.maplist(fields2) do |field|
          Convert.to_string(MakeSubInfo(disk, part, field, :overview))
        end
      end

      content = Builtins.mergestring(
        Builtins.maplist(splitfields.call(fields)) do |subfields|
          Ops.add(
            HTML.Heading(_Heading.call(Ops.get(subfields, 0, :none))),
            HTML.List(_List.call(Builtins.sublist(subfields, 1)))
          )
        end,
        ""
      )

      content
    end


    def Overview(fields, target_map, device)
      fields = deep_copy(fields)
      target_map = deep_copy(target_map)
      contents = OverviewContents(fields, target_map, device)

      RichText(Id(:text), Opt(:hstretch, :vstretch), contents)
    end


    def OverviewHelptext(fields)
      fields = deep_copy(fields)
      fields = Builtins.filter(fields) do |field|
        Builtins.substring(Builtins.tostring(field), 0, 8) != "`heading"
      end

      initial = _("<p>The overview contains:</p>")

      helptext = Builtins::List.reduce(initial, fields) do |tmp, field|
        Ops.add(tmp, Helptext(field, :overview))
      end

      helptext
    end

    publish :function => :IterateTargetMap, :type => "void (map <string, map>, void (map <string, map>, map))"
    publish :function => :UsedByString, :type => "string (map <string, any>)"
    publish :function => :TableHeader, :type => "term (list <symbol>)"
    publish :function => :AlwaysHideDisk, :type => "boolean (map <string, map>, map)"
    publish :function => :AlwaysHidePartition, :type => "boolean (map <string, map>, map, map)"
    publish :function => :PredicateAll, :type => "symbol (map, map)"
    publish :function => :PredicateDiskType, :type => "symbol (map, map, list <symbol>)"
    publish :function => :PredicateDiskDevice, :type => "symbol (map, map, list <string>)"
    publish :function => :PredicateDevice, :type => "symbol (map, map, list <string>)"
    publish :function => :PredicateUsedByDevice, :type => "symbol (map, map, list <string>)"
    publish :function => :PredicateMountpoint, :type => "symbol (map, map)"
    publish :function => :PredicateBtrfs, :type => "symbol (map, map)"
    publish :function => :PredicateTmpfs, :type => "symbol (map, map)"
    publish :function => :TableContents, :type => "list <term> (list <symbol>, map <string, map>, symbol (map, map))"
    publish :function => :Table, :type => "term (list <symbol>, map <string, map>, symbol (map, map))"
    publish :function => :TableHelptext, :type => "string (list <symbol>)"
    publish :function => :OverviewContents, :type => "string (list <symbol>, map <string, map>, string)"
    publish :function => :Overview, :type => "term (list <symbol>, map <string, map>, string)"
    publish :function => :OverviewHelptext, :type => "string (list <symbol>)"
  end

  StorageFields = StorageFieldsClass.new
  StorageFields.main
end
