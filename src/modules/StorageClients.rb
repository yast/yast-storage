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

# Module:		StorageClients.ycp
#
# Authors:		Thomas Fehr <fehr@suse.de>
#			Arvin Schnell <arvin@suse.de>
#
# Purpose:		Define callbacks for libstorage.
require "yast"
require "storage"


module Yast
  class StorageClientsClass < Module
    def main
      Yast.import "UI"

      Yast.import "Label"
      Yast.import "Mode"
      Yast.import "Popup"
      Yast.import "Report"
      Yast.import "SlideShow"
      Yast.import "StorageCallbacks"

      textdomain "storage"


      @sint = nil


      @enable_popup = false
      @texts = []

      @total_actions = 0
      @current_action = 0
    end

    def ProgressBar(id, cur, max)
      f = Ops.divide(Ops.multiply(100, cur), max)
      SlideShow.SubProgress(f, nil)
      SlideShow.GenericHandleInput

      nil
    end

    def EnablePopup
      Builtins.y2milestone("EnablePopup")
      @enable_popup = true
      if Ops.greater_than(Builtins.size(@texts), 0)
        Builtins.y2milestone("EnablePopup texts:%1", @texts)
        Builtins.foreach(@texts) { |s| Report.Message(s) }
      end
      @texts = []

      nil
    end


    def ShowInstallInfo(text)
      SlideShow.SubProgressStart(text)
      SlideShow.AppendMessageToInstLog(text)

      @current_action = Ops.add(@current_action, 1)

      # hack: assume every text change means another action
      Builtins.y2milestone(
        "Current action: %1, total stage progress: %2",
        @current_action,
        Ops.divide(Ops.multiply(@current_action, 100), @total_actions)
      )
      SlideShow.StageProgress(
        Ops.divide(Ops.multiply(@current_action, 100), @total_actions),
        nil
      )

      nil
    end


    def InfoPopup(text)
      Builtins.y2milestone("InfoPopup enable:%1 txt:%2", @enable_popup, text)
      if @enable_popup
        Report.Message(text)
      else
        @texts = Builtins.add(@texts, text)
      end

      nil
    end

    def YesNoPopup(text)
      Builtins.y2milestone("YesNoPopup txt:%1", text)
      Report.AnyQuestion(
        Popup.NoHeadline,
        text,
        Label.YesButton,
        Label.NoButton,
        :yes
      )
    end


    def CommitErrorPopup(error, last_action, extended_message)
      Builtins.y2milestone(
        "CommitErrorPopup error:%1 last_action:%2 extended_message:%3",
        error,
        last_action,
        extended_message
      )

      tmp1 = Builtins.splitstring(extended_message, "\n")
      if Ops.greater_than(Builtins.size(tmp1), 5)
        tmp1 = Builtins.sublist(tmp1, 0, 5)
        tmp1 = Ops.add(tmp1, "...")
      end
      extended_message = Builtins.mergestring(tmp1, "\n")

      text = Ops.add(
        Ops.add(
          _("Failure occurred during the following action:") + "\n",
          last_action
        ),
        "\n\n"
      )

      Builtins.y2milestone("before getErrorString error:%1", error )
      tmp = @sint.getErrorString(error).force_encoding("UTF-8")
      Builtins.y2milestone("before getErrorString ret:%1", tmp )
      text = Ops.add(Ops.add(text, tmp), "\n\n") if !Builtins.isempty(tmp)

      text = Ops.add(
        Ops.add(text, Builtins.sformat(_("System error code was: %1"), error)),
        "\n\n"
      )

      if !Builtins.isempty(extended_message)
        text = Ops.add(Ops.add(text, extended_message), "\n\n")
      end

      text = Ops.add(text, _("Continue despite the error?"))

      ret = Report.ErrorAnyQuestion(
        Popup.NoHeadline,
        text,
        Label.ContinueButton,
        Label.AbortButton,
        :focus_no
      )
      if Mode.autoinst
        ex = Report.Export
        if Ops.get_boolean(ex, ["yesno_messages", "show"], true) == false ||
            Ops.greater_than(
              Ops.get_integer(ex, ["yesno_messages", "timeout"], 0),
              0
            )
          ret = true
        end
      end
      Builtins.y2milestone("CommitErrorPopup ret:%1", ret)
      ret
    end


    def PasswordPopup(device, attempts, password)
      Builtins.y2milestone(
        "PasswordPopup device:%1 attempts:%2",
        device,
        attempts
      )

      password = ""

      UI.OpenDialog(
        Opt(:decorated),
        VBox(
          Password(
            Id(:password),
            # Label: get password for device
            # Please use newline if label is longer than 40 characters
            Builtins.sformat(_("&Enter Password for Device %1:"), device),
            password
          ),
          ButtonBox(
            PushButton(Id(:ok), Opt(:default), Label.OKButton),
            PushButton(Id(:cancel), Label.CancelButton)
          )
        )
      )

      UI.SetFocus(Id(:password))

      ret = Convert.to_symbol(UI.UserInput)

      if ret == :ok
        password = Convert.to_string(UI.QueryWidget(Id(:password), :Value))
      end

      UI.CloseDialog

      [ret == :ok, password]
    end


    def InstallCallbacks(value)
      Builtins.y2milestone("InstallCallbacks")

      @sint = value

      StorageCallbacks.ProgressBar("StorageClients::ProgressBar")
      StorageCallbacks.ShowInstallInfo("StorageClients::ShowInstallInfo")
      StorageCallbacks.InfoPopup("StorageClients::InfoPopup")
      StorageCallbacks.YesNoPopup("StorageClients::YesNoPopup")
      StorageCallbacks.CommitErrorPopup("StorageClients::CommitErrorPopup")
      StorageCallbacks.PasswordPopup("StorageClients::PasswordPopup")

      nil
    end

    publish :variable => :total_actions, :type => "integer"
    publish :function => :ProgressBar, :type => "void (string, integer, integer)"
    publish :function => :EnablePopup, :type => "void ()"
    publish :function => :ShowInstallInfo, :type => "void (string)"
    publish :function => :InfoPopup, :type => "void (string)"
    publish :function => :YesNoPopup, :type => "boolean (string)"
    publish :function => :CommitErrorPopup, :type => "boolean (integer, string, string)"
    publish :function => :PasswordPopup, :type => "list (string, integer, string)"
    publish :function => :InstallCallbacks, :type => "void (any)"
  end

  StorageClients = StorageClientsClass.new
  StorageClients.main
end
