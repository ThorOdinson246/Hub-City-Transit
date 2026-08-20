import '../../data/models/transit_dataset.dart';

class TransitHoliday {
  const TransitHoliday(this.name, this.date);

  final String name;
  final DateTime date;
}

/// Fallback holiday names, used only to label a closure the agency has already
/// declared. The authoritative list of *which days are closed* is the GTFS
/// `calendar_dates.txt` carried on the dataset — these rules are just for
/// putting a name on the date.
///
/// Do not use this to decide whether service runs: the agency closes for 12 days
/// a year, not these 5, and it observes weekend shifts.
List<TransitHoliday> holidaysForYear(int year) {
  return [
    TransitHoliday("New Year's Day", DateTime(year, 1, 1)),
    TransitHoliday('Independence Day', DateTime(year, 7, 4)),
    TransitHoliday('Labor Day', _nthWeekday(year, 9, DateTime.monday, 1)),
    TransitHoliday('Thanksgiving Day', _nthWeekday(year, 11, DateTime.thursday, 4)),
    TransitHoliday('Christmas Day', DateTime(year, 12, 25)),
    TransitHoliday('Christmas Eve', DateTime(year, 12, 24)),
    TransitHoliday("New Year's Eve", DateTime(year, 12, 31)),
    TransitHoliday('Martin Luther King Jr. Day',
        _nthWeekday(year, 1, DateTime.monday, 3)),
    TransitHoliday('Presidents Day', _nthWeekday(year, 2, DateTime.monday, 3)),
    TransitHoliday('Memorial Day', _lastWeekday(year, 5, DateTime.monday)),
    TransitHoliday('Veterans Day', DateTime(year, 11, 11)),
    TransitHoliday('Day after Thanksgiving',
        _nthWeekday(year, 11, DateTime.thursday, 4).add(const Duration(days: 1))),
  ];
}

DateTime _lastWeekday(int year, int month, int weekday) {
  final last = DateTime(year, month + 1, 0);
  return last.subtract(Duration(days: (last.weekday - weekday + 7) % 7));
}

DateTime _nthWeekday(int year, int month, int weekday, int nth) {
  final first = DateTime(year, month, 1);
  final offset = (weekday - first.weekday + 7) % 7;
  return DateTime(year, month, 1 + offset + 7 * (nth - 1));
}

bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

TransitHoliday? holidayOn(DateTime date) {
  for (final holiday in holidaysForYear(date.year)) {
    if (_sameDay(holiday.date, date)) return holiday;
  }
  return null;
}

/// The next holiday within [withinDays], so the UI can warn ahead of time rather
/// than only on the day itself.
TransitHoliday? upcomingHoliday(DateTime from, {int withinDays = 7}) {
  final candidates = [
    ...holidaysForYear(from.year),
    // Catches New Year's while we are still in late December.
    ...holidaysForYear(from.year + 1),
  ];
  final today = DateTime(from.year, from.month, from.day);

  TransitHoliday? best;
  for (final holiday in candidates) {
    final days = holiday.date.difference(today).inDays;
    if (days < 0 || days > withinDays) continue;
    if (best == null || holiday.date.isBefore(best.date)) best = holiday;
  }
  return best;
}

/// When each route actually runs. Derived from the timetable rather than
/// hardcoded, so a schedule change moves these automatically.
({int startMinutes, int endMinutes})? serviceWindowFor(RoutePattern pattern) {
  int? earliest;
  int? latest;
  for (final trip in pattern.trips) {
    for (final stopTime in trip.stopTimes) {
      final minutes = stopTime.minutes;
      if (minutes == null) continue;
      if (earliest == null || minutes < earliest) earliest = minutes;
      if (latest == null || minutes > latest) latest = minutes;
    }
  }
  if (earliest == null || latest == null) return null;
  return (startMinutes: earliest, endMinutes: latest);
}

/// The network-wide window: first bus anywhere to last bus anywhere.
({int startMinutes, int endMinutes})? networkServiceWindow(TransitDataset data) {
  int? earliest;
  int? latest;
  for (final pattern in data.routes.values) {
    final window = serviceWindowFor(pattern);
    if (window == null) continue;
    if (earliest == null || window.startMinutes < earliest) {
      earliest = window.startMinutes;
    }
    if (latest == null || window.endMinutes > latest) latest = window.endMinutes;
  }
  if (earliest == null || latest == null) return null;
  return (startMinutes: earliest, endMinutes: latest);
}

enum ServiceState { running, beforeFirstBus, afterLastBus, holiday, weekend }

class ServiceStatus {
  const ServiceStatus({
    required this.state,
    this.holidayName,
    this.nextServiceDay,
    this.windowStartMinutes,
    this.windowEndMinutes,
  });

  final ServiceState state;
  final String? holidayName;

  /// The next day buses run, for the "next available departure" line.
  final DateTime? nextServiceDay;
  final int? windowStartMinutes;
  final int? windowEndMinutes;

  bool get isRunning => state == ServiceState.running;
}

/// Whether buses are running right now, and if not, when they next will be.
ServiceStatus serviceStatusAt(TransitDataset data, DateTime now) {
  final window = networkServiceWindow(data);
  final start = window?.startMinutes;
  final end = window?.endMinutes;

  ServiceStatus withNext(ServiceState state, {String? holidayName}) {
    return ServiceStatus(
      state: state,
      holidayName: holidayName,
      nextServiceDay: _nextServiceDay(data, now),
      windowStartMinutes: start,
      windowEndMinutes: end,
    );
  }

  final exceptions = data.serviceExceptions;
  if (exceptions != null && exceptions.isRemoved(now)) {
    // Named where we can, but the closure itself is the agency's word.
    return withNext(ServiceState.holiday, holidayName: holidayOn(now)?.name);
  }

  final runsToday = data.services.values.any((s) => s.runsOn(now));
  if (!runsToday) return withNext(ServiceState.weekend);

  if (start == null || end == null) return withNext(ServiceState.afterLastBus);

  final minutes = now.hour * 60 + now.minute;
  if (minutes < start) return withNext(ServiceState.beforeFirstBus);
  if (minutes > end) return withNext(ServiceState.afterLastBus);

  return ServiceStatus(
    state: ServiceState.running,
    windowStartMinutes: start,
    windowEndMinutes: end,
  );
}

/// Walks forward to the next day that is both a service day and not a holiday.
DateTime? _nextServiceDay(TransitDataset data, DateTime from) {
  var day = DateTime(from.year, from.month, from.day);
  final minutes = from.hour * 60 + from.minute;
  final window = networkServiceWindow(data);

  // Still time to catch a bus today.
  bool runs(DateTime d) {
    if (data.serviceExceptions?.isRemoved(d) ?? false) return false;
    if (data.serviceExceptions?.isAdded(d) ?? false) return true;
    return data.services.values.any((s) => s.runsOn(d));
  }

  if (runs(day) && window != null && minutes < window.startMinutes) return day;

  for (var i = 1; i <= 21; i++) {
    day = DateTime(from.year, from.month, from.day + i);
    if (runs(day)) return day;
  }
  return null;
}
