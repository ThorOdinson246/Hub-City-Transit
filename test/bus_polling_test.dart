import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hubcity_transit_flutter/src/app/providers.dart';
import 'package:hubcity_transit_flutter/src/data/models/bus_location_model.dart';
import 'package:hubcity_transit_flutter/src/data/models/route_polyline_model.dart';
import 'package:hubcity_transit_flutter/src/data/models/route_schedule_model.dart';
import 'package:hubcity_transit_flutter/src/data/models/stop_model.dart';
import 'package:hubcity_transit_flutter/src/domain/repositories/transit_repository.dart';

/// Returns a scripted sequence of results, throwing where the script says to.
class _ScriptedRepository implements TransitRepository {
  _ScriptedRepository(this._script);

  final List<Object?> _script;
  int calls = 0;

  @override
  Future<BusLocationModel?> getBusLocation(String busId) async {
    final step = _script[calls.clamp(0, _script.length - 1)];
    calls++;
    if (step is Exception) throw step;
    return step as BusLocationModel?;
  }

  @override
  Future<List<RoutePolylineModel>> getRoutes() async => const [];

  @override
  Future<List<StopModel>> getStops({String? routeId}) async => const [];

  @override
  Future<RouteScheduleModel?> getSchedule(String routeId) async => null;
}

BusLocationModel _location(String id, DateTime seen) => BusLocationModel(
      lat: 31.32,
      lng: -89.29,
      busId: id,
      lastSeen: seen,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('a failed poll does not terminate the stream', () async {
    // The regression: getBusLocation throws, the exception escapes the async*
    // generator, and live tracking is dead until the app restarts.
    final seen = DateTime.now();
    final repository = _ScriptedRepository([
      _location('blue1', seen),
      Exception('network down'),
      _location('blue1', seen),
    ]);

    final container = ProviderContainer(
      overrides: [transitRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);

    final emitted = <BusLocationModel?>[];
    final subscription = container.listen(
      busLocationPollingProvider,
      (_, next) {
        if (next.hasValue) emitted.add(next.value);
      },
      fireImmediately: true,
    );
    addTearDown(subscription.close);

    // Long enough to cover the first poll, the failure, and the backed-off retry.
    await Future<void>.delayed(const Duration(seconds: 10));

    expect(
      repository.calls,
      greaterThanOrEqualTo(3),
      reason: 'the loop must keep polling after a failure',
    );
    expect(
      container.read(busLocationPollingProvider).hasError,
      isFalse,
      reason: 'a transport failure must not surface as a dead stream',
    );
  }, timeout: const Timeout(Duration(seconds: 30)));

  test('the last known position survives a failed poll', () async {
    final seen = DateTime.now();
    final repository = _ScriptedRepository([
      _location('blue1', seen),
      Exception('network down'),
    ]);

    final container = ProviderContainer(
      overrides: [transitRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);

    final subscription = container.listen(
      busLocationPollingProvider,
      (_, _) {},
      fireImmediately: true,
    );
    addTearDown(subscription.close);

    await Future<void>.delayed(const Duration(seconds: 8));

    // Without retention the marker disappears from the map on one dropped
    // request, while the info panel still claims to show a last known position.
    expect(container.read(busLocationPollingProvider).value, isNotNull);
    expect(container.read(busLocationPollingProvider).value?.busId, 'blue1');
  }, timeout: const Timeout(Duration(seconds: 30)));

  group('deriveBusStatus', () {
    test('a retained position still ages out to offline', () {
      final now = DateTime.now();
      final stale = _location('blue1', now.subtract(const Duration(minutes: 5)));

      expect(
        deriveBusStatus(latest: stale, isLoading: false, now: now),
        BusStatus.offline,
        reason: 'retaining the last fix must not fake liveness',
      );
    });

    test('a fresh position reads as live', () {
      final now = DateTime.now();
      expect(
        deriveBusStatus(
          latest: _location('blue1', now),
          isLoading: false,
          now: now,
        ),
        BusStatus.live,
      );
    });
  });
}
