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
  module PartitioningEpAllInclude
    def initialize_partitioning_ep_all(include_target)
      textdomain "storage"

      Yast.import "PackageCallbacks"
      Yast.import "PackageSystem"
    end

    def CreateAllPanel(user_data)
      user_data = deep_copy(user_data)
      _IsAvailable = lambda do |client|
        #in the installed system, we don't care if the client isn't there
        #as the user will be prompted to install the pkg anyway (in CallConfig)
        if !Stage.initial
          return true
        else
          #check if the client is in inst-sys
          return WFM.ClientExists(client)
        end
      end

      short_hostname = Hostname.CurrentHostname

      fields = StorageSettings.FilterTable(
        [
          :device,
          :udev_path,
          :udev_id,
          :size,
          :format,
          :encrypted,
          :type,
          :fs_type,
          :label,
          :mount_point,
          :mount_by,
          :used_by
        ]
      )

      target_map = Storage.GetTargetMap

      table_header = StorageFields.TableHeader(fields)
      table_contents = StorageFields.TableContents(
        fields,
        target_map,
        fun_ref(StorageFields.method(:PredicateAll), "symbol (map, map)")
      )

      buttons = [
        # push button text
        PushButton(Id(:rescan), Opt(:key_F6), _("Rescan Devices"))
      ]

      if Mode.installation
        # push button text
        buttons = Builtins.add(
          buttons,
          PushButton(Id(:import), _("Import Mount Points..."))
        )
      end

      buttons = Builtins.add(buttons, HStretch())

      configs = []

      if true
        # menu entry text
        configs = Builtins.add(
          configs,
          Item(
            Id(:cryptpwd),
            term(:icon, "yast-encrypted"),
            _("Provide Crypt &Passwords...")
          )
        )
      end

      if _IsAvailable.call("iscsi-client")
        # menu entry text
        configs = Builtins.add(
          configs,
          Item(
            Id(:iscsi),
            term(:icon, "yast-iscsi-client"),
            _("Configure &iSCSI...")
          )
        )
      end

      if true
        # menu entry text
        configs = Builtins.add(
          configs,
          Item(
            Id(:multipath),
            term(:icon, "yast-iscsi-server"),
            _("Configure &Multipath...")
          )
        )
      end

      if Arch.s390 && _IsAvailable.call("dasd")
        # menu entry text
        configs = Builtins.add(
          configs,
          Item(Id(:dasd), term(:icon, "yast-dasd"), _("Configure &DASD..."))
        )
      end

      if Arch.s390 && _IsAvailable.call("zfcp")
        # menu entry text
        configs = Builtins.add(
          configs,
          Item(Id(:zfcp), term(:icon, "yast-zfcp"), _("Configure &zFCP..."))
        )
      end

      if Arch.s390 && _IsAvailable.call("xpram")
        # menu entry text
        configs = Builtins.add(
          configs,
          Item(Id(:xpram), term(:icon, "yast-xpram"), _("Configure &XPRAM..."))
        )
      end

      if !Builtins.isempty(configs)
        # menu button text
        buttons = Builtins.add(
          buttons,
          MenuButton(Opt(:key_F7), _("Configure..."), configs)
        )
      end


      UI.ReplaceWidget(
        :tree_panel,
        Greasemonkey.Transform(
          VBox(
            # dialog heading, %1 is replaced with hostname
            term(
              :IconAndHeading,
              Builtins.sformat(_("Available Storage on %1"), short_hostname),
              StorageIcons.all_icon
            ),
            Table(
              Id(:table),
              Opt(:keepSorting, :notify, :notifyContextMenu),
              table_header,
              table_contents
            ),
            ArrangeButtons(buttons)
          )
        )
      )

      # helptext
      helptext = _("<p>This view shows all storage devices\navailable.</p>")

      display_info = UI.GetDisplayInfo

      if !Ops.get_boolean(display_info, "TextMode", false)
        # helptext
        helptext = Ops.add(
          helptext,
          _(
            "<p>By double clicking a table entry,\n" +
              "you navigate to the view with detailed information about the\n" +
              "device.</p>\n"
          )
        )
      else
        # helptext
        helptext = Ops.add(
          helptext,
          _(
            "<p>By selecting a table entry you can\nnavigate to the view with detailed information about the device.</p>"
          )
        )
      end

      Wizard.RestoreHelp(Ops.add(helptext, StorageFields.TableHelptext(fields)))

      nil
    end


    def HandleAllPanel(user_data, event)
      user_data = deep_copy(user_data)
      event = deep_copy(event)
      _CheckAndInstallPackages = lambda do |pkgs|
        pkgs = deep_copy(pkgs)
        return true if Stage.initial

        ret = false
        #switch off pkg-mgmt loading progress dialogs,
        #because it just plain sucks
        PackageCallbacks.RegisterEmptyProgressCallbacks
        ret = PackageSystem.CheckAndInstallPackages(pkgs)
        PackageCallbacks.RestorePreviousProgressCallbacks

        ret
      end

      _CallConfig = lambda do |text, pkgs, call|
        pkgs = deep_copy(pkgs)
        doit = true

        if !Storage.EqualBackupStates("expert-partitioner", "", true)
          doit = Popup.YesNo(text)
        end

        if doit
          if pkgs == nil || _CheckAndInstallPackages.call(pkgs)
            if call != nil
              Storage.ActivateHld(false)
              WFM.call(call)
            end

            RescanDisks()
            Storage.CreateTargetBackup("expert-partitioner")

            UpdateMainStatus()
            UpdateNavigationTree(nil)
            TreePanel.Create
          end
        end

        nil
      end

      case Event.IsWidgetActivated(event)
        when :rescan
          # popup text
          _CallConfig.call(
            _(
              "Rescaning disks cancels all current changes.\nReally rescan disks?"
            ),
            nil,
            nil
          )
        when :import
          ImportMountPoints()

          UpdateMainStatus()
          UpdateNavigationTree(nil)
          TreePanel.Create
      end

      case Event.IsMenu(event)
        when :iscsi
          # popup text
          _CallConfig.call(
            _(
              "Calling iSCSI configuration cancels all current changes.\nReally call iSCSI configuration?"
            ),
            ["yast2-iscsi-client"],
            "iscsi-client"
          )
        when :multipath
          if ProductFeatures.GetBooleanFeature(
              "partitioning",
              "use_separate_multipath_module"
            ) == true ||
              Mode.normal && WFM.ClientExists("multipath")
            # popup text
            _CallConfig.call(
              _(
                "Calling multipath configuration cancels all current changes.\nReally call multipath configuration?\n"
              ),
              ["yast2-multipath"],
              "multipath"
            )
          else
            # popup text
            _CallConfig.call(
              _(
                "Calling multipath configuration cancels all current changes.\nReally call multipath configuration?\n"
              ),
              nil,
              "multipath-simple"
            )
          end
        when :cryptpwd
          @tg = Storage.GetTargetMap
          @tg = Storage.AskCryptPasswords(@tg)
          Storage.SetTargetMap(@tg)
          UpdateMainStatus()
          UpdateNavigationTree(nil)
          TreePanel.Create
        when :dasd
          # popup text
          _CallConfig.call(
            _(
              "Calling DASD configuration cancels all current changes.\nReally call DASD configuration?"
            ),
            ["yast2-s390"],
            "dasd"
          )
        when :zfcp
          # popup text
          _CallConfig.call(
            _(
              "Calling zFCP configuration cancels all current changes.\nReally call zFCP configuration?"
            ),
            ["yast2-s390"],
            "zfcp"
          )
        when :xpram
          # popup text
          _CallConfig.call(
            _(
              "Calling XPRAM configuration cancels all current changes.\nReally call XPRAM configuration?"
            ),
            ["yast2-s390"],
            "xpram"
          )
      end

      case Event.IsWidgetContextMenuActivated(event)
        when :table
          @device = Convert.to_string(UI.QueryWidget(Id(:table), :CurrentItem))
          EpContextMenuDevice(@device)
      end

      nil
    end
  end
end
