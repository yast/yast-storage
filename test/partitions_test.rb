#!/usr/bin/env rspec

require_relative "spec_helper"

Yast.import "Partitions"
Yast.import "Arch"

describe Yast::Partitions do
  subject(:partitions) { Yast::Partitions }

  describe "#prep_boot_needed?" do
    before do
      allow(Yast::Partitions).to receive(:PrepBoot).and_return(prep_boot)
      allow(Yast::Arch).to receive(:board_iseries).and_return(iseries)
    end

    context "when PrepBoot is true and machine does not belongs to iSeries" do
      let(:prep_boot) { true }
      let(:iseries) { false }

      it "returns true" do
        expect(partitions.prep_boot_needed?).to eq(true)
      end
    end

    context "when PrepBoot is false" do
      let(:prep_boot) { false }
      let(:iseries) { false }

      it "returns false" do
        expect(partitions.prep_boot_needed?).to eq(false)
      end
    end

    context "when PrepBoot is true and machine belongs to iSeries" do
      let(:prep_boot) { true }
      let(:iseries) { true }

      it "returns false" do
        expect(partitions.prep_boot_needed?).to eq(false)
      end
    end
  end
end
