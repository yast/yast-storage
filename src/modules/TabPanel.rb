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

# File:        TabPanel.ycp
# Package:     yast2-storage
# Summary:	Expert Partitioner
# Authors:     Arvin Schnell <aschnell@suse.de>
#
# The DumbTab widget must have id `tab.  The ids of the items of the DumbTab
# widget must be made of symbols.
require "yast"

module Yast
  class TabPanelClass < Module
    def main
      Yast.import "UI"


      Yast.import "Event"


      @data = nil

      @current_item = nil

      @history = []


      @empty_panel = VBox(VStretch(), HStretch())
    end

    def CallCreate
      tmp = Ops.get(@data, @current_item)
      create_func = Convert.convert(
        Ops.get(tmp, :create),
        :from => "any",
        :to   => "void (any)"
      )
      if create_func != nil
        user_data = Ops.get(tmp, :user_data)
        create_func.call(user_data)
      end

      nil
    end

    def CallRefresh
      tmp = Ops.get(@data, @current_item)
      refresh_func = Convert.convert(
        Ops.get(tmp, :refresh),
        :from => "any",
        :to   => "void (any)"
      )
      if refresh_func != nil
        user_data = Ops.get(tmp, :user_data)
        refresh_func.call(user_data)
      end

      nil
    end

    def CallHandle(event)
      event = deep_copy(event)
      tmp = Ops.get(@data, @current_item)
      handle_func = Convert.convert(
        Ops.get(tmp, :handle),
        :from => "any",
        :to   => "void (any, map)"
      )
      if handle_func != nil
        user_data = Ops.get(tmp, :user_data)
        handle_func.call(user_data, event)
      end

      nil
    end

    def CallDestroy
      tmp = Ops.get(@data, @current_item)
      destroy_func = Convert.convert(
        Ops.get(tmp, :destroy),
        :from => "any",
        :to   => "void (any)"
      )
      if destroy_func != nil
        user_data = Ops.get(tmp, :user_data)
        destroy_func.call(user_data)
      end

      nil
    end


    def AddToHistory
      @history = Builtins.filter(@history) { |s| s != @current_item }
      @history = Builtins.prepend(@history, @current_item)

      nil
    end


    # When calling this function the DumbTab widget must already exist.
    #
    # The tab with symbol fallback will be selected if no other tab is found
    # in the tab history.
    def Init(d, fallback)
      d = deep_copy(d)
      @data = deep_copy(d)

      items = Builtins.maplist(@data) { |s, m| s }
      @current_item = Builtins.find(@history) { |s| Builtins.contains(items, s) }

      if @current_item == nil && Builtins.contains(items, fallback)
        @current_item = fallback
      end

      UI.ChangeWidget(:tab, :CurrentItem, @current_item) if @current_item != nil

      @current_item = Convert.to_symbol(UI.QueryWidget(:tab, :CurrentItem))

      CallCreate()

      nil
    end

    def Create
      CallCreate()

      nil
    end

    def Refresh
      CallRefresh()

      nil
    end

    def Handle(event)
      event = deep_copy(event)
      widget = Event.IsMenu(event)

      if widget != nil && Builtins.haskey(@data, widget)
        if widget != @current_item
          CallDestroy()
          @current_item = widget
          AddToHistory()
          CallCreate()
        end
      else
        CallHandle(event)
      end

      nil
    end

    def Destroy
      CallDestroy()

      nil
    end

    publish :variable => :empty_panel, :type => "const term"
    publish :function => :Init, :type => "void (map <symbol, map>, symbol)"
    publish :function => :Create, :type => "void ()"
    publish :function => :Refresh, :type => "void ()"
    publish :function => :Handle, :type => "void (map)"
    publish :function => :Destroy, :type => "void ()"
  end

  TabPanel = TabPanelClass.new
  TabPanel.main
end
