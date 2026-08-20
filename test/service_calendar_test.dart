import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hubcity_transit_flutter/src/data/models/transit_dataset.dart';
import 'package:hubcity_transit_flutter/src/domain/usecases/service_calendar.dart';

TransitDataset _dataset() => TransitDataset.fromJson(
    jsonDecode(File('assets/data/transit.json').readAsStringSync())
        as Map<String, dynamic>);

void main() {
  late TransitDataset data;
  setUpAll(() => data = _dataset());

  group('holiday rules', () {
    test('fixed-date holidays', () {
      final h = holidaysForYear(2026);
      expect(h.firstWhere((x) => x.name == "New Year's Day").date,
          DateTime(2026, 1, 1));
      expect(h.firstWhere((x) => x.name == 'Independence Day').date,
          DateTime(2026, 7, 4));
      expect(h.firstWhere((x) => x.name == 'Christmas Day').date,
          DateTime(2026, 12, 25));
    });

    test('Labor Day is the first Monday in September', () {
      for (final year in [2026, 2027, 2028]) {
        final labor =
            holidaysForYear(year).firstWhere((x) => x.name == 'Labor Day').date;
        expect(labor.weekday, DateTime.monday, reason: '$year');
        expect(labor.month, 9);
        expect(labor.day, lessThanOrEqualTo(7));
      }
    });

    test('Thanksgiving is the fourth Thursday in November', () {
      for (final year in [2026, 2027, 2028]) {
        final day = holidaysForYear(year)
            .firstWhere((x) => x.name == 'Thanksgiving Day')
            .date;
        expect(day.weekday, DateTime.thursday, reason: '$year');
        expect(day.month, 11);
        expect(day.day, inInclusiveRange(22, 28));
      }
    });

    test('holidayOn matches only the day itself', () {
      expect(holidayOn(DateTime(2026, 12, 25))?.name, 'Christmas Day');
      expect(holidayOn(DateTime(2026, 12, 24)), isNull);
    });

    test('upcomingHoliday warns within the window and not outside it', () {
      expect(upcomingHoliday(DateTime(2026, 12, 20))?.name, 'Christmas Day');
      expect(upcomingHoliday(DateTime(2026, 12, 1)), isNull);
    });

    test('finds New Years while still in December', () {
      expect(upcomingHoliday(DateTime(2026, 12, 29))?.name, "New Year's Day");
    });
  });

  group('service window', () {
    test('derives a plausible window from the timetable', () {
      final window = networkServiceWindow(data)!;
      expect(window.startMinutes, 6 * 60, reason: 'first bus at 06:00');
      expect(window.endMinutes, inInclusiveRange(18 * 60, 19 * 60));
    });

    test('per-route windows differ, and gold starts latest', () {
      final gold = serviceWindowFor(data.routes['gold']!)!;
      final blue = serviceWindowFor(data.routes['blue']!)!;
      expect(gold.startMinutes, greaterThan(blue.startMinutes));
    });
  });

  group('service status', () {
    test('mid-morning on a weekday is running', () {
      final status = serviceStatusAt(data, DateTime(2026, 8, 19, 10, 0));
      expect(status.state, ServiceState.running);
      expect(status.isRunning, isTrue);
    });

    test('before the first bus is not "no service"', () {
      // A rider at 5am should be told when buses start, not that today is off.
      final status = serviceStatusAt(data, DateTime(2026, 8, 19, 5, 0));
      expect(status.state, ServiceState.beforeFirstBus);
      expect(status.nextServiceDay, DateTime(2026, 8, 19));
    });

    test('after the last bus points at the next day', () {
      final status = serviceStatusAt(data, DateTime(2026, 8, 19, 22, 0));
      expect(status.state, ServiceState.afterLastBus);
      expect(status.nextServiceDay, DateTime(2026, 8, 20));
    });

    test('Saturday reports the weekend and points at Monday', () {
      final status = serviceStatusAt(data, DateTime(2026, 8, 22, 10, 0));
      expect(status.state, ServiceState.weekend);
      expect(status.nextServiceDay?.weekday, DateTime.monday);
    });

    test('Christmas reports the holiday by name, not just "no service"', () {
      final status = serviceStatusAt(data, DateTime(2026, 12, 25, 10, 0));
      expect(status.state, ServiceState.holiday);
      expect(status.holidayName, 'Christmas Day');
    });

    test('the next service day skips a holiday', () {
      // Christmas 2026 is a Friday, so the next running day is Monday the 28th.
      final status = serviceStatusAt(data, DateTime(2026, 12, 25, 10, 0));
      expect(status.nextServiceDay, DateTime(2026, 12, 28));
    });

    test('a holiday on a weekday still blocks service', () {
      final thanksgiving = holidaysForYear(2026)
          .firstWhere((h) => h.name == 'Thanksgiving Day')
          .date;
      expect(thanksgiving.weekday, DateTime.thursday);
      final status = serviceStatusAt(
          data, DateTime(thanksgiving.year, thanksgiving.month, thanksgiving.day, 10));
      expect(status.state, ServiceState.holiday);
    });
  });
}
