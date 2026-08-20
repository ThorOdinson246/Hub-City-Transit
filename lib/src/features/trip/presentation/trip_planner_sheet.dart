import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/transit_dataset.dart';
import '../../../domain/usecases/service_calendar.dart';
import '../../../domain/usecases/trip_planner.dart';
import '../application/active_trip.dart';
import '../application/trip_planner_providers.dart';
import 'itinerary_card.dart';
import 'trip_place_field.dart';

/// Whether the planner sheet is open over the map.
final plannerOpenProvider = StateProvider<bool>((ref) => false);

enum _TimeMode { leaveNow, leaveAt, arriveBy }

/// Trip planning as a sheet over the live map.
///
/// It was a separate tab, which meant planning blind, then a hidden "show on
/// map" button, then losing the itinerary on arrival. Keeping the map behind
/// means the route and the steps are readable at the same time.
class TripPlannerSheet extends ConsumerStatefulWidget {
  const TripPlannerSheet({super.key});

  @override
  ConsumerState<TripPlannerSheet> createState() => _TripPlannerSheetState();
}

class _TripPlannerSheetState extends ConsumerState<TripPlannerSheet> {
  final _controller = DraggableScrollableController();
  TripPlace? _from;
  TripPlace? _to;
  _TimeMode _mode = _TimeMode.leaveNow;
  TimeOfDay? _pickedTime;
  TripQuery? _query;

  bool get _canPlan => _from != null && _to != null;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _expand() {
    if (!_controller.isAttached) return;
    _controller.animateTo(0.92,
        duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
  }

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
    _expand();
  }

  void _close() {
    ref.read(plannerOpenProvider.notifier).state = false;
    ref.read(activeTripProvider.notifier).state = null;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    ref.listen<PendingDestination?>(pendingDestinationProvider, (_, next) {
      if (next == null) return;
      setState(() => _to =
          TripPlace(label: next.label, lat: next.lat, lng: next.lng));
      ref.read(pendingDestinationProvider.notifier).state = null;
      _expand();
    });

    return DraggableScrollableSheet(
      controller: _controller,
      initialChildSize: 0.5,
      minChildSize: 0.18,
      maxChildSize: 0.92,
      snap: true,
      snapSizes: const [0.18, 0.5, 0.92],
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: scheme.surfaceContainerLowest,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.16),
                blurRadius: 20,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: scheme.outlineVariant,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: Text('Plan a trip',
                        style: Theme.of(context).textTheme.titleLarge),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    tooltip: 'Close trip planner',
                    constraints:
                        const BoxConstraints(minWidth: 48, minHeight: 48),
                    onPressed: _close,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _form(scheme),
              const SizedBox(height: 18),
              if (_query case final TripQuery query)
                _Results(query: query, onShown: _collapseToHalf)
              else
                _hint(scheme),
            ],
          ),
        );
      },
    );
  }

  void _collapseToHalf() {
    if (!_controller.isAttached) return;
    _controller.animateTo(0.5,
        duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
  }

  Widget _hint(ColorScheme scheme) {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Text(
        'Choose a starting point and a destination.',
        textAlign: TextAlign.center,
        style: Theme.of(context)
            .textTheme
            .bodyMedium
            ?.copyWith(color: scheme.onSurfaceVariant),
      ),
    );
  }

  Widget _form(ColorScheme scheme) {
    return Column(
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
                    onFocused: _expand,
                  ),
                  const SizedBox(height: 10),
                  TripPlaceField(
                    label: 'To',
                    value: _to,
                    onChanged: (place) => setState(() => _to = place),
                    onFocused: _expand,
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 8, bottom: 4),
              child: IconButton.filledTonal(
                icon: const Icon(Icons.swap_vert_rounded),
                tooltip: 'Swap start and destination',
                onPressed: _from == null && _to == null
                    ? null
                    : () => setState(() {
                          final held = _from;
                          _from = _to;
                          _to = held;
                        }),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        SegmentedButton<_TimeMode>(
          segments: const [
            ButtonSegment(value: _TimeMode.leaveNow, label: Text('Leave now')),
            ButtonSegment(value: _TimeMode.leaveAt, label: Text('Leave at')),
            ButtonSegment(value: _TimeMode.arriveBy, label: Text('Arrive by')),
          ],
          selected: {_mode},
          showSelectedIcon: false,
          onSelectionChanged: (set) => setState(() => _mode = set.first),
        ),
        if (_mode != _TimeMode.leaveNow) ...[
          const SizedBox(height: 12),
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 52),
            child: OutlinedButton.icon(
              icon: const Icon(Icons.schedule_rounded, size: 20),
              label: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '${_mode == _TimeMode.arriveBy ? "Arrive by" : "Leave at"}'
                  '  ${(_pickedTime ?? TimeOfDay.now()).format(context)}',
                ),
              ),
              onPressed: () async {
                final picked = await showTimePicker(
                  context: context,
                  initialTime: _pickedTime ?? TimeOfDay.now(),
                );
                if (picked != null) setState(() => _pickedTime = picked);
              },
            ),
          ),
        ],
        const SizedBox(height: 14),
        SizedBox(
          height: 52,
          child: FilledButton(
            onPressed: _canPlan ? _plan : null,
            child: const Text('Plan my trip'),
          ),
        ),
      ],
    );
  }
}

