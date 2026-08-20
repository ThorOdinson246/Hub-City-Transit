import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/directions/mapbox_walking_directions.dart';
import '../../../core/directions/walking_directions.dart';
import '../../../core/network/dio_provider.dart';
import '../../../data/models/transit_dataset.dart';
import '../../../data/repositories/transit_dataset_repository.dart';
import '../../../data/services/nominatim_service.dart';
import '../../../domain/usecases/trip_planner.dart';

final transitDatasetRepositoryProvider =
    Provider<TransitDatasetRepository>((ref) => TransitDatasetRepository());

final transitDatasetProvider = FutureProvider<TransitDataset>((ref) {
  return ref.watch(transitDatasetRepositoryProvider).load();
});

final walkingDirectionsProvider = Provider<WalkingDirectionsService>((ref) {
  if (mapboxToken.isEmpty) return const EstimatedWalkingDirections();
  return MapboxWalkingDirections(
    dio: ref.watch(dioProvider),
    accessToken: mapboxToken,
  );
});

final tripPlannerProvider = Provider<TripPlanner>((ref) => TripPlanner());

/// One shared instance, so both trip fields queue behind the same client rather
/// than each holding its own Dio the way the map search does.
final nominatimServiceProvider =
    Provider<NominatimService>((ref) => NominatimService());

final placeSearchProvider =
    FutureProvider.autoDispose.family<List<NominatimPlace>, String>((ref, query) {
  if (query.trim().length < 3) return Future.value(const <NominatimPlace>[]);
  return ref.watch(nominatimServiceProvider).search(query);
});

class TripQuery {
  const TripQuery({
    required this.originLat,
    required this.originLng,
    required this.destLat,
    required this.destLng,
    required this.when,
    this.arriveBy = false,
    this.originLabel,
    this.destLabel,
  });

  final double originLat;
  final double originLng;
  final double destLat;
  final double destLng;
  final DateTime when;
  final bool arriveBy;
  final String? originLabel;
  final String? destLabel;

  @override
  bool operator ==(Object other) =>
      other is TripQuery &&
      other.originLat == originLat &&
      other.originLng == originLng &&
      other.destLat == destLat &&
      other.destLng == destLng &&
      other.when == when &&
      other.arriveBy == arriveBy;

  @override
  int get hashCode =>
      Object.hash(originLat, originLng, destLat, destLng, when, arriveBy);
}

/// Runs the planner for a query. Search uses free straight-line estimates
/// throughout; real walking directions are fetched separately, and only for the
/// legs of an itinerary the user is actually looking at.
final tripPlanProvider =
    FutureProvider.autoDispose.family<TripPlanResult, TripQuery>((ref, query) async {
  final dataset = await ref.watch(transitDatasetProvider.future);
  return ref.watch(tripPlannerProvider).plan(
        dataset: dataset,
        originLat: query.originLat,
        originLng: query.originLng,
        destLat: query.destLat,
        destLng: query.destLng,
        when: query.when,
        arriveBy: query.arriveBy,
      );
});

/// The two endpoints of a walk leg, as a cache key for [walkingRouteProvider].
class WalkLeg {
  const WalkLeg({
    required this.fromLat,
    required this.fromLng,
    required this.toLat,
    required this.toLng,
  });

  final double fromLat;
  final double fromLng;
  final double toLat;
  final double toLng;

  @override
  bool operator ==(Object other) =>
      other is WalkLeg &&
      other.fromLat == fromLat &&
      other.fromLng == fromLng &&
      other.toLat == toLat &&
      other.toLng == toLng;

  @override
  int get hashCode => Object.hash(fromLat, fromLng, toLat, toLng);
}

final walkingRouteProvider =
    FutureProvider.autoDispose.family<WalkingRoute, WalkLeg>((ref, leg) {
  return ref.watch(walkingDirectionsProvider).route(
        fromLat: leg.fromLat,
        fromLng: leg.fromLng,
        toLat: leg.toLat,
        toLng: leg.toLng,
      );
});
