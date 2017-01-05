#!/usr/bin/env rspec

require_relative "spec_helper"

Yast.import "FileSystems"
Yast.import "Storage"

describe Yast::FileSystems do
  subject { Yast::FileSystems }

  def btrfs_list_fixture(name)
    fixture_name = "btrfs_list_#{name}.out"
    File.read(File.join(FIXTURES_PATH, fixture_name))
  end

  let(:default_subvol) { "@" }
  let(:libstorage) do
    double("libstorage", getDefaultSubvolName: default_subvol, setDefaultSubvolName: default_subvol)
  end

  before do
    subject.InitSlib(libstorage)
  end

  describe "#default_subvol_from_target" do
    before do
      allow(Yast::Storage).to receive(:GetTargetMap).and_return(target_map)
      allow(Yast::ProductFeatures).to receive(:GetStringFeature)
        .with("partitioning", "btrfs_default_subvolume").and_return(default_subvol)
    end

    context "when root partition uses the default subvolume name (@)" do
      let(:target_map) { YAML.load_file(File.join(FIXTURES_PATH, "subvolumes.yml")) }

      before do
        allow(Yast::Execute).to receive(:on_target).with("btrfs", "subvol", "list", "/", anything)
          .and_return(btrfs_list_fixture("root"))
        allow(Yast::Execute).to receive(:on_target).with("btrfs", "subvol", "list", "/srv", anything)
          .and_return(btrfs_list_fixture("root_no_at"))
      end

      it "returns the default subvolume name" do
        expect(subject.default_subvol_from_target).to eq(default_subvol)
      end
    end

    context "when root partitions does not use btrfs" do
      let(:target_map) { YAML.load_file(File.join(FIXTURES_PATH, "subvolumes-no-root.yml")) }

      before do
        allow(Yast::Execute).to receive(:on_target).with("btrfs", "subvol", "list", "/", anything)
          .and_return(btrfs_list_fixture("root_no_at"))
      end

      context "but all btrfs partitions uses the same subvolume name" do
        before do
          allow(Yast::Execute).to receive(:on_target).with("btrfs", "subvol", "list", "/srv", anything)
            .and_return(btrfs_list_fixture("srv_no_at"))
          allow(Yast::Execute).to receive(:on_target).with("btrfs", "subvol", "list", "/data", anything)
            .and_return(btrfs_list_fixture("data_no_at"))
        end

        it "returns the used name ('' in this case)" do
          expect(subject.default_subvol_from_target).to eq("")
        end
      end

      context "and btrfs partitions uses different subvolume names" do
        before do
          allow(Yast::Execute).to receive(:on_target).with("btrfs", "subvol", "list", "/srv", anything)
            .and_return(btrfs_list_fixture("srv"))
          allow(Yast::Execute).to receive(:on_target).with("btrfs", "subvol", "list", "/data", anything)
            .and_return(btrfs_list_fixture("data_no_at"))
        end

        it "returns the distribution default" do
          expect(subject.default_subvol_from_target).to eq(default_subvol)
        end
      end
    end
  end

  describe "#read_default_subvol_from_target" do
    it "sets the default_subvol using the value from target" do
      subject.default_subvol = ""
      expect(subject).to receive(:default_subvol_from_target).and_return("@")
      expect { subject.read_default_subvol_from_target }.to change { subject.default_subvol }
        .from("").to("@")
    end
  end

  describe "#default_subvol=" do
    it "sets the default_subvol if a valid value is given" do
      expect(libstorage).to receive(:setDefaultSubvolName).with("@")
      subject.default_subvol = "@"
    end

    it "refuses to set default_subvol if an invalid value is given" do
      expect(libstorage).to_not receive(:setDefaultSubvolName)
      subject.default_subvol = "UNDEFINED"
    end
  end
end
