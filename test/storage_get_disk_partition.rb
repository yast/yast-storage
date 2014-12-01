#!/usr/bin/env rspec

ENV["Y2DIR"] = File.expand_path("../../src", __FILE__)

require "yast"

Yast.import "Storage"


describe "Storage#GetDiskPartition" do


  it "call for /dev/tmpfs" do

    data = {
      "disk" => "/dev/tmpfs",
      "nr" => ""
    }

    Yast::Storage.InitLibstorage(true)

    expect(Yast::Storage.GetDiskPartition("/dev/tmpfs")).to eq(data)

  end


  it "call for tmpfs" do

    data = {
      "disk" => "/dev/tmpfs",
      "nr" => "tmpfs"
    }

    Yast::Storage.InitLibstorage(true)

    expect(Yast::Storage.GetDiskPartition("tmpfs")).to eq(data)

  end


end
