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

# File:        Region.ycp
# Package:     yast2-storage
# Summary:	Expert Partitioner
# Authors:     Arvin Schnell <aschnell@suse.de>
#
# A region is a list of two integers, the first being the start and the
# second the length.
require "yast"

module Yast
  class RegionClass < Module
    def Start(a)
      a = deep_copy(a)
      Ops.get(a, 0, 0)
    end


    def Length(a)
      a = deep_copy(a)
      Ops.get(a, 1, 0)
    end


    def End(a)
      a = deep_copy(a)
      Ops.subtract(Ops.add(Ops.get(a, 0, 0), Ops.get(a, 1, 0)), 1)
    end


    # Checks whether region b lies within region a.
    def Inside(a, b)
      a = deep_copy(a)
      b = deep_copy(b)
      Ops.greater_or_equal(Start(b), Start(a)) &&
        Ops.less_or_equal(End(b), End(a))
    end

    publish :function => :Start, :type => "integer (list <integer>)"
    publish :function => :Length, :type => "integer (list <integer>)"
    publish :function => :End, :type => "integer (list <integer>)"
    publish :function => :Inside, :type => "boolean (list <integer>, list <integer>)"
  end

  Region = RegionClass.new
end
