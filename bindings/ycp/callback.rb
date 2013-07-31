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


# /usr/lib/YaST2/bin/y2base callback.ycp stdio
module Yast
  class CallbackClient < Client
    def main
      Yast.import "Storage"
      Yast.import "LibStorage"
      Yast.import "LibStorage::StorageInterface"
      Yast.import "LibStorage::Environment"
      Yast.import "StorageCallbacks"

      # // place this in Storage.ycp
      # global define void test_log_progress (string id, integer cur, integer max)
      # {
      # 	y2milestone ("IN YCP %1 %2 %3", id, cur, max);
      # }

      @logdir = "/var/log/YaST2"
      logdir_ref = arg_ref(@logdir)
      LibStorage.initDefaultLogger(logdir_ref)
      @logdir = logdir_ref.value

      @env = LibStorage::Environment.new("LibStorage::Environment", true)
      @o = LibStorage.createStorageInterface(@env)

      @r = 0

      StorageCallbacks.ProgressBar("Storage::test_log_progress")

      LibStorage::StorageInterface.setRecursiveRemoval(@o, true)

      @tmp1 = "/dev/sdb"
      @tmp2 = "msdos"
      @r = (
        tmp1_ref = arg_ref(@tmp1);
        tmp2_ref = arg_ref(@tmp2);
        destroyPartitionTable_result = LibStorage::StorageInterface.destroyPartitionTable(
          @o,
          tmp1_ref,
          tmp2_ref
        );
        @tmp1 = tmp1_ref.value;
        @tmp2 = tmp2_ref.value;
        destroyPartitionTable_result
      )
      Builtins.y2milestone("destroyPartitionTable ret = %1", @r)

      @tmp3 = "/dev/sdb"
      @name = ""
      @r = (
        tmp3_ref = arg_ref(@tmp3);
        name_ref = arg_ref(@name);
        createPartition_result = LibStorage::StorageInterface.createPartition(
          @o,
          tmp3_ref,
          LibStorage.PRIMARY,
          0,
          1100,
          name_ref
        );
        @tmp3 = tmp3_ref.value;
        @name = name_ref.value;
        createPartition_result
      )
      Builtins.y2milestone("createPartition ret = %1, name = %2", @r, @name)

      @r = (
        name_ref = arg_ref(@name);
        changeFormatVolume_result = LibStorage::StorageInterface.changeFormatVolume(
          @o,
          name_ref,
          true,
          LibStorage.EXT4
        );
        @name = name_ref.value;
        changeFormatVolume_result
      )
      Builtins.y2milestone("changeFormatVolume ret = %1", @r)

      @tmp4 = "/foo"
      @r = (
        name_ref = arg_ref(@name);
        tmp4_ref = arg_ref(@tmp4);
        changeMountPoint_result = LibStorage::StorageInterface.changeMountPoint(
          @o,
          name_ref,
          tmp4_ref
        );
        @name = name_ref.value;
        @tmp4 = tmp4_ref.value;
        changeMountPoint_result
      )
      Builtins.y2milestone("changeMountPoint ret = %1", @r)

      @r = LibStorage::StorageInterface.commit(@o)
      Builtins.y2milestone("commit ret = %1", @r)

      LibStorage.destroyStorageInterface(@o)

      nil
    end
  end
end

Yast::CallbackClient.new.main
