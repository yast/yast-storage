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

# File:
#	StorageDevices.ycp
#
# Module:
#	StorageDevices
#
# Depends:
#	StorageControllers
#
# Summary:
#	This module does all storage device related stuff:
#	- hard disk drives
#	- removable drives (ZIP)
#	- floppy devices
#
# $Id$
#
# Author:
#	Klaus Kaempf <kkaempf@suse.de> (initial)
require "yast"

module Yast
  class StorageDevicesClass < Module
    def main

      Yast.import "Mode"
      Yast.import "Stage"
      Yast.import "HwStatus"

      textdomain "storage"


      @disks_valid = false


      # @return [Hash] of $["device": $[..target..], ...] for each ZIP drive
      #
      @zip_drives = nil


      # @return [Array] of maps: all kinds of removable media, esp. ZIP drives
      @floppy_drives = nil


      # @return true if floppy drive present
      @floppy_present = nil


      # @return Device name of floppy, empty string if no floppy present
      @floppy_device = nil


      #---------------------------------------------------------------

      # list of cd-rom drives
      @cd_drives = nil

      # storage for localProbe, see Probe()
      @targetMapSize = 0
      StorageDevices()
    end

    #---------------------------------------------------------------


    def AddNormalLinknames(cddrives)
      cddrives = deep_copy(cddrives)
      linknum = {
        "cdrom"       => 0,
        "cdrecorder"  => 0,
        "dvd"         => 0,
        "dvdrecorder" => 0,
        "dvdram"      => 0
      }

      cddrives = Builtins.maplist(cddrives) do |e|
        # first, determine the drive type and make a linkname guess
        cddevice = Ops.get_string(e, "dev_name", "")
        linkname = "cdrom"
        if Ops.get_boolean(e, "dvdram", false)
          linkname = "dvdram"
        elsif Ops.get_boolean(e, "dvdr", false)
          linkname = "dvdrecorder"
        elsif Ops.get_boolean(e, "cdr", false) ||
            Ops.get_boolean(e, "cdrw", false)
          linkname = "cdrecorder"
        elsif Ops.get_boolean(e, "dvd", false)
          linkname = "dvd"
        end
        # now check the number (for /dev/cdrom, /dev/cdrom2, ...)
        number = Ops.get_integer(linknum, linkname, 0)
        Ops.set(linknum, linkname, Ops.add(number, 1))
        devname = Ops.add("/dev/", linkname)
        if Ops.greater_than(number, 0)
          devname = Builtins.sformat("%1%2", devname, Ops.add(number, 1))
        end
        Ops.set(e, "linkname", devname)
        deep_copy(e)
      end
      Builtins.y2milestone("AddNormalLinknames linknum %1", linknum)
      deep_copy(cddrives)
    end

    def AddAlternateLinks(cddrives)
      cddrives = deep_copy(cddrives)
      llist = []
      Builtins.foreach(cddrives) do |cd|
        llist = Convert.convert(
          Builtins.union(llist, Ops.get_list(cd, "udev_links", [])),
          :from => "list",
          :to   => "list <string>"
        )
      end
      Builtins.y2milestone("AddAlternateLinks llist %1", llist)

      if !Builtins.contains(llist, "cdrom") &&
          Ops.greater_than(Builtins.size(cddrives), 0)
        Ops.set(
          cddrives,
          [0, "udev_links"],
          Builtins.add(Ops.get_list(cddrives, [0, "udev_links"], []), "cdrom")
        )
        Builtins.y2milestone(
          "AddAlternateLinks cdrom %1",
          Ops.get(cddrives, 0, {})
        )
      end
      i = 0
      if !Builtins.contains(llist, "dvd")
        while Ops.less_than(i, Builtins.size(cddrives)) &&
            !Ops.get_boolean(cddrives, [i, "dvd"], false)
          i = Ops.add(i, 1)
        end
        if Ops.less_than(i, Builtins.size(cddrives))
          Ops.set(
            cddrives,
            [i, "udev_links"],
            Builtins.add(Ops.get_list(cddrives, [i, "udev_links"], []), "dvd")
          )
          Builtins.y2milestone(
            "AddAlternateLinks dvd %1",
            Ops.get(cddrives, i, {})
          )
        end
      end
      if !Builtins.contains(llist, "cdrecorder")
        i = 0
        while Ops.less_than(i, Builtins.size(cddrives)) &&
            !Ops.get_boolean(cddrives, [i, "cdrw"], false)
          i = Ops.add(i, 1)
        end
        if Ops.less_than(i, Builtins.size(cddrives))
          Ops.set(
            cddrives,
            [i, "udev_links"],
            Builtins.add(
              Ops.get_list(cddrives, [i, "udev_links"], []),
              "cdrecorder"
            )
          )
          Builtins.y2milestone(
            "AddAlternateLinks cdrecorder %1",
            Ops.get(cddrives, i, {})
          )
        end
      end
      Builtins.y2milestone("AddAlternateLinks ret %1", cddrives)
      deep_copy(@cd_drives)
    end

    # ProbeCDROMs()
    #
    # Initialize cd_drives
    #
    def ProbeCDROMs
      if @cd_drives == nil
        @cd_drives = []
        if Stage.initial || Stage.cont
          Builtins.y2milestone("before SCR::Read (.probe.cdrom)")
          @cd_drives = Convert.convert(
            SCR.Read(path(".probe.cdrom")),
            :from => "any",
            :to   => "list <map>"
          )
          Builtins.y2milestone("after SCR::Read (.probe.cdrom)")
          # write out data for hardware status check
          Builtins.foreach(@cd_drives) do |drive|
            HwStatus.Set(Ops.get_string(drive, "unique_key", ""), :yes)
          end
        else
          Builtins.y2milestone("before SCR::Read (.probe.cdrom)")
          Builtins.foreach(
            Convert.convert(
              SCR.Read(path(".probe.cdrom")),
              :from => "any",
              :to   => "list <map>"
            )
          ) do |e|
            conf = Convert.to_map(
              SCR.Read(
                path(".probe.status"),
                Ops.get_string(e, "unique_key", "")
              )
            )
            Builtins.y2milestone("ProbeCDROMs conf:%1", conf)
            Builtins.y2milestone("ProbeCDROMs cd:%1", e)
            if Ops.get_symbol(conf, "available", :no) != :no
              @cd_drives = Builtins.add(@cd_drives, e)
            end
          end

          if @cd_drives == nil || Builtins.size(@cd_drives) == 0
            @cd_drives = [{ "dev_name" => "/dev/cdrom" }]
          end
        end

        boot_device = Convert.to_string(
          SCR.Read(path(".etc.install_inf.Cdrom"))
        )
        boot_device = "" if boot_device == nil

        if boot_device != ""
          Builtins.y2milestone("ProbeCDROMs cddrives:%1", @cd_drives)
          Builtins.y2milestone("ProbeCDROMs boot_device:%1", boot_device)

          if Builtins.search(boot_device, "/dev/") != 0
            boot_device = Ops.add("/dev/", boot_device)
          end
          tmp = Builtins.filter(@cd_drives) do |e|
            Ops.get_string(e, "dev_name", "") == boot_device
          end
          if Ops.greater_than(Builtins.size(tmp), 0)
            @cd_drives = Builtins.filter(@cd_drives) do |e|
              Ops.get_string(e, "dev_name", "") != boot_device
            end
            @cd_drives = Convert.convert(
              Builtins.merge(tmp, @cd_drives),
              :from => "list",
              :to   => "list <map>"
            )
          end

          Builtins.y2milestone("ProbeCDROMs cddrives:%1", @cd_drives)
        end

        Builtins.y2milestone("ProbeCDROMs cddrives:%1", @cd_drives)
        @cd_drives = AddNormalLinknames(@cd_drives)
        @cd_drives = Builtins.maplist(@cd_drives) do |drive|
          Ops.set(
            drive,
            "udev_links",
            [Builtins.substring(Ops.get_string(drive, "linkname", ""), 5)]
          )
          deep_copy(drive)
        end
        @cd_drives = AddAlternateLinks(@cd_drives)
      end
      Builtins.y2milestone("ProbeCDROMs (%1)", @cd_drives)
      Ops.greater_than(Builtins.size(@cd_drives), 0)
    end

    def cddrives
      ProbeCDROMs() if @cd_drives == nil
      deep_copy(@cd_drives)
    end

    def GetCdromEntry(device)
      ret = {}
      Builtins.y2milestone("GetCdromEntry device %1", device)
      ret = Builtins.find(@cd_drives) do |e|
        Ops.get_string(e, "dev_orig", Ops.get_string(e, "dev_name", "")) == device
      end
      ret = {} if ret == nil
      Builtins.y2milestone("GetCdromEntry ret %1", ret)
      deep_copy(ret)
    end

    # FloppyReady ()
    # @return floppy media status
    # determines if a media is present.
    # @see: FloppyPresent
    # @see: FloppyDevice

    def FloppyReady
      if @floppy_present == nil
        @floppy_present = false
        @floppy_drives = []
        if Stage.initial
          Builtins.y2milestone("before .probe.floppy")
          @floppy_drives = Convert.convert(
            SCR.Read(path(".probe.floppy")),
            :from => "any",
            :to   => "list <map>"
          )
          Builtins.y2milestone("after .probe.floppy")

          # write out data for hardware status check
          Builtins.foreach(@floppy_drives) do |drive|
            HwStatus.Set(Ops.get_string(drive, "unique_key", ""), :yes)
          end
        else
          Builtins.y2milestone("before .probe.floppy.manual")
          @floppy_drives = Convert.convert(
            SCR.Read(path(".probe.floppy.manual")),
            :from => "any",
            :to   => "list <map>"
          )
          Builtins.y2milestone("after .probe.floppy.manual")
        end
        @floppy_device = Ops.get_string(@floppy_drives, [0, "dev_name"], "")
        @floppy_present = true if @floppy_device != "" || Mode.test
      end
      Builtins.y2milestone("FloppyDrives %1", @floppy_drives)
      Ops.greater_than(Builtins.size(Ops.get(@floppy_drives, 0, {})), 0) &&
        !Builtins.haskey(Ops.get(@floppy_drives, 0, {}), "notready")
    end


    # loop over floppy drives to find IDE ZIPs
    # return map of $[ "device" : $[target], ...]

    def findZIPs
      zips = {}
      FloppyReady()
      Builtins.foreach(@floppy_drives) do |disk|
        if Ops.get_boolean(disk, "zip", false)
          target = {}
          dname = ""

          ddevice = Ops.get_string(disk, "dev_name", "?")
          dinfo = Ops.get_string(disk, "vendor", "")

          Ops.set(target, "vendor", dinfo)
          dname = Ops.add(Ops.add(dname, dinfo), "-") if dinfo != ""

          dinfo = Ops.get_string(disk, "device", "")
          Ops.set(target, "model", dinfo)

          dname = Ops.add(dname, dinfo) if dinfo != ""
          Ops.set(target, "name", dname)
          Ops.set(target, "partitions", [])

          Ops.set(zips, ddevice, target)
        end
      end
      Builtins.y2milestone("zips %1", zips)
      deep_copy(zips)
    end

    def ZipDrives
      @zip_drives = findZIPs if @zip_drives == nil
      deep_copy(@zip_drives)
    end


    # Fake probing for storage devices in test or demo mode -
    # read ready-made target maps from file.
    #
    # @return	map	TargetMap

    def fakeProbe
      fake_map_file = Mode.test ? "demo_target_map.ycp" : "test_target_map.ycp"

      Builtins.y2milestone(
        "%1 mode - using fake target map from %2",
        Mode.test ? "Demo" : "Test",
        fake_map_file
      )

      target_map = Convert.convert(
        SCR.Read(path(".target.yast2"), fake_map_file),
        :from => "any",
        :to   => "map <string, map>"
      )

      Builtins.y2debug("Fake target map: %1", target_map)

      deep_copy(target_map)
    end


    def FloppyPresent
      FloppyReady() if @floppy_present == nil
      @floppy_present
    end

    def FloppyDevice
      FloppyReady() if @floppy_device == nil
      @floppy_device
    end

    def FloppyDrives
      FloppyReady() if @floppy_drives == nil
      deep_copy(@floppy_drives)
    end


    # Probe for storage devices attached to storage controllers
    # Should be called after StorageControllers::Initialize
    # @return	map	TargetMap

    def localProbe
      targets = {}
      return fakeProbe if Mode.test
      FloppyReady()

      # do the probing. disks are sorted the way found in /sys/block.
      all_disks = Convert.convert(
        SCR.Read(path(".probe.disk_raid")),
        :from => "any",
        :to   => "list <map>"
      )
      Builtins.y2milestone("localProbe: disks probed all_disks:%1", all_disks)

      if Builtins.size(all_disks) == 0
        # somehow, we couldn't find any harddisks for installation.
        # This is a fatal error, we can't do anything about it
        return deep_copy(targets)
      end

      # loop over all_disks, constructing targets map

      @zip_drives = {}

      Builtins.foreach(Builtins.filter(all_disks) do |e|
        !Builtins.isempty(Ops.get_string(e, "dev_name", ""))
      end) do |disk|
        Builtins.y2milestone("localProbe: disk %1", disk)
        target = {}
        no_disk = false
        notready = Ops.get_boolean(disk, "notready", false) &&
          Ops.get_string(disk, "device", "") != "DASD"
        is_zip = notready || Ops.get_boolean(disk, "zip", false)
        if Builtins.search(Ops.get_string(disk, "dev_name", ""), "/dev/dm-") == 0 &&
            Builtins.size(Ops.get_string(disk, "bios_id", "")) == 0 &&
            Ops.get_integer(
              disk,
              ["resource", "disk_log_geo", 0, "cylinders"],
              0
            ) == 0
          no_disk = true
        end
        if Ops.get_boolean(disk, "hotpluggable", false)
          Ops.set(target, "hotpluggable", true)
        end
        if Ops.get_boolean(disk, "softraiddisk", false)
          Ops.set(target, "softraiddisk", true)
        end
        res_fc = Ops.get_map(disk, ["resource", "fc", 0], {})
        Ops.set(target, "fc", res_fc) if res_fc != {}
        Builtins.y2milestone(
          "localProbe: is_zip:%1 notready:%2 softraid:%3 no_disk:%4",
          is_zip,
          notready,
          Ops.get_boolean(disk, "softraiddisk", false),
          no_disk
        )
        next if no_disk
        # write out data for hardware status check
        HwStatus.Set(Ops.get_string(disk, "unique_key", ""), :yes)
        Ops.set(target, "unique", Ops.get_string(disk, "unique_key", ""))
        Ops.set(target, "bus", Ops.get_string(disk, "bus", "?"))
        # needed also later as key
        ddevice = Ops.get_string(disk, "dev_name", "")
        Ops.set(target, "device", ddevice)
        if Ops.greater_than(
            Builtins.size(Ops.get_string(disk, "bios_id", "")),
            0
          )
          Ops.set(target, "bios_id", Ops.get_string(disk, "bios_id", ""))
        end
        Builtins.y2milestone("localProbe: disk: %1", ddevice)
        # ------------------------------------------------------
        # construct full target name
        if Ops.greater_than(
            Builtins.size(Ops.get_string(disk, "vendor", "")),
            0
          )
          Ops.set(target, "vendor", Ops.get_string(disk, "vendor", ""))
        end
        if Ops.greater_than(
            Builtins.size(Ops.get_string(disk, "device", "")),
            0
          )
          Ops.set(target, "model", Ops.get_string(disk, "device", ""))
        end
        if Ops.greater_than(
            Builtins.size(Ops.get_string(disk, "driver", "")),
            0
          )
          Ops.set(target, "driver", Ops.get_string(disk, "driver", ""))
        end
        if Ops.greater_than(
            Builtins.size(Ops.get_string(disk, "driver_module", "")),
            0
          )
          Ops.set(
            target,
            "driver_module",
            Ops.get_string(disk, "driver_module", "")
          )
        end
        if Ops.greater_than(
            Builtins.size(Ops.get_string(disk, "parent_unique_key", "")),
            0
          )
          tmp = Convert.to_map(
            SCR.Read(
              path(".probe.uniqueid"),
              Ops.get_string(disk, "parent_unique_key", "")
            )
          )
          Builtins.y2milestone("localProbe: parent %1", tmp)
          m1 = Builtins.find(Ops.get_list(tmp, "drivers", [])) do |e|
            Ops.get_boolean(e, "active", false)
          end
          Builtins.y2milestone("localProbe: m1 %1", m1)
          if m1 != nil &&
              Ops.greater_than(
                Builtins.size(Ops.get_list(m1, "modules", [])),
                0
              )
            Ops.set(
              target,
              "modules",
              Builtins.merge(
                Ops.get_list(target, "modules", []),
                Builtins.maplist(Ops.get_list(m1, "modules", [])) do |l|
                  Ops.get_string(l, 0, "")
                end
              )
            )
          end
          m2 = Builtins.find(Ops.get_list(disk, "drivers", [])) do |e|
            Ops.get_boolean(e, "active", false)
          end
          Builtins.y2milestone("localProbe: m2 %1", m2)
          if m2 != nil &&
              Ops.greater_than(
                Builtins.size(Ops.get_list(m2, "modules", [])),
                0
              )
            Ops.set(
              target,
              "modules",
              Builtins.merge(
                Ops.get_list(target, "modules", []),
                Builtins.maplist(Ops.get_list(m2, "modules", [])) do |l|
                  Ops.get_string(l, 0, "")
                end
              )
            )
          end
          Builtins.y2milestone(
            "localProbe: modules %1",
            Ops.get_list(target, "modules", [])
          )
        end
        # ----------------------------------------------------------
        # Partitions
        Ops.set(target, "partitions", [])
        # add constructed target map to list of all targets
        if (!notready || Builtins.search(ddevice, "/dev/dasd") == 0) &&
            Ops.greater_than(Builtins.size(target), 0)
          if is_zip
            Ops.set(@zip_drives, ddevice, target)
          else
            Ops.set(targets, ddevice, target)
            if notready && Builtins.search(ddevice, "/dev/dasd") == 0
              Ops.set(targets, [ddevice, "dasdfmt"], true)
            end
          end
        end
        Builtins.y2milestone(
          "localProbe: disk %1 tg: %2",
          ddevice,
          Ops.get(targets, ddevice, {})
        )
      end # foreach (disk)

      @zip_drives = Convert.convert(
        Builtins.union(@zip_drives, findZIPs),
        :from => "map",
        :to   => "map <string, map>"
      )

      Builtins.foreach(@zip_drives) do |k, e|
        @floppy_drives = Builtins.filter(@floppy_drives) do |f|
          Ops.get_string(f, "dev_name", "") != k
        end
      end
      Builtins.y2milestone("localProbe: FloppyDrives %1", FloppyDrives())
      Builtins.y2milestone("localProbe: ZipDrives %1", ZipDrives())

      deep_copy(targets)
    end

    # Probe ()
    # probe for target devices, return map
    # used like proposal-api
    #
    # @param boolean force_reset

    def Probe(force_reset)
      target = {}
      Builtins.y2milestone(
        "Probe force_reset:%1 disks_valid:%2",
        force_reset,
        @disks_valid
      )
      @targetMapSize = 0 if force_reset

      if @targetMapSize == 0 && @disks_valid
        target = localProbe
        @targetMapSize = Builtins.size(target)
        ProbeCDROMs()
      end
      deep_copy(target)
    end


    # Initialize

    def FullProbe
      FloppyReady() # probe floppy
      ProbeCDROMs() # probe CDs

      nil
    end

    def InitDone
      @disks_valid = true
      Builtins.y2milestone("called disks_valid %1", @disks_valid)

      nil
    end

    # Constructor

    def StorageDevices
      @disks_valid = true if !Stage.initial && !Mode.config

      nil
    end

    publish :function => :cddrives, :type => "list <map> ()"
    publish :function => :GetCdromEntry, :type => "map (string)"
    publish :function => :FloppyReady, :type => "boolean ()"
    publish :function => :ZipDrives, :type => "map <string, map> ()"
    publish :function => :FloppyPresent, :type => "boolean ()"
    publish :function => :FloppyDevice, :type => "string ()"
    publish :function => :FloppyDrives, :type => "list <map> ()"
    publish :function => :Probe, :type => "map <string, map> (boolean)"
    publish :function => :FullProbe, :type => "void ()"
    publish :function => :InitDone, :type => "void ()"
    publish :function => :StorageDevices, :type => "void ()"
  end

  StorageDevices = StorageDevicesClass.new
  StorageDevices.main
end
