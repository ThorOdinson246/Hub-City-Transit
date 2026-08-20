import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/usecases/trip_planner.dart';

/// An itinerary the rider chose to see drawn on the map.
class PlannedTrip {
  const PlannedTrip({
    required this.itinerary,
    required this.originLat,
    required this.originLng,
    required this.destLat,
    required this.destLng,
    this.originLabel,
    this.destLabel,
  });

  final TripItinerary itinerary;
  final double originLat;
  final double originLng;
  final double destLat;
  final double destLng;
  final String? originLabel;
  final String? destLabel;
}

/// Set when "Show on map" is tapped in the planner, cleared when the rider
/// dismisses the trip card or taps a stop. Lives above both tabs because the
/// planner writes it and the map reads it.
final activeTripProvider = StateProvider<PlannedTrip?>((ref) => null);
