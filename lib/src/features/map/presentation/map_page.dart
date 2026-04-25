import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../../app/providers.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/constants/route_metadata.dart';
import '../../../core/constants/transit_ids.dart';
import '../../../core/utils/haversine.dart';
import '../../../data/models/eta_result_model.dart';
import '../../../data/models/route_polyline_model.dart';
import '../../../data/models/stop_model.dart';
import '../../../data/models/bus_location_model.dart';

class MapPage extends ConsumerStatefulWidget {
  const MapPage({super.key});

  @override
  ConsumerState<MapPage> createState() => _MapPageState();
}

class _MapPageState extends ConsumerState<MapPage> {
  final MapController _mapController = MapController();

  BusId? _lastBus;
  RouteId? _lastRoute;
  StopModel? _selectedStop;

  bool _showFabMenu = false;
  bool _showTopOverlay = true;
  bool _showAllRoutes = true;
  bool _etaRequested = false;
  bool _etaLoading = false;
  bool _etaInFlight = false;

  double? _userLat;
  double? _userLng;
  String? _locationError;
  String? _etaError;
  EtaResultModel? _eta;

  Timer? _etaTimer;
  Timer? _overlayTimer;

  @override
  void initState() {
    super.initState();
    unawaited(_syncUserLocation(forcePrompt: false, center: false));
  }

  @override
  void dispose() {
    _etaTimer?.cancel();
    _overlayTimer?.cancel();
    super.dispose();
  }

