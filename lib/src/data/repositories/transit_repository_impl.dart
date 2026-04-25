import 'dart:convert';
import 'dart:math';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';

import '../../core/constants/app_constants.dart';
import '../../domain/repositories/transit_repository.dart';
import '../models/bus_location_model.dart';
import '../models/eta_result_model.dart';
import '../models/route_polyline_model.dart';
import '../models/route_schedule_model.dart';
import '../models/stop_model.dart';

final class TransitRepositoryImpl implements TransitRepository {
  TransitRepositoryImpl(this._dio);

  final Dio _dio;
  Map<String, List<StopModel>>? _stopsCache;
  Map<String, RouteScheduleModel>? _scheduleCache;

  @override
  Future<List<RoutePolylineModel>> getRoutes() async {
    final text = await rootBundle.loadString(localRouteAssetPath);
    final dynamic decoded = jsonDecode(text);
    return parseRoutePolylines(decoded);
  }

  @override
  Future<List<StopModel>> getStops({String? routeId}) async {
    final data = await _loadStops();
    if (routeId == null) {
      return data.values.expand((stops) => stops).toList(growable: false);
    }

    return data[routeId] ?? const [];
  }

  @override
  Future<RouteScheduleModel?> getSchedule(String routeId) async {
    final data = await _loadSchedules();
    return data[routeId];
  }

  @override
  Future<BusLocationModel?> getBusLocation(String busId) async {
    final normalizedArcGisUrl = _normalizeArcGisUrl();
    if (normalizedArcGisUrl.isEmpty) {
      throw Exception('ARCGIS_URL is not configured.');
    }

    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '$normalizedArcGisUrl/query',
        queryParameters: {
          'f': 'json',
          'where': "LOWER(full_name) = 'hct ${busId.toLowerCase()}'",
          'outFields': 'full_name,speed,course,location_timestamp',
          'returnGeometry': 'true',
          'outSR': '4326',
        },
      );
      final data = response.data;
      final features = data?['features'];
      if (data == null || features is! List || features.isEmpty) {
        return null;
      }

      final feature = features.first;
      if (feature is! Map<String, dynamic>) {
        return null;
      }

      final geometry = feature['geometry'];
      final attributes = feature['attributes'];
      if (geometry is! Map<String, dynamic> || attributes is! Map<String, dynamic>) {
        return null;
      }

      final lat = geometry['y'];
      final lng = geometry['x'];
      if (lat is! num || lng is! num) {
        return null;
      }

      final timestamp = attributes['location_timestamp'];
      final lastSeen = timestamp is num
          ? DateTime.fromMillisecondsSinceEpoch(timestamp.toInt())
          : DateTime.now();

