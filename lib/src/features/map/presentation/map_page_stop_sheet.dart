part of 'map_page.dart';

// ── Bus Info Default Panel ────────────────────────────────────────────────────
class _BusInfoPanel extends ConsumerWidget {
  const _BusInfoPanel({
    required this.selectedRoute,
    required this.selectedBus,
    required this.busAsync,
    required this.busStatus,
    required this.expanded,
    required this.onToggleExpanded,
    required this.onRouteChange,
    required this.onBusChange,
  });

  final RouteId selectedRoute;
  final BusId selectedBus;
  final AsyncValue<BusLocationModel?> busAsync;
  final BusStatus busStatus;
  final bool expanded;
  final VoidCallback onToggleExpanded;
  final void Function(RouteId) onRouteChange;
  final void Function(BusId) onBusChange;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final busLocation = busAsync.asData?.value;

    final statusColor = switch (busStatus) {
      BusStatus.live => const Color(0xFF16A34A),
      BusStatus.connecting => const Color(0xFFF59E0B),
      BusStatus.offline => cs.onSurfaceVariant,
    };
    final statusLabel = switch (busStatus) {
      BusStatus.live => 'Live',
      BusStatus.connecting => 'Connecting',
      BusStatus.offline => 'Offline',
    };

    final now = DateTime.now();
    String lastSeenStr = 'Unknown';
    if (busLocation != null) {
      final diff = now.difference(busLocation.lastSeen);
      if (diff.inSeconds < 60) {
        lastSeenStr = '${diff.inSeconds}s ago';
      } else if (diff.inMinutes < 60) {
        lastSeenStr = '${diff.inMinutes}m ago';
      } else {
        lastSeenStr = '${diff.inHours}h ago';
      }
    }

