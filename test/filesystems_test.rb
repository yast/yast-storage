#!/usr/bin/env rspec

require_relative "spec_helper"

Yast.import "FileSystems"
Yast.import "Storage"

describe Yast::FileSystems do
  subject { Yast::FileSystems }

  describe "#default_subvol_from_filesystem" do
    let(:target_map) { YAML.load_file(File.join(FIXTURES_PATH, "subvolumes.yml")) }
    let(:btrfs_list) { File.read(File.join(FIXTURES_PATH, "btrfs_list.out")) }
    let(:btrfs_list_no_at) { File.read(File.join(FIXTURES_PATH, "btrfs_list_no_at.out")) }
    let(:default_subvol) { "@" }

    before do
      allow(Yast::Storage).to receive(:GetTargetMap).and_return(target_map)
      allow(Yast::ProductFeatures).to receive(:GetStringFeature)
        .with("partitioning", "btrfs_default_subvolume").and_return(default_subvol)
    end

    context "when root partition uses the default subvolume name (@)" do
      let(:btrfs_list) { File.read(File.join(FIXTURES_PATH, "btrfs_list.out")) }

      it "returns the default subvolume name" do
        allow(Yast::Execute).to receive(:on_target).with("btrfs", "subvol", "list", "/", anything)
          .and_return(btrfs_list)
        allow(Yast::Execute).to receive(:on_target).with("btrfs", "subvol", "list", "/srv", anything)
          .and_return(btrfs_list_no_at)
        expect(subject.default_subvol_from_filesystem).to eq(default_subvol)
      end
    end

    context "when root partitions does not use the default subvolume name (@)" do
      before do
        allow(Yast::Execute).to receive(:on_target).with("btrfs", "subvol", "list", "/", anything)
          .and_return(btrfs_list_no_at)
      end

      context "but all partitions uses the same subvolume name" do
        before do
          allow(Yast::Execute).to receive(:on_target).with("btrfs", "subvol", "list", "/srv", anything)
            .and_return(btrfs_list_no_at)
        end

        it "returns the used name ('' in this case)" do
          expect(subject.default_subvol_from_filesystem).to eq("")
        end
      end

      context "and partitions uses different subvolume names" do
        before do
          allow(Yast::Execute).to receive(:on_target).with("btrfs", "subvol", "list", "/srv", anything)
            .and_return(btrfs_list_fixture("srv"))
          allow(Yast::Execute).to receive(:on_target).with("btrfs", "subvol", "list", "/data", anything)
            .and_return(btrfs_list_fixture("data_no_at"))
        end

        it "returns the distribution default" do
          expect(subject.default_subvol_from_filesystem).to eq("")
        end
      end
    end
  end
end
