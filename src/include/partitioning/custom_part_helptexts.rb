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

#  *************************************************************
#  *
#  *     YaST2      SuSE Labs                        -o)
#  *     --------------------                        /\\
#  *                                                _\_v
#  *           www.suse.de / www.suse.com
#  * ----------------------------------------------------------
#  *
#  * Name:          partitioning/custom_part_helptexts.ycp
#  *
#  * Author:        Michael Hager <mike@suse.de>
#  *
#  * Description:   Partitioner for experts.
#  *
#  *
#  * Purpose:       contains the big helptext
#  *
#  *
#  *
#  *************************************************************
#
#  $Id$
#
module Yast
  module PartitioningCustomPartHelptextsInclude
    def initialize_partitioning_custom_part_helptexts(include_target)
      textdomain "storage"
    end

    def GetCreateCryptFsHelptext(minpwlen, format, tmpcrypt)
      helptext = ""

      if format
        # help text for cryptofs
        helptext = _(
          "<p>\n" +
            "Create an encrypted file system.\n" +
            "</p>\n"
        )
      else
        # help text for cryptofs
        helptext = _(
          "<p>\n" +
            "Access an encrypted file system.\n" +
            "</p>\n"
        )
      end

      # help text for cryptofs
      helptext = Ops.add(
        helptext,
        _(
          "<p>\n" +
            "Keep in mind that this file system is only protected when it is not\n" +
            "mounted. Once it is mounted, it is as secure as every other\n" +
            "Linux file system.\n" +
            "</p>\n"
        )
      )


      if format
        if tmpcrypt
          helptext = Ops.add(
            helptext,
            _(
              "<p>\n" +
                "This mount point corresponds to a temporary filesystem like /tmp or /var/tmp.\n" +
                "If you leave the encryption password empty, the system will create\n" +
                "a random password at system startup for you. This means, you will lose all\n" +
                "data on these filesystems at system shutdown.\n" +
                "</p>\n"
            )
          )
        end
        # help text, continued
        helptext = Ops.add(
          helptext,
          _(
            "<p>\n" +
              "If you forget your password, you will lose access to the data on your file system.\n" +
              "Choose your password carefully. A combination of letters and numbers\n" +
              "is recommended. To ensure the password was entered correctly,\n" +
              "enter it twice.\n" +
              "</p>\n"
          )
        )

        # help text, continued
        helptext = Ops.add(
          helptext,
          Builtins.sformat(
            _(
              "<p>\n" +
                "You must distinguish between uppercase and lowercase. A password should have at\n" +
                "least %1 characters and, as a rule, not contain any special characters\n" +
                "(e.g., letters with accents or umlauts).\n" +
                "</p>\n"
            ),
            minpwlen
          )
        )

        # help text, continued
        helptext = Ops.add(
          helptext,
          Builtins.sformat(
            _(
              "<p>\n" +
                "Possible characters are\n" +
                "<tt>%1</tt>, blanks, uppercase and lowercase\n" +
                "letters (<tt>A-Za-Z</tt>), and digits <tt>0</tt> to <tt>9</tt>.\n" +
                "</p>\n"
            ),
            "#*,.;:._-+!$%&/|?{[()]}^\\&lt;&gt;!"
          )
        )
      end

      # help text, continued
      helptext = Ops.add(helptext, _("<p>\nDo not forget this password!\n</p>"))

      helptext
    end


    def GetUpdateCryptFsHelptext
      # help text for cryptofs
      helptext = _(
        "<p>\n" +
          "You will need to enter your encryption password.\n" +
          "</p>\n"
      )

      # help text, continued
      helptext = Ops.add(
        helptext,
        _(
          "<p>\n" +
            "If the encrypted file system does not contain any system file and therefore is\n" +
            "not needed for the update, you may select <b>Skip</b>. In this case, the\n" +
            "file system is not accessed during update.\n" +
            "</p>\n"
        )
      )

      helptext
    end


    def ia64_gpt_text
      _(
        "Warning: With your current setup, your installation\n" +
          "will encounter problems when booting, because the disk on which  \n" +
          "your /boot partition is located does not contain a GPT disk label.\n" +
          "\n" +
          "It will probably not be possible to boot such a setup.\n" +
          "\n" +
          "If you need to use this disk for installation, you should destroy \n" +
          "the disk label in the expert partitioner.\n"
      )
    end

    def ia64_gpt_fix_text
      _(
        "Warning: Your system states that it reqires an EFI \n" +
          "boot setup. Since the selected disk does not contain a \n" +
          "GPT disk label YaST will create a GPT label on this disk.\n" +
          "\n" +
          "You need to mark all partitions on this disk for removal.\n"
      )
    end
  end
end
