import 'package:flutter_test/flutter_test.dart';
import 'package:hubcity_transit_flutter/src/data/models/bus_location_model.dart';
import 'package:hubcity_transit_flutter/src/data/models/stop_model.dart';
import 'package:hubcity_transit_flutter/src/domain/usecases/schedule_adjustment_use_case.dart';

void main() {
  group('ScheduleAdjustmentUseCase', () {
    const useCase = ScheduleAdjustmentUseCase();

    final schedule = RouteSchedule(
      stops: const ['A', 'B', 'C'],
      trips: const [
        ['8:00 AM', '8:10 AM', '8:20 AM'],
        ['8:30 AM', '8:40 AM', '8:50 AM'],
      ],
    );

    final gpsStops = [
      const StopModel(
        stopId: 1,
        location: 'A',
        lat: 31.0,
        lng: -89.0,
        direction: 'Outbound',
      ),
      const StopModel(
        stopId: 2,
        location: 'B',
        lat: 31.001,
        lng: -89.001,
        direction: 'Outbound',
      ),
      const StopModel(
        stopId: 3,
        location: 'C',
        lat: 31.002,
        lng: -89.002,
        direction: 'Outbound',
      ),
    ];

    test('uses GPS-aware trip selection for multi-trip schedule', () {
      final now = DateTime.utc(2026, 1, 1, 8, 41);
      final bus = BusLocationModel(
        lat: 31.001,
        lng: -89.001,
        busId: 'blue1',
        lastSeen: now,
      );

      final result = useCase.adjust(
        schedule: schedule,
        gpsStops: gpsStops,
        busLocation: bus,
        now: now,
      );

      expect(result.tripIndex, 1);
      expect(result.isLiveAdjusted, isTrue);
      expect(result.appliedDelta, closeTo(0.85, 0.001));
    });

    test('does not apply live delta when offset exceeds threshold', () {
      final now = DateTime.utc(2026, 1, 1, 9, 30);
      final bus = BusLocationModel(
        lat: 31.001,
        lng: -89.001,
        busId: 'blue1',
        lastSeen: now,
      );

      final result = useCase.adjust(
        schedule: schedule,
        gpsStops: gpsStops,
        busLocation: bus,
        now: now,
      );

      expect(result.isLiveAdjusted, isFalse);
      expect(result.appliedDelta, 0);
    });
  });

  group('deriveBusStatus', () {
    test('returns connecting when loading without data', () {
      final status = deriveBusStatus(
        latest: null,
        isLoading: true,
        now: DateTime.utc(2026, 1, 1, 12),
      );

      expect(status, BusStatus.connecting);
    });

    test('returns offline when data is stale', () {
      final now = DateTime.utc(2026, 1, 1, 12);
      final status = deriveBusStatus(
        latest: BusLocationModel(
          lat: 31,
          lng: -89,
          busId: 'blue1',
          lastSeen: now.subtract(const Duration(minutes: 2)),
        ),
        isLoading: false,
        now: now,
      );

      expect(status, BusStatus.offline);
    });

    test('returns live when data is fresh', () {
      final now = DateTime.utc(2026, 1, 1, 12);
      final status = deriveBusStatus(
        latest: BusLocationModel(
          lat: 31,
          lng: -89,
          busId: 'blue1',
          lastSeen: now.subtract(const Duration(seconds: 20)),
        ),
        isLoading: false,
        now: now,
      );

      expect(status, BusStatus.live);
    });
  });
}
