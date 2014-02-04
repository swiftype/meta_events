# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'meta_events/version'

Gem::Specification.new do |spec|
  spec.name          = "meta_events"
  spec.version       = MetaEvents::VERSION
  spec.authors       = ["Andrew Geweke"]
  spec.email         = ["ageweke@swiftype.com"]
  spec.summary       = %q{Structured, documented, powerful event emitting library for Mixpanel and other such systems.}
  spec.homepage      = ""
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0")
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  if RUBY_VERSION =~ /^1\.8\./
    spec.add_dependency "activesupport", ">= 3.0", "< 4.0"
  else
    spec.add_dependency "activesupport", ">= 3.0", "<= 4.99.99"
  end

  spec.add_development_dependency "bundler", "~> 1.5"
  spec.add_development_dependency "rake"
  spec.add_development_dependency "rspec", "~> 2.14"
end
