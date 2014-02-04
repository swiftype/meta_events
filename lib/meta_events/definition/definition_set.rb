require "meta_events"
require "meta_events/definition/version"

module MetaEvents
  module Definition
    # A DefinitionSet is the root of the MetaEvents DSL. Generally speaking, any application will have exactly one
    # DefinitionSet, which contains the definition of every event it currently or has ever fired.
    #
    # The only reason a DefinitionSet is not a singleton object (or just class methods) is that it is extremely
    # useful for testing to be able to use a separate DefinitionSet.
    #
    # A single DefinitionSet has a +global_events_prefix+, which is prepended to every event fired. This can be used
    # to easily distinguish events that come through this system from events before it was introduced, or versus events
    # fired by some other system entirely.
    class DefinitionSet
      class BaseError < StandardError; end
      class RetiredEventError < BaseError; end

      class << self
        # Creates an MetaEvents::Definition::DefinitionSet. +source+ can be one of:
        #
        # * An MetaEvents::Definition::DefinitionSet; we simply return it. This can seem a little redundant (and it is), but
        #   it helps us write much cleaner code in other classes (like MetaEvents::Tracker).
        # * An IO (or StringIO, which doesn't actually inherit from IO but effectively is one); or
        # * A path to a File.
        #
        # In both of the last two cases, we interpret the contents of the file as Ruby code in the context of the new
        # DefinitionSet -- in other words, it should look something like:
        #
        #     global_events_prefix :mp
        #
        #     version 1, '2014-01-01' do
        #       category :foo do
        #         event :bar, '2014-01-16', 'this is great'
        #       end
        #     end
        def from(source)
          source = new(:definition_text => source) unless source.kind_of?(self)
          source
        end
      end

      # Creates a new instance. +global_events_prefix+ must be a String or Symbol; it will be prepended to the name
      # of every event fired. You can pass the empty string if you want.
      #
      # The block passed to this constructor is evaluated in the context of this object; this is how we build our
      # DSL.
      def initialize(options = { }, &block)
        @global_events_prefix = nil
        @versions = { }

        options.assert_valid_keys(:global_events_prefix, :definition_text)

        global_events_prefix options[:global_events_prefix] if options[:global_events_prefix]

        @source_description = "passed-in data/block"

        if (source = options[:definition_text])
          if source.kind_of?(String)
            File.open(File.expand_path(source)) { |f| read_from(f) }
          else
            read_from(source)
          end
        end

        instance_eval(&block) if block

        if global_events_prefix.blank?
          raise ArgumentError, "When reading events from #{@source_description}: you must declare a global_events_prefix, or else pass one to the constructor"
        end
      end

      # Sets the +global_events_prefix+ -- the string that will be prepended (with the version) to every single
      # event fired through this DefinitionSet.
      def global_events_prefix(prefix = nil)
        if prefix
          @global_events_prefix = prefix.to_s
        else
          @global_events_prefix
        end
      end

      # Declares a new version. The +number+ is required and must be unique. For +introduced+ and +options+, see the
      # constructor of ::MetaEvents::Definition::Version.
      #
      # The block passed is evaluated in the context of the new Version; this is how we build our DSL.
      def version(number, introduced, options = { }, &block)
        version = ::MetaEvents::Definition::Version.new(self, number, introduced, options, &block)
        raise "There is already a version #{version.number.inspect}" if @versions[version.number]
        @versions[version.number] = version
      end

      # Returns the Version object for the given number, or raises an exception if there is none.
      def fetch_version(number)
        @versions[number] || raise(ArgumentError, "No such version #{number.inspect}; I have: #{@versions.keys.sort_by(&:to_s).inspect}")
      end

      # Fetches an ::MetaEvents::Definition::Event object directly, by version number, category, and event.
      def fetch_event(version_num, category_name, event_name)
        fetch_version(version_num).fetch_event(category_name, event_name)
      end

      private
      def read_from(source)
        # StringIO is, really annoyingly, *not* an actual subclass of IO.
        raise ArgumentError, "Invalid source: #{source.inspect}" unless source.kind_of?(IO) || source.kind_of?(StringIO)
        args = [ source.read ]

        if source.respond_to?(:path) && source.respond_to?(:lineno) && source.path && source.lineno
          args += [ source.path, source.lineno ]
          @source_description = "#{source.path}:#{source.lineno}"
        end

        begin
          instance_eval(*args)
        rescue Exception => e
          raise "When reading event definitions from #{@source_description}, we got an exception: (#{e.class.name}) #{e.message}\n    #{e.backtrace.join("\n    ")}"
        end
      end
    end
  end
end
