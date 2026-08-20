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

  group('official service exceptions', () {
    test('the dataset carries the agency closure list', () {
      final ex = data.serviceExceptions!;
      expect(ex.removed, hasLength(greaterThanOrEqualTo(20)));
      expect(ex.source, contains('calendar_dates'));
    });

    test('closes for 12 days in 2026, not the 5 the website implies', () {
      final ex = data.serviceExceptions!;
      final in2026 = ex.removed.where((d) => d.startsWith('2026')).toList();
      expect(in2026, hasLength(12));
    });

    test('observes the weekend shift for Independence Day', () {
      // 4 July 2026 is a Saturday, so the agency closes Friday the 3rd. The
      // public website's rule would have marked the 4th and missed the closure.
      final ex = data.serviceExceptions!;
      expect(ex.removed, contains('20260703'));
      expect(ex.removed, isNot(contains('20260704')));
    });

    test('includes closures the website never lists', () {
      final ex = data.serviceExceptions!;
      expect(ex.removed, contains('20260119')); // MLK Day
      expect(ex.removed, contains('20260216')); // Presidents Day
      expect(ex.removed, contains('20260525')); // Memorial Day
      expect(ex.removed, contains('20261111')); // Veterans Day
      expect(ex.removed, contains('20261127')); // day after Thanksgiving
      expect(ex.removed, contains('20261224')); // Christmas Eve
    });

    test('names a closure where a rule matches the date', () {
      expect(holidayOn(DateTime(2026, 12, 25))?.name, 'Christmas Day');
      expect(holidayOn(DateTime(2026, 5, 25))?.name, 'Memorial Day');
      expect(holidayOn(DateTime(2026, 1, 19))?.name,
          'Martin Luther King Jr. Day');
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

    test('a closure the website omits still stops service', () {
      // Memorial Day 2026: a normal Monday by the website's rules.
      final status = serviceStatusAt(data, DateTime(2026, 5, 25, 10, 0));
      expect(status.state, ServiceState.holiday);
    });

    test('Christmas reports the holiday by name, not just "no service"', () {
      final status = serviceStatusAt(data, DateTime(2026, 12, 25, 10, 0));
      expect(status.state, ServiceState.holiday);
      expect(status.holidayName, 'Christmas Day');
    });

    test('the next service day skips consecutive closures', () {
      // 24 and 25 Dec 2026 are both closed, and the 26th is a Saturday, so the
      // next bus is Monday the 28th.
      final status = serviceStatusAt(data, DateTime(2026, 12, 24, 10, 0));
      expect(status.nextServiceDay, DateTime(2026, 12, 28));
    });

    test('Thanksgiving and the day after are both closed', () {
      expect(serviceStatusAt(data, DateTime(2026, 11, 26, 10)).state,
          ServiceState.holiday);
      expect(serviceStatusAt(data, DateTime(2026, 11, 27, 10)).state,
          ServiceState.holiday);
    });
  });
}
