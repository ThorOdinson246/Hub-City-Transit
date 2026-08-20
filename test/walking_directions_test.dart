import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hubcity_transit_flutter/src/core/directions/mapbox_walking_directions.dart';
import 'package:hubcity_transit_flutter/src/core/directions/walking_directions.dart';

const _hardyAnd34th = (lat: 31.32926, lng: -89.32570);
const _walmart49 = (lat: 31.3080327, lng: -89.3194348);

class _StubAdapter implements HttpClientAdapter {
  _StubAdapter(this.body, {this.status = 200});

  final String body;
  final int status;
  int calls = 0;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    calls++;
    if (status >= 400) {
      throw DioException.badResponse(
        statusCode: status,
        requestOptions: options,
        response: Response<dynamic>(requestOptions: options, statusCode: status),
      );
    }
    return ResponseBody.fromString(body, status, headers: <String, List<String>>{
      Headers.contentTypeHeader: <String>[Headers.jsonContentType],
    });
  }
}

String _mapboxResponse() => jsonEncode({
      'routes': [
        {
          'distance': 340.2,
          'duration': 254.0,
          'geometry': {
            'coordinates': [
              [-89.32570, 31.32926],
              [-89.32500, 31.32800],
              [-89.31943, 31.30803],
            ],
          },
          'legs': [
            {
              'steps': [
                {
                  'distance': 120.0,
                  'duration': 90.0,
                  'maneuver': {'instruction': 'Head south on S 34th Ave'},
                },
                {
                  'distance': 220.2,
                  'duration': 164.0,
                  'maneuver': {'instruction': 'Turn left onto Hardy St'},
                },
              ],
            },
          ],
        },
      ],
    });

Dio _dioWith(HttpClientAdapter adapter) => Dio()..httpClientAdapter = adapter;

void main() {
  group('estimate', () {
    test('applies the detour factor rather than reporting a straight line', () {
      final route = EstimatedWalkingDirections.estimate(
        fromLat: _hardyAnd34th.lat,
        fromLng: _hardyAnd34th.lng,
        toLat: _walmart49.lat,
        toLng: _walmart49.lng,
      );

      expect(route.isEstimate, isTrue);
      expect(route.steps, isEmpty);
      expect(route.geometry, isEmpty);
      expect(route.distanceMetres, greaterThan(2000));
    });

    test('never rounds a real walk down to zero minutes', () {
      final route = EstimatedWalkingDirections.estimate(
        fromLat: 31.32926,
        fromLng: -89.32570,
        toLat: 31.32930,
        toLng: -89.32572,
      );

      expect(route.durationMinutes, greaterThanOrEqualTo(1));
    });
  });

  group('mapbox', () {
    test('parses distance, duration, geometry and turn list', () async {
      final service = MapboxWalkingDirections(
        dio: _dioWith(_StubAdapter(_mapboxResponse())),
        accessToken: 'pk.test',
      );

      final route = await service.route(
        fromLat: _hardyAnd34th.lat,
        fromLng: _hardyAnd34th.lng,
        toLat: _walmart49.lat,
        toLng: _walmart49.lng,
      );

      expect(route.isEstimate, isFalse);
      expect(route.distanceMetres, closeTo(340.2, 0.01));
      expect(route.durationMinutes, 5);
      expect(route.geometry, hasLength(3));
      expect(route.steps.map((s) => s.instruction),
          containsAll(<String>['Head south on S 34th Ave', 'Turn left onto Hardy St']));
    });

    test('caches by rounded coordinates so a reopened plan costs nothing', () async {
      final adapter = _StubAdapter(_mapboxResponse());
      final service =
          MapboxWalkingDirections(dio: _dioWith(adapter), accessToken: 'pk.test');

      for (var i = 0; i < 3; i++) {
        await service.route(
          fromLat: _hardyAnd34th.lat,
          fromLng: _hardyAnd34th.lng,
          toLat: _walmart49.lat,
          toLng: _walmart49.lng,
        );
      }

      expect(adapter.calls, 1, reason: 'repeat legs must not re-bill');
    });

    test('falls back to an estimate when the request fails', () async {
      final service = MapboxWalkingDirections(
        dio: _dioWith(_StubAdapter('', status: 429)),
        accessToken: 'pk.test',
      );

      final route = await service.route(
        fromLat: _hardyAnd34th.lat,
        fromLng: _hardyAnd34th.lng,
        toLat: _walmart49.lat,
        toLng: _walmart49.lng,
      );

      expect(route.isEstimate, isTrue);
      expect(route.distanceMetres, greaterThan(0));
    });

    test('makes no request at all without a token', () async {
      final adapter = _StubAdapter(_mapboxResponse());
      final service =
          MapboxWalkingDirections(dio: _dioWith(adapter), accessToken: '');

      final route = await service.route(
        fromLat: _hardyAnd34th.lat,
        fromLng: _hardyAnd34th.lng,
        toLat: _walmart49.lat,
        toLng: _walmart49.lng,
      );

      expect(adapter.calls, 0);
      expect(route.isEstimate, isTrue);
      expect(service.isConfigured, isFalse);
    });

    test('malformed payloads degrade instead of throwing', () async {
      final service = MapboxWalkingDirections(
        dio: _dioWith(_StubAdapter(jsonEncode({'routes': []}))),
        accessToken: 'pk.test',
      );

      final route = await service.route(
        fromLat: _hardyAnd34th.lat,
        fromLng: _hardyAnd34th.lng,
        toLat: _walmart49.lat,
        toLng: _walmart49.lng,
      );

      expect(route.isEstimate, isTrue);
    });
  });
}
