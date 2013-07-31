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


# /usr/lib/YaST2/bin/y2base ./example.ycp stdio
module Yast
  class ExampleClient < Client
    def main
      Yast.import "LibStorage"
      Yast.import "LibStorage::StorageInterface"
      Yast.import "LibStorage::FsCapabilities"
      Yast.import "LibStorage::PartitionInfo"
      Yast.import "LibStorage::ContainerInfo"
      Yast.import "LibStorage::Environment"


      @o = nil

      @logdir = "/var/log/YaST2"
      logdir_ref = arg_ref(@logdir)
      LibStorage.initDefaultLogger(logdir_ref)
      @logdir = logdir_ref.value

      @env = LibStorage::Environment.new("LibStorage::Environment", true)

      @o = LibStorage.createStorageInterface(@env)

      test1
      test2
      test3
      test4
      test5
      test6
      test7
      test8
      test9

      LibStorage.destroyStorageInterface(@o)

      nil
    end

    def test1
      Builtins.y2milestone("test1")

      containers = []
      containers_ref = arg_ref(containers)
      LibStorage::StorageInterface.getContainers(@o, containers_ref)
      containers = containers_ref.value
      Builtins.foreach(containers) do |container|
        name = LibStorage::ContainerInfo.swig_name_get(container)
        Builtins.y2milestone("found containers %1", name)
        if LibStorage::ContainerInfo.swig_type_get(container) == LibStorage.DISK
          partitioninfos = []
          name_ref = arg_ref(name)
          partitioninfos_ref = arg_ref(partitioninfos)
          LibStorage::StorageInterface.getPartitionInfo(
            @o,
            name_ref,
            partitioninfos_ref
          )
          name = name_ref.value
          partitioninfos = partitioninfos_ref.value
          Builtins.foreach(partitioninfos) do |partitioninfo|
            Builtins.y2milestone(
              "found partition %1",
              LibStorage::PartitionInfo.swig_nr_get(partitioninfo)
            )
          end
        end
      end

      nil
    end


    def test2
      Builtins.y2milestone("test2")

      tmp = "sda1"
      mount_point = ""
      tmp_ref = arg_ref(tmp)
      mount_point_ref = arg_ref(mount_point)
      LibStorage::StorageInterface.getMountPoint(@o, tmp_ref, mount_point_ref)
      tmp = tmp_ref.value
      mount_point = mount_point_ref.value
      Builtins.y2milestone("mount point of /dev/sda1 is %1", mount_point)

      nil
    end


    def test3
      Builtins.y2milestone("test3")

      fscapabilities = LibStorage::FsCapabilities.new(
        "LibStorage::FsCapabilities"
      )
      LibStorage::StorageInterface.getFsCapabilities(
        @o,
        LibStorage.REISERFS,
        fscapabilities
      )
      Builtins.y2milestone(
        "isExtendable is %1",
        LibStorage::FsCapabilities.swig_isExtendable_get(fscapabilities)
      )

      nil
    end


    def test4
      Builtins.y2milestone("test4")

      tmp = "sda"
      i1 = (
        tmp_ref = arg_ref(tmp);
        cylinderToKb_result = LibStorage::StorageInterface.cylinderToKb(
          @o,
          tmp_ref,
          10
        );
        tmp = tmp_ref.value;
        cylinderToKb_result
      )
      Builtins.y2milestone("i1 = %1", i1)

      i2 = (
        tmp_ref = arg_ref(tmp);
        kbToCylinder_result = LibStorage::StorageInterface.kbToCylinder(
          @o,
          tmp_ref,
          100000
        );
        tmp = tmp_ref.value;
        kbToCylinder_result
      )
      Builtins.y2milestone("i2 = %1", i2)

      nil
    end


    def test5
      Builtins.y2milestone("test5")

      tmp = "sda1"
      b1 = true
      tmp_ref = arg_ref(tmp)
      b1_ref = arg_ref(b1)
      LibStorage::StorageInterface.getCrypt(@o, tmp_ref, b1_ref)
      tmp = tmp_ref.value
      b1 = b1_ref.value
      Builtins.y2milestone("b1 = %1", b1)

      nil
    end


    def test6
      Builtins.y2milestone("test6")

      LibStorage::StorageInterface.setRecursiveRemoval(@o, false)
      b = LibStorage::StorageInterface.getRecursiveRemoval(@o)
      Builtins.y2milestone("b = %1", b)

      nil
    end


    def test7
      Builtins.y2milestone("test7")

      tmp = "sda1"
      mb1 = LibStorage.MOUNTBY_LABEL
      tmp_ref = arg_ref(tmp)
      mb1_ref = arg_ref(mb1)
      LibStorage::StorageInterface.getMountBy(@o, tmp_ref, mb1_ref)
      tmp = tmp_ref.value
      mb1 = mb1_ref.value
      Builtins.y2milestone("mb1 = %1", mb1)

      nil
    end


    def test8
      Builtins.y2milestone("test8")

      containerinfos = []
      containerinfos_ref = arg_ref(containerinfos)
      LibStorage::StorageInterface.getContainers(@o, containerinfos_ref)
      containerinfos = containerinfos_ref.value

      Builtins.foreach(containerinfos) do |containerinfo|
        Builtins.y2milestone(
          "found container %1",
          LibStorage::ContainerInfo.swig_name_get(containerinfo)
        )
        type = LibStorage::ContainerInfo.swig_type_get(containerinfo)
        Builtins.y2milestone("of type %1", type)
      end

      nil
    end


    def test9
      Builtins.y2milestone("test9")
      mb1 = LibStorage.MOUNTBY_UUID
      mb1 = LibStorage::StorageInterface.getDefaultMountBy(@o)
      Builtins.y2milestone("mb1 = %1", mb1)

      nil
    end
  end
end

Yast::ExampleClient.new.main
