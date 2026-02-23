import 'package:flutter_test/flutter_test.dart';
import 'package:hubcity_transit_flutter/src/data/repositories/transit_repository_impl.dart';

void main() {
  test('parseRoutePolylines handles route-keyed map payload', () {
    const payload = {
      'blue': [
        [31.0, -89.0],
        [31.1, -89.1],
      ],
      'gold': [
        [32.0, -90.0],
      ],
    };

    final routes = parseRoutePolylines(payload);

    expect(routes, hasLength(2));
    expect(routes.first.routeId, 'blue');
    expect(routes.first.polyline, hasLength(2));
    expect(routes.last.routeId, 'gold');
    expect(routes.last.polyline.single, [32.0, -90.0]);
  });
}
