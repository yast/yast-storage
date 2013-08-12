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

require 'storage'

# /usr/lib/YaST2/bin/y2base ./example.rb stdio
module Yast
  class ExampleClient < Client
    def main

      @env = ::Storage::Environment.new(true)
      @o = ::Storage::createStorageInterface(@env)

      test1
      test2
      test3
      test4
      test5
      test6
      test7
      test8
      test9

      ::Storage::destroyStorageInterface(@o)

      nil
    end

    def test1
      Builtins.y2milestone("test1")

      containers = ::Storage::DequeContainerInfo.new()
      @o.getContainers(containers)
      containers.each do |container|
        name = container.name
        Builtins.y2milestone("found containers %1", name)
        if container.type == ::Storage::DISK
          partitioninfos = ::Storage::DequePartitionInfo.new()
          @o.getPartitionInfo(name, partitioninfos)
          partitioninfos.each do |partitioninfo|
            Builtins.y2milestone( "found partition %1", partitioninfo.nr)
          end
        end
      end

      nil
    end


    def test2
      Builtins.y2milestone("test2")

      tmp = "sda1"
      tmp_ref = arg_ref(tmp)
      ret, mount_point = @o.getMountPoint(tmp)
      mount_point = "" if ret<0
      Builtins.y2milestone("mount point of /dev/sda1 is %1", mount_point)

      nil
    end


    def test3
      Builtins.y2milestone("test3")

      fscapabilities = ::Storage::FsCapabilities.new()
      @o.getFsCapabilities(::Storage::REISERFS, fscapabilities)
      Builtins.y2milestone("isExtendable is %1", fscapabilities.isExtendable)

      nil
    end


    def test4
      Builtins.y2milestone("test4")

      tmp = "sda"
      i1 = @o.cylinderToKb(tmp, 10)
      Builtins.y2milestone("i1 = %1", i1)

      i2 = @o.kbToCylinder(tmp, 100000)
      Builtins.y2milestone("i2 = %1", i2)

      nil
    end


    def test5
      Builtins.y2milestone("test5")

      tmp = "sda1"
      ret, b1 = @o.getCrypt(tmp)
      b1 = false if ret<0
      Builtins.y2milestone("b1 = %1", b1)

      nil
    end


    def test6
      Builtins.y2milestone("test6")

      @o.setRecursiveRemoval(false)
      b = @o.getRecursiveRemoval()
      Builtins.y2milestone("b = %1", b)

      nil
    end


    def test7
      Builtins.y2milestone("test7")

      tmp = "sda1"
      mb1 = ::Storage::MOUNTBY_LABEL
      ret, mb1 = @o.getMountBy(tmp)
      Builtins.y2milestone("mb1 = %1", mb1)

      nil
    end


    def test8
      Builtins.y2milestone("test8")

      containerinfos = ::Storage::DequeContainerInfo.new()
      @o.getContainers(containerinfos)

      containerinfos.each do |containerinfo|
        Builtins.y2milestone( "found container %1", containerinfo.name)
        type = containerinfo.type
        Builtins.y2milestone("of type %1", type)
      end

      nil
    end


    def test9
      Builtins.y2milestone("test9")
      mb1 = ::Storage::MOUNTBY_DEVICE
      mb1 = @o.getDefaultMountBy()
      Builtins.y2milestone("mb1 = %1", mb1)

      nil
    end
  end
end

Yast::ExampleClient.new.main
