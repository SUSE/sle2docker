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
  s.description = "Quickly create SLE images for Docker using kiwi."

  s.required_rubygems_version = ">= 1.3.6"
  s.rubyforge_project         = "sle2docker"

  s.add_development_dependency "bundler"
  s.add_development_dependency "yard"
  s.files        = `git ls-files`.split("\n")
  s.executables  = `git ls-files`.split("\n").map{|f| f =~ /^bin\/(.*)/ ? $1 : nil}.compact
  s.require_path = 'lib'
end
