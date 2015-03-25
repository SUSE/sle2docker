# -*- encoding: utf-8 -*-

require File.expand_path("../lib/sle2docker/version", __FILE__)

Gem::Specification.new do |s|
  s.name        = "sle2docker"
  s.version     = Sle2Docker::VERSION
  s.platform    = Gem::Platform::RUBY
  s.authors     = ['Flavio Castelli']
  s.email       = ['fcastelli@suse.com']
  s.homepage    = "https://github.com/SUSE/sle2docker"
  s.summary     = "Create SLE images for Docker"

  s.description = <<EOD
sle2docker is a convenience tool which creates SUSE Linux Enterprise images for Docker.

The tool relies on KIWI and Docker itself to build the images.

Packages can be fetched either from Novell Customer Center (NCC) or from a local Subscription Management Tool (SMT).

Using DVD sources is currently unsupported.
EOD
  s.licenses    = ['MIT']

  s.required_rubygems_version = ">= 1.3.6"
  s.rubyforge_project         = "sle2docker"

  s.add_runtime_dependency "thor"
  s.add_development_dependency "bundler"
  s.add_development_dependency "fakefs"
  s.add_development_dependency 'rake'
  s.add_development_dependency "yard"
  s.files        = `git ls-files`.split("\n")
  s.executables  = `git ls-files`.split("\n").map{|f| f =~ /^bin\/(.*)/ ? $1 : nil}.compact
  s.require_path = 'lib'
end
