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
      output_attributes = input_attributes.dup

      category = output_attributes.delete(:event_category)
      name = output_attributes.delete(:event_name)
      properties = output_attributes.delete(:event_properties)

      return input_attributes unless category || name || properties

      unless category && name && properties
        raise ArgumentError, %{If you're adding event-tracking attributes to an element, you must either supply none of,
or all of, :event_category, :event_name, and :event_properties. (:event_properties can be an empty Hash
if you truly want to pass no additional properties; but you must supply it, so we know you didn't
just forget it.}
      end

      props_data = event_tracker.effective_properties(category, name, properties)

      classes = Array(output_attributes.delete(:class) || [ ])
      classes << meta_events_prefix_attribute("trk")
      output_attributes[:class] = classes

      data = (output_attributes[:data] ||= { })
      data[meta_events_prefix_attribute("evt")] = props_data[:event_name]
      data[meta_events_prefix_attribute("prp")] = props_data[:properties].to_json

      output_attributes
    end

    def meta_events_tracked_link_to(name = nil, options = nil, html_options = nil, &block)
      unless html_options && html_options[:event_category]
        raise ArgumentError, "You asked for a tracked link, but you didn't provide an :event_category: #{html_options.inspect}"
      end

      link_to(name, options, meta_events_tracking_attributes_for(html_options, meta_events_tracker), &block)
    end
  end
end
