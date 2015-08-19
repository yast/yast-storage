#!/usr/bin/env rspec

ENV["Y2DIR"] = File.expand_path("../../src", __FILE__)

require "yast"

Yast.import "Storage"
Yast.import "StorageInit"

describe "Yast::Storage" do
  before do
    Yast::Storage.InitLibstorage(false)
  end

  describe "#SetUserdata" do
    it "sets given user data for a given device" do
      # non-zero error for device that does not exist
      expect(Yast::Storage.SetUserdata("/dev/ice/does/not/exist", { "/" => "snapshots" })).not_to eq(0)
    end
  end
end
