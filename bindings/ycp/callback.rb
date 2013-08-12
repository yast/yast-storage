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


# /usr/lib/YaST2/bin/y2base callback.rb stdio
module Yast
  class CallbackClient < Client
    def main
      Yast.import "Storage"
      Yast.import "StorageCallbacks"

      # // place this in Storage.rb
      # def test_log_progress (id, cur, max)
      #   Builtins.y2milestone("IN YCP %1 %2 %3", id, cur, max)
      #	  nil
      # end
      # publish :function => :test_log_progress, :type => "void (integer,integer,integer)"

      env = ::Storage::Environment.new(false)
      @o = ::Storage::createStorageInterface(env)

      StorageCallbacks.ProgressBar("Storage::test_log_progress")

      @o.setRecursiveRemoval(true)

      @disk = "/dev/sdb"

      r = @o.destroyPartitionTable(@disk, "msdos")
      Builtins.y2milestone("destroyPartitionTable ret = %1", r)

      r, name = @o.createPartition(@disk, ::Storage::PRIMARY, 0, 1100)
      name = "" if r<0
      Builtins.y2milestone("createPartition ret = %1, name = %2", r, name)

      r = @o.changeFormatVolume(name, true, ::Storage::EXT4)
      Builtins.y2milestone("changeFormatVolume ret = %1", r)

      r = @o.changeMountPoint(name, "/foo")
      Builtins.y2milestone("changeMountPoint ret = %1", r)

      r = @o.commit()
      Builtins.y2milestone("commit ret = %1", r)

      ::Storage::destroyStorageInterface(@o)

      nil
    end
  end
end

Yast::CallbackClient.new.main
