import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/constants/route_metadata.dart';
import '../../../core/constants/transit_ids.dart';
import '../../../data/models/route_polyline_model.dart';
import '../../../domain/usecases/trip_planner.dart';
import '../application/active_trip.dart';
import '../application/trip_planner_providers.dart';
import 'trip_map_overlay.dart';

/// Draws the planned trip, using real Mapbox walking geometry where it has been
/// fetched and a straight line until then.
class TripPolylineLayer extends ConsumerWidget {
  const TripPolylineLayer({
    required this.trip,
    required this.routes,
    super.key,
  });

  final PlannedTrip trip;
  final List<RoutePolylineModel> routes;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final walkGeometry = <int, List<LatLng>>{};

    for (var i = 0; i < trip.itinerary.legs.length; i++) {
      final leg = trip.itinerary.legs[i];
      if (leg.kind != TripLegKind.walk) continue;

      final from = leg.fromStop != null
          ? (lat: leg.fromStop!.lat, lng: leg.fromStop!.lng)
          : (lat: trip.originLat, lng: trip.originLng);
      final to = leg.toStop != null
          ? (lat: leg.toStop!.lat, lng: leg.toStop!.lng)
          : (lat: trip.destLat, lng: trip.destLng);

      final route = ref
          .watch(walkingRouteProvider(WalkLeg(
            fromLat: from.lat,
            fromLng: from.lng,
            toLat: to.lat,
            toLng: to.lng,
          )))
          .valueOrNull;

      if (route != null && route.geometry.length >= 2) {
        walkGeometry[i] = route.geometry
            .map((p) => LatLng(p.lat, p.lng))
            .toList(growable: false);
      }
    }

    return PolylineLayer(
      polylines: tripPolylines(
        trip: trip,
        routes: routes,
        walkGeometry: walkGeometry,
      ),
    );
  }
}

/// Board pins numbered in ride order, so a two-route trip reads left to right.
class TripMarkerLayer extends StatelessWidget {
  const TripMarkerLayer({required this.trip, super.key});

  final PlannedTrip trip;

  @override
  Widget build(BuildContext context) {
    final markers = <Marker>[];
    var boardNumber = 0;

    for (final leg in trip.itinerary.legs) {
      if (leg.kind != TripLegKind.ride || leg.fromStop == null) continue;
      boardNumber++;
      final routeId = RouteId.tryParse(leg.routeId);
      markers.add(_pin(
        point: LatLng(leg.fromStop!.lat, leg.fromStop!.lng),
        color: routeId == null
            ? Theme.of(context).colorScheme.primary
            : routeColor(routeId),
        foreground: routeId == null ? Colors.white : onRouteColor(routeId),
        label: 'Board $boardNumber at ${leg.fromStop!.name}',
        text: '$boardNumber',
      ));
    }

    markers.add(_pin(
      point: LatLng(trip.destLat, trip.destLng),
      color: const Color(0xFF16A34A),
      foreground: Colors.white,
      label: trip.destLabel ?? 'Destination',
      icon: Icons.flag_rounded,
    ));

    return MarkerLayer(
      markers: markers
          .where((m) => m.point.latitude.isFinite && m.point.longitude.isFinite)
          .toList(growable: false),
    );
  }

  /// Anchored at the tip, not the centre — a pin whose point floats above the
  /// place it marks reads as pointing at the wrong thing.
  Marker _pin({
    required LatLng point,
    required Color color,
    required Color foreground,
    required String label,
    String? text,
    IconData? icon,
  }) {
    return Marker(
      point: point,
      width: 34,
      height: 44,
      alignment: Alignment.topCenter,
      child: Semantics(
        label: label,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
                boxShadow: const [
                  BoxShadow(color: Colors.black38, blurRadius: 4),
                ],
              ),
              alignment: Alignment.center,
              child: icon != null
                  ? Icon(icon, size: 16, color: foreground)
                  : Text(
                      text ?? '',
                      style: TextStyle(
                        color: foreground,
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                        height: 1,
                      ),
                    ),
            ),
            CustomPaint(
              size: const Size(10, 8),
              painter: _PinTip(color: color),
            ),
          ],
        ),
      ),
    );
  }
}

class _PinTip extends CustomPainter {
  const _PinTip({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    // latlong2 exports a generic Path<T> that shadows dart:ui's.
    final path = ui.Path()
      ..moveTo(0, 0)
      ..lineTo(size.width / 2, size.height)
      ..lineTo(size.width, 0)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_PinTip oldDelegate) => oldDelegate.color != color;
}
