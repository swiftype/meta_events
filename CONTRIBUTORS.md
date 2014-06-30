# Contributors to `meta_events`

Created and maintained by [Andrew Geweke](https://github.com/ageweke) under the support of the wonderful folks at
[Swiftype, Inc.](https://swiftype.com/).

Additional contributions by:

* [Aaron Lerch](https://github.com/aaronlerch): Support for custom external event names, so that end users of
  Mixpanel and other tools receiving data from `meta_events` can get nice, pretty, human-readable event names.
* [Pete Sharum](https://github.com/petesharum): Fix for `Time` objects passed in; turns out `Time#utc` _modifies_ its
  receiver, which is bad.
* [Jesse Rusak](https://github.com/jder): doc typos and fixes for usage of `Rails.logger`.
