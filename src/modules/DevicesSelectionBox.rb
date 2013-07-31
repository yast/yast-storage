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

# File:	DevicesSelectionBox.ycp
# Package:	yast2-storage
# Summary:	Expert Partitioner
# Authors:	Arvin Schnell <aschnell@suse.de>
require "yast"

module Yast
  class DevicesSelectionBoxClass < Module
    def main
      Yast.import "UI"

      textdomain "storage"


      Yast.import "Storage"
      Yast.import "StorageFields"
      Yast.import "DualMultiSelectionBox"
      Yast.import "Integer"


      @devices = []

      @selected_size_function = nil
    end

    # Returns list with the maps of the unselected devices.
    def GetUnselectedDevices
      selected = Convert.convert(
        DualMultiSelectionBox.GetSelected,
        :from => "list",
        :to   => "list <string>"
      )

      Builtins.filter(@devices) do |device|
        !Builtins.contains(selected, Ops.get_string(device, "device", ""))
      end
    end


    # Returns list with the maps of the selected devices.
    def GetSelectedDevices
      selected = Convert.convert(
        DualMultiSelectionBox.GetSelected,
        :from => "list",
        :to   => "list <string>"
      )
      ret = Builtins.maplist(selected) do |s|
        Ops.get(Builtins.filter(@devices) do |d|
          s == Ops.get_string(d, "device", "")
        end, 0, {})
      end
      deep_copy(ret)
    end


    def Sum(devices)
      devices = deep_copy(devices)
      Integer.Sum(Builtins.maplist(devices) do |device|
        Ops.get_integer(device, "size_k", 0)
      end)
    end


    def UnselectedSizeTerm(unselected_devices)
      unselected_devices = deep_copy(unselected_devices)
      size_k = Sum(unselected_devices)
      # footer text, %1 is replaced by size
      Left(
        Label(
          Builtins.sformat(
            _("Total size: %1"),
            Storage.KByteToHumanString(size_k)
          )
        )
      )
    end


    def SelectedSizeTerm(selected_devices)
      selected_devices = deep_copy(selected_devices)
      size_k = @selected_size_function.call(selected_devices)
      # footer text, %1 is replaced by size
      Left(
        Label(
          Builtins.sformat(
            _("Resulting size: %1"),
            Storage.KByteToHumanString(size_k)
          )
        )
      )
    end




    # The maps for the devices must contain the entries "device" and "size_k".
    #
    # Ordering of device list is irrelevant. Devices are ordered by StorageFields::IterateTargetMap.
    def Create(unselected_devices, selected_devices, fields, new_selected_size_function, unselected_label, selected_label, change_order)
      unselected_devices = deep_copy(unselected_devices)
      selected_devices = deep_copy(selected_devices)
      fields = deep_copy(fields)
      new_selected_size_function = deep_copy(new_selected_size_function)
      @devices = Builtins.flatten([unselected_devices, selected_devices])

      @selected_size_function = new_selected_size_function != nil ?
        new_selected_size_function :
        fun_ref(method(:Sum), "integer (list <map>)")

      device_names = Builtins.maplist(@devices) do |device|
        Ops.get_string(device, "device", "")
      end

      _Predicate = lambda do |disk, partition|
        disk = deep_copy(disk)
        partition = deep_copy(partition)
        StorageFields.PredicateDevice(disk, partition, device_names)
      end

      target_map = Storage.GetTargetMap

      header = StorageFields.TableHeader(fields)
      content = StorageFields.TableContents(
        fields,
        target_map,
        fun_ref(_Predicate, "symbol (map, map)")
      )

      selected = Builtins.maplist(selected_devices) do |device|
        Ops.get_string(device, "device", "")
      end

      DualMultiSelectionBox.Create(
        header,
        content,
        selected,
        unselected_label,
        selected_label,
        UnselectedSizeTerm(unselected_devices),
        SelectedSizeTerm(selected_devices),
        change_order
      )
    end


    def UpdateUnselectedSize
      UI.ReplaceWidget(
        Id(:unselected_rp),
        UnselectedSizeTerm(GetUnselectedDevices())
      )

      nil
    end


    def UpdateSelectedSize
      UI.ReplaceWidget(Id(:selected_rp), SelectedSizeTerm(GetSelectedDevices()))

      nil
    end


    def Handle(widget)
      DualMultiSelectionBox.Handle(widget)

      if Builtins.contains(
          [:unselected, :selected, :add, :add_all, :remove, :remove_all],
          widget
        )
        UpdateUnselectedSize()
        UpdateSelectedSize()
      end

      nil
    end

    publish :function => :GetUnselectedDevices, :type => "list <map> ()"
    publish :function => :GetSelectedDevices, :type => "list <map> ()"
    publish :function => :Create, :type => "term (list <map>, list <map>, list <symbol>, integer (list <map>), string, string, boolean)"
    publish :function => :UpdateUnselectedSize, :type => "void ()"
    publish :function => :UpdateSelectedSize, :type => "void ()"
    publish :function => :Handle, :type => "void (symbol)"
  end

  DevicesSelectionBox = DevicesSelectionBoxClass.new
  DevicesSelectionBox.main
end
