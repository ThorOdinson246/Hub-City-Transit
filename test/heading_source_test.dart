import 'package:flutter_test/flutter_test.dart';
import 'package:hubcity_transit_flutter/src/core/platform/heading_source.dart';
import 'package:hubcity_transit_flutter/src/core/platform/heading_source_sensors.dart'
    show SensorHeadingSource;

void main() {
  test('a non-web target resolves to the sensor-backed heading source', () {
    // Guards the conditional import in heading_source.dart. If a native target
    // ever picked the web implementation, the Android compass would die
    // silently — the heading cone simply never appears.
    expect(createHeadingSource(), isA<SensorHeadingSource>());
  });
}
