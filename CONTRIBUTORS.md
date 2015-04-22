# Contributors to `meta_events`

Created and maintained by [Andrew Geweke](https://github.com/ageweke) under the support of the wonderful folks at
[Swiftype, Inc.](https://swiftype.com/).

Additional contributions by:

* [Aaron Lerch](https://github.com/aaronlerch): Support for custom external event names, so that end users of
  Mixpanel and other tools receiving data from `meta_events` can get nice, pretty, human-readable event names.
* [Pete Sharum](https://github.com/petesharum): Fix for `Time` objects passed in; turns out `Time#utc` _modifies_ its
  receiver, which is bad.
* [Jesse Rusak](https://github.com/jder): doc typos and fixes for usage of `Rails.logger`.
* [charle5](https://github.com/charle5): Fix for `NoMethodError` (`undefined method 'watch' for Spring:Module`)
  when used with Spring in certain circumstances.
* [Fabian Stehle](https://github.com/fstehle): Fix for `NoMethodError` (`undefined method 'watch' for Spring:Module`)
  when used with Spring in certain circumstances.
* [Hubert Lee](https://github.com/hube): Fix for issue where the JavaScript exception you would get if you tried to
  invoke a front-end event that hadn't been registered would have the wrong event name in it.
* [David Yarbro](https://github.com/yarbro): Fix for issue where using `link_to` with a block would fail if you're
  using `meta_events`, due to the way Rails renames parameters in this scenario.
* [Mark Quezada](https://github.com/markquezada): Submitting a pull request for issue where using `link_to` with a
  block would fail if you're using `meta_events`, due to the way Rails renames parameters in this scenario.
* [Anthony](https://github.com/Aerlinger): Improved installation instructions.
* [Cayo Medeiros](https://github.com/yogodoshi): Remove RSpec deprecation warnings.

Inspiration for ideas by:

* [Harm de Wit](https://github.com/harmdewit) for adding a configurable `properties_separator` on the `version` in the
  events DSL.
