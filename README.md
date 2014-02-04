`MetaEvents` is a Ruby gem that sits on top of a user-centric analytics system like
[Mixpanel](https://www.mixpanel.com/) and provides structure, documentation, and a historical record to events,
and a powerful properties system that makes it easy to pass large numbers of consistent properties with your events.

### Background

Sending user-centric events to (_e.g._) Mixpanel is far from difficult; iit's a single method call. However, in a
large project, adding calls to Mixpanel all over eventually starts causing issues:

* Understanding what, exactly, an event is tracking, including when it was introduced and when it was changed, is
_paramount_ to doing correct analysis. But once events have been around for a while, whoever put them there has
long-since forgotten (or they may even not be around any more), and trying to understand what `User Upgraded Account`
means, eighteen months later, involves an awful lot of spelunking. (Why did it suddenly triple, permanently, on
February 19th? Is that because we changed what the event means or because we improved the product?)
* Getting a holistic view of what events there are and how they interact becomes basically impossible; all you can do
is look at the output (_i.e._, Mixpanel) and hope you can put the pieces together from there.
* Critical to using Mixpanel well is to pass lots and lots of properties; engineers being the lazy folks that we are,
we often don't do this, and, when we do, they're named inconsistently and may mean different things in different
places.
* Often you want certain properties of the currently-logged-in user (for example) passed on every single event, and
there's not always a clean way to do this.

### MetaEvents

`MetaEvents` helps solve this problem by adding a few critical features:

1. The **MetaEvents DSL** requires developers to declare and document events as they add them (and if they don't, they
can't fire them); this is quick and easy, but enormously powerful as it gives you a holistic view of your events, a
historical record, and detailed documentation on each one.
1. **Object properties support** means you can define the set of event properties an object in your system (like a
User) should expose, and then simply pass that object in your event &mdash; this makes it vastly easier to include
lots of properties, and be consistent about them.
1. **Implicit properties support** means you can add contextual properties (like the currently-logged-in user) in a
single place, and then have every event include those properties.

# Getting Started

Let's get started. We'll assume we're working in a Rails project, although MetaEvents has no dependencies on Rails or any other particular framework. We'll also assume you've installed the MetaEvents gem (ideally via your `Gemfile`).

### Declaring Events

First, let's declare an event that we want to fire. Create `config/meta_events.rb` (MetaEvents automatically
configures this as your events file if you're using Rails; if not, use `MetaEvents::Tracker.default_definitions =` to
set the path to whatever file you like):

    global_events_prefix :ab

    version 1, "2014-02-04" do
      category :user do
        event :signed_up, "2014-02-04", "user creates a brand-new account"
      end
    end

Let's walk through this:

* `global_events_prefix` is a short string that gets added before every single event; this helps discriminate events
  coming from MetaEvents from events coming from other systems. Choose this carefully, don't ever change it, and keep
  it short &mdash; most tools, like Mixpanel, have limited screen real estate for displaying event names.
* `version 1` defines a version of _your entire events system_; this is useful in the case where you want to rework
  the entire set of events you fire &mdash; which is not an uncommon thing. But, for a while, we'll only need a single
  version, and we'll call it 1.
* `2014-02-04` is when this version first was used; this can be any date (and time, if you _really_ want to be precise)
  that you want &mdash; it just has to be parseable by Ruby's `Time.parse` method. (MetaEvents never, ever compares
  this date to `Time.now` or otherwise uses it; it's just for documentation.)
* `category :user` is just a grouping and namespacing of events; the category name is included in every event name
  when fired.
* `event :signed_up` declares an event with a name; `2014-02-04` is required and is the date (and time) that this
  event was introduced. (Again, this is just for documentation purposes.) `user creates a brand-new account` is also
  just for documentation purposes (and also is required), and describes the exact purpose of this event.

### Firing Events

To fire an event, we need an instance of `MetaEvents::Tracker`. For reasons to be explained shortly, we'll want an
instance of this class to be created at a level where we may have things in common (like the current user) &mdash; so,
in a Rails application, our `ApplicationController` is a good place:

    class ApplicationController < ActionController::Base
      ...
      def event_tracker
        @event_tracker ||= MetaEvents::Tracker.new
      end
      ...
    end

Now, from the controller, we can fire an event and pass a couple of properties:

    class UsersController < ApplicationController
      ...
      def create
        ...
        event_tracker.event!(:user, :signed_up, { :user_gender => @new_user.gender, :user_age => @new_user.age })
        ...
      end
      ...
    end

We're just about all done; but, right now, the event isn't actually going anywhere, because we haven't configured any
_event receivers_.

### Hooking Up Mixpanel and a Test Receiver

An _event receiver_ is any object that responds to a method `#track(event_name, event_properties)`, where `event_name`
is a `String` and `event_name` is a Hash mapping `String` property names to simple scalar values &mdash; `true`,
`false`, `nil`, numbers (all `Numeric`s, including both integers and floating-point numbers, are supported), `String`s
(and `Symbol`s will be converted to `String`s transparently), and `Time` objects.

Fortunately, the [Mixpanel](https://github.com/zevarito/mixpanel) Gem complies with this interface perfectly. So, in
`config/environments/production.rb` (or any other file that loads before your first event gets fired):

    MetaEvents::Tracker.default_event_receivers << Mixpanel::Tracker.new("0123456789abcdef")

(where `0123456789abcdef` is actually your Mixpanel API token)

In our development environment, we may or may not want to include Mixpanel itself (so we can either add or not add the
Mixpanel event receiver, above); however, we might also want to print events to the console or some other file as
they are fired. So, in `config/environments/development.rb`:

    MetaEvents::Tracker.default_event_receivers << MetaEvents::TestReceiver.new

This will print events as they are fired to your Rails log (_e.g._, `log/development.log`); you can pass an argument
to the constructor of `TestReceiver` that's a `Logger`, an `IO` (_e.g._, `STDOUT`, `STDERR`, an open `File` object),
or a block (or anything responding to `call`), if you want it to go elsewhere.

### Testing It Out

Now, when you fire an event, you should get output like this in your Rails log:

    Tracked event: "ab1_user_signed_up"
                              user_age: 27
                           user_gender: female

...and, if you have configured Mixpanel properly, it will have been sent to Mixpanel, too!

# Making It Better

### Adding Implicit Properties

### Factoring Out Object Properties

### Retiring an Event

### Documenting Events

Currently, the documentation for the MetaEvents DSL is the source to that DSL itself &mdash; _i.e._,
`config/meta_events.rb` or something similar. However, methods on the DSL objects created (accessible via
a `Tracker`'s `#definitions` method, or `MetaEvents::Tracker`'s `default_definitions` class method) allow for
introspection, and could easily be extended to, _e.g._, generate HTML fully documenting the events.

Patches are welcome. ;-)

### Adding Comments to Events

### Adding a New Version

## Contributing

1. Fork it ( http://github.com/<my-github-username>/meta_events/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
