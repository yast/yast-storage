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

# Module:		auto_part_create.ycp
#
# Authors:		Andreas Schwab (schwab@suse.de)
#			Klaus Kämpf (kkaempf@suse.de)
#
# Purpose:		This module creates the neccessary partitions
#			in the targetMap
#
# $Id$
#
# used globals
#
# defined functions
module Yast
  module PartitioningAutoPartCreateInclude
    def initialize_partitioning_auto_part_create(include_target)
      textdomain "storage"

      Yast.import "Storage"
      Yast.import "Partitions"
      Yast.import "StorageProposal"
    end

    def create_partitions(tgmap, disk, partitions)
      tgmap = deep_copy(tgmap)
      disk = deep_copy(disk)
      partitions = deep_copy(partitions)
      Builtins.y2milestone(
        "create_partitions disk:%1",
        Builtins.haskey(disk, "partitions") ?
          Builtins.remove(disk, "partitions") :
          disk
      )
      Builtins.y2milestone("create_partitions partitions %1", partitions)
      StorageProposal.flex_init_swapable(tgmap)
      ret = false
      has_flex = StorageProposal.has_flex_proposal
      vm = StorageProposal.GetProposalVM
      Builtins.y2milestone("create_partitions flex %1 vm %2", has_flex, vm)
      Ops.set(disk, "partitions", partitions)
      if StorageProposal.NeedNewDisklabel(disk)
        Ops.set(tgmap, [Ops.get_string(disk, "device", ""), "disklabel"], "gpt")
        Ops.set(tgmap, [Ops.get_string(disk, "device", ""), "del_ptable"], true)
      end
      keep = Builtins.find(partitions) do |p|
        !Ops.get_boolean(p, "delete", false) &&
          Ops.get_symbol(p, "type", :unknown) != :free
      end
      if Builtins.size(vm) == 0
        if has_flex
          flex = StorageProposal.do_flexible_disk(disk)
          if Ops.get_boolean(flex, "ok", false)
            partitions = Ops.get_list(flex, ["disk", "partitions"], [])
          end
        else
          num_del_exist = Builtins.size(Builtins.filter(partitions) do |p|
            Ops.get_symbol(p, "type", :unknown) != :free &&
              Ops.get_boolean(p, "delete", false)
          end)
          num_del_free = Builtins.size(Builtins.filter(partitions) do |p|
            Ops.get_symbol(p, "type", :unknown) == :free &&
              Ops.get_boolean(p, "delete", false)
          end)
          r = StorageProposal.can_swap_reuse(
            Ops.get_string(disk, "device", ""),
            partitions,
            tgmap
          )
          if Builtins.haskey(r, "partitions")
            partitions = Ops.get_list(r, "partitions", [])
          elsif Builtins.haskey(r, "targets")
            tgmap = Ops.get_map(r, "targets", {})
          end

          Builtins.y2milestone(
            "create_partitions num_del_exist %1 num_del_free %2 swap_reuse %3",
            num_del_exist,
            num_del_free,
            Ops.greater_than(Builtins.size(r), 0)
          )
          Builtins.y2milestone("create_partitions keep %1", keep)
          if keep != nil && Ops.greater_than(Builtins.size(r), 0) &&
              !StorageProposal.GetProposalHome &&
              !StorageProposal.GetProposalSnapshots &&
              num_del_exist == 1 &&
              num_del_free == 0
            Builtins.y2milestone("create_partitions single special")
            first = true
            partitions = Builtins.maplist(partitions) do |p|
              if Ops.get_boolean(p, "delete", false) && first
                p = Builtins.remove(p, "delete")
                first = false
                p = Storage.SetVolOptions(
                  p,
                  "/",
                  Partitions.DefaultFs,
                  "",
                  "",
                  ""
                )
                Builtins.y2milestone("create_partitions single p %1", p)
              end
              deep_copy(p)
            end
          else
            have_swap = Ops.greater_than(Builtins.size(r), 0) &&
              !StorageProposal.GetProposalSuspend
            partitions = StorageProposal.get_proposal(have_swap, disk)
          end
        end
        Builtins.y2milestone("create_partitions %1", partitions)
      else
        id_save = {}
        Ops.set(
          disk,
          "partitions",
          Builtins.maplist(Ops.get_list(disk, "partitions", [])) do |p|
            if !Ops.get_boolean(p, "delete", false) &&
                Ops.get_symbol(p, "type", :unknown) != :free &&
                Ops.get_symbol(p, "type", :unknown) != :extended
              Ops.set(
                id_save,
                Ops.get_string(p, "device", ""),
                Ops.get_integer(p, "fsid", 0)
              )
              Ops.set(p, "fsid", Partitions.fsid_hibernation)
            end
            deep_copy(p)
          end
        )
        Builtins.y2milestone("create_partitions id_save %1", id_save)
        Builtins.y2milestone(
          "create_partitions ps %1",
          Ops.get_list(disk, "partitions", [])
        )
        r = StorageProposal.get_proposal_vm(tgmap, vm, disk)
        ret = Ops.get_boolean(r, "ok", false)
        if ret
          ddev = Ops.get_string(disk, "device", "")
          tgmap = Ops.get_map(r, "target", {})
          Ops.set(
            tgmap,
            [ddev, "partitions"],
            Builtins.maplist(Ops.get_list(tgmap, [ddev, "partitions"], [])) do |p|
              if Builtins.haskey(id_save, Ops.get_string(p, "device", ""))
                Ops.set(
                  p,
                  "fsid",
                  Ops.get_integer(id_save, Ops.get_string(p, "device", ""), 0)
                )
              end
              deep_copy(p)
            end
          )
          Builtins.y2milestone(
            "create_partitions ps %1",
            Ops.get_list(tgmap, [ddev, "partitions"], [])
          )
        end
      end
      keep = Builtins.find(partitions) do |p|
        !Ops.get_boolean(p, "delete", false) &&
          !Ops.get_boolean(p, "create", false)
      end
      partitions = Builtins.filter(partitions) do |p|
        Ops.get_symbol(p, "type", :unknown) != :free
      end
      Builtins.y2milestone("create_partitions keep %1", keep)
      if Builtins.size(vm) == 0
        ret = Ops.greater_than(Builtins.size(partitions), 0)
        if ret
          Ops.set(
            tgmap,
            [Ops.get_string(disk, "device", ""), "partitions"],
            partitions
          )
          tgmap = Storage.SpecialBootHandling(tgmap)
        end
      end
      if ret
        Storage.SetTargetMap(tgmap)
        Storage.AddMountPointsForWin(tgmap)
      end
      Builtins.y2milestone("create_partitions ret %1", ret)
      ret
    end
  end
end
