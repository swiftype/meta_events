require 'json'

module MetaEvents
  # This module gets included as a Rails helper module, if Rails is available. It defines methods that are usable
  # by views to do tracking from the front-end -- both auto-tracking and frontend events.
  module Helpers
    class << self
      # Defines (or returns) the prefix we use for our class and data attributes; this just needs to be unique enough
      # that we are highly unlikely to collide with any other attributes.
      def meta_events_javascript_tracking_prefix(prefix = nil)
        if prefix == nil
          @_meta_events_javascript_tracking_prefix
        else
          if (prefix.kind_of?(String) || prefix.kind_of?(Symbol)) && prefix.to_s.strip.length > 0
            @_meta_events_javascript_tracking_prefix = prefix.to_s.strip
            @_meta_events_javascript_tracking_prefix = $1 if @_meta_events_javascript_tracking_prefix =~ /^([^_]+)_+$/i
          else
            raise ArgumentError, "Must supply a String or Symbol, not: #{prefix.inspect}"
          end
        end
      end
    end

    # The default prefix we use.
    meta_events_javascript_tracking_prefix "mejtp"

    # PRIVATE (though there's no point to declaring something private in a helper; everything's being called from the
    # same object anyway). Simply prepends our prefix, plus an underscore, to whatever's passed in.
    def meta_events_prefix_attribute(name)
      "#{MetaEvents::Helpers.meta_events_javascript_tracking_prefix}_#{name}"
    end

    # Given a Hash of attributes for an element -- and, optionally, a MetaEvents::Tracker instance to use; we default
    # to using the one exposed by the +meta_events_tracker+ method -- extracts a +:meta_event+ property, if present,
    # and turns it into exactly the attributes that +meta_events.js.erb+ can use to detect that this is an element
    # we want to track (and thus correctly return it from its +forAllTrackableElements+ method). If no +:meta_event+
    # key is present on the incoming set of attributes, simply returns exactly its input.
    #
    # The +:meta_event+ property must be a Hash, containing:
    #
    # [:category] The name of the category of the event;
    # [:event] The name of the event within the category;
    # [:properties] Any additional properties to fire with the event; this is optional.
    def meta_events_tracking_attributes_for(input_attributes, event_tracker = meta_events_tracker)
      # See if we've even got an event...
      return input_attributes unless input_attributes && (input_attributes[:meta_event] || input_attributes['meta_event'])

      # If so, let's start populating our set of output attributes.
      # #with_indifferent_access dups the Hash even if it already has indifferent access, which is important here
      output_attributes = input_attributes.with_indifferent_access
      event_data = output_attributes.delete(:meta_event)

      # A little error-checking...
      unless event_data.kind_of?(Hash)
        raise ArgumentError, ":meta_event must be a Hash, not: #{event_data.inspect}"
      end

      event_data.assert_valid_keys(%w{category event properties})

      # Grab our event data...
      category = event_data[:category]
      event = event_data[:event]
      properties = event_data[:properties] || { }

      unless category && event
        raise ArgumentError, "You must supply :category and :event in your :meta_event attributes, not: #{event_data.inspect}"
      end

      # Ask the Tracker to compute the set of properties we should be firing with this event...
      props_data = event_tracker.effective_properties(category, event, properties)

      # Add our class to the +:class+ attribute -- Rails supports declaring +:class+ as an Array, and so we'll use
      # that here. It works fine even if +:class+ is a string of space-separated class names.
      classes = Array(output_attributes.delete(:class) || [ ])
      classes << meta_events_prefix_attribute("trk")
      output_attributes[:class] = classes

      # Set the data attributes we'll be looking for...
      output_attributes["data-#{meta_events_prefix_attribute('evt')}"] = props_data[:external_name]
      output_attributes["data-#{meta_events_prefix_attribute('prp')}"] = props_data[:properties].to_json

      # And we're done!
      output_attributes
    end

    # This works exactly like Rails' built-in +link_to+ method, except that it takes a +:meta_event+ property in
    # +html_options+ and turns the link into a tracked link, using #meta_events_tracking_attributes_for, above.
    #
    # The +:meta_event+ property is actually required; this is because, presumably, you're calling this method exactly
    # because you want to track something, and if you didn't pass +:meta_event+, you probably misspelled or forgot
    # about it.
    #
    # Obviously, feel free to create a shorter alias for this method in your application; we give it a long, unique
    # name here so that we don't accidentally collide with another helper method in your project.
    def meta_events_tracked_link_to(name = nil, options = nil, html_options = nil, &block)
      html_options, options, name = options, name, nil if block_given?

      unless html_options && html_options[:meta_event]
        raise ArgumentError, "You asked for a tracked link, but you didn't provide a :meta_event: #{html_options.inspect}"
      end

      if block_given?
        link_to(options, meta_events_tracking_attributes_for(html_options, meta_events_tracker), &block)
      else
        link_to(name, options, meta_events_tracking_attributes_for(html_options, meta_events_tracker))
      end
    end


    # Returns a JavaScript string that, when placed on a page into which +meta_events.js.erb+ has been included, sets
    # up all defined front-end events so that they can be fired by that JavaScript.
    def meta_events_frontend_events_javascript
      out = ""
      (meta_events_defined_frontend_events || { }).each do |name, properties|
        out << "MetaEvents.registerFrontendEvent(#{name.to_json}, #{properties.to_json});\n"
      end
      out.html_safe
    end
  end
end
