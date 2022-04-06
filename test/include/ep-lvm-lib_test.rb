#!/usr/bin/env rspec

# Copyright (c) [2022] SUSE LLC
#
# All Rights Reserved.
#
# This program is free software; you can redistribute it and/or modify it
# under the terms of version 2 of the GNU General Public License as published
# by the Free Software Foundation.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
# FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
# more details.
#
# You should have received a copy of the GNU General Public License along
# with this program; if not, contact SUSE LLC.
#
# To contact SUSE LLC about this file by physical or electronic mail, you may
# find current contact information at www.suse.com.

require_relative "../spec_helper"

describe "Yast::PartitioningEpLvmLibInclude" do
  # Dummy client
  module DummyYast
    class StorageClient < Yast::Client
      include Yast::I18n

      def main
        Yast.include self, "partitioning/ep-lvm-lib.rb"
      end

      def initialize
        main
      end
    end
  end

  subject { DummyYast::StorageClient.new }

  describe "#device_kernel_name" do
    let(:target_map) do
      {
        "/dev/mapper/mpathne" => {
          "device"=>"/dev/mapper/mpathne",
          "udev_id"=> ["dm-uuid-mpath-360050768108100bff000000000000824", "dm-name-mpathne"],
          "partitions"=> [
            {
              "device"=>"/dev/mapper/mpathne-part1",
              "udev_id"=> [
                "dm-uuid-part1-mpath-360050768108100bff000000000000824",
                "dm-name-mpathne-part1"
              ]
            }
          ]
        },
        "/dev/mapper/mpathnn" => {
          "device"=>"/dev/mapper/mpathnn",
          "udev_id"=> ["dm-uuid-mpath-360050768108100bff000000000000825", "dm-name-mpathnn"],
          "partitions"=> [
            {
              "device"=>"/dev/mapper/mpathnn-part1",
              "udev_id"=> [
                "dm-uuid-part1-mpath-360050768108100bff000000000000825",
                "dm-name-mpathnn-part1"
              ]
            }
          ]
        }
      }
    end

    context "when the given name is a known kernel name" do
      let(:device) { "/dev/mapper/mpathne" }

      it "returns the given name" do
        expect(subject.device_kernel_name(target_map, device)).to eq(device)
      end
    end

    context "when the given name is a unknown kernel name" do
      let(:device) { "/dev/mapper/mpathnz" }

      it "returns the given name" do
        expect(subject.device_kernel_name(target_map, device)).to eq(device)
      end
    end

    context "when the given name is a known device udev name" do
      let(:device) { "/dev/disk/by-id/dm-uuid-mpath-360050768108100bff000000000000824" }

      it "returns the device kernel name" do
        expect(subject.device_kernel_name(target_map, device)).to eq("/dev/mapper/mpathne")
      end
    end

    context "when the given name is a known partition udev name" do
      let(:device) { "/dev/disk/by-id/dm-uuid-part1-mpath-360050768108100bff000000000000825" }

      it "returns the partition kernel name" do
        expect(subject.device_kernel_name(target_map, device)).to eq("/dev/mapper/mpathnn-part1")
      end
    end

    context "when the given name is a unknown udev name" do
      let(:device) { "/dev/disk/by-id/dm-uuid-mpath-360050768108100bff000000000000899" }

      it "returns the given device" do
        expect(subject.device_kernel_name(target_map, device)).to eq(device)
      end
    end
  end
end
