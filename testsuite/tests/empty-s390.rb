# encoding: utf-8

# testedfiles: helper1b.yh
module Yast
  class Empty1Client < Client
    def main
      Yast.include self, "setup-system.rb"

      setup_system("s390-empty")

      Yast.include self, "helper1a.rb"

      Yast.import "ProductFeatures"

      ProductFeatures.SetBooleanFeature(
        "partitioning",
        "try_separate_home",
        false
      )
      ProductFeatures.SetBooleanFeature("partitioning", "proposal_lvm", false)
      ProductFeatures.SetStringFeature(
        "partitioning",
        "vm_desired_size",
        "30 GB"
      )
      ProductFeatures.SetStringFeature(
        "partitioning",
        "root_base_size",
        "20 GB"
      )

      # FIXME: architecture should be set from arch.info
      @READ = {
        "probe"     => {
          "architecture" => "s390_64",
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

      Yast.include self, "helper1b.rb"

      nil
    end
  end
end

Yast::Empty1Client.new.main
