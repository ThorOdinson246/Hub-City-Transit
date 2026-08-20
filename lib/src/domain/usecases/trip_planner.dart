import 'dart:math' as math;

import '../../data/models/transit_dataset.dart';

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
  });

  final List<TripItinerary> itineraries;
  final TripPlanFailure? failure;

  /// First departure of the next service day, for the timing failures.
  final int? nextServiceMinutes;

  /// Sometimes the honest answer is "just walk".
  final int? walkOnlyMinutes;
  final double? walkOnlyMetres;

  bool get hasResults => itineraries.isNotEmpty;
}

class _StopRef {
  const _StopRef(this.routeId, this.stop, this.walkMetres, this.walkMinutes);
  final String routeId;
  final PatternStop stop;
  final double walkMetres;
  final int walkMinutes;
}

/// Plans walk → ride → (transfer → ride) → walk journeys over the timetable.
///
/// Pure and synchronous, with time and data injected, so every case is
/// reproducible in a test.
class TripPlanner {
  const TripPlanner({this.config = const TripPlannerConfig()});

  final TripPlannerConfig config;

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
        _distance(originLat, originLng, destLat, destLng) * config.walkDetourFactor;
    final walkMinutes = _walkMinutes(walkMetres);

    final service = _serviceFor(dataset, when);
    if (service == null) {
      return TripPlanResult(
        failure: TripPlanFailure.outsideServiceDays,
        nextServiceMinutes: _firstDepartureOfDay(dataset),
        walkOnlyMinutes: walkMinutes,
        walkOnlyMetres: walkMetres,
      );
    }

    final origins = _nearbyStops(
      dataset,
      originLat,
      originLng,
      config.accessRadiusMetres,
      config.accessCandidates,
    );
    final destinations = _nearbyStops(
      dataset,
      destLat,
      destLng,
      math.min(config.destinationRadiusMetres,
          config.maxPracticalDestinationWalkMetres),
      config.destinationCandidates,
    );

    if (origins.isEmpty || destinations.isEmpty) {
      return TripPlanResult(
        failure: TripPlanFailure.noNearbyStops,
        walkOnlyMinutes: walkMinutes,
        walkOnlyMetres: walkMetres,
      );
    }

    final targetMinutes = when.hour * 60 + when.minute;
    final found = <TripItinerary>[];

    if (arriveBy) {
      // Brute-force backwards scan. Exact, and cheap enough on 153 trips that a
      // proper reverse search isn't worth the complexity.
      for (var depart = targetMinutes; depart >= 0; depart -= 5) {
        final batch = _search(dataset, origins, destinations, depart, service);
        found.addAll(batch.where((it) => it.arrivalMinutes <= targetMinutes));
        if (found.length >= config.maxResults * 3) break;
      }
    } else {
      found.addAll(_search(dataset, origins, destinations, targetMinutes, service));
    }

    if (found.isEmpty) {
      return TripPlanResult(
        failure: TripPlanFailure.noServiceAtTime,
        nextServiceMinutes: _firstDepartureOfDay(dataset),
        walkOnlyMinutes: walkMinutes,
        walkOnlyMetres: walkMetres,
      );
    }

    found.sort((a, b) {
      final byScore = a.score.compareTo(b.score);
      return byScore != 0 ? byScore : a.arrivalMinutes.compareTo(b.arrivalMinutes);
    });

    final unique = <String, TripItinerary>{};
    for (final itinerary in found) {
      final key = '${itinerary.routeIds.join('>')}|${itinerary.departureMinutes}';
      unique.putIfAbsent(key, () => itinerary);
      if (unique.length >= config.maxResults) break;
    }

