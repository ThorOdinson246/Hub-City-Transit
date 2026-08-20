import 'dart:math' as math;

import '../../data/models/transit_dataset.dart';
import 'service_calendar.dart';

/// Defaults come from the official site's own planner — those are calibrated
/// against this network, so reusing them beats guessing.
class TripPlannerConfig {
  const TripPlannerConfig({
    this.walkSpeedMetresPerSecond = 1.34,
    this.walkDetourFactor = 1.35,
    this.accessRadiusMetres = 2400,
    this.destinationRadiusMetres = 3200,
    this.maxPracticalDestinationWalkMetres = 2200,
    this.transferRadiusMetres = 420,
    this.sameStopTransferMetres = 35,
    this.transferBufferMinutes = 2,
    this.transferPenaltyMinutes = 8,
    this.maxTransfers = 1,
    this.accessCandidates = 12,
    this.destinationCandidates = 14,
    this.maxResults = 3,
    this.longWalkMetres = 1200,
  });

  /// ≈3 mph.
  final double walkSpeedMetresPerSecond;

  /// Straight lines underestimate walking on a street grid. Swap for real
  /// walking directions if we ever get them.
  final double walkDetourFactor;

  final double accessRadiusMetres;
  final double destinationRadiusMetres;
  final double maxPracticalDestinationWalkMetres;
  final double transferRadiusMetres;
  final double sameStopTransferMetres;
  final int transferBufferMinutes;

  /// A connection is worse than its clock time suggests — it can be missed,
  /// and waiting outdoors is grim.
  final int transferPenaltyMinutes;
  final int maxTransfers;
  final int accessCandidates;
  final int destinationCandidates;
  final int maxResults;
  final double longWalkMetres;
}

enum TripLegKind { walk, ride, transfer }

class TripLeg {
  const TripLeg({
    required this.kind,
    required this.startMinutes,
    required this.endMinutes,
    this.routeId,
    this.fromStop,
    this.toStop,
    this.distanceMetres,
    this.stopCount,
  });

  final TripLegKind kind;
  final int startMinutes;
  final int endMinutes;
  final String? routeId;
  final PatternStop? fromStop;
  final PatternStop? toStop;
  final double? distanceMetres;
  final int? stopCount;

  int get durationMinutes => endMinutes - startMinutes;
}

class TripItinerary {
  const TripItinerary({
    required this.legs,
    required this.departureMinutes,
    required this.arrivalMinutes,
    required this.totalWalkMetres,
    required this.transferCount,
  });

  final List<TripLeg> legs;
  final int departureMinutes;
  final int arrivalMinutes;
  final double totalWalkMetres;
  final int transferCount;

  int get durationMinutes => arrivalMinutes - departureMinutes;

  /// Ranking only; the user sees [durationMinutes].
  int get score =>
      durationMinutes + transferCount * _penalty + (totalWalkMetres ~/ 400);

  static const int _penalty = 8;

  List<String> get routeIds => legs
      .where((leg) => leg.kind == TripLegKind.ride && leg.routeId != null)
      .map((leg) => leg.routeId!)
      .toList(growable: false);
}

/// "No service today" and "nothing near your destination" need different words,
/// so they get different cases.
enum TripPlanFailure { outsideServiceDays, noServiceAtTime, noNearbyStops, noItinerary }

class TripPlanResult {
  const TripPlanResult({
    this.itineraries = const <TripItinerary>[],
    this.failure,
    this.nextServiceMinutes,
    this.walkOnlyMinutes,
    this.walkOnlyMetres,
    this.serviceStatus,
  });

  final List<TripItinerary> itineraries;
  final TripPlanFailure? failure;

  /// First departure of the next service day, for the timing failures.
  final int? nextServiceMinutes;

  /// Sometimes the honest answer is "just walk".
  final int? walkOnlyMinutes;
  final double? walkOnlyMetres;

  /// Why buses are not running, when they are not. Carries the holiday name and
  /// the next running day so the UI can say something specific.
  final ServiceStatus? serviceStatus;

  bool get hasResults => itineraries.isNotEmpty;
}

class _StopRef {
  const _StopRef(this.routeId, this.stop, this.walkMetres, this.walkMinutes);
  final String routeId;
  final PatternStop stop;
  final double walkMetres;
  final int walkMinutes;
}

