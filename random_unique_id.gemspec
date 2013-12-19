# encoding: UTF-8
# Copyright © 2013, Watu

lib = File.expand_path("../lib", __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "random_unique_id/version"

Gem::Specification.new do |spec|
  spec.name          = "random_unique_id"
  spec.version       = RandomUniqueId::VERSION
  spec.authors       = ["J. Pablo Fernández"]
  spec.email         = ["pupeno@watuapp.com"]
  spec.description   = %q{Generate random but unique ids for your active record records.}
  spec.summary       = %q{Generate random but unique ids for your active record records.}
  spec.homepage      = "https://github.com/watu/random_unique_id"
  spec.license       = "MIT"

  spec.files         = `git ls-files`.split($/)
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.3"
  spec.add_development_dependency "minitest", "~> 2.5.1"
  spec.add_development_dependency "minitest-reporters"
  spec.add_development_dependency "mocha"
  spec.add_development_dependency "rake"
  spec.add_development_dependency "simplecov"
  spec.add_development_dependency "shoulda"
  spec.add_development_dependency "sqlite3"

  spec.add_dependency "activesupport", "~> 3.2.0"
  spec.add_dependency "activerecord", "~> 3.2.0"
end
