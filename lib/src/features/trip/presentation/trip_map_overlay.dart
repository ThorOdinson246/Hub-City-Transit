import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/constants/route_metadata.dart';
import '../../../core/constants/transit_ids.dart';
import '../../../data/models/route_polyline_model.dart';
import '../../../domain/usecases/trip_planner.dart';
import '../application/active_trip.dart';

bool _finite(LatLng p) => p.latitude.isFinite && p.longitude.isFinite;

const Color _walkGrey = Color(0xFF64748B);

RouteId? _nextRideRoute(List<TripLeg> legs, int from) {
  for (var i = from + 1; i < legs.length; i++) {
    if (legs[i].kind == TripLegKind.ride) return RouteId.tryParse(legs[i].routeId);
  }
  return null;
}

/// Draws a planned trip: dashed for walking, the route's own colour for each
/// ride leg.
///
/// Ride legs are sliced from the full route polyline. On red and purple that
/// polyline circles the loop about three times, so a slice can pick the wrong
/// pass — see docs/DATA_RECONCILIATION_2026-08-20.md.
List<Polyline> tripPolylines({
  required PlannedTrip trip,
  required List<RoutePolylineModel> routes,
  Map<int, List<LatLng>> walkGeometry = const {},
}) {
  final result = <Polyline>[];

  for (var index = 0; index < trip.itinerary.legs.length; index++) {
    final leg = trip.itinerary.legs[index];
    switch (leg.kind) {
      case TripLegKind.walk:
        final from = leg.fromStop != null
            ? LatLng(leg.fromStop!.lat, leg.fromStop!.lng)
            : LatLng(trip.originLat, trip.originLng);
        final to = leg.toStop != null
            ? LatLng(leg.toStop!.lat, leg.toStop!.lng)
            : LatLng(trip.destLat, trip.destLng);
        result.add(Polyline(
          // Real pavement where Mapbox has answered, a straight line until then.
          points: walkGeometry[index] ?? [from, to],
          strokeWidth: 4,
          color: _walkGrey,
          pattern: const StrokePattern.dotted(spacingFactor: 2.2),
        ));

      case TripLegKind.transfer:
        if (leg.fromStop == null || leg.toStop == null) continue;
        // Dashed rather than dotted, in the colour of the route being joined, so
        // a connection reads differently from a walk to or from the street.
        final nextRoute = _nextRideRoute(trip.itinerary.legs, index);
        result.add(Polyline(
          points: [
            LatLng(leg.fromStop!.lat, leg.fromStop!.lng),
            LatLng(leg.toStop!.lat, leg.toStop!.lng),
          ],
          strokeWidth: 5,
          color: nextRoute == null ? _walkGrey : routeColors[nextRoute]!,
          pattern: StrokePattern.dashed(segments: const [10, 7]),
        ));

      case TripLegKind.ride:
        final routeId = RouteId.tryParse(leg.routeId);
        if (routeId == null || leg.fromStop == null || leg.toStop == null) {
          continue;
        }
        final model = routes
            .where((r) => RouteId.tryParse(r.routeId) == routeId)
            .firstOrNull;
        final board = LatLng(leg.fromStop!.lat, leg.fromStop!.lng);
        final alight = LatLng(leg.toStop!.lat, leg.toStop!.lng);
        final points = model == null
            ? <LatLng>[board, alight]
            : sliceRoute(model.polyline, board, alight);
        result.add(Polyline(
          points: points,
          strokeWidth: 6,
          color: routeColors[routeId]!,
        ));
    }
  }

  // flutter_map throws on a non-finite LatLng, which takes out the whole map
  // rather than one line.
  return result
      .map((line) => Polyline(
            points: line.points.where(_finite).toList(growable: false),
            strokeWidth: line.strokeWidth,
            color: line.color,
            pattern: line.pattern,
          ))
      .where((line) => line.points.length >= 2)
      .toList(growable: false);
}

List<Marker> tripMarkers({required PlannedTrip trip}) {
  final markers = <Marker>[];

  for (final leg in trip.itinerary.legs) {
    if (leg.kind != TripLegKind.ride) continue;
    final routeId = RouteId.tryParse(leg.routeId);
    final color = routeId == null ? const Color(0xFF1976D2) : routeColors[routeId]!;
    if (leg.fromStop case final board?) {
      markers.add(_pin(
        LatLng(board.lat, board.lng),
        color,
        Icons.directions_bus_rounded,
        'Board at ${board.name}',
      ));
    }
  }

  markers.add(_pin(
    LatLng(trip.destLat, trip.destLng),
    const Color(0xFF16A34A),
    Icons.flag_rounded,
    trip.destLabel ?? 'Destination',
  ));

  return markers.where((m) => _finite(m.point)).toList(growable: false);
}

Marker _pin(LatLng point, Color color, IconData icon, String label) {
  return Marker(
    point: point,
    width: 34,
    height: 34,
    child: Semantics(
      label: label,
      child: Container(
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
        ),
        child: Icon(icon, size: 18, color: Colors.white),
      ),
    ),
  );
}

/// The stretch of [polyline] between the two stops, wrapping past the end for a
/// loop route.
List<LatLng> sliceRoute(
  List<List<double>> polyline,
  LatLng start,
  LatLng end,
) {
  final points = <LatLng>[];
  for (final p in polyline) {
    if (p.length == 2) points.add(LatLng(p[0], p[1]));
  }
  if (points.length < 2) return [start, end];

  final startIdx = _nearestIndex(points, start);
  final endIdx = _nearestIndex(points, end);
  if (startIdx == endIdx) return [start, end];

  final slice = startIdx < endIdx
      ? points.sublist(startIdx, endIdx + 1)
      : [...points.sublist(startIdx), ...points.sublist(0, endIdx + 1)];

  return slice.length < 2 ? [start, end] : slice;
}

int _nearestIndex(List<LatLng> points, LatLng target) {
  var best = 0;
  var bestDistance = double.infinity;
  for (var i = 0; i < points.length; i++) {
    final d = _squaredDegrees(points[i], target);
    if (d < bestDistance) {
      bestDistance = d;
      best = i;
    }
  }
  return best;
}

/// Squared degree distance. Only used for ranking candidates, so the cost of a
/// real haversine buys nothing here.
double _squaredDegrees(LatLng a, LatLng b) {
  final dLat = a.latitude - b.latitude;
  final dLng = (a.longitude - b.longitude) * math.cos(a.latitude * math.pi / 180);
  return dLat * dLat + dLng * dLng;
}
