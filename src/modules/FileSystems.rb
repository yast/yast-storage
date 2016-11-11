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

# Module: 		FileSystems.ycp
#
# Authors:		Johannes Buchhold (jbuch@suse.de)
#		Arvin Schnell <aschnell@suse.de>
#
# Purpose:
# These module contains the supported filesystems and their settings.
#
#
# $Id$
require "storage"
require "yast"
require "yast2/execute"

module Yast
  class FileSystemsClass < Module
    include Yast::Logger

    # @return [Array<String>] Supported default subvolume names
    SUPPORTED_DEFAULT_SUBVOLUME_NAMES = ["", "@"].freeze

    # @return [String] Default subvolume name.
    attr_reader :default_subvol

    def main

      textdomain "storage"

      Yast.import "Arch"
      Yast.import "String"
      Yast.import "Partitions"
      Yast.import "Encoding"
      Yast.import "Stage"
      Yast.import "StorageInit"
      Yast.import "ProductFeatures"

      @conv_fs = {
        "def_sym" => :unknown,
        "def_int" => ::Storage::FSUNKNOWN,
        "m"       => {
          ::Storage::REISERFS => :reiser,
          ::Storage::EXT2     => :ext2,
          ::Storage::EXT3     => :ext3,
          ::Storage::EXT4     => :ext4,
          ::Storage::BTRFS    => :btrfs,
          ::Storage::VFAT     => :vfat,
          ::Storage::XFS      => :xfs,
          ::Storage::JFS      => :jfs,
          ::Storage::HFS      => :hfs,
          ::Storage::NTFS     => :ntfs,
          ::Storage::SWAP     => :swap,
          ::Storage::NFS      => :nfs,
          ::Storage::NFS4     => :nfs4,
          ::Storage::TMPFS    => :tmpfs,
          ::Storage::ISO9660  => :iso9660,
          ::Storage::UDF      => :udf,
          ::Storage::FSNONE   => :none
        }
      }


      # filesystems possible for root volume. used during scan for root volumes.
      @possible_root_fs = [:ext2, :ext3, :ext4, :btrfs, :reiser, :xfs]
      @swap_m_points = ["swap"]
      @tmp_m_points = ["/tmp", "/var/tmp"]
      @default_subvol = "UNDEFINED"

      @suggest_m_points = []
      @suggest_tmp_points = []


      @nchars = "0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"

      @sint = nil


      @FstabOptionStrings = [
        "defaults",
        "auto",
        "noauto",
        "atime",
        "noatime",
        "ro",
        "rw",
        "user",
        "nouser",
        "acl",
        "noacl",
        "user_xattr",
        "no_user_xattr",
        "data=journal",
        "data=ordered",
        "data=writeback",
        "dev",
        "nodev",
        "exec",
        "noexec",
        "suid",
        "nosuid",
        "async",
        "sync",
        "dirsync",
        "procuid",
        "barrier=none",
        "fs=floppyfss",
        "fs=cdfss",
        "users",
        "gid=users",
        "usrquota",
        "grpquota"
      ]

      @FstabOptionRegex = [
        "pri=[0-9]+",
        "iocharset=.+",
        "utf8=.*",
        "nls=.+",
        "codepage=.+",
        "gid=[0-9]+",
        "umask=[0-7]+",
        "loop=.+",
        "encryption=.+",
        "pri=[0-9]+",
        "locale=.+",
        "fmask=[0-7]+",
        "dmask=[0-7]+",
        "usrjquota=.+",
        "grpjquota=.+",
        "jqfmt=.+"
      ]


      @FstabDefaultMap = {
        "pts"    => {
          "spec"    => "devpts",
          "mount"   => "/dev/pts",
          "vfstype" => "devpts",
          "mntops"  => "mode=0620,gid=5",
          "freq"    => 0,
          "passno"  => 0
        },
        "proc"   => {
          "spec"    => "proc",
          "mount"   => "/proc",
          "vfstype" => "proc",
          "mntops"  => "defaults",
          "freq"    => 0,
          "passno"  => 0
        },
        "sys"    => {
          "spec"    => "sysfs",
          "mount"   => "/sys",
          "vfstype" => "sysfs",
          "mntops"  => "noauto",
          "freq"    => 0,
          "passno"  => 0
        },
        "debug"  => {
          "spec"    => "debugfs",
          "mount"   => "/sys/kernel/debug",
          "vfstype" => "debugfs",
          "mntops"  => "noauto",
          "freq"    => 0,
          "passno"  => 0
        },
        "swap"   => {
          "spec"    => "",
          "mount"   => "swap",
          "vfstype" => "swap",
          "mntops"  => "default",
          "freq"    => 0,
          "passno"  => 0
        },
        "root"   => {
          "spec"    => "",
          "mount"   => "",
          "vfstype" => "auto",
          "mntops"  => "defaults",
          "freq"    => 1,
          "passno"  => 1
        },
        "dev"    => {
          "spec"    => "",
          "mount"   => "",
          "vfstype" => "auto",
          "mntops"  => "noauto,user",
          "freq"    => 0,
          "passno"  => 0
        },
        "nfs"    => {
          "spec"    => "",
          "mount"   => "",
          "vfstype" => "nfs",
          "mntops"  => "defaults",
          "freq"    => 0,
          "passno"  => 0
        },
        "usb"    => {
          "spec"    => "usbfs",
          "mount"   => "/proc/bus/usb",
          "vfstype" => "usbfs",
          "mntops"  => "noauto",
          "freq"    => 0,
          "passno"  => 0
        },
        "cdrom"  => {
          "spec"    => "",
          "mount"   => "",
          "vfstype" => "subfs",
          "mntops"  => "noauto,fs=cdfss,ro,procuid,nosuid,nodev,exec",
          "freq"    => 0,
          "passno"  => 0
        },
        "floppy" => {
          "spec"    => "",
          "mount"   => "",
          "vfstype" => "auto",
          "mntops"  => "noauto,user,sync",
          "freq"    => 0,
          "passno"  => 0
        },
        "zip"    => {
          "spec"    => "",
          "mount"   => "",
          "vfstype" => "auto",
          "mntops"  => "noauto,user",
          "freq"    => 0,
          "passno"  => 0
        },
        "data"   => {
          "spec"    => "",
          "mount"   => "",
          "vfstype" => "auto",
          "mntops"  => "noauto,user",
          "freq"    => 0,
          "passno"  => 0
        }
      }

      # All supported filesystems
      @support = {
        :xfs        => true,
        :ext2       => true,
        :ext3       => true,
        :ext4       => true,
        :btrfs      => true,
        :jfs        => false,
        :vfat       => true,
        :ntfs       => true,
        :xxefi      => false,
        :xbootdisk  => false,
        :xxbootdisk => false,
        :xbootfat   => false,
        :xhibernate => true,
        :raid       => true,
        :lvm        => true
      }

      @unsupportFs = []

      @tmpfs_fst_options = [
        {
          :widget             => TextEntry(
            Id("tmpfs_size"),
            Opt(:hstretch),
            # label text
            _("Tmpfs &Size"),
            ""
          ),
          :query_key          => "tmpfs_size",
          :between            => [1, 200],
          :empty_allowed      => true,
          :min_size           => 100 * 1024,
          :valid_chars        => "0123456789kKmMgG%",
          # popup text
          :error_text         => _(
            "Invalid Size specified. Use number followed by K, M, G or %.\nValue must be above 100k or between 1% and 200%. Try again."
          ),
          :error_text_percent => _(
            "Value must be between 1% and 200%. Try again."
          ),
          :type               => :text,
          :str_opt            => "size=%1",
          :str_scan           => "size=(.*)",
          # help text, richtext format
          :help_text          => _(
            "<p><b>Tmpfs Size:</b>\n" +
              "Size may be either entered as a number followed by K,M,G for Kilo-, Mega- or Gigabyte or\n" +
              "as a number followed by a percent sign meaning percentage of memory.</p>"
          )
        }
      ]

      @swap_fst_options = [
        {
          :widget        => TextEntry(
            Id("priority"),
            Opt(:hstretch),
            # label text
            _("Swap &Priority"),
            "42"
          ),
          :query_key     => "priority",
          :between       => [0, 32767],
          :empty_allowed => true,
          :valid_chars   => "0123456789",
          # popup text
          :error_text    => _(
            "Value must be between 0 and 32767. Try again."
          ),
          :type          => :text,
          :str_opt       => "pri=%1",
          :str_scan      => "pri=(.*)",
          # help text, richtext format
          :help_text     => _(
            "<p><b>Swap Priority:</b>\nEnter the swap priority. Higher numbers mean higher priority.</p>\n"
          )
        }
      ]

      @SwapFileSystems = {
        :swap => {
          :name            => "Swap",
          :fsid            => Partitions.fsid_swap,
          :real_fs         => true,
          :supports_format => true,
          :fsid_item       => "0x82 Linux swap ",
          :fstype          => "Linux swap",
          :crypt           => true,
          :fst_options     => @swap_fst_options,
          :mountpoints     => @swap_m_points
        }
      }


      @PseudoFileSystems = {
        :lvm        => {
          :name            => "LVM",
          :fsid            => Partitions.fsid_lvm,
          :supports_format => false,
          :fsid_item       => "0x8E Linux LVM "
        },
        :raid       => {
          :name            => "RAID",
          :fsid            => Partitions.fsid_raid,
          :supports_format => false,
          :fsid_item       => "0xFD Linux RAID "
        },
        :xbootdisk  => {
          :name            => "PReP",
          :fsid            => Partitions.fsid_prep_chrp_boot,
          :supports_format => false,
          :fsid_item       => "0x41 PReP Boot"
        },
        :xxbootdisk  => {
          :name            => "GPT PReP",
          :fsid            => Partitions.fsid_gpt_prep,
          :supports_format => false,
          :label           => "gpt",
          :fsid_item       => "0x00 GPT PReP Boot"
        },
        :xbootfat   => {
          :name            => "FATBOOT",
          :fsid            => Partitions.fsid_fat16,
          :supports_format => false,
          :fsid_item       => "0x06 FAT16 Boot"
        },
        :xhibernate => {
          :name            => "Hibernate",
          :fsid            => Partitions.fsid_hibernation,
          :supports_format => false,
          :fsid_item       => "0xA0 Hibernation"
        },
        :xxbios     => {
          :name            => "BIOS Grub",
          :fsid            => Partitions.fsid_bios_grub,
          :supports_format => false,
          :label           => "gpt",
          :fsid_item       => "0x00 BIOS Grub"
        },
        :xxefi      => {
          :name            => "Efi Boot",
          :fsid            => Partitions.fsid_gpt_boot,
          :supports_format => false,
          :label           => "gpt",
          :fsid_item       => "0x00 EFI Boot"
        }
      }

      @lenc = {
        "el" => "iso8859-7",
        "hu" => "iso8859-2",
        "cs" => "iso8859-2",
        "hr" => "iso8859-2",
        "sl" => "iso8859-2",
        "sk" => "iso8859-2",
        "en" => "iso8859-1",
        "tr" => "iso8859-9",
        "lt" => "iso8859-13",
        "bg" => "iso8859-5",
        "ru" => "iso8859-5"
      }
      FileSystems()
    end

    def fromSymbol(conv, val)
      conv = deep_copy(conv)
      ret = Ops.get_integer(conv, "def_int", -1)
      Builtins.foreach(Ops.get_map(conv, "m", {})) { |i, s| ret = i if s == val }
      ret
    end


    def system_m_points
      ["/", "/usr", "/var", "/opt", Partitions.BootMount]
    end
    def crypt_m_points
      ["/", Partitions.BootMount, "/usr"]
    end

    def SuggestMPoints
      if Builtins.size(@suggest_m_points) == 0
        @suggest_m_points = ["/home", "/srv", "/tmp", "/usr/local"]
        order_m_mpoints = {
          "/"                  => 1,
          "/home"              => 2,
          "/var"               => 3,
          "/opt"               => 4,
          Partitions.BootMount => 5
        }
        non_proposed_m_points = ["/usr"]
        if Stage.initial
          @suggest_m_points = Convert.convert(
            Builtins.union(system_m_points, @suggest_m_points),
            :from => "list",
            :to   => "list <string>"
          )
        end
        @suggest_m_points = Builtins.filter(@suggest_m_points) do |s|
          !Builtins.contains(non_proposed_m_points, s)
        end
        @suggest_m_points = Builtins.sort(@suggest_m_points) do |a, b|
          Ops.get(order_m_mpoints, a, 99) == Ops.get(order_m_mpoints, b, 99) ?
            Ops.less_or_equal(a, b) :
            Ops.less_or_equal(
              Ops.get(order_m_mpoints, a, 99),
              Ops.get(order_m_mpoints, b, 99)
            )
        end
        Builtins.y2milestone("SuggestMPoints ret:%1", @suggest_m_points)
      end
      deep_copy(@suggest_m_points)
    end


    def SuggestTmpfsMPoints
      if Builtins.size(@suggest_tmp_points) == 0
        @suggest_tmp_points = ["/run", "/var/run", "/tmp", "/var/lock"]
        Builtins.y2milestone("SuggestTmpfsMPoints ret:%1", @suggest_tmp_points)
      end
      deep_copy(@suggest_tmp_points)
    end


    def GetGeneralFstabOptions
      options = [
        {
          # button text
          :widget    => Left(
            CheckBox(Id("opt_readonly"), _("Mount &Read-Only"), false)
          ),
          :query_key => "opt_readonly",
          # help text, richtext format
          :help_text => _(
            "<p><b>Mount Read-Only:</b>\n" +
              "Writing to the file system is not possible. Default is false. During installation\n" +
              "the file system is always mounted read-write.</p>"
          ),
          :type      => :boolean,
          :str_opt   => { 1 => "ro", "default" => "" },
          :str_scan  => [["ro", 1], ["rw", 0]]
        },
        {
          # button text
          :widget    => Left(
            CheckBox(Id("opt_noatime"), _("No &Access Time"), false)
          ),
          :query_key => "opt_noatime",
          # help text, richtext format
          :help_text => _(
            "<p><b>No Access Time:</b>\nAccess times are not updated when a file is read. Default is false.</p>\n"
          ),
          :type      => :boolean,
          :str_opt   => { 1 => "noatime", "default" => "" },
          :str_scan  => [["noatime", 1], ["atime", 0]]
        },
        {
          # button text
          :widget    => Left(
            CheckBox(Id("opt_user"), _("Mountable by User"), false)
          ),
          :query_key => "opt_user",
          # help text, richtext format
          :help_text => _(
            "<p><b>Mountable by User:</b>\nThe file system may be mounted by an ordinary user. Default is false.</p>\n"
          ),
          :type      => :boolean,
          :str_opt   => { 1 => "user", "default" => "" },
          :str_scan  => [["nouser", 0], ["user", 1]]
        },
        {
          # button text
          :widget    => Left(
            CheckBox(
              Id("opt_noauto"),
              Opt(:notify),
              _("Do Not Mount at System &Start-up"),
              false
            )
          ),
          :query_key => "opt_noauto",
          # help text, richtext format
          :help_text => _(
            "<p><b>Do Not Mount at System Start-up:</b>\n" +
              "The file system is not automatically mounted when the system starts.\n" +
              "An entry in /etc/fstab is created and the file system is mounted\n" +
              "with the appropriate options when the command <tt>mount &lt;mount point&gt;</tt>\n" +
              "is entered (&lt;mount point&gt; is the directory to which the file system is mounted). Default is false.</p>\n"
          ),
          :type      => :boolean,
          :str_opt   => { 1 => "noauto", "default" => "" },
          :str_scan  => [["noauto", 1], ["auto", 0]]
        },
        {
          # button text
          :widget    => Left(
            CheckBox(
              Id("opt_quota"),
              Opt(:notify),
              _("Enable &Quota Support"),
              false
            )
          ),
          :query_key => "opt_quota",
          # help text, richtext format
          :help_text => _(
            "<p><b>Enable Quota Support:</b>\n" +
              "The file system is mounted with user quotas enabled.\n" +
              "Default is false.</p>\n"
          ),
          :type      => :boolean
        }
      ]
      deep_copy(options)
    end

    def GetJournalFstabOptions
      options = [
        {
          :widget    => VBox(
            ComboBox(
              Id("opt_journal"),
              Opt(:hstretch),
              # label text
              _("Data &Journaling Mode"),
              ["journal", "ordered", "writeback"]
            ),
            VSpacing(0.5)
          ),
          :default   => "ordered",
          :query_key => "opt_journal",
          :type      => :text,
          # help text, richtext format
          :help_text => _(
            "<p><b>Data Journaling Mode:</b>\n" +
              "Specifies the journaling mode for file data.\n" +
              "<tt>journal</tt> -- All data is committed to the journal prior to being\n" +
              "written into the main file system. Highest performance impact.<br>\n" +
              "<tt>ordered</tt> -- All data is forced directly out to the main file system\n" +
              "prior to its metadata being committed to the journal. Medium performance impact.<br>\n" +
              "<tt>writeback</tt> -- Data ordering is not preserved. No performance impact.</p>\n"
          ),
          :str_opt   => "data=%1",
          :str_scan  => "data=(.*)"
        }
      ]
      deep_copy(options)
    end

    def GetAclFstabOptions
      options = [
        {
          # button text
          :widget    => Left(
            CheckBox(Id("opt_acl"), _("&Access Control Lists (ACL)"), false)
          ),
          :query_key => "opt_acl",
          # help text, richtext format
          :help_text => _(
            "<p><b>Access Control Lists (ACL):</b>\nEnable access control lists on the file system.</p>\n"
          ),
          :type      => :boolean,
          :default   => true,
          :str_opt   => { 0 => "noacl", "default" => "acl" },
          :str_scan  => [["acl", 1], ["noacl", 0]]
        },
        {
          # button text
          :widget    => Left(
            CheckBox(Id("opt_eua"), _("&Extended User Attributes"), false)
          ),
          :query_key => "opt_eua",
          # help text, richtext format
          :help_text => _(
            "<p><b>Extended User Attributes:</b>\nAllow extended user attributes on the file system.</p>\n"
          ),
          :type      => :boolean,
          :str_opt   => { 1 => "user_xattr", "default" => "" },
          :str_scan  => [["user_xattr", 1], ["nouser_xattr", 0]]
        }
      ]
      deep_copy(options)
    end

    def GetArbitraryOptionField
      opt = {
        # label text
        :widget        => TextEntry(
          Id("opt_arbitrary"),
          Opt(:hstretch),
          _("Arbitrary Option &Value"),
          ""
        ),
        :query_key     => "opt_arbitrary",
        :invalid_chars => "\t ",
        :error_text    => _(
          "Invalid characters in arbitrary option value. Do not use spaces or tabs. Try again."
        ),
        # help text, richtext format
        :help_text     => _(
          "<p><b>Arbitrary Option Value:</b>\n" +
            "In this field, type any legal mount option allowed in the fourth field of /etc/fstab.\n" +
            "Multiple options are separated by commas.</p>\n"
        ),
        :type          => :text
      }
      deep_copy(opt)
    end

    def GetNormalFilesystems
      fat_fst_options = [
        {
          # label text
          :widget    => ComboBox(
            Id("opt_iocharset"),
            Opt(:editable, :hstretch),
            _("Char&set for file names"),
            [
              "",
              "iso8859-1",
              "iso8859-15",
              "iso8859-2",
              "iso8859-5",
              "iso8859-7",
              "iso8859-9",
              "utf8",
              "koi8-r",
              "euc-jp",
              "sjis",
              "gb2312",
              "big5",
              "euc-kr"
            ]
          ),
          :query_key => "opt_iocharset",
          :type      => :text,
          # help text, richtext format
          :help_text => _(
            "<p><b>Charset for File Names:</b>\nSet the charset used for display of file names in Windows partitions.</p>\n"
          ),
          :str_opt   => "iocharset=%1",
          :str_scan  => "iocharset=(.*)"
        },
        {
          # label text
          :widget    => ComboBox(
            Id("opt_codepage"),
            Opt(:editable, :hstretch),
            _("Code&page for short FAT names"),
            ["", "437", "852", "932", "936", "949", "950"]
          ),
          :query_key => "opt_codepage",
          :type      => :text,
          # help text, richtext format
          :help_text => _(
            "<p><b>Codepage for Short FAT Names:</b>\nThis codepage is used for converting to shortname characters on FAT file systems.</p>\n"
          ),
          :str_opt   => "codepage=%1",
          :str_scan  => "codepage=(.*)"
        }
      ]

      vfat_options = [
        {
          # label text
          :widget     => ComboBox(
            Id("opt_number_of_fats"),
            Opt(:hstretch),
            _("Number of &FATs"),
            ["auto", "1", "2"]
          ),
          :query_key  => "opt_number_of_fats",
          :option_str => "-f",
          # help text, richtext format
          :help_text  => _(
            "<p><b>Number of FATs:</b>\nSpecify the number of file allocation tables in the file system. The default is 2.</p>"
          )
        },
        {
          # label text
          :widget     => ComboBox(
            Id("opt_fat_size"),
            Opt(:hstretch),
            _("FAT &Size"),
            [
              "auto",
              Item(Id("12"), "12 bit"),
              Item(Id("16"), "16 bit"),
              Item(Id("32"), "32 bit")
            ]
          ),
          :query_key  => "opt_fat_size",
          :option_str => "-F",
          # help text, richtext format
          :help_text  => _(
            "<p><b>FAT Size:</b>\nSpecifies the type of file allocation tables used (12, 16, or 32-bit). If auto is specified, YaST will automatically select the value most suitable for the file system size.</p>\n"
          )
        },
        {
          # label text
          :widget      => TextEntry(
            Id("opt_root_dir_entries"),
            Opt(:hstretch),
            _("Root &Dir Entries"),
            "auto"
          ),
          :query_key   => "opt_root_dir_entries",
          :option_str  => "-r",
          :between     => [112, -1],
          :valid_chars => "0123456789",
          # popup text
          :error_text  => _(
            "The minimum size for \"Root Dir Entries\" is 112. Try again."
          ),
          # help text, richtext format
          :help_text   => _(
            "<p><b>Root Dir Entries:</b>\nSelect the number of entries available in the root directory.</p>\n"
          )
        }
      ]


      reiserfs_options = [
        {
          # label text
          :widget       => ComboBox(
            Id("opt_hash"),
            Opt(:hstretch),
            _("Hash &Function"),
            ["auto", "r5", "tea", "rupasov"]
          ),
          :query_key    => "opt_hash",
          :option_str   => "--hash",
          :option_blank => true,
          # help text, richtext format
          :help_text    => _(
            "<p><b>Hash Function:</b>\nThis specifies the name of the hash function to use to sort the file names in directories.</p>\n"
          )
        },
        {
          # label text
          :widget       => ComboBox(
            Id("opt_format"),
            Opt(:hstretch),
            _("FS &Revision"),
            ["auto", "3.5", "3.6"]
          ),
          :query_key    => "opt_format",
          :option_str   => "--format",
          :option_blank => true,
          # help text, richtext format
          :help_text    => _(
            "<p><b>FS Revision:</b>\nThis option defines the reiserfs format revision to use. '3.5' is for backwards compatibility with kernels of the 2.2.x series. '3.6' is more recent, but can only be used with kernel versions greater than or equal to 2.4.</p>\n"
          )
        }
      ]


      xfs_options = [
        {
          # label text
          :widget     => ComboBox(
            Id("opt_blocksize"),
            Opt(:hstretch),
            _("Block &Size in Bytes"),
            #,"8192", "16384","32768"
            ["auto", "512", "1024", "2048", "4096"]
          ),
          :query_key  => "opt_blocksize",
          :option_str => "-bsize=",
          # help text, richtext format
          :help_text  => _(
            "<p><b>Block Size:</b>\nSpecify the size of blocks in bytes. Valid block size values are 512, 1024, 2048 and 4096 bytes per block. If auto is selected, the standard block size of 4096 is used.</p>\n"
          )
        },
        {
          # label text
          :widget     => ComboBox(
            Id("opt_bytes_per_inode"),
            Opt(:hstretch),
            _("&Inode Size"),
            ["auto", "256", "512", "1024", "2048"]
          ),
          :query_key  => "opt_bytes_per_inode",
          :option_str => "-isize=",
          # help text, richtext format
          :help_text  => _(
            "<p><b>Inode Size:</b>\nThis option specifies the inode size of the file system.</p>\n"
          )
        },
        {
          # label text
          :widget     => ComboBox(
            Id("opt_max_inode_space"),
            Opt(:hstretch),
            _("&Percentage of Inode Space"),
            [
              "auto",
              "5",
              "10",
              "15",
              "20",
              "25",
              "30",
              "35",
              "40",
              "45",
              "50",
              "55",
              "60",
              "65",
              "70",
              "75",
              "80",
              "85",
              "90",
              "95",
              Item(Id("0"), "100")
            ]
          ),
          :query_key  => "opt_max_inode_space",
          :option_str => "-imaxpct=",
          # help text, richtext format
          :help_text  => _(
            "<p><b>Percentage of Inode Space:</b>\nThe option \"Percentage of Inode Space\" specifies the maximum percentage of space in the file system that can be allocated to inodes.</p>\n"
          )
        },
        {
          # label text
          :widget     => ComboBox(
            Id("opt_inode_align"),
            Opt(:hstretch),
            _("Inode &Aligned"),
            ["auto", Item(Id("1"), "true"), Item(Id("0"), "false")]
          ),
          :query_key  => "opt_inode_align",
          :option_str => "-ialign=",
          # help text, richtext format
          :help_text  => _(
            "<p><b>Inode Aligned:</b>\n" +
              "The option \"Inode Aligned\" is used to specify whether inode allocation is or\n" +
              "is not aligned. By default inodes are aligned, which\n" +
              "is usually more efficient than unaligned access.</p>\n"
          )
        }
      ]


      jfs_options = [
        # 	    $[
        # 	   // label text
        # 	   `widget : `ComboBox(`id("opt_iocharset"), `opt(`editable,`hstretch), _("Char&set for file names"),
        # 	                       ["", "iso8859-1", "iso8859-15", "iso8859-2",
        # 			        "iso8859-5", "iso8859-7", "iso8859-9", "utf8",
        # 			        "koi8-r", "euc-jp", "sjis", "gb2312", "big5", "euc-kr" ]),
        # 	   `query_key : "opt_iocharset",
        # 	   `type : `text,
        # 	     // help text, richtext format
        # 	   `help_text : _("<p><b>Charset for File Names:</b>
        # Set the charset used to display file names on the partition.</p>\n"),
        # 	   `str_opt : "iocharset=%1",
        # 	   `str_scan : "iocharset=\(.*\)"
        # 	 ],
        {
          # label text
          :widget      => TextEntry(
            Id("opt_log_size"),
            Opt(:hstretch),
            _("&Log Size in Megabytes"),
            "auto"
          ),
          :query_key   => "opt_log_size",
          :option_str  => "-s",
          # no way to find out the max log size ????
          :between     => [0, -1], #  -> -1 = infinite
          :valid_chars => "0123456789",
          # popup text
          :error_text  => _(
            "The \"Log Size\" value is incorrect.\nEnter a value greater than zero.\n"
          ),
          # xgettext: no-c-format
          # help text, richtext format
          :help_text   => _(
            "<p><b>Log Size</b>\nSet the log size (in megabytes). If auto, the default is 40% of the aggregate size.</p>\n"
          )
        },
        {
          # label text
          :widget     => CheckBox(
            Id("opt_blocks_utility"),
            _("Invoke Bad Blocks List &Utility"),
            false
          ),
          :query_key  => "opt_blocks_utility",
          :option_str => "-c"
        }
      ]

      ext2_options = [
        {
          # label text
          :widget      => TextEntry(
            Id("opt_raid"),
            Opt(:hstretch),
            _("Stride &Length in Blocks"),
            "none"
          ),
          :query_key   => "opt_raid",
          :option_str  => "-Rstride=",
          :valid_chars => "0123456789",
          :between     => [1, -1],
          # popup text
          :error_text  => _(
            "The \"Stride Length in Blocks\" value is invalid.\nSelect a value greater than 1.\n"
          ),
          # help text, richtext format
          :help_text   => _(
            "<p><b>Stride Length in Blocks:</b>\n" +
              "Set RAID-related options for the file system. Currently, the only supported\n" +
              "argument is 'stride', which takes the number of blocks in a\n" +
              "RAID stripe as its argument.</p>\n"
          )
        },
        {
          # label text
          :widget     => ComboBox(
            Id("opt_blocksize"),
            Opt(:hstretch),
            _("Block &Size in Bytes"),
            #,"8192", "16384","32768"
            ["auto", "1024", "2048", "4096"]
          ),
          :query_key  => "opt_blocksize",
          :option_str => "-b",
          # help text, richtext format
          :help_text  => _(
            "<p><b>Block Size:</b>\nSpecify the size of blocks in bytes. Valid block size values are 1024, 2048, and 4096 bytes per block. If auto is selected, the block size is determined by the file system size and the expected use of the file system.</p>\n"
          )
        },
        {
          # label text
          :widget     => ComboBox(
            Id("opt_inode_density"),
            Opt(:hstretch),
            _("Bytes per &Inode"),
            ["auto", "1024", "2048", "4096", "8192", "16384", "32768"]
          ),
          :query_key  => "opt_inode_density",
          :option_str => "-i",
          # help text, richtext format
          :help_text  => _(
            "<p><b>Bytes per Inode:</b> \n" +
              "Specify the bytes to inode ratio. YaST creates an inode for every\n" +
              "&lt;bytes-per-inode&gt; bytes of space on the disk. The larger the\n" +
              "bytes-per-inode ratio, the fewer inodes will be created.  Generally, this\n" +
              "value should not be smaller than the block size of the file system, or else\n" +
              "too many inodes will be created. It is not possible to expand the number of\n" +
              "inodes on a file system after its creation. So be sure to enter a reasonable\n" +
              "value for this parameter.</p>\n"
          )
        },
        {
          # label text
          :widget      => TextEntry(
            Id("opt_reserved_blocks"),
            Opt(:hstretch),
            _("Percentage of Blocks &Reserved for root"),
            "auto"
          ),
          :query_key   => "opt_reserved_blocks",
          :option_str  => "-m",
          #`default 	: 5,
          :below       => 99,
          :str_length  => 6,
          :valid_chars => "0123456789.",
          # popup text
          :error_text  => _(
            "The \"Percentage of Blocks Reserved for root\" value is incorrect.\nAllowed are float numbers no larger than 99 (e.g. 0.5).\n"
          ),
          # xgettext: no-c-format
          # help text, richtext format
          :help_text   => _(
            "<p><b>Percentage of Blocks Reserved for root:</b> Specify the percentage of blocks reserved for the super user. The default is computed so that normally 1 Gig is reserved. Upper limit for reserved default is 5.0, lowest reserved default is 0.1.</p>"
          )
        },
        {
          # checkbox text
          :widget     => CheckBox(
            Id("opt_reg_checks"),
            Opt(:hstretch),
            _("Disable Regular Checks")
          ),
          :query_key  => "opt_reg_checks",
          :option_str => "-c 0 -i 0",
          :option_cmd => :tunefs,
          :type       => :boolean,
          :default    => false,
          # help text, richtext format
          :help_text  => _(
            "<p><b>Disable Regular Checks:</b>\nDisable regular file system check at booting.</p>\n"
          )
        }
      ]

      ext3_only_options = [
        {
          # label text
          :widget     => ComboBox(
            Id("opt_bytes_per_inode"),
            Opt(:hstretch),
            _("&Inode Size"),
            ["default", "128", "256", "512", "1024"]
          ),
          :query_key  => "opt_bytes_per_inode",
          :option_str => "-I",
          # help text, richtext format
          :help_text  => _(
            "<p><b>Inode Size:</b>\nThis option specifies the inode size of the file system.</p>\n"
          )
        },
        {
          # label text
          :widget       => CheckBox(
            Id("opt_dir_index"),
            Opt(:hstretch),
            _("&Directory Index Feature")
          ),
          :query_key    => "opt_dir_index",
          :option_str   => "-O dir_index",
          :option_false => "-O ^dir_index",
          :type         => :boolean,
          # help text, richtext format
          :help_text    => _(
            "<p><b>Directory Index:</b>\nEnables use of hashed b-trees to speed up lookups in large directories.</p>\n"
          )
        }
      ]

      ext4_only_options = [
        {
          # label text
          :widget     => CheckBox(
            Id("no_journal"),
            Opt(:hstretch),
            _("&No Journal")
          ),
          :query_key  => "no_journal",
          :option_str => "-O ^has_journal",
          :type       => :boolean,
          :default    => false,
          # help text, richtext format
          :help_text  => _(
            "<p><b>No Journal:</b>\n" +
              "Suppressed use of journaling on filesystem. Only activate this when you really\n" +
              "know what you are doing.</p>\n"
          )
        }
      ]

      ext3_options = Convert.convert(
        Builtins.merge(ext2_options, ext3_only_options),
        :from => "list",
        :to   => "list <map <symbol, any>>"
      )
      ext4_options = Convert.convert(
        Builtins.merge(ext2_options, ext3_only_options),
        :from => "list",
        :to   => "list <map <symbol, any>>"
      )
      ext4_options = Convert.convert(
        Builtins.merge(ext4_options, ext4_only_options),
        :from => "list",
        :to   => "list <map <symbol, any>>"
      )

      ext2_fst_options = []
      ext3_fst_options = []
      ext4_fst_options = []
      reiser_fst_options = []


      _RealFileSystems = {
        :ext2    => {
          :name            => "Ext2",
          :fsid            => Partitions.fsid_native,
          :real_fs         => true,
          :supports_format => true,
          :fsid_item       => "0x83 Linux ",
          :fstype          => "Linux native",
          :crypt           => true,
          :mountpoints     => SuggestMPoints(),
          :mount_option    => "-t ext2",
          :mount_string    => "ext2",
          :fst_options     => ext2_fst_options,
          :options         => ext2_options
        },
        :vfat    => {
          :name            => "FAT",
          :fsid            => 12,
          :real_fs         => true,
          :alt_fsid        => [12, 259],
          :supports_format => true,
          :fsid_item       => "0x0C Win95 FAT32 ",
          :fstype          => "Fat32",
          :crypt           => true,
          :mountpoints     => SuggestMPoints(),
          :mount_option    => "-t vfat",
          :mount_string    => "vfat",
          :needed_modules  => ["fat", "vfat"],
          :fst_options     => fat_fst_options,
          :options         => vfat_options
        },
        :reiser  => {
          :name            => "Reiser",
          :fsid            => Partitions.fsid_native,
          :real_fs         => true,
          :supports_format => true,
          :fsid_item       => "0x83 Linux ",
          :fstype          => "Linux native",
          :crypt           => true,
          :mountpoints     => SuggestMPoints(),
          :mount_option    => "-t reiserfs",
          :mount_string    => "reiserfs",
          :needed_modules  => ["reiserfs"],
          :fst_options     => reiser_fst_options,
          :options         => reiserfs_options
        },
        :xfs     => {
          :name            => "XFS",
          :fsid            => Partitions.fsid_native,
          :real_fs         => true,
          :supports_format => true,
          :fsid_item       => "0x83 Linux ",
          :fstype          => "Linux native",
          :crypt           => true,
          :mountpoints     => SuggestMPoints(),
          :mount_option    => "-t xfs",
          :mount_string    => "xfs",
          :needed_modules  => ["xfs"],
          :options         => xfs_options
        },
        :jfs     => {
          :name            => "JFS",
          :fsid            => Partitions.fsid_native,
          :real_fs         => true,
          :supports_format => true,
          :fsid_item       => "0x83 Linux ",
          :fstype          => "Linux native",
          :crypt           => true,
          :mountpoints     => SuggestMPoints(),
          :mount_string    => "jfs",
          :mount_option    => "-t jfs",
          :needed_modules  => ["jfs"],
          :options         => jfs_options
        },
        :ext3    => {
          :name            => "Ext3",
          :fsid            => Partitions.fsid_native,
          :real_fs         => true,
          :supports_format => true,
          :fsid_item       => "0x83 Linux ",
          :fstype          => "Linux native",
          :crypt           => true,
          :mountpoints     => SuggestMPoints(),
          :mount_string    => "ext3",
          :mount_option    => "-t ext3",
          :needed_modules  => ["jbd", "mbcache", "ext3"],
          :fst_options     => ext3_fst_options,
          :options         => ext3_options
        },
        :ext4    => {
          :name            => "Ext4",
          :fsid            => Partitions.fsid_native,
          :real_fs         => true,
          :supports_format => true,
          :fsid_item       => "0x83 Linux ",
          :fstype          => "Linux native",
          :crypt           => true,
          :mountpoints     => SuggestMPoints(),
          :mount_string    => "ext4",
          :mount_option    => "-t ext4",
          :needed_modules  => ["jbd2", "mbcache", "ext4"],
          :fst_options     => ext4_fst_options,
          :options         => ext4_options
        },
        :btrfs   => {
          :name            => "BtrFS",
          :fsid            => Partitions.fsid_native,
          :real_fs         => true,
          :supports_format => true,
          :fsid_item       => "0x83 Linux ",
          :fstype          => "Linux native",
          :crypt           => true,
          :mountpoints     => SuggestMPoints(),
          :mount_string    => "btrfs",
          :mount_option    => "-t btrfs",
          :needed_modules  => ["btrfs"],
          :fst_options     => [],
          :options         => []
        },
        :hfs     => {
          :name            => "MacHFS",
          :fsid            => Partitions.fsid_mac_hfs,
          :real_fs         => true,
          :supports_format => true,
          :alt_fsid        => [131],
          :fsid_item       => "0x102 Apple_HFS ",
          :fstype          => "Apple_HFS ",
          :crypt           => false,
          :mountpoints     => [],
          :mount_string    => "hfs",
          :mount_option    => "-t hfs",
          :needed_modules  => ["hfs"],
          :fst_options     => [],
          :options         => []
        },
        :hfsplus => {
          :name            => "MacHFS+",
          :fsid            => Partitions.fsid_mac_hfs,
          :real_fs         => true,
          :supports_format => false,
          :alt_fsid        => [131],
          :fsid_item       => "0x102 Apple_HFS ",
          :fstype          => "Apple_HFS ",
          :crypt           => false,
          :mountpoints     => [],
          :mount_string    => "hfsplus",
          :mount_option    => "-t hfsplus",
          :needed_modules  => ["hfsplus"],
          :fst_options     => [],
          :options         => []
        },
        :ntfs    => {
          :name            => "NTFS",
          :fsid            => 7,
          :real_fs         => true,
          :supports_format => false,
          :alt_fsid        => Partitions.fsid_ntfstypes,
          :fsid_item       => "0x07 NTFS ",
          :fstype          => "NTFS ",
          :crypt           => false,
          :mountpoints     => [],
          :mount_string    => "ntfs-3g",
          :mount_option    => "-t ntfs",
          :needed_modules  => ["ntfs"],
          :fst_options     => [],
          :options         => []
        },
        :tmpfs   => {
          :name         => "TmpFS",
          :mountpoints  => SuggestTmpfsMPoints(),
          :mount_string => "tmpfs",
          :mount_option => "-t tmpfs",
          :fst_options  => @tmpfs_fst_options
        },
        :iso9660 => {
          :name            => "ISO9660",
          :real_fs         => true,
          :supports_format => false,
          :crypt           => false,
          :mountpoints     => [],
          :mount_string    => "iso9660",
          :mount_option    => "-t iso9660",
          :options         => []
        },
        :udf => {
          :name            => "UDF",
          :real_fs         => true,
          :supports_format => false,
          :crypt           => false,
          :mountpoints     => [],
          :mount_string    => "udf",
          :mount_option    => "-t udf",
          :options         => []
        }
      }

      deep_copy(_RealFileSystems)
    end


    # Filesystem Definitions
    # @return [Hash] map with all supported filesystems
    def GetAllFileSystems(add_swap, add_pseudo, label)
      ret = Builtins.filter(GetNormalFilesystems()) do |fs_key, fs_map|
        Ops.get(@support, fs_key, false)
      end

      if add_swap
        ret = Convert.convert(
          Builtins.union(ret, @SwapFileSystems),
          :from => "map",
          :to   => "map <symbol, map <symbol, any>>"
        )
      end
      if add_pseudo
        ret = Convert.convert(
          Builtins.union(ret, Builtins.filter(@PseudoFileSystems) do |fs_key, fs_map|
            Ops.get(@support, fs_key, false) ||
              !Builtins.isempty(Ops.get_string(fs_map, :label, "")) &&
                Ops.get_string(fs_map, :label, "") == label
          end),
          :from => "map",
          :to   => "map <symbol, map <symbol, any>>"
        )
      end
      deep_copy(ret)
    end

    def GetTmpfsFilesystem
      Ops.get(GetNormalFilesystems(), :tmpfs, {})
    end

    def GetFstabOptWidgets(fsys)
      ret = []
      if fsys == :swap
        ret = deep_copy(@swap_fst_options)
      elsif fsys == :tmpfs
        ret = deep_copy(@tmpfs_fst_options)
      else
        fs = GetAllFileSystems(true, false, "")
        ret = Ops.get_list(fs, [fsys, :fst_options], [])
        if Builtins.contains([:ext3, :ext4, :reiser], fsys)
          ret = Convert.convert(
            Builtins.union(ret, GetJournalFstabOptions()),
            :from => "list",
            :to   => "list <map <symbol, any>>"
          )
        end
        if Builtins.contains([:ext2, :ext3, :ext4, :reiser], fsys)
          ret = Convert.convert(
            Builtins.union(ret, GetAclFstabOptions()),
            :from => "list",
            :to   => "list <map <symbol, any>>"
          )
        end
      end
      Builtins.y2milestone("fsys:%1 ret:%2", fsys, ret)
      deep_copy(ret)
    end


    def FindFsid(fs_item)
      ret = nil
      fs = Convert.convert(
        Builtins.union(GetNormalFilesystems(), @SwapFileSystems),
        :from => "map",
        :to   => "map <symbol, map>"
      )
      fs = Convert.convert(
        Builtins.union(fs, @PseudoFileSystems),
        :from => "map",
        :to   => "map <symbol, map>"
      )
      l = Builtins.maplist(Builtins.filter(fs) do |s, m|
        Ops.get_string(m, :fsid_item, "") == fs_item
      end) { |ss, mm| Ops.get(mm, :fsid) }
      ret = Ops.get_integer(l, 0, 0) if !Builtins.isempty(l)
      Builtins.y2milestone("FindFsid item:%1 ret:%2", fs_item, ret)
      ret
    end


    def FileSystems
      Ops.set(@support, :vfat, false) if Arch.sparc64 || Arch.sparc32
      if Arch.ppc and !Arch.board_powernv
        Ops.set(@support, :vfat, Arch.board_chrp)
        Ops.set(@support, :xbootdisk, true)
        Ops.set(@support, :xxbootdisk, true)
        Ops.set(@support, :xbootfat, Arch.board_chrp)
      end
      Ops.set(@support, :vfat, false) if Arch.s390
      if Arch.ia64
        Ops.set(@support, :jfs, false)
        Ops.set(@support, :xxefi, true)
      end
      Ops.set(@support, :reiser, false) if Arch.alpha
      if Arch.board_mac
        Ops.set(@support, :hfs, true)
        Ops.set(@support, :hfsplus, true)
      end
      Builtins.y2milestone("support %1", @support)

      nil
    end


    def InitSlib(value)
      @sint = value
      if @sint != nil
        @default_subvol = @sint.getDefaultSubvolName()
        Builtins.y2milestone(
          "InitSlib used default_subvol:\"%1\"",
          @default_subvol
        )
      end

      nil
    end


    def assertInit
      if @sint == nil
        @sint = StorageInit.CreateInterface(false)
        Builtins.y2error("StorageInit::CreateInterface failed") if @sint == nil
      end

      nil
    end

    def IsSupported(used_fs)
      Ops.get(@support, used_fs, false)
    end

    def IsUnsupported(used_fs)
      Builtins.contains(@unsupportFs, used_fs)
    end

    def GetFsMap(used_fs)
      allfs = GetAllFileSystems(true, true, "")
      if Builtins.haskey(allfs, used_fs)
        return Ops.get(allfs, used_fs, {})
      else
        fs = GetNormalFilesystems()
        return Ops.get(fs, used_fs, {})
      end
    end


    def GetName(used_fs, defaultv)
      fsmap = GetFsMap(used_fs)
      ret = Ops.get_string(fsmap, :name, "")
      ret = "NTFS" if ret == "" && used_fs == :ntfs # obsolete? (included in RealFileSystems)
      ret = "NFS" if ret == "" && used_fs == :nfs
      ret = "NFS4" if ret == "" && used_fs == :nfs4
      ret = defaultv if ret == ""
      ret
    end


    def GetFsid(used_fs)
      fsmap = GetFsMap(used_fs)
      Ops.get_integer(fsmap, :fsid, Partitions.fsid_native)
    end

    def GetSupportFormat(used_fs)
      fsmap = GetFsMap(used_fs)
      Ops.get_boolean(fsmap, :supports_format, false)
    end

    def GetFsidItem(used_fs)
      fsmap = GetFsMap(used_fs)
      Ops.get_string(fsmap, :fsid_item, "")
    end

    def GetFstype(used_fs)
      fsmap = GetFsMap(used_fs)
      Ops.get_string(fsmap, :fstype, "")
    end

    def GetCrypt(used_fs)
      fsmap = GetFsMap(used_fs)
      Ops.get_boolean(fsmap, :crypt)
    end

    def GetPossibleMountPoints(used_fs)
      fsmap = GetFsMap(used_fs)
      Ops.get_list(fsmap, :mountpoints, [])
    end

    def GetMountOption(used_fs)
      fsmap = GetFsMap(used_fs)
      Ops.get_string(fsmap, :mount_option, "")
    end

    def GetOptions(used_fs)
      fsmap = GetFsMap(used_fs)
      Ops.get_list(fsmap, :options, [])
    end


    # Return the mount option for each used_fs (-t)
    # @return [String]
    def GetMountString(used_fs, defaultv)
      fsmap = GetFsMap(used_fs)
      ret = Ops.get_string(fsmap, :mount_string, defaultv)
      Builtins.y2milestone("GetMountString used_fs:%1 ret:%2", used_fs, ret)
      ret
    end


    def GetNeededModules(used_fs)
      fsmap = GetFsMap(used_fs)
      ret = Ops.get_list(fsmap, :needed_modules, [])
      Builtins.y2milestone("GetNeededModules used_fs:%1 ret:%2", used_fs, ret)
      deep_copy(ret)
    end


    def MinFsSizeK(fsys)
      ret = 0
      assertInit
      id = fromSymbol(@conv_fs, fsys)
      caps = ::Storage::FsCapabilities.new()
      if @sint.getFsCapabilities(id, caps)
        ret = caps.minimalFsSizeK
      end
      Builtins.y2milestone("MinFsSizeK fsys:%1 ret:%2", fsys, ret)
      ret
    end


    def MountUuid(fsys)
      ret = false
      assertInit
      id = fromSymbol(@conv_fs, fsys)
      caps = ::Storage::FsCapabilities.new()
      if @sint.getFsCapabilities(id, caps)
        ret = caps.supportsUuid
      end
      Builtins.y2milestone("MountUuid fsys:%1 ret:%2", fsys, ret)
      ret
    end


    def MountLabel(fsys)
      ret = false
      assertInit
      id = fromSymbol(@conv_fs, fsys)
      caps = ::Storage::FsCapabilities.new()
      if @sint.getFsCapabilities(id, caps)
        ret = caps.supportsLabel
      end
      Builtins.y2milestone("MountLabel fsys:%1 ret:%2", fsys, ret)
      ret
    end


    def ChangeLabelMounted(fsys)
      ret = false
      assertInit
      id = fromSymbol(@conv_fs, fsys)
      caps = ::Storage::FsCapabilities.new()
      if @sint.getFsCapabilities(id, caps)
        ret = caps.labelWhileMounted
      end
      Builtins.y2milestone("ChangeLabelMounted fsys:%1 ret:%2", fsys, ret)
      ret
    end


    def LabelLength(fsys)
      ret = 0
      assertInit
      id = fromSymbol(@conv_fs, fsys)
      caps = ::Storage::FsCapabilities.new()
      if @sint.getFsCapabilities(id, caps)
        ret = caps.labelLength
      end
      Builtins.y2milestone("LabelLength fsys:%1 ret:%2", fsys, ret)
      ret
    end


    def IsResizable(fsys)
      ret = {}
      assertInit
      id = fromSymbol(@conv_fs, fsys)
      caps = ::Storage::FsCapabilities.new()
      if @sint.getFsCapabilities(id, caps)
        ret = {
          "extend"       => caps.isExtendable,
          "shrink"       => caps.isReduceable,
          "mount_extend" => caps.isExtendableWhileMounted,
          "mount_shrink" => caps.isReduceableWhileMounted
        }
      end
      Builtins.y2milestone("IsResizable fsys:%1 ret:%2", fsys, ret)
      deep_copy(ret)
    end


    def FsToSymbol(type)
      ret = :none

      if type == "ext2"
        ret = :ext2
      elsif type == "ext3"
        ret = :ext3
      elsif type == "ext4"
        ret = :ext4
      elsif type == "btrfs"
        ret = :btrfs
      elsif Builtins.regexpmatch(type, "reiser.*")
        ret = :reiser
      elsif type == "jfs"
        ret = :jfs
      elsif type == "xfs"
        ret = :xfs
      elsif type == "vfat" || Builtins.regexpmatch(type, "fat.*")
        ret = :vfat
      elsif type == "ntfs"
        ret = :ntfs
      elsif type == "hfs"
        ret = :hfs
      elsif type == "swap"
        ret = :swap
      end

      ret
    end


    def IsCryptMp(mount, prefix)
      ret = Builtins.contains(crypt_m_points, mount)
      if !ret && prefix
        mp = Builtins.filter(system_m_points) { |s| s != "/" }
        Builtins.foreach(mp) do |s|
          ret = ret || Builtins.search(mount, Ops.add(s, "/")) == 0
        end
      end
      Builtins.y2milestone(
        "IsCryptMp mount:%1 prefix:%2 ret:%3",
        mount,
        prefix,
        ret
      )
      ret
    end

    def IsSystemMp(mount, prefix)
      mp = Convert.convert(
        Builtins.union(system_m_points, ["/boot"]),
        :from => "list",
        :to   => "list <string>"
      )
      ret = Builtins.contains(mp, mount)
      if !ret && prefix
        mp = Builtins.filter(mp) { |s| s != "/" }
        Builtins.foreach(mp) do |s|
          ret = ret || Builtins.search(mount, Ops.add(s, "/")) == 0
        end
      end
      if Ops.greater_than(Builtins.size(mount), 0)
        Builtins.y2milestone(
          "IsSystemMp mount:%1 prefix:%2 ret:%3",
          mount,
          prefix,
          ret
        )
      end
      ret
    end

    def RemoveCryptOpts(opt)
      ret = opt
      ret = String.CutRegexMatch(ret, ",*loop[^,]*", true)
      ret = String.CutRegexMatch(ret, ",*encryption=[^,]*", true)
      ret = String.CutRegexMatch(ret, ",*phash=[^,]*", true)
      ret = String.CutRegexMatch(ret, ",*itercountk=[^,]*", true)
      if Builtins.size(ret) != Builtins.size(opt)
        ret = String.CutRegexMatch(ret, "^,", false)
        Builtins.y2milestone("in %1 ret %2", opt, ret)
      end
      ret
    end

    def LangTypicalEncoding
      lang = Encoding.GetEncLang
      enc = "utf8"
      if !Encoding.GetUtf8Lang
        enc = "iso8859-15"
        lang = Builtins.substring(lang, 0, 2)
        lang = Builtins.tolower(lang)
        enc = Ops.get_string(@lenc, lang, "") if Builtins.haskey(@lenc, lang)
      end
      Builtins.y2milestone("LangTypicalEncoding lang %1 ret %2", lang, enc)
      enc
    end

    def DefaultFstabOptions(part)
      part = deep_copy(part)
      fsys = Ops.get_symbol(part, "used_fs", :none)
      fst_default = ""
      if Ops.get_boolean(part, "format", false) &&
          Builtins.contains([:ext2, :ext3, :ext4, :reiser], fsys)
        fst_default = "acl,user_xattr"
      elsif Ops.get_boolean(part, "format", false) && fsys == :btrfs &&
          @default_subvol != ""
        fst_default = Ops.add("subvol=", @default_subvol)
      elsif !Arch.ia64 && Builtins.contains([:vfat, :ntfs], fsys)
        fst_default = ""
        is_boot = Builtins.substring(Ops.get_string(part, "mount", ""), 0, 5) == "/boot"
        fst_default = "users,gid=users" if !is_boot
        enc = LangTypicalEncoding()
        code = Encoding.GetCodePage(enc)
        if Ops.greater_than(Builtins.size(enc), 0)
          if fsys != :ntfs
            fst_default = Ops.add(fst_default, ",umask=0002")
            if enc == "utf8"
              fst_default = Ops.add(fst_default, ",utf8=true")
            else
              fst_default = Ops.add(Ops.add(fst_default, ",iocharset="), enc)
            end
          else
            fst_default = Ops.add(fst_default, ",fmask=133,dmask=022")
            m = Convert.to_map(
              SCR.Execute(path(".target.bash_output"), "locale | grep LC_CTYPE")
            )
            sl = Builtins.splitstring(Ops.get_string(m, "stdout", ""), "\n")
            sl = Builtins.splitstring(Ops.get(sl, 0, ""), "=")
            Builtins.y2milestone("DefaultFstabOptions sl %1", sl)
            if Ops.greater_than(Builtins.size(Ops.get(sl, 1, "")), 0)
              fst_default = Ops.add(
                Ops.add(fst_default, ",locale="),
                Builtins.deletechars(Ops.get(sl, 1, ""), "\"")
              )
            end
          end
        end
        if Ops.greater_than(Builtins.size(code), 0) && code != "437" &&
            fsys != :ntfs &&
            !is_boot
          fst_default = Ops.add(Ops.add(fst_default, ",codepage="), code)
        end
      end

      dev = Ops.get_string(part, "device", "")

      if Ops.get_string(part, "mount", "") != "/"
        need_nofail = false
        assertInit

        devs = Convert.convert(
          Ops.get(part, "using_devices") { [dev] },
          :from => "any",
          :to   => "list <string>"
        )
        Builtins.y2milestone("DefaultFstabOptions devs:%1", devs)

        usedby_devices = ::Storage::ListString.new()
	dv = ::Storage::ListString.new()
	devs.each { |x| dv.push(x) }
        if @sint.getRecursiveUsedBy( dv, true, usedby_devices)==0 
          # USB since those might actually not be present during boot
          # iSCSI since the boot scripts need it
          hotplug_transports = [::Storage::USB, ::Storage::ISCSI]

          usedby_devices.each do |usedby_device|
            dp = ::Storage::ContVolInfo.new()
            if @sint.getContVolInfo(usedby_device, dp)==0 &&
                dp.ctype == ::Storage::DISK
              disk = dp.cdevice
              infos = ::Storage::DiskInfo.new()
              if @sint.getDiskInfo(disk, infos)==0 &&
                  Builtins.contains(hotplug_transports, infos.transport)
                need_nofail = true
              end
            end
          end

          if need_nofail
            if !Builtins.isempty(fst_default)
              fst_default = Ops.add(fst_default, ",")
            end
            fst_default = Ops.add(fst_default, "nofail")
          end
        end
      end

      if Builtins.substring(fst_default, 0, 1) == ","
        fst_default = Builtins.substring(fst_default, 1)
      end
      Builtins.y2milestone(
        "DefaultFstabOptions dev %3 fsys %1 is %2",
        fsys,
        fst_default,
        dev
      )
      fst_default
    end


    def DefaultFormatOptions(part)
      part = deep_copy(part)
      ret = {}
      fsys = Ops.get_symbol(part, "used_fs", :none)
      if Ops.get_boolean(part, "format", false)
        if Builtins.contains([:ext3, :ext4], fsys)
          Ops.set(
            ret,
            "opt_dir_index",
            { "option_str" => "-O dir_index", "option_value" => true }
          )
          Ops.set(
            ret,
            "opt_reg_checks",
            {
              "option_str"   => "-c 0 -i 0",
              "option_value" => true,
              "option_cmd"   => :tunefs
            }
          )
        end
        if Arch.board_pegasos && Builtins.contains([:ext2, :ext3, :ext4], fsys)
          Ops.set(
            ret,
            "opt_bytes_per_inode",
            { "option_str" => "-I", "option_value" => "128" }
          )
        end
        if Arch.s390 && Builtins.contains([:ext2, :ext3, :ext4], fsys)
          Ops.set(
            ret,
            "opt_blocksize",
            { "option_str" => "-b", "option_value" => "4096" }
          )
        end
        if Builtins.contains([:ext2, :ext3, :ext4], fsys)
          if Arch.s390
            Ops.set(
              ret,
              "opt_blocksize",
              { "option_str" => "-b", "option_value" => "4096" }
            )
          end
          f = Ops.multiply(
            Ops.divide(
              1048580.0,
              Convert.convert(
                Ops.get_integer(part, "size_k", 0),
                :from => "integer",
                :to   => "float"
              )
            ),
            Convert.convert(100, :from => "integer", :to => "float")
          )
          if Ops.greater_than(
              f,
              Convert.convert(5, :from => "integer", :to => "float")
            )
            f = Convert.convert(5, :from => "integer", :to => "float")
          end
          f = 0.1 if Ops.less_than(f, 0.1)
          Ops.set(
            ret,
            "opt_reserved_blocks",
            { "option_str" => "-m", "option_value" => Builtins.tostring(f, 1) }
          )
        end
      end
      Builtins.y2milestone(
        "DefaultFormatOptions fsys %1 fmt %2 is %3",
        fsys,
        Ops.get_boolean(part, "format", false),
        ret
      )
      deep_copy(ret)
    end

    def HasFstabOption(part, opt, prefix)
      part = deep_copy(part)
      l = Builtins.splitstring(Ops.get_string(part, "fstopt", ""), ",")
      if prefix
        l = Builtins.filter(l) { |s| Builtins.search(s, opt) == 0 }
      else
        l = Builtins.filter(l) { |s| s == opt }
      end
      Builtins.y2milestone(
        "HasFstabOption fst:%1 opt:%2 prefix:%3 l:%4 ret:%5",
        Ops.get_string(part, "fstopt", ""),
        opt,
        prefix,
        l,
        Ops.greater_than(Builtins.size(l), 0)
      )
      Ops.greater_than(Builtins.size(l), 0)
    end

    def CheckFstabOptions(option_list)
      found = false
      index = 0
      Builtins.y2milestone("CheckFstabOptions option_list=%1", option_list)
      olist = Builtins.splitstring(option_list, ",")
      known = []
      unknown = []
      Builtins.foreach(olist) do |o|
        if Builtins.contains(@FstabOptionStrings, o)
          known = Builtins.add(known, o)
        else
          found = false
          index = 0
          while !found && Ops.less_than(index, Builtins.size(@FstabOptionRegex))
            found = Builtins.regexpmatch(
              o,
              Ops.get(@FstabOptionRegex, index, "")
            )
            index = Ops.add(index, 1)
          end
          if found
            known = Builtins.add(known, o)
          else
            unknown = Builtins.add(unknown, o)
          end
        end
      end
      ret = {
        "all_known"       => Builtins.size(unknown) == 0,
        "known_options"   => Builtins.mergestring(known, ","),
        "unknown_options" => Builtins.mergestring(unknown, ",")
      }
      Builtins.y2milestone("CheckFstabOptions ret=%1", ret)
      deep_copy(ret)
    end


    def GetFstabDefaultMap(key)
      Ops.get(@FstabDefaultMap, key, {})
    end

    def GetFstabDefaultList(key)
      m = GetFstabDefaultMap(key)
      [
        Ops.get_string(m, "spec", ""),
        Ops.get_string(m, "mount", ""),
        Ops.get_string(m, "vfstype", ""),
        Ops.get_string(m, "mntops", ""),
        Builtins.tostring(Ops.get_integer(m, "freq", 0)),
        Builtins.tostring(Ops.get_integer(m, "passno", 0))
      ]
    end


    def CanMountRo(part)
      part = deep_copy(part)
      only_rw_fs = [:tmpfs, :swap]
      !Builtins.contains(only_rw_fs, Ops.get_symbol(part, "used_fs", :unknown))
    end

    def CanDoQuota(part)
      part = deep_copy(part)
      quota_fs = [:ext2, :ext3, :ext4, :reiser, :xfs]
      Builtins.contains(quota_fs, Ops.get_symbol(part, "used_fs", :unknown))
    end

    def HasQuota(part)
      part = deep_copy(part)
      opts = Builtins.splitstring(Ops.get_string(part, "fstopt", ""), ",")
      Builtins.find(opts) do |opt|
        opt == "usrquota" || opt == "grpquota" ||
          Builtins.search(opt, "usrjquota=") == 0 ||
          Builtins.search(opt, "grpjquota=") == 0
      end != nil
    end

    def RemoveQuotaOpts(fst_opts)
      opts = Builtins.splitstring(fst_opts, ",")
      opts = Builtins.filter(opts) do |opt|
        opt != "usrquota" && opt != "grpquota" &&
          Builtins.search(opt, "usrjquota=") != 0 &&
          Builtins.search(opt, "grpjquota=") != 0 &&
          Builtins.search(opt, "jqfmt=") != 0
      end
      Builtins.mergestring(opts, ",")
    end

    def AddQuotaOpts(part, fst_opts)
      part = deep_copy(part)
      journal = [:ext3, :ext4, :btrfs, :reiser]
      ret = RemoveQuotaOpts(fst_opts)
      if Builtins.contains(journal, Ops.get_symbol(part, "used_fs", :unknown))
        ret = Ops.add(
          ret,
          ",usrjquota=aquota.user,grpjquota=aquota.group,jqfmt=vfsv0"
        )
      else
        ret = Ops.add(ret, ",usrquota,grpquota")
      end
      ret
    end

    # Set the default subvolume name
    #
    # @param [String] Default subvolume name. Only "" and "@" are supported.
    # @return [Boolean] True if subvolume was changed; false otherwise.
    def default_subvol=(name)
      return if @sint.nil?
      if SUPPORTED_DEFAULT_SUBVOLUME_NAMES.include?(name)
        @default_subvol = name
        @sint.setDefaultSubvolName(name)
        true
      else
        log.warn "Unsupported default subvolume name='#{name}'. Ignoring."
        false
      end
    end

    # Try to find the default subvolume name in the target system
    #
    # * Root partition takes precedence
    # * Not supported: more than 1 Btrfs filesystems, one using
    #   a '@' default subvolume and the other using ''. In that case,
    #   default_subvolume is set to product's default.
    #
    # @return [String,nil] Default subvolume from the target system
    def default_subvol_from_target
      Yast.import "Storage"
      parts = Storage.GetTargetMap.map { |_k, d| d.fetch("partitions")  }.flatten.compact
      btrfs_parts = parts.select { |p| p["used_fs"] == :btrfs }
      default_subvol_names = btrfs_parts.reduce({}) do |memo, part|
        memo[part["mount"]] = btrfs_subvol_name_for(part["mount"]) unless part["mount"].nil?
        memo
      end

      # Root takes precedence
      return default_subvol_names["/"] if default_subvol_names.has_key?("/")

      # If all has the same default subvolume name
      found_names = default_subvol_names.values.uniq
      return found_names.first if found_names.size == 1

      # If there are different values, fallback to product's default
      default_subvol_from_product
    end

    # Default subvol name from product
    #
    # @return [String] Default subvolume name
    def default_subvol_from_product
      ProductFeatures.GetStringFeature("partitioning", "btrfs_default_subvolume")
    end

    # Read the default subvolume from the filesystem and stores the value
    #
    # @return [String,nil] Default subvolume from the target system
    # @see default_subvol_from_target
    def read_default_subvol_from_target
      self.default_subvol = default_subvol_from_target
    end

    protected

    # Find the default subvolume name
    #
    # Only "" and "@" are supported.
    #
    # @param mount [String] Mount point.
    # @return ["@", ""] Default subvolume name for the given mount point.
    def btrfs_subvol_name_for(mount)
      ret = Yast::Execute.on_target("btrfs", "subvol", "list", mount, stdout: :capture)
      ret.split("\n").first =~ /.+ @\z/ ? "@" : ""
    end

    publish :variable => :conv_fs, :type => "map <string, any>"
    publish :variable => :possible_root_fs, :type => "const list <symbol>"
    publish :function => :system_m_points, :type => "list <string> ()"
    publish :function => :crypt_m_points, :type => "list <string> ()"
    publish :variable => :swap_m_points, :type => "const list <string>"
    publish :variable => :tmp_m_points, :type => "const list <string>"
    publish :variable => :nchars, :type => "string"
    publish :function => :default_subvol, :type => "string ()"
    publish :function => :default_subvol=, :type => "string (string)"
    publish :function => :SuggestMPoints, :type => "list <string> ()"
    publish :function => :SuggestTmpfsMPoints, :type => "list <string> ()"
    publish :function => :GetGeneralFstabOptions, :type => "list <map <symbol, any>> ()"
    publish :function => :GetJournalFstabOptions, :type => "list <map <symbol, any>> ()"
    publish :function => :GetAclFstabOptions, :type => "list <map <symbol, any>> ()"
    publish :function => :GetArbitraryOptionField, :type => "map <symbol, any> ()"
    publish :function => :GetAllFileSystems, :type => "map <symbol, map <symbol, any>> (boolean, boolean, string)"
    publish :function => :GetTmpfsFilesystem, :type => "map <symbol, any> ()"
    publish :function => :GetFstabOptWidgets, :type => "list <map <symbol, any>> (symbol)"
    publish :function => :FindFsid, :type => "integer (string)"
    publish :function => :FileSystems, :type => "void ()"
    publish :function => :InitSlib, :type => "void (any)"
    publish :function => :IsSupported, :type => "boolean (symbol)"
    publish :function => :IsUnsupported, :type => "boolean (symbol)"
    publish :function => :GetFsMap, :type => "map <symbol, any> (symbol)"
    publish :function => :GetName, :type => "string (symbol, string)"
    publish :function => :GetFsid, :type => "integer (symbol)"
    publish :function => :GetSupportFormat, :type => "boolean (symbol)"
    publish :function => :GetFsidItem, :type => "string (symbol)"
    publish :function => :GetFstype, :type => "string (symbol)"
    publish :function => :GetCrypt, :type => "boolean (symbol)"
    publish :function => :GetPossibleMountPoints, :type => "list (symbol)"
    publish :function => :GetMountOption, :type => "string (symbol)"
    publish :function => :GetOptions, :type => "list (symbol)"
    publish :function => :GetMountString, :type => "string (symbol, string)"
    publish :function => :GetNeededModules, :type => "list <string> (symbol)"
    publish :function => :MinFsSizeK, :type => "integer (symbol)"
    publish :function => :MountUuid, :type => "boolean (symbol)"
    publish :function => :MountLabel, :type => "boolean (symbol)"
    publish :function => :ChangeLabelMounted, :type => "boolean (symbol)"
    publish :function => :LabelLength, :type => "integer (symbol)"
    publish :function => :IsResizable, :type => "map <string, boolean> (symbol)"
    publish :function => :FsToSymbol, :type => "symbol (string)"
    publish :function => :IsCryptMp, :type => "boolean (string, boolean)"
    publish :function => :IsSystemMp, :type => "boolean (string, boolean)"
    publish :function => :RemoveCryptOpts, :type => "string (string)"
    publish :function => :LangTypicalEncoding, :type => "string ()"
    publish :function => :DefaultFstabOptions, :type => "string (map)"
    publish :function => :DefaultFormatOptions, :type => "map <string, map <string, any>> (map)"
    publish :function => :HasFstabOption, :type => "boolean (map, string, boolean)"
    publish :function => :CheckFstabOptions, :type => "map (string)"
    publish :function => :GetFstabDefaultMap, :type => "map (string)"
    publish :function => :GetFstabDefaultList, :type => "list <string> (string)"
    publish :function => :CanMountRo, :type => "boolean (map)"
    publish :function => :CanDoQuota, :type => "boolean (map)"
    publish :function => :HasQuota, :type => "boolean (map)"
    publish :function => :RemoveQuotaOpts, :type => "string (string)"
    publish :function => :AddQuotaOpts, :type => "string (map, string)"
  end

  FileSystems = FileSystemsClass.new
  FileSystems.main
end
