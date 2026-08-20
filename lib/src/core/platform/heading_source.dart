import 'heading_source_sensors.dart'
    if (dart.library.js_interop) 'heading_source_web.dart' as impl;

/// Device compass heading in degrees clockwise from true north, or `null` when
/// the platform can supply a position but not a bearing.
///
/// Exists so the heading cone is one concept with per-platform implementations
/// rather than a `kIsWeb` branch: `flutter_compass` has no web support, and the
/// browser equivalent needs a permission handshake that sensors never do.
abstract interface class HeadingSource {
  Stream<double?> headings();

  /// Must be called from a user gesture.
  ///
  /// Only iOS Safari gates orientation behind a prompt, and it only honours the
  /// request inside a real user interaction. Returns whether headings can be
  /// expected; callers should degrade rather than fail.
  Future<bool> ensurePermission();
}

HeadingSource createHeadingSource() => impl.createHeadingSource();
