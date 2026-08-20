import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/layout/responsive.dart';
import '../../../core/constants/route_metadata.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/transit_ids.dart';
import '../../../core/utils/transfer_connections.dart';
import '../../../data/models/route_schedule_model.dart';
import '../../../data/models/stop_model.dart';
import '../../../data/models/transit_dataset.dart';
import '../../../domain/usecases/schedule_adjustment_use_case.dart';
import '../../../domain/usecases/service_calendar.dart';
import '../../trip/application/trip_planner_providers.dart';

class SchedulePage extends ConsumerStatefulWidget {
  const SchedulePage({super.key});
  @override
  ConsumerState<SchedulePage> createState() => _SchedulePageState();
}

class _SchedulePageState extends ConsumerState<SchedulePage> {
  String _query = '';
  bool _transferOnly = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final route = ref.watch(selectedRouteProvider);
    final stopsAsync = ref.watch(stopsBySelectedRouteProvider);
    final allStopsByRouteAsync = ref.watch(allStopsByRouteProvider);
    final scheduleAsync = ref.watch(selectedRouteScheduleProvider);
    final adjustment = ref.watch(selectedRouteAdjustmentProvider);
    final accent = routeColor(route);

    return SafeArea(child: ContentPane(child: Column(children: [
      // ── Header ──────────────────────────────────────────────────────────
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Schedule', style: tt.headlineLarge),
          const SizedBox(height: 4),
          Row(children: [
            Icon(Icons.alt_route_rounded, color: accent, size: 18),
            const SizedBox(width: 6),
            Text(routeNames[route] ?? route.value,
              style: TextStyle(color: accent, fontWeight: FontWeight.w800, fontSize: 18)),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: cs.surfaceContainerLow,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: cs.outlineVariant),
              ),
              child: Text('Inbound',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: cs.onSurfaceVariant)),
            ),
          ]),
        ]),
      ),

      // ── Route chips ──────────────────────────────────────────────────────
      const SizedBox(height: 10),
      _RouteChips(route: route, cs: cs),

      // ── Search + filter bar ───────────────────────────────────────────────
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
        child: Row(children: [
          Expanded(
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Search stops...',
                prefixIcon: Icon(Icons.search_rounded),
                isDense: true,
              ),
              onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
            ),
          ),
          const SizedBox(width: 8),
          FilterChip(
            selected: _transferOnly,
            showCheckmark: false,
            label: const Text('Transfers', style: TextStyle(fontSize: 11)),
            onSelected: (v) => setState(() => _transferOnly = v),
          ),
        ]),
      ),

      // ── Live adjusted chip ────────────────────────────────────────────────
      if (adjustment?.isLiveAdjusted == true)
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: AppColors.live.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: AppColors.live.withValues(alpha: 0.3)),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.gps_fixed_rounded, size: 13, color: AppColors.live),
                const SizedBox(width: 5),
                const Text('Live Adjusted',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.live)),
              ]),
            ),
          ]),
        ),

      const SizedBox(height: 10),

      // ── List ───────────────────────────────────────────────────────────────
      Expanded(child: stopsAsync.when(
        data: (stops) => allStopsByRouteAsync.when(
          data: (allStops) => scheduleAsync.when(
            data: (schedule) => _buildList(
              context, cs, tt, route, accent, stops, allStops, schedule, adjustment,
              ref.watch(transitDatasetProvider).asData?.value,
              DateTime.now().hour * 60 + DateTime.now().minute),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => _Err('Schedule error: $e'),
          ),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => _Err('Transfer data error: $e'),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _Err('Stops error: $e'),
      )),
    ])));
  }

  Widget _buildList(
    BuildContext context,
    ColorScheme cs,
    TextTheme tt,
    RouteId route,
    Color accent,
    List<StopModel> stops,
    Map<RouteId, List<StopModel>> allStops,
    RouteScheduleModel? schedule,
    AdjustmentResult? adjustment,
    TransitDataset? dataset,
    int nowMinutes,
  ) {
    if (schedule == null) {
      return const Center(child: Text('No schedule available'));
    }

    final transferMap = <String, List<TransferStopConnection>>{};
    for (final s in stops) {
      transferMap['${s.stopId}'] = findTransferConnections(
        selectedRoute: route, stop: s, allStopsByRoute: allStops);
    }

    final entries = <_Entry>[];
    for (var i = 0; i < schedule.stops.length; i++) {
      final name = schedule.stops[i];
      if (_query.isNotEmpty && !name.toLowerCase().contains(_query)) continue;
      final matchedStop = _matchStop(name, stops);
      final conn = matchedStop == null
          ? const <TransferStopConnection>[]
          : transferMap['${matchedStop.stopId}'] ?? const <TransferStopConnection>[];
      if (_transferOnly && conn.isEmpty) continue;
      final adj = adjustment != null && i < adjustment.stops.length ? adjustment.stops[i] : null;
      // Straight from the timetable, so rows still show times when no bus is
      // running. The live adjustment refines these when it is available.
      final pattern = dataset?.route(route.value);
      final upcoming = pattern == null
          ? (times: const <int>[], tomorrow: false)
          : upcomingDepartures(pattern, i + 1, nowMinutes);
      entries.add(_Entry(
        index: i,
        direction: matchedStop?.direction,
        name: name,
        departures: upcoming.times,
        departuresTomorrow: upcoming.tomorrow,
        scheduled: adj?.scheduledTime ?? '',
        adjusted: adj?.adjustedTime ?? '',
        isPast: adj?.isPast ?? false,
        isCurrent: adjustment?.snappedStopIndex == i,
        connections: conn,
      ));
    }

    if (entries.isEmpty) return const Center(child: Text('No matching stops'));

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(14, 6, 14, 24),
      itemCount: entries.length,
      itemBuilder: (_, i) => _StopRow(
        entry: entries[i],
        route: route,
        accent: accent,
        cs: cs, tt: tt,
        isLast: i == entries.length - 1,
      ),
    );
  }

  /// Resolves a timetable stop name to the GPS stop record, or null when there
  /// is no confident match.
  ///
  /// The two lists genuinely differ — blue has 44 GPS stops against 50 timetable
  /// entries, and six of seven routes disagree — so a null here is a real state,
  /// not an error. Callers must degrade rather than invent a value.
  StopModel? _matchStop(String name, List<StopModel> stops) {
    final n = _norm(name);
    if (n.isEmpty) return null;
    for (final s in stops) {
      if (_norm(s.location) == n) return s;
    }
    // Fall back to containment, longest match first, so "Main" cannot claim a
    // row that "Main St at 7th" describes better.
    StopModel? best;
    var bestLength = 0;
    for (final s in stops) {
      final candidate = _norm(s.location);
      if (candidate.isEmpty) continue;
      if (!candidate.contains(n) && !n.contains(candidate)) continue;
      if (candidate.length > bestLength) {
        best = s;
        bestLength = candidate.length;
      }
    }
    return best;
  }

  String _norm(String v) => v.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
}

