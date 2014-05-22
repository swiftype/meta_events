require "meta_events"

# An ::MetaEvents::Definition::Event is the lowest level of the MetaEvents DSL. It belongs to a Category (which, in turn,
# belongs to a Version), and should represent a single, consistent "thing that happened" that you want to track.
# The name of an Event must be unique within its Category and Version.
#
# The definition of "single, consistent" depends very much on your context and the scope of what you're tracking,
# and will require significant judgement calls. For example, if your event is +:signup+ (in category +:user+), and
# you change from a lengthy, complex, demanding signup process to Facebook signup -- with an optional form of all the
# lengthy information later -- is that the same event? It depends greatly on how you think of it; you could keep it
# the same event, or introduce a new +:simple_signup+ event -- it depends on how you want to track it.
module MetaEvents
  module Definition
    class Event
      attr_reader :category, :name

      class << self
        # Normalizes the name of an Event, so that we don't run into crazy Symbol-vs.-String bugs.
        def normalize_name(name)
          raise ArgumentError, "Must supply a name for an event, not: #{name.inspect}" if name.blank?
          name.to_s.strip.downcase.to_sym
        end
      end

      # Creates a new instance. +category+ must be the ::MetaEvents::Definition::Category that this event is part of; +name+
      # must be the name of the event.
      #
      # In order to create a new instance, you must also supply a description for the instance and indicate when it was
      # introduced; this is part of the required record-keeping that makes the MetaEvents DSL useful. You can do this in one
      # of several ways (expressed as it would look in the DSL):
      #
      #    category :user do
      #      event :signup, "2014-01-01", "a new user we've never heard of before signs up"
      #    end
      #
      # or:
      #
      #    category :user do
      #      event :signup, :introduced => "2014-01-01", :desc => "a new user we've never heard of before signs up"
      #    end
      #
      # or:
      #
      #    category :user do
      #      event :signup do
      #        introduced "2014-01-01"
      #        desc "a new user we've never heard of before signs up"
      #      end
      #    end
      #
      # You can also combine these in any way you want; what's important is just that they get set, or else you'll get an
      # exception at definition time.
      def initialize(category, name, *args, &block)
        raise ArgumentError, "Must supply a Category, not #{category.inspect}" unless category.kind_of?(::MetaEvents::Definition::Category)

        @category = category
        @name = self.class.normalize_name(name)
        @notes = [ ]

        apply_options!(args.extract_options!)
        args = apply_args!(args)

        raise ArgumentError, "Too many arguments: don't know what to do with #{args.inspect}" if args.present?

        instance_eval(&block) if block

        ensure_complete!
      end

      # Given a set of properties, validates this event -- that is, either returns without doing anything if everything is
      # OK, or raises an exception if the event should not be allowed to be fired. Currently, all we do is fail if the
      # event has been retired (directly, or via its Category or Version); however, this could easily be extended to
      # provide for required properties, property validation, or anything else.
      def validate!(properties)
        if retired_at
          raise ::MetaEvents::Definition::DefinitionSet::RetiredEventError, "Event #{full_name} was retired at #{retired_at.inspect} (or its category or version was); you can't use it any longer."
        end
      end

      # Returns, or sets, the description for an event.
      def desc(text = nil)
        @description = text if text
        @description
      end

      # Returns, or sets, the introduced-at time for an event.
      def introduced(time = nil)
        @introduced = Time.parse(time) if time
        @introduced
      end

      # Returns, or sets, an external_name to use for an event.
      def external_name(name = nil)
        @external_name = name if name
        @external_name
      end

      # Returns the name of the category for an event.
      def category_name
        category.name
      end

      # Returns the canonical full name of an event, including all prefixes.
      def full_name
        "#{category.prefix}#{name}"
      end

      # Returns the time at which this event has been retired, if any -- this is the earliest time from its category
      # (which, in turn, is the earliest of the category and the version), and this event. If an event has been retired,
      # then #validate! will fail.
      def retired_at(value = nil)
        @retired_at = Time.parse(value) if value
        [ @retired_at, category.retired_at ].compact.min
      end

      # Adds a note to this event. Notes are simply metadata right now -- useful for indicating what the history of an
      # event is, significant changes in its meaning, and so on.
      def note(when_left, who, text)
        raise ArgumentError, "You must specify when this note was left" if when_left.blank?
        when_left = Time.parse(when_left)
        raise ArgumentError, "You must specify who left this note" if who.blank?
        raise ArgumentError, "You must specify an actual note" if text.blank?

        @notes << { :when_left => when_left, :who => who, :text => text }
      end

      # Returns all notes associated with this event, as an array of Hashes.
      def notes
        @notes
      end

      # Override for clearer data.
      def to_s
        "<Event #{name.inspect} of #{category}>"
      end

      private
      # Called at the very end of the constructor, to ensure that you have declared all required properties for this
      # event.
      def ensure_complete!
        raise ArgumentError, "You must specify a description for event #{full_name}, either as an argument, in the options, or using 'desc'" if @description.blank?
        raise ArgumentError, "You must record when you introduced event #{full_name}, either as an argument, in the options, or using 'introduced'" if (! @introduced)
      end

      # Called with the set of options (which can be empty) supplied in the constructor; responsible for applying those
      # to the object properly.
      def apply_options!(options)
        options.assert_valid_keys(:introduced, :desc, :description, :retired_at, :external_name)

        introduced options[:introduced] if options[:introduced]
        desc options[:desc] if options[:desc]
        desc options[:description] if options[:description]
        external_name options[:external_name] if options[:external_name]

        @retired_at = Time.parse(options[:retired_at]) if options[:retired_at]
      end

      # Called with the arguments (past the category and event name) supplied to the constructor; responsible for
      # applying those to the object properly.
      def apply_args!(args)
        intro = args.shift
        d = args.shift
        introduced intro if intro
        desc d if d
        args
      end
    end
  end
end