class _Ride {
  const _Ride(this.routeId, this.from, this.to, this.board, this.arrive);
  final String routeId;
  final PatternStop from;
  final PatternStop to;
  final int board;
  final int arrive;
}

/// A place where one route can be swapped for another, either the same physical
/// stop or a short walk.
class _Transfer {
  const _Transfer(this.fromRoute, this.alight, this.toRoute, this.board, this.walkMinutes);
  final String fromRoute;
  final PatternStop alight;
  final String toRoute;
  final PatternStop board;
  final int walkMinutes;
}

/// Precomputed lookups, built once per dataset.
///
/// Without this the transfer search was origins x destinations x stops x stops —
/// about 420,000 iterations per search, each doing a linear scan for a stop time.
/// Arrive-by ran that up to 144 times and froze the app.
class _Index {
  _Index(this.tripTimes, this.transfersByRoute);

  /// routeId -> trips -> sequence -> minutes past midnight.
  final Map<String, List<Map<int, int>>> tripTimes;

  /// routeId -> the transfers available while riding it.
  final Map<String, List<_Transfer>> transfersByRoute;

  static _Index build(TransitDataset data, TripPlannerConfig config) {
    final times = <String, List<Map<int, int>>>{};
    for (final entry in data.routes.entries) {
      times[entry.key] = [
        for (final trip in entry.value.trips)
          {
            for (final st in trip.stopTimes)
              if (st.minutes case final int m) st.sequence: m,
          },
      ];
    }

    final transfers = <String, List<_Transfer>>{};
    final routes = data.routes.entries.toList();
    for (var a = 0; a < routes.length; a++) {
      for (var b = 0; b < routes.length; b++) {
        if (a == b) continue;
        for (final alight in routes[a].value.stops) {
          for (final board in routes[b].value.stops) {
            final sameGroup = alight.stopGroupId != null &&
                alight.stopGroupId == board.stopGroupId;
            final metres = _distanceBetween(
                alight.lat, alight.lng, board.lat, board.lng);
            if (!sameGroup && metres > config.transferRadiusMetres) continue;
            final walk = sameGroup || metres <= config.sameStopTransferMetres
                ? 0
                : math.max(1,
                    (metres * config.walkDetourFactor /
                            config.walkSpeedMetresPerSecond /
                            60)
                        .round());
            transfers
                .putIfAbsent(routes[a].key, () => <_Transfer>[])
                .add(_Transfer(routes[a].key, alight, routes[b].key, board, walk));
          }
        }
      }
    }
    return _Index(times, transfers);
  }
}

/// Plans walk -> ride -> (transfer -> ride) -> walk journeys over the timetable.
///
/// Pure and synchronous, with time and data injected, so every case is
/// reproducible in a test.
class TripPlanner {
  TripPlanner({this.config = const TripPlannerConfig()});

  final TripPlannerConfig config;

  TransitDataset? _indexedFor;
  _Index? _index;

  _Index _indexFor(TransitDataset data) {
    if (!identical(_indexedFor, data) || _index == null) {
      _index = _Index.build(data, config);
      _indexedFor = data;
    }
    return _index!;
  }

  TripPlanResult plan({
    required TransitDataset dataset,
    required double originLat,
    required double originLng,
    required double destLat,
    required double destLng,
    required DateTime when,
    bool arriveBy = false,
  }) {
    final walkMetres =
        _distanceBetween(originLat, originLng, destLat, destLng) *
            config.walkDetourFactor;
    final walkMinutes = _walkMinutes(walkMetres);

    final status = serviceStatusAt(dataset, when);
    final service = _serviceFor(dataset, when);
    if (service == null || status.state == ServiceState.holiday) {
      return TripPlanResult(
        failure: TripPlanFailure.outsideServiceDays,
        nextServiceMinutes: _firstDeparture(dataset),
        walkOnlyMinutes: walkMinutes,
        walkOnlyMetres: walkMetres,
        serviceStatus: status,
      );
    }

    final origins = _nearbyStops(dataset, originLat, originLng,
        config.accessRadiusMetres, config.accessCandidates);
    final destinations = _nearbyStops(
        dataset,
        destLat,
        destLng,
        math.min(config.destinationRadiusMetres,
            config.maxPracticalDestinationWalkMetres),
        config.destinationCandidates);

    if (origins.isEmpty || destinations.isEmpty) {
      return TripPlanResult(
        failure: TripPlanFailure.noNearbyStops,
        walkOnlyMinutes: walkMinutes,
        walkOnlyMetres: walkMetres,
      );
    }

    final index = _indexFor(dataset);
    final target = when.hour * 60 + when.minute;
    final found = _search(index, origins, destinations, target, arriveBy);

    if (found.isEmpty) {
      return TripPlanResult(
        failure: TripPlanFailure.noServiceAtTime,
        nextServiceMinutes: _firstDeparture(dataset),
        walkOnlyMinutes: walkMinutes,
        walkOnlyMetres: walkMetres,
        serviceStatus: status,
      );
    }

    found.sort((a, b) {
      final byScore = a.score.compareTo(b.score);
      return byScore != 0 ? byScore : a.arrivalMinutes.compareTo(b.arrivalMinutes);
    });

    final unique = <String, TripItinerary>{};
    for (final it in found) {
      unique.putIfAbsent(
          '${it.routeIds.join('>')}|${it.departureMinutes}', () => it);
      if (unique.length >= config.maxResults) break;
    }

    return TripPlanResult(
      itineraries: unique.values.toList(growable: false),
      walkOnlyMinutes: walkMinutes,
      walkOnlyMetres: walkMetres,
      serviceStatus: status,
    );
  }

