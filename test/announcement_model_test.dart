import 'package:flutter_test/flutter_test.dart';
import 'package:hubcity_transit_flutter/src/data/models/announcement.dart';

Announcement _announcement({
  String id = 'a1',
  DateTime? updatedAt,
  List<ActivePeriod> activePeriods = const <ActivePeriod>[],
  List<InformedEntity> informedEntities = const <InformedEntity>[],
}) {
  return Announcement(
    id: id,
    kind: AnnouncementKind.serviceAlert,
    severity: AnnouncementSeverity.warning,
    title: 'Title',
    body: 'Body',
    updatedAt: updatedAt ?? DateTime.utc(2026, 8, 19, 12),
    activePeriods: activePeriods,
    informedEntities: informedEntities,
  );
}

void main() {
  group('revisionKey', () {
    test('changes when the announcement is edited', () {
      // The whole point: a rider who dismissed "minor delays" must see the
      // escalation to "route suspended" published under the same id.
      final original = _announcement(updatedAt: DateTime.utc(2026, 8, 19, 12));
      final edited = _announcement(updatedAt: DateTime.utc(2026, 8, 19, 15));

      expect(original.revisionKey, isNot(edited.revisionKey));
    });

    test('is stable for an unchanged announcement', () {
      final at = DateTime.utc(2026, 8, 19, 12);
      expect(
        _announcement(updatedAt: at).revisionKey,
        _announcement(updatedAt: at).revisionKey,
      );
    });
  });

  group('isActiveAt', () {
    test('an announcement with no periods is always active', () {
      expect(_announcement().isActiveAt(DateTime.utc(2030)), isTrue);
    });

    test('respects an open-ended period', () {
      final announcement = _announcement(
        activePeriods: [ActivePeriod(start: DateTime.utc(2026, 8, 19, 5))],
      );

      expect(announcement.isActiveAt(DateTime.utc(2026, 8, 19, 4)), isFalse);
      expect(announcement.isActiveAt(DateTime.utc(2027)), isTrue);
    });

    test('supports several windows, which one range could not express', () {
      // "Weekday mornings for two weeks" is the real-world case that a single
      // start/end pair cannot represent.
      final announcement = _announcement(
        activePeriods: [
          ActivePeriod(
            start: DateTime.utc(2026, 8, 19, 6),
            end: DateTime.utc(2026, 8, 19, 9),
          ),
          ActivePeriod(
            start: DateTime.utc(2026, 8, 20, 6),
            end: DateTime.utc(2026, 8, 20, 9),
          ),
        ],
      );

      expect(announcement.isActiveAt(DateTime.utc(2026, 8, 19, 7)), isTrue);
      expect(announcement.isActiveAt(DateTime.utc(2026, 8, 19, 12)), isFalse);
      expect(announcement.isActiveAt(DateTime.utc(2026, 8, 20, 7)), isTrue);
    });

    test('is inactive once the last window closes', () {
      final announcement = _announcement(
        activePeriods: [
          ActivePeriod(
            start: DateTime.utc(2026, 8, 19, 6),
            end: DateTime.utc(2026, 8, 19, 9),
          ),
        ],
      );

      expect(announcement.isActiveAt(DateTime.utc(2026, 8, 19, 9, 1)), isFalse);
    });
  });

  group('appliesToRoute', () {
    test('an announcement with no entities is agency-wide', () {
      expect(_announcement().appliesToRoute('gold'), isTrue);
      expect(_announcement().appliesToRoute(null), isTrue);
    });

    test('a route-scoped announcement only matches that route', () {
      final announcement = _announcement(
        informedEntities: const [InformedEntity(routeId: 'blue')],
      );

      expect(announcement.appliesToRoute('blue'), isTrue);
      expect(announcement.appliesToRoute('gold'), isFalse);
      expect(announcement.appliesToRoute(null), isFalse);
    });

    test('a stop-only entity does not narrow the route scope', () {
      // Scoping to a stop without naming a route should not silently hide the
      // alert from every rider.
      final announcement = _announcement(
        informedEntities: const [InformedEntity(stopId: 12)],
      );

      expect(announcement.appliesToRoute('blue'), isTrue);
    });
  });

  group('fromJson', () {
    test('parses a full GTFS-Realtime shaped record', () {
      final announcement = Announcement.fromJson(<String, dynamic>{
        'id': '2026-08-19-hardy-detour',
        'kind': 'service_alert',
        'severity': 'SEVERE',
        'effect': 'DETOUR',
        'title': 'Hardy St detour',
        'body': 'Blue route is detouring via 4th St.',
        'updatedAt': '2026-08-19T14:03:00Z',
        'activePeriods': [
          {'start': '2026-08-19T05:00:00Z', 'end': '2026-08-26T23:59:00Z'},
        ],
        'informedEntities': [
          {'routeId': 'blue'},
        ],
      });

      expect(announcement.severity, AnnouncementSeverity.severe);
      expect(announcement.effect, AnnouncementEffect.detour);
      expect(announcement.activePeriods.single.end, isNotNull);
      expect(announcement.informedEntities.single.routeId, 'blue');
    });

    test('defaults effect when the server omits it', () {
      final announcement = Announcement.fromJson(<String, dynamic>{
        'id': 'a1',
        'kind': 'product_update',
        'severity': 'INFO',
        'title': 'New trip planner',
        'body': 'Plan walk and ride trips.',
        'updatedAt': '2026-08-19T14:03:00Z',
      });

      expect(announcement.effect, AnnouncementEffect.unknownEffect);
      expect(announcement.activePeriods, isEmpty);
    });

    test('throws on an unrecognised enum so the record can be dropped', () {
      // The repository relies on this throwing to isolate one bad record
      // instead of rendering a half-understood alert.
      expect(
        () => Announcement.fromJson(<String, dynamic>{
          'id': 'a1',
          'kind': 'service_alert',
          'severity': 'CATASTROPHIC',
          'title': 'x',
          'body': 'y',
          'updatedAt': '2026-08-19T14:03:00Z',
        }),
        throwsA(anything),
      );
    });
  });
}
