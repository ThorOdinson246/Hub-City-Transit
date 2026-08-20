import 'package:flutter_web_plugins/url_strategy.dart';

/// Drops the `#` from web URLs, so routes read `/schedule` rather than
/// `/#/schedule`.
///
/// The host must rewrite unknown paths to `index.html`, or a refresh at a deep
/// link 404s before Flutter ever loads. GitHub Pages cannot rewrite, so the
/// build copies `index.html` to `404.html` — Pages serves that for any unmatched
/// path, which boots the app and lets the router read the original URL.
void configureUrlStrategy() => usePathUrlStrategy();
