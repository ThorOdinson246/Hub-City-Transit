part of 'map_page.dart';

// ── Trip Planner Sheet ────────────────────────────────────────────────────────
class TripPlannerSheet extends ConsumerStatefulWidget {
  const TripPlannerSheet({super.key, this.userPos, required this.onTripCalculated});
  final dynamic userPos;
  final void Function(TripResult) onTripCalculated;

  @override
  ConsumerState<TripPlannerSheet> createState() => _TripPlannerSheetState();
}

class _TripPlannerSheetState extends ConsumerState<TripPlannerSheet> {
  final _toCtrl = TextEditingController();
  String? _fromLabel;
  bool _loading = false;
  String? _error;
  List<dynamic> _suggestions = [];
  TripResult? _result;

  Timer? _debounce;

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
    _debounce?.cancel();
    super.dispose();
  }

  final _nominatim = NominatimService();

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    if (query.trim().length < 3) {
      setState(() => _suggestions = []);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 600), () async {
      setState(() { _loading = true; _error = null; });
      try {
        final results = await _nominatim.search(query);
        if (mounted) setState(() { _suggestions = results; _loading = false; });
      } catch (e) {
        if (mounted) setState(() { _loading = false; _error = 'Search failed'; });
      }
    });
  }

  Future<void> _plan(NominatimPlace place) async {
    FocusScope.of(context).unfocus();
    if (widget.userPos == null) {
      setState(() => _error = 'Location not available. Enable location first.');
      return;
    }

    final allStops = ref.read(allStopsByRouteProvider).asData?.value;
    if (allStops == null) return;

    setState(() { _loading = true; _error = null; _result = null; });

    // 1. Geocode the destination
    final destLat = place.lat;
    final destLng = place.lon;
    final destName = place.displayName.split(',').first;

    // 2. Find best route: minimizes (walk to board stop) + (walk from dest stop to address)
    double bestTotalWalk = double.infinity;
    StopModel? bestBoardStop;
    StopModel? bestDestStop;
    RouteId? bestRoute;

    for (final entry in allStops.entries) {
      final routeStops = entry.value;
      if (routeStops.isEmpty) continue;

      // Nearest to user
      StopModel? boardStop;
      double minOriginDist = double.infinity;
      for (final s in routeStops) {
        final d = haversineMeters(widget.userPos!.latitude, widget.userPos!.longitude, s.lat, s.lng);
        if (d < minOriginDist) { minOriginDist = d; boardStop = s; }
      }

      // Nearest to destination
      StopModel? destStop;
      double minDestDist = double.infinity;
      for (final s in routeStops) {
        final d = haversineMeters(destLat, destLng, s.lat, s.lng);
        if (d < minDestDist) { minDestDist = d; destStop = s; }
      }

      if (boardStop != null && destStop != null) {
        final totalWalk = minOriginDist + minDestDist;
        if (totalWalk < bestTotalWalk) {
          bestTotalWalk = totalWalk;
          bestBoardStop = boardStop;
          bestDestStop = destStop;
          bestRoute = entry.key;
        }
      }
    }

    if (bestBoardStop == null || bestDestStop == null || bestRoute == null) {
      setState(() { _loading = false; _error = 'Could not find a valid route to this address.'; });
      return;
    }

    final walkDistToOrigin = haversineMeters(widget.userPos!.latitude, widget.userPos!.longitude, bestBoardStop.lat, bestBoardStop.lng);
    final walkDistFromDest = haversineMeters(destLat, destLng, bestDestStop.lat, bestDestStop.lng);
    
    final result = TripResult(
      walkMetersToOrigin: walkDistToOrigin.round(),
      walkMinsToOrigin: (walkDistToOrigin / 80).round().clamp(1, 99),
      walkMetersFromDest: walkDistFromDest.round(),
      walkMinsFromDest: (walkDistFromDest / 80).round().clamp(1, 99),
      boardStop: bestBoardStop!,
      destStop: bestDestStop!,
      route: bestRoute!,
      destinationName: destName,
      destinationPoint: LatLng(destLat, destLng),
    );

    setState(() {
      _loading = false;
    });

    widget.onTripCalculated(result);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
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
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                hintText: 'Search destination...',
                prefixIcon: const Icon(Icons.location_on_rounded, color: Color(0xFFE53935)),
                suffixIcon: _loading
                    ? const Padding(padding: EdgeInsets.all(12), child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)))
                    : null,
              ),
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

            // Autocomplete suggestions
            if (_suggestions.isNotEmpty) ...[
              const SizedBox(height: 16),
              Container(
                decoration: BoxDecoration(
                  color: cs.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: cs.outlineVariant),
                ),
                child: Column(
                  children: _suggestions.map((s) {
                    final place = s as NominatimPlace;
                    final parts = place.displayName.split(',');
                    final mainText = parts.first;
                    final subText = parts.skip(1).join(',').trim();
                    return ListTile(
                      leading: const Icon(Icons.place_rounded),
                      title: Text(mainText),
                      subtitle: Text(subText, maxLines: 1, overflow: TextOverflow.ellipsis),
                      onTap: () => _plan(place),
                    );
                  }).toList(),
                ),
              ),
            ],
          ]),
        ),
      ),
    );
  }
}

class TripResult {
  const TripResult({
    required this.walkMetersToOrigin,
    required this.walkMinsToOrigin,
    required this.walkMetersFromDest,
    required this.walkMinsFromDest,
    required this.boardStop,
    required this.destStop,
    required this.route,
    required this.destinationName,
    required this.destinationPoint,
  });
  final int walkMetersToOrigin;
  final int walkMinsToOrigin;
  final int walkMetersFromDest;
  final int walkMinsFromDest;
  final StopModel boardStop;
  final StopModel destStop;
  final RouteId route;
  final String destinationName;
  final LatLng destinationPoint;
  
  int get totalWalkMins => walkMinsToOrigin + walkMinsFromDest;
}

class TripActiveCard extends StatelessWidget {
  const TripActiveCard({required this.result, required this.onClose, required this.cs, required this.tt});
  final TripResult result;
  final VoidCallback onClose;
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
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 12, 0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Trip Details', style: tt.titleMedium),
              IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: onClose,
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
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
              Text('Walk ${result.walkMinsToOrigin} min (${result.walkMetersToOrigin}m)', style: tt.titleMedium),
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

        // Arrive at dest stop
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Row(children: [
            Container(width: 36, height: 36,
              decoration: BoxDecoration(
                color: cs.surfaceContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.transfer_within_a_station_rounded, size: 20, color: cs.onSurface),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Get off at ${result.destStop.location}', style: tt.bodyMedium),
            ])),
          ]),
        ),

        Divider(height: 1, indent: 64, color: cs.outlineVariant.withValues(alpha: 0.5)),

        // Walk to final destination
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
              Text('Walk ${result.walkMinsFromDest} min (${result.walkMetersFromDest}m)', style: tt.titleMedium),
              Text('to ${result.destinationName}', style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
            ])),
          ]),
        ),
      ]),
    );
  }
}