      return BusLocationModel(
        lat: lat.toDouble(),
        lng: lng.toDouble(),
        busId: busId,
        lastSeen: lastSeen,
        heading: attributes['course'] is num
            ? (attributes['course'] as num).toDouble()
            : null,
        speed: attributes['speed'] is num
            ? (attributes['speed'] as num).toDouble()
            : null,
      );
    } on DioException catch (error) {
      final data = error.response?.data;
      if (data is Map<String, dynamic>) {
        final features = data['features'];
        if (features is List && features.isEmpty) {
          return null;
        }
      }
      if (error.response?.statusCode == 503) {
        return null;
      }
      throw Exception(_mapDioError(error, 'Unable to load bus location.'));
    }
  }

  @override
  Future<EtaResultModel> getEta({
    required String busId,
    required double userLat,
    required double userLng,
  }) async {
    final busLocation = await getBusLocation(busId);
    if (busLocation == null) {
      return EtaResultModel(
        busId: busId,
        status: 'bus-offline',
        message: 'Bus location unavailable',
      );
    }

    if (googleMapsApiKey.isEmpty) {
      return EtaResultModel(
        busId: busId,
        status: 'error',
        message: 'GOOGLE_MAPS_API_KEY is not configured.',
      );
    }

    final stops = await getStops(routeId: _routeIdForBus(busId));
    if (stops.isEmpty) {
      return EtaResultModel(
        busId: busId,
        status: 'error',
        message: 'No stops available for selected route.',
      );
    }

    final userStopIdx = _findNearestStopIndex(userLat, userLng, stops);
    final busStopIdx = _findNearestStopIndex(
      busLocation.lat,
      busLocation.lng,
      stops,
    );
    final userStop = stops[userStopIdx];

    final waypoints = busStopIdx <= userStopIdx
        ? stops
              .sublist(busStopIdx, userStopIdx + 1)
              .map((stop) => [stop.lat, stop.lng])
              .toList(growable: false)
        : [
            ...stops
                .sublist(busStopIdx)
                .map((stop) => [stop.lat, stop.lng]),
            ...stops
                .sublist(0, userStopIdx + 1)
                .map((stop) => [stop.lat, stop.lng]),
          ];

    final totalSeconds = await _calculateEtaWithWaypointLimit(
      origin: [busLocation.lat, busLocation.lng],
      destination: waypoints.last,
      waypoints: waypoints,
    );

    if (totalSeconds == null) {
      return EtaResultModel(
        busId: busId,
        status: 'error',
        nearestStopId: userStop.stopId,
        nearestStopName: userStop.location,
        message: 'Could not calculate directions.',
      );
    }

    return EtaResultModel(
      busId: busId,
      status: 'ok',
      etaMinutes: (totalSeconds / 60).round(),
      nearestStopId: userStop.stopId,
      nearestStopName: userStop.location,
    );
  }

  String _mapDioError(DioException error, String fallbackMessage) {
    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.sendTimeout ||
        error.type == DioExceptionType.receiveTimeout) {
      return 'Request timed out. Please try again.';
    }

    if (error.type == DioExceptionType.connectionError) {
      return 'No internet connection.';
    }

    final statusCode = error.response?.statusCode;
    if (statusCode != null && statusCode >= 500) {
      return 'Server is unavailable. Please try again shortly.';
    }

    return fallbackMessage;
  }

  Future<Map<String, List<StopModel>>> _loadStops() async {
    if (_stopsCache != null) {
      return _stopsCache!;
    }

    final text = await rootBundle.loadString(localStopsAssetPath);
    final decoded = jsonDecode(text);
    if (decoded is! Map<String, dynamic>) {
      _stopsCache = const {};
      return _stopsCache!;
    }

    final parsed = <String, List<StopModel>>{};
    for (final entry in decoded.entries) {
      final value = entry.value;
      if (value is! List<dynamic>) continue;
      parsed[entry.key] = value
          .whereType<Map<String, dynamic>>()
          .map(StopModel.fromJson)
          .toList(growable: false);
    }
    _stopsCache = parsed;
    return parsed;
  }

  Future<Map<String, RouteScheduleModel>> _loadSchedules() async {
    if (_scheduleCache != null) {
      return _scheduleCache!;
    }

    final text = await rootBundle.loadString(localScheduleAssetPath);
    final decoded = jsonDecode(text);
    if (decoded is! Map<String, dynamic>) {
      _scheduleCache = const {};
      return _scheduleCache!;
    }

    final parsed = <String, RouteScheduleModel>{};
    for (final entry in decoded.entries) {
      final value = entry.value;
      if (value is! Map<String, dynamic>) continue;
      parsed[entry.key] = RouteScheduleModel.fromJson(value);
    }
    _scheduleCache = parsed;
    return parsed;
  }

  String _normalizeArcGisUrl() {
    final trimmed = arcGisUrl.trim();
    if (trimmed.isEmpty) return '';
    return trimmed.endsWith('/query')
        ? trimmed.substring(0, trimmed.length - '/query'.length)
        : trimmed;
  }

  String _routeIdForBus(String busId) {
    if (busId.startsWith('blue')) return 'blue';
    if (busId.startsWith('gold')) return 'gold';
    return busId;
  }

  int _findNearestStopIndex(
    double lat,
    double lng,
    List<StopModel> stops,
  ) {
    var minDistance = double.infinity;
    var minIndex = 0;

    for (var i = 0; i < stops.length; i++) {
      final stop = stops[i];
      final distance = _haversineMeters(lat, lng, stop.lat, stop.lng);
      if (distance < minDistance) {
        minDistance = distance;
        minIndex = i;
      }
    }

    return minIndex;
  }

  Future<int?> _calculateEtaWithWaypointLimit({
    required List<double> origin,
    required List<double> destination,
    required List<List<double>> waypoints,
  }) async {
    if (waypoints.length <= 25) {
      return _fetchDirectionsEta(
        origin: origin,
        destination: destination,
        waypoints: waypoints,
      );
    }

    var totalSeconds = 0;
    var currentOrigin = origin;
    var remaining = List<List<double>>.from(waypoints);

    while (remaining.isNotEmpty) {
      final batch = remaining.take(25).toList(growable: false);
      final eta = await _fetchDirectionsEta(
        origin: currentOrigin,
        destination: batch.last,
        waypoints: batch,
      );

      if (eta == null) {
        return null;
      }

      totalSeconds += eta;
      currentOrigin = batch.last;
      remaining = remaining.skip(25).toList(growable: false);
    }

    return totalSeconds;
  }

  Future<int?> _fetchDirectionsEta({
    required List<double> origin,
    required List<double> destination,
    required List<List<double>> waypoints,
  }) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        'https://maps.googleapis.com/maps/api/directions/json',
        queryParameters: {
          'origin': '${origin[0]},${origin[1]}',
          'destination': '${destination[0]},${destination[1]}',
          'waypoints': waypoints.map((w) => '${w[0]},${w[1]}').join('|'),
          'mode': 'driving',
          'key': googleMapsApiKey,
          'departure_time': 'now',
          'traffic_model': 'optimistic',
          'optimize_waypoints': 'false',
        },
      );

      final data = response.data;
      final routes = data?['routes'];
      if (data?['status'] != 'OK' || routes is! List || routes.isEmpty) {
        return null;
      }

      final firstRoute = routes.first;
      if (firstRoute is! Map<String, dynamic>) return null;
      final legs = firstRoute['legs'];
      if (legs is! List || legs.isEmpty) return null;

      var total = 0;
      for (var i = 0; i < legs.length - 1; i++) {
        final leg = legs[i];
        if (leg is! Map<String, dynamic>) continue;
        final duration = leg['duration'];
        if (duration is! Map<String, dynamic>) continue;
        final value = duration['value'];
        if (value is num) {
          total += value.toInt();
        }
      }
      return total;
    } on DioException {
      return null;
    }
  }

  double _haversineMeters(
    double lat1,
    double lng1,
    double lat2,
    double lng2,
  ) {
    const earthRadiusMeters = 6371000;
    final dLat = _degreesToRadians(lat2 - lat1);
    final dLng = _degreesToRadians(lng2 - lng1);
    final a =
        (sin(dLat / 2) * sin(dLat / 2)) +
        cos(_degreesToRadians(lat1)) *
            cos(_degreesToRadians(lat2)) *
            (sin(dLng / 2) * sin(dLng / 2));
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadiusMeters * c;
  }

  double _degreesToRadians(double degrees) => degrees * (pi / 180);
}

List<RoutePolylineModel> parseRoutePolylines(dynamic decoded) {
  if (decoded is Map<String, dynamic>) {
    final result = <RoutePolylineModel>[];
    for (final entry in decoded.entries) {
      final value = entry.value;
      if (value is! List<dynamic>) {
        continue;
      }

      final polyline = <List<double>>[];
      for (final point in value) {
        if (point is List<dynamic> && point.length == 2) {
          final lat = point[0];
          final lng = point[1];
          if (lat is num && lng is num) {
            polyline.add([lat.toDouble(), lng.toDouble()]);
          }
        }
      }

      result.add(RoutePolylineModel(routeId: entry.key, polyline: polyline));
    }
    return result;
  }

  if (decoded is List<dynamic>) {
    return decoded
        .whereType<Map<String, dynamic>>()
        .map(RoutePolylineModel.fromJson)
        .toList(growable: false);
  }

  return const [];
}
