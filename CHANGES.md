# `meta_events` Changelog

### 1.2.1, 6 November 2014

* Fixed an issue where you could get a `NoMethodError` (`undefined method 'watch' for Spring:Module`) if running with
  Spring, depending on your exact load order and dependency set.

### 1.2.0, 30 June 2014

* You can now customize the separator used in nested properties by passing (_e.g._) `:property_separator => ' '` to
  the declaration of a `version` in the definition DSL. This allows you to get nested properties named things like
  `user age`, `user name`, and so on, rather than `user_age` and `user_name`. (Thanks to
  [Harm de Wit](https://github.com/harmdewit) for the idea.)
* If you passed in a `Time` object to an `#event!` call, `meta_events` was calling `#utc` on it to normalize it to
  UTC...and `Time#utc` (unbeknownst to me) _modifies_ its receiver, which is really bad. Now we call `Time#getutc`
  instead, which doesn't do that. (Big shout-out to [Pete Sharum](https://github.com/petesharum) for catching and
  fixing this, along with a spec for the fix!)
* Added syntax highlighting to the README.
* Bumped versions of Ruby we test against under Travis to the latest ones.

### 1.1.2, 29 May 2014

* The `:external_name` on an Event was not correctly passed (instead of the fully-qualified event name) when using
  link auto-tracking. This fixes the issue, and adds a spec to make sure it works properly.

### 1.1.1, 26 May 2014

* 1.1.0 was accidentally released with a bad dependency that prevented it from installing against anything that used
  ActiveSupport >= 4.0. This corrects that error.
* Documented how to make MetaEvents work with background systems like Resque or Sidekiq to make event dispatch
  asynchronous.
* Documented that the `mixpanel-ruby` gem is still required to work with Mixpanel server-side, and that the Mixpanel
  JavaScript code is still required to work with Mixpanel on the front end.
* Changed Travis configuration to use Ruby 2.1.1 (vs. 2.1.0) and JRuby 1.7.11 (vs. 1.7.9).

## 1.1.0, 25 May 2014

* Support for customizing the event names to Mixpanel using any algorithm you want (`:external_name` in `MetaEvents::Tracker#initialize` or `MetaEvents::Tracker.default_external_name`), or by overriding them on an `Event`-by-`Event` basis (`:external_name` in the DSL on an `Event`). Many thanks to [Aaron Lerch](https://github.com/aaronlerch) for the awesome code and responsiveness!

### 1.0.3, 24 March 2014

* Fixed an issue where the `TestReceiver`'s `Rails.logger` reference could happen before `Rails.logger` was actually loaded, causing an exception. (Thanks to [Jesse Rusak](https://github.com/jder)!)
* Fixed a minor documentation bug (Thanks to [Jesse Rusak](https://github.com/jder)!)
* Added Changelog.
