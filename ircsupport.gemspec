# coding: utf-8
$:.push File.expand_path("../lib", __FILE__)
require 'ircsupport/version'

Gem::Specification.new do |gem|
  gem.name        = "ircsupport"
  gem.version     = IRCSupport::VERSION
  gem.authors     = ["Hinrik Örn Sigurðsson"]
  gem.email       = ["hinrik.sig@gmail.com"]
  gem.homepage    = "https://github.com/hinrik/ircsupport"
  gem.summary     = "An IRC protocol library"
  gem.description = "IRCSupport provides tools for dealing with the IRC protocol."
  gem.licenses    = ['MIT']

  gem.files         = `git ls-files`.split("\n")
  gem.test_files    = `git ls-files -- test/*`.split("\n")
  gem.require_path  = "lib"
  gem.has_rdoc      = "yard"
  gem.required_ruby_version = '>= 1.9.1'

  gem.add_development_dependency "rake"
  gem.add_development_dependency "simplecov"
  gem.add_development_dependency "yard", ">= 0.7.5"
  gem.add_development_dependency "redcarpet"
  gem.add_development_dependency "minitest", ">= 2.11.4"
  gem.add_development_dependency "turn"
end
