import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../data/models/transit_dataset.dart';
import '../../../domain/usecases/trip_planner.dart';
import '../application/active_trip.dart';
import '../application/trip_planner_providers.dart';
import 'itinerary_card.dart';
import 'trip_place_field.dart';

enum _TimeMode { leaveNow, leaveAt, arriveBy }

class TripPlannerPage extends ConsumerStatefulWidget {
  const TripPlannerPage({super.key});

  @override
  ConsumerState<TripPlannerPage> createState() => _TripPlannerPageState();
}

class _TripPlannerPageState extends ConsumerState<TripPlannerPage> {
  TripPlace? _from;
  TripPlace? _to;
  _TimeMode _mode = _TimeMode.leaveNow;
  TimeOfDay? _pickedTime;
  TripQuery? _query;

  bool get _canPlan => _from != null && _to != null;

  void _plan() {
    final from = _from;
    final to = _to;
    if (from == null || to == null) return;

    final now = DateTime.now();
    final time = _pickedTime ?? TimeOfDay.fromDateTime(now);
    final when = _mode == _TimeMode.leaveNow
        ? now
        : DateTime(now.year, now.month, now.day, time.hour, time.minute);

    setState(() {
      _query = TripQuery(
        originLat: from.lat,
        originLng: from.lng,
        destLat: to.lat,
        destLng: to.lng,
        when: when,
        arriveBy: _mode == _TimeMode.arriveBy,
        originLabel: from.label,
        destLabel: to.label,
      );
    });
  }

