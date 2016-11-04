#!/usr/bin/env rspec

ENV["Y2DIR"] = File.expand_path("../../src", __FILE__)

require "yast"

Yast.import "Storage"
Yast.import "StorageInit"

describe "Yast::Storage" do
  subject { Yast::Storage }

  before do
    subject.InitLibstorage(false)
  end

  describe "#SetUserdata" do
    it "sets given user data for a given device" do
      # non-zero error for device that does not exist
      expect(subject.SetUserdata("/dev/ice/does/not/exist", { "/" => "snapshots" })).not_to eq(0)
    end
  end

  describe "#default_subvolume_name" do
    it "returns the default subvolume name according to FileSystems" do
      expect(Yast::FileSystems).to receive(:default_subvol).and_return("SOME-VALUE")
      expect(subject.default_subvolume_name).to eq("SOME-VALUE")
    end
  end
end
