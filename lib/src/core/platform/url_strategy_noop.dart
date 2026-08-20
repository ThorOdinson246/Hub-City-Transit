/// No-op on every platform that has no browser URL bar.
///
/// Kept as a real implementation rather than a `kIsWeb` branch at the call site
/// so `flutter_web_plugins` never enters the Android or iOS compile graph.
void configureUrlStrategy() {}
