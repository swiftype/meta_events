module MetaEvents
  module Helpers
    class << self
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

    meta_events_javascript_tracking_prefix "mejtp"

    def meta_events_prefix_attribute(name)
      "#{MetaEvents::Helpers.meta_events_javascript_tracking_prefix}_#{name}"
    end

    def meta_events_tracking_attributes_for(input_attributes, event_tracker)
      return input_attributes unless input_attributes && input_attributes[:meta_event]

      output_attributes = input_attributes.dup
      event_data = output_attributes.delete(:meta_event)

      unless event_data.kind_of?(Hash)
        raise ArgumentError, ":meta_event must be a Hash, not: #{event_data.inspect}"
      end

      event_data.assert_valid_keys(:category, :event, :properties)

      category = event_data[:category]
      event = event_data[:event]
      properties = event_data[:properties] || { }

      unless category && event
        raise ArgumentError, "You must supply :category and :event in your :meta_event attributes, not: #{event_data.inspect}"
      end

      props_data = event_tracker.effective_properties(category, event, properties)

      classes = Array(output_attributes.delete(:class) || [ ])
      classes << meta_events_prefix_attribute("trk")
      output_attributes[:class] = classes

      data = (output_attributes[:data] ||= { })
      data[meta_events_prefix_attribute("evt")] = props_data[:event_name]
      data[meta_events_prefix_attribute("prp")] = props_data[:properties].to_json

      output_attributes
    end

    def meta_events_tracked_link_to(name = nil, options = nil, html_options = nil, &block)
      unless html_options && html_options[:meta_event]
        raise ArgumentError, "You asked for a tracked link, but you didn't provide a :meta_event: #{html_options.inspect}"
      end

      link_to(name, options, meta_events_tracking_attributes_for(html_options, meta_events_tracker), &block)
    end


    def meta_events_frontend_events_javascript
      out = ""
      (@_meta_events_registered_clientside_events || { }).each do |name, properties|
        out << "MetaEvents.registerFrontendEvent(#{name.to_json}, #{properties.to_json});\n"
      end
      out.html_safe
    end
  end
end
