import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/route_metadata.dart';
import '../../../core/constants/transit_ids.dart';
import '../../../data/models/transit_dataset.dart';
import '../../../domain/usecases/trip_planner.dart';
import '../application/trip_planner_providers.dart';

class ItineraryCard extends ConsumerStatefulWidget {
  const ItineraryCard({
    required this.itinerary,
    required this.label,
    required this.onShowOnMap,
    this.highlight = false,
    this.footnote,
    super.key,
  });

  final TripItinerary itinerary;
  final String label;
  final VoidCallback onShowOnMap;
  final bool highlight;

  /// e.g. a warning that walking the whole way would be quicker.
  final String? footnote;

  @override
  ConsumerState<ItineraryCard> createState() => _ItineraryCardState();
}

class _ItineraryCardState extends ConsumerState<ItineraryCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final it = widget.itinerary;

    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: widget.highlight ? scheme.primary : scheme.outlineVariant,
          width: widget.highlight ? 2 : 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            button: true,
            label: '${widget.label}, ${it.durationMinutes} minutes, '
                'leave ${formatClock(it.departureMinutes)}, '
                'arrive ${formatClock(it.arrivalMinutes)}'
                '${it.transferCount > 0 ? ", ${it.transferCount} transfer" : ""}',
            child: InkWell(
              onTap: () => setState(() => _expanded = !_expanded),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(widget.label,
                              style: text.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w700)),
                        ),
                        Text('${it.durationMinutes} min',
                            style: text.titleMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: scheme.primary)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _ModeStrip(itinerary: it),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 16,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        _TimeBlock(
                            label: 'Leave at',
                            value: formatClock(it.departureMinutes),
                            text: text),
                        _TimeBlock(
                            label: 'Arrive by',
                            value: formatClock(it.arrivalMinutes),
                            text: text),
                        Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.directions_walk_rounded,
                              size: 16, color: scheme.onSurfaceVariant),
                          const SizedBox(width: 4),
                          Text('${it.totalWalkMetres.round()} m',
                              style: text.bodySmall
                                  ?.copyWith(color: scheme.onSurfaceVariant)),
                        ]),
                        Icon(
                          _expanded
                              ? Icons.keyboard_arrow_up_rounded
                              : Icons.keyboard_arrow_down_rounded,
                          color: scheme.onSurfaceVariant,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (widget.footnote case final String note)
            Container(
              width: double.infinity,
              color: scheme.tertiary.withValues(alpha: 0.12),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Text(note,
                  style: text.bodySmall?.copyWith(color: scheme.onSurface)),
            ),
          if (_expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Column(
                children: [
                  const Divider(height: 1),
                  for (final leg in it.legs) _LegRow(leg: leg),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: FilledButton.tonalIcon(
                      onPressed: widget.onShowOnMap,
                      icon: const Icon(Icons.map_rounded, size: 20),
                      label: const Text('Show on map'),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _TimeBlock extends StatelessWidget {
  const _TimeBlock({required this.label, required this.value, required this.text});
  final String label;
  final String value;
  final TextTheme text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label,
            style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
        Text(value,
            style: text.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
      ],
    );
  }
}

/// The walk → bus → walk pictogram row.
class _ModeStrip extends StatelessWidget {
  const _ModeStrip({required this.itinerary});
  final TripItinerary itinerary;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final chips = <Widget>[];

    for (final leg in itinerary.legs) {
      if (leg.kind == TripLegKind.transfer) continue;
      if (chips.isNotEmpty) {
        chips.add(Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Icon(Icons.chevron_right_rounded,
              size: 16, color: scheme.onSurfaceVariant),
        ));
      }
      if (leg.kind == TripLegKind.walk) {
        chips.add(_ModeChip(
            icon: Icons.directions_walk_rounded,
            color: scheme.onSurfaceVariant,
            background: scheme.surfaceContainerHighest));
      } else {
        final route = RouteId.tryParse(leg.routeId);
        final color = route == null ? scheme.primary : routeColors[route]!;
        chips.add(_ModeChip(
            icon: Icons.directions_bus_rounded,
            color: route == null ? scheme.onPrimary : onRouteColor(route),
            background: color));
      }
    }

    return Wrap(crossAxisAlignment: WrapCrossAlignment.center, children: chips);
  }
}

class _ModeChip extends StatelessWidget {
  const _ModeChip({
    required this.icon,
    required this.color,
    required this.background,
  });
  final IconData icon;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 30,
      height: 30,
      decoration: BoxDecoration(color: background, shape: BoxShape.circle),
      child: Icon(icon, size: 17, color: color),
    );
  }
}

