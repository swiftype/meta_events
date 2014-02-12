require "meta_events/version"
require "meta_events/definition/definition_set"
require "meta_events/tracker"
require "meta_events/test_receiver"
require "meta_events/helpers"
require "meta_events/engine"
require "meta_events/controller_methods"

# See if we can load Rails -- but don't fail if we can't; we'll just use this to decide whether we should
# load the Railtie or not.
begin
  gem 'rails'
rescue Gem::LoadError => le
  # ok
end

begin
  require 'rails'
rescue LoadError => le
  # ok
end

if defined?(::Rails)
  require "meta_events/railtie"
end

module MetaEvents
  # Your code goes here...
end
