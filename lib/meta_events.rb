require "meta_events/version"
require "meta_events/definition/definition_set"
require "meta_events/tracker"
require "meta_events/test_receiver"

gem 'rails' rescue nil
require 'rails' rescue nil

if defined?(::Rails)
  require "meta_events/railtie"
end

module MetaEvents
  # Your code goes here...
end
