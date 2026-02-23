import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants/app_constants.dart';
import '../core/constants/transit_ids.dart';
import '../core/network/dio_provider.dart';
import '../data/models/bus_location_model.dart';
import '../data/models/route_polyline_model.dart';
import '../data/models/stop_model.dart';
import '../data/repositories/transit_repository_impl.dart';
import '../domain/repositories/transit_repository.dart';
import '../domain/usecases/schedule_adjustment_use_case.dart';

final selectedRouteProvider = StateProvider<RouteId>((ref) => RouteId.blue);
final selectedBusProvider = StateProvider<BusId>((ref) => BusId.blue1);

final transitRepositoryProvider = Provider<TransitRepository>((ref) {
  final dio = ref.watch(dioProvider);
  return TransitRepositoryImpl(dio);
});

final routesProvider = FutureProvider<List<RoutePolylineModel>>((ref) async {
  final repository = ref.watch(transitRepositoryProvider);
  return repository.getRoutes();
});

final stopsBySelectedRouteProvider = FutureProvider<List<StopModel>>((
  ref,
) async {
  final repository = ref.watch(transitRepositoryProvider);
  final route = ref.watch(selectedRouteProvider);
  return repository.getStops(routeId: route.value);
});

final allStopsByRouteProvider = FutureProvider<Map<RouteId, List<StopModel>>>(
  (ref) async {
    final repository = ref.watch(transitRepositoryProvider);
    final entries = await Future.wait(
      RouteId.values.map((route) async {
        final stops = await repository.getStops(routeId: route.value);
        return MapEntry(route, stops);
      }),
    );
    return Map<RouteId, List<StopModel>>.fromEntries(entries);
  },
);

final busLocationPollingProvider = StreamProvider<BusLocationModel?>((
  ref,
) async* {
  final repository = ref.watch(transitRepositoryProvider);
  final busId = ref.watch(selectedBusProvider).value;

  yield await repository.getBusLocation(busId);

  while (true) {
    await Future<void>.delayed(busRefreshInterval);
    yield await repository.getBusLocation(busId);
  }
});

final busStatusProvider = Provider<BusStatus>((ref) {
  final busAsync = ref.watch(busLocationPollingProvider);
  return deriveBusStatus(
    latest: busAsync.asData?.value,
    isLoading: busAsync.isLoading,
    now: DateTime.now(),
  );
});