    final routeBuses = routeBusMap[selectedRoute] ?? [];

    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: GestureDetector(
        onVerticalDragEnd: (details) {
          if (details.primaryVelocity! > 300 && expanded) {
            onToggleExpanded();
          } else if (details.primaryVelocity! < -300 && !expanded) {
            onToggleExpanded();
          }
        },
        child: AnimatedSize(
          duration: const Duration(milliseconds: 250),
          curve: Curves.fastOutSlowIn,
          child: Align(
            alignment: Alignment.bottomCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: Container(
                decoration: BoxDecoration(
              color: cs.surfaceContainerLowest,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(22),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 18,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Drag handle + header row
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: onToggleExpanded,
                  child: Column(
                    children: [
                      Center(
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 10),
                          width: 36,
                          height: 4,
                          decoration: BoxDecoration(
                            color: cs.outlineVariant,
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                        child: Row(
                          children: [
                            Text(
                              'BUS INFO',
                              style: tt.labelSmall?.copyWith(
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.8,
                                color: cs.onSurfaceVariant,
                              ),
                            ),
                            const Spacer(),
                            Icon(
                              expanded
                                  ? Icons.keyboard_arrow_down_rounded
                                  : Icons.keyboard_arrow_up_rounded,
                              size: 18,
                              color: cs.onSurfaceVariant,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                if (expanded) ...[
                  // Route selector
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: SizedBox(
                      width: double.infinity,
                      child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: RouteId.values.map((r) {
                        final sel = r == selectedRoute;
                        return Semantics(
                          button: true,
                          label: 'Switch to ${routeNames[r] ?? r.name} route',
                          selected: sel,
                          child: MouseRegion(
                            cursor: SystemMouseCursors.click,
                            child: GestureDetector(
                              onTap: () => onRouteChange(r),
                              child: AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: sel ? routeColors[r] : cs.surfaceContainer,
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      color: sel ? Colors.white : routeColors[r],
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    routeNames[r]?.replaceAll(' Route', '') ??
                                        r.value,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: sel ? Colors.white : cs.onSurface,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        );
                      }).toList(),
                    ),
                    ),
                  ),

                  // Bus picker
                  if (routeBuses.length > 1) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                      child: SizedBox(
                        width: double.infinity,
                        child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            'Bus:',
                            style: tt.labelMedium?.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                          ...routeBuses.map((b) {
                            final sel = b == selectedBus;
                            return MouseRegion(
                              cursor: SystemMouseCursors.click,
                              child: GestureDetector(
                                onTap: () => onBusChange(b),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 180),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: sel
                                        ? routeColors[selectedRoute]
                                        : cs.surfaceContainer,
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(
                                    b.value.toUpperCase(),
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                      color: sel ? Colors.white : cs.onSurface,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }),
                        ],
                      ),
                      ),
                    ),
                  ],

                  // Bus detail card
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: cs.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: cs.outlineVariant.withValues(alpha: 0.6),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Bus name + status
                          Row(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: routeColors[selectedRoute]!.withValues(
                                    alpha: 0.12,
                                  ),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.directions_bus_rounded,
                                  color: routeColors[selectedRoute],
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      selectedBus.value.toUpperCase(),
                                      style: tt.titleLarge?.copyWith(
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    Text(
                                      routeNames[selectedRoute] ??
                                          selectedRoute.name,
                                      style: tt.bodySmall?.copyWith(
                                        color: cs.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  color: statusColor.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 7,
                                      height: 7,
                                      decoration: BoxDecoration(
                                        color: statusColor,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 5),
                                    Text(
                                      statusLabel,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: statusColor,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          if (busLocation != null) ...[
                            const SizedBox(height: 12),
                            // Stats row
                            Row(
                              children: [
                                _StatCell(
                                  label: 'LAST SEEN',
                                  value: lastSeenStr,
                                  cs: cs,
                                  tt: tt,
                                ),
                                _StatCell(
                                  label: 'HEADING',
                                  value: busLocation.heading != null
                                      ? _headingLabel(busLocation.heading!)
                                      : '—',
                                  cs: cs,
                                  tt: tt,
                                ),
                                _StatCell(
                                  label: 'SPEED',
                                  value: busLocation.speed != null
                                      ? '${busLocation.speed!.round()} mph'
                                      : '—',
                                  cs: cs,
                                  tt: tt,
                                ),
                              ],
                            ),
                            if (busStatus == BusStatus.offline) ...[
                              const SizedBox(height: 10),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: cs.outlineVariant.withValues(
                                    alpha: 0.2,
                                  ),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  'Showing last known position. Bus may have gone out of service.',
                                  style: tt.bodySmall?.copyWith(
                                    color: cs.onSurfaceVariant,
                                  ),
                                ),
                              ),
                            ],
                          ] else if (busAsync.isLoading) ...[
                            const SizedBox(height: 10),
                            const Center(
                              child: SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],

                // Safe area spacer
                SizedBox(height: MediaQuery.of(context).padding.bottom),
              ],
            ),
          ),
        ),
      ),
    ),
  ),
);
  }

  String _headingLabel(double deg) {
    const dirs = ['N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW'];
    return dirs[((deg + 22.5) / 45).floor() % 8];
  }
}

class _StatCell extends StatelessWidget {
  const _StatCell({
    required this.label,
    required this.value,
    required this.cs,
    required this.tt,
  });
  final String label, value;
  final ColorScheme cs;
  final TextTheme tt;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: tt.labelSmall?.copyWith(
            color: cs.onSurfaceVariant,
            letterSpacing: 0.5,
          ),
        ),
        Text(
          value,
          style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w800),
        ),
      ],
    ),
  );
}


class _StopDetailSheet extends ConsumerWidget {
  const _StopDetailSheet({
    required this.stop,
    required this.selectedRoute,
    required this.userPos,
    required this.allStopsAsync,
    required this.stopsAsync,
    required this.selectedBus,
    required this.onClose,
    required this.onSwitchRoute,
  });

  final StopModel stop;
  final RouteId selectedRoute;
  final Position? userPos;
  final AsyncValue<Map<RouteId, List<StopModel>>> allStopsAsync;
  final AsyncValue<List<StopModel>> stopsAsync;
  final BusId selectedBus;
  final VoidCallback onClose;
  final void Function(RouteId) onSwitchRoute;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final favorites = ref.watch(favoritesProvider);
    final isFavorite = favorites.contains(stop.stopId.toString());
    
