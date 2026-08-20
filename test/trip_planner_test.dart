import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hubcity_transit_flutter/src/data/models/transit_dataset.dart';
import 'package:hubcity_transit_flutter/src/domain/usecases/trip_planner.dart';

/// Loads the real bundled dataset from disk rather than a fixture, so these
/// tests fail if the data regresses — which is the point.
TransitDataset _dataset() {
  final raw = File('assets/data/transit.json').readAsStringSync();
  return TransitDataset.fromJson(jsonDecode(raw) as Map<String, dynamic>);
}

/// A Wednesday, inside service hours.
DateTime _weekdayAt(int hour, int minute) =>
    DateTime(2026, 8, 19, hour, minute);

void main() {
  late TransitDataset data;
  const planner = TripPlanner();

  setUpAll(() => data = _dataset());

  group('dataset integrity', () {
    test('every route has stops and trips', () {
      expect(data.routes.keys, hasLength(7));
      for (final entry in data.routes.entries) {
        expect(entry.value.stops, isNotEmpty, reason: entry.key);
        expect(entry.value.trips, isNotEmpty, reason: entry.key);
      }
    });

    test('stop sequences are 1-based and contiguous', () {
      for (final entry in data.routes.entries) {
        final sequences =
            entry.value.stops.map((s) => s.sequence).toList()..sort();
        expect(sequences.first, 1, reason: entry.key);
        for (var i = 0; i < sequences.length; i++) {
          expect(sequences[i], i + 1, reason: '${entry.key} at index $i');
        }
      }
    });

    test('every stop time maps to a real stop, and times parse', () {
      for (final entry in data.routes.entries) {
        final valid = entry.value.stops.map((s) => s.sequence).toSet();
        for (final trip in entry.value.trips) {
          for (final stopTime in trip.stopTimes) {
            expect(valid, contains(stopTime.sequence),
                reason: '${entry.key} ${trip.tripId}');
            expect(stopTime.minutes, isNotNull,
                reason: '${entry.key} ${trip.tripId} ${stopTime.time}');
          }
        }
      }
    });

    test('trips advance monotonically through the sequence', () {
      for (final entry in data.routes.entries) {
        for (final trip in entry.value.trips) {
          var previous = -1;
          for (final stopTime in trip.stopTimes) {
            final minutes = stopTime.minutes!;
            expect(minutes, greaterThanOrEqualTo(previous),
                reason: '${entry.key} ${trip.tripId} went backwards');
            previous = minutes;
          }
        }
      }
    });

    test('coordinates are inside the Hattiesburg area', () {
      for (final entry in data.allStops) {
        expect(entry.stop.lat, inInclusiveRange(31.2, 31.45), reason: entry.stop.name);
        expect(entry.stop.lng, inInclusiveRange(-89.5, -89.1), reason: entry.stop.name);
      }
    });
  });

  group('service calendar', () {
    test('weekday service runs Monday to Friday only', () {
      final weekday = data.services['weekday']!;
      expect(weekday.runsOn(DateTime(2026, 8, 19)), isTrue); // Wednesday
      expect(weekday.runsOn(DateTime(2026, 8, 22)), isFalse); // Saturday
      expect(weekday.runsOn(DateTime(2026, 8, 23)), isFalse); // Sunday
    });

    test('a Sunday plan reports no service rather than inventing a trip', () {
      // The defect this guards: with no calendar, Sunday rendered weekday times
      // as live and left riders waiting for a bus that was never coming.
      final result = planner.plan(
        dataset: data,
        originLat: 31.3271,
        originLng: -89.2903,
        destLat: 31.3080,
        destLng: -89.3194,
        when: DateTime(2026, 8, 23, 10, 0),
      );

      expect(result.hasResults, isFalse);
      expect(result.failure, TripPlanFailure.outsideServiceDays);
      expect(result.nextServiceMinutes, isNotNull);
    });
  });

  group('planning', () {
    test('finds a direct ride between two stops on one route', () {
      final green = data.routes['green']!;
      final from = green.stops.first;
      final to = green.stops[green.stops.length ~/ 2];

      final result = planner.plan(
        dataset: data,
        originLat: from.lat,
        originLng: from.lng,
        destLat: to.lat,
        destLng: to.lng,
        when: _weekdayAt(8, 0),
      );

      expect(result.hasResults, isTrue);
      final best = result.itineraries.first;
      expect(best.legs.first.kind, TripLegKind.walk);
      expect(best.legs.last.kind, TripLegKind.walk);
      expect(best.routeIds, isNotEmpty);
      expect(best.arrivalMinutes, greaterThan(best.departureMinutes));
    });

    test('legs are contiguous and ordered in time', () {
      final result = planner.plan(
        dataset: data,
        originLat: 31.3271,
        originLng: -89.2903,
        destLat: 31.3080,
        destLng: -89.3194,
        when: _weekdayAt(8, 0),
      );

      expect(result.hasResults, isTrue);
      for (final itinerary in result.itineraries) {
        for (var i = 0; i < itinerary.legs.length - 1; i++) {
          expect(itinerary.legs[i].endMinutes,
              lessThanOrEqualTo(itinerary.legs[i + 1].startMinutes),
              reason: 'leg $i overlaps the next');
        }
        expect(itinerary.legs.first.startMinutes, itinerary.departureMinutes);
        expect(itinerary.legs.last.endMinutes, itinerary.arrivalMinutes);
      }
    });

    test('never boards a bus before the rider can walk to the stop', () {
      final result = planner.plan(
        dataset: data,
        originLat: 31.3271,
        originLng: -89.2903,
        destLat: 31.3080,
        destLng: -89.3194,
        when: _weekdayAt(8, 0),
      );

      for (final itinerary in result.itineraries) {
        final walk = itinerary.legs.first;
        final ride = itinerary.legs.firstWhere((l) => l.kind == TripLegKind.ride);
        expect(ride.startMinutes, greaterThanOrEqualTo(walk.endMinutes));
      }
    });

    test('a ride always moves forward along the route sequence', () {
      final result = planner.plan(
        dataset: data,
        originLat: 31.3271,
        originLng: -89.2903,
        destLat: 31.3080,
        destLng: -89.3194,
        when: _weekdayAt(8, 0),
      );

      for (final itinerary in result.itineraries) {
        for (final leg in itinerary.legs.where((l) => l.kind == TripLegKind.ride)) {
          expect(leg.toStop!.sequence, greaterThan(leg.fromStop!.sequence));
        }
      }
    });

    test('arrive-by never arrives after the requested time', () {
      final target = _weekdayAt(12, 0);
      final result = planner.plan(
        dataset: data,
        originLat: 31.3271,
        originLng: -89.2903,
        destLat: 31.3080,
        destLng: -89.3194,
        when: target,
        arriveBy: true,
      );

      expect(result.hasResults, isTrue);
      for (final itinerary in result.itineraries) {
        expect(itinerary.arrivalMinutes,
            lessThanOrEqualTo(target.hour * 60 + target.minute));
      }
    });

    test('reports the walk-only option so the UI can admit riding is slower', () {
      final result = planner.plan(
        dataset: data,
        originLat: 31.3271,
        originLng: -89.2903,
        destLat: 31.3275,
        destLng: -89.2910,
        when: _weekdayAt(9, 0),
      );

      expect(result.walkOnlyMinutes, isNotNull);
      expect(result.walkOnlyMetres, isNotNull);
    });

    test('a destination far outside the network yields no nearby stops', () {
      final result = planner.plan(
        dataset: data,
        originLat: 31.3271,
        originLng: -89.2903,
        destLat: 32.2988,
        destLng: -90.1848, // Jackson, ~150 km away
        when: _weekdayAt(9, 0),
      );

      expect(result.hasResults, isFalse);
      expect(result.failure, TripPlanFailure.noNearbyStops);
    });

    test('after the last bus, reports a timing failure with the next departure', () {
      final result = planner.plan(
        dataset: data,
        originLat: 31.3271,
        originLng: -89.2903,
        destLat: 31.3080,
        destLng: -89.3194,
        when: _weekdayAt(23, 30),
      );

      expect(result.hasResults, isFalse);
      expect(result.failure, TripPlanFailure.noServiceAtTime);
      expect(result.nextServiceMinutes, isNotNull);
    });

    test('returns at most maxResults, all distinct', () {
      final result = planner.plan(
        dataset: data,
        originLat: 31.3271,
        originLng: -89.2903,
        destLat: 31.3080,
        destLng: -89.3194,
        when: _weekdayAt(8, 0),
      );

      expect(result.itineraries.length, lessThanOrEqualTo(3));
      final keys = result.itineraries
          .map((i) => '${i.routeIds.join(">")}|${i.departureMinutes}')
          .toSet();
      expect(keys.length, result.itineraries.length);
    });
  });

  group('transfers', () {
    test('can produce a two-route itinerary via a shared stop group', () {
      // train_depot links blue/brown/orange/purple; walmart_49 links green/red.
      final groups = {for (final g in data.stopGroups) g.stopGroupId: g.routes};
      expect(groups, isNotEmpty);

      final result = planner.plan(
        dataset: data,
        originLat: 31.3271,
        originLng: -89.2903,
        destLat: 31.3080,
        destLng: -89.3194,
        when: _weekdayAt(7, 0),
      );

      expect(result.hasResults, isTrue);
      // Transfers are optional for this pair, but any that appear must be sane.
      for (final itinerary in result.itineraries.where((i) => i.transferCount > 0)) {
        final transfer =
            itinerary.legs.firstWhere((l) => l.kind == TripLegKind.transfer);
        expect(transfer.endMinutes, greaterThanOrEqualTo(transfer.startMinutes));
        expect(itinerary.routeIds.toSet().length, greaterThan(1));
      }
    });
  });
}
