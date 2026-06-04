import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';


import '../core/constants/app_constants.dart';
import '../core/constants/transit_ids.dart';

import '../core/network/dio_provider.dart';
import '../data/models/bus_location_model.dart';
import '../data/models/route_polyline_model.dart';
import '../data/models/route_schedule_model.dart';
import '../data/models/stop_model.dart';
import '../data/repositories/transit_repository_impl.dart';
import '../domain/repositories/transit_repository.dart';
import '../domain/usecases/schedule_adjustment_use_case.dart';

// ─── Location & Sensors ───────────────────────────────────────────────────────
final compassProvider = StreamProvider<CompassEvent>((ref) {
  if (kIsWeb) return const Stream.empty();
  return FlutterCompass.events ?? const Stream.empty();
});

// ─── Route / bus selection ────────────────────────────────────────────────────
final selectedRouteProvider = StateProvider<RouteId>((ref) => RouteId.blue);
final selectedBusProvider = StateProvider<BusId>((ref) => BusId.blue1);

// ─── Repository ───────────────────────────────────────────────────────────────
final transitRepositoryProvider = Provider<TransitRepository>((ref) {
  final dio = ref.watch(dioProvider);
  return TransitRepositoryImpl(dio);
});

// ─── Data providers ──────────────────────────────────────────────────────────
final routesProvider = FutureProvider<List<RoutePolylineModel>>((ref) async {
  final repository = ref.watch(transitRepositoryProvider);
  return repository.getRoutes();
});

final stopsBySelectedRouteProvider = FutureProvider<List<StopModel>>((ref) async {
  final repository = ref.watch(transitRepositoryProvider);
  final route = ref.watch(selectedRouteProvider);
  return repository.getStops(routeId: route.value);
});

final allStopsByRouteProvider =
    FutureProvider<Map<RouteId, List<StopModel>>>((ref) async {
  final repository = ref.watch(transitRepositoryProvider);
  final entries = await Future.wait(
    RouteId.values.map((route) async {
      final stops = await repository.getStops(routeId: route.value);
      return MapEntry(route, stops);
    }),
  );
  return Map<RouteId, List<StopModel>>.fromEntries(entries);
});

final selectedRouteScheduleProvider =
    FutureProvider<RouteScheduleModel?>((ref) async {
  final repository = ref.watch(transitRepositoryProvider);
  final route = ref.watch(selectedRouteProvider);
  return repository.getSchedule(route.value);
});

// ─── Bus location polling ─────────────────────────────────────────────────────
final busLocationPollingProvider = StreamProvider<BusLocationModel?>((ref) async* {
  final repository = ref.watch(transitRepositoryProvider);
  final busId = ref.watch(selectedBusProvider).value;

  yield await repository.getBusLocation(busId);

  while (true) {
    await Future<void>.delayed(busRefreshInterval);
    yield await repository.getBusLocation(busId);
  }
});

// ─── Bus status ───────────────────────────────────────────────────────────────
final busStatusProvider = Provider<BusStatus>((ref) {
  final busAsync = ref.watch(busLocationPollingProvider);
  return deriveBusStatus(
    latest: busAsync.asData?.value,
    isLoading: busAsync.isLoading,
    now: DateTime.now(),
  );
});

// ─── Schedule adjustment ──────────────────────────────────────────────────────
final selectedRouteAdjustmentProvider = Provider<AdjustmentResult?>((ref) {
  final schedule = ref.watch(selectedRouteScheduleProvider).asData?.value;
  final gpsStops = ref.watch(stopsBySelectedRouteProvider).asData?.value;
  final busLocation = ref.watch(busLocationPollingProvider).asData?.value;

  if (schedule == null || gpsStops == null || gpsStops.isEmpty) {
    return null;
  }

  const useCase = ScheduleAdjustmentUseCase();
  return useCase.adjust(
    schedule: RouteSchedule(stops: schedule.stops, trips: schedule.trips),
    gpsStops: gpsStops,
    busLocation: busLocation,
    now: DateTime.now(),
  );
});