    final distM = userPos != null
        ? haversineMeters(
            userPos!.latitude,
            userPos!.longitude,
            stop.lat,
            stop.lng,
          )
        : null;
    final walkMins = distM != null ? (distM / 80).round().clamp(1, 99) : null;

    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: AnimatedSize(
        duration: const Duration(milliseconds: 300),
        curve: Curves.fastOutSlowIn,
        child: Align(
          alignment: Alignment.bottomCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.65,
              ),
              decoration: BoxDecoration(
                color: cs.surfaceContainerLowest,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.16),
                    blurRadius: 20,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: ListView(
                shrinkWrap: true,
                padding: EdgeInsets.fromLTRB(
                  16,
                  0,
                  16,
                  MediaQuery.of(context).padding.bottom + 16,
                ),
                children: [
                  // Drag handle — swipe down here to dismiss
                  GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onVerticalDragEnd: (details) {
                      if ((details.primaryVelocity ?? 0) > 200) {
                        onClose();
                      }
                    },
                    onVerticalDragUpdate: (details) {
                      if (details.delta.dy > 12) {
                        onClose();
                      }
                    },
                    child: Center(
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 10),
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: cs.outlineVariant,
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                  ),
                  // Header
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              stop.location,
                              style: tt.titleLarge,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Wrap(
                              spacing: 6,
                              children: [
                                _InfoChip(label: stop.direction, cs: cs),
                                _InfoChip(label: 'Stop #${stop.stopId}', cs: cs),
                                if (walkMins != null)
                                  _InfoChip(
                                    label: '~$walkMins min walk',
                                    icon: Icons.directions_walk_rounded,
                                    cs: cs,
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      MouseRegion(
                        cursor: SystemMouseCursors.click,
                        child: IconButton(
                          icon: Icon(
                            isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                            color: isFavorite ? Colors.red : cs.onSurfaceVariant,
                          ),
                          onPressed: () {
                            ref.read(favoritesProvider.notifier).toggleFavorite(stop.stopId.toString());
                          },
                        ),
                      ),
                      Container(
                        margin: const EdgeInsets.only(left: 8),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: routeColors[selectedRoute],
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          routeNames[selectedRoute] ?? selectedRoute.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: onClose,
                        icon: Icon(
                          Icons.close_rounded,
                          color: cs.onSurfaceVariant,
                        ),
                        visualDensity: VisualDensity.compact,
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  // ETA
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: cs.outlineVariant.withValues(alpha: 0.6),
                      ),
                    ),
                    child: _NextArrivalsSection(
                      stop: stop,
                      routeColor: routeColors[selectedRoute]!,
                    ),
                  ),
                  const SizedBox(height: 14),
                  // Transfer chips
                  allStopsAsync.when(
                    data: (allStops) {
                      final conns = findTransferConnections(
                        selectedRoute: selectedRoute,
                        stop: stop,
                        allStopsByRoute: allStops,
                      );
                      if (conns.isEmpty) return const SizedBox.shrink();
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Transfers', style: tt.labelLarge),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: conns
                                .map(
                                  (c) => ActionChip(
                                    avatar: CircleAvatar(
                                      radius: 6,
                                      backgroundColor: routeColors[c.routeId],
                                    ),
                                    backgroundColor: routeColors[c.routeId]!
                                        .withValues(alpha: 0.12),
                                    side: BorderSide(
                                      color: routeColors[c.routeId]!.withValues(
                                        alpha: 0.3,
                                      ),
                                    ),
                                    label: Text(
                                      routeNames[c.routeId] ?? c.routeId.name,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: routeColors[c.routeId],
                                      ),
                                    ),
                                    onPressed: () => onSwitchRoute(c.routeId),
                                  ),
                                )
                                .toList(),
                          ),
                          const SizedBox(height: 14),
                        ],
                      );
                    },
                    loading: () => const SizedBox.shrink(),
                    error: (_, _) => const SizedBox.shrink(),
                  ),
                  // Next stops
                  stopsAsync.when(
                    data: (routeStops) {
                      final idx = routeStops.indexWhere(
                        (s) => s.stopId == stop.stopId,
                      );
                      final next = idx < 0
                          ? <StopModel>[]
                          : routeStops.skip(idx + 1).take(3).toList();
                      if (next.isEmpty) return const SizedBox.shrink();
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.alt_route_rounded,
                                size: 15,
                                color: cs.onSurfaceVariant,
                              ),
                              const SizedBox(width: 5),
                              Text('Next Stops', style: tt.labelLarge),
                            ],
                          ),
                          const SizedBox(height: 10),
                          ...next.asMap().entries.map(
                            (e) => Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: Row(
                                children: [
                                  Column(
                                    children: [
                                      Container(
                                        width: 10,
                                        height: 10,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: routeColors[selectedRoute]!,
                                            width: 2,
                                          ),
                                          color: cs.surfaceContainerLowest,
                                        ),
                                      ),
                                      if (e.key < next.length - 1)
                                        Container(
                                          width: 2,
                                          height: 22,
                                          color: cs.outlineVariant,
                                        ),
                                    ],
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      e.value.location,
                                      style: tt.bodyMedium,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                    loading: () => const SizedBox.shrink(),
                    error: (_, _) => const SizedBox.shrink(),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}


class _InfoChip extends StatelessWidget {

  const _InfoChip({required this.label, required this.cs, this.icon});
  final String label;
  final ColorScheme cs;
  final IconData? icon;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: cs.surfaceContainerLow,
      borderRadius: BorderRadius.circular(999),
      border: Border.all(color: cs.outlineVariant),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 11, color: cs.onSurfaceVariant),
          const SizedBox(width: 3),
        ],
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: cs.onSurfaceVariant,
          ),
        ),
      ],
    ),
  );
}

