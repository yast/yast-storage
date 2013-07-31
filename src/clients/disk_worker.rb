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
#   disk_worker.ycp
#
# Module:
#   Configuration of disk
#
# Summary:
#   Main file
#
# Authors:
#   Michael Hager <mike@suse.de>
#   Michal Svec <msvec@suse.com>
#   Arvin Schnell <aschnell@suse.de>
#
# Wrapper file for inst_disk.ycp
module Yast
  class DiskWorkerClient < Client
    def main
      textdomain "storage"

      Yast.import "CommandLine"
      Yast.import "Storage"
      Yast.import "StorageFields"


      @cmdline = {
        # Commandline help title
        "help"       => _("Storage Configuration"),
        "id"         => "disk",
        "guihandler" => fun_ref(method(:DiskSequence), "any ()"),
        "initialize" => fun_ref(method(:Dummy), "boolean ()"),
        "finish"     => fun_ref(method(:Dummy), "boolean ()"),
        "actions"    => {
          "list" => {
            # Commandline command help
            "help"    => _(
              "List disks and partitions"
            ),
            "example" => "storage list partitions",
            "handler" => fun_ref(
              method(:StorageCmdline),
              "boolean (map <string, string>)"
            )
          }
        },
        "options"    => {
          "disks"      => {
            # Command line option help text
            "help" => _("List disks")
          },
          "partitions" => {
            # Command line option help text
            "help" => _("List partitions")
          }
        },
        "mappings"   => { "list" => ["disks", "partitions"] }
      }

      CommandLine.Run(@cmdline)
      true
    end

    def DiskSequence
      return :abort if !Storage.InitLibstorage(false)

      Storage.SwitchUiAutomounter(false)
      ret = WFM.CallFunction("inst_disk", [true, true])
      Storage.SwitchUiAutomounter(true)
      Storage.SaveUsedFs

      Storage.FinishLibstorage

      deep_copy(ret)
    end


    def Dummy
      true
    end


    def StorageCmdline(options)
      options = deep_copy(options)
      disks = true
      partitions = true

      if !Builtins.isempty(options)
        disks = Builtins.haskey(options, "disks")
        partitions = Builtins.haskey(options, "partitions")
      end

      fields = [:device, :size, :fs_type, :mount_point, :label, :model]

      _Predicate = lambda do |disk, partition|
        disk = deep_copy(disk)
        partition = deep_copy(partition)
        returns = [:tmpfs, :nfs, :nfs4, :unknown]

        if partition == nil
          if disks
            return :showandfollow
          else
            return :follow
          end
        else
          if partitions
            if Builtins.contains(
                returns,
                Ops.get_symbol(partition, "used_fs", :unknown)
              )
              return :ignore
            else
              return :show
            end
          else
            return :ignore
          end
        end
      end

      target_map = Storage.GetTargetMap

      header = StorageFields.TableHeader(fields)
      content = StorageFields.TableContents(
        fields,
        target_map,
        fun_ref(_Predicate, "symbol (map, map)")
      )

      CommandLine.PrintTable(header, content)

      true
    end
  end
end

Yast::DiskWorkerClient.new.main
