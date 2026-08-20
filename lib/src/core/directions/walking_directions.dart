import 'dart:math' as math;

/// One turn in a walking route.
class WalkingStep {
  const WalkingStep({
    required this.instruction,
    required this.distanceMetres,
    required this.durationSeconds,
  });

  final String instruction;
  final double distanceMetres;
  final double durationSeconds;
}

class WalkingRoute {
  const WalkingRoute({
    required this.distanceMetres,
    required this.durationSeconds,
    this.steps = const <WalkingStep>[],
    this.geometry = const <({double lat, double lng})>[],
    this.isEstimate = false,
  });

  final double distanceMetres;
  final double durationSeconds;
  final List<WalkingStep> steps;

  /// Empty for an estimate — the caller draws a straight line instead.
  final List<({double lat, double lng})> geometry;

  /// True when this came from the straight-line fallback, so the UI can avoid
  /// promising turn-by-turn it doesn't have.
  final bool isEstimate;

  int get durationMinutes => (durationSeconds / 60).ceil().clamp(1, 1 << 30);
}

abstract interface class WalkingDirectionsService {
  /// Never throws. A failure returns the straight-line estimate, because a walk
  /// leg with no turn list still beats an error where the itinerary should be.
  Future<WalkingRoute> route({
    required double fromLat,
    required double fromLng,
    required double toLat,
    required double toLng,
  });
}

/// Straight-line distance with a detour factor. Used when no token is
/// configured, and as the fallback whenever a real lookup fails.
class EstimatedWalkingDirections implements WalkingDirectionsService {
  const EstimatedWalkingDirections({
    this.detourFactor = 1.35,
    this.speedMetresPerSecond = 1.34,
  });

  final double detourFactor;
  final double speedMetresPerSecond;

  @override
  Future<WalkingRoute> route({
    required double fromLat,
    required double fromLng,
    required double toLat,
    required double toLng,
  }) async =>
      estimate(
        fromLat: fromLat,
        fromLng: fromLng,
        toLat: toLat,
        toLng: toLng,
        detourFactor: detourFactor,
        speedMetresPerSecond: speedMetresPerSecond,
      );

  static WalkingRoute estimate({
    required double fromLat,
    required double fromLng,
    required double toLat,
    required double toLng,
    double detourFactor = 1.35,
    double speedMetresPerSecond = 1.34,
  }) {
    final metres =
        _haversine(fromLat, fromLng, toLat, toLng) * detourFactor;
    return WalkingRoute(
      distanceMetres: metres,
      durationSeconds: metres / speedMetresPerSecond,
      isEstimate: true,
    );
  }
}

double _haversine(double lat1, double lng1, double lat2, double lng2) {
  const earthRadius = 6371000.0;
  final dLat = _radians(lat2 - lat1);
  final dLng = _radians(lng2 - lng1);
  final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(_radians(lat1)) *
          math.cos(_radians(lat2)) *
          math.sin(dLng / 2) *
          math.sin(dLng / 2);
  return earthRadius * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
}

double _radians(double degrees) => degrees * math.pi / 180;
