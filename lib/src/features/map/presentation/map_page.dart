import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../../../app/providers.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/constants/route_metadata.dart';
import '../../../core/constants/transit_ids.dart';
import '../../../core/utils/haversine.dart';
import '../../../core/utils/transfer_connections.dart';
import '../../../data/models/eta_result_model.dart';
import '../../../data/models/stop_model.dart';
import '../../../domain/usecases/schedule_adjustment_use_case.dart';

class MapPage extends ConsumerStatefulWidget {
  const MapPage({super.key});

  @override
  ConsumerState<MapPage> createState() => _MapPageState();
}

class _MapPageState extends ConsumerState<MapPage> {
  BusId? _lastBus;
  RouteId? _lastRoute;
  StopModel? _selectedStop;
  bool _etaRequested = false;
  bool _etaLoading = false;
  bool _etaInFlight = false;
  double? _userLat;
  double? _userLng;
  String? _locationError;
  String? _etaError;
  EtaResultModel? _eta;
  Timer? _etaTimer;

  @override
  void dispose() {
    _etaTimer?.cancel();
    super.dispose();
  }

  void _resetEtaState() {
    _etaTimer?.cancel();
    _etaRequested = false;
    _etaLoading = false;
    _etaInFlight = false;
    _etaError = null;
    _eta = null;
  }

  void _configureEtaTimer(BusId selectedBus) {
    _etaTimer?.cancel();
    if (!_etaRequested || _userLat == null || _userLng == null) {
      return;
    }

    _etaTimer = Timer.periodic(etaRefreshInterval, (_) {
      _fetchEta(selectedBus, silent: true);
    });
  }

  Future<bool> _requestLocation() async {
    _locationError = null;

    final servicesEnabled = await Geolocator.isLocationServiceEnabled();
    if (!servicesEnabled) {
      if (!mounted) {
        return false;
      }
      setState(() {
        _locationError = 'Location services are disabled.';
      });
      return false;
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      if (!mounted) {
        return false;
      }
      setState(() {
        _locationError =
            'Location permission denied. Enable location to calculate ETA.';
      });
      return false;
    }

    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );

