#!/usr/bin/env rspec

require_relative "spec_helper"

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
