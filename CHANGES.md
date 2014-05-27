# `meta_events` Changelog

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