// ─── User location — stream-based ────────────────────────────────────────────
/// Emits the latest user [Position] via Geolocator's position stream.
/// Returns null until permission is granted or if services are disabled.
final userLocationProvider = StreamProvider<Position?>((ref) async* {
  // Check permission state first — don't request here (handled by UI)
  final permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied ||
      permission == LocationPermission.deniedForever) {
    yield null;
    return;
  }

  final serviceEnabled = await Geolocator.isLocationServiceEnabled();
  if (!serviceEnabled) {
    yield null;
    return;
  }

  // get current position immediately so the map doesn't start at [0,0]
  try {
    final current = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 10),
      ),
    );
    yield current;
  } catch (_) {
    yield null;
  }

  yield* Geolocator.getPositionStream(
    locationSettings: const LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 5, // meters — don't spam on tiny jitters
    ),
  ).handleError((_) {});
});

// ─── Theme mode ───────────────────────────────────────────────────────────────
class ThemeModeController extends StateNotifier<ThemeMode> {
  ThemeModeController() : super(ThemeMode.system) {
    _load();
  }

  static const _key = 'theme_mode';

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(_key);
    switch (value) {
      case 'light':
        state = ThemeMode.light;
        break;
      case 'dark':
        state = ThemeMode.dark;
        break;
      default:
        state = ThemeMode.system;
    }
  }

  Future<void> setMode(ThemeMode mode) async {
    state = mode;
    final prefs = await SharedPreferences.getInstance();
    final raw = switch (mode) {
      ThemeMode.light => 'light',
      ThemeMode.dark => 'dark',
      ThemeMode.system => 'system',
    };
    await prefs.setString(_key, raw);
  }
}

final themeModeProvider =
    StateNotifierProvider<ThemeModeController, ThemeMode>(
  (ref) => ThemeModeController(),
);

// ─── Dark basemap toggle ──────────────────────────────────────────────────────
class DarkBasemapController extends StateNotifier<bool> {
  DarkBasemapController() : super(true) {
    _load();
  }
  static const _key = 'dark_basemap';

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getBool(_key) ?? true; // on by default
  }

  Future<void> toggle(bool value) async {
    state = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, value);
  }
}

final darkBasemapProvider =
    StateNotifierProvider<DarkBasemapController, bool>(
  (ref) => DarkBasemapController(),
);

// ─── Onboarding seen flag ─────────────────────────────────────────────────────
final onboardingSeenProvider = FutureProvider<bool>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool('onboarding_seen') ?? false;
});

Future<void> markOnboardingSeen() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool('onboarding_seen', true);
}

// ─── BusStatus helpers (keep in sync with existing use case) ──────────────────
enum BusStatus { live, connecting, offline }

BusStatus deriveBusStatus({
  required BusLocationModel? latest,
  required bool isLoading,
  required DateTime now,
}) {
  if (isLoading && latest == null) return BusStatus.connecting;
  if (latest == null) return BusStatus.offline;
  final age = now.difference(latest.lastSeen);
  if (age > busStaleThreshold) return BusStatus.offline;
  return BusStatus.live;
}

// ─── Favorite Stops ───────────────────────────────────────────────────────────
class FavoritesNotifier extends StateNotifier<List<String>> {
  FavoritesNotifier() : super([]) {
    _load();
  }

  static const _key = 'favorite_stops';

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getStringList(_key) ?? [];
  }

  Future<void> toggleFavorite(String stopId) async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> current = List.from(state);
    if (current.contains(stopId)) {
      current.remove(stopId);
    } else {
      current.add(stopId);
    }
    state = current;
    await prefs.setStringList(_key, current);
  }
}

final favoritesProvider = StateNotifierProvider<FavoritesNotifier, List<String>>((ref) {
  return FavoritesNotifier();
});
