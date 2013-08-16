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

# File:	StorageSettings.ycp
# Package:	yast2-storage
# Summary:	Expert Partitioner
# Authors:	Arvin Schnell <aschnell@suse.de>
require "yast"

module Yast
  class StorageSettingsClass < Module
    def main


      textdomain "storage"


      Yast.import "Storage"
      Yast.import "Partitions"
      Yast.import "Integer"
      Yast.import "HTML"


      @display_name = nil

      @hidden_fields = nil
      @visible_fields = []

      @modified = false
    end

    def GetModified
      @modified
    end

    def SetModified
      @modified = true

      nil
    end


    def SetDisplayName(new_display_name)
      @display_name = new_display_name

      nil
    end

    def GetDisplayName
      if @display_name == nil
        tmp = Convert.to_string(
          SCR.Read(path(".sysconfig.storage.DISPLAY_NAME"))
        )
        if tmp == nil ||
            !Builtins.contains(["device", "id", "path"], Builtins.tolower(tmp))
          tmp = "device"
        end

        @display_name = Builtins.tosymbol(Builtins.tolower(tmp))
      end

      @display_name
    end

    def DisplayName(data)
      data = deep_copy(data)
      ret = ""

      case GetDisplayName()
        when :path
          ret = Ops.get_string(data, "udev_path", "")
        when :id
          ret = Ops.get_string(data, ["udev_id", 0], "")
      end

      ret = Ops.get_string(data, "name", "") if Builtins.isempty(ret)

      ret
    end


    def SetHiddenFields(new_hidden_fields)
      new_hidden_fields = deep_copy(new_hidden_fields)
      @hidden_fields = Builtins.toset(new_hidden_fields)

      nil
    end


    def GetHiddenFields
      if @hidden_fields == nil
        tmp = Convert.to_string(
          SCR.Read(path(".sysconfig.storage.HIDDEN_FIELDS"))
        )
        tmp = "" if tmp == nil

        @hidden_fields = Builtins.toset(
          Builtins.maplist(Builtins.splitstring(tmp, " \t")) do |field|
            Builtins.tosymbol(Builtins.tolower(field))
          end
        )
      end

      deep_copy(@hidden_fields)
    end


    def FilterTable(fields)
      fields = deep_copy(fields)
      hidden = GetHiddenFields()

      if GetDisplayName() != :path
        hidden = Builtins::Multiset.union(hidden, [:udev_path])
      else
        hidden = Builtins::Multiset.difference(hidden, [:udev_path])
      end

      if GetDisplayName() != :id
        hidden = Builtins::Multiset.union(hidden, [:udev_id])
      else
        hidden = Builtins::Multiset.difference(hidden, [:udev_id])
      end

      Builtins.filter(fields) { |field| !Builtins.setcontains(hidden, field) }
    end


    def FilterOverview(fields)
      fields = deep_copy(fields)
      hidden = GetHiddenFields()

      Builtins.filter(fields) { |field| !Builtins.setcontains(hidden, field) }
    end

    def InvertVisibleFields(all_fields, selected)
      all_fields = deep_copy(all_fields)
      selected = deep_copy(selected)
      Builtins.foreach(Integer.Range(Builtins.size(all_fields))) do |i|
        fields = Ops.get_list(all_fields, [i, :fields], [])
        label = Ops.get_string(all_fields, [i, :label], "")
        if Builtins.contains(selected, i)
          @hidden_fields = Builtins::Multiset.difference(@hidden_fields, fields)
          @visible_fields = Builtins::Multiset.union(@visible_fields, [label])
        else
          @hidden_fields = Builtins::Multiset.union(@hidden_fields, fields)
          @visible_fields = Builtins::Multiset.difference(
            @visible_fields,
            [label]
          )
        end
      end

      nil
    end


    def Summary
      tmp = [
        _("Default Mount-by:") + " " + Storage.GetDefaultMountBy().id2name,
        _("Default File System:") + " " + Partitions.DefaultFs().id2name,
        _("Show Storage Devices by:") + " " + GetDisplayName().id2name,
        _("Partition Alignment:") + " " + Storage.GetPartitionAlignment().id2name[6..-1],
        _("Visible Information on Storage Devices:") + " " + HTML.List(@visible_fields)
      ]

      HTML.List(tmp)
    end


    def Save
      if @display_name != nil
        tmp = @display_name.id2name
        SCR.Write(path(".sysconfig.storage.DISPLAY_NAME"), tmp)
      end

      if @hidden_fields != nil
        tmp = (@hidden_fields.map { |field| field.id2name }).join(" ")
        SCR.Write(path(".sysconfig.storage.HIDDEN_FIELDS"), tmp)
      end

      if true
        tmp = Storage.GetDefaultMountBy().id2name
        SCR.Write(path(".sysconfig.storage.DEVICE_NAMES"), tmp)
      end

      if true
        tmp = Partitions.DefaultFs().id2name
        SCR.Write(path(".sysconfig.storage.DEFAULT_FS"), tmp)
      end

      if true
        tmp = Storage.GetPartitionAlignment().id2name[6..-1]
        SCR.Write(path(".sysconfig.storage.PARTITION_ALIGN"), tmp)
      end
    end


    publish :function => :GetModified, :type => "boolean ()"
    publish :function => :SetModified, :type => "void ()"
    publish :function => :SetDisplayName, :type => "void (symbol)"
    publish :function => :GetDisplayName, :type => "symbol ()"
    publish :function => :DisplayName, :type => "string (map)"
    publish :function => :SetHiddenFields, :type => "void (list <symbol>)"
    publish :function => :GetHiddenFields, :type => "list <symbol> ()"
    publish :function => :FilterTable, :type => "list <symbol> (list <symbol>)"
    publish :function => :FilterOverview, :type => "list <symbol> (list <symbol>)"
    publish :function => :InvertVisibleFields, :type => "void (list <map <symbol, any>>, list <integer>)"
    publish :function => :Summary, :type => "string ()"
    publish :function => :Save, :type => "void ()"
  end

  StorageSettings = StorageSettingsClass.new
  StorageSettings.main
end
