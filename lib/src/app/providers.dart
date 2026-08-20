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

/// Pauses work while the app is not in the foreground.
///
/// Without this the poll ran at its full rate in the background on Android:
/// 1,200 requests per hour per device against a public ArcGIS feature service,
/// for a map nobody was looking at.
class _ForegroundGate {
  _ForegroundGate() {
    _listener = AppLifecycleListener(
      onResume: _resume,
      onPause: _suspend,
      onHide: _suspend,
    );
  }

  late final AppLifecycleListener _listener;
  Completer<void>? _resumed;
  var _disposed = false;

  bool get _isForeground {
    final state = WidgetsBinding.instance.lifecycleState;
    // Null before the first lifecycle event — treat as foreground so the very
    // first poll is not delayed on a cold start.
    return state == null || state == AppLifecycleState.resumed;
  }

  Future<void> whenForeground() {
    if (_disposed || _isForeground) return Future<void>.value();
    return (_resumed ??= Completer<void>()).future;
  }

  void _suspend() {
    _resumed ??= Completer<void>();
  }

  void _resume() {
    _resumed?.complete();
    _resumed = null;
  }

  void dispose() {
    _disposed = true;
    _resume();
    _listener.dispose();
  }
}

/// Backs off after repeated failures so a struggling upstream is not hammered
/// at 20 requests a minute per device. Caps at a minute.
Duration _pollBackoff(int consecutiveFailures) {
  if (consecutiveFailures <= 0) return busRefreshInterval;
  final seconds = busRefreshInterval.inSeconds * (1 << (consecutiveFailures - 1));
  return Duration(seconds: seconds.clamp(1, 60));
}

/// Latest known bus position, polled while the app is in the foreground.
///
/// Three properties the previous implementation lacked:
///
///  * **A failed poll no longer ends the stream.** `getBusLocation` throws on
///    most transport errors, and an exception inside an `async*` generator
///    terminates it permanently. Riding through one dead-cell pocket used to
///    leave the app reading "offline" until it was restarted.
///  * **The last known position survives a failure**, so the marker stays on
///    the map instead of vanishing on a single dropped request. It still ages
///    out via `busStaleThreshold`, so a long outage correctly reads as offline.
///  * **Polling pauses when the app is backgrounded.**
///
/// Deliberately not `autoDispose`: `MapPage` is kept alive by
/// `StatefulShellRoute`'s `IndexedStack` and never stops watching, so it would
/// never fire. Lifecycle gating is what actually stops the requests.
final busLocationPollingProvider = StreamProvider<BusLocationModel?>((ref) async* {
  final repository = ref.watch(transitRepositoryProvider);
  final busId = ref.watch(selectedBusProvider).value;

  final gate = _ForegroundGate();
  ref.onDispose(gate.dispose);

  BusLocationModel? lastKnown;
  var consecutiveFailures = 0;

  while (true) {
    await gate.whenForeground();

    try {
      final location = await repository.getBusLocation(busId);
      consecutiveFailures = 0;
      if (location != null) lastKnown = location;
      yield location ?? lastKnown;
    } on Object {
      // Transport failure, bad payload, unconfigured endpoint. Keep the last
      // fix on screen and try again rather than killing the stream.
      consecutiveFailures++;
      yield lastKnown;
    }

    await Future<void>.delayed(_pollBackoff(consecutiveFailures));
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
const String onboardingSeenKey = 'onboarding_seen';

/// Whether onboarding has been completed, readable synchronously.
///
/// The router's redirect runs before any frame and cannot await, so this is
/// seeded in `main()` from [readOnboardingSeen] and overridden into the scope.
/// Defaults to `true` so a failure to read never traps someone in onboarding
/// with no way forward — on web the backing store is localStorage, which throws
/// outright when site data is blocked.
final onboardingSeenProvider = StateProvider<bool>((ref) => true);

Future<bool> readOnboardingSeen() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(onboardingSeenKey) ?? false;
  } catch (_) {
    return true;
  }
}

Future<void> markOnboardingSeen() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(onboardingSeenKey, true);
  } catch (_) {
    // Non-fatal: the in-memory flag still advances, so the session completes.
  }
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
