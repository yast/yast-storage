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
# The Tree widget must have id `tree.  The ids of the items of the Tree
# widget must be made of symbols or strings.
require "yast"

module Yast
  class TreePanelClass < Module
    def main
      Yast.import "UI"


      Yast.import "Event"


      @data = nil

      @current_item = nil


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


    # Initialises internal data and calls the create function of the
    # selected panel.
    #
    # When calling this function the Tree widget must already exist.
    def Init(d)
      d = deep_copy(d)
      @data = deep_copy(d)

      @current_item = UI.QueryWidget(:tree, :CurrentItem)
      CallCreate()

      nil
    end

    # Update the contents of the Tree widget.
    def Update(d, tree, new_item)
      d = deep_copy(d)
      tree = deep_copy(tree)
      new_item = deep_copy(new_item)
      old_item = deep_copy(@current_item)

      UI.ChangeWidget(:tree, :Items, tree)

      if new_item == nil
        UI.ChangeWidget(:tree, :CurrentItem, @current_item)
      else
        UI.ChangeWidget(:tree, :CurrentItem, new_item)
      end

      new_item = UI.QueryWidget(:tree, :CurrentItem)

      if old_item != new_item
        CallDestroy()
        @data = deep_copy(d)
        @current_item = deep_copy(new_item)
        CallCreate()
      else
        @data = deep_copy(d)
      end

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

    # Handle user input by either switching the panel or delegating the input
    # to the selected panel.
    def Handle(event)
      event = deep_copy(event)
      widget = Event.IsWidgetActivatedOrSelectionChanged(event)

      if widget == :tree
        new_current_item = UI.QueryWidget(:tree, :CurrentItem)
        if new_current_item != @current_item
          CallDestroy()
          @current_item = deep_copy(new_current_item)
          CallCreate()
        end
      else
        CallHandle(event)
      end

      nil
    end

    # Set new active item of the tree ( + replace main dlg content accordingly)
    def SwitchToNew(new_current_item)
      new_current_item = deep_copy(new_current_item)
      if @current_item != new_current_item
        UI.ChangeWidget(:tree, :CurrentItem, new_current_item)
        CallDestroy()
        @current_item = deep_copy(new_current_item)
        CallCreate()
      end

      nil
    end

    # Delegating destroying to the selected panel.
    def Destroy
      CallDestroy()

      nil
    end

    publish :variable => :empty_panel, :type => "const term"
    publish :function => :Init, :type => "void (map <any, map>)"
    publish :function => :Update, :type => "void (map <any, map>, list <term>, any)"
    publish :function => :Create, :type => "void ()"
    publish :function => :Refresh, :type => "void ()"
    publish :function => :Handle, :type => "void (map)"
    publish :function => :SwitchToNew, :type => "void (any)"
    publish :function => :Destroy, :type => "void ()"
  end

  TreePanel = TreePanelClass.new
  TreePanel.main
end
