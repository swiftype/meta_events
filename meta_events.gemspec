# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'meta_events/version'

Gem::Specification.new do |spec|
  spec.name          = "meta_events"
  spec.version       = MetaEvents::VERSION
  spec.authors       = ["Andrew Geweke", "Caleb Buxton"]
  spec.email         = ["ageweke@swiftype.com", "caleb+meta_events@kinside.com"]
  spec.summary       = %q{Structured, documented, powerful event emitting library for Mixpanel and other such systems.}
  spec.homepage      = "https://www.github.com/trykinside/meta_events"
  spec.license       = "MIT"

  if spec.respond_to?(:metadata)
    spec.metadata["allowed_push_host"] = "https://rubygems.pkg.github.com/trykinside"
  end

  spec.files         = `git ls-files -z`.split("\x0")
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_dependency "json"
  spec.add_dependency "activesupport", ">= 3.0"

  spec.add_development_dependency "bundler", "~> 1.5"
  spec.add_development_dependency "rake", "< 11"
  spec.add_development_dependency "rspec", "~> 2"
  spec.add_development_dependency "pry", "~> 0.12"
end