class _Results extends ConsumerWidget {
  const _Results({required this.query, required this.onShown});

  final TripQuery query;
  final VoidCallback onShown;

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
                  TripPlanFailure.outsideServiceDays =>
                    result.serviceStatus?.holidayName ?? 'No service today',
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
            final walkWins =
                walkOnly != null && walkOnly <= best.durationMinutes;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${result.itineraries.length} option'
                  '${result.itineraries.length == 1 ? "" : "s"}',
                  style: text.titleSmall?.copyWith(color: scheme.onSurfaceVariant),
                ),
                const SizedBox(height: 10),
                for (var i = 0; i < result.itineraries.length; i++) ...[
                  ItineraryCard(
                    // Keyed by the itinerary, not the slot, so re-planning does
                    // not leave a card expanded on someone else's legs.
                    key: ValueKey(
                        '${result.itineraries[i].routeIds.join(">")}'
                        '@${result.itineraries[i].departureMinutes}'),
                    itinerary: result.itineraries[i],
                    label: i == 0 ? 'Recommended route' : _altLabel(result, i),
                    highlight: i == 0,
                    footnote: i == 0 && walkWins
                        ? 'Walking the whole way takes about $walkOnly min, '
                            'which may be quicker than waiting.'
                        : null,
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
                      onShown();
                    },
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
    final status = result.serviceStatus;
    final resumes = _resumesPhrase(status, next);

    switch (result.failure) {
      case TripPlanFailure.outsideServiceDays:
        final reason = status?.holidayName != null
            ? 'Hub City Transit does not run on ${status!.holidayName}.'
            : 'Hub City Transit runs weekdays only.';
        return '$reason$resumes';
      case TripPlanFailure.noServiceAtTime:
        final reason = status?.state == ServiceState.beforeFirstBus
            ? 'Buses have not started running yet today.'
            : 'Service has finished for the day.';
        return '$reason$resumes';
      case TripPlanFailure.noNearbyStops:
        return 'There is no bus stop close enough to one end of this trip.';
      default:
        return 'No combination of routes connects these two places.';
    }
  }

  String _resumesPhrase(ServiceStatus? status, int? nextMinutes) {
    final day = status?.nextServiceDay;
    if (day == null || nextMinutes == null) return '';
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final delta = day.difference(today).inDays;
    final when = switch (delta) {
      0 => 'today',
      1 => 'tomorrow',
      _ => _weekdayName(day.weekday),
    };
    return ' The next departure is $when at ${formatClock(nextMinutes)}.';
  }

  static String _weekdayName(int weekday) => const [
        'Monday',
        'Tuesday',
        'Wednesday',
        'Thursday',
        'Friday',
        'Saturday',
        'Sunday',
      ][weekday - 1];
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
