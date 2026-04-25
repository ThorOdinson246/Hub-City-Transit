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
  String query = '';
  bool transferOnly = false;

  @override
  Widget build(BuildContext context) {
    final route = ref.watch(selectedRouteProvider);
    final stopsAsync = ref.watch(stopsBySelectedRouteProvider);
    final allStopsByRouteAsync = ref.watch(allStopsByRouteProvider);
    final scheduleAsync = ref.watch(selectedRouteScheduleProvider);
    final adjustment = ref.watch(selectedRouteAdjustmentProvider);

    return SafeArea(
      child: Column(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Schedule',
                style: TextStyle(fontSize: 34, fontWeight: FontWeight.w800),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Row(
              children: [
                Icon(Icons.alt_route_rounded, color: routeColors[route], size: 18),
                const SizedBox(width: 6),
                Text(
                  routeNames[route] ?? route.value,
                  style: TextStyle(
                    color: routeColors[route],
                    fontWeight: FontWeight.w700,
                    fontSize: 19,
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  '• Inbound',
                  style: TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search stops on this route',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (value) {
                setState(() {
                  query = value.trim().toLowerCase();
                });
              },
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                FilterChip(
                  selected: transferOnly,
                  showCheckmark: false,
                  onSelected: (value) {
                    setState(() {
                      transferOnly = value;
                    });
                  },
                  label: const Text('Transfers only'),
                ),
                const SizedBox(width: 8),
                if (adjustment != null)
                  Chip(
                    backgroundColor: const Color(0xFFBFDBFE),
                    avatar: Icon(
                      adjustment.isLiveAdjusted
                          ? Icons.gps_fixed_rounded
                          : Icons.schedule_rounded,
                      size: 16,
                    ),
                    label: Text(
                      adjustment.isLiveAdjusted
                          ? 'Live adjusted'
                          : 'Schedule view',
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: stopsAsync.when(
              data: (stops) => allStopsByRouteAsync.when(
                data: (allStopsByRoute) => scheduleAsync.when(
                  data: (schedule) => _buildScheduleList(
                    route: route,
                    stops: stops,
                    allStopsByRoute: allStopsByRoute,
                    schedule: schedule,
                    adjustment: adjustment,
                  ),
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (error, _) =>
                      _ErrorState(message: 'Failed to load schedule: $error'),
                ),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, _) => _ErrorState(
                  message: 'Failed to load transfer data: $error',
                ),
              ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) =>
                  _ErrorState(message: 'Failed to load stops: $error'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScheduleList({
    required RouteId route,
    required List<StopModel> stops,
    required Map<RouteId, List<StopModel>> allStopsByRoute,
    required RouteScheduleModel? schedule,
    required AdjustmentResult? adjustment,
  }) {
    if (schedule == null) {
      return const Center(child: Text('No schedule available for this route'));
    }

    final transferMap = <String, List<TransferStopConnection>>{};
    for (final stop in stops) {
      transferMap['${stop.stopId}:${stop.location}'] = findTransferConnections(
        selectedRoute: route,
        stop: stop,
        allStopsByRoute: allStopsByRoute,
      );
    }

    final entries = List<_ScheduleEntry>.generate(schedule.stops.length, (index) {
      final scheduleStopName = schedule.stops[index];
      final connections =
          _findConnectionsForScheduleStop(scheduleStopName, stops, transferMap);
      final adjustedStop =
          adjustment != null && index < adjustment.stops.length
              ? adjustment.stops[index]
              : null;

      return _ScheduleEntry(
        index: index,
        stopName: scheduleStopName,
        scheduledTime: adjustedStop?.scheduledTime ?? '',
        adjustedTime: adjustedStop?.adjustedTime ?? '',
        isPast: adjustedStop?.isPast ?? false,
        isCurrent:
            adjustment != null && adjustment.snappedStopIndex == index,
        transferConnections: connections,
      );
    }).where((entry) {
      final matchesQuery =
          query.isEmpty || entry.stopName.toLowerCase().contains(query);
      if (!matchesQuery) {
        return false;
      }
      if (!transferOnly) {
        return true;
      }
      return entry.transferConnections.isNotEmpty;
    }).toList(growable: false);

    if (entries.isEmpty) {
      return const Center(child: Text('No matching stops'));
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(14, 6, 14, 16),
      itemCount: entries.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final entry = entries[index];
        final colorScheme = Theme.of(context).colorScheme;

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
              Container(
                width: 18,
                alignment: Alignment.topCenter,
                margin: const EdgeInsets.only(top: 8),
                child: Column(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: entry.isCurrent
                            ? routeColors[route]
                            : Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: entry.isCurrent
                              ? Colors.black
                              : const Color(0xFF9CA3AF),
                          width: 2,
                        ),
                      ),
                    ),
                    Container(
                      width: 2,
                      height: 108,
                      color: const Color(0xFFD1D5DB),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: entry.isCurrent
                        ? const Color(0xFFF9FAFB)
                        : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: entry.isCurrent
                          ? routeColors[route]!
                          : const Color(0xFFC5C6CA),
                    ),
                  ),
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 4,
                        height: 74,
                        decoration: BoxDecoration(
                          color: routeColors[route],
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              entry.stopName,
                              style: TextStyle(
                                fontSize: entry.isCurrent ? 31 / 2 : 14,
                                fontWeight: entry.isCurrent
                                    ? FontWeight.w800
                                    : FontWeight.w700,
                                color: entry.isPast
                                    ? colorScheme.onSurfaceVariant
                                    : colorScheme.onSurface,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Stop ID: ${8120 + entry.index}',
                              style: TextStyle(
                                fontSize: 12,
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                            if (entry.transferConnections.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: entry.transferConnections
                                    .map(
                                      (connection) => Chip(
                                        visualDensity: VisualDensity.compact,
                                        materialTapTargetSize:
                                            MaterialTapTargetSize.shrinkWrap,
                                        backgroundColor: routeColors[connection.routeId]!
                                            .withValues(alpha: 0.14),
                                        label: Text(
                                          routeNames[connection.routeId] ??
                                              connection.routeId.name,
                                          style: const TextStyle(fontSize: 10),
                                        ),
                                      ),
                                    )
                                    .toList(growable: false),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            entry.adjustedTime.isNotEmpty
                                ? entry.adjustedTime
                                : entry.scheduledTime,
                            style: TextStyle(
                              fontSize: entry.isCurrent ? 34 / 2 : 13,
                              fontWeight: entry.isCurrent
                                  ? FontWeight.w800
                                  : FontWeight.w600,
                            ),
                          ),
                          if (entry.isCurrent)
                            const Text(
                              'On time',
                              style: TextStyle(
                                fontSize: 11,
                                color: Color(0xFF6B7280),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
        );
      },
    );
  }

  List<TransferStopConnection> _findConnectionsForScheduleStop(
    String stopName,
    List<StopModel> routeStops,
    Map<String, List<TransferStopConnection>> transferMap,
  ) {
    final normalizedTarget = _normalize(stopName);
    for (final stop in routeStops) {
      final normalizedStop = _normalize(stop.location);
      if (normalizedStop.contains(normalizedTarget) ||
          normalizedTarget.contains(normalizedStop)) {
        return transferMap['${stop.stopId}:${stop.location}'] ?? const [];
      }
    }
    return const [];
  }

  String _normalize(String value) =>
      value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
}

class _ScheduleEntry {
  const _ScheduleEntry({
    required this.index,
    required this.stopName,
    required this.scheduledTime,
    required this.adjustedTime,
    required this.isPast,
    required this.isCurrent,
    required this.transferConnections,
  });

  final int index;
  final String stopName;
  final String scheduledTime;
  final String adjustedTime;
  final bool isPast;
  final bool isCurrent;
  final List<TransferStopConnection> transferConnections;
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          message,
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
