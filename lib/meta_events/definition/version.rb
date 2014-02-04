require "meta_events"
require "meta_events/definition/category"

module MetaEvents
  module Definition
    # A Version is the common top level of hierarchy in the MetaEvents DSL. A Version represents a version of your
    # application's _entire_ event hierarchy -- that is, you should create a new Version if (and only if) you decide
    # to rearrange major parts of, or all of, your event hierarchy. (This is something that, in my experience, happens
    # more often than you'd imagine. ;)
    #
    # A Version belongs to a DefinitionSet; it has a +number+, which is just an integer (that you'll probably be
    # happier with if you make sequential, but no such requirement is imposed), the date (and possibly time) that it
    # was introduced (for record-keeping purposes). Additionally, you can mark a version as _retired_, which means that
    # it is still accessible for record-keeping purposes but will not allow any of its events to actually be fired.
    class Version
      attr_reader :definition_set, :number, :introduced

      # Creates a new instance. +definition_set+ is the MetaEvents::Definition::DefinitionSet to which this Version belongs;
      # +number+ is an integer telling you, well, which version this is -- it must be unique within the DefinitionSet.
      # +introduced+ is a String that must be parseable using Time.parse; this should be the date (and time, if you
      # really want to be precise) that the Version was first used, for record-keeping purposes.
      #
      # Currently, +options+ can contain:
      #
      # [:retired_at] If present, must be a String representing a date and/or time (as parseable by Time.parse); its
      #               presence indicates that this version is _retired_, meaning that you will not be allowed to fire
      #               events from this version. (The date and time itself is present for record-keeping purposes.)
      #               Set this if (and only if) this version should no longer be in use, presumably because it has
      #               been superseded by another version.
      #
      # Note that neither the introduction time nor retired-at time are actually compared with +Time.now+ in any way;
      # the introduction time is not used in the event mechanism at all, and the +retired_at+ time is treated as a
      # simple boolean flag (if present, you can't fire events from this version).
      #
      # The block passed to this constructor is evaluated in the context of this object; this is how we build our
      # DSL.
      def initialize(definition_set, number, introduced, options = { }, &block)
        raise ArgumentError, "You must pass a DefinitionSet, not #{definition_set.inspect}" unless definition_set.kind_of?(::MetaEvents::Definition::DefinitionSet)
        raise ArgumentError, "You must pass a version, not #{number.inspect}" unless number.kind_of?(Integer)

        @definition_set = definition_set
        @number = number
        @introduced = Time.parse(introduced)
        @categories = { }

        options.assert_valid_keys(:retired_at)

        @retired_at = Time.parse(options[:retired_at]) if options[:retired_at]

        instance_eval(&block) if block
      end

      # Returns the prefix that all events in this version should have -- something like "st1", for example.
      def prefix
        "#{definition_set.global_events_prefix}#{number}_"
      end

      # Declares a category within this version; this is part of our DSL. See the constructor of
      # ::MetaEvents::Definition::Category for more information about the arguments.
      def category(name, options = { }, &block)
        category = ::MetaEvents::Definition::Category.new(self, name, options, &block)
        raise ArgumentError, "There is already a category named #{name.inspect}" if @categories[category.name]
        @categories[category.name] = category
      end

      # Returns the Category with the given name, or raises ArgumentError if there is no such category.
      def category_named(name)
        name = ::MetaEvents::Definition::Category.normalize_name(name)
        @categories[name] || raise(ArgumentError, "#{self} has no category #{name.inspect}; it has: #{@categories.keys.sort_by(&:to_s).inspect}")
      end

      # Returns the ::MetaEvents::Definition::Event object for the given category and event name, or raises
      # ArgumentError if no such category or event exists.
      def fetch_event(category_name, event_name)
        category_named(category_name).event_named(event_name)
      end

      # Returns the Time at which this version was retired, or +nil+ if it is still active.
      def retired_at
        @retired_at
      end

      # Override #to_s, for a cleaner view.
      def to_s
        "<Version #{number}>"
      end
    end
  end
end
