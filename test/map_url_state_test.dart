import 'package:flutter_test/flutter_test.dart';
import 'package:hubcity_transit_flutter/src/core/constants/transit_ids.dart';

void main() {
  group('RouteId.tryParse', () {
    test('accepts every real route name', () {
      for (final route in RouteId.values) {
        expect(RouteId.tryParse(route.name), route);
      }
    });

    test('returns null rather than defaulting to blue', () {
      // fromValue falls back to blue, which would turn a typo'd or absent
      // ?route= into a silent, wrong selection.
      expect(RouteId.tryParse(null), isNull);
      expect(RouteId.tryParse(''), isNull);
      expect(RouteId.tryParse('Blue'), isNull);
      expect(RouteId.tryParse('magenta'), isNull);
      expect(RouteId.fromValue('magenta'), RouteId.blue);
    });
  });

  group('map URL', () {
    // Mirrors _MapPageState._pushSelection.
    String urlFor(RouteId route, {String? stopId}) => Uri(
          path: '/map',
          queryParameters: {
            'route': route.value,
            'stop': ?stopId,
          },
        ).toString();

    test('encodes a route on its own', () {
      expect(urlFor(RouteId.gold), '/map?route=gold');
    });

    test('encodes a route and stop together', () {
      expect(urlFor(RouteId.blue, stopId: '4021'), '/map?route=blue&stop=4021');
    });

    test('round-trips back to the same selection', () {
      final uri = Uri.parse(urlFor(RouteId.purple, stopId: '18'));
      expect(RouteId.tryParse(uri.queryParameters['route']), RouteId.purple);
      expect(uri.queryParameters['stop'], '18');
    });

    test('a closed sheet leaves no stop parameter to restore', () {
      final uri = Uri.parse(urlFor(RouteId.red));
      expect(uri.queryParameters.containsKey('stop'), isFalse);
      expect(RouteId.tryParse(uri.queryParameters['route']), RouteId.red);
    });
  });
}
