#!/usr/bin/env rspec

require_relative "spec_helper"

Yast.import "Partitions"
Yast.import "Arch"

describe Yast::Partitions do
  subject(:partitions) { Yast::Partitions }

  describe "#RdonlyText" do
    context "when on readonly disk during installation" do
      it "shows disk not readable text and hint to ignore this message" do
        text = partitions.RdonlyText({"device" => "/dev/sda1"}, false)
        expect(text).to include("not readable")
        expect(text).to include("ignore this message")
      end
    end

    context "when on readonly disk in expert partitioner" do
      it "shows text containing hint to Create new Partition" do
        text = partitions.RdonlyText({"device" => "/dev/sda1"}, true)
        expect(text).to include("Create New Partition Table")
      end
    end

    context "when on LDL DASD" do
      it "shows LDL text (without hint to Create new Partition)" do
        text = partitions.RdonlyText({"device" => "/dev/dasdd",
                                         "dasd_format" => ::Storage::DASDF_LDL}, true)
        expect(text).to include("LDL")
        expect(text).not_to include("Create New Partition Table")
      end
    end

    context "when on readonly disk having fake partition" do
      it "shows text about automatically generated partition" do
        text = partitions.RdonlyText({"device" => "/dev/sda1", "has_fake_partition" => true}, false)
        expect(text).to include("automatically generated")
      end
    end

  end
end
