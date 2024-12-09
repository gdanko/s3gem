# coding: utf-8
lib = File.expand_path("../lib", __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "s3gem/version"

Gem::Specification.new do |spec|
  spec.name          = "s3gem"
  spec.version       = S3Gem::VERSION
  spec.authors       = ["Gary Danko"]
  spec.email         = ["gdanko@protonmail.com"]
  spec.summary       = "Utility for maintaining an s3-based gem repository"
  spec.description   = "Utility for maintaining an s3-based gem repository"
  spec.homepage      = "https://github.com/gdanko/s3gem"
  spec.license       = "GPL-2.0"

  spec.files = [
    "lib/s3gem/cli.rb",
    "lib/s3gem/config.rb",
    "lib/s3gem/createrepo.rb",
    "lib/s3gem/exception.rb",
    "lib/s3gem/repo.rb",
    "lib/s3gem/utils.rb",
    "lib/s3gem.rb",
    "bin/s3gem",
  ]

  spec.executables   = ["s3gem"]
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.required_ruby_version = ">= 2.2.3"

  spec.add_development_dependency "bundler", "~> 1.15"
  spec.add_development_dependency "rake", "~> 10.0"

  #spec.add_runtime_dependency "aws-sdk-s3", "~> 1.12", ">=1.12.0"
  spec.add_runtime_dependency "aws-sdk-s3"
  spec.add_runtime_dependency "s3sync", "~> 0.2", ">= 0.2.4"
  spec.add_runtime_dependency "thor", "~> 1.2.0", ">= 1.2.1"
end
