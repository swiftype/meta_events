require 'active_support'

module MetaEvents
  module ControllerMethods
    extend ActiveSupport::Concern

    def meta_events_define_frontend_event(category, event, properties = { }, options = { })
      options.assert_valid_keys(:name)

      name = options[:name] || "#{category}_#{event}"

      @_meta_events_registered_clientside_events ||= { }
      @_meta_events_registered_clientside_events[name] = meta_events_tracker.effective_properties(category, event, properties)
    end

    def meta_events_defined_frontend_events
      @_meta_events_registered_clientside_events || { }
    end

    included do
      helper_method :meta_events_define_frontend_event, :meta_events_defined_frontend_events
    end
  end
end
