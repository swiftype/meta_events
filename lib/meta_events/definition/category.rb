require "meta_events"
require "meta_events/definition/event"
require "active_support"
require "active_support/core_ext"

module MetaEvents
  module Definition
    # A Category is the middle level of hierarchy in the MetaEvents DSL. Child of a Version and parent of an Event, it
    # groups together a set of Events that logically belong together. Programmatically, it serves no purpose other than
    # to group together related events, so that the namespace of events doesn't get enormous.
    #
    class Category
      class << self
        # Normalizes the name of a category, so that we don't run into crazy Symbol-vs.-String bugs.
        def normalize_name(name)
          raise ArgumentError, "Must supply a name for a category, not: #{name.inspect}" if name.blank?
          name.to_s.strip.downcase.to_sym
        end
      end

      attr_reader :version, :name

      # Creates a new instance. +version+ must be the ::MetaEvents::Definition::Version to which this Category should belong;
      # +name+ is the name of the category. +options+ can contain:
      #
      # [:retired_at] If passed, this must be a String that can be parsed by Time.parse; it indicates the time at which
      #               this category was retired, meaning that it no longer can be used to fire events. (The code does
      #               not actually care about the value of this Time; that's used only for record-keeping purposes --
      #               rather, it's used simply as a flag indicating that the category has been retired, and events in
      #               it should no longer be allowed to be fired.)
      #
      # The block passed to this constructor is evaluated in the context of this object; this is how we build our
      # DSL.
      def initialize(version, name, options = { }, &block)
        raise ArgumentError, "You must pass a Version, not: #{version.inspect}" unless version.kind_of?(::MetaEvents::Definition::Version)

        @version = version
        @name = self.class.normalize_name(name)
        @events = { }

        options.assert_valid_keys(:retired_at)

        @retired_at = Time.parse(options[:retired_at]) if options[:retired_at]

        instance_eval(&block) if block
      end

      # Declares a new event. +name+ is the name of the event; all additional arguments are passed to the constructor
      # of ::MetaEvents::Definition::Event. It is an error to try to define two events with the same name.
      def event(name, *args, &block)
        event = ::MetaEvents::Definition::Event.new(self, name, *args, &block)
        raise ArgumentError, "Category #{self.name.inspect} already has an event named #{event.name.inspect}" if @events[event.name]
        @events[event.name] = event
      end

      # Returns the full prefix that events of this Category should use.
      def prefix
        "#{version.prefix}#{name}_"
      end

      # Retrieves an event with the given name; raises +ArgumentError+ if there is no such event.
      def event_named(name)
        name = ::MetaEvents::Definition::Event.normalize_name(name)
        @events[name] || raise(ArgumentError, "#{self} has no event named #{name.inspect}; it has: #{@events.keys.sort_by(&:to_s).inspect}")
      end

      # Returns the effective time at which this category was retired, or +nil+ if it is not retired. This is the
      # earliest of the time at which this category was retired and the time at which the version was retired.
      def retired_at
        [ @retired_at, version.retired_at ].compact.min
      end

      # Override #to_s, for a cleaner view.
      def to_s
        "<Category #{name.inspect} of #{version}>"
      end
    end
  end
end
