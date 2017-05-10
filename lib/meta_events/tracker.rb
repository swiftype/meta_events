require "meta_events"
require "active_support"
require "ipaddr"

module MetaEvents
  # The MetaEvents::Tracker is the primary (and only) class you ordinarily use from the MetaEvents system. By itself,
  # it does not actually call any event-tracking services; it takes the events you give it, expands them into
  # fully-qualified event names, expands nested properties, validates it all against the DSL, and then calls through to
  # one or more event _receivers_, which are simply any object that responds to a very simple method signature.
  #
  # ## Instantiation and Lifecycle
  #
  # A MetaEvents::Tracker object is designed to be created once in each context where you're processing actions on
  # behalf of a particular user -- for example, once in the request cycle in a Rails application, most likely as part
  # of ApplicationController. This is because a Tracker accepts, in its constructor, a +distinct_id+, which is the
  # way you identify a particular user to your events system. It is possible to override this on an event-by-event
  # basis (by passing a +:distinct_id+ property explicitly to the event), but it is generally cleaner and easier to
  # simply instantiate the MetaEvents::Tracker object once for each processing cycle.
  #
  # Further, a Tracker accepts _implicit properties_ on creation; this is a set of zero or more properties that get
  # automatically added to every event processed by the tracker. Typically, these will be user-centric properties,
  # like the user's location, age, plan, or anything else. By using the support for #to_event_properties (below), the
  # canonical form of Tracker instantiation looks something like:
  #
  #     event_tracker = MetaEvents::Tracker.new(current_user.id, request.remote_ip,
  #                                             :implicit_properties => { :user => current_user })
  #
  # ...which will automatically add all properties exposed by User#to_event_properties on every single event fired by
  # that Tracker.
  #
  # See the discussion for #initialize, too -- there are certain things you want to do for logged-out users and at the
  # point when a user signs up.
  #
  # If you concurrently are firing events from multiple versions in the MetaEvents DSL, you'll need to use multiple
  # MetaEvents::Tracker instances -- any given Tracker only works with a single version at once. Since the point of DSL
  # versions is to support wholesale overhauls of your entire events system, this is probably fine; the set of
  # implicit properties you want to use will almost certainly have changed, too.
  #
  # Any way you choose to use an MetaEvents::Tracker is fine -- the overhead to creating one is pretty small.
  #
  # ## Event Receivers
  #
  # To make an MetaEvents::Tracker actually do something, it must have one or more _event receiver_s. An event receiver is
  # any object that responds to the following method:
  #
  #     track(distinct_id, event_name, event_properties)
  #
  # ...where +distinct_id+ is a String or Integer that uniquely identifies the user for which we're firing the event,
  # +event_name+ is a String which is the full name of the event (more on that below), and +event_properties+
  # is a map of String keys (the names of properties) to values that are numbers (any Numeric -- integer or
  # floating-point -- will do), true, false, nil, a Time, or a String. This interface is designed to be extremely simple, and
  # is modeled after the popular Mixpanel (https://www.mixpanel.com/) API.
  #
  # **IMPORTANT**: Event receivers are called sequentially, in a loop, directly inside the call to #event!. If they
  # raise an exception, it will be propagated through and will be received by the caller of #event!; if they are slow
  # or time out, this latency will be directly experienced by the caller to #event!. This is intentional, because only
  # you can know whether you want to swallow these exceptions or propagate them, or whether you need to make event
  # reporting asynchronous -- and, if so, _how_ -- or not. Think carefully, and add asychronicity or exception handling
  # if needed.
  #
  # Provided with this library is MetaEvents::TestReceiver, which will accept an IO object (like STDOUT), a Logger, or
  # a block, and will accept events and write them as human-readable strings to this destination. Also, the
  # 'mixpanel-ruby' gem is plug-compatible with this library -- an instance of Mixpanel::Tracker is a valid event
  # receiver.
  #
  # To specify the event receiver(s), you can (in order of popularity):
  #
  # * Configure the default receiver(s) for all MetaEvents::Tracker instances that are not otherwise specified by using
  #   <tt>MetaEvents::Tracker.default_event_receivers = [ receiver1, receiver2 ]
  # * Specify receivers at the time you create a new MetaEvents::Tracker:
  #   <tt>tracker = MetaEvents::Tracker.new(current_user.id, request.remote_ip, :event_receivers => [ receiver1, receiver2 ])
  # * Modify an existing MetaEvents::Tracker:
  #   <tt>my_tracker.event_receivers = [ receiver1, receiver2 ]
  #
  # ## Version Specification
  #
  # As mentioned above, any given MetaEvents::Tracker can only fire events from a single version within the MetaEvents DSL.
  # Since the point of DSL versions is to support wholesale overhauls of your entire events system, this is probably
  # fine; the set of implicit properties you want to use will almost certainly have changed, too.
  #
  # To specify the version within your MetaEvents DSL that a Tracker will work against, you can:
  #
  # * Set the default for all MetaEvents::Tracker instances using <tt>MetaEvents::Tracker.default_version = 1</tt>; or
  # * Specify the version at the time you create a new MetaEvents::Tracker: <tt>tracker = MetaEvents::Tracker.new(current_user.id, request.remote_ip, :version => 1)</tt>;
  #
  # <tt>MetaEvents::Tracker.default_version</tt> is 1 by default, so, until you define your second version, you can safely
  # ignore this.
  #
  # ## Setting Up Definitions
  #
  # Part of the whole point of the MetaEvents::Tracker is that it works against the MetaEvents DSL. If you're using this with
  # Rails, you simply need to create <tt>config/events.rb</tt> with something like:
  #
  #     global_events_prefix :pz
  #
  #     version 1, '2014-01-30' do
  #       category :user do
  #         event :signup, '2014-02-01', 'a user first creates their account'
  #         event :login, '2014-02-01', 'a user enters their password'
  #       end
  #     end
  #
  # ...and it will "just work".
  #
  # If you're not using Rails or you don't want to do this, it's still easy enough. You can specify a set of events
  # in one of two ways:
  #
  # * As a separate file, using the MetaEvents DSL, just like the <tt>config/events.rb</tt> example above;
  # * Directly as an instance of MetaEvents::Definition::DefinitionSet, using any mechanism you choose.
  #
  # Once you have either of the above, you can set up your MetaEvents::Tracker with it in any of these ways:
  #
  # * <tt>MetaEvents::Tracker.default_definitions = "path/to/myfile"</tt>;
  # * <tt>MetaEvents::Tracker.default_definitions = my_definition_set</tt> -- both of these will set the definitions for
  #   any and all MetaEvents::Tracker instances that do not have definitions directly set on them;
  # * <tt>my_tracker = MetaEvents::Tracker.new(current_user.id, request.remote_ip, :definitions => "path/to/myfile")</tt>;
  # * <tt>my_tracker = MetaEvents::Tracker.new(current_user.id, request.remote_ip, :definitions => my_definition_set)</tt> -- setting it in the constructor.
  #
  # ## Implicit Properties
  #
  # When you create an MetaEvents::Tracker instance, you can add implicit properties to it simply by passing the
  # +:implicit_properties+ option to the constructor. These properties will be automatically attached to all events
  # fired by that object, unless they are explicitly overridden with a different value (+nil+ will work if needed)
  # passed in the individual event call.
  #
  # ## Property Merging: Sub-Hashes
  #
  # Sometimes you have large numbers of properties that pertain to a particular entity in your system. For this reason,
  # the MetaEvents::Tracker supports _sub-hashes_:
  #
  #     my_tracker.event!(:user, :signed_up,
  #          :user => { :first_name => 'Jane', :last_name => 'Dunham', :city => 'Seattle' }, :color => 'green')
  #
  # This will result in a call to the event receivers that looks like this:
  #
  #     receiver.track('some_distinct_id', 'ab1_user_signed_up', {
  #         'user_first_name' => 'Jane',
  #         'user_last_name'  => 'Dunham',
  #         'user_city'       => 'Seattle',
  #         'color'           => 'green'
  #     })
  #
  # Using this mechanism, you can easily sling around entire sets of properties without needing to write lots of code
  # using Hash, #merge, and so on. Even better, if you accidentally collide two properties with each other this way
  # (such as if you specified a separate, top-level +:user_city+ key above), MetaEvents::Tracker will let you know about it.
  #
  # ## Property Merging: to_event_properties
  #
  # What you _really_ want, however, is to be able to pass entire objects into an event -- this is where the real power
  # of the MetaEvents::Tracker comes in handy.
  #
  # If you pass into an event, or into the implicit-properties set, a key that's bound to a value that's an object that
  # responds to #to_event_properties, then this method will be called, and its properties merged in. For example,
  # assume you have the following:
  #
  #     class User < ActiveRecord::Base
  #       ...
  #       def to_event_properties
  #         {
  #            :age => ((Time.now - date_of_birth) / 1.year).floor,
  #            :payment_level => payment_level,
  #            :city => home_city
  #            ...
  #         }
  #       end
  #       ...
  #     end
  #
  # ...and now you make a call like this:
  #
  #     my_tracker.event!(:user, :logged_in, :user => current_user, :last_login => current_user.last_login)
  #
  # You'll end up with a set of properties like this:
  #
  #     receiver.track('some_distinct_id', 'ab1_user_logged_in', {
  #         'user_age' => 27,
  #         'user_payment_level' => 'enterprise',
  #         'user_city' => 'Seattle',
  #         'last_login' => 2014-02-03 17:28:34 -0800
  #     })
  #
  # Using this mechanism, you can (and should!) define standard #to_event_properties methods on many of your models,
  # and then pass in models frequently -- this allows you to easily build large sets of properties to pass with your
  # events, which is one of the keys to making many event-tracking tools as powerful as possible.
  #
  # Because this mechanism works the way it does, you can also pass in multiple models of the same type:
  #
  #     my_tracker.event!(:user, :sent_message, :from => from_user, :to => to_user)
  #
  # ...becomes:
  #
  #     receiver.track('some_distinct_id', 'ab1_user_sent_message', {
  #         'from_age' => 27,
  #         'from_payment_level' => 'enterprise',
  #         'from_city' => 'Seattle',
  #         'to_age' => 35,
  #         'to_payment_level' => 'personal',
  #         'to_city' => 'San Francisco'
  #     })
  #
  # Note that if you need different #to_event_properties objects for different situations, as sometimes occurs, the
  # fact that Hash merging works the same way means you can build it yourself, trivially:
  #
  #      my_tracker.event!(:user, :logged_in,
  #                        :user => current_user.login_event_properties, :last_login => current_user.last_login)
  #
  # ...or however you'd like it to work.
  #
  # ## The Global Events Prefix
  #
  # No matter how you configure the MetaEvents::Tracker, you _must_ specify a "global events prefix" -- either using the
  # MetaEvents DSL (<tt>global_events_prefix :foo</tt>), or in the constructor
  # (<tt>MetaEvents::Tracker.new(current_user.id, request.remote_ip, :global_events_prefix => :foo)</tt>).
  #
  # The point of the global events prefix is to help distinguish events generated by this system from any events you
  # may have feeding into a target system that are generated elsewhere. You can set the global events prefix to anything
  # you like; it, plus, the version number, will be prepended to all event names. For example, if you set it to +'pz'+,
  # and you're using version 3, then an event +:foo+ in a category +:bar+ will have the full name +pz3_foo_bar+.
  #
  # We recommend that you keep the global events prefix short, simply because tools like Mixpanel often have a
  # relatively small amount of screen real estate available for event names.
  #
  # ### Overriding Event Names
  #
  # There might be a situation where users performing analysis desire a friendlier name than the default.
  # The external name can be customized with a lambda (or any object that responds to <tt>#call(event)</tt>).
  # To customize the external name for all MetaEvents::Tracker instances,
  # specify <tt>MetaEvents::Tracker.default_external_name = lambda { |event| "custom event name" }</tt>.
  #
  # To customize the external name for a specific MetaEvents::Tracker instance, pass the lambda
  # in the constructor, for example:
  # <tt>MetaEvents::Tracker.new(current_user.id, request.remote_ip, :external_name => lambda {|e| "#{e.full_name}_CUSTOM" })</tt>
  #
  # To reset default behavior back to the built-in default, simply set <tt>MetaEvents::Tracker.default_external_name = nil</tt>
  #
  # The event passed to external_name is an instance of ::MetaEvents::Definition::Event
  #
  class Tracker
    class EventError < StandardError; end
    class PropertyCollisionError < EventError; end

    # ## Class Attributes

    # The set of event receivers that MetaEvents::Tracker instances will use if they aren't configured otherwise. This is
    # useful if you want to set up event receivers "as configuration" -- for example, in config/environment.rb in
    # Rails.
    cattr_accessor :default_event_receivers
    self.default_event_receivers = [ ]

    class << self

      # The set of event definitions from the MetaEvents DSL that MetaEvents::Tracker instances will use, by default (_i.e._, if not
      # passed a separate definitions file using <tt>:definitions =></tt> in the constructor). You can set this to
      # the pathname of a file containing event definitions, an +IO+ object containing the text of event definitions, or
      # an ::MetaEvents::Definition::DefinitionSet object that you create any way you want.
      #
      # Reading +default_definitions+ always will return an instance of ::MetaEvents::Definition::DefinitionSet.
      def default_definitions=(source)
        @default_definitions = ::MetaEvents::Definition::DefinitionSet.from(source)
      end
      attr_reader :default_definitions

      # The built-in default calculation of an external event name, which is the event's <tt>:full_name</tt>
      DEFAULT_EXTERNAL_NAME = lambda { |event| event.full_name }

      # The default value that new MetaEvents::Tracker instances will use to provide external names for events.
      def default_external_name=(provider)
        if provider && !provider.respond_to?(:call)
          raise ArgumentError, "default_external_name must respond to #call"
        end
        @default_external_name = provider
      end

      # If a default external name provider was not specified, use the built-in default.
      def default_external_name
        @default_external_name || DEFAULT_EXTERNAL_NAME
      end
    end

    # The default version that new MetaEvents::Tracker instances will use to look up events in the MetaEvents DSL.
    cattr_accessor :default_version
    self.default_version = 1

    # ## Instance Attributes

    # The set of event receivers that this MetaEvents::Tracker instance will use. This should always be an Array (although
    # it can be empty if you don't want to send events anywhere).
    attr_accessor :event_receivers

    # The ::MetaEvents::Definitions::DefinitionSet that this Tracker is using.
    attr_reader :definitions

    # The version of events that this Tracker is using.
    attr_reader :version

    # A method that provides the external name for an event.
    attr_reader :external_name

    # Creates a new instance.
    #
    # +distinct_id+ is the "distinct ID" of the user on behalf of whom events are going to be fired; this can be +nil+
    # if there is no such user (for example, if you're firing events from a background job that has nothing to do with
    # any particular user). This will be automatically added to all events fired from this MetaEvents::Tracker as a
    # property named +"distinct_id"+. Typically, this will be the primary key of your +users+ table, although it can
    # be any unique identifier you want.
    #
    # +ip+ is the IP address of the user. This is called out as an explicit parameter so that you don't forget it; you
    # can pass +nil+ if you need to or if it isn't relevant, but you generally should pass it -- systems like Mixpanel
    # use it to do geolocation for the client. If you need to override this on an event-by-event basis, simply pass
    # a property named +ip+.
    #
    # (If a user has not logged in yet, you will probably want to assign them a unique ID anyway, via a cookie, and
    # then pass this ID here. If the user logs in to an already-existing account, you probably just want to switch to
    # using their logged-in user ID, since the stuff they did before they logged in isn't very interesting -- you
    # already have them as a user. But if they sign up for a new account, you'll lose tracking across that boundary
    # unless your events provider provides something like Mixpanel's +alias+ call; making that kind of call is beyond
    # the scope of MetaEvents, and should be done separately.)
    #
    # +options+ can contain:
    #
    # [:definitions] If present, this can be anything accepted by ::MetaEvents::Definition::DefinitionSet#from, which will
    #                currently accept a pathname to a file, an +IO+ object that contains the text of definitions, or
    #                an ::MetaEvents::Definition::DefinitionSet that you create however you want. If you don't pass
    #                +:definitions+, then this will use whatever the class property +:default_event_receivers+ is
    #                set to. (If neither one of these is set, you will receive an ArgumentError.)
    # [:version] If present, this should be an integer that specifies which version within the specified MetaEvents DSL this
    #            MetaEvents::Tracker should fire events from. A single Tracker can only fire events from one version; if you
    #            need to support multiple versions simultaneously (for example, if you want to have a period of overlap
    #            during the transition from one version of your events system to another), create multiple Trackers.
    # [:event_receivers] If present, this should be a (possibly empty) Array that lists the set of event-receiver
    #                    objects that you want fired events delivered to.
    # [:implicit_properties] If present, this should be a Hash; this defines a set of properties that will get included
    #                        with every event fired from this Tracker. This can use the hash-merge and object syntax
    #                        (#to_event_properties) documented above. Any properties explicitly passed with an event
    #                        that have the same name as these properties will override these properties for that event.
    # [:external_name] If present, this should be a lambda that takes a single argument and returns a string, or an
    #                  object that responds to call(event). If +:external_name+ is not provided, it will use the
    #                  default configured for the MetaEvents::Tracker class.
    def initialize(distinct_id, ip, options = { })
      options.assert_valid_keys(:definitions, :version, :external_name, :implicit_properties, :event_receivers)

      definitions = options[:definitions] || self.class.default_definitions
      unless definitions
        raise ArgumentError, "We have no event definitions to use. You must either set event definitions for " +
