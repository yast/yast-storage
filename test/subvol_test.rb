#!/usr/bin/env rspec

require_relative "spec_helper"
require "storage/subvol"
require "pp"
Yast.import "Arch"


describe Yast::StorageClass::Subvol do

  context "#new" do
    let(:current_arch) { Yast::Arch.arch_short }

    describe "Simple subvol with defaults" do
      subject { Yast::StorageClass::Subvol.new("var/spool") }

      it "has the correct path" do
        expect(subject.path).to be == "var/spool"
      end

      it "is COW" do
        expect(subject.cow?).to be true
      end

      it "is not arch-specific" do
        expect(subject.arch_specific?).to be false
      end

      it "matches arch 'fake'" do
        expect(subject.matches_arch?("fake")).to be true
      end
    end

    describe "NoCOW subvol" do
      subject { Yast::StorageClass::Subvol.new("var/lib/mysql", copy_on_write: false) }

      it "is NoCOW" do
        expect(subject.no_cow?).to be true
      end

      it "is not arch-specific" do
        expect(subject.arch_specific?).to be false
      end
    end

    describe "simple arch-specific subvol" do
      subject { Yast::StorageClass::Subvol.new("boot/grub2/fake-arch", archs: ["fake-arch"]) }

      it "is arch specific" do
        expect(subject.arch_specific?).to be true
      end

      it "does not match the current arch" do
        expect(subject.current_arch?).to be false
      end
    end

    describe "arch-specific subvol for current arch" do
      subject { Yast::StorageClass::Subvol.new("boot/grub2/fake-arch", archs: ["fake-arch", current_arch]) }

      it "is arch specific" do
        expect(subject.arch_specific?).to be true
      end

      it "matches the current arch" do
        expect(subject.current_arch?).to be true
      end
    end

    describe "arch-specific subvol for everything except the current arch" do
      subject { Yast::StorageClass::Subvol.new("boot/grub2/fake-arch", archs: ["!#{current_arch}"]) }

      it "does not match the current arch" do
        expect(subject.current_arch?).to be false
      end
    end
  end

  context "#create_from_xml" do
    describe "Fully specified subvol" do
      subject do
        xml = { "path" => "var/fake", "copy_on_write" => false, "archs" => "fake, ppc,  !  foo" }
        Yast::StorageClass::Subvol.create_from_xml( xml )
      end

      it "has the correct path" do
        expect(subject.path).to be == "var/fake"
      end

      it "is NoCOW" do
        expect(subject.no_cow?).to be true
      end

      it "is tolerant against whitespace in the archs list" do
        expect(subject.archs).to be == ["fake", "ppc", "!foo"]
      end

      it "matches arch 'fake'" do
        expect(subject.matches_arch?("fake")).to be true
      end

      it "matches arch 'ppc'" do
        expect(subject.matches_arch?("ppc")).to be true
      end

      it "does not match arch 'foo'" do
        expect(subject.matches_arch?("foo")).to be false
      end

      it "does not match arch 'bar'" do
        expect(subject.matches_arch?("bar")).to be false
      end

    end

    describe "Minimalistic subvol" do
      subject do
        xml = { "path" => "var/fake" }
        Yast::StorageClass::Subvol.create_from_xml( xml )
      end

      it "has the correct path" do
        expect(subject.path).to be == "var/fake"
      end

      it "is COW" do
        expect(subject.cow?).to be true
      end

      it "is not arch-specific" do
        expect(subject.arch_specific?).to be false
      end

      it "matches arch 'fake'" do
        expect(subject.matches_arch?("fake")).to be true
      end
    end
  end
end
