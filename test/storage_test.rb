#!/usr/bin/env rspec

ENV["Y2DIR"] = File.expand_path("../../src", __FILE__)

require "yast"

Yast.import "Storage"
Yast.import "StorageInit"

describe "Yast::Storage" do
  subject { Yast::Storage }

  before { subject.main }

  describe "#InitLibstorage" do
    before { Yast::Mode.SetMode(mode) }

    context "when running on normal mode" do
      let(:mode) { "normal" }

      it "reads the default subvolume from the target system" do
        expect(Yast::FileSystems).to receive(:read_default_subvol_from_target)
        subject.InitLibstorage(false)
      end
    end

    context "when running on autoinst_config mode" do
      let(:mode) { "autoinst_config" }

      it "reads the default subvolume from the target system" do
        expect(Yast::FileSystems).to receive(:read_default_subvol_from_target)
        subject.InitLibstorage(false)
      end
    end

    context "when running on installation mode" do
      let(:mode) { "installation" }

      it "does not read the default subvolume" do
        expect(Yast::FileSystems).to_not receive(:read_default_subvol_from_target)
        subject.InitLibstorage(false)
      end
    end
  end

  describe "#SetUserdata" do
    before { subject.InitLibstorage(false) }

    it "sets given user data for a given device" do
      # non-zero error for device that does not exist
      expect(subject.SetUserdata("/dev/ice/does/not/exist", { "/" => "snapshots" })).not_to eq(0)
    end
  end

  describe "#default_subvolume_name" do
    before { subject.InitLibstorage(false) }

    it "returns the default subvolume name according to FileSystems" do
      expect(Yast::FileSystems).to receive(:default_subvol).and_return("SOME-VALUE")
      expect(subject.default_subvolume_name).to eq("SOME-VALUE")
    end
  end
end
