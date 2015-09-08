#!/usr/bin/env rspec

$LOAD_PATH.unshift File.expand_path("../../src", __FILE__)
ENV["Y2DIR"] = File.expand_path("../../src", __FILE__)

require "yast"

Yast.import "Storage"
Yast.import "Partitions"

describe Yast::Storage do
  subject(:storage) { Yast::Storage }

  # This is a base map. Real maps hold more information but for testing purposes this is enough.
  def base_map
    {
      "/dev/vda" =>
      { "device" => "/dev/vda",
        "label" => "gpt",
        "partitions" => [
          {
            "create" => true,
            "detected_fs" => :unknown,
            "device" => "/dev/vda1",
            "format" => true,
            "fsid" => 131,
            "fstype" => "Linux native",
            "inactive" => true,
            "mount" => "/boot",
            "type" => :primary
          }
        ]
      }
    }
  end

  # Helper function to build a map with custom boot partition information
  #
  # BASE_MAP is used as base for that map. With boot_part_data you can
  # change the boot partition information.
  #
  # @param [Hash] boot_part_data Boot partition data
  # @return [Hash] Target map with data included in boot_part_data
  def build_map(boot_part_data = {})
    new_map = base_map
    new_map["/dev/vda"]["partitions"] = [base_map["/dev/vda"]["partitions"][0].merge(boot_part_data)]
    new_map
  end

  describe "#SpecialBootHandling" do
    let(:prep_boot) { false } # PreP boot
    let(:efi_boot) { false }  # EFI boot
    let(:board_mac) { false } # Architecture board_mac
    let(:ia64) { false }      # Architecture ia64
    let(:x86_64) { false }    # Architecture x86_64
    let(:fsid_boot) { 65 }

    before do
      allow(Yast::Partitions).to receive(:PrepBoot).and_return(prep_boot)
      allow(Yast::Partitions).to receive(:EfiBoot).and_return(efi_boot)
      allow(Yast::Arch).to receive(:board_mac).and_return(board_mac)
      allow(Yast::Arch).to receive(:ia64).and_return(ia64)
      allow(Yast::Arch).to receive(:x86_64).and_return(x86_64)
      allow(Yast::Partitions).to receive(:fsid_mac_hfs).and_return(fsid)
      allow(Yast::Partitions).to receive(:FsIdToString).and_return(fstype)
      allow(Yast::Partitions).to receive(:FsidBoot).and_return(fsid)
    end

    context "when boot partition is PreP" do
      before do
        allow(Yast::Partitions).to receive(:FsidBoot).and_return(fsid)
      end

      let(:prep_boot) { true }
      let(:fsid) { 264 }
      let(:fstype) { "GPT PReP" }

      it "adjusts fsid, fstype and mount point" do
        new_map = storage.SpecialBootHandling(build_map)
        boot = new_map["/dev/vda"]["partitions"].first
        expect(boot["mount"]).to eq("")
        expect(boot["fsid"]).to eq(fsid)
        expect(boot["fstype"]).to eq(fstype)
        expect(boot["format"]).to eq(false)
      end

      context "when partition exists and id is not correct" do
        it "adds a flag to change fsid" do
          new_map = storage.SpecialBootHandling(build_map("create" => false))
          boot = new_map["/dev/vda"]["partitions"].first
          expect(boot["ori_fsid"]).to eq(131)
          expect(boot["change_fsid"]).to eq(true)
        end
      end

      context "when partition exists and id is correct" do
        it "does not add any flag to change fsid" do
          new_map = storage.SpecialBootHandling(build_map("create" => false, "fsid" => fsid))
          boot = new_map["/dev/vda"]["partitions"].first
          expect(boot["ori_fsid"]).to be_nil
          expect(boot["change_fsid"]).to be_nil
        end
      end

      context "when have PPC boot" do
        it "does not modify anything" do
          expect(Yast::Partitions).to receive(:FsidBoot).and_return(fsid)
          new_map = storage.SpecialBootHandling(build_map("mount" => "", "create" => false))
          boot = new_map["/dev/vda"]["partitions"].first
          expect(boot["mount"]).to eq("")
          expect(boot["fsid"]).to eq(131)
          expect(boot["fstype"]).to eq("Linux native")
          expect(boot["format"]).to eq(true)
        end
      end
    end

    context "when arch is 'board_mac'" do
      let(:board_mac) { true }
      let(:fsid) { 258 }
      let(:fstype) { "Apple_HFS" }

      it "adjusts fsid, fstype, mount point, used_fs and detected_fs" do
        new_map = storage.SpecialBootHandling(build_map)
        boot = new_map["/dev/vda"]["partitions"].first
        expect(boot["mount"]).to eq("")
        expect(boot["fsid"]).to eq(fsid)
        expect(boot["fstype"]).to eq(fstype)
        expect(boot["used_fs"]).to eq(:hfs)
        expect(boot["detected_fs"]).to eq(:hfs)
      end
    end

    context "when arch is 'ia64'" do
      let(:ia64) { true }
      let(:fsid) { 259 }
      let(:fstype) { "BIOS Grub" }

      it "adjusts fsid and fstype" do
        new_map = storage.SpecialBootHandling(build_map)
        boot = new_map["/dev/vda"]["partitions"].first
        expect(boot["fsid"]).to eq(fsid)
        expect(boot["fstype"]).to eq(fstype)
      end

      context "when partition exists and detected_fs is vfat" do
        it "sets the 'format' flag to false" do
          new_map = storage.SpecialBootHandling(build_map("create" => false, "format" => true, "detected_fs" => :vfat))
          boot = new_map["/dev/vda"]["partitions"].first
          expect(boot["format"]).to eq(false)
        end
      end
    end

    context "when partition is GPT on x86_64" do
      let(:x86_64) { true }
      let(:fsid) { 263 }
      let(:fstype) { "BIOS Grub" }

      it "adjusts fsid, fstype, mount point and sets 'format' flag to false" do
        new_map = Yast::Storage.SpecialBootHandling(build_map)
        boot = new_map["/dev/vda"]["partitions"].first
        expect(boot["mount"]).to eq("")
        expect(boot["fsid"]).to eq(fsid)
        expect(boot["fstype"]).to eq(fstype)
        expect(boot["format"]).to eq(false)
      end
    end
  end
end
