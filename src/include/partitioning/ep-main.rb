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
  module PartitioningEpMainInclude
    def initialize_partitioning_ep_main(include_target)
      Yast.import "UI"
      textdomain "storage"

      Yast.import "Arch"
      Yast.import "Mode"
      Yast.import "Stage"
      Yast.import "Label"
      Yast.import "Hostname"
      Yast.import "Event"
      Yast.import "ContextMenu"
      Yast.import "TabPanel"
      Yast.import "TreePanel"
      Yast.import "Popup"
      Yast.import "Storage"
      Yast.import "StorageFields"
      Yast.import "StorageIcons"
      Yast.import "StorageSettings"
      Yast.import "Wizard"
      Yast.import "MiniWorkflow"
      Yast.import "Greasemonkey"
      Yast.import "Partitions"
      Yast.import "FileSystems"
      Yast.import "DevicesSelectionBox"
      Yast.import "Integer"
      Yast.import "String"
      Yast.import "Region"
      Yast.import "ProductFeatures"
      Yast.import "Directory"
      Yast.import "HTML"
      Yast.import "Map"
      Yast.import "Icon"

      Yast.include include_target, "partitioning/lvm_ui_dialogs.rb"
      Yast.include include_target, "partitioning/raid_lib.rb"
      Yast.include include_target, "partitioning/custom_part_check_generated.rb"


      # dialog caption
      @caption = _("Expert Partitioner")


      Yast.include include_target, "partitioning/ep-lib.rb"
      Yast.include include_target, "partitioning/ep-dialogs.rb"
      Yast.include include_target, "partitioning/ep-import.rb"

      Yast.include include_target, "partitioning/ep-all.rb"
      Yast.include include_target, "partitioning/ep-hd.rb"
      Yast.include include_target, "partitioning/ep-lvm.rb"
      Yast.include include_target, "partitioning/ep-raid.rb"
      Yast.include include_target, "partitioning/ep-loop.rb"
      Yast.include include_target, "partitioning/ep-dm.rb"
      Yast.include include_target, "partitioning/ep-nfs.rb"
      Yast.include include_target, "partitioning/ep-btrfs.rb"
      Yast.include include_target, "partitioning/ep-tmpfs.rb"
      Yast.include include_target, "partitioning/ep-unused.rb"

      Yast.include include_target, "partitioning/ep-graph.rb"
      Yast.include include_target, "partitioning/ep-summary.rb"
      Yast.include include_target, "partitioning/ep-settings.rb"
      Yast.include include_target, "partitioning/ep-log.rb"
    end

    def UpdateTableFocus(device)
      if UI.WidgetExists(Id(:table))
        UI.ChangeWidget(Id(:table), :CurrentItem, device)
      end

      nil
    end
    def UpdateMainStatus
      if Mode.normal
        next_label = Storage.EqualBackupStates("expert-partitioner", "", true) ?
          Label.FinishButton :
          Label.NextButton

        Wizard.SetNextButton(:next, next_label)
      end

      nil
    end


    def MakeNavigationTree(open_items)
      open_items = deep_copy(open_items)
      # TODO: somehow use AlwaysHideDisk

      data = {
        :all         => {
          :create => fun_ref(method(:CreateAllPanel), "void (any)"),
          :handle => fun_ref(method(:HandleAllPanel), "void (any, map)")
        },
        :hd          => {
          :create => fun_ref(method(:CreateHdMainPanel), "void (any)"),
          :handle => fun_ref(method(:HandleHdMainPanel), "void (any, map)")
        },
        :lvm         => {
          :create => fun_ref(method(:CreateLvmMainPanel), "void (any)"),
          :handle => fun_ref(method(:HandleLvmMainPanel), "void (any, map)")
        },
        :md          => {
          :create => fun_ref(method(:CreateRaidMainPanel), "void (any)"),
          :handle => fun_ref(method(:HandleRaidMainPanel), "void (any, map)")
        },
        :loop        => {
          :create => fun_ref(method(:CreateLoopMainPanel), "void (any)"),
          :handle => fun_ref(method(:HandleLoopMainPanel), "void (any, map)")
        },
        :dm          => {
          :create => fun_ref(method(:CreateDmMainPanel), "void (any)"),
          :handle => fun_ref(method(:HandleDmMainPanel), "void (any, map)")
        },
        :nfs         => {
          :create => fun_ref(method(:CreateNfsMainPanel), "void (any)"),
          :handle => fun_ref(method(:HandleNfsMainPanel), "void (any, map)")
        },
        :btrfs       => {
          :create => fun_ref(method(:CreateBtrfsMainPanel), "void (any)"),
          :handle => fun_ref(method(:HandleBtrfsMainPanel), "void (any, map)")
        },
        :tmpfs       => {
          :create => fun_ref(method(:CreateTmpfsMainPanel), "void (any)"),
          :handle => fun_ref(method(:HandleTmpfsMainPanel), "void (any, map)")
        },
        :unused      => {
          :create => fun_ref(method(:CreateUnusedPanel), "void (any)"),
          :handle => fun_ref(method(:HandleUnusedPanel), "void (any, map)")
        },
        :devicegraph => {
          :create  => fun_ref(method(:CreateDeviceGraphPanel), "void (any)"),
          :refresh => fun_ref(method(:RefreshDeviceGraphPanel), "void (any)"),
          :handle  => fun_ref(
            method(:HandleDeviceGraphPanel),
            "void (any, map)"
          )
        },
        :mountgraph  => {
          :create  => fun_ref(method(:CreateMountGraphPanel), "void (any)"),
          :refresh => fun_ref(method(:RefreshDeviceGraphPanel), "void (any)"),
          :handle  => fun_ref(method(:HandleMountGraphPanel), "void (any, map)")
        },
        :summary     => {
          :create => fun_ref(method(:CreateSummaryPanel), "void (any)")
        },
        :settings    => {
          :create  => fun_ref(method(:CreateSettingsPanel), "void (any)"),
          :handle  => fun_ref(method(:HandleSettingsPanel), "void (any, map)"),
          :destroy => fun_ref(method(:DestroySettingsPanel), "void (any)")
        },
        :log         => {
          :create  => fun_ref(method(:CreateLogPanel), "void (any)"),
          :handle  => fun_ref(method(:HandleLogPanel), "void (any, map)"),
          :destroy => fun_ref(method(:DestroyLogPanel), "void (any)")
        }
      }

      subtree = {}

      target_map = Storage.GetTargetMap


      open = lambda do |id|
        id = deep_copy(id)
        Ops.get_string(open_items, id, "") == "ID"
      end


      huhu = lambda do |disk, type, a, b|
        disk = deep_copy(disk)
        a = deep_copy(a)
        b = deep_copy(b)
        disk_device = Ops.get_string(disk, "device", "")

        partitions = Ops.get_list(disk, "partitions", [])
        partitions = Builtins.filter(partitions) do |partition|
          !StorageFields.AlwaysHidePartition(target_map, disk, partition)
        end

        tmp = []
        Builtins.foreach(partitions) do |partition|
          part_device = Ops.get_string(partition, "device", "")
          part_displayname = StorageSettings.DisplayName(partition)
          tmp = Builtins.add(
            tmp,
            Item(Id(part_device), part_displayname, open.call(part_device))
          )
          data = Builtins.add(
            data,
            part_device,
            Builtins.union(a, { :user_data => part_device })
          )
        end

        if b != nil
          disk_displayname = StorageSettings.DisplayName(disk)
          Ops.set(
            subtree,
            type,
            Builtins.add(
              Ops.get(subtree, type, []),
              Item(
                Id(disk_device),
                disk_displayname,
                open.call(disk_device),
                tmp
              )
            )
          )
          data = Builtins.add(
            data,
            disk_device,
            Builtins.union(b, { :user_data => disk_device })
          )
        else
          Ops.set(
            subtree,
            type,
            Builtins.merge(Ops.get(subtree, type, []), tmp)
          )
        end

        nil
      end


      callback = lambda do |target_map2, disk|
        target_map2 = deep_copy(target_map2)
        disk = deep_copy(disk)
        type = Ops.get_symbol(disk, "type", :CT_UNKNOWN)

        case type
          when :CT_DISK, :CT_DMMULTIPATH, :CT_DMRAID, :CT_MDPART
            huhu.call(
              disk,
              :hd,
              {
                :create => fun_ref(
                  method(:CreateHdPartitionPanel),
                  "void (any)"
                ),
                :handle => fun_ref(
                  method(:HandleHdPartitionPanel),
                  "void (any, map)"
                )
              },
              {
                :create => fun_ref(method(:CreateHdDiskPanel), "void (any)"),
                :handle => fun_ref(
                  method(:HandleHdDiskPanel),
                  "void (any, map)"
                )
              }
            )
          when :CT_LVM
            huhu.call(
              disk,
              :lvm,
              {
                :create => fun_ref(method(:CreateLvmLvPanel), "void (any)"),
                :handle => fun_ref(method(:HandleLvmLvPanel), "void (any, map)")
              },
              {
                :create => fun_ref(method(:CreateLvmVgPanel), "void (any)"),
                :handle => fun_ref(method(:HandleLvmVgPanel), "void (any, map)")
              }
            )
          when :CT_MD
            huhu.call(
              disk,
              :md,
              {
                :create => fun_ref(method(:CreateRaidPanel), "void (any)"),
                :handle => fun_ref(method(:HandleRaidPanel), "void (any, map)")
              },
              nil
            )
          when :CT_LOOP
            huhu.call(
              disk,
              :loop,
              {
                :create => fun_ref(method(:CreateLoopPanel), "void (any)"),
                :handle => fun_ref(method(:HandleLoopPanel), "void (any, map)")
              },
              nil
            )
          when :CT_DM
            huhu.call(
              disk,
              :dm,
              {
                :create => fun_ref(method(:CreateDmPanel), "void (any)"),
                :handle => fun_ref(method(:HandleDmPanel), "void (any, map)")
              },
              nil
            )
          when :CT_NFS
            huhu.call(
              disk,
              :nfs,
              {
                :create => fun_ref(method(:CreateNfsPanel), "void (any)"),
                :handle => fun_ref(
                  method(:HandleNfsMainPanel),
                  "void (any, map)"
                )
              },
              nil
            )
          when :CT_BTRFS
            huhu.call(
              disk,
              :btrfs,
              {
                :create => fun_ref(method(:CreateBtrfsPanel), "void (any)"),
                :handle => fun_ref(method(:HandleBtrfsPanel), "void (any, map)")
              },
              nil
            )
          when :CT_TMPFS
            huhu.call(
              disk,
              :tmpfs,
              {
                :create => fun_ref(method(:CreateTmpfsPanel), "void (any)"),
                :handle => fun_ref(method(:HandleTmpfsPanel), "void (any, map)")
              },
              nil
            )
        end

        nil
      end


      StorageFields.IterateTargetMap(
        target_map,
        fun_ref(callback, "void (map <string, map>, map)")
      )

      short_hostname = Hostname.CurrentHostname

      # TODO: same ordering as with IterateTargetMap
      tree = [
        Item(
          Id(:all),
          term(:icon, StorageIcons.all_icon),
          short_hostname,
          open.call(:all),
          [
            # tree node label
            Item(
              Id(:hd),
              term(:icon, StorageIcons.hd_icon),
              _("Hard Disks"),
              open.call(:hd),
              Ops.get(subtree, :hd, [])
            ),
            # tree node label
            Item(
              Id(:md),
              term(:icon, StorageIcons.raid_icon),
              _("RAID"),
              open.call(:md),
              Ops.get(subtree, :md, [])
            ),
            # tree node label
            Item(
              Id(:lvm),
              term(:icon, StorageIcons.lvm_icon),
              _("Volume Management"),
              open.call(:lvm),
              Ops.get(subtree, :lvm, [])
            ),
            # tree node label
            Item(
              Id(:loop),
              term(:icon, StorageIcons.loop_icon),
              _("Crypt Files"),
              open.call(:loop),
              Ops.get(subtree, :loop, [])
            ),
            # tree node label
            Item(
              Id(:dm),
              term(:icon, StorageIcons.dm_icon),
              _("Device Mapper"),
              open.call(:dm),
              Ops.get(subtree, :dm, [])
            ),
            # tree node label
            Item(
              Id(:nfs),
              term(:icon, StorageIcons.nfs_icon),
              _("NFS"),
              open.call(:nfs)
            ),
            # tree node label
            Item(
              Id(:btrfs),
              term(:icon, StorageIcons.nfs_icon),
              _("Btrfs"),
              open.call(:btrfs)
            ),
            # tree node label
            Item(
              Id(:tmpfs),
              term(:icon, StorageIcons.nfs_icon),
              _("tmpfs"),
              open.call(:tmpfs)
            ),
            # tree node label
            Item(
              Id(:unused),
              term(:icon, StorageIcons.unused_icon),
              _("Unused Devices"),
              open.call(:unused)
            )
          ]
        )
      ]

      if UI.HasSpecialWidget(:Graph)
        # tree node label
        tree = Builtins.add(
          tree,
          Item(
            Id(:devicegraph),
            term(:icon, StorageIcons.graph_icon),
            _("Device Graph"),
            open.call(:devicegraph)
          )
        )
        # tree node label
        tree = Builtins.add(
          tree,
          Item(
            Id(:mountgraph),
            term(:icon, StorageIcons.graph_icon),
            _("Mount Graph"),
            open.call(:mountgraph)
          )
        )
      end


      # tree node label
      tree = Builtins.add(
        tree,
        Item(
          Id(:summary),
          term(:icon, StorageIcons.summary_icon),
          _("Installation Summary"),
          open.call(:summary)
        )
      )

      # tree node label
      tree = Builtins.add(
        tree,
        Item(
          Id(:settings),
          term(:icon, StorageIcons.settings_icon),
          _("Settings"),
          open.call(:settings)
        )
      )

      if Mode.normal
        # tree node label
        tree = Builtins.add(
          tree,
          Item(
            Id(:log),
            term(:icon, StorageIcons.log_icon),
            _("Log"),
            open.call(:log)
          )
        )
      end

      return tree, data

    end


    def UpdateNavigationTree(new_focus)
      new_focus = deep_copy(new_focus)

      open_items = Convert.to_map(UI.QueryWidget(Id(:tree), :OpenItems))

      tree, data = MakeNavigationTree(open_items)

      TreePanel.Update(data, tree, new_focus)

      nil
    end


    def EpContextMenuDevice(device)
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


    # Confirm leaving the module
    def ReallyQuit(label)
      # popup text, %1 will be replaces with button text
      text = Builtins.sformat(
        _(
          "You have changed the partitioning or storage settings. These changes\n" +
            "will be lost if you exit the partitioner with %1.\n" +
            "Really exit?"
        ),
        Builtins.deletechars(label, "&")
      )

      Popup.YesNo(text)
    end


    def SummaryDialogHelptext
      # helptext
      helptext = _("<p>Here you can see the partitioning summary.</p>")

      helptext
    end


    # Fullscreen summary of changes
    def SummaryDialog
      ret = :none

      Wizard.CreateDialog
      Wizard.SetContentsButtons(
        Ops.add(@caption, _(": Summary")),
        VBox(RichText(CompleteSummary())),
        SummaryDialogHelptext(),
        Label.BackButton,
        Label.FinishButton
      )
      Wizard.SetDesktopIcon("disk")

      while true
        ret = Convert.to_symbol(UI.UserInput)

        break if ret == :next || ret == :back

        if ret == :abort && ReallyQuit(Label.AbortButton)
          ret = :abort
          break
        end
      end

      Wizard.CloseDialog
      Builtins.y2milestone("Summary dialog returned %1", ret)
      ret
    end


    # apply changes in running system
    def DoApply
      ret1 = SummaryDialog()

      if ret1 == :back
        return :back
      elsif ret1 == :next
        Wizard.CreateDialog
        Wizard.SetDesktopIcon("disk")
        ret2 = Convert.to_symbol(
          WFM.CallFunction("inst_prepdisk", [true, true])
        )
        StorageSettings.Save
        Wizard.CloseDialog

        Storage.CreateTargetBackup("expert-partitioner")

        if ret2 != :next
          return :back
        else
          return :next
        end
      end

      nil
    end


    def ExpertPartitioner
      SCR.Write(
        path(".target.ycp"),
        Storage.SaveDumpPath("targetmap-ep-start"),
        Storage.GetTargetMap
      )

      Storage.CreateTargetBackup("expert-partitioner")

      tree, data = MakeNavigationTree({ :all => "ID" })

      back_label = Label.BackButton
      next_label = Mode.normal ? Label.FinishButton : Label.AcceptButton
      abort_label = Label.AbortButton

      contents = MarginBox(
        0.5,
        0.5,
        HBox(
          HWeight(
            30,
            # tree node label
            Tree(Id(:tree), Opt(:notify), _("System View"), tree)
          ),
          HWeight(70, ReplacePoint(Id(:tree_panel), TreePanel.empty_panel))
        )
      )

      # heading text
      Wizard.SetContentsButtons(@caption, contents, "", back_label, next_label)
      Wizard.HideBackButton if Mode.normal

      TreePanel.Init(data)

      widget = nil
      begin
        event = Wizard.WaitForEvent

        TreePanel.Handle(event)

        widget = Ops.get_symbol(event, "ID")

        case widget
          when :abort, :back
            if !Storage.EqualBackupStates("expert-partitioner", "", true)
              if !ReallyQuit(widget == :back ? back_label : abort_label)
                widget = :again
              end
            end
          when :next
            if !Storage.EqualBackupStates("expert-partitioner", "", true) ||
                StorageSettings.GetModified
              if !check_created_partition_table(
                  Storage.GetTargetMap,
                  Stage.initial && !Mode.repair
                )
                widget = :again
              else
                widget = :again if DoApply() == :back if Mode.normal
              end
            else
              Builtins.y2milestone("No changes to partitioning - nothing to do")
              widget = :abort
            end
        end

        case Event.IsWidgetActivated(event)
          when :table
            citem = UI.QueryWidget(Id(:table), :CurrentItem)
            TreePanel.SwitchToNew(citem)
            UI.SetFocus(UI.WidgetExists(Id(:table)) ? Id(:table) : Id(:text))
        end
      end until widget == :back || widget == :abort || widget == :next

      TreePanel.Destroy

      case widget
        when :abort, :back
          Storage.SetPartMode("CUSTOM") if Storage.GetPartMode == "NORMAL"
        when :next
          if !Storage.EqualBackupStates("expert-partitioner", "", true)
            Storage.SetPartMode("CUSTOM")
            Storage.UpdateChangeTime
          end
      end

      Storage.DisposeTargetBackup("expert-partitioner")

      SCR.Write(
        path(".target.ycp"),
        Storage.SaveDumpPath("targetmap-ep-end"),
        Storage.GetTargetMap
      )

      widget
    end
  end
end
