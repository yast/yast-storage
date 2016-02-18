#!/usr/bin/env rspec

require_relative "../spec_helper"
require "storage/shadowed_vol_helper"

Yast.import "Storage"

describe Yast::ShadowedVolHelper do
  def find_partition(target_map, mount_point)
    partitions = target_map.values.each_with_object([]) do |disk, list|
      list.concat(disk.fetch("partitions", []))
    end
    partitions.detect { |part| part["mount"] == mount_point }
  end

  def find_subvol(partition, name)
    subvols = partition["subvol"] || []
    subvols.detect { |subvol| subvol["name"] == name }
  end

  def update_partition(target_map, path, new_part, clean_deleted: false)
    old = find_partition(target_map, path)
    target_map["/dev/vda"]["partitions"].delete(old)
    target_map["/dev/vda"]["partitions"] << new_part if new_part
    if clean_deleted
      new_part["subvol"].delete_if { |subvol| subvol["delete"] }
    end
  end

  subject(:helper) { Yast::ShadowedVolHelper.instance }

  before do
    allow(Yast::FileSystems).to receive(:default_subvol).and_return("@")
    helper.reset
  end

  describe "#root_partition" do
    let(:new_root) { helper.root_partition(target_map: target_map) }

    context "when no subvolume is shadowed" do
      let(:target_map) { build_map("gpt-btrfs") }

      it "returns an exact copy of the current root partition" do
        root = find_partition(target_map, "/")
        expect(new_root).to eq root
        expect(new_root).to_not equal root
      end
    end

    context "when the partitions shadow some subvolumes" do
      let(:target_map) { build_map("msdos-btrfs-shadowed-twice") }

      it "marks the subvolumes for deletion" do
        subvol = find_subvol(new_root, "@/boot/grub2/i386-pc")
        expect(subvol["delete"]).to eq true
        subvol = find_subvol(new_root, "@/home")
        expect(subvol["delete"]).to eq true
      end

      context "after removing one of the offender partitions" do
        before do
          update_partition(target_map, "/", new_root, clean_deleted: clean)
          update_partition(target_map, "/boot", nil)
        end

        context "and committing the changes" do
          let(:clean) { true }

          it "restores the corresponding subvolumes" do
            second_root = helper.root_partition(target_map: target_map)
            subvol = find_subvol(second_root, "@/boot/grub2/i386-pc")
            expect(subvol["delete"]).to_not eq true
          end

          it "does not restore another subvolumes" do
            second_root = helper.root_partition(target_map: target_map)
            subvol = find_subvol(second_root, "@/home")
            expect(subvol["delete"]).to eq true
          end

          it "does not restore the subvolume if #reset was called" do
            helper.reset
            second_root = helper.root_partition(target_map: target_map)
            subvol = find_subvol(second_root, "@/boot/grub2/i386-pc")
            expect(subvol).to be_nil
          end
        end

        context "before committing the changes" do
          let(:clean) { false }

          it "restores the corresponding subvolumes" do
            second_root = helper.root_partition(target_map: target_map)
            subvol = find_subvol(second_root, "@/boot/grub2/i386-pc")
            expect(subvol["delete"]).to_not eq true
          end

          it "does not restore another subvolumes" do
            second_root = helper.root_partition(target_map: target_map)
            subvol = find_subvol(second_root, "@/home")
            expect(subvol["delete"]).to eq true
          end

          it "does not restore the subvolume if #reset was called" do
            helper.reset
            second_root = helper.root_partition(target_map: target_map)
            subvol = find_subvol(second_root, "@/boot/grub2/i386-pc")
            expect(subvol["delete"]).to eq true
          end
        end
      end
    end
  end
end
