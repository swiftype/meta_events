# `meta_events` Changelog

## 1.1.0, 25 May 2014

* Support for customizing the event names to Mixpanel using any algorithm you want (`:external_name` in `MetaEvents::Tracker#initialize` or `MetaEvents::Tracker.default_external_name`), or by overriding them on an `Event`-by-`Event` basis (`:external_name` in the DSL on an `Event`). Many thanks to [Aaron Lerch](https://github.com/aaronlerch) for the awesome code and responsiveness!

### 1.0.3, 24 March 2014

* Fixed an issue where the `TestReceiver`'s `Rails.logger` reference could happen before `Rails.logger` was actually loaded, causing an exception. (Thanks to [Jesse Rusak](https://github.com/jder)!)
* Fixed a minor documentation bug (Thanks to [Jesse Rusak](https://github.com/jder)!)
* Added Changelog.
