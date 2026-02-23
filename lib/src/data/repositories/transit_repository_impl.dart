import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';

import '../models/bus_location_model.dart';
import '../models/eta_result_model.dart';
import '../models/route_polyline_model.dart';
import '../models/stop_model.dart';
import '../../core/constants/app_constants.dart';
import '../../domain/repositories/transit_repository.dart';

final class TransitRepositoryImpl implements TransitRepository {
  TransitRepositoryImpl(this._dio);

  final Dio _dio;

  @override
  Future<List<RoutePolylineModel>> getRoutes() async {
    final text = await rootBundle.loadString(localRouteAssetPath);
    final dynamic decoded = jsonDecode(text);
    return parseRoutePolylines(decoded);
  }

  @override
  Future<List<StopModel>> getStops({String? routeId}) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/api/stops',
      queryParameters: routeId == null ? null : {'route': routeId},
    );

    final dynamic data = response.data;
    if (data is Map<String, dynamic> && data['stops'] is List<dynamic>) {
      return (data['stops'] as List<dynamic>)
          .whereType<Map<String, dynamic>>()
          .map(StopModel.fromJson)
          .toList(growable: false);
    }

    if (data is Map<String, dynamic>) {
      final allStops = <StopModel>[];
      for (final entry in data.entries) {
        final value = entry.value;
        if (value is List<dynamic>) {
          allStops.addAll(
            value.whereType<Map<String, dynamic>>().map(StopModel.fromJson),
          );
        }
      }
      return allStops;
    }

    return const [];
  }

  @override
  Future<BusLocationModel?> getBusLocation(String busId) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/api/bus-location',
        queryParameters: {'bus': busId},
      );
      final data = response.data;
      if (data == null) {
        return null;
      }
      return BusLocationModel.fromJson(data);
    } on DioException catch (error) {
      if (error.response?.statusCode == 503) {
        return null;
      }
      rethrow;
    }
  }

  @override
  Future<EtaResultModel> getEta({
    required String busId,
    required double userLat,
    required double userLng,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/api/eta',
      queryParameters: {'bus': busId, 'userLat': userLat, 'userLng': userLng},
    );

    final data = response.data;
    if (data == null) {
      return EtaResultModel(
        busId: busId,
        status: 'error',
        message: 'No data returned from API',
      );
    }
    return EtaResultModel.fromJson(data);
  }
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
