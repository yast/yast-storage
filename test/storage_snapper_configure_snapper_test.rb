#!/usr/bin/env rspec

ENV["Y2DIR"] = File.expand_path("../../src", __FILE__)

require "yast"

Yast.import "StorageSnapper"
Yast.import "Storage"


describe "StorageSnapper#configure_snapper?" do


  subject { Yast::StorageSnapper.configure_snapper? }


  it "configures snapper" do

    data = {
      "device" => "/dev/sda1",
      "mount" => "/",
      "used_fs" => :btrfs,
      "userdata" => { "/" => "snapshots" }
    }

    allow(Yast::Storage).to receive(:GetEntryForMountpoint).with("/").once.and_return(data)

    expect(subject).to eq true

  end


  it "does not configure snapper" do

    data = {
      "device" => "/dev/sda1",
      "mount" => "/",
      "used_fs" => :btrfs
    }

    allow(Yast::Storage).to receive(:GetEntryForMountpoint).with("/").once.and_return(data)

    expect(subject).to eq false

  end


  it "does not configure snapper" do

    data = {
      "device" => "/dev/sda1",
      "mount" => "/",
      "used_fs" => :xfs,
      "userdata" => { "/" => "snapshots" }
    }

    allow(Yast::Storage).to receive(:GetEntryForMountpoint).with("/").once.and_return(data)

    expect(subject).to eq false

  end


  it "does not configure snapper" do

    data = {
      "device" => "/dev/sda1",
      "mount" => "/",
      "used_fs" => :xfs
    }

    allow(Yast::Storage).to receive(:GetEntryForMountpoint).with("/").once.and_return(data)

    expect(subject).to eq false

  end

end
