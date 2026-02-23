import '../../core/constants/app_constants.dart';
import '../../core/utils/haversine.dart';
import '../../data/models/bus_location_model.dart';
import '../../data/models/stop_model.dart';

const double maxDeltaMinutes = 15;
const double maxGpsAgeMinutes = 5;
const double maxSnapDistanceMeters = 500;
const double smoothingFactor = 0.85;

class RouteSchedule {
  const RouteSchedule({required this.stops, required this.trips});

  final List<String> stops;
  final List<List<String>> trips;
}

class AdjustedStop {
  const AdjustedStop({
    required this.index,
    required this.name,
    required this.scheduledTime,
    required this.adjustedTime,
    required this.adjustedMinutes,
    required this.deltaMinutes,
    required this.isPast,
  });

  final int index;
  final String name;
  final String scheduledTime;
  final String adjustedTime;
  final double adjustedMinutes;
  final double deltaMinutes;
  final bool isPast;
}

class AdjustmentResult {
  const AdjustmentResult({
    required this.tripIndex,
    required this.isLiveAdjusted,
    required this.rawDelta,
    required this.appliedDelta,
    required this.snappedStopIndex,
    required this.stops,
  });

  final int tripIndex;
  final bool isLiveAdjusted;
  final double rawDelta;
  final double appliedDelta;
  final int snappedStopIndex;
  final List<AdjustedStop> stops;
}

class ScheduleAdjustmentUseCase {
  const ScheduleAdjustmentUseCase();

  AdjustmentResult adjust({
    required RouteSchedule schedule,
    required List<StopModel> gpsStops,
    required BusLocationModel? busLocation,
    required DateTime now,
  }) {
    final nowMinutes = _nowMinutes(now);
    var snappedScheduleIndex = -1;
    var gpsFresh = false;

    if (busLocation != null && gpsStops.isNotEmpty) {
      final ageMinutes =
          now.difference(busLocation.lastSeen).inMilliseconds / 60000;
      if (ageMinutes <= maxGpsAgeMinutes) {
        gpsFresh = true;
        final snap = _snapToNearestStop(
          gpsStops,
          busLocation.lat,
          busLocation.lng,
        );
        if (snap != null) {
          snappedScheduleIndex = _gpsIndexToScheduleIndex(
            snap.stopIndex,
            gpsStops.length,
            schedule.stops.length,
          );
        }
      }
    }

    final tripIndex = gpsFresh && snappedScheduleIndex >= 0
        ? _identifyTripByBusPosition(schedule, nowMinutes, snappedScheduleIndex)
        : _identifyTrip(schedule, nowMinutes);

    if (tripIndex < 0) {
      return AdjustmentResult(
        tripIndex: -1,
        isLiveAdjusted: false,
        rawDelta: 0,
        appliedDelta: 0,
        snappedStopIndex: snappedScheduleIndex,
        stops: _buildStops(schedule, null, 0, nowMinutes),
      );
    }

    var rawDelta = 0.0;
    var appliedDelta = 0.0;
    var isLive = false;
    final trip = schedule.trips[tripIndex];

    if (gpsFresh &&
        snappedScheduleIndex >= 0 &&
        snappedScheduleIndex < trip.length) {
      final scheduledAtSnap = parseTimeToMinutes(trip[snappedScheduleIndex]);
      if (!scheduledAtSnap.isNaN) {
        rawDelta = nowMinutes - scheduledAtSnap;
        if (rawDelta.abs() <= maxDeltaMinutes) {
          appliedDelta = rawDelta * smoothingFactor;
          isLive = true;
        }
      }
    }

    return AdjustmentResult(
      tripIndex: tripIndex,
      isLiveAdjusted: isLive,
      rawDelta: rawDelta,
      appliedDelta: appliedDelta,
      snappedStopIndex: snappedScheduleIndex,
      stops: _buildStops(schedule, trip, appliedDelta, nowMinutes),
    );
  }

  List<AdjustedStop> _buildStops(
    RouteSchedule schedule,
    List<String>? trip,
    double appliedDelta,
    double nowMinutes,
  ) {
    return List<AdjustedStop>.generate(schedule.stops.length, (index) {
      final scheduledTime = trip != null && index < trip.length
          ? trip[index]
          : '';
      final scheduled = parseTimeToMinutes(scheduledTime);
      final adjusted = scheduled.isNaN ? double.nan : scheduled + appliedDelta;
      return AdjustedStop(
        index: index,
        name: schedule.stops[index],
        scheduledTime: scheduledTime,
        adjustedTime: adjusted.isNaN
            ? scheduledTime
            : minutesToTimeString(adjusted),
        adjustedMinutes: adjusted,
        deltaMinutes: scheduled.isNaN ? 0 : appliedDelta,
        isPast: !adjusted.isNaN && adjusted < nowMinutes,
      );
    });
  }