"all event trackers using #{self.class.name}.default_definitions = (DefinitionSet or file), " +
"or pass them to this constructor using :definitions." +
"If you're using Rails, you can also simply put your definitions in the file " +
"config/meta_events.rb, and they will be automatically loaded."
      end

      @definitions = ::MetaEvents::Definition::DefinitionSet.from(definitions)
      @version = options[:version] || self.class.default_version || raise(ArgumentError, "Must specify a :version")
      @external_name = options[:external_name] || self.class.default_external_name || raise(ArgumentError, "Must specify an :external_name")
      raise ArgumentError, ":external_name option must respond to #call" unless @external_name.respond_to?(:call)

      @implicit_properties = { }
      self.class.merge_properties(@implicit_properties, { :ip => normalize_ip(ip).to_s }, property_separator) if ip
      self.class.merge_properties(@implicit_properties, options[:implicit_properties] || { }, property_separator)
      self.distinct_id = distinct_id if distinct_id

      self.event_receivers = Array(options[:event_receivers] || self.class.default_event_receivers.dup)
    end

    # In certain cases, you will only have access to the distinct ID later, and this allows for that use case. (For
    # example, if you create the Tracker in your Rails application's ApplicationController, then, when you process the
    # login action for your application, there will be no distinct ID when the Tracker is created -- because the user
    # does not have the proper cookie set yet -- but you'll discover the distinct ID in the middle of the action.)
    def distinct_id=(new_value)
      new_distinct_id = self.class.normalize_scalar_property_value(new_value)
      if new_distinct_id == :invalid_property_value
        raise ArgumentError, "This is not an acceptable value for a distinct ID: #{new_distinct_id.inspect}"
      end
      @distinct_id = new_distinct_id
    end

    attr_reader :distinct_id

    # Fires an event. +category_name+ must be the name of a category in the MetaEvents DSL (within the version that this
    # Tracker is using -- which is 1 if you haven't changed it); +event_name+ must be the name
    # of an event. +additional_properties+, if present, must be a Hash; the properties supplied will be combined with
    # any implicit properties defined on this Tracker, and sent along with the event.
    #
    # +additional_properties+ can use the sub-hash and object syntax discussed, above, under the introduction to this
    # class.
    def event!(category_name, event_name, additional_properties = { })
      event_data = effective_properties(category_name, event_name, additional_properties)
      event_data[:properties] = { 'time' => Time.now.to_i }.merge(event_data[:properties])

      self.event_receivers.each do |receiver|
        receiver.track(event_data[:distinct_id], event_data[:external_name], event_data[:properties])
      end
    end

    # Given a category, an event, and (optionally) additional properties, performs all of the expansion and validation
    # of #event!, but does not actually fire the event -- rather, returns a Hash containing:
    #
    # [:distinct_id]   The +distinct_id+ that should be passed with the event; this can be +nil+ if there is no distinct
    #                  ID being passed.
    # [:event_name]    The fully-qualified event name, including +global_events_prefix+ and version number.
    # [:external_name] The event name for use in an events backend.
    #                  By default this is +:event_name+ but can be overridden.
    # [:properties]    The full set of properties, expanded (so values will only be scalars, never Hashes or objects),
    #                  with String keys, exactly as they should be passed to an events system.
    #
    # This method can be used for many things, but its primary purpose is to support front-end (Javascript-fired)
    # events: you can have it compute exactly the set of properties that should be attached to such events, embed
    # them into the page (using HTML +data+ attributes, JavaScript literals, or any other storage mechanism you want),
    # and then have the front-end fire them. This allows consistency between front-end and back-end events, and is
    # another big advantage of MetaEvents.
    def effective_properties(category_name, event_name, additional_properties = { })
      event = version_object.fetch_event(category_name, event_name)

      explicit = { }
      self.class.merge_properties(explicit, additional_properties, property_separator)
      properties = @implicit_properties.merge(explicit)

      event.validate!(properties)
      # We need to do this instead of just using || so that you can override a present distinct_id with nil.
      net_distinct_id = if properties.has_key?('distinct_id') then properties.delete('distinct_id') else self.distinct_id end

      event_external_name = event.external_name || external_name.call(event)
      raise TypeError, "The external name of an event must be a String" unless event_external_name.kind_of?(String)

      {
        :distinct_id   => net_distinct_id,
        :event_name    => event.full_name,
        :external_name => event_external_name,
        :properties    => properties
      }
    end

    private
    # When we're expanding Hashes, we don't want to get into infinite recursion if you accidentally create a circular
    # reference. Rather than adding code to actually detect true circular references, we simply refuse to expand
    # Hashes beyond this many layers deep.
    MAX_DEPTH = 10

    # Returns the ::MetaEvents::Definition::Version object we should use for this Tracker.
    def version_object
      @definitions.fetch_version(version)
    end

    # Returns the separator we should use when creating property names for nested properties.
    def property_separator
      version_object.property_separator
    end

    # Accepts an IP address (or nil) in String, Integer, or IPAddr formats, and returns an IPAddr (or nil).
    def normalize_ip(ip)
      case ip
      when nil then nil
      when String then IPAddr.new(ip)
      when Integer then IPAddr.new(ip, Socket::AF_INET)
      when IPAddr then ip
      else raise ArgumentError, "IP must be a String, IPAddr, or Integer, not: #{ip.inspect}"
      end
    end

    class << self
      # Given a target Hash of properties in +target+, and a source Hash of properties in +source+, merges all properties
      # in +source+ into +target+, obeying our hash-expansion rules (as specified in the introduction to this class).
      # All new properties are added with their keys as Strings, and values must be:
      #
      # * A scalar of type Numeric (integer and floating-point numbers are both accepted), true, false, or nil;
      # * A String or Symbol (and Symbols are converted to Strings before being used);
      # * A Time;
      # * A Hash, which will be recursively added using its key, plus an underscore, as the prefix
      #   (that is, <tt>{ :foo => { :bar => :baz }}</tt> will become <tt>{ 'foo_bar' => 'baz' }</tt>);
      # * An object that responds to <tt>#to_event_properties</tt>, which must in turn return a Hash; #to_event_properties
      #   will be called, and it will then be treated exactly like a Hash, above.
      #
      # +prefix+ and +depth+ are only used for internal recursive calls:
      #
      # +prefix+ is a prefix that should be applied to all keys in the +source+ Hash before merging them into the +target+
      # Hash. (Nothing is added to this prefix first, so, if you want an underscore separating it from the key, include
      # the underscore in the +prefix+.)
      #
      # +depth+ should be an integer, indicating how many layers of recursive calls we've invoked; this is simply to
      # prevent infinite recursion -- if this exceeds +MAX_DEPTH+, above, then an exception will be raised.
      def merge_properties(target, source, separator, prefix = nil, depth = 0)
        if depth > MAX_DEPTH
          raise "Nesting in EventTracker is too great; do you have a circular reference? " +
            "We reached depth: #{depth.inspect}; expanding: #{source.inspect} with prefix #{prefix.inspect} into #{target.inspect}"
        end

        unless source.kind_of?(Hash)
          raise ArgumentError, "You must supply a Hash for properties at #{prefix.inspect}; you supplied: #{source.inspect}"
        end

        source.each do |key, value|
          prefixed_key = "#{prefix}#{key}"

          if target.has_key?(prefixed_key)
            raise PropertyCollisionError, %{Because of hash delegation, multiple properties with the key #{prefixed_key.inspect} are
  present. This can happen, for example, if you do this:

    event!(:foo_bar => 'baz', :foo => { :bar => 'quux' })

  ...since we will expand the second hash into a :foo_bar key, but there is already
  one present.}
          end

          net_value = normalize_scalar_property_value(value)
          if net_value == :invalid_property_value
            with_separator = "#{prefixed_key}#{separator}"
            if value.kind_of?(Hash)
              merge_properties(target, value, separator, with_separator, depth + 1)
            elsif value.respond_to?(:to_event_properties)
              merge_properties(target, value.to_event_properties, separator, with_separator, depth + 1)
            else
              raise ArgumentError, "Event property #{prefixed_key.inspect} is not a valid scalar, Hash, or object that " +
                "responds to #to_event_properties, but rather #{value.inspect} (#{value.class.name})."
            end
          else
            target[prefixed_key] = net_value
          end
        end
      end

      FLOAT_INFINITY = (1.0 / 0.0)

      # Given a potential scalar value for a property, either returns the value that should actually be set in the
      # resulting set of properties (for example, converting Symbols to Strings) or returns +:invalid_property_value+
      # if that isn't a valid scalar value for a property.
      def normalize_scalar_property_value(value)
        return "NaN" if value.kind_of?(Float) && value.nan?

        case value
        when true, false, nil then value
        when ActiveSupport::Duration then value.to_i
        when Numeric then value
        when String then value.strip
        when Symbol then value.to_s.strip
        when Time then value.getutc.strftime("%Y-%m-%dT%H:%M:%S")
        when IPAddr then value.to_s
        when FLOAT_INFINITY then "+infinity"
        when -FLOAT_INFINITY then "-infinity"
        when Array then
          out = value.map { |e| normalize_scalar_property_value(e) }
          out = :invalid_property_value if out.detect { |e| e == :invalid_property_value }
          out
        else :invalid_property_value
        end
      end
    end
  end
end
