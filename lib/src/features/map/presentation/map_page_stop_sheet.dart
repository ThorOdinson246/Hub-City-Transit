part of 'map_page.dart';

// ── Stop Detail Draggable Sheet ───────────────────────────────────────────────
class _StopDetailSheet extends ConsumerWidget {
  const _StopDetailSheet({
    required this.stop,
    required this.selectedRoute,
    required this.userPos,
    required this.allStopsByRouteAsync,
    required this.stopsAsync,
    required this.selectedBus,
    required this.etaLoading,
    required this.etaRequested,
    required this.etaMinutes,
    required this.etaNearestStop,
    required this.etaError,
    required this.onClose,
    required this.onGetEta,
    required this.onSwitchRoute,
  });

  final StopModel stop;
  final RouteId selectedRoute;
  final dynamic userPos;
  final AsyncValue<Map<RouteId, List<StopModel>>> allStopsByRouteAsync;
  final AsyncValue<List<StopModel>> stopsAsync;
  final BusId selectedBus;
  final bool etaLoading;
  final bool etaRequested;
  final int? etaMinutes;
  final String? etaNearestStop;
  final String? etaError;
  final VoidCallback onClose;
  final VoidCallback onGetEta;
  final void Function(RouteId) onSwitchRoute;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    final distanceM = userPos != null
        ? haversineMeters(userPos!.latitude, userPos!.longitude, stop.lat, stop.lng)
        : null;
    final walkMins = distanceM != null ? (distanceM / 80).round().clamp(1, 99) : null;

    return DraggableScrollableSheet(
      initialChildSize: 0.38,
      minChildSize: 0.28,
      maxChildSize: 0.75,
      builder: (ctx, scrollCtrl) => Container(
        decoration: BoxDecoration(
          color: cs.surfaceContainerLowest,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.18), blurRadius: 24, offset: const Offset(0, -4)),
          ],
        ),
        child: ListView(
          controller: scrollCtrl,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
          children: [
            // drag handle
            Center(
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: 10),
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: cs.outlineVariant,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),

            // Header row
            Row(children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(stop.location,
                  style: tt.titleLarge,
                  maxLines: 2, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Wrap(spacing: 6, children: [
                  _InfoChip(label: stop.direction, cs: cs),
                  _InfoChip(label: 'Stop #${stop.stopId}', cs: cs),
                  if (walkMins != null) _InfoChip(
                    label: '~$walkMins min walk',
                    icon: Icons.directions_walk_rounded,
                    cs: cs,
                  ),
                ]),
              ])),
              Container(
                margin: const EdgeInsets.only(left: 8),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: routeColors[selectedRoute],
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  routeNames[selectedRoute] ?? selectedRoute.name,
                  style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800),
                ),
              ),
              IconButton(
                onPressed: onClose,
                icon: Icon(Icons.close_rounded, color: cs.onSurfaceVariant),
                visualDensity: VisualDensity.compact,
              ),
            ]),

            const SizedBox(height: 14),

            // ETA card
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: cs.surfaceContainerLow,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.6)),
              ),
              child: _EtaSection(
                routeColor: routeColors[selectedRoute]!,
                routeName: routeNames[selectedRoute] ?? selectedRoute.name,
                loading: etaLoading,
                requested: etaRequested,
                minutes: etaMinutes,
                nearestStop: etaNearestStop,
                error: etaError,
                hasLocation: userPos != null,
                onTap: onGetEta,
                cs: cs, tt: tt,
              ),
            ),

            const SizedBox(height: 14),

            // Transfer connections
            allStopsByRouteAsync.when(
              data: (allStops) {
                final connections = findTransferConnections(
                  selectedRoute: selectedRoute,
                  stop: stop,
                  allStopsByRoute: allStops,
                );
                if (connections.isEmpty) return const SizedBox.shrink();
                return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Transfers', style: tt.labelLarge),
                  const SizedBox(height: 8),
                  Wrap(spacing: 8, runSpacing: 8, children: connections.map((c) =>
                    ActionChip(
                      avatar: CircleAvatar(
                        radius: 6,
                        backgroundColor: routeColors[c.routeId],
                      ),
                      backgroundColor: routeColors[c.routeId]!.withValues(alpha: 0.12),
                      side: BorderSide(color: routeColors[c.routeId]!.withValues(alpha: 0.3)),
                      label: Text(routeNames[c.routeId] ?? c.routeId.name,
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: routeColors[c.routeId])),
                      onPressed: () => onSwitchRoute(c.routeId),
                    ),
                  ).toList()),
                  const SizedBox(height: 14),
                ]);
              },
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
            ),

            // Next stops
            stopsAsync.when(
              data: (routeStops) {
                final idx = routeStops.indexWhere((s) => s.stopId == stop.stopId);
                final next = idx < 0 ? const <StopModel>[] : routeStops.skip(idx + 1).take(3).toList();
                if (next.isEmpty) return const SizedBox.shrink();
                return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Icon(Icons.alt_route_rounded, size: 16, color: cs.onSurfaceVariant),
                    const SizedBox(width: 6),
                    Text('Next Stops', style: tt.labelLarge),
                  ]),
                  const SizedBox(height: 10),
                  ...next.asMap().entries.map((e) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(children: [
                      Column(children: [
                        Container(
                          width: 10, height: 10,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: routeColors[selectedRoute]!, width: 2),
                            color: cs.surfaceContainerLowest,
                          ),
                        ),
                        if (e.key < next.length - 1)
                          Container(width: 2, height: 22, color: cs.outlineVariant),
                      ]),
                      const SizedBox(width: 10),
                      Expanded(child: Text(e.value.location,
                        style: tt.bodyMedium, maxLines: 1, overflow: TextOverflow.ellipsis)),
                    ]),
                  )),
                ]);
              },
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
            ),
          ],
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
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (icon != null) ...[Icon(icon, size: 12, color: cs.onSurfaceVariant), const SizedBox(width: 3)],
        Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: cs.onSurfaceVariant)),
      ]),
    );
  }
}

