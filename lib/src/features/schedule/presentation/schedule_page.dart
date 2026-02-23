import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/constants/route_metadata.dart';
import '../../../core/utils/transfer_connections.dart';

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

    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Schedule',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
                  ),
                ),
                Text(routeNames[route] ?? route.value),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Search stops',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
                isDense: true,
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
                  onSelected: (value) {
                    setState(() {
                      transferOnly = value;
                    });
                  },
                  label: const Text('Transfer stops only'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Expanded(
            child: stopsAsync.when(
              data: (stops) {
                final transferMap = allStopsByRouteAsync.maybeWhen(
                  data: (allStopsByRoute) {
                    final map = <String, List<TransferStopConnection>>{};
                    for (final stop in stops) {
                      map['${stop.stopId}:${stop.location}'] =
                          findTransferConnections(
                        selectedRoute: route,
                        stop: stop,
                        allStopsByRoute: allStopsByRoute,
                      );
                    }
                    return map;
                  },
                  orElse: () => const <String, List<TransferStopConnection>>{},
                );

                final filtered = stops.where((stop) {
                  final matchesQuery =
                      query.isEmpty ||
                      stop.location.toLowerCase().contains(query);
                  if (!matchesQuery) {
                    return false;
                  }
                  if (!transferOnly) {
                    return true;
                  }
                  final key = '${stop.stopId}:${stop.location}';
                  final hasTransfer = (transferMap[key] ?? const []).isNotEmpty;
                  return hasTransfer;
                }).toList(growable: false);

                if (filtered.isEmpty) {
                  return const Center(child: Text('No matching stops'));
                }

                return ListView.separated(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  itemBuilder: (context, index) {
                    final stop = filtered[index];
                    final transferConnections =
                        transferMap['${stop.stopId}:${stop.location}'] ??
                        const <TransferStopConnection>[];
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                      ),
                      leading: CircleAvatar(child: Text('${stop.stopId}')),
                      title: Text(stop.location),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(stop.direction),
                          if (transferConnections.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: transferConnections
                                    .map(
                                      (connection) => Chip(
                                        visualDensity: VisualDensity.compact,
                                        materialTapTargetSize:
                                            MaterialTapTargetSize.shrinkWrap,
                                        avatar: CircleAvatar(
                                          radius: 6,
                                          backgroundColor:
                                              routeColors[connection.routeId],
                                        ),
                                        label: Text(
                                          routeNames[connection.routeId] ??
                                              connection.routeId.name,
                                          style: const TextStyle(fontSize: 11),
                                        ),
                                      ),
                                    )
                                    .toList(growable: false),
                              ),
                            ),
                        ],
                      ),
                      isThreeLine: transferConnections.isNotEmpty,
                      trailing: const Icon(Icons.chevron_right),
                    );
                  },
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemCount: filtered.length,
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) =>
                  Center(child: Text('Failed to load stops: $error')),
            ),
          ),
        ],
      ),
    );
  }
}
