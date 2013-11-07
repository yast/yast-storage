#! /usr/bin/env rspec

ENV["Y2DIR"] = File.expand_path("../../src", __FILE__)

require "yast"

Yast.import "Kernel"
Yast.import "Storage"

# Target Map used for testing handling Kernel modules at boot
KERNEL_MODULES_TARGET_MAP = {
  "/dev/sda" => {
    "bios_id" => "0x80",
    "bus" => "IDE",
    "cyl_count" => 38913, "cyl_size" => 8225280,
    "device" => "/dev/sda",
    "driver" => "ahci",
    "driver_module" => "ahci",
    "label" => "msdos",
    "max_logical" => 255,
    "max_primary" => 4,
    "model" => "HTS72323",
    "name" => "sda",
    "partitions" => [
      {
        "crypt_device" => "/dev/mapper/cr_sda7",
        "detected_fs" => :ext4,
        "device" => "/dev/sda7",
        "enc_type" => :none,
        "fsid" => 131,
        "fstopt" => "acl,user_xattr",
        "fstype" => "Linux native",
        "mount" => "/home",
        "mountby" => :device,
        "name" => "sda7",
        "noauto" => false,
        "nr" => 7,
        "region" => [14776, 24097],
        "size_k" => 193556480,
        "type" => :logical,
        "udev_id" => [
          "ata-HITACHI_HTS723232A7A364_E3834563J0X2PN-part7",
          "scsi-1ATA_HITACHI_HTS723232A7A364_E3834563J0X2PN-part7",
          "scsi-SATA_HITACHI_HTS72323_E3834563J0X2PN-part7",
          "wwn-0x5000cca61ddc9871-part7"
        ],
        "udev_path" => "pci-0000:00:1f.2-scsi-0:0:0:0-part7",
        "used_fs" => :ext4,
        "uuid" => "5583b026-8e4c-4934-9e48-9c45f4b8febe"
       },
      {
        "detected_fs" => :ext4,
        "device" => "/dev/sda8",
        "fsid" => 131,
        "fstopt" => "acl,user_xattr",
        "fstype" => "Linux native",
        "mount" => "/var",
        "mountby" => :device,
        "name" => "sda8",
        "noauto" => false,
        "nr" => 8,
        "region" => [114776, 124097],
        "size_k" => 193556480,
        "type" => :logical,
        "udev_id" => [
          "ata-HITACHI_HTS723232A7A364_E3834563J0X2PN-part8",
          "scsi-1ATA_HITACHI_HTS723232A7A364_E3834563J0X2PN-part8",
          "scsi-SATA_HITACHI_HTS72323_E3834563J0X2PN-part8",
          "wwn-0x5000cca61ddc9871-part8"
        ],
        "udev_path" => "pci-0000:00:1f.2-scsi-0:0:0:0-part8",
        "used_fs" => :ext4,
        "uuid" => "5583b026-8e4c-4934-9e48-9c45f4b8febf"
       }
    ],
    "sector_size" => 512,
    "size_k" => 312571224,
    "transport" => :sata,
    "type" => :CT_DISK,
    "udev_id" => [
      "ata-HITACHI_HTS723232A7A364_E3834563J0X2PN",
      "scsi-1ATA_HITACHI_HTS723232A7A364_E3834563J0X2PN",
      "scsi-SATA_HITACHI_HTS72323_E3834563J0X2PN",
      "wwn-0x5000cca61ddc9871"
    ],
    "udev_path" => "pci-0000:00:1f.2-scsi-0:0:0:0",
    "unique" => "3OOL.GBCqMDvmsaA",
    "vendor" => "HITACHI"
  }
}

describe "#HandleModulesOnBoot" do
  it "adds 'cryptoloop' and 'twofish' modules to kernel modules loaded on boot
      if 'twofish' encryption is used and partition is not automatically mounted" do
    target_map = KERNEL_MODULES_TARGET_MAP.clone
    target_map["/dev/sda"]["partitions"][0]["enc_type"] = :twofish
    target_map["/dev/sda"]["partitions"][0]["noauto"]   = true

    Yast::Kernel.stub(:module_to_be_loaded?).and_return(false)
    Yast::Kernel.should_receive(:AddModuleToLoad).with("cryptoloop").once.and_return(true)
    Yast::Kernel.should_receive(:AddModuleToLoad).with("twofish").once.and_return(true)
    Yast::Kernel.should_not_receive(:AddModuleToLoad)
    Yast::Kernel.stub(:SaveModulesToLoad).and_return(true)

    expect(Yast::Storage.HandleModulesOnBoot(target_map)).to be_true
  end

  it "adds 'loop_fish2' module to kernel modules loaded on boot if 'twofish_old'
      encryption is used" do
    target_map = KERNEL_MODULES_TARGET_MAP.clone
    target_map["/dev/sda"]["partitions"][0]["enc_type"] = :twofish_old
    target_map["/dev/sda"]["partitions"][0]["noauto"]   = true

    Yast::Kernel.stub(:module_to_be_loaded?).and_return(false)
    Yast::Kernel.should_receive(:AddModuleToLoad).with("loop_fish2").once.and_return(true)
    Yast::Kernel.should_not_receive(:AddModuleToLoad)
    Yast::Kernel.stub(:SaveModulesToLoad).and_return(true)

    expect(Yast::Storage.HandleModulesOnBoot(target_map)).to be_true
  end

  it "adds 'loop_fish2' module to kernel modules loaded on boot if 'twofish_256_old'
      encryption is used and partition is not automatically mounted" do
    target_map = KERNEL_MODULES_TARGET_MAP.clone
    target_map["/dev/sda"]["partitions"][0]["enc_type"] = :twofish_256_old
    target_map["/dev/sda"]["partitions"][0]["noauto"]   = true

    Yast::Kernel.stub(:module_to_be_loaded?).and_return(false)
    Yast::Kernel.should_receive(:AddModuleToLoad).with("loop_fish2").once.and_return(true)
    Yast::Kernel.should_not_receive(:AddModuleToLoad)
    Yast::Kernel.stub(:SaveModulesToLoad).and_return(true)

    expect(Yast::Storage.HandleModulesOnBoot(target_map)).to be_true
  end

  it "does not add any module to kernel modules loaded on boot if partition
      is automatically mounted" do
    target_map = KERNEL_MODULES_TARGET_MAP.clone
    target_map["/dev/sda"]["partitions"][0]["enc_type"] = :twofish
    target_map["/dev/sda"]["partitions"][0]["noauto"]   = false

    Yast::Kernel.should_not_receive(:AddModuleToLoad)
    Yast::Kernel.stub(:SaveModulesToLoad).and_return(true)

    expect(Yast::Storage.HandleModulesOnBoot(target_map)).to be_true
  end

  it "does not add any module to kernel modules loaded on boot if partition
      does not use encryption" do
      target_map = KERNEL_MODULES_TARGET_MAP.clone
      target_map["/dev/sda"]["partitions"][0]["enc_type"] = :none

      Yast::Kernel.should_not_receive(:AddModuleToLoad)
      Yast::Kernel.stub(:SaveModulesToLoad).and_return(true)

      expect(Yast::Storage.HandleModulesOnBoot(target_map)).to be_true
  end
end