class _LegRow extends StatelessWidget {
  const _LegRow({required this.leg});
  final TripLeg leg;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final route = RouteId.tryParse(leg.routeId);
    final accent = route == null ? scheme.onSurfaceVariant : routeColors[route]!;

    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 62,
            child: Text(formatClock(leg.startMinutes),
                style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 12, top: 2),
            child: Icon(
              switch (leg.kind) {
                TripLegKind.walk => Icons.directions_walk_rounded,
                TripLegKind.ride => Icons.directions_bus_rounded,
                TripLegKind.transfer => Icons.swap_horiz_rounded,
              },
              size: 18,
              color: accent,
            ),
          ),
          Expanded(child: _legBody(context, scheme, text, route)),
        ],
      ),
    );
  }

  Widget _legBody(
      BuildContext context, ColorScheme scheme, TextTheme text, RouteId? route) {
    switch (leg.kind) {
      case TripLegKind.walk:
        final target = leg.toStop?.name ?? 'your destination';
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(leg.toStop == null ? 'Walk to destination' : 'Walk to $target',
                style: text.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 2),
            Text(
              '${leg.durationMinutes} min'
              '${leg.distanceMetres != null ? " • ${_miles(leg.distanceMetres!)}" : ""}',
              style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
            if (leg.fromStop != null || leg.toStop != null)
              _WalkingDirections(leg: leg),
          ],
        );
      case TripLegKind.transfer:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Transfer at ${leg.toStop?.name ?? "the next stop"}',
                style: text.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 2),
            Text('${leg.durationMinutes} min transfer time',
                style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
          ],
        );
      case TripLegKind.ride:
        final name = route == null ? 'Bus' : routeNames[route]!;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(name,
                style: text.bodyMedium
                    ?.copyWith(fontWeight: FontWeight.w700, color: route == null ? null : routeColors[route])),
            const SizedBox(height: 2),
            Text(
              'Board ${leg.fromStop?.name ?? ""} at ${formatClock(leg.startMinutes)}. '
              'Get off at ${leg.toStop?.name ?? ""} at ${formatClock(leg.endMinutes)}.',
              style: text.bodySmall,
            ),
            const SizedBox(height: 2),
            Text('${leg.durationMinutes} min ride • ${leg.stopCount ?? 0} stops',
                style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
          ],
        );
    }
  }

  static String _miles(double metres) {
    final miles = metres / 1609.34;
    return miles < 0.1 ? 'nearby' : '${miles.toStringAsFixed(1)} mi';
  }
}

/// Turn-by-turn for a walk leg. Only requests directions when opened, so a plan
/// nobody expands costs nothing.
class _WalkingDirections extends ConsumerStatefulWidget {
  const _WalkingDirections({required this.leg});
  final TripLeg leg;

  @override
  ConsumerState<_WalkingDirections> createState() => _WalkingDirectionsState();
}

class _WalkingDirectionsState extends ConsumerState<_WalkingDirections> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final stop = widget.leg.toStop ?? widget.leg.fromStop;
    if (stop == null) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: TextButton.icon(
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              alignment: Alignment.centerLeft,
              tapTargetSize: MaterialTapTargetSize.padded,
            ),
            onPressed: () => setState(() => _open = !_open),
            icon: Icon(
                _open ? Icons.arrow_drop_down_rounded : Icons.arrow_right_rounded,
                size: 20),
            label: const Text('Walking directions'),
          ),
        ),
        if (_open) _steps(context, scheme, text, stop),
      ],
    );
  }

  Widget _steps(
      BuildContext context, ColorScheme scheme, TextTheme text, PatternStop stop) {
    final leg = WalkLeg(
      fromLat: widget.leg.fromStop?.lat ?? stop.lat,
      fromLng: widget.leg.fromStop?.lng ?? stop.lng,
      toLat: widget.leg.toStop?.lat ?? stop.lat,
      toLng: widget.leg.toStop?.lng ?? stop.lng,
    );

    return ref.watch(walkingRouteProvider(leg)).when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: SizedBox(
                height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2)),
          ),
          error: (_, _) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text('Directions unavailable right now.',
                style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
          ),
          data: (route) {
            if (route.steps.isEmpty) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  route.isEstimate
                      ? 'Estimated walk — step-by-step directions are not available.'
                      : 'No turns; head straight there.',
                  style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                ),
              );
            }
            return Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final step in route.steps)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(top: 6, right: 8),
                            child: Container(
                              width: 5,
                              height: 5,
                              decoration: BoxDecoration(
                                  color: scheme.onSurfaceVariant,
                                  shape: BoxShape.circle),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              '${step.instruction} (${step.distanceMetres.round()} m)',
                              style: text.bodySmall,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            );
          },
        );
  }
}
