# encoding: UTF-8
# Copyright © 2013, 2014, Watu

require "rubygems"

# Test coverage
require "simplecov"
require "coveralls"
SimpleCov.start do
  add_filter "/test/"
end
Coveralls.wear! # Comment out this line to have the local coverage generated.

require "minitest/autorun"
require "minitest/reporters"
MiniTest::Reporters.use!

# This class is here only to trick shoulda into attaching itself to MiniTest due to: https://github.com/thoughtbot/shoulda-context/issues/38
module ActiveSupport
  class TestCase < MiniTest::Unit::TestCase
  end
end
require "shoulda"
require "shoulda-context"
require "shoulda-matchers"

require "mocha/setup"

# Database setup
require "active_record"
require "logger"
ActiveRecord::Base.logger = Logger.new(STDERR)
ActiveRecord::Base.logger.level = Logger::WARN
ActiveRecord::Base.configurations = {"sqlite3" => {adapter: "sqlite3", database: ":memory:"}}
ActiveRecord::Base.establish_connection(:sqlite3)

# Make the code to be tested easy to load.
$LOAD_PATH.unshift(File.dirname(__FILE__))
$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), "..", "lib"))
