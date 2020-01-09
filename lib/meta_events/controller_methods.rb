require 'active_support'

module MetaEvents
  # This module defines methods that we add to ActionController::Base if we're being used with Rails.
  module ControllerMethods
    # We use this for the #included block, below.
    extend ActiveSupport::Concern

    # Declares a new "frontend event". A frontend event is, at its core, a binding from a name to (an event name,
    # a set of properties to fire with that event); by default, the name used is just the event name, without its
    # normal prefix (_i.e._, +foo_bar+, not +ab1_foo_bar+).
    #
    # You declare the frontend event here, on the server side; the server renders into the page this very binding,
    # and the frontend JavaScript (+meta_events.js.erb+) can pick up that data and expose it by very easy-to-use
    # JavaScript functions.
    #
    # +category+ is the category for your event;
    def meta_events_define_frontend_event(category, event, properties = { }, options = { })
      options.assert_valid_keys(:name, :tracker)

      name = (options[:name] || "#{category}_#{event}").to_s
      tracker = options[:tracker] || meta_events_tracker

      @_meta_events_registered_clientside_events ||= { }
      @_meta_events_registered_clientside_events[name] = tracker.effective_properties(category, event, properties)
    end

    # Returns the set of defined frontend events.
    def meta_events_defined_frontend_events
      @_meta_events_registered_clientside_events || { }
    end

    def meta_events_tracker
      raise "You must implement the method #meta_events_tracker on your controllers for this method to work; it should return the MetaEvents::Tracker instance (ideally, cached, using just something like @tracker ||=) that you want to use."
    end

    # When we get included into a controller, declare these methods as helper methods, so they're available to views,
    # too.
    included do
      helper_method(:meta_events_define_frontend_event, :meta_events_defined_frontend_events, :meta_events_tracker) if respond_to?(:helper_method)
    end
  end
end
