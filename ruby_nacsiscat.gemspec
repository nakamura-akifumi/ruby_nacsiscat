# -*- encoding: utf-8 -*-
require File.expand_path('../lib/ruby_nacsiscat/version', __FILE__)

Gem::Specification.new do |gem|
  gem.authors       = ["AKifumi NAKAMURA"]
  gem.email         = ["nakamura@opentech.co.jp"]
  gem.description   = %q{NACSIS CAT Connector for Ruby}
  gem.summary       = %q{NACSIS CAT Connector}
  gem.homepage      = ""

  gem.files         = `git ls-files`.split($\)
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.name          = "ruby_nacsiscat"
  gem.require_paths = ["lib"]
  gem.version       = RubyNacsiscat::VERSION

  gem.add_development_dependency "rspec"
end
