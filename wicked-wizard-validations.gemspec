# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'wicked/wizard/validations/version'

Gem::Specification.new do |spec|
  spec.name          = "wicked-wizard-validations"
  spec.version       = Wicked::Wizard::Validations::VERSION
  spec.authors       = ["Ed Jones"]
  spec.email         = ["ed@errorstudio.co.uk"]
  spec.summary       = %q{A validation mixin for Wicked.}
  spec.description   = %q{This gem allows you to conditionally validate your models, based on where in a multi-step process the user is.}
  spec.homepage      = "https://github.com/errorstudio/wicked-wizard-validations"
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0")
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.6"
  spec.add_development_dependency "rake"

  spec.add_dependency 'wicked', '~> 1.0'
end