  List<TripItinerary> _search(
    _Index index,
    List<_StopRef> origins,
    List<_StopRef> destinations,
    int target,
    bool arriveBy,
  ) {
    final results = <TripItinerary>[];

    for (final from in origins) {
      // Depart-at: the rider is ready after the walk. Arrive-by: we work
      // backwards from the deadline instead, so the walk is subtracted later.
      final readyAt = arriveBy ? null : target + from.walkMinutes;

      for (final to in destinations) {
        if (to.routeId != from.routeId) continue;
        final deadline = arriveBy ? target - to.walkMinutes : null;
        final ride = _pickRide(
            index, from.routeId, from.stop, to.stop, readyAt, deadline);
        if (ride == null) continue;
        results.add(_assemble(from, to, [ride]));
      }
    }

    if (config.maxTransfers >= 1) {
      for (final from in origins) {
        final readyAt = arriveBy ? null : target + from.walkMinutes;
        final hops = index.transfersByRoute[from.routeId] ?? const <_Transfer>[];

        for (final hop in hops) {
          if (hop.alight.sequence == from.stop.sequence) continue;

          for (final to in destinations) {
            if (to.routeId != hop.toRoute) continue;
            if (hop.board.sequence == to.stop.sequence) continue;
            final deadline = arriveBy ? target - to.walkMinutes : null;

            if (arriveBy) {
              final second = _pickRide(index, hop.toRoute, hop.board, to.stop,
                  null, deadline);
              if (second == null) continue;
              final firstDeadline =
                  second.board - hop.walkMinutes - config.transferBufferMinutes;
              final first = _pickRide(index, from.routeId, from.stop,
                  hop.alight, null, firstDeadline);
              if (first == null) continue;
              results.add(_assemble(from, to, [first, second],
                  transferWalkMinutes: hop.walkMinutes));
            } else {
              final first = _pickRide(
                  index, from.routeId, from.stop, hop.alight, readyAt, null);
              if (first == null) continue;
              final connectAt =
                  first.arrive + hop.walkMinutes + config.transferBufferMinutes;
              final second = _pickRide(
                  index, hop.toRoute, hop.board, to.stop, connectAt, null);
              if (second == null) continue;
              results.add(_assemble(from, to, [first, second],
                  transferWalkMinutes: hop.walkMinutes));
            }
          }
        }
      }
    }

    return results;
  }

