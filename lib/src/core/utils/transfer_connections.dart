import '../constants/transit_ids.dart';
import '../../data/models/stop_model.dart';
import 'haversine.dart';

class TransferStopConnection {
  const TransferStopConnection({
    required this.routeId,
    required this.stopId,
    required this.location,
    required this.distanceMeters,
  });

  final RouteId routeId;
  final int stopId;
  final String location;
  final double distanceMeters;
}

List<TransferStopConnection> findTransferConnections({
  required RouteId selectedRoute,
  required StopModel stop,
  required Map<RouteId, List<StopModel>> allStopsByRoute,
  double thresholdMeters = 110,
}) {
  final results = <TransferStopConnection>[];

  for (final entry in allStopsByRoute.entries) {
    if (entry.key == selectedRoute) {
      continue;
    }

    for (final candidate in entry.value) {
      final distance = haversineMeters(
        stop.lat,
        stop.lng,
        candidate.lat,
        candidate.lng,
      );
      if (distance <= thresholdMeters) {
        results.add(
          TransferStopConnection(
            routeId: entry.key,
            stopId: candidate.stopId,
            location: candidate.location,
            distanceMeters: distance,
          ),
        );
      }
    }
  }

  results.sort((a, b) {
    final byRoute = a.routeId.name.compareTo(b.routeId.name);
    if (byRoute != 0) {
      return byRoute;
    }
    final byDistance = a.distanceMeters.compareTo(b.distanceMeters);
    if (byDistance != 0) {
      return byDistance;
    }
    return a.stopId.compareTo(b.stopId);
  });

  return results;
}