/// Route selector.
///
/// Wraps rather than scrolls horizontally once there is room. A horizontal
/// strip is a fine phone pattern but a poor pointer one: it shows no scrollbar,
/// and a mouse wheel over it scrolls the page instead, so routes past the right
/// edge are effectively undiscoverable. Height is intrinsic so the chips grow
/// with browser zoom instead of overflowing a fixed 38px box.
class _RouteChips extends ConsumerWidget {
  const _RouteChips({required this.route, required this.cs});

  final RouteId route;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chips = [
      for (final r in RouteId.values) _chip(ref, r, r == route),
    ];

    if (Breakpoints.of(context).isCompact) {
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          spacing: 6,
          children: chips,
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Wrap(spacing: 6, runSpacing: 6, children: chips),
    );
  }

  Widget _chip(WidgetRef ref, RouteId r, bool selected) {
    final color = routeColor(r);
    return ChoiceChip(
      showCheckmark: false,
      selected: selected,
      selectedColor: color,
      backgroundColor: cs.surfaceContainerLow,
      side: BorderSide(color: selected ? color : cs.outlineVariant),
      label: Text(
        routeNames[r]?.replaceAll(' Route', '') ?? r.value,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: selected ? onRouteColor(r) : cs.onSurface,
        ),
      ),
      onSelected: (_) {
        ref.read(selectedRouteProvider.notifier).state = r;
        ref.read(selectedBusProvider.notifier).state = routeBusMap[r]!.first;
      },
    );
  }
}

