# encoding: utf-8

require 'rexml/document'

module Yast
  module Helper1aInclude

    def initialize_helper1a(include_target)
      Yast.import "Testsuite"

      @READ = {
        "probe"     => {
          "architecture" => "i386",
          "bios"         => [ { "lba_support" => true } ],
          "cdrom"        => [],
          "system"       => [ { "system" => "" } ]
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

      begin
        file = File.new("tmp/arch.info")
        doc = REXML::Document.new(file)
        arch = doc.elements["arch"].elements["arch"].text
        system = ""
        if arch == "s390x"
          arch = "s390_64"
        end
        if arch == "ppc64le"
          arch = "ppc64"
          system = "CHRP"
        end
        @READ["probe"]["architecture"] = arch
        @READ["probe"]["system"][0]["system"] = system
      rescue Errno::ENOENT
      end

      Testsuite.Init([@READ, {}, @READ], nil)

      Yast.import "Stage"

      Stage.Set("initial")
    end

  end
end
