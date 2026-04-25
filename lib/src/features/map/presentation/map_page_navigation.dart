part of 'map_page.dart';

// ── Trip Planner Sheet ────────────────────────────────────────────────────────
class _TripPlannerSheet extends ConsumerStatefulWidget {
  const _TripPlannerSheet({this.userPos});
  final dynamic userPos;

  @override
  ConsumerState<_TripPlannerSheet> createState() => _TripPlannerSheetState();
}

class _TripPlannerSheetState extends ConsumerState<_TripPlannerSheet> {
  final _toCtrl = TextEditingController();
  String? _fromLabel;
  bool _loading = false;
  String? _error;
  _TripResult? _result;

  @override
  void initState() {
    super.initState();
    if (widget.userPos != null) {
      _fromLabel = 'Your current location';
    }
  }

  @override
  void dispose() {
    _toCtrl.dispose();
    super.dispose();
  }

  Future<void> _plan() async {
    final toQuery = _toCtrl.text.trim();
    if (toQuery.isEmpty) return;

    final allStops = ref.read(allStopsByRouteProvider).asData?.value;
    if (allStops == null) return;

    // Find destination stop by fuzzy match across all routes
    StopModel? destStop;
    RouteId? destRoute;
    for (final entry in allStops.entries) {
      for (final s in entry.value) {
        if (s.location.toLowerCase().contains(toQuery.toLowerCase())) {
          destStop = s;
          destRoute = entry.key;
          break;
        }
      }
      if (destStop != null) break;
    }

    if (destStop == null) {
      setState(() => _error = 'No stop found matching "$toQuery". Try a stop name.');
      return;
    }

    if (widget.userPos == null) {
      setState(() => _error = 'Location not available. Enable location first.');
      return;
    }

    setState(() { _loading = true; _error = null; _result = null; });

    // Find nearest boarding stop to user
    final routeStops = allStops[destRoute] ?? [];
    if (routeStops.isEmpty) {
      setState(() { _loading = false; _error = 'No stops on that route.'; });
      return;
    }

    StopModel? boardStop;
    double minDist = double.infinity;
    for (final s in routeStops) {
      final d = haversineMeters(widget.userPos!.latitude, widget.userPos!.longitude, s.lat, s.lng);
      if (d < minDist) { minDist = d; boardStop = s; }
    }

    if (boardStop == null) {
      setState(() { _loading = false; _error = 'Could not find a nearby stop.'; });
      return;
    }

    final walkMins = (minDist / 80).round().clamp(1, 99);

    setState(() {
      _loading = false;
      _result = _TripResult(
        walkMeters: minDist.round(),
        walkMins: walkMins,
        boardStop: boardStop!,
        destStop: destStop!,
        route: destRoute!,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Center(child: Container(
              width: 40, height: 4, margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(color: cs.outlineVariant, borderRadius: BorderRadius.circular(999)),
            )),
            Text('Plan a Trip', style: tt.titleLarge),
            const SizedBox(height: 4),
            Text('Walk to a stop + take the bus', style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
            const SizedBox(height: 16),

            // From
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: cs.surfaceContainerLow,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: cs.outlineVariant),
              ),
              child: Row(children: [
                Icon(Icons.my_location_rounded, size: 18, color: const Color(0xFF1976D2)),
                const SizedBox(width: 10),
                Expanded(child: Text(
                  _fromLabel ?? 'Enable location to auto-fill',
                  style: tt.bodyMedium?.copyWith(
                    color: _fromLabel != null ? cs.onSurface : cs.onSurfaceVariant,
                  ),
                )),
              ]),
            ),

            // Connector line
            Padding(
              padding: const EdgeInsets.only(left: 22),
              child: Container(width: 2, height: 16, color: cs.outlineVariant),
            ),

            // To
            TextField(
              controller: _toCtrl,
              decoration: InputDecoration(
                hintText: 'Destination stop...',
                prefixIcon: const Icon(Icons.location_on_rounded, color: Color(0xFFE53935)),
                suffixIcon: _loading
                    ? const Padding(padding: EdgeInsets.all(12), child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)))
                    : IconButton(icon: const Icon(Icons.arrow_forward_rounded), onPressed: _plan),
              ),
              onSubmitted: (_) => _plan(),
            ),

            if (_error != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: cs.error.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(_error!, style: tt.bodySmall?.copyWith(color: cs.error)),
              ),
            ],

            if (_result != null) ...[
              const SizedBox(height: 16),
              _TripResultCard(result: _result!, cs: cs, tt: tt),
            ],
          ]),
        ),
      ),
    );
  }
}

class _TripResult {
  const _TripResult({
    required this.walkMeters,
    required this.walkMins,
    required this.boardStop,
    required this.destStop,
    required this.route,
  });
  final int walkMeters;
  final int walkMins;
  final StopModel boardStop;
  final StopModel destStop;
  final RouteId route;
}

class _TripResultCard extends StatelessWidget {
  const _TripResultCard({required this.result, required this.cs, required this.tt});
  final _TripResult result;
  final ColorScheme cs;
  final TextTheme tt;

  @override
  Widget build(BuildContext context) {
    final color = routeColors[result.route]!;
    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Walk step
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(width: 36, height: 36,
              decoration: BoxDecoration(
                color: cs.surfaceContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.directions_walk_rounded, size: 20, color: cs.onSurface),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Walk ${result.walkMins} min (${result.walkMeters}m)', style: tt.titleMedium),
              Text('to ${result.boardStop.location}', style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
            ])),
          ]),
        ),

        Divider(height: 1, indent: 64, color: cs.outlineVariant.withValues(alpha: 0.5)),

        // Bus step
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(width: 36, height: 36,
              decoration: BoxDecoration(color: color.withValues(alpha: 0.15), shape: BoxShape.circle),
              child: Icon(Icons.directions_bus_rounded, size: 20, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(999)),
                  child: Text(routeNames[result.route] ?? result.route.name,
                    style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800)),
                ),
              ]),
              const SizedBox(height: 4),
              Text('Board at ${result.boardStop.location}', style: tt.bodyMedium),
              Text('Towards ${result.destStop.location}', style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
            ])),
          ]),
        ),

        Divider(height: 1, indent: 64, color: cs.outlineVariant.withValues(alpha: 0.5)),

        // Arrive step
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Row(children: [
            Container(width: 36, height: 36,
              decoration: BoxDecoration(
                color: const Color(0xFF16A34A).withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.flag_rounded, size: 20, color: Color(0xFF16A34A)),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Arrive at', style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
              Text(result.destStop.location, style: tt.titleMedium),
            ])),
          ]),
        ),
      ]),
    );
  }
}
