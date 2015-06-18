# encoding: utf-8

# Copyright (c) [2015] SUSE LLC
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
# with this program; if not, contact SUSE LLC.
#
# To contact SUSE LLC about this file by physical or electronic mail, you may
# find current contact information at www.suse.com.


module Yast
  module StorageHelpers
    module TargetMapFormatter

      INDENT_WIDTH  = 4
      INDENT_PREFIX = ""

      # Format a storage target map for readable output e.g. in the log.
      #
      # @param  [Hash]   target_map       the storage target map to format
      # @return [String] formatted output as multi-line string
      #
      def format_target_map( target_map )
        format_any( target_map, 0 )
      end


      def format_any( obj, indent_level )
        result = "";

        if ( obj == nil )
          return "<nil>"
        elsif ( obj.is_a? Hash )
          result = format_hash( obj, indent_level )
        elsif ( obj.is_a? Array )
          result = format_array( obj, indent_level )
        else
          result = format_simple( obj, indent_level )
        end

        result
      end


      def format_array( array, indent_level )
        lines = []

        array.each do |item|
          line = format_any( item, indent_level + 1 )
          lines.push( line ) unless line.empty?
        end

        line_prefix = indentation( indent_level )
        if ( lines.empty? )
          line_prefix + "[]"
        else
          line_prefix + "[\n" + lines.join( ",\n" ) + "\n" + line_prefix + "]"
        end
      end


      def format_hash( hash, indent_level )
        if ( is_simple_hash( hash ) )
          return format_simple_hash( hash, indent_level )
        end

        lines = []
        content_prefix = indentation( indent_level + 1 )

        hash.each do |key, value|
          line = content_prefix + "\"#{key}\" =>";

          if ( value.is_a?( Hash ) )
            if ( is_simple_hash( value ) )
              line += " " + format_simple_hash( value, 0 )
            else
              line += "\n" + format_hash( value, indent_level + 1 )
            end
          elsif ( value.is_a?( Array ) )
            line += "\n" + format_array( value, indent_level + 1 )
          else
            line += " \"#{value}\""
          end

          lines.push( line )
        end

        line_prefix = indentation( indent_level )
        if ( lines.empty? )
          line_prefix + "{}"
        else
          line_prefix + "{\n" + lines.join( ",\n" ) + "\n" + line_prefix + "}"
        end
      end


      def format_simple_hash( hash, indent_level )
        lines = []

        hash.each do |key, value|
          line = "\"#{key}\" => \"#{value}\""
          lines.push( line )
        end

        line_prefix = indentation( indent_level )
        if ( lines.empty? )
          line_prefix + "{}"
        else
          line_prefix + "{ " + lines.join( ", " ) + " }"
        end
      end


      def is_simple_hash( hash )
        if hash.size > 3
          return false
        end

        hash.each_value { |val| return false if val.is_a?( Hash ) || val.is_a?( Array ) }
        true
      end


      def format_simple( anything, indent_level )
        indentation( indent_level ) + "\"#{anything}\""
      end

      def indentation( indent_level )
        INDENT_PREFIX + " " * INDENT_WIDTH * indent_level
      end

    end
  end
end