class _EtaSection extends StatelessWidget {
  const _EtaSection({
    required this.routeColor,
    required this.routeName,
    required this.loading,
    required this.requested,
    required this.minutes,
    required this.nearestStop,
    required this.error,
    required this.hasLocation,
    required this.onTap,
    required this.cs,
    required this.tt,
  });
  final Color routeColor;
  final String routeName;
  final bool loading;
  final bool requested;
  final int? minutes;
  final String? nearestStop;
  final String? error;
  final bool hasLocation;
  final VoidCallback onTap;
  final ColorScheme cs;
  final TextTheme tt;

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return Row(children: [
        SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: routeColor)),
        const SizedBox(width: 12),
        Text('Calculating arrival time...', style: tt.bodyMedium),
      ]);
    }
    if (error != null) {
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(error!, style: tt.bodySmall?.copyWith(color: cs.error)),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: onTap,
          child: Text('Retry', style: TextStyle(color: routeColor, fontWeight: FontWeight.w700)),
        ),
      ]);
    }
    if (minutes != null) {
      return Row(children: [
        Container(width: 4, height: 40,
          decoration: BoxDecoration(color: routeColor, borderRadius: BorderRadius.circular(999))),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('$routeName · Arriving',
            style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
          Text('$minutes min', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: cs.onSurface)),
        ])),
        GestureDetector(onTap: onTap, child: Icon(Icons.refresh_rounded, color: cs.onSurfaceVariant)),
      ]);
    }
    return Row(children: [
      Icon(Icons.schedule_rounded, size: 18, color: cs.onSurfaceVariant),
      const SizedBox(width: 10),
      Expanded(child: Text(
        hasLocation ? 'Tap to get arrival time' : 'Enable location for arrival times',
        style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
      )),
      if (hasLocation)
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: routeColor,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          onPressed: onTap,
          child: const Text('Get ETA', style: TextStyle(fontSize: 12)),
        ),
    ]);
  }
}

