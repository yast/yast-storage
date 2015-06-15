#!/usr/bin/rspec

require_relative "spec_helper"
require "storage/target_map_formatter"
require "pp"


describe Yast::StorageHelpers::TargetMapFormatter do

  # Workaround to test Ruby modules part 1: Use a dummy class that includes the module
  class DummyClass
    include Yast::StorageHelpers::TargetMapFormatter
  end


  before (:all) do
    # Workaround to test Ruby modules part 2: Instantiate the dummy class
    @formatter = DummyClass.new

    @sample_target_map =
    {
      "create" => true,
      "detected_fs" => "btrfs",
      "device" => "/dev/sda2",
      "format" => true,
      "fsid" => 131,
      "fstype" => "Linux native",
      "inactive" => true,
      "mount" => "/",
      "mountby" => "uuid",
      "name" => "sda2",
      "nr" => 2,
      "region" =>  [190, 1306],
      "size_k" => 10490445,
      "subvol" =>
      [
        { "create" => true, "name" => "boot/grub2/i386-pc"},
        { "create" => true, "name" => "boot/grub2/x86_64-efi"},
        { "create" => true, "name" => "opt"},
        { "create" => true, "name" => "srv"},
        { "create" => true, "name" => "tmp"},
        { "create" => true, "name" => "usr/local"},
        { "create" => true, "name" => "var/crash"},
        { "create" => true, "name" => "var/lib/mailman"},
        { "create" => true, "name" => "var/lib/named"},
        { "create" => true, "name" => "var/lib/pgsql"},
        { "create" => true, "name" => "var/log"},
        { "create" => true, "name" => "var/opt"},
        { "create" => true, "name" => "var/spool"},
        { "create" => true, "name" => "var/tmp"}
      ],
      "type" => "primary",
      "udev_id" =>
      [
        "ata-QEMU_HARDDISK_QM00001-part2",
        "scsi-0ATA_QEMU_HARDDISK_QM00001-part2",
        "scsi-1ATA_QEMU_HARDDISK_QM00001-part2",
        "scsi-SATA_QEMU_HARDDISK_QM00001-part2"
      ],
      "udev_path" => "pci-0000:00:01.1-ata-1.0-part2",
      "used_by" =>
      [
        { "device" => "12345", "type" => "UB_BTRFS" }
      ],
      "used_by_device" => "12345",
      "used_by_type" => "UB_BTRFS",
      "used_fs" => "btrfs",
      "userdata" => { "/" => "snapshots" },
      "uuid" => "12345"
    }

    # Expected sample output. Uncomment the 'puts' in
    # the real-world test case to get this output.
    @sample_output = <<'SAMPLE_EOF'
{
    "create" => "true",
    "detected_fs" => "btrfs",
    "device" => "/dev/sda2",
    "format" => "true",
    "fsid" => "131",
    "fstype" => "Linux native",
    "inactive" => "true",
    "mount" => "/",
    "mountby" => "uuid",
    "name" => "sda2",
    "nr" => "2",
    "region" =>
    [
        "190",
        "1306"
    ],
    "size_k" => "10490445",
    "subvol" =>
    [
        { "create" => "true", "name" => "boot/grub2/i386-pc" },
        { "create" => "true", "name" => "boot/grub2/x86_64-efi" },
        { "create" => "true", "name" => "opt" },
        { "create" => "true", "name" => "srv" },
        { "create" => "true", "name" => "tmp" },
        { "create" => "true", "name" => "usr/local" },
        { "create" => "true", "name" => "var/crash" },
        { "create" => "true", "name" => "var/lib/mailman" },
        { "create" => "true", "name" => "var/lib/named" },
        { "create" => "true", "name" => "var/lib/pgsql" },
        { "create" => "true", "name" => "var/log" },
        { "create" => "true", "name" => "var/opt" },
        { "create" => "true", "name" => "var/spool" },
        { "create" => "true", "name" => "var/tmp" }
    ],
    "type" => "primary",
    "udev_id" =>
    [
        "ata-QEMU_HARDDISK_QM00001-part2",
        "scsi-0ATA_QEMU_HARDDISK_QM00001-part2",
        "scsi-1ATA_QEMU_HARDDISK_QM00001-part2",
        "scsi-SATA_QEMU_HARDDISK_QM00001-part2"
    ],
    "udev_path" => "pci-0000:00:01.1-ata-1.0-part2",
    "used_by" =>
    [
        { "device" => "12345", "type" => "UB_BTRFS" }
    ],
    "used_by_device" => "12345",
    "used_by_type" => "UB_BTRFS",
    "used_fs" => "btrfs",
    "userdata" => { "/" => "snapshots" },
    "uuid" => "12345"
}
SAMPLE_EOF
  end

  describe "using a trivial map" do
    it "should format as one-liner" do
      @trivial_map = { "one" => "1", "two" => "2", "three" => "3" }
      expect( @formatter.format_target_map( @trivial_map ) ).to be == '{ "one" => "1", "two" => "2", "three" => "3" }'
    end
  end

  describe "using real world target map" do
    it "should format sample data as expected" do
      # Uncomment to get actual output (e.g. to update @sample_output above),
      # but watch out for the final newline the 'here' document adds (thus the 'chomp')
      # puts @formatter.format_target_map(@sample_target_map)
      expect( @formatter.format_target_map(@sample_target_map) ).to be == @sample_output.chomp
    end
  end

  describe "Fringe cases:" do
    it "should not choke on an empty map" do
      expect( @formatter.format_target_map( {} ) ).to be == "{}"
    end
    it "should not choke on an empty array" do
      expect( @formatter.format_target_map( [] ) ).to be == "[]"
    end
    it "should survive nil input" do
      expect( @formatter.format_target_map( nil ) ).to be == "<nil>"
    end
  end

end