  Future<void> _syncUserLocation({
    required bool forcePrompt,
    required bool center,
  }) async {
    _locationError = null;

    final servicesEnabled = await Geolocator.isLocationServiceEnabled();
    if (!servicesEnabled) {
      if (!mounted) return;
      setState(() {
        _locationError = 'Location services are disabled.';
      });
      return;
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied && forcePrompt) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      if (!mounted) return;
      setState(() {
        _locationError = 'Location permission is off. Tap the location button.';
      });
      return;
    }

    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 12),
        ),
      );
      if (!mounted) return;

      setState(() {
        _userLat = position.latitude;
        _userLng = position.longitude;
        _locationError = null;
      });

      if (center) {
        _moveTo(position.latitude, position.longitude, 15.2);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _locationError = 'Unable to read your current location.';
      });
    }
  }

  void _moveTo(double lat, double lng, double zoom) {
    _mapController.move(LatLng(lat, lng), zoom);
  }

  void _handleMapGesture(bool hasGesture) {
    if (!hasGesture) {
      _overlayTimer?.cancel();
      _overlayTimer = Timer(const Duration(milliseconds: 420), () {
        if (!mounted) return;
        setState(() {
          _showTopOverlay = true;
        });
      });
      return;
    }

    _overlayTimer?.cancel();
    if (_showTopOverlay) {
      setState(() {
        _showTopOverlay = false;
        _showFabMenu = false;
      });
    }
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

  void _resetEtaState() {
    _etaTimer?.cancel();
    _etaRequested = false;
    _etaLoading = false;
    _etaInFlight = false;
    _etaError = null;
    _eta = null;
  }

  Future<void> _fetchEta(BusId selectedBus, {required bool silent}) async {
    if (_etaInFlight || _userLat == null || _userLng == null) return;

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
      if (!mounted) return;
      setState(() {
        _eta = result;
        _etaLoading = false;
        _etaError = null;
        _etaRequested = true;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _etaLoading = false;
        _etaError = 'ETA unavailable: $error';
      });
    } finally {
      _etaInFlight = false;
    }
  }

  Future<void> _onGetEta(BusId selectedBus) async {
    if (_userLat == null || _userLng == null) {
      await _syncUserLocation(forcePrompt: true, center: false);
      if (_userLat == null || _userLng == null) return;
    }

    if (!mounted) return;
    setState(() {
      _etaRequested = true;
    });
    _configureEtaTimer(selectedBus);
    await _fetchEta(selectedBus, silent: false);
  }

  StopModel? _nearestStop(List<StopModel> stops, {required double lat, required double lng}) {
    if (stops.isEmpty) return null;
    StopModel? nearest;
    var nearestMeters = double.infinity;

    for (final stop in stops) {
      final d = haversineMeters(lat, lng, stop.lat, stop.lng);
      if (d < nearestMeters) {
        nearestMeters = d;
        nearest = stop;
      }
    }
    return nearest;
  }

  Future<void> _openSearchSheet(Map<RouteId, List<StopModel>> allStopsByRoute) async {
    final route = ref.read(selectedRouteProvider);
    final routeStops = allStopsByRoute[route] ?? const <StopModel>[];

    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        var query = '';
        return StatefulBuilder(
          builder: (context, setModalState) {
            final filteredRoutes = RouteId.values.where((r) {
              final raw = (routeNames[r] ?? r.name).toLowerCase();
              return query.isEmpty || raw.contains(query);
            }).toList(growable: false);

            final filteredStops = routeStops.where((s) {
              final raw = '${s.location} ${s.stopId} ${s.direction}'.toLowerCase();
              return query.isEmpty || raw.contains(query);
            }).take(24).toList(growable: false);

            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    autofocus: true,
                    decoration: const InputDecoration(
                      hintText: 'Search stops or routes...',
                      prefixIcon: Icon(Icons.search_rounded),
                    ),
                    onChanged: (value) {
                      setModalState(() {
                        query = value.trim().toLowerCase();
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  Flexible(
                    child: ListView(
                      shrinkWrap: true,
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(bottom: 6),
                          child: Text('Routes', style: TextStyle(fontWeight: FontWeight.w700)),
                        ),
                        ...filteredRoutes.map(
                          (r) => ListTile(
                            dense: true,
                            leading: CircleAvatar(backgroundColor: routeColors[r], radius: 8),
                            title: Text(routeNames[r] ?? r.name),
                            onTap: () {
                              ref.read(selectedRouteProvider.notifier).state = r;
                              ref.read(selectedBusProvider.notifier).state = routeBusMap[r]!.first;
                              Navigator.of(context).pop();
                            },
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Padding(
                          padding: EdgeInsets.only(bottom: 6),
                          child: Text('Stops', style: TextStyle(fontWeight: FontWeight.w700)),
                        ),
                        ...filteredStops.map(
                          (s) => ListTile(
                            dense: true,
                            leading: const Icon(Icons.location_on_outlined),
                            title: Text(s.location, maxLines: 1, overflow: TextOverflow.ellipsis),
                            subtitle: Text('Stop #${s.stopId} · ${s.direction}'),
                            onTap: () {
                              setState(() {
                                _selectedStop = s;
                              });
                              _moveTo(s.lat, s.lng, 15.7);
                              Navigator.of(context).pop();
                            },
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
      },
    );
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

    return allStopsByRouteAsync.when(
      data: (allStopsByRoute) {
        final routeStops = stopsAsync.asData?.value ?? const <StopModel>[];
        return routesAsync.when(
          data: (routes) {
            final busLocation = busAsync.asData?.value;
            final centerLat = _userLat ?? busLocation?.lat ?? 31.3271;
            final centerLng = _userLng ?? busLocation?.lng ?? -89.2903;

            final lines = _buildPolylines(routes, selectedRoute);
            final stopMarkers = _buildStopMarkers(routeStops, selectedRoute);
            final busMarkers = _buildBusMarkers(
              selectedBus: selectedBus,
              selectedRoute: selectedRoute,
              routeStops: routeStops,
              busLocation: busLocation,
            );
            final userMarker = _buildUserMarker();

            return Stack(
              children: [
                Positioned.fill(
                  child: FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      initialCenter: LatLng(centerLat, centerLng),
                      initialZoom: 13.5,
                      minZoom: 10,
                      maxZoom: 19,
                      onPositionChanged: (_, hasGesture) => _handleMapGesture(hasGesture),
                    ),
                    children: [
                      TileLayer(
                        urlTemplate:
                            'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png',
                        subdomains: const ['a', 'b', 'c', 'd'],
                        userAgentPackageName: 'com.hubcitytransit',
                      ),
                      PolylineLayer(polylines: lines),
                      MarkerLayer(markers: stopMarkers),
                      MarkerLayer(markers: busMarkers),
                      if (userMarker != null) MarkerLayer(markers: [userMarker]),
                    ],
                  ),
                ),
                Positioned(
                  left: 12,
                  right: 12,
                  top: 0,
                  child: SafeArea(
                    bottom: false,
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 220),
                      child: _showTopOverlay
                          ? _TopSearchBar(
                              onTapSearch: () => _openSearchSheet(allStopsByRoute),
                              onTapSettings: () => context.push('/settings'),
                            )
                          : Align(
                              alignment: Alignment.topCenter,
                              child: FilledButton.tonalIcon(
                                key: const ValueKey('showOverlayBtn'),
                                onPressed: () {
                                  setState(() {
                                    _showTopOverlay = true;
                                  });
                                },
                                icon: const Icon(Icons.search_rounded),
                                label: const Text('Search stops or routes...'),
                              ),
                            ),
                    ),
                  ),
                ),
                Positioned(
                  right: 12,
                  bottom: 166,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if (_showFabMenu) ...[
                        _MapActionButton(
                          label: _showAllRoutes ? 'Show selected route' : 'Show all routes',
                          icon: Icons.layers_rounded,
                          onTap: () {
                            setState(() {
                              _showAllRoutes = !_showAllRoutes;
                              _showFabMenu = false;
                            });
                          },
                        ),
                        const SizedBox(height: 8),
                        _MapActionButton(
                          label: 'Nearby stop',
                          icon: Icons.location_on_rounded,
                          onTap: () {
                            if (_userLat != null && _userLng != null) {
                              final nearest = _nearestStop(
                                routeStops,
                                lat: _userLat!,
                                lng: _userLng!,
                              );
                              if (nearest != null) {
                                setState(() {
                                  _selectedStop = nearest;
                                });
                                _moveTo(nearest.lat, nearest.lng, 15.8);
                              }
                            }
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
                            _openSearchSheet(allStopsByRoute);
                          },
                        ),
                        const SizedBox(height: 10),
                      ],
                      GestureDetector(
                        onLongPress: () {
                          setState(() {
                            _showFabMenu = !_showFabMenu;
                            _showTopOverlay = true;
                          });
                        },
                        child: FloatingActionButton.small(
                          heroTag: 'location-fab',
                          backgroundColor: const Color(0xFF000101),
                          foregroundColor: Colors.white,
                          onPressed: () async {
                            await _syncUserLocation(forcePrompt: true, center: true);
                            if (_userLat != null && _userLng != null) {
                              final nearest = _nearestStop(
                                routeStops,
                                lat: _userLat!,
                                lng: _userLng!,
                              );
                              if (nearest != null && mounted) {
                                setState(() {
                                  _selectedStop = nearest;
                                });
                              }
                            }
                          },
                          child: const Icon(Icons.my_location_rounded),
                        ),
                      ),
                    ],
                  ),
                ),
                Positioned(
                  left: 10,
                  right: 10,
                  bottom: 8,
                  child: _BottomFlyer(
                    selectedRoute: selectedRoute,
                    selectedBus: selectedBus,
                    routeStops: routeStops,
                    selectedStop: _selectedStop,
                    userLat: _userLat,
                    userLng: _userLng,
                    locationError: _locationError,
                    eta: _eta,
                    etaLoading: _etaLoading,
                    etaError: _etaError,
                    busLocation: busLocation,
                    onRouteSelected: (route) {
                      ref.read(selectedRouteProvider.notifier).state = route;
                      ref.read(selectedBusProvider.notifier).state = routeBusMap[route]!.first;
                    },
                    onBusSelected: (bus) {
                      ref.read(selectedBusProvider.notifier).state = bus;
                      setState(() {
                        _selectedStop = null;
                      });
                    },
                    onRequestEta: () => _onGetEta(selectedBus),
                    onStopSelected: (stop) {
                      setState(() {
                        _selectedStop = stop;
                      });
                      _moveTo(stop.lat, stop.lng, 15.9);
                    },
                  ),
                ),
              ],
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(child: Text('Failed to load map data: $error')),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(child: Text('Failed to load map data: $error')),
    );
  }

  List<Polyline> _buildPolylines(List<RoutePolylineModel> routes, RouteId selectedRoute) {
    return routes
        .where((route) => _showAllRoutes || RouteId.fromValue(route.routeId) == selectedRoute)
        .map((route) {
          final routeId = RouteId.fromValue(route.routeId);
          final points = route.polyline
              .where((pair) => pair.length == 2)
              .map((pair) => LatLng(pair[0], pair[1]))
              .toList(growable: false);

          return Polyline(
            points: points,
            strokeWidth: routeId == selectedRoute ? 4.2 : 2.2,
            color: routeColors[routeId]!.withValues(
              alpha: routeId == selectedRoute ? 0.9 : 0.35,
            ),
          );
        })
        .toList(growable: false);
  }

  List<Marker> _buildStopMarkers(List<StopModel> stops, RouteId route) {
    return stops
        .map(
          (stop) => Marker(
            point: LatLng(stop.lat, stop.lng),
            width: 20,
            height: 20,
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _selectedStop = stop;
                  _showTopOverlay = true;
                });
              },
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: _selectedStop?.stopId == stop.stopId
                      ? Colors.white
                      : routeColors[route],
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: _selectedStop?.stopId == stop.stopId
                        ? routeColors[route]!
                        : Colors.white,
                    width: 2,
                  ),
                ),
              ),
            ),
          ),
        )
        .toList(growable: false);
  }

  List<Marker> _buildBusMarkers({
    required BusId selectedBus,
    required RouteId selectedRoute,
    required List<StopModel> routeStops,
    required BusLocationModel? busLocation,
  }) {
    if (busLocation == null) return const <Marker>[];

    return [
      Marker(
        point: LatLng(busLocation.lat, busLocation.lng),
        width: 72,
        height: 54,
        child: GestureDetector(
          onTap: () {
            if (_userLat != null && _userLng != null) {
              final nearest = _nearestStop(routeStops, lat: busLocation.lat, lng: busLocation.lng);
              if (nearest != null) {
                setState(() {
                  _selectedStop = nearest;
                });
              }
            }
            _onGetEta(selectedBus);
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: routeColors[selectedRoute],
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  selectedBus.value.toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
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
                  border: Border.all(color: routeColors[selectedRoute]!, width: 2),
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
      ),
    ];
  }

  Marker? _buildUserMarker() {
    if (_userLat == null || _userLng == null) return null;

    return Marker(
      point: LatLng(_userLat!, _userLng!),
      width: 28,
      height: 28,
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: const Color(0x330061A4),
          border: Border.all(color: const Color(0xFF0061A4), width: 1.5),
        ),
        child: const Center(
          child: CircleAvatar(
            radius: 5,
            backgroundColor: Color(0xFF0061A4),
          ),
        ),
      ),
    );
  }
}

