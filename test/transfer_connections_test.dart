import 'package:flutter_test/flutter_test.dart';
import 'package:hubcity_transit_flutter/src/core/constants/transit_ids.dart';
import 'package:hubcity_transit_flutter/src/core/utils/transfer_connections.dart';
import 'package:hubcity_transit_flutter/src/data/models/stop_model.dart';

void main() {
  test('findTransferConnections returns nearby stops on other routes', () {
    const selectedStop = StopModel(
      stopId: 11,
      location: 'Hardy St and 31st Ave',
      lat: 31.324901,
      lng: -89.335847,
      direction: 'Outbound',
    );

    const allStopsByRoute = {
      RouteId.blue: [selectedStop],
      RouteId.gold: [
        StopModel(
          stopId: 6,
          location: 'Hardy St and 31st Ave',
          lat: 31.324901,
          lng: -89.335847,
          direction: 'Outbound',
        ),
      ],
      RouteId.red: [
        StopModel(
          stopId: 99,
          location: 'Far Away Stop',
          lat: 31.3000,
          lng: -89.2000,
          direction: 'Outbound',
        ),
      ],
    };

    final connections = findTransferConnections(
      selectedRoute: RouteId.blue,
      stop: selectedStop,
      allStopsByRoute: allStopsByRoute,
    );

    expect(connections, hasLength(1));
    expect(connections.first.routeId, RouteId.gold);
    expect(connections.first.stopId, 6);
  });

  test('findTransferConnections does not include same-route stops', () {
    const selectedStop = StopModel(
      stopId: 1,
      location: 'Sample Stop',
      lat: 31.0,
      lng: -89.0,
      direction: 'Outbound',
    );

    const allStopsByRoute = {
      RouteId.blue: [
        selectedStop,
        StopModel(
          stopId: 2,
          location: 'Nearby same route stop',
          lat: 31.0002,
          lng: -89.0002,
          direction: 'Inbound',
        ),
      ],
    };

    final connections = findTransferConnections(
      selectedRoute: RouteId.blue,
      stop: selectedStop,
      allStopsByRoute: allStopsByRoute,
    );

    expect(connections, isEmpty);
  });
}
