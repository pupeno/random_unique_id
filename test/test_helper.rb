# encoding: UTF-8
# Copyright © 2013, 2014, 2015, Carousel Apps

require "rubygems"

# Test coverage
require "simplecov"
require "coveralls"
SimpleCov.start do
  add_filter "/test/"
end
Coveralls.wear! # Comment out this line to have the local coverage generated.
require "codeclimate-test-reporter"
CodeClimate::TestReporter.start

require "minitest/autorun"
require "minitest/reporters"
MiniTest::Reporters.use!
require "active_support/test_case"
require "shoulda"
require "shoulda-context"
require "shoulda-matchers"
require "mocha/setup"

# Make the code to be tested easy to load.
$LOAD_PATH.unshift(File.dirname(__FILE__))
$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), "..", "lib"))

# Database setup
require "active_record"
require "logger"
ActiveRecord::Base.logger = Logger.new(STDERR)
ActiveRecord::Base.logger.level = Logger::WARN
ActiveRecord::Base.configurations = {"sqlite3" => {adapter: "sqlite3", database: ":memory:"}}
ActiveRecord::Base.establish_connection(:sqlite3)

# Shutup.
I18n.enforce_available_locales = false # TODO: remove this line when it's not needed anymore.

if ActiveSupport::TestCase.respond_to? :test_order=
  ActiveSupport::TestCase.test_order = :random
end
