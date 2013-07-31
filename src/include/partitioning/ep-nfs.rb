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
  module PartitioningEpNfsInclude
    def initialize_partitioning_ep_nfs(include_target)
      textdomain "storage"

      Yast.import "PackageCallbacks"
      Yast.import "PackageSystem"


      #boolean initialized = false;
      @target_map = {}
      @already_initialized = false
    end

    def CreateNfsMainPanel(user_data)
      user_data = deep_copy(user_data)
      nfs_list = []
      _Predicate = lambda do |disk, partition|
        disk = deep_copy(disk)
        partition = deep_copy(partition)
        StorageFields.PredicateDiskType(disk, partition, [:CT_NFS])
      end

      _CreateContent = lambda do
        pkg_installed = false
        #fallback dialog content
        fallback_content = VBox(
          Left(
            Label(
              _(
                "NFS configuration is not available. Check yast2-nfs-client package installation."
              )
            )
          ),
          VStretch(),
          HStretch()
        )

        #Check if we have y2-nfs-client installed
        if !Stage.initial
          pkgs = ["yast2-nfs-client"]
          PackageCallbacks.RegisterEmptyProgressCallbacks
          pkg_installed = PackageSystem.CheckAndInstallPackages(pkgs)
          PackageCallbacks.RestorePreviousProgressCallbacks
        else
          filename = "nfs-client4part"
          pkg_installed = WFM.ClientExists(filename)
        end

        if pkg_installed
          content = Convert.to_term(
            WFM.CallFunction("nfs-client4part", ["CreateUI"])
          )
          if content != nil
            return deep_copy(content)
          else
            Builtins.y2error(
              "Failed to retrieve dialog content from yast2-nfs-client"
            )
          end
        end

        #Obviously something went wrong - reset the help text and put a fallback content in
        Wizard.SetHelpText(" ")
        deep_copy(fallback_content)
      end

      _Initialize = lambda do
        @target_map = Storage.GetTargetMap

        #No NFS shares so far, set empty 'partitions' list
        if !Builtins.haskey(@target_map, "/dev/nfs")
          Ops.set(
            @target_map,
            "/dev/nfs",
            { "type" => :CT_NFS, "partitions" => [] }
          )
        end
        nfs_list = Ops.get_list(@target_map, ["/dev/nfs", "partitions"], [])

        Builtins.y2milestone("Found NFS shares: %1", nfs_list)

        if !Stage.initial && !@already_initialized
          Builtins.y2milestone("Reading NFS settings")
          WFM.CallFunction("nfs-client4part", ["Read"])
          @already_initialized = true
        end

        nil
      end



      UI.ReplaceWidget(
        :tree_panel,
        Greasemonkey.Transform(
          VBox(
            HStretch(),
            # heading
            term(
              :IconAndHeading,
              _("Network File System (NFS)"),
              StorageIcons.nfs_icon
            ),
            _CreateContent.call
          )
        )
      )

      _Initialize.call

      WFM.CallFunction(
        "nfs-client4part",
        ["FromStorage", { "shares" => nfs_list }]
      )

      nil
    end


    def HandleNfsMainPanel(user_data, event)
      user_data = deep_copy(user_data)
      event = deep_copy(event)
      _AddShare = lambda do |entry|
        entry = deep_copy(entry)
        Builtins.y2milestone(
          "Adding NFS share: %1 mountpoint: %2 options: %3",
          Ops.get_string(entry, "device", ""),
          Ops.get_string(entry, "mount", ""),
          Ops.get_string(entry, "fstopt", "")
        )
        @target_map = Storage.GetTargetMap
        nfs_list = Ops.get_list(@target_map, ["/dev/nfs", "partitions"], [])

        device = Ops.get_string(entry, "device", "")
        mount = Ops.get_string(entry, "mount", "")
        opts = Ops.get_string(entry, "fstopt", "")
        nfs4 = Ops.get_string(entry, "vfstype", "nfs") == "nfs4"

        sizeK = Storage.CheckNfsVolume(device, opts, nfs4)
        if Ops.less_or_equal(sizeK, 0)
          #rollback only if user does not want to save (#450060)
          #the mount might fail later if the errors are not corrected, but the user has been warned
          if !Popup.YesNo(
              Builtins.sformat(
                _("Test mount of NFS share '%1' failed.\nSave it anyway?"),
                Ops.get_string(entry, "device", "")
              )
            )
            WFM.CallFunction(
              "nfs-client4part",
              ["FromStorage", { "shares" => nfs_list }]
            )
            return
          end
          Builtins.y2warning(
            "Test mount of NFS share %1 failed, but user decided to save it anyway - this might not work.",
            Ops.get_string(entry, "device", "")
          )

          #this really sucks - but libstorage returns negative integers (error code) instead of
          #real size - Perl then wants to die in addNfsVolume call
          sizeK = 0
        end
        Storage.AddNfsVolume(device, opts, sizeK, mount, nfs4)

        nil
      end

      _EditShare = lambda do |entry|
        entry = deep_copy(entry)
        Builtins.y2milestone(
          "Changing NFS share: %1 mountpoint: %2 options: %3",
          Ops.get_string(entry, "device", ""),
          Ops.get_string(entry, "mount", ""),
          Ops.get_string(entry, "fstopt", "")
        )

        #device got renamed -
        #delete the one with old name and create new
        if Builtins.haskey(entry, "old_device")
          Storage.DeleteDevice(Ops.get_string(entry, "old_device", ""))
          _AddShare.call(entry)
        else
          dev = Ops.get_string(entry, "device", "")
          @target_map = Storage.GetTargetMap
          nfs_list = Ops.get_list(@target_map, ["/dev/nfs", "partitions"], [])

          nfs_list = Builtins.maplist(nfs_list) do |m|
            if Ops.get_string(m, "device", "") == dev
              Ops.set(m, "fstopt", Ops.get_string(entry, "fstopt", ""))
              Ops.set(m, "mount", Ops.get_string(entry, "mount", ""))
              Ops.set(
                m,
                "vfstype",
                Ops.get_symbol(entry, "used_fs", :nfs) == :nfs ? "nfs" : "nfs4"
              )
            end
            deep_copy(m)
          end
          Ops.set(@target_map, ["/dev/nfs", "partitions"], nfs_list)
          Storage.SetTargetMap(@target_map)
        end

        nil
      end

      _DeleteShare = lambda do |entry|
        entry = deep_copy(entry)
        Builtins.y2milestone(
          "Deleting NFS share: %1 mountpoint: %2 options: %3",
          Ops.get_string(entry, "device", ""),
          Ops.get_string(entry, "mount", ""),
          Ops.get_string(entry, "fstopt", "")
        )
        dev = Ops.get_string(entry, "device", "")

        Storage.DeleteDevice(dev)

        nil
      end

      line = Convert.convert(
        WFM.CallFunction(
          "nfs-client4part",
          ["HandleEvent", { "widget_id" => Event.IsWidgetActivated(event) }]
        ),
        :from => "any",
        :to   => "map <string, any>"
      )

      #do something only if y2-nfs-client returns some reasonable data
      if line != {} && line != nil
        case Event.IsWidgetActivated(event)
          when :newbut
            _AddShare.call(line)
          when :editbut
            _EditShare.call(line)
          when :delbut
            _DeleteShare.call(line)
          else

        end
        UI.SetFocus(Id(:fstable))
        UpdateMainStatus()
      end 
      #FIXME: Take care that non-fstab settings of nfs-client
      #(firewall, sysconfig, idmapd) get written on closing partitioner

      nil
    end

    def CreateNfsPanel(user_data)
      user_data = deep_copy(user_data)
      #a hack - we don't have overviews for nfs dirs, so let's switch to the main panel ...
      CreateNfsMainPanel(user_data)
      UI.ChangeWidget(:tree, :CurrentItem, :nfs)

      nil
    end
  end
end
