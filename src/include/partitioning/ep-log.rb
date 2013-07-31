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
  module PartitioningEpLogInclude
    def initialize_partitioning_ep_log(include_target)
      textdomain "storage"

      Yast.import "LogViewCore"
    end

    def CreateLogPanel(user_data)
      user_data = deep_copy(user_data)
      file = "/var/log/messages"

      UI.ReplaceWidget(
        :tree_panel,
        Greasemonkey.Transform(
          VBox(
            # heading
            term(:IconAndHeading, _("Log"), StorageIcons.log_icon),
            # label for log view
            LogView(
              Id(:log),
              Builtins.sformat(_("Contents of %1:"), file),
              10,
              0
            ),
            # push button text
            PushButton(Id(:update), _("Update"))
          )
        )
      )

      # helptext, %1 is replaced by a filename
      helptext = Builtins.sformat(_("This view shows the content of %1."), file)

      Wizard.RestoreHelp(helptext)

      LogViewCore.Start(Id(:log), { "file" => file })

      nil
    end


    def HandleLogPanel(user_data, event)
      user_data = deep_copy(user_data)
      event = deep_copy(event)
      case Event.IsWidgetActivated(event)
        when :update
          LogViewCore.Update(Id(:log))
      end

      case Event.IsTimeout(event)
        when :timeout
          LogViewCore.Update(Id(:log))
      end

      nil
    end


    def DestroyLogPanel(user_data)
      user_data = deep_copy(user_data)
      LogViewCore.Stop

      nil
    end
  end
end
