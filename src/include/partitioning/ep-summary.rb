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
  module PartitioningEpSummaryInclude
    def initialize_partitioning_ep_summary(include_target)
      textdomain "storage"
    end

    def CreateSummaryPanel(user_data)
      user_data = deep_copy(user_data)
      UI.ReplaceWidget(
        :tree_panel,
        Greasemonkey.Transform(
          VBox(
            # dialog heading
            term(
              :IconAndHeading,
              _("Installation Summary"),
              StorageIcons.summary_icon
            ),
            RichText(CompleteSummary())
          )
        )
      )

      # helptext
      helptext = _("<p>This view shows the installation summary.</p>")

      Wizard.RestoreHelp(helptext)

      nil
    end
  end
end
