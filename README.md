`MetaEvents` is a Ruby gem that sits on top of a user-centric analytics system like
[Mixpanel](https://www.mixpanel.com/) and provides structure, documentation, and a historical record to events,
and a powerful properties system that makes it easy to pass large numbers of consistent properties with your events.

### Background

Sending user-centric events to (_e.g._) Mixpanel is far from difficult; it's a single method call. However, in a
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
1. **Front-end integration** lets you very easily track events from DOM elements (like links) using JavaScript, and
use a powerful mechanism to fire front-end events in any way you want.

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
in a Rails application, our `ApplicationController` is a good place. We need to pass it the _distinct ID_ of the user
that's signed in, which is almost always just the primary key from the `users` table &mdash; or `nil` if no user is
currently signed in. We also pass it the IP address of the user (which can safely be `nil`); Mixpanel, for example,
uses this for doing geolocation of users:

    class ApplicationController < ActionController::Base
      ...
      def event_tracker
        @event_tracker ||= MetaEvents::Tracker.new(current_user.try(:id), request.remote_ip)
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

An _event receiver_ is any object that responds to a method `#track(distinct_id, event_name, event_properties)`, where
`distinct_id` is the distinct ID of the user, `event_name` is a `String` and `event_name` is a Hash mapping `String`
property names to simple scalar values &mdash; `true`, `false`, `nil`, numbers (all `Numeric`s, including both
integers and floating-point numbers, are supported), `String`s (and `Symbol`s will be converted to `String`s
transparently), and `Time` objects.

Fortunately, the [Mixpanel](https://github.com/mixpanel/mixpanel-ruby) Gem complies with this interface perfectly.
So, in `config/environments/production.rb` (or any other file that loads before your first event gets fired):

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

    Tracked event: user 483123, "ab1_user_signed_up"
                              user_age: 27
                           user_gender: female

...and, if you have configured Mixpanel properly, it will have been sent to Mixpanel, too!

### Firing Front-End Events

Generally speaking, firing events from the back end (your application server talking to Mixpanel or some other service
directly) is more reliable, while firing events from the front end (JavaScript in your users' browsers talking to
Mixpanel or some other service) is more scalable &mdash; so you may wish to fire events from the front end, too.
Further, there are certain events (scrolling, JavaScript manipulation in the browser, and so on) that simply don't
exist on the back end and can't be tracked from there &mdash; at least, not without adding calls back to your server
from the front-end JavaScript.

**IMPORTANT**: In case it isn't obvious, _any property you include in a front-end event is visible to your users_.
No matter what tricks you might include to obscure that data, it fundamentally will be present on your users' computers
and thus visible to them if they want to take a look. This is no different  than the situation would be without
MetaEvents, but, because MetaEvents makes it so easy to add large amounts of properties (which is a good thing!),
you should take extra care with your `#to_event_properties` methods once you start firing front-end events.

You can fire front-end events with MetaEvents in two ways: _auto-tracking_ and _property expansion_.

#### Auto-Tracking

Auto-tracking is the easiest way of triggering front-end events. MetaEvents provides a Rails helper method that adds
certain attributes to any DOM element you wish (like a link); it then provides a JavaScript function that automatically
picks up these attributes, decodes them, and calls any function you want with them.

As an example, in a view, you simply convert:

    <%= link_to("go here", user_awesome_path, :class => "my_class") %>

...to:

    <%= meta_events_tracked_link_to("go here", user_awesome_path, :class => "my_class",
                                    :meta_event => { :category => :user, :event => :awesome,
                                                     :properties => { :color => 'green' } }) %>

(Not immediately obvious: the `:meta_event` attribute is just part of the `html_options` `Hash` that
`link_to` accepts, not an additional parameter. `meta_events_tracked_link_to` accepts exactly the same parameters as
`link_to`.)

This automatically turns the generated HTML from:

    <a href="/users/awesome" class="my_class">go here</a>

to something like this:

    <a href="/users/awesome" class="my_class mejtp_trk" data-mejtp-event="ab1_user_awesome"
       data-mejtp-prp="{&quot;ip&quot;:&quot;127.0.0.1&quot;,&quot;color&quot;:&quot;green&quot;,&quot;implicit_prop_1&quot;:&quot;someValue&quot;}">go here</a>

`mejtp` stands for "MetaEvents JavaScript Tracking Prefix", and is simply a likely-unique prefix for these values.
(You can change it with `MetaEvents::Helpers.meta_events_javascript_tracking_prefix 'foo'`.) `mejtp_trk` is the class
that allows us to easily detect which elements are set up for tracking; the two data attributes pass the full name
of the event, and a JSON-encoded string of all the properties (both implicit and explicit) to pass with the event.

Now, add this to a Javascript file in your application:

    //= require meta_events

And, finally, call something like this:

    $(document).ready(function() {
      MetaEvents.forAllTrackableElements(document, function(id, element, eventName, properties) {
        mixpanel.track_links("#" + id, eventName, properties);
      })
    });

`MetaEvents.forAllTrackableElements` accepts a root element to start searching at, and a callback function. It finds
all elements with class `mejtp_trk` on them underneath that element, extracts the event name and properties, and adds
a generated DOM ID to that element if it doesn't have one already. It then calls your callback function, passing that
(existing or generated) DOM ID, the element itself, the name of the event, and the full set of properties (decoded, as
a JavaScript Object here). You can then (as above) easily use this to do anything you want, like telling Mixpanel to
track that link properly.

`forAllTrackableElements` also sets a certain data attribute on each link as it processes it, so it's safe to call as
often as you wish &mdash; for example, if the DOM changes. It does _not_ know when the DOM changes, however, so, if you
add content to your page, you will need to re-call it.

#### Property Expansion

If you need to do something more sophisticated than auto-tracking, you can also still easily leverage MetaEvents.
`MetaEvents::Tracker` has the `#effective_properties` method,
which returns everything you need to fire an event. For example, say we want to fire a Mixpanel event in some
arbitrary location in JavaScript code. We can easily have our view generate exactly the event name and properties we
want to fire. We'll change this:

    <script>
      someJavascriptCall("foo");
    </script>

to:

    <script>
    <% data = event_tracker.effective_properties(:user, :did_some_call, { :color => :green }) %>
      someJavascriptCall("foo", <%= data.to_json %>)
    </script>

This will pass, as the second argument to `someJavascriptCall`, a JavaScript Object that looks something like this:

    {
      distinct_id: 12389045,
      event_name:  "ab1_user_did_some_call",
      properties: {
        ip: "127.0.0.1",
        color: "green",
        implicit_prop_1: "someValue"
      }
    }

In other words, `effective_properties` returns a Ruby Hash that contains the `:distinct_id`, the fully-qualified
`:event_name`, and `:properties`, mapping to all properties that should be passed with that call. You can pass this
around to any code that needs it, and do anything you want with it. This gives you a flexible interface to do anything
you want.

You may ask: why do I need to have Ruby code generate this data for me? Why not expose a JavaScript interface to the
same thing? This would be easier in the front-end in certain situations; however, this would also mean reimplementing
quite a lot of MetaEvents in pure JavaScript &mdash; it would have to have a good chunk of the MetaEvents DSL, all
the property-normalizing and -resolution code, all the hash merging, and it _still_ would have to make you pass
certain Ruby objects into it (like a `User`, for example, if you want all of a `User`'s properties). It's much better
to keep that data server-side, and only expose what we need.

### More About Distinct IDs

We glossed over the discussion of the distinct ID above. In short, it is a unique identifier (of no particular format;
both Strings and integers are acceptable) that is unique to the user in question, based on your application's
definition of 'user'. Using the primary key from your `users` table is typically a great way to do it.

There are a few situations where you need to take special care, however:

* **What about visitors who aren't signed in yet?** In this case, you will want to generate a unique ID and assign it
  to the visitor anyway; generating a very large random number and putting it in a cookie in their browser is a good
  way to do this, as well as using something like nginx's `ngx_http_userid_module`.
  (Note that Mixpanel has facilities to do this automatically; however, it uses cookies set on their
  domain, which means you can't read them, which limits it unacceptably &mdash; server-side code and even your own
  Javascript will be unable to use this ID.)
* **What do I do when a user logs in?** Typically, you simply want to switch completely from using their old
  (cookie-based) unique ID to using the primary key of your `users` table (or whatever you use for tracking logged-in
  users). This may seem counterintuitive, but it makes sense, particularly in broad consumer applications: until
  someone logs in, all you really know is which _browser_ is hitting your site, not which _user_. Activity that happens
  in the signed-out state might be the user who eventually logs in...but it also might not be, in the case of shared
  machines; further, activity that happens before the user logs in is unlikely to be particularly interesting to you
  &mdash; you already have the user as a registered user, and so this isn't a conversion or sign-up funnel. Effectively
  treating the activity that happens before they sign in as a completely separate user is actually exactly the right
  thing to do. The correct code structure is simply to call `#distinct_id=` on your `MetaEvents::Tracker` at exactly
  the point at which you log them in (using your session, or a cookie, or whatever), and be done with it.
* **What do I do when a user signs up?** This is the tricky case. You really want to correlate all the activity that
  happened before the signup process with the activity afterwards, so that you can start seeing things like "users who
  come in through funnel X convert to truly active/paid/whatever users at a higher rate than those through funnel Y".
  This requires support from your back-end analytics provider; Mixpanel calls it _aliasing_, and it's accessed via
  their `alias` call. It effectively says "the user with autogenerated ID X is the exact same user as the user with
  primary-key ID Y". Making this call is beyond the scope of MetaEvents, but is quite easy to do assuming your
  analytics provider supports it.

You may also wish to see Mixpanel's documentation about distinct ID, [here](https://mixpanel.com/docs/managing-users/what-the-unique-identifer-does-and-why-its-important), [here](https://mixpanel.com/docs/managing-users/assigning-your-own-unique-identifiers-to-users), and [here](https://mixpanel.com/docs/integration-libraries/using-mixpanel-alias).

# The Real Power of MetaEvents

Now that we've gotten the basics out of the way, we can start using the real power of MetaEvents.

### Adding Implicit Properties

Very often, just by being in some particular part of code, you already know a fair amount of data that you want to
pass as events. For example, if you're inside a Rails controller action, and you have a current user, you're probably
going to want to pass properties about that user to any event that happens in the controller action.

You could add these to every single call to `#event!`, but MetaEvents has a better way. When you create the
`MetaEvents::Tracker` instance, you can define _implicit properties_. Let's add some now:

    class ApplicationController < ActionController::Base
      ...
      def event_tracker
        implicit_properties = { }
        if current_user
          implicit_properties.merge!(
            :user_gender => current_user.gender,
            :user_age => current_user.age
          )
        end
        @event_tracker ||= MetaEvents::Tracker.new(current_user.try(:id), request.remote_ip,
                                                   :implicit_properties => implicit_properties)
      end
      ...
    end

Now, these properties will get passed on every event fired by this Tracker. (This is, in fact, the biggest
consideration when deciding when and where you'll create new `MetaEvents::Tracker` instances: implicit properties are
extremely useful, so you'll want the lifecycle of a Tracker to match closely the lifecycle of something in your
application that has implicit properties.)

### Multi-Object Events

We're also going to face another problem: many events involve multiple underlying objects, each of which has many
properties that are defined on it. For example, imagine we have an event triggered when a user sends a message to
another user. We have at least three entities: the 'from' user, the 'to' user, and the message itself. If we really
want to instrument this event properly, we're going to want something like this:

    event_tracker.event!(:user, :sent_message, {
      :from_user_country => from_user.country,
      :from_user_state => from_user.state,
      :from_user_postcode => from_user.postcode,
      :from_user_city => from_user.city,
      :from_user_language => from_user.language,
      :from_user_referred_from => from_user.referred_from,
      :from_user_gender => from_user.gender,
      :from_user_age => from_user.age,

      :to_user_country => to_user.country,
      :to_user_state => to_user.state,
      :to_user_postcode => to_user.postcode,
      :to_user_city => to_user.city,
      :to_user_language => to_user.language,
      :to_user_referred_from => to_user.referred_from,
      :to_user_gender => to_user.gender,
      :to_user_age => to_user.age,

      :message_sent_at => message.sent_at,
      :message_type => message.type,
      :message_length => message.length,
      :message_language => message.language,
      :message_attachments => message.attachments?
      })

Needless to say, this kind of sucks. Either we're going to end up with a ton of duplicate, unmaintainable code, or
we'll just cut back and only pass a few properties &mdash; greatly reducing the possibilities of our analytics
system.

### Using Hashes to Factor Out Naming

We can improve this situation by using a feature of MetaEvents: when properties are nested in sub-hashes, they get
automatically expanded and their names prefixed by the outer hash key. So let's define a couple of methods on models:

    class User < ActiveRecord::Base
      def to_event_properties
        {
          :country => country,
          :state => state,
          :postcode => postcode,
          :city => city,
          :language => language,
          :referred_from => referred_from,
          :gender => gender,
          :age => age
        }
      end
    end

    class Message < ActiveRecord::Base
      def to_event_properties
        {
          :sent_at => sent_at,
          :type => type,
          :length => length,
          :language => language,
          :attachments => attachments?
        }
      end
    end

Now, we can pass the exact same set of properties as the above example, by simply doing:

    event_tracker.event!(:user, :sent_message, {
      :from_user => from_user.to_event_properties,
      :to_user => to_user.to_event_properties,
      :message => message.to_event_properties
      })

**SO** much better.

### Moving Hash Generation To Objects

And &mdash; tah-dah! &mdash; MetaEvents supports this syntax automatically. If you pass an object as a property, and
that object defines a method called `#to_event_properties`, then it will be called automatically, and replaced.
Our code now looks like:

    event_tracker.event!(:user, :sent_message, { :from_user => from_user, :to_user => to_user, :message => message })

### How to Take the Most Advantage

To make the most use of MetaEvents, define `#to_event_properties` very liberally on objects in your system, make them
return any properties you even think might be useful, and pass them to events. MetaEvents will expand them for you,
allowing large numbers of properties on events, which allows Mixpanel and other such systems to be of the most use
to you.

# Miscellaneous and Trivia

A few things before we're done:

### Mixpanel, Aliasing, and People

MetaEvents is _not_ intended as a complete superset of a backend analytics library (like Mixpanel) &mdash; there are
features of those libraries that are not implemented via MetaEvents, and which should be used by direct calls to the
service in question.

For example, Mixpanel has an `alias` call that lets you tell it that a user with a particular distinct ID is actually
the same person as a user with a different distinct ID &mdash; this is typically used at signup, when you convert from
an "anonymous" distinct ID representing the unknown user who is poking around your site to the actual official user ID
(typically your `users` table primary key) of that user. MetaEvents does not, in any way, attempt to support this; it
allows you to pass whatever `distinct_id` you want in the `#event!` call, but, if you want to use `alias`, you should
make that Mixpanel call directly. (See also the discussion above about _distinct ID_.)

Similarly, Mixpanel's People functionality is not in any way directly supported by MetaEvents. You may well use the
Tracker's `#effective_properties` method to compute a set of properties that you pass to Mixpanel's People system,
but there are no calls directly in MetaEvents to do this for you.

### Retiring an Event

Often you'll have events that you _retire_ &mdash; they were used in the past, but no longer. You could just delete
them from your MetaEvents DSL file, but this will mean the historical record is suddenly gone. (Well, there's source
control, but that's a pain.)

Rather than doing this, you can retire them:

    global_events_prefix :ab

    version 1, "2014-02-04" do
      category :user do
        event :logged_in_with_facebook, "2014-02-04", "user creates a brand-new account", :retired_at => "2014-06-01"
        event :signed_up, "2014-02-04", "user creates a brand-new account"
      end
    end

Given the above, trying to call `event!(:user, :logged_in_with_facebook)` will fail with an exception, because the
event has been retired. (Note that, once again, the actual date passed to `:retired_at` is simply for record-keeping
purposes; the exception is generated if `:retired_at` is set to _anything_.)

You can retire events, categories, and entire versions; this system ensures the DSL continues to be a historical record
of what things were in the past, as well as what they are today.

### Adding Notes to Events

You can also add notes to events. They must be tagged with the author and the time, and they can be very useful for
documenting changes:

    global_events_prefix :ab

    version 1, "2014-02-04" do
      category :user do
        event :signed_up, "2014-02-04", "user creates a brand-new account" do
          note "2014-03-17", "jsmith", "Moved sign-up button to the home page -- should increase signups significantly"
        end
      end
    end

This allows you to record changes to events, as well as the events themselves.

### Documenting Events

Currently, the documentation for the MetaEvents DSL is the source to that DSL itself &mdash; _i.e._,
`config/meta_events.rb` or something similar. However, methods on the DSL objects created (accessible via
a `Tracker`'s `#definitions` method, or `MetaEvents::Tracker`'s `default_definitions` class method) allow for
introspection, and could easily be extended to, _e.g._, generate HTML fully documenting the events.

Patches are welcome. ;-)

### Times

MetaEvents correctly converts any `Time` object you pass into the correct String format for Mixpanel (_e.g._,
`2014-02-03T15:49:17`), converting it to UTC first. This should make your times much cleaner.

### Adding a New Version

What is this top-level `version` in the DSL? Well, every once in a while, you will want to completely redo your set of
events &mdash; perhaps you've learned a lot about using your analytics system, and realize you want them configured
in a different way.

When you want to do this, define a new top-level `version` in your DSL, and pass `:version => 2` (or whatever number
you gave the new version) when creating your `MetaEvents::Tracker`. The tracker will look under that version for
categories and events, and completely ignore other versions; your events will be called things like `ab2_user_signup`
instead of `ab1_user_signup`, and so on. The old version can still stay present in your DSL for documentation and
historical purposes.

When you're completely done with the old version, retire it &mdash; `version 1, :retired_at => '2014-06-01' do ...`.

Often, you'll want to run two versions simultaneously, because you want to have a transition period where you fire
_both_ sets of events &mdash; this is hugely helpful in figuring out how your old events map to new events and
when adjusting bases for the new events. (If you simply flash-cut from an old version to a new one on a single day,
it is difficult or impossible to know if true underlying usage, etc., _actually_ changed, or if it's just an artifact
of changing events.) You can simply create two `MetaEvents::Tracker` instances, one for each version, and use them
in parallel.

## Contributing

1. Fork it ( http://github.com/swiftype/meta_events/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
