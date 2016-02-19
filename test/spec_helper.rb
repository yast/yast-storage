# Copyright (c) 2014 SUSE LLC.
#  All Rights Reserved.

#  This program is free software; you can redistribute it and/or
#  modify it under the terms of version 2 or 3 of the GNU General
#  Public License as published by the Free Software Foundation.

#  This program is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.   See the
#  GNU General Public License for more details.

#  You should have received a copy of the GNU General Public License
#  along with this program; if not, contact SUSE LLC.

#  To contact Novell about this file by physical or electronic mail,
#  you may find current contact information at www.suse.com

# Set the paths
SRC_PATH = File.expand_path("../../src", __FILE__)
DATA_PATH = File.join(File.expand_path(File.dirname(__FILE__)), "data")
FIXTURES_PATH = File.expand_path('../fixtures', __FILE__)
ENV["Y2DIR"] = SRC_PATH

require "yast"
require "yast/rspec"
require "yaml"

if ENV["COVERAGE"]
  require "simplecov"
  SimpleCov.start

  # for coverage we need to load all ruby files
  Dir["#{SRC_PATH}/lib/**/*.rb"].each { |f| require_relative f }

  # use coveralls for on-line code coverage reporting at Travis CI
  if ENV["TRAVIS"]
    require "coveralls"
    SimpleCov.formatter = SimpleCov::Formatter::MultiFormatter[
      SimpleCov::Formatter::HTMLFormatter,
      Coveralls::SimpleCov::Formatter
    ]
  end
end

# Helper method to load partitioning maps
#
# Partitioning maps are stored in /test/fixtures as ycp files.
#
# @param [String] name Map name (without .ycp extension)
# @return Hash    Hash representing information contained in the map
def build_map(name)
  path = File.join(FIXTURES_PATH, "#{name}.yml")
  content = YAML.load_file(path)
  raise "Fixtures #{name} not found (file #{path}) does not exist)" if content.nil?
  content
end
