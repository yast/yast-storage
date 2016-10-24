# encoding: utf-8

# Copyright (c) [2012-2015] Novell, Inc.
#
# All Rights Reserved.
#
# This program is free software; you can redistribute it and/or modify it
# under the terms of version 2 of the GNU General Public License as published
# by the Free Software Foundation.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
# FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
# more details.
#
# You should have received a copy of the GNU General Public License along
# with this program; if not, contact Novell, Inc.
#
# To contact Novell about this file by physical or electronic mail, you may
# find current contact information at www.novell.com.

require "yast"
require "storage"
Yast.import "Arch"

module Yast
  class StorageClass < Module

    # Helper class to represent a subvolume as defined in control.xml
    #
    class Subvol
      include Yast::Logger

      attr_accessor :path, :copy_on_write, :archs

      def initialize(path, copy_on_write: true, archs: nil)
        @path = path
        @copy_on_write = copy_on_write
        @archs = archs
      end

      def to_s
        text = "Subvol #{@path}"
        text += " (NoCOW)" unless @copy_on_write
        text += archs.nil? ? " (archs: all)" : " (archs: #{@archs})"
      end

      def arch_specific?
        !archs.nil?
      end

      def cow?
        @copy_on_write
      end

      def no_cow?
        !@copy_on_write
      end

      # Check if this subvolume should be used for the current architecture.
      # A subvolume is used if its archs contain the current arch.
      # It is not used if its archs contain the current arch negated
      # (e.g. "!ppc").
      #
      # @return bool
      #
      def current_arch?
        matches_arch? { |arch| Arch.respond_to?(arch.to_sym) && Arch.send(arch.to_sym) }
      end

      # Check if this subvolume should be used for an architecture.
      #
      # If a block is given, the block is called as the matcher with the
      # architecture to be tested as its argument.
      #
      # If no block is given (and only then), the 'target_arch' parameter is
      # used to check against.
      #
      def matches_arch?(target_arch = nil, &block)
        return true unless arch_specific?
        use_subvol = false
        archs.each do |a|
          arch = a.dup
          negate = arch.start_with?("!")
          arch[0] = "" if negate # remove leading "!"
          if block_given?
            match = block.call(arch)
          else
            match = arch == target_arch
          end
          if match && negate
            log.info("Not using #{self} for explicitly excluded arch #{arch}")
            return false
          end
          use_subvol ||= match
        end
        log.info("Using arch specific #{self}: #{use_subvol}")
        use_subvol
      end

      def self.create_from_xml(xml)
        return nil unless xml.key?("path")
        path = xml["path"]
        cow = true
        if xml.key?("copy_on_write")
          cow = xml["copy_on_write"]
        end
        archs = nil
        if xml.key?("archs")
          archs = xml["archs"].gsub("\s+", "").split(",")
        end
        arch_text = archs.to_s || "all"
        log.info("Creating Subvol from XML for \"#{path}\" cow: #{cow} archs: #{arch_text}")
        subvol = Subvol.new(path, copy_on_write: cow, archs: archs)
        log.info("Creating #{subvol}")
        subvol
      end
    end
  end
end