  int _identifyTrip(RouteSchedule schedule, double currentMinutes) {
    var bestTrip = -1;
    var bestDiff = double.infinity;

    for (var i = 0; i < schedule.trips.length; i++) {
      final trip = schedule.trips[i];
      if (trip.isEmpty) {
        continue;
      }
      final first = parseTimeToMinutes(trip.first);
      final last = parseTimeToMinutes(trip.last);
      if (first.isNaN || last.isNaN) {
        continue;
      }
      if (first <= currentMinutes && last >= currentMinutes - 5) {
        final diff = currentMinutes - first;
        if (diff < bestDiff) {
          bestDiff = diff;
          bestTrip = i;
        }
      }
    }

    if (bestTrip != -1) {
      return bestTrip;
    }

    for (var i = 0; i < schedule.trips.length; i++) {
      final trip = schedule.trips[i];
      if (trip.isEmpty) {
        continue;
      }
      final first = parseTimeToMinutes(trip.first);
      if (!first.isNaN && first >= currentMinutes) {
        return i;
      }
    }

    return -1;
  }

  int _identifyTripByBusPosition(
    RouteSchedule schedule,
    double currentMinutes,
    int snappedScheduleIndex,
  ) {
    var bestTrip = -1;
    var bestDelta = double.infinity;

    for (var i = 0; i < schedule.trips.length; i++) {
      final trip = schedule.trips[i];
      if (trip.isEmpty || snappedScheduleIndex >= trip.length) {
        continue;
      }

      final first = parseTimeToMinutes(trip.first);
      final last = parseTimeToMinutes(trip.last);
      if (first.isNaN || last.isNaN) {
        continue;
      }
      if (first > currentMinutes + 5 || last < currentMinutes - 15) {
        continue;
      }

      final stopTime = parseTimeToMinutes(trip[snappedScheduleIndex]);
      if (stopTime.isNaN) {
        continue;
      }
      final delta = (currentMinutes - stopTime).abs();
      if (delta < bestDelta) {
        bestDelta = delta;
        bestTrip = i;
      }
    }

    return bestTrip == -1 ? _identifyTrip(schedule, currentMinutes) : bestTrip;
  }

  _SnapResult? _snapToNearestStop(
    List<StopModel> stops,
    double busLat,
    double busLng,
  ) {
    var minDistance = double.infinity;
    var minIndex = -1;

    for (var i = 0; i < stops.length; i++) {
      final stop = stops[i];
      final distance = haversineMeters(busLat, busLng, stop.lat, stop.lng);
      if (distance < minDistance) {
        minDistance = distance;
        minIndex = i;
      }
    }

    if (minIndex == -1 || minDistance > maxSnapDistanceMeters) {
      return null;
    }

    return _SnapResult(stopIndex: minIndex, distanceMeters: minDistance);
  }

  int _gpsIndexToScheduleIndex(int gpsIndex, int gpsCount, int scheduleCount) {
    if (gpsCount <= 1 || scheduleCount <= 1) {
      return 0;
    }
    final ratio = gpsIndex / (gpsCount - 1);
    final mapped = (ratio * (scheduleCount - 1)).round();
    return mapped.clamp(0, scheduleCount - 1);
  }
}

class _SnapResult {
  const _SnapResult({required this.stopIndex, required this.distanceMeters});

  final int stopIndex;
  final double distanceMeters;
}

double _nowMinutes(DateTime now) => now.hour * 60 + now.minute.toDouble();

double parseTimeToMinutes(String time) {
  final match = RegExp(
    r'^(\d{1,2}):(\d{2})\s*(AM|PM)$',
    caseSensitive: false,
  ).firstMatch(time.trim());
  if (match == null) {
    return double.nan;
  }

  var hour = int.parse(match.group(1)!);
  final minute = int.parse(match.group(2)!);
  final period = match.group(3)!.toUpperCase();

  if (period == 'AM' && hour == 12) {
    hour = 0;
  }
  if (period == 'PM' && hour != 12) {
    hour += 12;
  }

  return (hour * 60 + minute).toDouble();
}

String minutesToTimeString(double value) {
  var wrapped = value % 1440;
  if (wrapped < 0) {
    wrapped += 1440;
  }
  final rounded = wrapped.round();
  final hours24 = rounded ~/ 60;
  final minutes = rounded % 60;
  final period = hours24 >= 12 ? 'PM' : 'AM';
  var hours12 = hours24 % 12;
  if (hours12 == 0) {
    hours12 = 12;
  }
  return '$hours12:${minutes.toString().padLeft(2, "0")} $period';
}

enum BusStatus { live, connecting, offline }

BusStatus deriveBusStatus({
  required BusLocationModel? latest,
  required bool isLoading,
  required DateTime now,
}) {
  if (isLoading && latest == null) {
    return BusStatus.connecting;
  }
  if (latest == null) {
    return BusStatus.offline;
  }

  final staleThreshold = busStaleThreshold.inMilliseconds;
  final age = now.difference(latest.lastSeen).inMilliseconds;
  if (age > staleThreshold) {
    return BusStatus.offline;
  }
  return BusStatus.live;
}
