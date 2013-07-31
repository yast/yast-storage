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
  module PartitioningEpImportInclude
    def initialize_partitioning_ep_import(include_target)
      textdomain "storage"


      Yast.import "Directory"
      Yast.import "FileSystems"
      Yast.import "Label"
      Yast.import "Popup"
      Yast.import "Storage"
      Yast.import "StorageFields"
      Yast.import "StorageSettings"
    end

    def MountVar(var, root, rdev, mp, target_map)
      var = deep_copy(var)
      root = deep_copy(root)
      target_map = deep_copy(target_map)
      ret = ""
      mount_success = false
      Builtins.y2milestone(
        "MountVar rdev:%1 mp:%2 var:%3 root:%4",
        rdev,
        mp,
        var,
        root
      )
      if Ops.greater_than(Ops.get_integer(var, "size_k", 0), 0)
        ret = Ops.get_string(var, "device", "")
      else
        ds = Builtins.maplist(target_map) { |d, disk| d }
        Builtins.y2milestone("MountVar ds:%1", ds)
        ds = Builtins.filter(ds) do |d|
          Ops.get_symbol(target_map, [d, "type"], :CT_UNKNOWN) == :CT_DISK
        end
        Builtins.y2milestone("MountVar ds:%1", ds)
        rootm = Storage.GetDiskPartition(rdev)
        rootf = Storage.GetDiskPartition(Ops.get_string(root, "device", ""))
        varf = Storage.GetDiskPartition(Ops.get_string(var, "device", ""))
        if Ops.get_string(rootf, "disk", "") == Ops.get_string(varf, "disk", "")
          ret = Storage.GetDeviceName(
            Ops.get_string(rootm, "disk", ""),
            Ops.get(varf, "nr", 0)
          )
        elsif Builtins.size(ds) == 1
          ret = Storage.GetDeviceName(
            Ops.get(ds, 0, ""),
            Ops.get(varf, "nr", 0)
          )
        elsif Ops.greater_than(Builtins.size(ds), 1)
          i = 0
          while Ops.less_than(i, Builtins.size(ds)) && Builtins.isempty(ret)
            ret = Storage.GetDeviceName(
              Ops.get(ds, i, ""),
              Ops.get(varf, "nr", 0)
            )
            if !Builtins.isempty(Storage.GetPartition(target_map, ret)) &&
                Storage.Mount(ret, mp)
              d = Convert.to_map(
                SCR.Read(path(".target.stat"), Ops.add(mp, "/lib/hardware"))
              )
              Builtins.y2milestone("MountVar d:%1", d)
              ret = "" if !Ops.get_boolean(d, "isdir", false)
              Storage.Umount(ret, false)
            else
              ret = ""
            end
            i = Ops.add(i, 1)
          end
        end
      end
      ret = "" if !Builtins.isempty(ret) && !Storage.Mount(ret, mp)
      Builtins.y2milestone("MountVar ret:%1", ret)
      ret
    end


    # Find and read fstab by installation. Scan existing partitions.
    # @parm target_map all targets
    # @parm search_point mount point where partitions can be mounted
    # @return [Hash{String => Array}] map with device and fstab data found
    def FindExistingFstabs(target_map, search_point)
      target_map = deep_copy(target_map)
      fstabs = {}

      Builtins.foreach(target_map) do |disk_device, disk|
        partitions = Builtins.filter(Ops.get_list(disk, "partitions", [])) do |part|
          Builtins.contains(
            FileSystems.possible_root_fs,
            Ops.get_symbol(part, "detected_fs", :unknown)
          )
        end
        Builtins.foreach(partitions) do |part|
          part_device = Ops.get_string(part, "device", "")
          # try to mount
          mount_success = Storage.Mount(part_device, search_point)
          if mount_success &&
              Ops.greater_than(
                SCR.Read(
                  path(".target.size"),
                  Ops.add(search_point, "/etc/fstab")
                ),
                0
              )
            fstab = Storage.ReadFstab(Ops.add(search_point, "/etc"))
            Builtins.y2milestone("FindExistingFstabs fstab:%1", fstab)
            if !Builtins.isempty(fstab)
              if Builtins.find(fstab) do |p|
                  Ops.get_integer(p, "size_k", 0) == 0
                end != nil
                vardev = ""
                var = Builtins.find(fstab) do |p|
                  Ops.get_string(p, "mount", "") == "/var"
                end
                root = Builtins.find(fstab) do |p|
                  Ops.get_string(p, "mount", "") == "/"
                end
                Builtins.y2milestone("FindExistingFstabs var:%1", var)
                if var != nil
                  vardev = MountVar(
                    var,
                    root,
                    part_device,
                    Ops.add(search_point, "/var"),
                    target_map
                  )
                  Builtins.y2milestone("FindExistingFstabs vardev:%1", vardev)
                end
                dmap = Storage.BuildDiskmap({})
                if !Builtins.isempty(dmap)
                  Builtins.y2milestone("FindExistingFstabs dmap:%1", dmap)
                  Builtins.y2milestone("FindExistingFstabs fstab:%1", fstab)
                  fstab = Builtins.maplist(fstab) do |p|
                    if Ops.get_integer(p, "size_k", 0) == 0
                      Ops.set(
                        p,
                        "device",
                        Storage.HdDiskMap(Ops.get_string(p, "device", ""), dmap)
                      )
                    end
                    deep_copy(p)
                  end
                  Builtins.y2milestone("FindExistingFstabs fstab:%1", fstab)
                end
                s = Builtins.size(fstab)
                fstab = Builtins.filter(fstab) { |p| Storage.CanEdit(p, false) }
                if s != Builtins.size(fstab)
                  Builtins.y2milestone("FindExistingFstabs fstab:%1", fstab)
                end
                Storage.Umount(vardev, false) if !Builtins.isempty(vardev)
              end

              Ops.set(fstabs, part_device, fstab) if !Builtins.isempty(fstab)
            end
          end
          # unmount
          Storage.Umount(part_device, false) if mount_success
        end
      end
      Builtins.y2milestone(
        "FindExistingFstabs size(fstabs):%1",
        Builtins.size(fstabs)
      )
      Builtins.y2milestone("FindExistingFstabs fstabs:%1", fstabs)
      deep_copy(fstabs)
    end


    # Scan and Read and return fstabs.
    # @parm target_map all targets
    # @return [Hash{String => Array}] map with device and fstab data found
    def ScanAndReadExistingFstabs(target_map)
      target_map = deep_copy(target_map)
      search_point = Ops.add(Directory.tmpdir, "/tmp-mp")

      if !Ops.get_boolean(
          Convert.to_map(SCR.Read(path(".target.stat"), search_point)),
          "isdir",
          false
        )
        SCR.Execute(path(".target.mkdir"), search_point)
      end

      fstabs = FindExistingFstabs(target_map, search_point)

      deep_copy(fstabs)
    end


    # Merge fstab with target_map.
    def AddFstabToTargetMap(target_map, fstab, format_sys)
      target_map = deep_copy(target_map)
      fstab = deep_copy(fstab)
      Builtins.y2milestone("AddFstabToTargetMap fstab:%1", fstab)

      new_target_map = Builtins.mapmap(target_map) do |disk_device, disk|
        Ops.set(
          disk,
          "partitions",
          Builtins.maplist(Ops.get_list(disk, "partitions", [])) do |partition|
            part_device = Ops.get_string(partition, "device", "")
            if !Storage.IsInstallationSource(part_device)
              Builtins.foreach(fstab) do |fstab_entry|
                dev_fstab = Ops.get_string(fstab_entry, "device", "")
                mount_fstab = Ops.get_string(fstab_entry, "mount", "")
                if dev_fstab == part_device
                  Ops.set(partition, "mount", mount_fstab)
                  if format_sys && FileSystems.IsSystemMp(mount_fstab, false) &&
                      mount_fstab != "/boot/efi"
                    Ops.set(partition, "format", true)
                  end
                  if format_sys && Ops.get_string(partition, "mount", "") == "/" &&
                      Ops.get_symbol(partition, "detected_fs", :unknown) == :BTRFS
                    partition = Storage.AddSubvolRoot(partition)
                  end
                  if !Builtins.isempty(
                      Ops.get_string(fstab_entry, "fstopt", "")
                    ) &&
                      Ops.get_string(fstab_entry, "fstopt", "") != "default"
                    Ops.set(
                      partition,
                      "fstopt",
                      Ops.get_string(fstab_entry, "fstopt", "")
                    )
                  end
                  if Ops.get_symbol(fstab_entry, "mountby", :device) != :device
                    Ops.set(
                      partition,
                      "mountby",
                      Ops.get_symbol(fstab_entry, "mountby", :device)
                    )
                  end
                  if Ops.get_symbol(fstab_entry, "enc_type", :none) != :none
                    Ops.set(
                      partition,
                      "enc_type",
                      Ops.get_symbol(fstab_entry, "enc_type", :none)
                    )
                  end
                end
              end
            end
            deep_copy(partition)
          end
        )
        { disk_device => disk }
      end

      Builtins.y2milestone(
        "AddFstabToTargetMap new_target_map:%1",
        new_target_map
      )

      deep_copy(new_target_map)
    end


    def FstabAddDialogHelptext
      # help text, richtext format
      helptext = _(
        "<p>YaST has scanned your hard disks and found one or several existing \n" +
          "Linux systems with mount points. The old mount points are shown in \n" +
          "the table.</p>\n"
      )

      # help text, richtext format
      helptext = Ops.add(
        helptext,
        _(
          "<p>You can choose whether the existing system\n" +
            "volumes, e.g. / and /usr, will be formatted during the\n" +
            "installation. Non-system volumes, e.g. /home, will not be formatted.</p>"
        )
      )

      helptext
    end


    # Scan exiting partitions for fstab files and if one found read the mountpoints
    # from the fstab file and build a new target_map.
    # Ask the user if he like to use the new or old target_map
    # (with or without found mountpoints)
    def FstabAddDialog(target_map, fstabs, format_sys)
      target_map = deep_copy(target_map)
      fstabs = deep_copy(fstabs)
      Builtins.y2milestone("FstabAddDialog target_map:%1", target_map)
      Builtins.y2milestone("FstabAddDialog fstabs:%1", fstabs)

      if Builtins.isempty(fstabs)
        # popup text
        Popup.Message(_("No previous system with mount points was detected."))
        return ""
      end

      devices = Builtins.maplist(fstabs) { |device2, fstab| device2 }

      fields = StorageSettings.FilterTable(
        [:device, :size, :type, :fs_type, :label, :mount_point]
      )

      table_header = StorageFields.TableHeader(fields)

      navigate_buttons = Empty()
      if Ops.greater_than(Builtins.size(fstabs), 1)
        navigate_buttons = HBox(
          PushButton(Id(:show_prev), _("Show &Previous")),
          PushButton(Id(:show_next), _("Show &Next"))
        )
      end

      UI.OpenDialog(
        Opt(:decorated),
        VBox(
          VSpacing(0.45),
          # dialog heading
          Left(Heading(_("Import Mount Points from Existing System:"))),
          MarginBox(
            1,
            0.5,
            VBox(
              Left(ReplacePoint(Id(:device), Empty())),
              MinSize(
                60,
                8,
                Table(Id(:table), Opt(:keepSorting), table_header, [])
              ),
              VSpacing(0.45),
              navigate_buttons,
              VSpacing(0.45),
              # checkbox label
              Left(CheckBox(Id(:format_sys), _("Format System Volumes"), true))
            )
          ),
          ButtonBox(
            PushButton(Id(:help), Opt(:helpButton), Label.HelpButton),
            # pushbutton label
            PushButton(Id(:ok), Opt(:default), _("Import")),
            PushButton(Id(:cancel), Label.CancelButton)
          )
        )
      )

      UI.ChangeWidget(:help, :HelpText, FstabAddDialogHelptext())

      userinput = :none
      idx = 0
      begin
        device2 = Ops.get(devices, idx, "")

        fstab = Convert.convert(
          Ops.get(fstabs, device2, []),
          :from => "list",
          :to   => "list <map>"
        )

        new_target_map = AddFstabToTargetMap(
          target_map,
          fstab,
          format_sys.value
        )

        # popup text %1 is replaced by a device name (e.g. /dev/hda1)
        str = Builtins.sformat(_("/etc/fstab found on %1 contains:"), device2)
        UI.ReplaceWidget(Id(:device), Label(str))

        table_contents = StorageFields.TableContents(
          fields,
          new_target_map,
          fun_ref(
            StorageFields.method(:PredicateMountpoint),
            "symbol (map, map)"
          )
        )
        UI.ChangeWidget(Id(:table), :Items, table_contents)
        UI.ChangeWidget(Id(:table), :CurrentItem, nil)

        if Ops.greater_than(Builtins.size(fstabs), 1)
          UI.ChangeWidget(Id(:show_prev), :Enabled, Ops.greater_than(idx, 0))
          UI.ChangeWidget(
            Id(:show_next),
            :Enabled,
            Ops.less_than(idx, Ops.subtract(Builtins.size(fstabs), 1))
          )
        end

        userinput = Convert.to_symbol(UI.UserInput)

        case userinput
          when :show_next
            idx = Ops.add(idx, 1)
          when :show_prev
            idx = Ops.subtract(idx, 1)
        end
        Builtins.y2milestone("idx %1", idx)
      end until userinput == :ok || userinput == :cancel

      format_sys.value = Convert.to_boolean(
        UI.QueryWidget(Id(:format_sys), :Value)
      )

      UI.CloseDialog

      device = userinput == :ok ? Ops.get(devices, idx, "") : ""
      Builtins.y2milestone("FstabAddDialog device:%1", device)
      device
    end


    def ImportMountPoints
      Storage.CreateTargetBackup("import")
      Storage.ResetOndiskTarget

      target_map = Storage.GetOndiskTarget

      fstabs = ScanAndReadExistingFstabs(target_map)
      Builtins.y2milestone("ImportMountPoints fstabs:%1", fstabs)

      format_sys = true
      device = (
        format_sys_ref = arg_ref(format_sys);
        _FstabAddDialog_result = FstabAddDialog(
          target_map,
          fstabs,
          format_sys_ref
        );
        format_sys = format_sys_ref.value;
        _FstabAddDialog_result
      )
      new_target_map = {}
      import_ok = false
      if !Builtins.isempty(device)
        Builtins.y2milestone("ImportMountPoints device:%1", device)
        fstab = Convert.convert(
          Ops.get(fstabs, device, []),
          :from => "list",
          :to   => "list <map>"
        )
        import_ok = true

        new_target_map = AddFstabToTargetMap(target_map, fstab, format_sys)

        Builtins.foreach(new_target_map) do |d, disk|
          Builtins.foreach(Ops.get_list(disk, "partitions", [])) do |p|
            key = Ops.get_symbol(p, "type", :unknown) != :loop ?
              Ops.get_string(p, "device", "error") :
              Ops.get_string(p, "fpath", "error")
            if !Builtins.isempty(Ops.get_string(p, "mount", "")) &&
                Ops.get_symbol(p, "enc_type", :none) != :none &&
                !Ops.get_boolean(p, "tmpcrypt", false) &&
                Storage.NeedCryptPwd(key)
              ok = false
              dev = Ops.get_string(p, "device", "")
              pwd = ""
              begin
                ok = false
                pwd = DlgPasswdCryptFs(dev, 1, false, false)
                if pwd != nil && !Builtins.isempty(pwd)
                  if Storage.CheckCryptOk(dev, pwd, true, false)
                    ok = Storage.SetCryptPwd(dev, pwd) &&
                      Storage.SetCrypt(dev, true, false)
                  else
                    Popup.Error(_("Wrong Password Provided."))
                  end
                elsif Builtins.size(pwd) == 0
                  ok = true
                  import_ok = false
                end
              end while !ok
            end
          end
        end
      end
      if import_ok
        Storage.SetTargetMap(new_target_map)
      else
        Storage.RestoreTargetBackup("import")
      end

      Storage.DisposeTargetBackup("import")

      nil
    end
  end
end
