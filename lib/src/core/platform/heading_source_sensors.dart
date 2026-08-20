import 'package:flutter_compass/flutter_compass.dart';

import 'heading_source.dart';

HeadingSource createHeadingSource() => const SensorHeadingSource();

/// Magnetometer-backed heading, used everywhere with a real compass sensor.
class SensorHeadingSource implements HeadingSource {
  const SensorHeadingSource();

  @override
  Stream<double?> headings() {
    final events = FlutterCompass.events;
    if (events == null) return const Stream.empty();
    return events.map((event) => event.heading);
  }

  /// Android and iOS expose the magnetometer without a prompt; location
  /// permission is requested separately and is not a precondition here.
  @override
  Future<bool> ensurePermission() async => true;
}