    return TripPlanResult(
      itineraries: unique.values.toList(growable: false),
      walkOnlyMinutes: walkMinutes,
      walkOnlyMetres: walkMetres,
    );
  }

  List<TripItinerary> _search(
    TransitDataset dataset,
    List<_StopRef> origins,
    List<_StopRef> destinations,
    int departAfter,
    ServiceCalendar service,
  ) {
    final results = <TripItinerary>[];

    for (final from in origins) {
      final readyAt = departAfter + from.walkMinutes;

      for (final to in destinations) {
        if (to.routeId != from.routeId) continue;
        if (to.stop.sequence <= from.stop.sequence) continue;

        final ride = _firstRide(dataset, from.routeId, from.stop, to.stop, readyAt);
        if (ride == null) continue;
        results.add(_assemble(from, to, [ride]));
      }
    }

    if (config.maxTransfers >= 1) {
      results.addAll(_searchWithTransfer(dataset, origins, destinations, departAfter));
    }

    return results;
  }

  List<TripItinerary> _searchWithTransfer(
    TransitDataset dataset,
    List<_StopRef> origins,
    List<_StopRef> destinations,
    int departAfter,
  ) {
    final results = <TripItinerary>[];

    for (final from in origins) {
      final readyAt = departAfter + from.walkMinutes;
      final firstRoute = dataset.route(from.routeId);
      if (firstRoute == null) continue;

      for (final to in destinations) {
        if (to.routeId == from.routeId) continue;
        final secondRoute = dataset.route(to.routeId);
        if (secondRoute == null) continue;

        for (final alight in firstRoute.stops) {
          if (alight.sequence <= from.stop.sequence) continue;

          for (final board in secondRoute.stops) {
            if (board.sequence >= to.stop.sequence) continue;
            final gap = _distance(alight.lat, alight.lng, board.lat, board.lng);
            final sameGroup = alight.stopGroupId != null &&
                alight.stopGroupId == board.stopGroupId;
            if (!sameGroup && gap > config.transferRadiusMetres) continue;

            final legOne =
                _firstRide(dataset, from.routeId, from.stop, alight, readyAt);
            if (legOne == null) continue;

            final walkAcross = gap <= config.sameStopTransferMetres
                ? 0
                : _walkMinutes(gap * config.walkDetourFactor);
            final connectAt =
                legOne.arrive + walkAcross + config.transferBufferMinutes;

            final legTwo =
                _firstRide(dataset, to.routeId, board, to.stop, connectAt);
            if (legTwo == null) continue;

            results.add(_assemble(from, to, [legOne, legTwo],
                transferWalkMetres: sameGroup ? 0 : gap));
          }
        }
      }
    }

    return results;
  }

  TripItinerary _assemble(
    _StopRef from,
    _StopRef to,
    List<_Ride> rides, {
    double transferWalkMetres = 0,
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
          distanceMetres: transferWalkMetres,
        ));
      }
      legs.add(TripLeg(
        kind: TripLegKind.ride,
        startMinutes: ride.board,
        endMinutes: ride.arrive,
        routeId: ride.routeId,
        fromStop: ride.from,
        toStop: ride.to,
        stopCount: ride.to.sequence - ride.from.sequence,
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
      totalWalkMetres: from.walkMetres + to.walkMetres + transferWalkMetres,
      transferCount: rides.length - 1,
    );
  }

  _Ride? _firstRide(
    TransitDataset dataset,
    String routeId,
    PatternStop from,
    PatternStop to,
    int readyAt,
  ) {
    final pattern = dataset.route(routeId);
    if (pattern == null || to.sequence <= from.sequence) return null;

    _Ride? best;
    for (final trip in pattern.trips) {
      final boardAt = trip.timeAtSequence(from.sequence)?.minutes;
      final arriveAt = trip.timeAtSequence(to.sequence)?.minutes;
      if (boardAt == null || arriveAt == null) continue;
      if (boardAt < readyAt || arriveAt <= boardAt) continue;
      if (best == null || boardAt < best.board) {
        best = _Ride(routeId, from, to, boardAt, arriveAt);
      }
    }
    return best;
  }

  List<_StopRef> _nearbyStops(
    TransitDataset dataset,
    double lat,
    double lng,
    double radius,
    int limit,
  ) {
    final all = <_StopRef>[];
    for (final entry in dataset.allStops) {
      final metres =
          _distance(lat, lng, entry.stop.lat, entry.stop.lng) * config.walkDetourFactor;
      if (metres > radius) continue;
      all.add(_StopRef(entry.routeId, entry.stop, metres, _walkMinutes(metres)));
    }
    all.sort((a, b) => a.walkMetres.compareTo(b.walkMetres));
    return all.take(limit).toList(growable: false);
  }

  ServiceCalendar? _serviceFor(TransitDataset dataset, DateTime when) {
    for (final service in dataset.services.values) {
      if (service.runsOn(when)) return service;
    }
    return null;
  }

  int? _firstDepartureOfDay(TransitDataset dataset) {
    int? earliest;
    for (final pattern in dataset.routes.values) {
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

  double _distance(double lat1, double lng1, double lat2, double lng2) {
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
}

class _Ride {
  const _Ride(this.routeId, this.from, this.to, this.board, this.arrive);
  final String routeId;
  final PatternStop from;
  final PatternStop to;
  final int board;
  final int arrive;
}
