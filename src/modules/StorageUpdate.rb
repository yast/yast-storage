# encoding: utf-8

# Copyright (c) [2012-2013] Novell, Inc.
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

# Module:	StorageUpdate.ycp
#
# Authors:	Thomas Fehr <fehr@suse.de>
#		Arvin Schnell <aschnell@suse.de>
require "yast"

module Yast
  class StorageUpdateClass < Module
    def main

      textdomain "storage"


      Yast.import "Arch"
      Yast.import "AsciiFile"
      Yast.import "FileSystems"
      Yast.import "Partitions"
      Yast.import "Storage"


      # flag indicates calling StorageUpdate::Update()
      @called_update = false
    end

    def UpdateFstabSubfs
      Builtins.y2milestone(
        "UpdateFstabSubfs removing fstab entries for cdrom and floppy"
      )
      tabpath = Storage.PathToDestdir("/etc/fstab")
      fstab = Partitions.GetFstab(tabpath)
      line = 0
      rem_lines = []
      while Ops.less_or_equal(line, AsciiFile.NumLines(fstab))
        l = (
          fstab_ref = arg_ref(fstab);
          _GetLine_result = AsciiFile.GetLine(fstab_ref, line);
          fstab = fstab_ref.value;
          _GetLine_result
        )
        if Builtins.search(
            Ops.get_string(l, ["fields", 1], ""),
            "/media/floppy"
          ) == 0
          rem_lines = Builtins.add(rem_lines, line)
        elsif Builtins.search(
            Ops.get_string(l, ["fields", 1], ""),
            "/media/cdrom"
          ) == 0 ||
            Builtins.search(Ops.get_string(l, ["fields", 1], ""), "/media/dvd") == 0 ||
            Builtins.search(
              Ops.get_string(l, ["fields", 1], ""),
              "/media/cdrecorder"
            ) == 0 ||
            Builtins.search(
              Ops.get_string(l, ["fields", 1], ""),
              "/media/dvdrecorder"
            ) == 0 ||
            Builtins.search(Ops.get_string(l, ["fields", 1], ""), "/cdrom") == 0 ||
            Builtins.search(Ops.get_string(l, ["fields", 1], ""), "/dvd") == 0 ||
            Builtins.search(Ops.get_string(l, ["fields", 1], ""), "/cdrecorder") == 0 ||
            Builtins.search(
              Ops.get_string(l, ["fields", 1], ""),
              "/dvdrecorder"
            ) == 0
          rem_lines = Builtins.add(rem_lines, line)
        end
        line = Ops.add(line, 1)
      end
      Builtins.y2milestone("UpdateFstabSubfs %1", rem_lines)
      if Ops.greater_than(Builtins.size(rem_lines), 0)
        rem_lines = Builtins.sort(rem_lines)
        fstab_ref = arg_ref(fstab)
        AsciiFile.RemoveLines(fstab_ref, rem_lines)
        fstab = fstab_ref.value
      end
      fstab_ref = arg_ref(fstab)
      AsciiFile.RewriteFile(fstab_ref, tabpath)
      fstab = fstab_ref.value

      nil
    end


    def UpdateFstabSysfs
      Builtins.y2milestone("UpdateFstabSysfs called")
      tabpath = Storage.PathToDestdir("/etc/fstab")
      fstab = Partitions.GetFstab(tabpath)
      line = 0
      have_sysfs = false
      while !have_sysfs && Ops.less_or_equal(line, AsciiFile.NumLines(fstab))
        l = (
          fstab_ref = arg_ref(fstab);
          _GetLine_result = AsciiFile.GetLine(fstab_ref, line);
          fstab = fstab_ref.value;
          _GetLine_result
        )
        have_sysfs = Ops.get_string(l, ["fields", 1], "") == "/sys"
        line = Ops.add(line, 1)
      end
      if !have_sysfs
        entry = FileSystems.GetFstabDefaultMap("sys")
        fstlist = [
          Ops.get_string(entry, "spec", ""),
          Ops.get_string(entry, "mount", ""),
          Ops.get_string(entry, "vfstype", ""),
          Ops.get_string(entry, "mntops", ""),
          Builtins.sformat("%1", Ops.get_integer(entry, "freq", 0)),
          Builtins.sformat("%1", Ops.get_integer(entry, "passno", 0))
        ]
        Builtins.y2milestone("UpdateFstabSysfs entry %1", entry)
        Builtins.y2milestone("UpdateFstabSysfs fstlist %1", fstlist)
        fstab_ref = arg_ref(fstab)
        AsciiFile.AppendLine(fstab_ref, fstlist)
        fstab = fstab_ref.value
        fstab_ref = arg_ref(fstab)
        AsciiFile.RewriteFile(fstab_ref, tabpath)
        fstab = fstab_ref.value
      end

      nil
    end


    def UpdateFstabHotplugOption
      Builtins.y2milestone("UpdateFstabHotplugOption")
      tabpath = Storage.PathToDestdir("/etc/fstab")
      fstab = Partitions.GetFstab(tabpath)
      line = 0
      n = ""
      while Ops.less_or_equal(line, AsciiFile.NumLines(fstab))
        l = (
          fstab_ref = arg_ref(fstab);
          _GetLine_result = AsciiFile.GetLine(fstab_ref, line);
          fstab = fstab_ref.value;
          _GetLine_result
        )
        options = Ops.get_string(l, ["fields", 3], "")
        if Builtins.regexpmatch(options, "^(.*,)?hotplug(,.*)?$")
          options = Builtins.regexpsub(
            options,
            "^(.*,)?hotplug(,.*)?$",
            "\\1nofail\\2"
          )
          fstab_ref = arg_ref(fstab)
          AsciiFile.ChangeLineField(fstab_ref, line, 3, options)
          fstab = fstab_ref.value
        end
        line = Ops.add(line, 1)
      end
      fstab_ref = arg_ref(fstab)
      AsciiFile.RewriteFile(fstab_ref, tabpath)
      fstab = fstab_ref.value

      nil
    end


    def UpdateFstabPersistentNames
      Builtins.y2milestone(
        "UpdateFstabPersistentDevNames updating to SLES10 names"
      )
      tabpath = Storage.PathToDestdir("/etc/fstab")
      fstab = Partitions.GetFstab(tabpath)
      line = 0
      n = ""
      while Ops.less_or_equal(line, AsciiFile.NumLines(fstab))
        l = (
          fstab_ref = arg_ref(fstab);
          _GetLine_result = AsciiFile.GetLine(fstab_ref, line);
          fstab = fstab_ref.value;
          _GetLine_result
        )
        n = Storage.SLES9PersistentDevNames(
          Ops.get_string(l, ["fields", 0], "")
        )
        if n != Ops.get_string(l, ["fields", 0], "")
          fstab_ref = arg_ref(fstab)
          AsciiFile.ChangeLineField(fstab_ref, line, 0, n)
          fstab = fstab_ref.value
        end
        line = Ops.add(line, 1)
      end
      fstab_ref = arg_ref(fstab)
      AsciiFile.RewriteFile(fstab_ref, tabpath)
      fstab = fstab_ref.value

      nil
    end


    def UpdateMdadm
      Builtins.y2milestone("UpdateMdadm")
      cpath = Storage.PathToDestdir("/etc/mdadm.conf")
      file = {}
      file_ref = arg_ref(file)
      AsciiFile.SetComment(file_ref, "^[ \t]*#")
      file = file_ref.value
      file_ref = arg_ref(file)
      AsciiFile.ReadFile(file_ref, cpath)
      file = file_ref.value
      line = 0
      changed = false
      while Ops.less_or_equal(line, AsciiFile.NumLines(file))
        if Builtins.search(
            Ops.get_string(file, ["l", line, "line"], ""),
            "DEVICE"
          ) != nil &&
            Builtins.search(
              Ops.get_string(file, ["l", line, "line"], ""),
              "/dev/"
            ) != nil
          changed = true
          Ops.set(file, ["l", line, "line"], "DEVICE partitions")
          Builtins.y2milestone(
            "UpdateMdadm %1",
            Ops.get_map(file, ["l", line], {})
          )
        end
        line = Ops.add(line, 1)
      end
      if changed
        file_ref = arg_ref(file)
        AsciiFile.RewriteFile(file_ref, cpath)
        file = file_ref.value
      end

      nil
    end


    def UpdateFstabDiskmap(diskmap)
      diskmap = deep_copy(diskmap)
      Builtins.y2milestone("UpdateFstabDiskmap map %1", diskmap)
      tabpath = Storage.PathToDestdir("/etc/fstab")
      fstab = Partitions.GetFstab(tabpath)
      line = 0
      n = ""
      while Ops.less_or_equal(line, AsciiFile.NumLines(fstab))
        l = (
          fstab_ref = arg_ref(fstab);
          _GetLine_result = AsciiFile.GetLine(fstab_ref, line);
          fstab = fstab_ref.value;
          _GetLine_result
        )
        n = Storage.HdDiskMap(Ops.get_string(l, ["fields", 0], ""), diskmap)
        if n != Ops.get_string(l, ["fields", 0], "")
          fstab_ref = arg_ref(fstab)
          AsciiFile.ChangeLineField(fstab_ref, line, 0, n)
          fstab = fstab_ref.value
        end
        line = Ops.add(line, 1)
      end
      fstab_ref = arg_ref(fstab)
      AsciiFile.RewriteFile(fstab_ref, tabpath)
      fstab = fstab_ref.value
      tabpath = Storage.PathToDestdir("/etc/cryptotab")
      crtab = Partitions.GetCrypto(tabpath)
      line = 0
      while Ops.less_or_equal(line, AsciiFile.NumLines(crtab))
        l = (
          crtab_ref = arg_ref(crtab);
          _GetLine_result = AsciiFile.GetLine(crtab_ref, line);
          crtab = crtab_ref.value;
          _GetLine_result
        )
        n = Storage.HdDiskMap(Ops.get_string(l, ["fields", 1], ""), diskmap)
        if n != Ops.get_string(l, ["fields", 1], "")
          crtab_ref = arg_ref(crtab)
          AsciiFile.ChangeLineField(crtab_ref, line, 1, n)
          crtab = crtab_ref.value
        end
        line = Ops.add(line, 1)
      end
      crtab_ref = arg_ref(crtab)
      AsciiFile.RewriteFile(crtab_ref, tabpath)
      crtab = crtab_ref.value

      nil
    end


    def UpdateFstabUsbdevfs
      Builtins.y2milestone("UpdateFstabUsbdevfs updating usbdevfs to usbfs")
      changed = false
      tabpath = Storage.PathToDestdir("/etc/fstab")
      fstab = Partitions.GetFstab(tabpath)
      line = 0
      while Ops.less_or_equal(line, AsciiFile.NumLines(fstab))
        l = (
          fstab_ref = arg_ref(fstab);
          _GetLine_result = AsciiFile.GetLine(fstab_ref, line);
          fstab = fstab_ref.value;
          _GetLine_result
        )
        if Ops.get_string(l, ["fields", 2], "") == "usbdevfs"
          fstab_ref = arg_ref(fstab)
          AsciiFile.ChangeLineField(fstab_ref, line, 2, "usbfs")
          fstab = fstab_ref.value
          fstab_ref = arg_ref(fstab)
          AsciiFile.ChangeLineField(fstab_ref, line, 0, "usbfs")
          fstab = fstab_ref.value
          changed = true
        end
        line = Ops.add(line, 1)
      end
      if changed
        Builtins.y2milestone("UpdateFstabUsbdevfs changed")
        fstab_ref = arg_ref(fstab)
        AsciiFile.RewriteFile(fstab_ref, tabpath)
        fstab = fstab_ref.value
      end

      nil
    end


    def UpdateFstabIseriesVd
      Builtins.y2milestone("UpdateFstabIseriesVd updating hdx to iseries/vdx")
      tabpath = Storage.PathToDestdir("/etc/fstab")
      fstab = Partitions.GetFstab(tabpath)
      line = 0
      n = ""
      while Ops.less_or_equal(line, AsciiFile.NumLines(fstab))
        l = (
          fstab_ref = arg_ref(fstab);
          _GetLine_result = AsciiFile.GetLine(fstab_ref, line);
          fstab = fstab_ref.value;
          _GetLine_result
        )
        n = Storage.HdToIseries(Ops.get_string(l, ["fields", 0], ""))
        if n != Ops.get_string(l, ["fields", 0], "")
          fstab_ref = arg_ref(fstab)
          AsciiFile.ChangeLineField(fstab_ref, line, 0, n)
          fstab = fstab_ref.value
        end
        line = Ops.add(line, 1)
      end
      fstab_ref = arg_ref(fstab)
      AsciiFile.RewriteFile(fstab_ref, tabpath)
      fstab = fstab_ref.value
      tabpath = Storage.PathToDestdir("/etc/cryptotab")
      crtab = Partitions.GetCrypto(tabpath)
      line = 0
      while Ops.less_or_equal(line, AsciiFile.NumLines(crtab))
        l = (
          crtab_ref = arg_ref(crtab);
          _GetLine_result = AsciiFile.GetLine(crtab_ref, line);
          crtab = crtab_ref.value;
          _GetLine_result
        )
        n = Storage.HdToIseries(Ops.get_string(l, ["fields", 1], ""))
        if n != Ops.get_string(l, ["fields", 1], "")
          crtab_ref = arg_ref(crtab)
          AsciiFile.ChangeLineField(crtab_ref, line, 1, n)
          crtab = crtab_ref.value
        end
        line = Ops.add(line, 1)
      end
      crtab_ref = arg_ref(crtab)
      AsciiFile.RewriteFile(crtab_ref, tabpath)
      crtab = crtab_ref.value

      nil
    end


    def UpdateCryptoType
      Builtins.y2milestone("UpdateCryptoType")
      tabpath = Storage.PathToDestdir("/etc/fstab")
      fstab = Partitions.GetFstab(tabpath)
      line = 0
      pos = 0
      searchstr = "encryption=twofish256"
      while Ops.less_or_equal(line, AsciiFile.NumLines(fstab))
        l = (
          fstab_ref = arg_ref(fstab);
          _GetLine_result = AsciiFile.GetLine(fstab_ref, line);
          fstab = fstab_ref.value;
          _GetLine_result
        )
        pos = Builtins.search(Ops.get_string(l, ["fields", 3], ""), searchstr)
        if pos != nil
          new = Builtins.substring(Ops.get_string(l, ["fields", 3], ""), 0, pos)
          new = Ops.add(new, "encryption=twofishSL92")
          new = Ops.add(
            new,
            Builtins.substring(
              Ops.get_string(l, ["fields", 3], ""),
              Ops.add(pos, Builtins.size(searchstr))
            )
          )
          Builtins.y2milestone("new options line in %1 is %2", l, new)
          fstab_ref = arg_ref(fstab)
          AsciiFile.ChangeLineField(fstab_ref, line, 3, new)
          fstab = fstab_ref.value
        end
        line = Ops.add(line, 1)
      end
      fstab_ref = arg_ref(fstab)
      AsciiFile.RewriteFile(fstab_ref, tabpath)
      fstab = fstab_ref.value
      tabpath = Storage.PathToDestdir("/etc/cryptotab")
      crtab = Partitions.GetCrypto(tabpath)
      line = 0
      while Ops.less_or_equal(line, AsciiFile.NumLines(crtab))
        l = (
          crtab_ref = arg_ref(crtab);
          _GetLine_result = AsciiFile.GetLine(crtab_ref, line);
          crtab = crtab_ref.value;
          _GetLine_result
        )
        if Ops.get_string(l, ["fields", 4], "") == "twofish256"
          Builtins.y2milestone("set twofishSL92 in line %1", l)
          crtab_ref = arg_ref(crtab)
          AsciiFile.ChangeLineField(crtab_ref, line, 4, "twofishSL92")
          crtab = crtab_ref.value
        end
        line = Ops.add(line, 1)
      end
      crtab_ref = arg_ref(crtab)
      AsciiFile.RewriteFile(crtab_ref, tabpath)
      crtab = crtab_ref.value

      nil
    end

    def UpdateFstabCryptNofail
      Builtins.y2milestone("UpdateFstabCryptNofail called")
      tabpath = Storage.PathToDestdir("/etc/fstab")
      fstab = Partitions.GetFstab(tabpath)
      line = 0
      update = false
      while Ops.less_or_equal(line, AsciiFile.NumLines(fstab))
        l = (
          fstab_ref = arg_ref(fstab);
          _GetLine_result = AsciiFile.GetLine(fstab_ref, line);
          fstab = fstab_ref.value;
          _GetLine_result
        )
        if Builtins.search(
            Ops.get_string(l, ["fields", 0], ""),
            "/dev/mapper/cr_"
          ) == 0
          ls = Builtins.splitstring(Ops.get_string(l, ["fields", 3], ""), ",")
          ls = Builtins.filter(ls) { |s| s != "noauto" }
          if Builtins.size(Builtins.filter(ls) { |s| s == "nofail" }) == 0
            ls = Builtins.add(ls, "nofail")
            fstab_ref = arg_ref(fstab)
            AsciiFile.ChangeLineField(
              fstab_ref,
              line,
              3,
              Builtins.mergestring(ls, ",")
            )
            fstab = fstab_ref.value
            update = true
          end
        end
        line = Ops.add(line, 1)
      end
      if update
        fstab_ref = arg_ref(fstab)
        AsciiFile.RewriteFile(fstab_ref, tabpath)
        fstab = fstab_ref.value
      end

      nil
    end

    def UpdateFstabWindowsMounts
      Builtins.y2milestone("UpdateFstabWindowsMounts called")
      tabpath = Storage.PathToDestdir("/etc/fstab")
      fstab = Partitions.GetFstab(tabpath)
      rem_lines = []
      line = 0
      while Ops.less_or_equal(line, AsciiFile.NumLines(fstab))
        l = (
          fstab_ref = arg_ref(fstab);
          _GetLine_result = AsciiFile.GetLine(fstab_ref, line);
          fstab = fstab_ref.value;
          _GetLine_result
        )
        if Builtins.search(Ops.get_string(l, ["fields", 1], ""), "/windows/") == 0 &&
            Builtins.size(Ops.get_string(l, ["fields", 1], "")) == 10 ||
            Builtins.search(Ops.get_string(l, ["fields", 1], ""), "/dos/") == 0 &&
              Builtins.size(Ops.get_string(l, ["fields", 1], "")) == 6
          rem_lines = Builtins.add(rem_lines, line)
        end
        line = Ops.add(line, 1)
      end
      if Ops.greater_than(Builtins.size(rem_lines), 0)
        rem_lines = Builtins.sort(rem_lines)
        Builtins.y2milestone("UpdateFstabWindowsMounts %1", rem_lines)
        fstab_ref = arg_ref(fstab)
        AsciiFile.RemoveLines(fstab_ref, rem_lines)
        fstab = fstab_ref.value
        fstab_ref = arg_ref(fstab)
        AsciiFile.RewriteFile(fstab_ref, tabpath)
        fstab = fstab_ref.value
      end

      nil
    end

    def UpdateFstabRemoveSystemdMps
      Builtins.y2milestone("UpdateFstabRemoveSystemdMps called")
      tabpath = Storage.PathToDestdir("/etc/fstab")
      fstab = Partitions.GetFstab(tabpath)
      rem_lines = []
      rem_dirs = [
        "/proc",
        "/sys",
        "/sys/kernel/debug",
        "/dev/pts",
        "/proc/bus/usb"
      ]
      line = 0
      while Ops.less_or_equal(line, AsciiFile.NumLines(fstab))
        l = (
          fstab_ref = arg_ref(fstab);
          _GetLine_result = AsciiFile.GetLine(fstab_ref, line);
          fstab = fstab_ref.value;
          _GetLine_result
        )
        if Builtins.contains(rem_dirs, Ops.get_string(l, ["fields", 1], ""))
          rem_lines = Builtins.add(rem_lines, line)
        end
        line = Ops.add(line, 1)
      end
      if Ops.greater_than(Builtins.size(rem_lines), 0)
        rem_lines = Builtins.sort(rem_lines)
        Builtins.y2milestone("UpdateFstabRemoveSystemdMps %1", rem_lines)
        fstab_ref = arg_ref(fstab)
        AsciiFile.RemoveLines(fstab_ref, rem_lines)
        fstab = fstab_ref.value
        fstab_ref = arg_ref(fstab)
        AsciiFile.RewriteFile(fstab_ref, tabpath)
        fstab = fstab_ref.value
      end

      nil
    end


    def UpdateFstabDmraidToMdadm()
      Builtins.y2milestone("UpdateFstabDmraidToMdadm")

      mapping = Storage.GetDmraidToMdadm()
      if mapping.empty?
        return
      end

      fstab_path = Storage.PathToDestdir("/etc/fstab")
      fstab = Partitions.GetFstab(fstab_path)

      for line in 1..AsciiFile.NumLines(fstab)
        l = (
          fstab_ref = arg_ref(fstab);
          _GetLine_result = AsciiFile.GetLine(fstab_ref, line);
          fstab = fstab_ref.value;
          _GetLine_result
        )

        device = Ops.get_string(l, ["fields", 0], "")

        device = Storage.TranslateDeviceDmraidToMdadm(device, mapping)

        if device != Ops.get_string(l, ["fields", 0], "")
          fstab_ref = arg_ref(fstab)
          AsciiFile.ChangeLineField(fstab_ref, line, 0, device)
          fstab = fstab_ref.value
        end
      end

      fstab_ref = arg_ref(fstab)
      AsciiFile.RewriteFile(fstab_ref, fstab_path)
      fstab = fstab_ref.value

      crtab_path = Storage.PathToDestdir("/etc/cryptotab")
      crtab = Partitions.GetCrypto(crtab_path)

      for line in 1..AsciiFile.NumLines(crtab)
        l = (
          crtab_ref = arg_ref(crtab);
          _GetLine_result = AsciiFile.GetLine(crtab_ref, line);
          crtab = crtab_ref.value;
          _GetLine_result
        )

        device = Ops.get_string(l, ["fields", 1], "")

        device = Storage.TranslateDeviceDmraidToMdadm(device, mapping)

        if device != Ops.get_string(l, ["fields", 1], "")
          crtab_ref = arg_ref(crtab)
          AsciiFile.ChangeLineField(crtab_ref, line, 1, device)
          crtab = crtab_ref.value
        end
      end

      crtab_ref = arg_ref(crtab)
      AsciiFile.RewriteFile(crtab_ref, crtab_path)
      crtab = crtab_ref.value

      return
    end


    # Updates fstab on disk
    #
    # @param map old version
    # @param map new version
    #
    #
    # **Structure:**
    #
    #     version $[
    #        // This means version 9.1
    #        "major" : 9,
    #        "minor" : 1,
    #      ]
    def Update(oldv, newv)
      oldv = deep_copy(oldv)
      newv = deep_copy(newv)
      if !@called_update
        Builtins.y2milestone("Update old:%1 new:%2", oldv, newv)

        # Enterprise products do not have minor release number
        # map enterprise releases to corresponding code bases of SL
        sles_major_to_minor = { 8 => 2, 9 => 1, 10 => 1 }
        if Builtins.haskey(oldv, "major") && !Builtins.haskey(oldv, "minor")
          Ops.set(
            oldv,
            "minor",
            Ops.get_integer(
              sles_major_to_minor,
              Ops.get_integer(oldv, "major", 0),
              0
            )
          )
          Builtins.y2milestone("Update old:%1", oldv)
        end
        if Builtins.haskey(newv, "major") && !Builtins.haskey(newv, "minor")
          Ops.set(
            newv,
            "minor",
            Ops.get_integer(
              sles_major_to_minor,
              Ops.get_integer(newv, "major", 0),
              0
            )
          )
          Builtins.y2milestone("Update new:%1", newv)
        end
        if !Builtins.haskey(oldv, "major") || !Builtins.haskey(newv, "major")
          Builtins.y2error("Missing key major or minor")
        end

        if Ops.less_or_equal(Ops.get_integer(oldv, "major", 0), 9)
          UpdateFstabSysfs()
        end
        if Ops.less_than(Ops.get_integer(oldv, "major", 0), 9)
          UpdateFstabUsbdevfs()
        end
        UpdateFstabPersistentNames() if Ops.get_integer(oldv, "major", 0) == 9

        if Ops.less_or_equal(Ops.get_integer(oldv, "major", 0), 10)
          UpdateFstabHotplugOption()
        end

        UpdateFstabDmraidToMdadm()

        dm = Storage.BuildDiskmap(oldv)
        if Ops.greater_than(Builtins.size(dm), 0)
          UpdateFstabDiskmap(dm)
          UpdateMdadm()
        end
        if Ops.less_than(Ops.get_integer(oldv, "major", 0), 9) ||
            Ops.get_integer(oldv, "major", 0) == 9 &&
              Ops.less_or_equal(Ops.get_integer(oldv, "minor", 0), 2)
          UpdateCryptoType()
        end
        if Ops.less_than(Ops.get_integer(oldv, "major", 0), 10) ||
            Ops.get_integer(oldv, "major", 0) == 10 &&
              Ops.get_integer(oldv, "minor", 0) == 0
          of = "/etc/udev/rules.d/20-cdrom.rules"
          Builtins.y2milestone("removing obsolete %1", of)
          SCR.Execute(path(".target.remove"), of)
          of = "/etc/udev/rules.d/55-cdrom.rules"
          Builtins.y2milestone("removing obsolete %1", of)
          SCR.Execute(path(".target.remove"), of)
        end
        if Ops.less_than(Ops.get_integer(oldv, "major", 0), 10) ||
            Ops.get_integer(oldv, "major", 0) == 10 &&
              Ops.less_or_equal(Ops.get_integer(oldv, "minor", 0), 2)
          of = "/etc/udev/rules.d/65-cdrom.rules"
          Builtins.y2milestone("removing obsolete %1", of)
          SCR.Execute(path(".target.remove"), of)
        end
        if Ops.less_than(Ops.get_integer(oldv, "major", 0), 10) ||
            Ops.get_integer(oldv, "major", 0) == 10 &&
              Ops.get_integer(oldv, "minor", 0) == 0
          UpdateFstabSubfs()
        end
        if Ops.less_than(Ops.get_integer(oldv, "major", 0), 9) ||
            Ops.get_integer(oldv, "major", 0) == 9 &&
              Ops.get_integer(oldv, "minor", 0) == 0
          UpdateFstabIseriesVd() if Arch.board_iseries
        end
        if Ops.less_than(Ops.get_integer(oldv, "major", 0), 10) ||
            Ops.get_integer(oldv, "major", 0) == 10 &&
              Ops.less_or_equal(Ops.get_integer(oldv, "minor", 0), 2)
          cmd = "cd / && /sbin/insserv /etc/init.d/boot.crypto"
          bo = Convert.to_map(SCR.Execute(path(".target.bash_output"), cmd))
          Builtins.y2milestone("Update bo %1", bo)

          cmd = "cd / && /sbin/insserv /etc/init.d/boot.crypto-early"
          bo = Convert.to_map(SCR.Execute(path(".target.bash_output"), cmd))
          Builtins.y2milestone("Update bo %1", bo)
        end
        if Ops.less_than(Ops.get_integer(oldv, "major", 0), 11) ||
            Ops.get_integer(oldv, "major", 0) == 11 &&
              Ops.less_or_equal(Ops.get_integer(oldv, "minor", 0), 2)
          UpdateFstabCryptNofail()
        end
        # 	    if( oldv["major"]:0<=11 || (oldv["major"]:0==12 && oldv["minor"]:0<=1))
        # 		UpdateFstabWindowsMounts();
        if Ops.less_than(Ops.get_integer(oldv, "major", 0), 13)
          UpdateFstabRemoveSystemdMps()
        end
        # set flag -> it indicates that Update was already called
        @called_update = true
      else
        Builtins.y2milestone("Skip calling Update() -> It was already called")
      end

      nil
    end

    publish :function => :UpdateFstabHotplugOption, :type => "void ()"
    publish :function => :Update, :type => "void (map, map)"
  end

  StorageUpdate = StorageUpdateClass.new
  StorageUpdate.main
end