class _TopSearchBar extends StatelessWidget {
  const _TopSearchBar({required this.onTapSearch, required this.onTapSettings});

  final VoidCallback onTapSearch;
  final VoidCallback onTapSettings;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('topSearch'),
      height: 56,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.93),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        children: [
          const SizedBox(width: 14),
          const Icon(Icons.directions_bus_rounded, color: Colors.white, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: InkWell(
              onTap: onTapSearch,
              child: const Text(
                'Hub City Transit  ·  Search stops or routes...',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: Colors.white70, fontSize: 16 / 1.1),
              ),
            ),
          ),
          IconButton(
            onPressed: onTapSettings,
            icon: const Icon(Icons.settings_outlined, color: Colors.white70),
          ),
        ],
      ),
    );
  }
}

class _BottomFlyer extends StatelessWidget {
  const _BottomFlyer({
    required this.selectedRoute,
    required this.selectedBus,
    required this.routeStops,
    required this.selectedStop,
    required this.userLat,
    required this.userLng,
    required this.locationError,
    required this.eta,
    required this.etaLoading,
    required this.etaError,
    required this.busLocation,
    required this.onRouteSelected,
    required this.onBusSelected,
    required this.onRequestEta,
    required this.onStopSelected,
  });

  final RouteId selectedRoute;
  final BusId selectedBus;
  final List<StopModel> routeStops;
  final StopModel? selectedStop;
  final double? userLat;
  final double? userLng;
  final String? locationError;
  final EtaResultModel? eta;
  final bool etaLoading;
  final String? etaError;
  final BusLocationModel? busLocation;
  final ValueChanged<RouteId> onRouteSelected;
  final ValueChanged<BusId> onBusSelected;
  final VoidCallback onRequestEta;
  final ValueChanged<StopModel> onStopSelected;

