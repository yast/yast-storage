#!/usr/bin/rspec

ENV["Y2DIR"] = File.expand_path("../../src", __FILE__)

require "yast"

Yast.import "StorageUtils"


describe "StorageUtils#ConfigureSnapper" do


  it "configures snapper" do

    data = {
      "device" => "/dev/sda1",
      "mount" => "/",
      "used_fs" => :btrfs,
      "userdata" => { "/" => "snapshots" }
    }

    Yast::Storage.stub(:GetEntryForMountpoint).with("/").once.and_return(data)

    Yast::SCR.stub(:Execute).and_return(1)
    Yast::SCR.should_receive(:Execute).exactly(2).times.and_return(0)

    Yast::SCR.stub(:Write).and_return(1)
    Yast::SCR.should_receive(:Write).exactly(1).times.and_return(0)

    Yast::StorageUtils.ConfigureSnapper()

  end


  it "does not configure snapper" do

    data = {
      "device" => "/dev/sda1",
      "mount" => "/",
      "used_fs" => :btrfs
    }

    Yast::Storage.stub(:GetEntryForMountpoint).with("/").once.and_return(data)

    Yast::SCR.stub(:Execute).and_return(1)
    Yast::SCR.should_receive(:Execute).exactly(0).times

    Yast::SCR.stub(:Write).and_return(1)
    Yast::SCR.should_receive(:Write).exactly(0).times

    Yast::StorageUtils.ConfigureSnapper()

  end


end