  /// Earliest ride departing at or after [notBefore], or the latest one arriving
  /// at or before [notAfter]. Every route is a closed loop, so a ride whose
  /// sequence goes backwards rides through the terminus onto the next run.
  _Ride? _pickRide(
    _Index index,
    String routeId,
    PatternStop from,
    PatternStop to,
    int? notBefore,
    int? notAfter,
  ) {
    if (from.sequence == to.sequence) return null;
    final trips = index.tripTimes[routeId];
    if (trips == null || trips.isEmpty) return null;

    final wraps = to.sequence < from.sequence;
    var terminus = 0;
    if (wraps) {
      for (final t in trips) {
        for (final seq in t.keys) {
          if (seq > terminus) terminus = seq;
        }
      }
    }

    _Ride? best;
    for (final trip in trips) {
      final board = trip[from.sequence];
      if (board == null) continue;

      int? arrive;
      if (!wraps) {
        arrive = trip[to.sequence];
      } else {
        final end = trip[terminus];
        if (end == null) continue;
        for (final next in trips) {
          final candidate = next[to.sequence];
          if (candidate == null || candidate < end) continue;
          if (arrive == null || candidate < arrive) arrive = candidate;
        }
      }
      if (arrive == null || arrive <= board) continue;
      if (notBefore != null && board < notBefore) continue;
      if (notAfter != null && arrive > notAfter) continue;

      if (best == null ||
          (notAfter != null ? board > best.board : board < best.board)) {
        best = _Ride(routeId, from, to, board, arrive);
      }
    }
    return best;
  }

  TripItinerary _assemble(
    _StopRef from,
    _StopRef to,
    List<_Ride> rides, {
    int transferWalkMinutes = 0,
  }) {
    final legs = <TripLeg>[];
    final departure = rides.first.board - from.walkMinutes;

    legs.add(TripLeg(
      kind: TripLegKind.walk,
      startMinutes: departure,
      endMinutes: rides.first.board,
      toStop: from.stop,
      distanceMetres: from.walkMetres,
    ));

    for (var i = 0; i < rides.length; i++) {
      final ride = rides[i];
      if (i > 0) {
        legs.add(TripLeg(
          kind: TripLegKind.transfer,
          startMinutes: rides[i - 1].arrive,
          endMinutes: ride.board,
          fromStop: rides[i - 1].to,
          toStop: ride.from,
          distanceMetres: transferWalkMinutes *
              config.walkSpeedMetresPerSecond *
              60,
        ));
      }
      legs.add(TripLeg(
        kind: TripLegKind.ride,
        startMinutes: ride.board,
        endMinutes: ride.arrive,
        routeId: ride.routeId,
        fromStop: ride.from,
        toStop: ride.to,
        stopCount: (ride.to.sequence - ride.from.sequence).abs(),
      ));
    }

    legs.add(TripLeg(
      kind: TripLegKind.walk,
      startMinutes: rides.last.arrive,
      endMinutes: rides.last.arrive + to.walkMinutes,
      fromStop: to.stop,
      distanceMetres: to.walkMetres,
    ));

    return TripItinerary(
      legs: legs,
      departureMinutes: departure,
      arrivalMinutes: rides.last.arrive + to.walkMinutes,
      totalWalkMetres: from.walkMetres + to.walkMetres,
      transferCount: rides.length - 1,
    );
  }

  List<_StopRef> _nearbyStops(TransitDataset data, double lat, double lng,
      double radius, int limit) {
    final all = <_StopRef>[];
    for (final entry in data.allStops) {
      final metres = _distanceBetween(lat, lng, entry.stop.lat, entry.stop.lng) *
          config.walkDetourFactor;
      if (metres > radius) continue;
      all.add(_StopRef(entry.routeId, entry.stop, metres, _walkMinutes(metres)));
    }
    all.sort((a, b) => a.walkMetres.compareTo(b.walkMetres));
    return all.take(limit).toList(growable: false);
  }

  ServiceCalendar? _serviceFor(TransitDataset data, DateTime when) {
    for (final service in data.services.values) {
      if (service.runsOn(when)) return service;
    }
    return null;
  }

  int? _firstDeparture(TransitDataset data) {
    int? earliest;
    for (final pattern in data.routes.values) {
      for (final trip in pattern.trips) {
        final minutes = parseHhMm(trip.startTime);
        if (minutes == null) continue;
        if (earliest == null || minutes < earliest) earliest = minutes;
      }
    }
    return earliest;
  }

  int _walkMinutes(double metres) =>
      math.max(1, (metres / config.walkSpeedMetresPerSecond / 60).round());
}

double _distanceBetween(double lat1, double lng1, double lat2, double lng2) {
  const earthRadius = 6371000.0;
  final dLat = _radians(lat2 - lat1);
  final dLng = _radians(lng2 - lng1);
  final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(_radians(lat1)) *
          math.cos(_radians(lat2)) *
          math.sin(dLng / 2) *
          math.sin(dLng / 2);
  return earthRadius * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
}

double _radians(double degrees) => degrees * math.pi / 180;
