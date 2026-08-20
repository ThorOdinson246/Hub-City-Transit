import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'heading_source.dart';

HeadingSource createHeadingSource() => const WebHeadingSource();

@JS('window')
external JSObject get _window;

@JS('DeviceOrientationEvent')
external JSObject? get _deviceOrientationEvent;

/// Heading from the browser's DeviceOrientation API.
///
/// Only works on a secure origin, and only on hardware with a magnetometer —
/// desktop machines generally have none, so this emits `null` there and the map
/// falls back to a non-directional puck rather than showing a cone that lies.
class WebHeadingSource implements HeadingSource {
  const WebHeadingSource();

  /// Safari never fires `deviceorientationabsolute`; it puts a true compass
  /// bearing on the ordinary event instead.
  static const _absoluteEvent = 'deviceorientationabsolute';
  static const _relativeEvent = 'deviceorientation';

  @override
  Future<bool> ensurePermission() async {
    final ctor = _deviceOrientationEvent;
    if (ctor == null) return false;

    // Present on iOS 13+ only. Elsewhere orientation needs no grant.
    if (!ctor.has('requestPermission')) return true;

    try {
      final result = await (ctor.callMethod<JSPromise<JSString>>(
        'requestPermission'.toJS,
      )).toDart;
      return result.toDart == 'granted';
    } catch (_) {
      // Throws when called outside a user gesture. Treat as "no heading".
      return false;
    }
  }

  @override
  Stream<double?> headings() {
    if (_deviceOrientationEvent == null) return const Stream.empty();

    late final StreamController<double?> controller;
    late final JSFunction listener;
    var eventName = _absoluteEvent;

    void onEvent(JSObject event) {
      controller.add(_headingFrom(event));
    }

    controller = StreamController<double?>(
      onListen: () {
        listener = onEvent.toJS;
        // Chrome/Firefox report true north on the absolute event. Safari does
        // not implement it at all, so fall back and read its compass property.
        if (!_window.has('ondeviceorientationabsolute')) {
          eventName = _relativeEvent;
        }
        _window.callMethod<JSAny?>(
          'addEventListener'.toJS,
          eventName.toJS,
          listener,
        );
      },
      onCancel: () {
        _window.callMethod<JSAny?>(
          'removeEventListener'.toJS,
          eventName.toJS,
          listener,
        );
      },
    );

    return controller.stream;
  }

  double? _headingFrom(JSObject event) {
    // iOS: already degrees clockwise from magnetic north.
    final webkit = event.getProperty<JSNumber?>('webkitCompassHeading'.toJS);
    final webkitHeading = webkit?.toDartDouble;
    if (webkitHeading != null && !webkitHeading.isNaN) {
      return webkitHeading % 360;
    }

    // Everyone else: alpha is counter-clockwise from north, and only means
    // north at all when the reading is absolute.
    final isAbsolute =
        event.getProperty<JSBoolean?>('absolute'.toJS)?.toDart ?? false;
    final alpha = event.getProperty<JSNumber?>('alpha'.toJS)?.toDartDouble;
    if (!isAbsolute || alpha == null || alpha.isNaN) return null;

    return (360 - alpha) % 360;
  }
}
