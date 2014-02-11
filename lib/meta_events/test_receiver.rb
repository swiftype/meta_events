module MetaEvents
  # A MetaEvents::TestReceiver is a very simple object that conforms to the call signature required by the
  # MetaEvents::Tracker for event receivers. It writes each event as human-readable text to a +target+, which can be:
  #
  # * A block (or any object that responds to #call), which will be passed a String;
  # * A Logger (or any object that responds to #info), which will be passed a String;
  # * An IO (like +STDOUT+ or +STDERR+, or any object that responds to #puts), which will be passed a String.
  #
  # This object is useful for watching and debugging events in development environments.
  class TestReceiver
    def initialize(target = nil, &block)
      @target = target || block || ::Rails.logger
    end

    def track(distinct_id, event_name, properties)
      string = "Tracked event: user #{distinct_id.inspect}, #{event_name.inspect}"
      properties.keys.sort.each do |k|
        value = properties[k]
        unless value == nil
          string << "\n    %30s: %s" % [ k, properties[k] ]
        end
      end

      say(string)
    end

    def say(string)
      if @target.respond_to?(:call)
        @target.call "#{string}\n"
      elsif @target.respond_to?(:info)
        @target.info "#{string}"
      else
        @target.puts string
      end
    end
  end
end