  @override
  Widget build(BuildContext context) {
    final nearestDistance = (selectedStop != null && userLat != null && userLng != null)
        ? haversineMeters(userLat!, userLng!, selectedStop!.lat, selectedStop!.lng)
        : null;

    final walkMins = nearestDistance == null ? null : (nearestDistance / 80).round().clamp(1, 999);

    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(color: Color(0x40000000), blurRadius: 18, offset: Offset(0, 8)),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'BUS INFO',
            style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: RouteId.values.map((route) {
              final active = route == selectedRoute;
              return FilterChip(
                selected: active,
                showCheckmark: false,
                backgroundColor: const Color(0xFF2A2A2A),
                selectedColor: routeColors[route],
                side: BorderSide.none,
                labelStyle: TextStyle(
                  color: active ? Colors.white : Colors.white70,
                  fontWeight: FontWeight.w700,
                ),
                label: Text(routeNames[route]!.replaceAll(' Route', '')),
                onSelected: (_) => onRouteSelected(route),
              );
            }).toList(growable: false),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: routeBusMap[selectedRoute]!.map((bus) {
              final active = bus == selectedBus;
              return ChoiceChip(
                selected: active,
                showCheckmark: false,
                selectedColor: routeColors[selectedRoute],
                side: BorderSide.none,
                backgroundColor: const Color(0xFF2A2A2A),
                labelStyle: TextStyle(
                  color: active ? Colors.white : Colors.white70,
                  fontWeight: FontWeight.w700,
                ),
                label: Text(bus.value.toUpperCase()),
                onSelected: (_) => onBusSelected(bus),
              );
            }).toList(growable: false),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              CircleAvatar(
                backgroundColor: routeColors[selectedRoute]!.withValues(alpha: 0.35),
                child: Icon(Icons.directions_bus_rounded, color: routeColors[selectedRoute]),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      selectedBus.value.toUpperCase(),
                      style: const TextStyle(color: Colors.white, fontSize: 24 / 2, fontWeight: FontWeight.w700),
                    ),
                    Text(
                      routeNames[selectedRoute]!,
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ],
                ),
              ),
              if (etaLoading)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                TextButton(
                  onPressed: onRequestEta,
                  child: const Text('Get ETA'),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _MetricCard(
                label: 'LAST SEEN',
                value: busLocation == null
                    ? '--'
                    : '${DateTime.now().difference(busLocation!.lastSeen).inMinutes}m ago',
              ),
              const SizedBox(width: 8),
              _MetricCard(
                label: 'HEADING',
                value: busLocation?.heading == null ? '--' : '${busLocation!.heading!.round()}°',
              ),
              const SizedBox(width: 8),
              _MetricCard(
                label: 'SPEED',
                value: busLocation?.speed == null ? '--' : '${busLocation!.speed!.round()} mph',
              ),
            ],
          ),
          if (selectedStop != null) ...[
            const SizedBox(height: 10),
            Text(
              'Destination: ${selectedStop!.location}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
            ),
            if (walkMins != null)
              Text(
                'Step 1: Walk ~$walkMins min to stop ${selectedStop!.stopId}',
                style: const TextStyle(color: Colors.white70),
              ),
            Text(
              'Step 2: Board ${selectedBus.value.toUpperCase()} (${routeNames[selectedRoute]})',
              style: const TextStyle(color: Colors.white70),
            ),
          ],
          if (etaError != null) ...[
            const SizedBox(height: 8),
            Text(etaError!, style: const TextStyle(color: Colors.redAccent)),
          ],
          if (locationError != null) ...[
            const SizedBox(height: 8),
            Text(locationError!, style: const TextStyle(color: Colors.orangeAccent)),
          ],
          const SizedBox(height: 8),
          const Text(
            'Tap bus or stop markers for route guidance.',
            style: TextStyle(color: Colors.white54, fontSize: 12),
          ),
          if (routeStops.isNotEmpty) ...[
            const SizedBox(height: 8),
            SizedBox(
              height: 34,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: routeStops.length.clamp(0, 8),
                separatorBuilder: (_, _) => const SizedBox(width: 6),
                itemBuilder: (context, index) {
                  final stop = routeStops[index];
                  return ActionChip(
                    backgroundColor: const Color(0xFF2A2A2A),
                    labelStyle: const TextStyle(color: Colors.white70),
                    label: Text(stop.location, overflow: TextOverflow.ellipsis),
                    onPressed: () => onStopSelected(stop),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: const Color(0xFF232323),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(color: Colors.white54, fontSize: 11)),
            const SizedBox(height: 4),
            Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
          ],
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