  void _swap() {
    setState(() {
      final held = _from;
      _from = _to;
      _to = held;
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    // Arriving from a landmark tap on the map. Consumed so returning to the tab
    // later does not silently re-apply an old destination.
    ref.listen<PendingDestination?>(pendingDestinationProvider, (_, next) {
      if (next == null) return;
      setState(() => _to = TripPlace(
            label: next.label,
            lat: next.lat,
            lng: next.lng,
          ));
      ref.read(pendingDestinationProvider.notifier).state = null;
    });

    return Scaffold(
      appBar: AppBar(title: const Text('Plan a trip')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Column(
                    children: [
                      TripPlaceField(
                        label: 'From',
                        value: _from,
                        allowCurrentLocation: true,
                        onChanged: (place) => setState(() => _from = place),
                      ),
                      const SizedBox(height: 10),
                      TripPlaceField(
                        label: 'To',
                        value: _to,
                        onChanged: (place) => setState(() => _to = place),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 8, bottom: 4),
                  child: IconButton.filledTonal(
                    icon: const Icon(Icons.swap_vert_rounded),
                    tooltip: 'Swap start and destination',
                    onPressed: _from == null && _to == null ? null : _swap,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _ModeSelector(
              mode: _mode,
              onChanged: (mode) => setState(() => _mode = mode),
            ),
            if (_mode != _TimeMode.leaveNow) ...[
              const SizedBox(height: 12),
              _TimeField(
                label: _mode == _TimeMode.arriveBy ? 'Arrive by' : 'Leave at',
                time: _pickedTime ?? TimeOfDay.now(),
                onChanged: (time) => setState(() => _pickedTime = time),
              ),
            ],
            const SizedBox(height: 16),
            SizedBox(
              height: 52,
              child: FilledButton(
                onPressed: _canPlan ? _plan : null,
                child: const Text('Plan my trip'),
              ),
            ),
            const SizedBox(height: 20),
            if (_query case final TripQuery query)
              _Results(query: query)
            else
              Padding(
                padding: const EdgeInsets.only(top: 24),
                child: Text(
                  'Choose a starting point and a destination.',
                  textAlign: TextAlign.center,
                  style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ModeSelector extends StatelessWidget {
  const _ModeSelector({required this.mode, required this.onChanged});

  final _TimeMode mode;
  final ValueChanged<_TimeMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<_TimeMode>(
      segments: const [
        ButtonSegment(value: _TimeMode.leaveNow, label: Text('Leave now')),
        ButtonSegment(value: _TimeMode.leaveAt, label: Text('Leave at')),
        ButtonSegment(value: _TimeMode.arriveBy, label: Text('Arrive by')),
      ],
      selected: {mode},
      showSelectedIcon: false,
      onSelectionChanged: (set) => onChanged(set.first),
    );
  }
}

class _TimeField extends StatelessWidget {
  const _TimeField({
    required this.label,
    required this.time,
    required this.onChanged,
  });

  final String label;
  final TimeOfDay time;
  final ValueChanged<TimeOfDay> onChanged;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 52),
      child: OutlinedButton.icon(
        icon: const Icon(Icons.schedule_rounded, size: 20),
        label: Align(
          alignment: Alignment.centerLeft,
          child: Text('$label  ${time.format(context)}'),
        ),
        onPressed: () async {
          final picked =
              await showTimePicker(context: context, initialTime: time);
          if (picked != null) onChanged(picked);
        },
      ),
    );
  }
}

class _Results extends ConsumerWidget {
  const _Results({required this.query});

  final TripQuery query;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return ref.watch(tripPlanProvider(query)).when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 32),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (_, _) => const _Message(
            icon: Icons.error_outline_rounded,
            title: 'Could not plan this trip',
            body: 'Something went wrong reading the timetable. Try again.',
          ),
          data: (result) {
            if (!result.hasResults) {
              return _Message(
                icon: switch (result.failure) {
                  TripPlanFailure.outsideServiceDays => Icons.event_busy_rounded,
                  TripPlanFailure.noServiceAtTime => Icons.schedule_rounded,
                  TripPlanFailure.noNearbyStops => Icons.location_off_rounded,
                  _ => Icons.search_off_rounded,
                },
                title: switch (result.failure) {
                  TripPlanFailure.outsideServiceDays => 'No service today',
                  TripPlanFailure.noServiceAtTime => 'No buses at that time',
                  TripPlanFailure.noNearbyStops => 'No stops nearby',
                  _ => 'No route found',
                },
                body: _failureBody(result),
                walkOnly: result.walkOnlyMinutes,
              );
            }

            final walkOnly = result.walkOnlyMinutes;
            final best = result.itineraries.first;
            final walkingBeatsRiding =
                walkOnly != null && walkOnly <= best.durationMinutes;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${result.itineraries.length} option'
                    '${result.itineraries.length == 1 ? "" : "s"}',
                    style: text.titleSmall
                        ?.copyWith(color: scheme.onSurfaceVariant)),
                const SizedBox(height: 10),
                for (var i = 0; i < result.itineraries.length; i++) ...[
                  ItineraryCard(
                    itinerary: result.itineraries[i],
                    label: i == 0 ? 'Recommended route' : _altLabel(result, i),
                    highlight: i == 0,
                    onShowOnMap: () {
                      ref.read(activeTripProvider.notifier).state = PlannedTrip(
                        itinerary: result.itineraries[i],
                        originLat: query.originLat,
                        originLng: query.originLng,
                        destLat: query.destLat,
                        destLng: query.destLng,
                        originLabel: query.originLabel,
                        destLabel: query.destLabel,
                      );
                      StatefulNavigationShell.of(context).goBranch(0);
                    },
                    footnote: i == 0 && walkingBeatsRiding
                        ? 'Walking the whole way takes about $walkOnly min, '
                            'which may be quicker than waiting.'
                        : null,
                  ),
                  const SizedBox(height: 12),
                ],
              ],
            );
          },
        );
  }

  String _altLabel(TripPlanResult result, int index) {
    final here = result.itineraries[index];
    final best = result.itineraries.first;
    if (here.totalWalkMetres < best.totalWalkMetres) return 'Least walking';
    if (here.transferCount < best.transferCount) return 'Fewest transfers';
    if (here.departureMinutes > best.departureMinutes) return 'Leave later';
    return 'Alternative route';
  }

  String _failureBody(TripPlanResult result) {
    final next = result.nextServiceMinutes;
    switch (result.failure) {
      case TripPlanFailure.outsideServiceDays:
        return 'Hub City Transit runs weekdays only.'
            '${next != null ? " Next buses start at ${formatClock(next)} on Monday." : ""}';
      case TripPlanFailure.noServiceAtTime:
        return 'Service has finished for the day.'
            '${next != null ? " The first bus tomorrow is at ${formatClock(next)}." : ""}';
      case TripPlanFailure.noNearbyStops:
        return 'There is no bus stop close enough to one end of this trip.';
      default:
        return 'No combination of routes connects these two places.';
    }
  }
}

class _Message extends StatelessWidget {
  const _Message({
    required this.icon,
    required this.title,
    required this.body,
    this.walkOnly,
  });

  final IconData icon;
  final String title;
  final String body;
  final int? walkOnly;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        children: [
          Icon(icon, size: 36, color: scheme.onSurfaceVariant),
          const SizedBox(height: 12),
          Text(title, textAlign: TextAlign.center, style: text.titleMedium),
          const SizedBox(height: 6),
          Text(body,
              textAlign: TextAlign.center,
              style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
          if (walkOnly != null) ...[
            const SizedBox(height: 12),
            Text('Walking the whole way takes about $walkOnly min.',
                textAlign: TextAlign.center,
                style: text.bodySmall?.copyWith(color: scheme.onSurface)),
          ],
        ],
      ),
    );
  }
}