class _Entry {
  const _Entry({required this.index, required this.direction, required this.name,
    required this.departures, required this.departuresTomorrow,
    required this.scheduled, required this.adjusted, required this.isPast,
    required this.isCurrent, required this.connections});
  final int index;

  /// Outbound or Inbound. Tells a rider which side of the road to wait on,
  /// which the internal stop id never did.
  final String? direction;
  final String name, scheduled, adjusted;

  /// Next few scheduled departures, minutes past midnight.
  final List<int> departures;
  final bool departuresTomorrow;
  final bool isPast, isCurrent;
  final List<TransferStopConnection> connections;
}

class _StopRow extends StatelessWidget {
  const _StopRow({required this.entry, required this.route, required this.accent,
    required this.cs, required this.tt, required this.isLast});
  final _Entry entry;
  final RouteId route;
  final Color accent;
  final ColorScheme cs;
  final TextTheme tt;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final timeStr = entry.adjusted.isNotEmpty ? entry.adjusted : entry.scheduled;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Timeline dot
        SizedBox(width: 20, child: Column(children: [
          const SizedBox(height: 12),
          Container(
            width: 12, height: 12,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: entry.isCurrent ? accent : cs.surfaceContainerLowest,
              border: Border.all(
                color: entry.isCurrent ? accent
                    : entry.isPast ? cs.outlineVariant : cs.outline,
                width: 2,
              ),
            ),
          ),
          if (!isLast) Container(width: 2, height: 60, color: cs.outlineVariant),
        ])),
        const SizedBox(width: 8),

        // Card
        Expanded(child: Opacity(
          opacity: entry.isPast ? 0.5 : 1.0,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: entry.isCurrent
                  ? cs.surfaceContainerLow
                  : cs.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: entry.isCurrent ? accent : cs.outlineVariant.withValues(alpha: 0.6),
                width: entry.isCurrent ? 1.5 : 1,
              ),
            ),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Accent bar
              Container(
                width: 3.5, height: entry.isCurrent ? 80 : 44,
                decoration: BoxDecoration(color: accent, borderRadius: BorderRadius.circular(999)),
              ),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(child: Text(entry.name,
                    style: entry.isCurrent
                        ? tt.titleMedium?.copyWith(fontWeight: FontWeight.w800)
                        : tt.bodyMedium?.copyWith(fontWeight: FontWeight.w700))),
                  if (entry.isCurrent)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.live,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: const [
                        Icon(Icons.bolt_rounded, size: 10, color: Colors.white),
                        SizedBox(width: 2),
                        Text('Live', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Colors.white)),
                      ]),
                    ),
                ]),
                if (entry.direction case final String direction)
                  Text(direction,
                    style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant)),
                if (entry.departures.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(entry.departuresTomorrow ? 'Tomorrow' : 'Next',
                        style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant)),
                      for (final t in entry.departures)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: cs.surfaceContainerHigh,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(formatClock(t),
                            style: tt.labelSmall?.copyWith(fontWeight: FontWeight.w700)),
                        ),
                    ],
                  ),
                ],
                if (entry.connections.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Wrap(spacing: 5, runSpacing: 5, children: entry.connections.map((c) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: routeColor(c.routeId).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(routeNames[c.routeId]?.replaceAll(' Route', '') ?? c.routeId.name,
                      style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: routeColors[c.routeId])),
                  )).toList()),
                ],
              ])),
              const SizedBox(width: 8),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text(timeStr,
                  style: entry.isCurrent
                      ? TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: cs.onSurface)
                      : tt.bodyMedium?.copyWith(fontWeight: FontWeight.w700)),
                if (entry.isCurrent)
                  Text('On time', style: tt.labelSmall?.copyWith(color: AppColors.live)),
              ]),
            ]),
          ),
        )),
      ]),
    );
  }
}

class _Err extends StatelessWidget {
  const _Err(this.msg);
  final String msg;
  @override
  Widget build(BuildContext context) => Center(child: Padding(
    padding: const EdgeInsets.all(24),
    child: Text(msg, textAlign: TextAlign.center),
  ));
}
