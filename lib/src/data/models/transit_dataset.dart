import 'package:freezed_annotation/freezed_annotation.dart';

part 'transit_dataset.freezed.dart';
part 'transit_dataset.g.dart';

/// The unified timetable — stops carry coordinates *and* their sequence.
///
/// Replaces the old split between `stops.json` (44 blue stops) and
/// `schedules.json` (50). They never corresponded, so the delta engine mapped
/// between them by ratio and invented several minutes of delay.
@freezed
abstract class TransitDataset with _$TransitDataset {
  const factory TransitDataset({
    required TransitMeta meta,
    required Map<String, ServiceCalendar> services,
    required Map<String, RoutePattern> routes,
    @Default(<StopGroup>[]) List<StopGroup> stopGroups,
    ServiceExceptions? serviceExceptions,
  }) = _TransitDataset;

  const TransitDataset._();

  factory TransitDataset.fromJson(Map<String, dynamic> json) =>
      _$TransitDatasetFromJson(json);

  RoutePattern? route(String routeId) => routes[routeId];

  Iterable<({String routeId, PatternStop stop})> get allStops sync* {
    for (final entry in routes.entries) {
      for (final stop in entry.value.stops) {
        yield (routeId: entry.key, stop: stop);
      }
    }
  }
}

/// Days the agency has explicitly cancelled or added service, straight from the
/// official GTFS `calendar_dates.txt`. Dates are `yyyyMMdd`.
///
/// This replaces a guessed holiday list. The agency closes for 12 days a year,
/// not the 5 the public website implies, and it *does* observe weekend shifts —
/// July 4 2026 falls on a Saturday and the closure is Friday the 3rd.
@freezed
abstract class ServiceExceptions with _$ServiceExceptions {
  const factory ServiceExceptions({
    @Default(<String>[]) List<String> removed,
    @Default(<String>[]) List<String> added,
    String? source,
  }) = _ServiceExceptions;

  const ServiceExceptions._();

  factory ServiceExceptions.fromJson(Map<String, dynamic> json) =>
      _$ServiceExceptionsFromJson(json);

  static String key(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}'
      '${date.month.toString().padLeft(2, '0')}'
      '${date.day.toString().padLeft(2, '0')}';

  bool isRemoved(DateTime date) => removed.contains(key(date));
  bool isAdded(DateTime date) => added.contains(key(date));
}

@freezed
abstract class TransitMeta with _$TransitMeta {
  const factory TransitMeta({
    required String timezone,
    String? source,
    String? transfersPolicy,
  }) = _TransitMeta;

  factory TransitMeta.fromJson(Map<String, dynamic> json) =>
      _$TransitMetaFromJson(json);
}

/// `days` uses 1..7 to match `DateTime.weekday`.
@freezed
abstract class ServiceCalendar with _$ServiceCalendar {
  const factory ServiceCalendar({
    @Default(<int>[]) List<int> days,
  }) = _ServiceCalendar;

  const ServiceCalendar._();

  factory ServiceCalendar.fromJson(Map<String, dynamic> json) =>
      _$ServiceCalendarFromJson(json);

  bool runsOn(DateTime date) => days.contains(date.weekday);
}

@freezed
abstract class RoutePattern with _$RoutePattern {
  const factory RoutePattern({
    @Default(<PatternStop>[]) List<PatternStop> stops,
    @Default(<PatternTrip>[]) List<PatternTrip> trips,
  }) = _RoutePattern;

  const RoutePattern._();

  factory RoutePattern.fromJson(Map<String, dynamic> json) =>
      _$RoutePatternFromJson(json);

  int get lastSequence =>
      stops.isEmpty ? 0 : stops.map((s) => s.sequence).reduce((a, b) => a > b ? a : b);

  PatternStop? stopBySequence(int sequence) {
    for (final stop in stops) {
      if (stop.sequence == sequence) return stop;
    }
    return null;
  }
}

@freezed
abstract class PatternStop with _$PatternStop {
  const factory PatternStop({
    required int stopId,

    /// 1-based. The link between a stop and its times — never infer it from a
    /// list index.
    required int sequence,
    required String name,
    required double lat,
    required double lng,
    @Default(<String>[]) List<String> transfersTo,

    /// Outbound, Inbound or Station. Distinguishes the two sides of a road at a
    /// paired stop, which is the difference between catching your bus and
    /// watching it go the other way.
    String? direction,

    /// Same group means same physical place, so transfers there cost no walk.
    String? stopGroupId,
  }) = _PatternStop;

  factory PatternStop.fromJson(Map<String, dynamic> json) =>
      _$PatternStopFromJson(json);
}

@freezed
abstract class PatternTrip with _$PatternTrip {
  const factory PatternTrip({
    required String tripId,
    required String serviceId,
    required String startTime,
    @Default(<StopTime>[]) List<StopTime> stopTimes,
  }) = _PatternTrip;

  const PatternTrip._();

  factory PatternTrip.fromJson(Map<String, dynamic> json) =>
      _$PatternTripFromJson(json);

  StopTime? timeAtSequence(int sequence) {
    for (final stopTime in stopTimes) {
      if (stopTime.sequence == sequence) return stopTime;
    }
    return null;
  }
}

@freezed
abstract class StopTime with _$StopTime {
  const factory StopTime({
    required int sequence,

    /// `HH:mm`, agency local time.
    required String time,
  }) = _StopTime;

  const StopTime._();

  factory StopTime.fromJson(Map<String, dynamic> json) =>
      _$StopTimeFromJson(json);

  int? get minutes => parseHhMm(time);
}

@freezed
abstract class StopGroup with _$StopGroup {
  const factory StopGroup({
    required String stopGroupId,
    @Default(<String>[]) List<String> routes,
  }) = _StopGroup;

  factory StopGroup.fromJson(Map<String, dynamic> json) =>
      _$StopGroupFromJson(json);
}

/// `HH:mm` to minutes since midnight. Strict on purpose — the old 12-hour
/// parser turned 24-hour input into NaN and silently dropped the trip.
int? parseHhMm(String value) {
  final parts = value.split(':');
  if (parts.length < 2) return null;
  final hour = int.tryParse(parts[0]);
  final minute = int.tryParse(parts[1]);
  if (hour == null || minute == null) return null;
  if (hour < 0 || hour > 47 || minute < 0 || minute > 59) return null;
  return hour * 60 + minute;
}

String formatClock(int minutesOfDay) {
  final normalised = minutesOfDay % (24 * 60);
  final hour24 = normalised ~/ 60;
  final minute = normalised % 60;
  final suffix = hour24 >= 12 ? 'PM' : 'AM';
  final hour12 = hour24 % 12 == 0 ? 12 : hour24 % 12;
  return '$hour12:${minute.toString().padLeft(2, '0')} $suffix';
}
