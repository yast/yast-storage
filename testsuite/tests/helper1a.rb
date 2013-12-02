# encoding: utf-8

module Yast
  module Helper1aInclude
    def initialize_helper1a(include_target)
      Yast.import "Testsuite"

      @READ = {
        "probe"     => {
          "architecture" => "i386",
          "bios"         => [{ "lba_support" => true }],
          "cdrom"        => []
        },
        "proc"      => {
          "swaps"   => [],
          "meminfo" => { "memtotal" => 256 * 1024 }
        },
        "sysconfig" => {
          "storage"    => { "DEFAULT_FS" => "btrfs" },
          "bootloader" => { "LOADER_TYPE" => "grub" },
          "language"   => { "RC_LANG" => "en_US.UTF-8", "RC_LC_MESSAGES" => "" }
        },
        "target"    => {
          "size"        => 0,
          "bash_output" => {},
          "yast2"       => {},
          "dir"         => []
        }
      }

      Testsuite.Init([@READ, {}, @READ], nil)

      Yast.import "Stage"

      Stage.Set("initial")
    end
  end
end