      if (!mounted) {
        return false;
      }
      setState(() {
        _userLat = position.latitude;
        _userLng = position.longitude;
        _locationError = null;
      });
      return true;
    } catch (_) {
      if (!mounted) {
        return false;
      }
      setState(() {
        _locationError = 'Unable to read your current location.';
      });
      return false;
    }
  }

  Future<void> _fetchEta(BusId selectedBus, {required bool silent}) async {
    if (_etaInFlight || _userLat == null || _userLng == null) {
      return;
    }

    _etaInFlight = true;
    if (!silent && mounted) {
      setState(() {
        _etaLoading = true;
        _etaError = null;
      });
    }

    try {
      final repository = ref.read(transitRepositoryProvider);
      final result = await repository.getEta(
        busId: selectedBus.value,
        userLat: _userLat!,
        userLng: _userLng!,
      );

      if (!mounted) {
        return;
      }
      setState(() {
        _eta = result;
        _etaLoading = false;
        _etaError = null;
        _etaRequested = true;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _etaLoading = false;
        _etaError = 'ETA unavailable: $error';
      });
    } finally {
      _etaInFlight = false;
    }
  }

  Future<void> _onRequestEta(BusId selectedBus) async {
    if (_userLat == null || _userLng == null) {
      final ok = await _requestLocation();
      if (!ok) {
        return;
      }
    }

    if (!mounted) {
      return;
    }
    setState(() {
      _etaRequested = true;
    });
    _configureEtaTimer(selectedBus);
    await _fetchEta(selectedBus, silent: false);
  }

  @override
  Widget build(BuildContext context) {
    final selectedRoute = ref.watch(selectedRouteProvider);
    final selectedBus = ref.watch(selectedBusProvider);
    final routesAsync = ref.watch(routesProvider);
    final stopsAsync = ref.watch(stopsBySelectedRouteProvider);
    final allStopsByRouteAsync = ref.watch(allStopsByRouteProvider);
    final busAsync = ref.watch(busLocationPollingProvider);
    final busStatus = ref.watch(busStatusProvider);

    if (_lastBus != selectedBus) {
      _lastBus = selectedBus;
      _resetEtaState();
    }
    if (_lastRoute != selectedRoute) {
      _lastRoute = selectedRoute;
      _selectedStop = null;
    }

    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Live Map',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
                  ),
                ),
                Chip(
                  label: Text(routeNames[selectedRoute] ?? selectedRoute.value),
                  avatar: CircleAvatar(
                    backgroundColor: routeColors[selectedRoute],
                    radius: 7,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 56,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              scrollDirection: Axis.horizontal,
              itemBuilder: (context, index) {
                final route = RouteId.values[index];
                final selected = route == selectedRoute;
                return ChoiceChip(
                  selected: selected,
                  label: Text(routeNames[route] ?? route.value),
                  onSelected: (_) {
                    ref.read(selectedRouteProvider.notifier).state = route;
                    ref.read(selectedBusProvider.notifier).state =
                        routeBusMap[route]!.first;
                  },
                );
              },
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemCount: RouteId.values.length,
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: routesAsync.when(
              data: (routes) {
                final busLocation = busAsync.asData?.value;
                final selectedCenter = busLocation != null
                    ? LatLng(busLocation.lat, busLocation.lng)
                    : const LatLng(31.3271, -89.2903);

                final polylineLayers = routes
                    .map((route) {
                      final routeId = RouteId.fromValue(route.routeId);
                      final points = route.polyline
                          .where((pair) => pair.length == 2)
                          .map((pair) => LatLng(pair[0], pair[1]))
                          .toList(growable: false);

                      return Polyline(
                        points: points,
                        strokeWidth: routeId == selectedRoute ? 4 : 2,
                        color: routeColors[routeId]!.withValues(
                          alpha: routeId == selectedRoute ? 0.92 : 0.22,
                        ),
                      );
                    })
                    .toList(growable: false);

                final stopMarkers =
                    stopsAsync.asData?.value
                        .map(
                          (stop) => Marker(
                            point: LatLng(stop.lat, stop.lng),
                            width: 20,
                            height: 20,
                            child: GestureDetector(
                              onTap: () {
                                setState(() {
                                  _selectedStop = stop;
                                });
                              },
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  color: _selectedStop?.stopId == stop.stopId
                                      ? Colors.white
                                      : routeColors[selectedRoute],
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: _selectedStop?.stopId == stop.stopId
                                        ? routeColors[selectedRoute]!
                                        : Colors.white,
                                    width: 2,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        )
                        .toList(growable: false) ??
                    const <Marker>[];

                final busMarker = busLocation == null
                    ? const <Marker>[]
                    : [
                        Marker(
                          point: LatLng(busLocation.lat, busLocation.lng),
                          width: 26,
                          height: 26,
                          child: const Icon(
                            Icons.directions_bus,
                            color: Colors.black,
                            size: 24,
                          ),
                        ),
                      ];

                return Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Stack(
                      children: [
                        FlutterMap(
                          options: MapOptions(
                            initialCenter: selectedCenter,
                            initialZoom: 13,
                            minZoom: 11,
                            maxZoom: 18,
                          ),
                          children: [
                            TileLayer(
                              urlTemplate:
                                  'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                              userAgentPackageName: 'com.hubcitytransit',
                            ),
                            PolylineLayer(polylines: polylineLayers),
                            MarkerLayer(markers: stopMarkers),
                            MarkerLayer(markers: busMarker),
                          ],
                        ),
                        Positioned(
                          left: 10,
                          right: 10,
                          top: 10,
                          child: Card(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              child: busAsync.when(
                                data: (location) {
                                  if (location == null) {
                                    return Text(
                                      'Status: ${_statusLabel(busStatus)}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    );
                                  }
                                  return Text(
                                    'Status: ${_statusLabel(busStatus)} · ${selectedBus.value} · ${location.lat.toStringAsFixed(5)}, ${location.lng.toStringAsFixed(5)}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  );
                                },
                                loading: () => const Text(
                                  'Connecting to live bus feed...',
                                ),
                                error: (error, _) =>
                                    Text('Bus feed error: $error'),
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          left: 10,
                          right: 10,
                          bottom: 10,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (_selectedStop != null)
                                Card(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 10,
                                    ),
                                    child: _buildStopDetailCard(
                                      selectedRoute: selectedRoute,
                                      allStopsByRouteAsync: allStopsByRouteAsync,
                                    ),
                                  ),
                                ),
                              Card(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 10,
                                  ),
                                  child: _buildEtaCard(selectedBus),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) =>
                  Center(child: Text('Failed to load map data: $error')),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEtaCard(BusId selectedBus) {
    if (_userLat == null || _userLng == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Enable location for ETA',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          if (_locationError != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                _locationError!,
                style: const TextStyle(color: Colors.redAccent),
              ),
            ),
          OutlinedButton.icon(
            onPressed: _requestLocation,
            icon: const Icon(Icons.my_location),
            label: const Text('Enable location'),
          ),
        ],
      );
    }

    if (!_etaRequested) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Check ETA to nearest stop',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          FilledButton.icon(
            onPressed: () => _onRequestEta(selectedBus),
            icon: const Icon(Icons.schedule),
            label: const Text('Get ETA'),
          ),
        ],
      );
    }

    if (_etaLoading) {
      return const Text('Calculating ETA...');
    }

    if (_etaError != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_etaError!, style: const TextStyle(color: Colors.redAccent)),
          const SizedBox(height: 6),
          OutlinedButton(
            onPressed: () => _onRequestEta(selectedBus),
            child: const Text('Retry ETA'),
          ),
        ],
      );
    }

    if (_eta == null) {
      return OutlinedButton(
        onPressed: () => _onRequestEta(selectedBus),
        child: const Text('Refresh ETA'),
      );
    }

    final eta = _eta!;
    if (eta.status == 'bus-offline') {
      return Row(
        children: [
          const Expanded(
            child: Text(
              'Bus offline. Location data unavailable.',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          IconButton(
            onPressed: () => _onRequestEta(selectedBus),
            icon: const Icon(Icons.refresh),
          ),
        ],
      );
    }

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                eta.etaMinutes == null
                    ? 'ETA unavailable'
                    : '${eta.etaMinutes} min ETA',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
              if (eta.nearestStopName != null)
                Text(
                  'Nearest stop: ${eta.nearestStopName}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
            ],
          ),
        ),
        IconButton(
          onPressed: () => _onRequestEta(selectedBus),
          icon: const Icon(Icons.refresh),
        ),
      ],
    );
  }

  Widget _buildStopDetailCard({
    required RouteId selectedRoute,
    required AsyncValue<Map<RouteId, List<StopModel>>> allStopsByRouteAsync,
  }) {
    final stop = _selectedStop;
    if (stop == null) {
      return const SizedBox.shrink();
    }

    final distanceMeters = (_userLat == null || _userLng == null)
        ? null
        : haversineMeters(_userLat!, _userLng!, stop.lat, stop.lng);

    final subtitle = <String>[stop.direction, 'Stop #${stop.stopId}'];
    if (distanceMeters != null) {
      if (distanceMeters < 1000) {
        subtitle.add('${distanceMeters.round()}m away');
      } else {
        subtitle.add('${(distanceMeters / 1000).toStringAsFixed(1)}km away');
      }
      final walkMins = (distanceMeters / 80).round().clamp(1, 999);
      subtitle.add('~$walkMins min walk');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    stop.location,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle.join(' · '),
                    style: const TextStyle(color: Colors.black54, fontSize: 12),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: () {
                setState(() {
                  _selectedStop = null;
                });
              },
              icon: const Icon(Icons.close),
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
        const SizedBox(height: 8),
        allStopsByRouteAsync.when(
          data: (allStopsByRoute) {
            final connections = findTransferConnections(
              selectedRoute: selectedRoute,
              stop: stop,
              allStopsByRoute: allStopsByRoute,
            );
            if (connections.isEmpty) {
              return const Text(
                'No transfer connections at this stop.',
                style: TextStyle(fontSize: 12, color: Colors.black54),
              );
            }

            return Wrap(
              spacing: 8,
              runSpacing: 8,
              children: connections
                  .map(
                    (connection) => ActionChip(
                      backgroundColor:
                          routeColors[connection.routeId]!.withValues(alpha: 0.18),
                      avatar: CircleAvatar(
                        radius: 7,
                        backgroundColor: routeColors[connection.routeId],
                      ),
                      label: Text(routeNames[connection.routeId]!),
                      onPressed: () {
                        ref.read(selectedRouteProvider.notifier).state =
                            connection.routeId;
                        ref.read(selectedBusProvider.notifier).state =
                            routeBusMap[connection.routeId]!.first;
                        setState(() {
                          _selectedStop = null;
                        });
                      },
                    ),
                  )
                  .toList(growable: false),
            );
          },
          loading: () => const SizedBox(
            height: 18,
            width: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          error: (_, _) => const Text(
            'Transfer data unavailable right now.',
            style: TextStyle(fontSize: 12, color: Colors.black54),
          ),
        ),
      ],
    );
  }
}

String _statusLabel(BusStatus status) {
  switch (status) {
    case BusStatus.live:
      return 'Live';
    case BusStatus.connecting:
      return 'Connecting';
    case BusStatus.offline:
      return 'Offline';
  }
}