// ── FAB Long-press Menu ───────────────────────────────────────────────────────
class _FabMenuSheet extends StatelessWidget {
  const _FabMenuSheet({
    required this.onShowAllRoutes,
    required this.onNearbyStops,
    required this.onSearchRoute,
    required this.onPlanTrip,
  });
  final VoidCallback onShowAllRoutes;
  final VoidCallback onNearbyStops;
  final VoidCallback onSearchRoute;
  final VoidCallback onPlanTrip;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 40, height: 4, margin: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(color: cs.outlineVariant, borderRadius: BorderRadius.circular(999))),
          Text('Map Options', style: tt.titleMedium),
          const SizedBox(height: 16),
          _MenuTile(icon: Icons.layers_rounded, label: 'Show All Routes',
            sub: 'View every active route on the map', cs: cs, tt: tt, onTap: onShowAllRoutes),
          _MenuTile(icon: Icons.location_on_rounded, label: 'Nearby Stops',
            sub: 'Find stops closest to your location', cs: cs, tt: tt, onTap: onNearbyStops),
          _MenuTile(icon: Icons.search_rounded, label: 'Search Route or Stop',
            sub: 'Find a specific route or stop', cs: cs, tt: tt, onTap: onSearchRoute),
          _MenuTile(icon: Icons.directions_rounded, label: 'Plan a Trip',
            sub: 'Walk + bus directions to your destination', cs: cs, tt: tt, onTap: onPlanTrip),
        ]),
      ),
    );
  }
}

class _MenuTile extends StatelessWidget {
  const _MenuTile({required this.icon, required this.label, required this.sub, required this.cs, required this.tt, required this.onTap});
  final IconData icon; final String label, sub;
  final ColorScheme cs; final TextTheme tt; final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => ListTile(
    onTap: onTap,
    leading: Container(width: 40, height: 40,
      decoration: BoxDecoration(color: cs.surfaceContainerLow, borderRadius: BorderRadius.circular(12)),
      child: Icon(icon, color: cs.primary, size: 22)),
    title: Text(label, style: tt.titleMedium),
    subtitle: Text(sub, style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
    trailing: Icon(Icons.chevron_right_rounded, color: cs.onSurfaceVariant),
    contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
  );
}

// ── Search Sheet ──────────────────────────────────────────────────────────────
class _SearchSheet extends StatefulWidget {
  const _SearchSheet({required this.onRouteSelected});
  final void Function(RouteId) onRouteSelected;
  @override
  State<_SearchSheet> createState() => _SearchSheetState();
}
class _SearchSheetState extends State<_SearchSheet> {
  String _q = '';
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final filtered = RouteId.values.where((r) =>
      _q.isEmpty ||
      (routeNames[r] ?? '').toLowerCase().contains(_q.toLowerCase()) ||
      (routeDescriptions[r] ?? '').toLowerCase().contains(_q.toLowerCase())
    ).toList();

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.6,
        child: Column(children: [
          Container(width: 40, height: 4, margin: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(color: cs.outlineVariant, borderRadius: BorderRadius.circular(999))),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: TextField(
              autofocus: true,
              decoration: const InputDecoration(
                hintText: 'Search routes or stops...',
                prefixIcon: Icon(Icons.search_rounded),
              ),
              onChanged: (v) => setState(() => _q = v),
            ),
          ),
          Expanded(child: ListView.builder(
            itemCount: filtered.length,
            itemBuilder: (_, i) {
              final r = filtered[i];
              return ListTile(
                leading: Container(width: 36, height: 36,
                  decoration: BoxDecoration(color: routeColors[r]!.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)),
                  child: Icon(Icons.directions_bus_rounded, color: routeColors[r], size: 18)),
                title: Text(routeNames[r] ?? r.name, style: tt.titleMedium),
                subtitle: Text(routeDescriptions[r] ?? '', style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
                onTap: () { widget.onRouteSelected(r); Navigator.pop(context); },
              );
            },
          )),
        ]),
      )),
    );
  }
}
