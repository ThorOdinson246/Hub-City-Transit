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

class MapPage extends ConsumerStatefulWidget {
  const MapPage({super.key});

  @override
  ConsumerState<MapPage> createState() => _MapPageState();
}

class _MapPageState extends ConsumerState<MapPage> {
  BusId? _lastBus;
  RouteId? _lastRoute;
  StopModel? _selectedStop;
  bool _showFabMenu = false;
  bool _mapUiVisible = true;
  bool _etaRequested = false;
  bool _etaLoading = false;
  bool _etaInFlight = false;
  double? _userLat;
  double? _userLng;
  String? _locationError;
  String? _etaError;
  EtaResultModel? _eta;
  Timer? _etaTimer;
  Timer? _uiRestoreTimer;

  @override
  void dispose() {
    _etaTimer?.cancel();
    _uiRestoreTimer?.cancel();
    super.dispose();
  }

  void _handleMapGesture(bool hasGesture) {
    if (hasGesture) {
      _uiRestoreTimer?.cancel();
      if (_mapUiVisible) {
        setState(() {
          _mapUiVisible = false;
          _showFabMenu = false;
        });
      }
      return;
    }

    _uiRestoreTimer?.cancel();
    _uiRestoreTimer = Timer(const Duration(milliseconds: 450), () {
      if (!mounted) {
        return;
      }
      setState(() {
        _mapUiVisible = true;
      });
    });
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

    if (_lastBus != selectedBus) {
      _lastBus = selectedBus;
      _resetEtaState();
    }
    if (_lastRoute != selectedRoute) {
      _lastRoute = selectedRoute;
      _selectedStop = null;
    }

    return routesAsync.when(
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
                          width: 68,
                          height: 52,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: routeColors[selectedRoute],
                                  borderRadius: BorderRadius.circular(999),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Color(0x1A000000),
                                      blurRadius: 6,
                                      offset: Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Text(
                                  selectedBus.value.toUpperCase(),
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 3),
                              Container(
                                width: 26,
                                height: 26,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: routeColors[selectedRoute]!,
                                    width: 2,
                                  ),
                                ),
                                child: Icon(
                                  Icons.directions_bus_rounded,
                                  size: 16,
                                  color: routeColors[selectedRoute],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ];
                return Stack(
                  children: [
                    Positioned.fill(
                      child: FlutterMap(
                        options: MapOptions(
                          initialCenter: selectedCenter,
                          initialZoom: 13,
                          minZoom: 11,
                          maxZoom: 18,
                          onPositionChanged: (_, hasGesture) {
                            _handleMapGesture(hasGesture);
                          },
                        ),
                        children: [
                          TileLayer(
                            urlTemplate:
                                'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png',
                            subdomains: const ['a', 'b', 'c', 'd'],
                            userAgentPackageName: 'com.hubcitytransit',
                          ),
                          PolylineLayer(polylines: polylineLayers),
                          MarkerLayer(markers: stopMarkers),
                          MarkerLayer(markers: busMarker),
                        ],
                      ),
                    ),
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: SafeArea(
                        bottom: false,
                        child: AnimatedSlide(
                          offset: _mapUiVisible ? Offset.zero : const Offset(0, -1),
                          duration: const Duration(milliseconds: 220),
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                            child: Column(
                              children: [
                                Container(
                                  height: 56,
                                  padding: const EdgeInsets.symmetric(horizontal: 10),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.93),
                                    borderRadius: BorderRadius.circular(18),
                                    border: Border.all(color: const Color(0xFFC5C6CA)),
                                  ),
                                  child: Row(
                                    children: [
                                      IconButton(
                                        onPressed: () {},
                                        icon: const Icon(Icons.menu_rounded),
                                      ),
                                      const Expanded(
                                        child: Text(
                                          'Hub City Transit',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            fontSize: 17,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ),
                                      IconButton(
                                        onPressed: () {},
                                        icon: const Icon(Icons.account_circle_outlined),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 10),
                                SizedBox(
                                  height: 46,
                                  child: ListView.separated(
                                    scrollDirection: Axis.horizontal,
                                    itemCount: RouteId.values.length,
                                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                                    itemBuilder: (context, index) {
                                      final route = RouteId.values[index];
                                      final selected = route == selectedRoute;
                                      return ChoiceChip(
                                        showCheckmark: false,
                                        selected: selected,
                                        label: Text(routeNames[route] ?? route.value),
                                        selectedColor: const Color(0xFF000101),
                                        labelStyle: TextStyle(
                                          color: selected
                                              ? Colors.white
                                              : const Color(0xFF44474A),
                                          fontWeight: FontWeight.w700,
                                        ),
                                        onSelected: (_) {
                                          ref.read(selectedRouteProvider.notifier).state =
                                              route;
                                          ref.read(selectedBusProvider.notifier).state =
                                              routeBusMap[route]!.first;
                                        },
                                      );
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      right: 12,
                      bottom: 154,
                      child: AnimatedOpacity(
                        opacity: _mapUiVisible ? 1 : 0,
                        duration: const Duration(milliseconds: 200),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            if (_showFabMenu) ...[
                              _MapActionButton(
                                label: 'Show all routes',
                                icon: Icons.layers_rounded,
                                onTap: () {
                                  setState(() {
                                    _showFabMenu = false;
                                  });
                                },
                              ),
                              const SizedBox(height: 8),
                              _MapActionButton(
                                label: 'Nearby stops',
                                icon: Icons.location_on_rounded,
                                onTap: () {
                                  setState(() {
                                    _showFabMenu = false;
                                  });
                                },
                              ),
                              const SizedBox(height: 8),
                              _MapActionButton(
                                label: 'Search route',
                                icon: Icons.search_rounded,
                                onTap: () {
                                  setState(() {
                                    _showFabMenu = false;
                                  });
                                },
                              ),
                              const SizedBox(height: 10),
                            ],
                            FloatingActionButton(
                              heroTag: 'map-menu-fab',
                              backgroundColor: const Color(0xFF000101),
                              foregroundColor: Colors.white,
                              onPressed: () {
                                setState(() {
                                  _showFabMenu = !_showFabMenu;
                                  _mapUiVisible = true;
                                });
                              },
                              child: Icon(
                                _showFabMenu ? Icons.close_rounded : Icons.route_rounded,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Positioned(
                      left: 12,
                      right: 12,
                      bottom: 10,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_selectedStop != null)
                            Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.97),
                                borderRadius: BorderRadius.circular(24),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Color(0x22000000),
                                    blurRadius: 18,
                                    offset: Offset(0, 10),
                                  ),
                                ],
                              ),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 12,
                                ),
                                child: _buildStopDetailCard(
                                  selectedRoute: selectedRoute,
                                  allStopsByRouteAsync: allStopsByRouteAsync,
                                ),
                              ),
                            ),
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.97),
                              borderRadius: BorderRadius.circular(16),
                            ),
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
                );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(child: Text('Failed to load map data: $error')),
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

    final routeLabel = routeNames[selectedRoute] ?? selectedRoute.name;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Align(
          alignment: Alignment.topCenter,
          child: Container(
            width: 44,
            height: 4,
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFD1D5DB),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
        ),
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
                  const SizedBox(height: 2),
                  Text(subtitle.join('  ·  '), style: const TextStyle(fontSize: 12)),
                ],
              ),
            ),
            _RoutePill(label: routeLabel, color: routeColors[selectedRoute]!),
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

            final routeStops = ref.read(stopsBySelectedRouteProvider).asData?.value ?? const <StopModel>[];
            final selectedIdx = routeStops.indexWhere((s) => s.stopId == stop.stopId);
            final nextStops = selectedIdx < 0
                ? const <StopModel>[]
                : routeStops.skip(selectedIdx + 1).take(3).toList(growable: false);

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (connections.isNotEmpty)
                  Wrap(
              spacing: 8,
              runSpacing: 8,
              children: connections
                  .map(
                    (connection) => ActionChip(
                      backgroundColor: routeColors[connection.routeId]!
                          .withValues(alpha: 0.18),
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
                  ),
                if (nextStops.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  const Text('Next Stops', style: TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  ...nextStops.map(
                    (next) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        children: [
                          const Icon(Icons.radio_button_unchecked, size: 16),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              next.location,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
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

class _RoutePill extends StatelessWidget {
  const _RoutePill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: 6),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _MapActionButton extends StatelessWidget {
  const _MapActionButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(999),
      elevation: 2,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(width: 8),
              Icon(icon, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}
