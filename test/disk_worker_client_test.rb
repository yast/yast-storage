#!/usr/bin/env rspec

require_relative "spec_helper"
require_relative "../src/clients/disk_worker"

describe Yast::DiskWorkerClient do
  subject(:client) { Yast::DiskWorkerClient.new }

  describe "#main" do
    before do
      allow(Yast::Storage).to receive(:InitLibstorage).and_return(true)
      allow(Yast::Storage).to receive(:FinishLibstorage)
      allow(Yast::Storage).to receive(:SwitchUiAutomounter)
      allow(Yast::Storage).to receive(:SaveUsedFs)
      allow(Yast::FileSystems).to receive(:read_default_subvol_from_target)
    end

    it "launches the inst_disk client" do
      expect(Yast::WFM).to receive(:CallFunction).with("inst_disk", [true, true])
      client.main
    end

    it "reads the Btrfs default subvolume name" do
      expect(Yast::FileSystems).to receive(:read_default_subvol_from_target)
      client.main
    end

    it "initializes and finishes libstorage" do
      expect(Yast::Storage).to receive(:InitLibstorage).with(false).and_return(true)
      expect(Yast::Storage).to receive(:FinishLibstorage)
      client.main
    end

    it "saves used filesystems" do
      expect(Yast::Storage).to receive(:SaveUsedFs)
      client.main
    end

    context "when libstorage initialization fails" do
      before do
        allow(Yast::Storage).to receive(:InitLibstorage).and_return(false)
      end

      it "does not launch the inst_disk client" do
        expect(Yast::WFM).to_not receive(:CallFunction)
        client.main
      end
    end
  end
end
