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
  module PartitioningEpLibInclude
    def initialize_partitioning_ep_lib(include_target)
      textdomain "storage"
    end

    def AddedToList(old, new)
      old = deep_copy(old)
      new = deep_copy(new)
      Builtins::Multiset.difference(Builtins.sort(new), Builtins.sort(old))
    end


    def RemovedFromList(old, new)
      old = deep_copy(old)
      new = deep_copy(new)
      Builtins::Multiset.difference(Builtins.sort(old), Builtins.sort(new))
    end


    # Calculates the devices from the devices, devices_add and devices_rem entries
    # in data.
    def MergeDevices(data)
      data = deep_copy(data)
      devices = Builtins.sort(Ops.get_list(data, "devices", []))
      devices_add = Builtins.sort(Ops.get_list(data, "devices_add", []))
      devices_rem = Builtins.sort(Ops.get_list(data, "devices_rem", []))

      devices = Builtins::Multiset.union(devices, devices_add)
      devices = Builtins::Multiset.difference(devices, devices_rem)

      deep_copy(devices)
    end


    def SplitDevice(target_map, device, disk, part)
      target_map = deep_copy(target_map)
      disk_tmp = Ops.get(target_map, device)
      part_tmp = nil

      if disk_tmp == nil
        part_tmp = Storage.GetPartition(target_map, device)
        disk_tmp = Storage.GetDisk(target_map, device)
      end

      disk.value = deep_copy(disk_tmp)
      part.value = deep_copy(part_tmp)

      nil
    end


    # Must be called before removing device.
    def ParentDevice(device)
      target_map = Storage.GetTargetMap

      disk = nil
      part = nil

      disk_ref = arg_ref(disk)
      part_ref = arg_ref(part)
      SplitDevice(target_map, device, disk_ref, part_ref)
      disk = disk_ref.value
      part = part_ref.value

      Ops.get_string(disk, "device", "")
    end


    def ConfirmDeletingUsedDevice(tg, part, used_by)
      tg = deep_copy(tg)
      part = deep_copy(part)
      device = Ops.get_string(part, "device", "")
      used_by_device = Ops.get_string(part, "used_by_device", "")

      case used_by
        when :UB_LVM
          volumes = Storage.GetAffectedDevices(device)
          return ConfirmRecursiveDelete(
            device,
            volumes,
            _("Confirm Deleting Partition Used by LVM"),
            Builtins.sformat(
              _(
                "The selected partition is used by volume group \"%1\".\n" +
                  "To keep the system in a consistent state, the following volume group\n" +
                  "and its logical volumes will be deleted:\n"
              ),
              used_by_device
            ),
            Builtins.sformat(
              _("Delete partition \"%1\" and volume group \"%2\" now?"),
              device,
              used_by_device
            )
          )
        when :UB_MD
          volumes = Storage.GetAffectedDevices(device)
          return ConfirmRecursiveDelete(
            device,
            volumes,
            _("Confirm Deleting Partition Used by RAID"),
            Builtins.sformat(
              _(
                "The selected partition belongs to RAID  \"%1\".\n" +
                  "To keep the system in a consistent state, the following\n" +
                  "RAID device will be deleted:\n"
              ),
              used_by_device
            ),
            Builtins.sformat(
              _("Delete partition \"%1\" and RAID \"%2\" now?"),
              device,
              used_by_device
            )
          )
        else

      end

      false
    end

    # Must be called before removing device.
    def NextDeviceAfterDelete(device)
      target_map = Storage.GetTargetMap

      parent = ParentDevice(device)

      partitions = Builtins.maplist(
        Ops.get_list(target_map, [parent, "partitions"], [])
      ) { |part| Ops.get_string(part, "device", "") }

      index = -1
      Builtins.foreach(Integer.Range(Builtins.size(partitions))) do |i|
        index = i if Ops.get(partitions, i, "") == device
      end

      ret = ""
      if Ops.greater_than(index, 0)
        ret = Ops.get(partitions, Ops.subtract(index, 1), "")
      elsif Ops.greater_than(Builtins.size(partitions), 1)
        ret = Ops.get(partitions, 1, "")
      end

      Builtins.y2milestone(
        "NextDeviceAfterDelete device:%1 ret:%2",
        device,
        ret
      )
      ret
    end


    def EpDeleteDevice(id)
      tg = Storage.GetTargetMap

      part = {}
      disk = Storage.GetDisk(tg, id)

      part = Storage.GetPartition(tg, id) if !Builtins.haskey(tg, id)
      Builtins.y2milestone("id:%1 part:%2", id, part)
      return false if !Builtins.haskey(tg, id) && Builtins.size(part) == 0

      if Ops.get_boolean(disk, "readonly", false)
        Popup.Error(Partitions.RdonlyText(disk, true))
        return false
      end

      if Builtins.haskey(tg, id)
        if Ops.get_symbol(tg, [id, "type"], :CT_UNKNOWN) == :CT_MD
          return false
        elsif Ops.get_symbol(tg, [id, "type"], :CT_UNKNOWN) == :CT_DMRAID
          if Popup.YesNo(Builtins.sformat(_("Really delete BIOS RAID %1?"), id))
            if deleteAllDevPartitions(disk, Stage.initial)
              Storage.DeleteDmraid(id)
            end
            return true
          end
        # YesNo popup text %1 is replaced by a disk name e.g. /dev/hda
        elsif Popup.YesNo(
            Builtins.sformat(_("Really delete all partitions on %1?"), id)
          )
          deleteAllDevPartitions(disk, Stage.initial)
          return true
        end
      elsif Ops.get_symbol(part, "type", :unknown) == :lvm
        if !check_device_delete(part, Stage.initial, {})
          return false
        else
          return HandleRemoveLv(tg, id)
        end
      else
        #///////////////////////////////////////////////////
        # delete algorithm:
        # if you find newly created (but until now not realy
        # written) partition (sign: "create = true"): delete it
        # else there must be already existing partition: mark it
        # with "delete = true"

        Builtins.y2milestone("delete part %1", part)
        #///////////////////////////////////////////////////
        # check if the partition can be deleted

        if Ops.get_symbol(part, "type", :primary) == :extended &&
            !check_extended_delete(disk, Stage.initial)
          return false
        end

        if Ops.get_symbol(part, "type", :primary) != :extended
          used_by = check_devices_used([part], false)

          if used_by != :UB_NONE
            if ConfirmDeletingUsedDevice(tg, part, used_by)
              recursive = Storage.GetRecursiveRemoval
              Storage.SetRecursiveRemoval(true)
              Storage.DeleteDevice(Ops.get_string(part, "device", ""))
              Storage.SetRecursiveRemoval(recursive)
              return true
            else
              return false
            end
          end

          return false if !check_device_delete(part, Stage.initial, disk)
        end

        #///////////////////////////////////////////////////
        # now delete partition!!

        # YesNo popup text, %1 is replaced by a device name e.g. /dev/hda1
        if Popup.YesNo(
            Builtins.sformat(
              _("Really delete %1?"),
              Ops.get_string(part, "device", "")
            )
          )
          if (Builtins.search(id, "/dev/loop") == 0 ||
              Builtins.search(id, "/dev/mapper/") == 0) &&
              Ops.greater_than(
                Builtins.size(Ops.get_string(part, "fpath", "")),
                0
              ) &&
              Mode.normal &&
              # YesNo popup.  %1 is path to a file
              Popup.YesNo(
                Builtins.sformat(
                  _("\nShould the loop file %1 also be removed?\n"),
                  Ops.get_string(part, "fpath", "")
                )
              )
            Storage.DeleteLoop(
              Ops.get_string(disk, "device", ""),
              Ops.get_string(part, "fpath", ""),
              true
            )
          else
            Storage.DeleteDevice(Ops.get_string(part, "device", ""))
          end
          return true
        end
      end

      false
    end


    def DiskBarGraph(device)
      return Empty() if !UI.HasSpecialWidget(:BarGraph)

      target_map = Storage.GetTargetMap

      disk = nil
      part = nil
      disk_ref = arg_ref(disk)
      part_ref = arg_ref(part)
      SplitDevice(target_map, device, disk_ref, part_ref)
      disk = disk_ref.value
      part = part_ref.value

      return Empty() if Storage.IsUsedBy(disk)

      bits = []
      labels = []

      _AddSegment = lambda do |bit, label, size_k|
        bit = deep_copy(bit)
        # Guarantee some minimal share (1%) of total graph width to the segment.
        # Prevents small partitions e.g. swaps from disappearing completely.
        bits = Builtins.add(
          bits,
          Integer.Clamp(
            Convert.convert(
              Ops.multiply(
                Convert.convert(1000, :from => "integer", :to => "float"),
                bit
              ),
              :from => "float",
              :to   => "integer"
            ),
            10,
            1000
          )
        )
        labels = Builtins.add(
          labels,
          Ops.add(Ops.add(label, "\n"), Storage.KByteToHumanString(size_k))
        )

        nil
      end

      case Ops.get_symbol(disk, "type", :CT_UNKNOWN)
        when :CT_DISK, :CT_DMMULTIPATH, :CT_DMRAID, :CT_MDPART
          emptyspace = _("Unpartitioned")

          # Filter out extended partitions
          partitions = Builtins.filter(Ops.get_list(disk, "partitions", [])) do |one_part|
            Ops.get_symbol(one_part, "type", :none) == :primary ||
              Ops.get_symbol(one_part, "type", :none) == :logical
          end
          # and sort the remaining ones by start cyl
          partitions = Builtins.sort(partitions) do |m, n|
            Ops.less_than(
              Region.Start(Ops.get_list(m, "region", [])),
              Region.Start(Ops.get_list(n, "region", []))
            )
          end

          # Clean disk (or 1 big extended partition)
          if Builtins.isempty(partitions)
            bits = [100]
            labels = [
              Ops.add(
                Ops.add(emptyspace, "\n"),
                Storage.KByteToHumanString(Ops.get_integer(disk, "size_k", 0))
              )
            ]
          else
            i = 0
            part_count = Builtins.size(partitions)
            ccyl = 0
            endcyl = Ops.get_integer(disk, "cyl_count", 1)

            while Ops.less_than(ccyl, endcyl)
              part2 = Ops.get(partitions, i, {})
              region = Ops.get_list(partitions, [i, "region"], [])
              ccyl = Region.Start(region)
              next_cyl = 0

              # this is the last partition in a row, look at the last cylinder of the disk
              if Ops.add(i, 1) == part_count
                next_cyl = endcyl
              else
                next_cyl = Region.Start(
                  Ops.get_list(partitions, [Ops.add(i, 1), "region"], [])
                )
              end

              tmp1 = Ops.divide(
                Convert.convert(
                  Region.Length(region),
                  :from => "integer",
                  :to   => "float"
                ),
                Convert.convert(
                  Ops.get_integer(disk, "cyl_count", 1),
                  :from => "integer",
                  :to   => "float"
                )
              )
              if Ops.greater_or_equal(tmp1, 0.0)
                _AddSegment.call(
                  tmp1,
                  Ops.get_string(part2, "name", ""),
                  Ops.get_integer(part2, "size_k", 0)
                )
              end

              # Now there is some xtra space between the end of this partition and the start of the next one
              # or the end of the disk if
              # 1. end +1th cyl is not the next one
              # 2. end cyl is not the same as the next one (yeah, partitions may share a cylinder)
              if Region.End(region) != next_cyl &&
                  Ops.add(Region.End(region), 1) != next_cyl
                tmp2 = Ops.divide(
                  Convert.convert(
                    Ops.subtract(next_cyl, Region.End(region)),
                    :from => "integer",
                    :to   => "float"
                  ),
                  Convert.convert(
                    Ops.get_integer(disk, "cyl_count", 1),
                    :from => "integer",
                    :to   => "float"
                  )
                )
                if Ops.greater_or_equal(tmp2, 0.0)
                  _AddSegment.call(
                    tmp2,
                    emptyspace,
                    Ops.divide(
                      Ops.multiply(
                        Ops.subtract(next_cyl, Region.End(region)),
                        Ops.get_integer(disk, "cyl_size", 1)
                      ),
                      1024
                    )
                  )
                end
              end

              ccyl = next_cyl
              i = Ops.add(i, 1)
            end
          end
        when :CT_LVM
          emptyspace = _("Unallocated")

          partitions = Ops.get_list(disk, "partitions", [])

          disk_size_k = Ops.get_integer(disk, "size_k", 1)
          disk_free_k = disk_size_k

          Builtins.foreach(partitions) do |partition|
            size_k = Ops.get_integer(partition, "size_k", 0)
            disk_free_k = Ops.subtract(disk_free_k, size_k)
            _AddSegment.call(
              Ops.divide(
                Convert.convert(size_k, :from => "integer", :to => "float"),
                Convert.convert(disk_size_k, :from => "integer", :to => "float")
              ),
              Ops.get_string(partition, "name", ""),
              size_k
            )
          end

          if Ops.greater_than(disk_free_k, 0)
            _AddSegment.call(
              Ops.divide(
                Convert.convert(disk_free_k, :from => "integer", :to => "float"),
                Convert.convert(disk_size_k, :from => "integer", :to => "float")
              ),
              emptyspace,
              disk_free_k
            )
          end
      end

      BarGraph(bits, labels)
    end


    def CompleteSummary
      part_summary = Storage.ChangeText
      if Builtins.isempty(part_summary)
        part_summary = HTML.Heading(_("<p>No changes to partitioning.</p>"))
      else
        part_summary = Ops.add(
          HTML.Heading(_("<p>Changes to partitioning:</p>")),
          part_summary
        )
      end

      config_summary = HTML.Heading(_("<p>No changes to storage settings.</p>"))
      if StorageSettings.GetModified
        config_summary = Ops.add(
          HTML.Heading(_("<p>Storage settings:</p>")),
          StorageSettings.Summary
        )
      end

      Ops.add(part_summary, config_summary)
    end


    def ArrangeButtons(buttons)
      buttons = deep_copy(buttons)
      # Unfortunately the UI does not provide functionality to rearrange
      # buttons in two or more lines if the available space is
      # limited. This implementation in YCP has several drawbacks, e.g. it
      # does not know anything about the font size, the font metric, the
      # button frame size, the actually available space nor is it run when
      # the dialog is resized. Also see fate #314971.

      display_info = UI.GetDisplayInfo
      textmode = Ops.get_boolean(display_info, "TextMode", false)
      width = Ops.get_integer(display_info, "DefaultWidth", 1024)

      max_buttons = 6

      if textmode && Ops.less_or_equal(width, 140) ||
          !textmode && Mode.installation && Ops.less_or_equal(width, 1280)
        max_buttons = 2
      end

      ret = VBox()

      line = HBox()

      i = 0
      j = 0

      Builtins.foreach(buttons) do |button|
        line = Builtins.add(line, button)
        i = Ops.add(i, 1)
        if Builtins.contains(
            [:PushButton, :MenuButton],
            Builtins.symbolof(button)
          )
          j = Ops.add(j, 1)

          if j == max_buttons
            line = Builtins.add(line, HStretch()) if i != Builtins.size(buttons)

            ret = Builtins.add(ret, line)
            line = HBox()
            j = 0
          end
        end
      end

      ret = Builtins.add(ret, line)

      deep_copy(ret)
    end

    def ChangeWidgetIfExists(wid, property, value)
      value = deep_copy(value)
      UI.ChangeWidget(Id(wid), property, value) if UI.WidgetExists(Id(wid))

      nil
    end
  end
end
