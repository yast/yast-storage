#!/usr/bin/env rspec

ENV["Y2DIR"] = File.expand_path("../../src", __FILE__)

require "yast"

Yast.import "StorageSnapper"
Yast.import "Storage"


describe "StorageSnapper#ConfigureSnapper?" do


  it "configures snapper" do

    data = {
      "device" => "/dev/sda1",
      "mount" => "/",
      "used_fs" => :btrfs,
      "userdata" => { "/" => "snapshots" }
    }

    Yast::Storage.stub(:GetEntryForMountpoint).with("/").once.and_return(data)

    expect(Yast::StorageSnapper.ConfigureSnapper?).to be_true

  end


  it "does not configure snapper" do

    data = {
      "device" => "/dev/sda1",
      "mount" => "/",
      "used_fs" => :btrfs
    }

    Yast::Storage.stub(:GetEntryForMountpoint).with("/").once.and_return(data)

    expect(Yast::StorageSnapper.ConfigureSnapper?).to be_false

  end


end