class _NextArrivalsSection extends ConsumerWidget {
  const _NextArrivalsSection({
    required this.stop,
    required this.routeColor,
  });

  final StopModel stop;
  final Color routeColor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final now = DateTime.now();

    final schedule = ref.watch(selectedRouteScheduleProvider).asData?.value;
    final adjustment = ref.watch(selectedRouteAdjustmentProvider);

    if (schedule == null) {
      return Center(
        child: Text('Schedule data not available.', style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
      );
    }


    final stopNameNorm = stop.location.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    int schedIdx = -1;
    for (int i = 0; i < schedule.stops.length; i++) {
      final s = schedule.stops[i].toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
      if (s.contains(stopNameNorm) || stopNameNorm.contains(s)) {
        schedIdx = i;
        break;
      }
    }

    if (schedIdx == -1) {
      return Center(
        child: Text('No schedule data for this specific stop.', style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
      );
    }

    final nowMinutes = now.hour * 60 + now.minute.toDouble();

    // delta = 0 when bus is offline so we fall back to pure schedule
    final delta = adjustment?.isLiveAdjusted == true ? adjustment!.appliedDelta : 0.0;

    final upcoming = <Map<String, dynamic>>[];
    final isLiveAdjusted = adjustment?.isLiveAdjusted == true;

    for (final trip in schedule.trips) {
      if (schedIdx >= trip.length) continue;
      final timeStr = trip[schedIdx];
      final rawMins = parseTimeToMinutes(timeStr);
      if (rawMins.isNaN) continue;

      final adjustedMins = rawMins + delta;
      if (adjustedMins >= nowMinutes - 1) {
        upcoming.add({
          'time': minutesToTimeString(adjustedMins),
          'scheduledTime': timeStr,
          'minutesUntil': (adjustedMins - nowMinutes).round(),
          'isLive': isLiveAdjusted,
        });
        if (upcoming.length >= 3) break;
      }
    }

    // nothing left today, show first few trips for tomorrow
    final isTomorrow = upcoming.isEmpty;
    if (isTomorrow) {
      for (final trip in schedule.trips) {
        if (schedIdx >= trip.length) continue;
        final timeStr = trip[schedIdx];
        final rawMins = parseTimeToMinutes(timeStr);
        if (rawMins.isNaN) continue;
        upcoming.add({
          'time': timeStr,
          'scheduledTime': timeStr,
          'minutesUntil': -1, // signals "next service"
          'isLive': false,
        });
        if (upcoming.length >= 3) break;
      }
    }

    if (upcoming.isEmpty) {
      return Center(
        child: Text('No schedule data for this stop.', style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.access_time_rounded, size: 14, color: cs.onSurfaceVariant),
            const SizedBox(width: 6),
            Text(
              isTomorrow ? 'NEXT SERVICE' : 'NEXT ARRIVALS',
              style: tt.labelSmall?.copyWith(
                color: cs.onSurfaceVariant,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
            if (isLiveAdjusted && !isTomorrow) ...[ 
              const Spacer(),
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 4),
                    const Text(
                      'Live',
                      style: TextStyle(color: Colors.green, fontSize: 10, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: upcoming.asMap().entries.map((e) {
            final idx = e.key;
            final arr = e.value;
            final mins = arr['minutesUntil'] as int;
            final isFirst = idx == 0;
            final isTomorrowEntry = mins == -1;
            return Expanded(
              child: Container(
                margin: EdgeInsets.only(right: idx == upcoming.length - 1 ? 0 : 8),
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                decoration: BoxDecoration(
                  color: isFirst ? cs.surfaceContainerHighest : cs.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(12),
                  border: isFirst
                      ? Border.all(color: routeColor, width: 2)
                      : Border.all(color: cs.outlineVariant),
                ),
                child: Column(
                  children: [
                    Text(
                      arr['time'] as String,
                      style: tt.titleMedium?.copyWith(
                        fontWeight: isFirst ? FontWeight.w800 : FontWeight.w600,
                        color: isFirst ? cs.onSurface : cs.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isTomorrowEntry
                          ? 'Next service'
                          : mins <= 0
                              ? 'Now'
                              : mins == 1
                                  ? '1 min'
                                  : '$mins min',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        color: isTomorrowEntry
                            ? cs.onSurfaceVariant
                            : mins <= 2
                                ? Colors.green
                                : cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}




// cycles through search hint phrases with typewriter effect
// shows anchor text first then types/erases hints so users know the bar is interactive
class _TypewriterBrandBar extends StatefulWidget {
  const _TypewriterBrandBar({required this.cs});
  final ColorScheme cs;

  @override
  State<_TypewriterBrandBar> createState() => _TypewriterBrandBarState();
}

class _TypewriterBrandBarState extends State<_TypewriterBrandBar> with SingleTickerProviderStateMixin {
  static const _phrases = [
    'Hub City Transit',
    'Where do you want to go?',
    'Plan a trip...',
    'Search a stop...',
  ];

  int _phraseIdx = 0;
  int _charIdx = 0;
  bool _deleting = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    // Wait 2s before starting the typewriter effect
    Future.delayed(const Duration(seconds: 2), _tick);
  }

  void _tick() {
    if (!mounted) return;
    final phrase = _phrases[_phraseIdx];

    if (!_deleting) {
      if (_charIdx < phrase.length) {
        setState(() => _charIdx++);
        _timer = Timer(const Duration(milliseconds: 50), _tick);
      } else {
        // Pause at end before deleting
        _timer = Timer(const Duration(milliseconds: 1600), () {
          setState(() => _deleting = true);
          _tick();
        });
      }
    } else {
      if (_charIdx > 0) {
        setState(() => _charIdx--);
        _timer = Timer(const Duration(milliseconds: 30), _tick);
      } else {
        // Move to next phrase
        setState(() {
          _deleting = false;
          _phraseIdx = (_phraseIdx + 1) % _phrases.length;
          // First phrase is the anchor — don't delete past it on first iteration
          if (_phraseIdx == 0) _phraseIdx = 1;
        });
        _timer = Timer(const Duration(milliseconds: 200), _tick);
      }
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final phrase = _phrases[_phraseIdx];
    final text = phrase.substring(0, _charIdx.clamp(0, phrase.length));
    final isAnchor = _phraseIdx == 0;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: Text(
            text.isEmpty ? _phrases[0] : text,
            style: TextStyle(
              fontSize: 15,
              fontWeight: isAnchor ? FontWeight.w800 : FontWeight.w500,
              color: isAnchor ? widget.cs.onSurface : widget.cs.onSurfaceVariant,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        // Blinking cursor
        if (!isAnchor || _charIdx < _phrases[0].length)
          AnimatedOpacity(
            opacity: _charIdx % 2 == 0 ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 400),
            child: Container(
              width: 2,
              height: 16,
              margin: const EdgeInsets.only(left: 2),
              color: widget.cs.primary,
            ),
          ),
      ],
    );
  }
}

// bus marker — shows route pill + icon circle with directional arrow
// status drives color: live = route color, connecting = amber pulse, offline = greyed out
Widget buildBusMarker({
  required BusLocationModel busLocation,
  required BusStatus busStatus,
  required RouteId selectedRoute,
  required BusId selectedBus,
  required VoidCallback onTap,
}) {
  final color = routeColors[selectedRoute]!;
  final isOffline = busStatus == BusStatus.offline;
  final isConnecting = busStatus == BusStatus.connecting;

  final statusColor = switch (busStatus) {
    BusStatus.live => color,
    BusStatus.connecting => const Color(0xFFF59E0B),
    BusStatus.offline => Colors.grey.shade500,
  };

  return Semantics(
    button: true,
    label: 'Bus ${selectedBus.value}, Status: ${busStatus.name}',
    child: GestureDetector(
      onTap: onTap,
      child: SizedBox(
      width: 80,
      height: 90,
      child: Center(
        child: Opacity(
          opacity: isOffline ? 0.55 : 1.0,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Route/bus label pill
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: statusColor,
                  borderRadius: BorderRadius.circular(999),
                  boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2))],
                ),
                child: Text(
                  selectedBus.value.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 3),
              // Bus icon circle with pulsing ring and direction pointer
              SizedBox(
                width: 50,
                height: 50,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Pulsing ring — when live or connecting
                    if (!isOffline)
                      ExcludeSemantics(child: _PulsingRing(color: statusColor)),
                    
                    // Direction arrow — only when heading available
                    if (!isOffline && busLocation.heading != null)
                      ExcludeSemantics(
                        child: Transform.rotate(
                          angle: (busLocation.heading! * 3.14159265 / 180),
                          child: Align(
                            alignment: Alignment.topCenter,
                            child: Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: CustomPaint(
                                size: const Size(10, 10),
                                painter: _PointerPainter(color: statusColor),
                              ),
                            ),
                          ),
                        ),
                      ),
                    
                    // Bus icon circle
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(color: statusColor, width: 2.5),
                        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
                      ),
                      child: Icon(
                        Icons.directions_bus_rounded,
                        size: 14,
                        color: statusColor,
                      ),
                    ),
                  ],
                ),
              ),
                // Status sub-label (offline / connecting)
                if (isOffline)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      'OFFLINE',
                      style: TextStyle(
                        fontSize: 7,
                        fontWeight: FontWeight.w800,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  )
                else if (isConnecting)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      '···',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        color: Colors.orange.shade400,
                      ),
                    ),
                  ),
              ],
          ),
        ),
      ),
      ),
    ),
  );
}

class _PointerPainter extends CustomPainter {
  _PointerPainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final fillPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final borderPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round;

