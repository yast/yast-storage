#!/usr/bin/env rspec

require_relative "../spec_helper"

Yast.import "Arch"
Yast.import "AutoinstData"
Yast.import "FileSystems"
Yast.import "Partitions"
Yast.import "Popup"
Yast.import "Product"
Yast.import "Stage"

describe "Yast::PartitioningCustomPartCheckGeneratedInclude" do
  FIXTURES_PATH = File.expand_path('../../fixtures', __FILE__)

  # Dummy client to test PartitioningCustomPartCheckGeneratedInclude
  module DummyYast
    class StorageClient < Yast::Client
      include Yast::I18n

      def main
        Yast.include self, "partitioning/custom_part_check_generated.rb"
      end

      def initialize
        main
      end
    end
  end

  # Helper method to load partitioning maps
  #
  # Partitioning maps are stored in /test/fixtures as ycp files.
  #
  # @param [String] name Map name (without .ycp extension)
  # @return Hash    Hash representing information contained in the map
  def build_map(name)
    path = File.join(FIXTURES_PATH, "#{name}.ycp")
    content = Yast::SCR.Read(Yast::Path.new(".target.ycp"), path)
    raise "Fixtures #{name} not found (file #{path}) does not exist)" if content.nil?
    content
  end

  subject(:client) { DummyYast::StorageClient.new }

  describe "#check_created_partition_table" do
    let(:efi) { false } # EFI boot
    let(:arch) { "x86_64" }
    let(:boot_mount) { "/boot" }
    let(:warnings) { true }
    let(:prep_boot) { false }

    before do
      allow(Yast::SCR).to receive(:Read).with(path(".target.ycp"), anything).and_call_original
      allow(Yast::Arch).to receive(:architecture).and_return(arch)
      allow(Yast::Partitions).to receive(:EfiBoot).and_return(efi)
      allow(Yast::FileSystems).to receive(:default_subvol).and_return("@")
      allow(Yast::Product).to receive(:name).and_return("SLES 12 SP1")
      allow(Yast::AutoinstData).to receive(:BootRaidWarning).and_return(warnings)
      allow(Yast::AutoinstData).to receive(:BootCylWarning).and_return(warnings)
      allow(Yast::Partitions).to receive(:BootMount).and_return(boot_mount) # Avoid Partitions cache
      allow(Yast::Partitions).to receive(:PrepBoot).and_return(prep_boot)
    end

    context "during installation" do
      let(:installation) { true }

      before do
        Yast::Stage.Set("initial")
      end

      context "target map is ok" do
        let(:map) { build_map("gpt-btrfs") }

        it "returns true" do
          expect(Yast::Popup).to_not receive(:YesNo)
          expect(client.check_created_partition_table(map, installation)).to eq(true)
        end
      end

      context "when root partition is not present" do
        let(:map) do
          # remove /root from map
          build_map("gpt-btrfs").tap { |m| m["/dev/vda"]["partitions"].delete_at(2) }
        end

        it "warns the user and returns false" do
          expect(Yast::Popup).to receive(:YesNo).with(/have not assigned a root partition/)
            .and_return(false)
          expect(client.check_created_partition_table(map, installation)).to eq(false)
        end
      end

      context "when FAT is used for some system mount point (/, /usr, /home, /opt or /var)" do
        let(:map) { build_map("msdos-root-fat") }

        it "warns the user and returns false" do
          expect(Yast::Popup).to receive(:YesNo).with(/You tried to mount a FAT partition/)
            .and_return(false)
          expect(client.check_created_partition_table(map, installation)).to eq(false)
        end
      end

      context "when BIOS GRUB is not used" do
        context "and filesystem for /boot partition is Btrfs" do
          let(:map) { build_map("gpt-btrfs-boot") }

          it "warns the user and returns false" do
            expect(Yast::Popup).to receive(:YesNo).with(/with Btrfs to the\nmount point \/boot/)
              .and_return(false)
            expect(client.check_created_partition_table(map, installation)).to eq(false)
          end
        end

        context "and /boot partition ends after Partitions.BootCyl" do
          let(:map) { build_map("msdos-ext4-boot") }

          it "warns the user and returns false" do
            allow(Yast::Partitions).to receive(:BootCyl).and_return(32)
            expect(Yast::Popup).to receive(:YesNo).with(/Your boot partition ends above cylinder/)
              .and_return(false)
            expect(client.check_created_partition_table(map, installation)).to eq(false)
          end
        end

        context "and /boot partition is too small" do
          let(:map) do
            build_map("msdos-ext4-boot").tap do |m|
              m["/dev/vda"]["partitions"][0]["size_k"] = 1024
            end
          end

          it "warns the user and returns false" do
            expect(Yast::Popup).to receive(:YesNo).with(/Your boot partition is smaller than/)
              .and_return(false)
            expect(client.check_created_partition_table(map, installation)).to eq(false)
          end
        end

        context "and filesystem is not Btrfs and size and region are ok" do
          let(:map) { build_map("msdos-ext4-boot") }

          it "returns true" do
            expect(Yast::Popup).to_not receive(:YesNo)
            expect(client.check_created_partition_table(map, installation)).to eq(true)
          end
        end
      end

      context "when PReP/CHRP is needed" do
        let(:prep_boot) { true }

        before do
          allow(Yast::Arch).to receive(:board_chrp).and_return(true)
        end

        context "when /boot partition is not present and machine does not belong to iSeries" do
          let(:map) do
            build_map("gpt-ppc-btrfs").tap { |m| m["/dev/sda"]["partitions"].delete_at(0) }
          end

          before do
            allow(Yast::Arch).to receive(:board_iseries).and_return(false)
          end

          it "show a warning and returns false" do
            expect(Yast::Popup).to receive(:YesNo).with(/There is no partition mounted as \/boot/)
              .and_return(false)
            expect(client.check_created_partition_table(map, installation)).to eq(false)
          end
        end

        context "and a PReP boot partition is needed but machine belongs to iSeries" do
          let(:map) do
            build_map("gpt-ppc-btrfs").tap { |m| m["/dev/sda"]["partitions"].delete_at(0) }
          end

          before do
            allow(Yast::Arch).to receive(:board_iseries).and_return(true)
          end

          it "returns true" do
            expect(Yast::Popup).to_not receive(:YesNo)
            expect(client.check_created_partition_table(map, installation)).to eq(true)
          end
        end

        context "and boot partition has no mount point" do
          let(:map) { build_map("gpt-ppc-btrfs") }

          before do
            allow(Yast::Arch).to receive(:board_compatible).and_return(true)
          end

          context "and fsid matches FsidBoot" do
            it "returns true" do
              expect(Yast::Popup).to_not receive(:YesNo)
              expect(client.check_created_partition_table(map, installation)).to eq(true)
            end
          end

          context "and fsid is 6" do
            let(:map) do
              build_map("gpt-ppc-btrfs").tap do |m|
                m["/dev/sda"]["partitions"][0].merge!("fsid" => 6, "boot_size_k" => 200000)
              end
            end

            it "returns true" do
              expect(Yast::Popup).to_not receive(:YesNo)
              expect(client.check_created_partition_table(map, installation)).to eq(true)
            end
          end

          context "and fsid does not match FsidBoot" do
            it "warns the user and returns false" do
              allow(Yast::Partitions).to receive(:FsidBoot).and_return(1)
              expect(client.check_created_partition_table(map, installation)).to eq(false)
            end
          end
        end

        context "and a /boot partition is present but it's not PReP/CHRP" do
          let(:map) do
            build_map("gpt-ppc-btrfs").tap do |m|
              m["/dev/sda"]["partitions"][0].merge!("fsid" => 131, "fstype" => "Linux native")
            end
          end

          it "warns the user and returns false" do
            expect(Yast::Popup).to receive(:YesNo).with(/There is no partition mounted as \/boot/)
              .and_return(false)
            expect(client.check_created_partition_table(map, installation)).to eq(false)
          end

          context "and machine belongs to iSeries" do
            before do
              allow(Yast::Arch).to receive(:board_iseries).and_return(true)
            end

            it "returns true" do
              expect(Yast::Popup).to_not receive(:YesNo)
              expect(client.check_created_partition_table(map, installation)).to eq(true)
            end
          end
        end
      end

      context "when /boot partition is not present" do
        let(:map) do
          build_map("gpt-btrfs").tap { |m| m["/dev/vda"]["partitions"].delete_at(0) }
        end

        context "and root partition ends after Partitions.BootCyl" do
          let(:map) { build_map("msdos-ext4-boot-root") }

          it "warns the user and returns false" do
            allow(Yast::Partitions).to receive(:BootCyl).and_return(32)
            expect(Yast::Popup).to receive(:YesNo).with(/has an end cylinder above 32/)
              .and_return(false)
            expect(client.check_created_partition_table(map, installation)).to eq(false)
          end
        end

        context "and using a GPT partition table" do
          it "warns the user and returns false" do
            expect(Yast::Popup).to receive(:YesNo)
              .with(/Warning: There is no partition of type bios_grub present./)
              .and_return(false)
            expect(client.check_created_partition_table(map, installation)).to eq(false)
          end
        end

        context "and root is on a RAID1" do
          let(:map) { build_map("gpt-root-raid1") }

          it "returns true" do
            expect(Yast::Popup).to_not receive(:YesNo)
            expect(client.check_created_partition_table(map, installation)).to eq(true)
          end
        end

        context "and root is on a RAID0" do
          let(:map) { build_map("gpt-root-raid0") }

          it "warns the user and returns false" do
            expect(Yast::Popup).to receive(:YesNo).with(/installation might not be directly bootable/)
              .and_return(false)
            expect(client.check_created_partition_table(map, installation)).to eq(false)
          end
        end

        context "and root is on a RAID0 but machine belongs to iSeries" do
          let(:map) { build_map("gpt-root-raid0") }

          it "returns true" do
            allow(Yast::Arch).to receive(:board_iseries).and_return(true)
            expect(Yast::Popup).to_not receive(:YesNo)
            expect(client.check_created_partition_table(map, installation)).to eq(true)
          end
        end

        context "and root is on a RAID0 but warnings are disabled" do
          let(:map) { build_map("gpt-root-raid0") }
          let(:warnings) { false }

          it "returns true" do
            expect(Yast::Popup).to_not receive(:YesNo)
            expect(client.check_created_partition_table(map, installation)).to eq(true)
          end
        end
      end

      context "when boot is on RAID1" do
        let(:map) { build_map("gpt-boot-raid1") }

        it "returns true" do
          expect(Yast::Popup).to_not receive(:YesNo)
          expect(client.check_created_partition_table(map, installation)).to eq(true)
        end
      end

      context "when boot is on RAID0" do
        context "and machine belongs to iSeries" do
          let(:map) { build_map("gpt-boot-raid0") }

          it "returns true" do
            allow(Yast::Arch).to receive(:board_iseries).and_return(true)
            expect(Yast::Popup).to_not receive(:YesNo)
            expect(client.check_created_partition_table(map, installation)).to eq(true)
          end
        end

        context "but machine does not belongs to iSeries" do
          let(:map) { build_map("gpt-boot-raid0") }

          it "warns the user and returns false" do
            expect(Yast::Popup).to receive(:YesNo).with(/installation might not be directly bootable/)
              .and_return(false)
            expect(client.check_created_partition_table(map, installation)).to eq(false)
          end
        end

        context "and warnings are disabled" do
          let(:map) { build_map("gpt-boot-raid0") }
          let(:warnings) { false }

          it "returns true" do
            expect(Yast::Popup).to_not receive(:YesNo)
            expect(client.check_created_partition_table(map, installation)).to eq(true)
          end
        end
      end

      context "when some BTRFS subvolume is shadowed" do
        let(:map) { build_map("msdos-btrfs-shadowed") }

        it "warns the user and returns false" do
          expect(Yast::Popup).to receive(:YesNo).with(/subvolumes of the root filesystem are shadowed/)
            .and_return(false)
          expect(client.check_created_partition_table(map, installation)).to eq(false)
        end
      end

      context "when no swap is found" do
        let(:map) do
          build_map("gpt-btrfs").tap { |m| m["/dev/vda"]["partitions"].delete_at(1) }
        end

        it "warns the user and returns false" do
          expect(Yast::Popup).to receive(:YesNo).with(/have not assigned a swap partition/)
            .and_return(false)
          expect(client.check_created_partition_table(map, installation)).to eq(false)
        end
      end

      context "when some partition is mounted but won't be formatted" do
        let(:map) do
          build_map("gpt-btrfs").tap do |m|
            m["/dev/vda"]["partitions"][2]["format"] = false
          end
        end

        it "warns the user and returns false" do
          expect(Yast::Popup).to receive(:YesNo).with(/onto an existing partition that will not be\nformatted/)
            .and_return(false)
          expect(client.check_created_partition_table(map, installation)).to eq(false)
        end
      end

      context "when root is on hardware RAID" do
        context "and /boot is not found" do
          let(:map) { build_map("dmraid-ext4-boot-root") }

          it "warns the user and returns false" do
            expect(Yast::Popup).to receive(:YesNo).with(/no \nseparate \/boot partition on your RAID disk./)
              .and_return(false)
            expect(client.check_created_partition_table(map, installation)).to eq(false)
          end
        end

        context "and /boot is found" do
          let(:map) { build_map("dmraid-ext4-boot") }

          it "returns true" do
            expect(Yast::Popup).to_not receive(:YesNo)
            expect(client.check_created_partition_table(map, installation)).to eq(true)
          end
        end
      end

      context "on board_mac" do
        before do
          allow(Yast::Arch).to receive(:board_mac).and_return(true)
          allow(Yast::Arch).to receive(:board_chrp).and_return(true)
        end

        context "when boot partition has no mount point an is HFS" do
          let(:map) { build_map("msdos-hfs") }

          it "returns true" do
            expect(Yast::Popup).to_not receive(:YesNo)
            expect(client.check_created_partition_table(map, installation)).to eq(true)
          end
        end
      end

      context "on EFI" do
        let(:efi) { true }
        let(:boot_mount) { "/boot/efi" }

        context "when FAT is used for /boot" do
          let(:map) do
            build_map("gpt-boot-fat").tap do |m|
              m["/dev/vda"]["partitions"][0]["mount"] = "/boot/efi"
            end
          end

          it "returns true" do
            expect(Yast::Popup).to_not receive(:YesNo)
            expect(client.check_created_partition_table(map, installation)).to eq(true)
          end
        end

        context "when disk which contains /boot is labeled as 'msdos'" do
          let(:map) do
            build_map("msdos-boot-fat").tap do |m|
              m["/dev/vda"]["partitions"][0]["mount"] = "/boot/efi"
            end
          end

          it "warns the user and returns false" do
            expect(Yast::Popup).to receive(:YesNo)
              .with(/your \/boot partition is located does not contain a GPT/)
              .and_return(false)
            expect(client.check_created_partition_table(map, installation)).to eq(false)
          end
        end

        context "when /boot partition is not present" do
          let(:map) do
            build_map("gpt-boot-fat").tap { |m| m["/dev/vda"]["partitions"].delete_at(0) }
          end

          it "warns the user and returns false" do
            expect(Yast::Popup).to receive(:YesNo).with(/no\nFAT partition mounted on \/boot/)
            expect(client.check_created_partition_table(map, installation)).to eq(false)
          end
        end
      end

      context "on ia64" do
        let(:arch) { "ia64" }

        context "when FAT is used for /boot" do
          let(:map) { build_map("gpt-boot-fat") }

          it "returns true" do
            expect(Yast::Popup).to_not receive(:YesNo)
            expect(client.check_created_partition_table(map, installation)).to eq(true)
          end
        end

        context "when disk which contains /boot is labeled as 'msdos'" do
          let(:map) { build_map("msdos-boot-fat") }

          it "warns the user and returns false" do
            expect(Yast::Popup).to receive(:YesNo)
              .with(/your \/boot partition is located does not contain a GPT/)
              .and_return(false)
            expect(client.check_created_partition_table(map, installation)).to eq(false)
          end
        end

        context "and /boot partition is not present" do
          let(:map) do
            build_map("msdos-boot-fat").tap { |m| m["/dev/vda"]["partitions"].delete_at(0) }
          end

          it "shows a dialog and returns false" do
            expect(Yast::Popup).to receive(:YesNo).with(/no\nFAT partition mounted on \/boot/)
            expect(client.check_created_partition_table(map, installation)).to eq(false)
          end
        end
      end

      context "on no EFI nor ia64" do
        context "when FAT is used for /boot (no EFI nor ia64)" do
          let(:map) { build_map("gpt-boot-fat") }

          it "warns the user and returns false" do
            expect(Yast::Popup).to receive(:YesNo).with(/You tried to mount a FAT partition to the/)
            .and_return(false)
            expect(client.check_created_partition_table(map, installation)).to eq(false)
          end
        end

        context "when disk which contains /boot is labeled as 'msdos'" do
          let(:map) { build_map("msdos-boot-ext4") }

          it "returns true" do
            expect(Yast::Popup).to_not receive(:YesNo)
            expect(client.check_created_partition_table(map, installation)).to eq(true)
          end
        end
      end
    end

    context "during normal operation" do
      let(:installation) { false }

      before do
        Yast::Stage.Set("normal")
      end

      context "target map is ok" do
        let(:map) { build_map("gpt-btrfs") }

        it "returns true" do
          expect(Yast::Popup).to_not receive(:YesNo)
          expect(client.check_created_partition_table(map, installation)).to eq(true)
        end
      end

      context "when root partition is not present" do
        let(:map) do
          # remove /root from map
          build_map("gpt-btrfs").tap { |m| m["/dev/vda"]["partitions"].delete_at(2) }
        end

        it "returns true" do
          expect(Yast::Popup).to_not receive(:YesNo)
          expect(client.check_created_partition_table(map, installation)).to eq(true)
        end
      end

      context "when FAT is used for some system mount point (/, /usr, /home, /opt or /var)" do
        let(:map) { build_map("msdos-root-fat") }

        it "warns the user and returns false" do
          expect(Yast::Popup).to receive(:YesNo).with(/You tried to mount a FAT partition/)
            .and_return(false)
          expect(client.check_created_partition_table(map, installation)).to eq(false)
        end
      end

      context "on EFI" do
        let(:efi) { true }
        let(:boot_mount) { "/boot/efi" }

        context "when FAT is used for /boot" do
          let(:map) do
            build_map("gpt-boot-fat").tap do |m|
              m["/dev/vda"]["partitions"][0]["mount"] = "/boot/efi"
            end
          end

          it "returns true" do
            expect(Yast::Popup).to_not receive(:YesNo)
            expect(client.check_created_partition_table(map, installation)).to eq(true)
          end
        end

        context "when disk which contains /boot is labeled as 'msdos'" do
          let(:map) do
            build_map("msdos-boot-fat").tap do |m|
              m["/dev/vda"]["partitions"][0]["mount"] = "/boot/efi"
            end
          end

          it "returns true" do
            expect(Yast::Popup).to_not receive(:YesNo)
            expect(client.check_created_partition_table(map, installation)).to eq(true)
          end
        end

        context "when /boot partition is not present" do
          let(:map) do
            build_map("gpt-boot-fat").tap { |m| m["/dev/vda"]["partitions"].delete_at(0) }
          end

          it "returns true" do
            expect(Yast::Popup).to_not receive(:YesNo)
            expect(client.check_created_partition_table(map, installation)).to eq(true)
          end
        end
      end

      context "on ia64" do
        let(:arch) { "ia64" }

        context "when FAT is used for /boot" do
          let(:map) { build_map("gpt-boot-fat") }

          it "returns true" do
            expect(Yast::Popup).to_not receive(:YesNo)
            expect(client.check_created_partition_table(map, installation)).to eq(true)
          end
        end

        context "when disk which contains /boot is labeled as 'msdos'" do
          let(:map) { build_map("msdos-boot-fat") }

          it "returns true" do
            expect(Yast::Popup).to_not receive(:YesNo)
            expect(client.check_created_partition_table(map, installation)).to eq(true)
          end
        end

        context "and /boot partition is not present" do
          let(:map) do
            build_map("msdos-boot-fat").tap { |m| m["/dev/vda"]["partitions"].delete_at(0) }
          end

          it "returns true" do
            expect(Yast::Popup).to_not receive(:YesNo)
            expect(client.check_created_partition_table(map, installation)).to eq(true)
          end
        end
      end

      context "on no EFI nor ia64" do
        context "when FAT is used for /boot (no EFI nor ia64)" do
          let(:map) { build_map("gpt-boot-fat") }

          it "warns the user and returns false" do
            expect(Yast::Popup).to receive(:YesNo).with(/You tried to mount a FAT partition to the/)
            .and_return(false)
            expect(client.check_created_partition_table(map, installation)).to eq(false)
          end
        end

        context "when disk which contains /boot is labeled as 'msdos'" do
          let(:map) { build_map("msdos-boot-ext4") }

          it "returns true" do
            expect(Yast::Popup).to_not receive(:YesNo)
            expect(client.check_created_partition_table(map, installation)).to eq(true)
          end
        end
      end

      context "when BIOS GRUB is not used" do
        context "and filesystem for /boot partition is Btrfs" do
          let(:map) { build_map("gpt-btrfs-boot") }

          it "warns the user and returns false" do
            expect(Yast::Popup).to receive(:YesNo).with(/with Btrfs to the\nmount point \/boot/)
              .and_return(false)
            expect(client.check_created_partition_table(map, installation)).to eq(false)
          end
        end

        context "and /boot partition ends after Partitions.BootCyl" do
          let(:map) { build_map("msdos-ext4-boot") }

          it "returns true" do
            allow(Yast::Partitions).to receive(:BootCyl).and_return(32)
            expect(Yast::Popup).to_not receive(:YesNo)
            expect(client.check_created_partition_table(map, installation)).to eq(true)
          end
        end

        context "and /boot partition is too small" do
          let(:map) do
            build_map("msdos-ext4-boot").tap do |m|
              m["/dev/vda"]["partitions"][0]["size_k"] = 1024
            end
          end

          it "returns true" do
            expect(Yast::Popup).to_not receive(:YesNo)
            expect(client.check_created_partition_table(map, installation)).to eq(true)
          end
        end

        context "and filesystem is not Btrfs and size and region are ok" do
          let(:map) { build_map("msdos-ext4-boot") }

          it "returns true" do
            expect(Yast::Popup).to_not receive(:YesNo)
            expect(client.check_created_partition_table(map, installation)).to eq(true)
          end
        end
      end

      context "when PReP/CHRP is needed" do
        let(:prep_boot) { true }

        before do
          allow(Yast::Arch).to receive(:board_chrp).and_return(true)
        end

        context "when /boot partition is not present and machine does not belong to iSeries" do
          let(:map) do
            build_map("gpt-ppc-btrfs").tap { |m| m["/dev/sda"]["partitions"].delete_at(0) }
          end

          before do
            allow(Yast::Arch).to receive(:board_iseries).and_return(false)
          end

          it "returns true" do
            expect(Yast::Popup).to_not receive(:YesNo)
            expect(client.check_created_partition_table(map, installation)).to eq(true)
          end
        end

        context "and a PReP boot partition is needed but machine belongs to iSeries" do
          let(:map) do
            build_map("gpt-ppc-btrfs").tap { |m| m["/dev/sda"]["partitions"].delete_at(0) }
          end

          before do
            allow(Yast::Arch).to receive(:board_iseries).and_return(true)
          end

          it "returns true" do
            expect(Yast::Popup).to_not receive(:YesNo)
            expect(client.check_created_partition_table(map, installation)).to eq(true)
          end
        end

        context "and boot partition has no mount point" do
          let(:map) { build_map("gpt-ppc-btrfs") }

          before do
            allow(Yast::Arch).to receive(:board_compatible).and_return(true)
          end

          context "and fsid matches FsidBoot" do
            it "returns true" do
              expect(Yast::Popup).to_not receive(:YesNo)
              expect(client.check_created_partition_table(map, installation)).to eq(true)
            end
          end

          context "and fsid is 6" do
            let(:map) do
              build_map("gpt-ppc-btrfs").tap do |m|
                m["/dev/sda"]["partitions"][0].merge!("fsid" => 6, "boot_size_k" => 200000)
              end
            end

            it "returns true" do
              expect(Yast::Popup).to_not receive(:YesNo)
              expect(client.check_created_partition_table(map, installation)).to eq(true)
            end
          end

          context "and fsid does not match FsidBoot" do
            it "returns true" do
              allow(Yast::Partitions).to receive(:FsidBoot).and_return(1)
              expect(Yast::Popup).to_not receive(:YesNo)
              expect(client.check_created_partition_table(map, installation)).to eq(true)
            end
          end
        end

        context "and a /boot partition is present but it's not PReP/CHRP" do
          let(:map) do
            build_map("gpt-ppc-btrfs").tap do |m|
              m["/dev/sda"]["partitions"][0].merge!("fsid" => 131, "fstype" => "Linux native")
            end
          end

          it "warns the user and returns false" do
            expect(Yast::Popup).to_not receive(:YesNo)
            expect(client.check_created_partition_table(map, installation)).to eq(true)
          end

          context "and machine belongs to iSeries" do
            before do
              allow(Yast::Arch).to receive(:board_iseries).and_return(true)
            end

            it "returns true" do
              expect(Yast::Popup).to_not receive(:YesNo)
              expect(client.check_created_partition_table(map, installation)).to eq(true)
            end
          end
        end
      end

      context "when /boot partition is not present" do
        let(:map) do
          build_map("gpt-btrfs").tap { |m| m["/dev/vda"]["partitions"].delete_at(0) }
        end

        context "and root partition ends after Partitions.BootCyl" do
          let(:map) { build_map("msdos-ext4-boot-root") }

          it "returns true" do
            allow(Yast::Partitions).to receive(:BootCyl).and_return(32)
            expect(Yast::Popup).to_not receive(:YesNo)
            expect(client.check_created_partition_table(map, installation)).to eq(true)
          end
        end

        context "and using a GPT partition table" do
          it "returns true" do
            expect(Yast::Popup).to_not receive(:YesNo)
            expect(client.check_created_partition_table(map, installation)).to eq(true)
          end
        end

        context "and root is on a RAID1" do
          let(:map) { build_map("gpt-root-raid1") }

          it "returns true" do
            expect(Yast::Popup).to_not receive(:YesNo)
            expect(client.check_created_partition_table(map, installation)).to eq(true)
          end
        end

        context "and root is on a RAID0" do
          let(:map) { build_map("gpt-root-raid0") }

          it "returns true" do
            expect(Yast::Popup).to_not receive(:YesNo)
            expect(client.check_created_partition_table(map, installation)).to eq(true)
          end
        end

        context "and root is on a RAID0 but machine belongs to iSeries" do
          let(:map) { build_map("gpt-root-raid0") }

          it "returns true" do
            allow(Yast::Arch).to receive(:board_iseries).and_return(true)
            expect(client.check_created_partition_table(map, installation)).to eq(true)
          end
        end

        context "and root is on a RAID0 but warnings are disabled" do
          let(:map) { build_map("gpt-root-raid0") }
          let(:warnings) { false }

          it "returns true" do
            expect(Yast::Popup).to_not receive(:YesNo)
            expect(client.check_created_partition_table(map, installation)).to eq(true)
          end
        end
      end

      context "when boot is on RAID1" do
        let(:map) { build_map("gpt-boot-raid1") }

        it "returns true" do
          expect(Yast::Popup).to_not receive(:YesNo)
          expect(client.check_created_partition_table(map, installation)).to eq(true)
        end
      end

      context "when boot is on RAID0" do
        context "and machine belongs to iSeries" do
          let(:map) { build_map("gpt-boot-raid0") }

          it "returns true" do
            allow(Yast::Arch).to receive(:board_iseries).and_return(true)
            expect(Yast::Popup).to_not receive(:YesNo)
            expect(client.check_created_partition_table(map, installation)).to eq(true)
          end
        end

        context "but machine does not belongs to iSeries" do
          let(:map) { build_map("gpt-boot-raid0") }

          it "returns true" do
            expect(Yast::Popup).to_not receive(:YesNo)
            expect(client.check_created_partition_table(map, installation)).to eq(true)
          end
        end

        context "and warnings are disabled" do
          let(:map) { build_map("gpt-boot-raid0") }
          let(:warnings) { false }

          it "returns true" do
            expect(Yast::Popup).to_not receive(:YesNo)
            expect(client.check_created_partition_table(map, installation)).to eq(true)
          end
        end
      end

      context "when some BTRFS subvolume is shadowed" do
        let(:map) { build_map("msdos-btrfs-shadowed") }

        it "warns the user and returns false" do
          expect(Yast::Popup).to receive(:YesNo).with(/subvolumes of the root filesystem are shadowed/)
            .and_return(false)
          expect(client.check_created_partition_table(map, installation)).to eq(false)
        end
      end

      context "when no swap is found" do
        let(:map) do
          build_map("gpt-btrfs").tap { |m| m["/dev/vda"]["partitions"].delete_at(1) }
        end

        it "returns true" do
          expect(Yast::Popup).to_not receive(:YesNo)
          expect(client.check_created_partition_table(map, installation)).to eq(true)
        end
      end

      context "when some partition is mounted but won't be formatted" do
        let(:map) do
          build_map("gpt-btrfs").tap do |m|
            m["/dev/vda"]["partitions"][2]["format"] = false
          end
        end

        it "returns true" do
          expect(Yast::Popup).to_not receive(:YesNo)
          expect(client.check_created_partition_table(map, installation)).to eq(true)
        end
      end

      context "when root is on hardware RAID" do
        context "and /boot is not found" do
          let(:map) { build_map("dmraid-ext4-boot-root") }

          it "warns the user and returns false" do
            expect(Yast::Popup).to receive(:YesNo).with(/no \nseparate \/boot partition on your RAID disk./)
              .and_return(false)
            expect(client.check_created_partition_table(map, installation)).to eq(false)
          end
        end

        context "and /boot is found" do
          let(:map) { build_map("dmraid-ext4-boot") }

          it "returns true" do
            expect(Yast::Popup).to_not receive(:YesNo)
            expect(client.check_created_partition_table(map, installation)).to eq(true)
          end
        end
      end

      context "on board_mac" do
        before do
          allow(Yast::Arch).to receive(:board_mac).and_return(true)
          allow(Yast::Arch).to receive(:board_chrp).and_return(true)
        end

        context "when boot partition has no mount point an is HFS" do
          let(:map) { build_map("msdos-hfs") }

          it "returns true" do
            expect(Yast::Popup).to_not receive(:YesNo)
            expect(client.check_created_partition_table(map, installation)).to eq(true)
          end
        end
      end
    end
  end
end
