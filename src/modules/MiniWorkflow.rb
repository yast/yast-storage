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

# File:        MiniWorkflow.ycp
# Package:     yast2-storage
# Summary:	Expert Partitioner
# Authors:     Arvin Schnell <aschnell@suse.de>
#
# Tiny wrapper around Sequencer and Wizard.
require "yast"

module Yast
  class MiniWorkflowClass < Module
    def main
      Yast.import "Label"
      Yast.import "Wizard"
      Yast.import "Sequencer"


      @title = ""
    end

    def SetTitle(newtitle)
      @title = newtitle #a je to!

      nil
    end

    def SetContents(contents, help_text)
      contents = deep_copy(contents)
      Wizard.SetContents(@title, contents, help_text, true, true)

      nil
    end


    def SetLastStep(last_step)
      if last_step
        Wizard.SetNextButton(:next, Label.FinishButton)
      else
        Wizard.SetNextButton(:next, Label.NextButton)
      end

      nil
    end


    def UserInput
      Convert.to_symbol(Wizard.UserInput)
    end



    def Run(new_title, new_icon, aliases, sequence, start)
      aliases = deep_copy(aliases)
      sequence = deep_copy(sequence)
      @title = new_title

      Wizard.OpenNextBackDialog
      Wizard.SetContents(@title, Empty(), "", false, false)
      Wizard.SetTitleIcon(
        Builtins.substring(
          new_icon,
          0,
          Ops.subtract(Builtins.size(new_icon), 4)
        )
      )

      sequence = Builtins.mapmap(sequence) do |key, value|
        if key != "ws_start" && Ops.is_map?(value)
          if !Builtins.haskey(Convert.to_map(value), :abort)
            value = Builtins.add(Convert.to_map(value), :abort, :abort)
          end
        end
        { key => value }
      end

      Ops.set(sequence, "ws_start", start)

      ret = Sequencer.Run(aliases, sequence)

      Wizard.CloseDialog

      ret
    end

    publish :function => :SetTitle, :type => "void (string)"
    publish :function => :SetContents, :type => "void (term, string)"
    publish :function => :SetLastStep, :type => "void (boolean)"
    publish :function => :UserInput, :type => "symbol ()"
    publish :function => :Run, :type => "symbol (string, string, map <string, any>, map <string, any>, string)"
  end

  MiniWorkflow = MiniWorkflowClass.new
  MiniWorkflow.main
end