    final path = ui.Path()
      ..moveTo(size.width / 2, 0)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    canvas.drawPath(path, fillPaint);
    canvas.drawPath(path, borderPaint);
  }

  @override
  bool shouldRepaint(covariant _PointerPainter oldDelegate) => color != oldDelegate.color;
}

// ── Pulsing Ring Animation ─────────────────────────────────────────────────────
class _PulsingRing extends StatefulWidget {
  const _PulsingRing({required this.color});
  final Color color;

  @override
  State<_PulsingRing> createState() => _PulsingRingState();
}

class _PulsingRingState extends State<_PulsingRing> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scale;
  late Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(duration: const Duration(milliseconds: 1200), vsync: this)..repeat();
    _scale = Tween<double>(begin: 0.5, end: 1.5).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    _opacity = Tween<double>(begin: 0.8, end: 0.0).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _controller,
    builder: (_, _) => Transform.scale(
      scale: _scale.value,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: widget.color.withValues(alpha: _opacity.value * 0.4),
        ),
      ),
    ),
  );
}

// ── User Location Direction Marker ─────────────────────────────────────────────
Widget buildUserLocationMarker(Position position, double? heading) {
  // We use the heading from flutter_compass for the direction cone.
  // If heading is null (not available), we just show the dot.
  final hasHeading = heading != null;
  final rads = hasHeading ? (heading * (3.1415926535897932 / 180.0)) : 0.0;

  return Transform.rotate(
    angle: rads,
    child: CustomPaint(
      size: const Size(80, 80),
      painter: _UserDirectionPainter(
        color: const Color(0xFF1976D2),
        hasHeading: hasHeading,
      ),
    ),
  );
}

