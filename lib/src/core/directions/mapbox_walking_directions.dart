import 'package:dio/dio.dart';

import 'walking_directions.dart';

/// Mapbox Directions, walking profile.
///
/// Only ever called for walk legs of an itinerary already on screen — never
/// during search, which evaluates dozens of candidate pairs against the free
/// estimate instead. That keeps a plan at roughly two requests rather than
/// fifty, which is what makes the free tier comfortable.
final class MapboxWalkingDirections implements WalkingDirectionsService {
  MapboxWalkingDirections({
    required Dio dio,
    required String accessToken,
    this.cacheLimit = 200,
  })  : _dio = dio,
        _token = accessToken;

  static const String _base = 'https://api.mapbox.com/directions/v5/mapbox/walking';

  final Dio _dio;
  final String _token;
  final int cacheLimit;
  final Map<String, WalkingRoute> _cache = <String, WalkingRoute>{};

  bool get isConfigured => _token.isNotEmpty;

  @override
  Future<WalkingRoute> route({
    required double fromLat,
    required double fromLng,
    required double toLat,
    required double toLng,
  }) async {
    final fallback = EstimatedWalkingDirections.estimate(
      fromLat: fromLat,
      fromLng: fromLng,
      toLat: toLat,
      toLng: toLng,
    );
    if (!isConfigured) return fallback;

    // Rounded to ~1m. Stop coordinates are fixed, so the same leg recurs
    // constantly as the user reopens a plan.
    final key = '${fromLat.toStringAsFixed(5)},${fromLng.toStringAsFixed(5)};'
        '${toLat.toStringAsFixed(5)},${toLng.toStringAsFixed(5)}';
    final hit = _cache[key];
    if (hit != null) return hit;

    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '$_base/$fromLng,$fromLat;$toLng,$toLat',
        queryParameters: <String, String>{
          'access_token': _token,
          'geometries': 'geojson',
          'steps': 'true',
          'overview': 'full',
        },
      );

      final parsed = _parse(response.data);
      if (parsed == null) return fallback;

      if (_cache.length >= cacheLimit) _cache.remove(_cache.keys.first);
      _cache[key] = parsed;
      return parsed;
    } on DioException {
      return fallback;
    }
  }

  WalkingRoute? _parse(Map<String, dynamic>? data) {
    final routes = data?['routes'];
    if (routes is! List || routes.isEmpty) return null;
    final first = routes.first;
    if (first is! Map<String, dynamic>) return null;

    final distance = first['distance'];
    final duration = first['duration'];
    if (distance is! num || duration is! num) return null;

    final geometry = <({double lat, double lng})>[];
    final coords = (first['geometry'] as Map<String, dynamic>?)?['coordinates'];
    if (coords is List) {
      for (final point in coords) {
        if (point is List && point.length >= 2) {
          final lng = point[0];
          final lat = point[1];
          if (lat is num && lng is num) {
            geometry.add((lat: lat.toDouble(), lng: lng.toDouble()));
          }
        }
      }
    }

    final steps = <WalkingStep>[];
    final legs = first['legs'];
    if (legs is List) {
      for (final leg in legs) {
        final legSteps = (leg as Map<String, dynamic>?)?['steps'];
        if (legSteps is! List) continue;
        for (final step in legSteps) {
          if (step is! Map<String, dynamic>) continue;
          final maneuver = step['maneuver'];
          final instruction = maneuver is Map<String, dynamic>
              ? maneuver['instruction']
              : null;
          if (instruction is! String || instruction.isEmpty) continue;
          steps.add(WalkingStep(
            instruction: instruction,
            distanceMetres: (step['distance'] as num?)?.toDouble() ?? 0,
            durationSeconds: (step['duration'] as num?)?.toDouble() ?? 0,
          ));
        }
      }
    }

    return WalkingRoute(
      distanceMetres: distance.toDouble(),
      durationSeconds: duration.toDouble(),
      steps: steps,
      geometry: geometry,
    );
  }
}
