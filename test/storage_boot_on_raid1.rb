#!/usr/bin/env rspec

$LOAD_PATH.unshift File.expand_path('../../src', __FILE__)
ENV["Y2DIR"] = File.expand_path("../../src", __FILE__)

require "yast"

require "include/partitioning/custom_part_lib"

class CustomPartLib < Yast::Client
  include Singleton
  def initialize
    Yast.include self, "partitioning/custom_part_lib.rb"
  end
end

Yast.import "Arch"
Yast.import "Partitions"

describe "CustomPartLib#CheckOkMount" do


  it "/boot is only possible with RAID1 on PowerPC" do

    allow(Yast::Arch).to receive(:architecture).and_return("ppc")
    allow(Yast::Partitions).to receive(:EfiBoot).and_return(false)

    expect(CustomPartLib.instance.check_raid_mount_points("/boot", "raid1")).to eq true
  end

  it "We cannot put /boot/zipl on any RAID" do

    allow(Yast::Arch).to receive(:architecture).and_return("s390_64")
    allow(Yast::Partitions).to receive(:EfiBoot).and_return(false)

    expect(CustomPartLib.instance.check_raid_mount_points("/boot/zipl", "raid1")).to eq false
  end

  it "x86 can boot with /boot on RAID1 " do

    allow(Yast::Arch).to receive(:architecture).and_return("x86_64")
    allow(Yast::Partitions).to receive(:EfiBoot).and_return(false)

    expect(CustomPartLib.instance.check_raid_mount_points("/boot", "raid1")).to eq true
  end

end