class _UserDirectionPainter extends CustomPainter {
  _UserDirectionPainter({required this.color, required this.hasHeading});
  final Color color;
  final bool hasHeading;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    if (hasHeading) {
      final paint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.center,
          end: Alignment.topCenter,
          colors: [
            color.withValues(alpha: 0.35), // softer cone gradient
            color.withValues(alpha: 0.0),
          ],
        ).createShader(Rect.fromLTRB(0, 0, size.width, size.height / 2))
        ..style = PaintingStyle.fill;

      final path = ui.Path()
        ..moveTo(center.dx, center.dy) // Starts inside the dot
        ..lineTo(center.dx - 22, 4) // Top left flare
        ..quadraticBezierTo(center.dx, 16, center.dx + 22, 4) // Smooth curve
        ..close();

      canvas.drawPath(path, paint);
    }

    // Halo
    final haloPaint = Paint()..color = color.withValues(alpha: 0.22)..style = PaintingStyle.fill;
    final haloBorder = Paint()..color = Colors.white..strokeWidth = 2..style = PaintingStyle.stroke;
    canvas.drawCircle(center, 15, haloPaint);
    canvas.drawCircle(center, 15, haloBorder);

    // Inner dot
    final dotPaint = Paint()..color = color..style = PaintingStyle.fill;
    final dotBorder = Paint()..color = Colors.white..strokeWidth = 1.5..style = PaintingStyle.stroke;
    canvas.drawCircle(center, 7, dotPaint);
    canvas.drawCircle(center, 7, dotBorder);
  }

  @override
  bool shouldRepaint(covariant _UserDirectionPainter old) => old.color != color || old.hasHeading != hasHeading;
}

