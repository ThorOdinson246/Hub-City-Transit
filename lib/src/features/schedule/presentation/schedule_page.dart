import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/constants/route_metadata.dart';
import '../../../core/constants/transit_ids.dart';
import '../../../core/utils/transfer_connections.dart';
import '../../../data/models/route_schedule_model.dart';
import '../../../data/models/stop_model.dart';
import '../../../domain/usecases/schedule_adjustment_use_case.dart';

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
    final routeColor = routeColors[route]!;

    return SafeArea(child: Column(children: [
      // ── Header ──────────────────────────────────────────────────────────
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Schedule', style: tt.headlineLarge),
          const SizedBox(height: 4),
          Row(children: [
            Icon(Icons.alt_route_rounded, color: routeColor, size: 18),
            const SizedBox(width: 6),
            Text(routeNames[route] ?? route.value,
              style: TextStyle(color: routeColor, fontWeight: FontWeight.w800, fontSize: 18)),
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
      SizedBox(
        height: 38,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: RouteId.values.length,
          separatorBuilder: (_, _) => const SizedBox(width: 6),
          itemBuilder: (_, i) {
            final r = RouteId.values[i];
            final sel = r == route;
            return ChoiceChip(
              showCheckmark: false,
              selected: sel,
              selectedColor: routeColors[r],
              backgroundColor: cs.surfaceContainerLow,
              side: BorderSide(
                color: sel ? routeColors[r]! : cs.outlineVariant,
              ),
              label: Text(routeNames[r]?.replaceAll(' Route', '') ?? r.value,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: sel ? Colors.white : cs.onSurface,
                )),
              onSelected: (_) {
                ref.read(selectedRouteProvider.notifier).state = r;
                ref.read(selectedBusProvider.notifier).state = routeBusMap[r]!.first;
              },
            );
          },
        ),
      ),

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
                color: const Color(0xFF16A34A).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: const Color(0xFF16A34A).withValues(alpha: 0.3)),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.gps_fixed_rounded, size: 13, color: Color(0xFF16A34A)),
                const SizedBox(width: 5),
                const Text('Live Adjusted',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF16A34A))),
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
              context, cs, tt, route, routeColor, stops, allStops, schedule, adjustment),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => _Err('Schedule error: $e'),
          ),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => _Err('Transfer data error: $e'),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _Err('Stops error: $e'),
      )),
    ]));
  }

  Widget _buildList(
    BuildContext context,
    ColorScheme cs,
    TextTheme tt,
    RouteId route,
    Color routeColor,
    List<StopModel> stops,
    Map<RouteId, List<StopModel>> allStops,
    RouteScheduleModel? schedule,
    AdjustmentResult? adjustment,
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
      final conn = _connectionsFor(name, stops, transferMap);
      if (_transferOnly && conn.isEmpty) continue;
      final adj = adjustment != null && i < adjustment.stops.length ? adjustment.stops[i] : null;
      entries.add(_Entry(
        index: i,
        name: name,
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
        routeColor: routeColor,
        cs: cs, tt: tt,
        isLast: i == entries.length - 1,
      ),
    );
  }

  List<TransferStopConnection> _connectionsFor(
    String name, List<StopModel> stops, Map<String, List<TransferStopConnection>> map) {
    final n = _norm(name);
    for (final s in stops) {
      if (_norm(s.location).contains(n) || n.contains(_norm(s.location))) {
        return map['${s.stopId}'] ?? [];
      }
    }
    return [];
  }

  String _norm(String v) => v.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
}

class _Entry {
  const _Entry({required this.index, required this.name, required this.scheduled,
    required this.adjusted, required this.isPast, required this.isCurrent, required this.connections});
  final int index;
  final String name, scheduled, adjusted;
  final bool isPast, isCurrent;
  final List<TransferStopConnection> connections;
}

class _StopRow extends StatelessWidget {
  const _StopRow({required this.entry, required this.route, required this.routeColor,
    required this.cs, required this.tt, required this.isLast});
  final _Entry entry;
  final RouteId route;
  final Color routeColor;
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
              color: entry.isCurrent ? routeColor : cs.surfaceContainerLowest,
              border: Border.all(
                color: entry.isCurrent ? routeColor
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
                color: entry.isCurrent ? routeColor : cs.outlineVariant.withValues(alpha: 0.6),
                width: entry.isCurrent ? 1.5 : 1,
              ),
            ),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Accent bar
              Container(
                width: 3.5, height: entry.isCurrent ? 80 : 44,
                decoration: BoxDecoration(color: routeColor, borderRadius: BorderRadius.circular(999)),
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
                        color: const Color(0xFF16A34A),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: const [
                        Icon(Icons.bolt_rounded, size: 10, color: Colors.white),
                        SizedBox(width: 2),
                        Text('LIVE', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Colors.white)),
                      ]),
                    ),
                ]),
                Text('Stop ID: ${8120 + entry.index}',
                  style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant)),
                if (entry.connections.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Wrap(spacing: 5, runSpacing: 5, children: entry.connections.map((c) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: routeColors[c.routeId]!.withValues(alpha: 0.15),
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
                  Text('On time', style: tt.labelSmall?.copyWith(color: const Color(0xFF16A34A))),
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
