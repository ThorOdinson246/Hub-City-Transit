import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../../../app/providers.dart';
import '../../../core/constants/route_metadata.dart';
import '../../../core/constants/transit_ids.dart';
import '../../../core/utils/transfer_connections.dart';
import '../../../data/models/stop_model.dart';

part 'map_page_stop_sheet.dart';
part 'map_page_navigation.dart';

class MapPage extends ConsumerStatefulWidget {
  const MapPage({super.key});
  @override
  ConsumerState<MapPage> createState() => _MapPageState();
}

class _MapPageState extends ConsumerState<MapPage> {
  final _mapController = MapController();
  StopModel? _selectedStop;
  bool _mapUiVisible = true;
  Timer? _uiRestoreTimer;
  bool _etaLoading = false;
  bool _etaInFlight = false;
  bool _etaRequested = false;
  String? _etaError;
  int? _etaMinutes;
  String? _etaNearestStop;

  @override
  void dispose() {
    _uiRestoreTimer?.cancel();
    _mapController.dispose();
    super.dispose();
  }

  void _onMapGesture(bool hasGesture) {
    if (hasGesture) {
      _uiRestoreTimer?.cancel();
      if (_mapUiVisible) setState(() { _mapUiVisible = false; });
      return;
    }
    _uiRestoreTimer?.cancel();
    _uiRestoreTimer = Timer(const Duration(milliseconds: 500), () {
      if (mounted) setState(() => _mapUiVisible = true);
    });
  }

  void _flyToUser(Position? pos) {
    if (pos == null) return;
    _mapController.move(LatLng(pos.latitude, pos.longitude), 15);
  }

  Future<void> _fetchEta(BusId bus, Position pos) async {
    if (_etaInFlight) return;
    _etaInFlight = true;
    setState(() { _etaLoading = true; _etaError = null; });
    try {
      final repo = ref.read(transitRepositoryProvider);
      final result = await repo.getEta(
        busId: bus.value, userLat: pos.latitude, userLng: pos.longitude,
      );
      if (!mounted) return;
      setState(() {
        _etaLoading = false;
        _etaRequested = true;
        if (result.status == 'ok') {
          _etaMinutes = result.etaMinutes;
          _etaNearestStop = result.nearestStopName;
        } else {
          _etaError = result.message ?? 'ETA unavailable';
        }
      });
    } catch (e) {
      if (mounted) setState(() { _etaLoading = false; _etaError = e.toString(); });
    } finally {
      _etaInFlight = false;
    }
  }

  void _showFabMenu(BuildContext context, Position? userPos) {
    final cs = Theme.of(context).colorScheme;
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      backgroundColor: cs.surfaceContainerLowest,
      builder: (_) => _FabMenuSheet(
        onShowAllRoutes: () { Navigator.pop(context); },
        onNearbyStops: () { Navigator.pop(context); },
        onSearchRoute: () {
          Navigator.pop(context);
          _showSearchSheet(context);
        },
        onPlanTrip: () {
          Navigator.pop(context);
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: cs.surfaceContainerLowest,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            builder: (_) => _TripPlannerSheet(userPos: userPos),
          );
        },
      ),
    );
  }

  void _showSearchSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerLowest,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _SearchSheet(
        onRouteSelected: (r) {
          ref.read(selectedRouteProvider.notifier).state = r;
          ref.read(selectedBusProvider.notifier).state = routeBusMap[r]!.first;
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final selectedRoute = ref.watch(selectedRouteProvider);
    final selectedBus = ref.watch(selectedBusProvider);
    final routesAsync = ref.watch(routesProvider);
    final stopsAsync = ref.watch(stopsBySelectedRouteProvider);
    final allStopsByRouteAsync = ref.watch(allStopsByRouteProvider);
    final busAsync = ref.watch(busLocationPollingProvider);
    final locationAsync = ref.watch(userLocationProvider);
    final userPos = locationAsync.asData?.value;

    final polylineLayers = routesAsync.asData?.value.map((route) {
      final rId = RouteId.fromValue(route.routeId);
      final pts = route.polyline
          .where((p) => p.length == 2)
          .map((p) => LatLng(p[0], p[1]))
          .toList();
      return Polyline(
        points: pts,
        strokeWidth: rId == selectedRoute ? 4.5 : 2,
        color: routeColors[rId]!.withValues(
          alpha: rId == selectedRoute ? 0.9 : 0.2,
        ),
      );
    }).toList() ?? [];

    final stopMarkers = stopsAsync.asData?.value.map((stop) => Marker(
      point: LatLng(stop.lat, stop.lng),
      width: 22, height: 22,
      child: GestureDetector(
        onTap: () => setState(() => _selectedStop = stop),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: _selectedStop?.stopId == stop.stopId
                ? Colors.white : routeColors[selectedRoute],
            borderRadius: BorderRadius.circular(11),
            border: Border.all(
              color: _selectedStop?.stopId == stop.stopId
                  ? routeColors[selectedRoute]! : Colors.white,
              width: 2.5,
            ),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 4)],
          ),
        ),
      ),
    )).toList() ?? [];

    final busLocation = busAsync.asData?.value;
    final busMarkers = busLocation == null ? <Marker>[] : [
      Marker(
        point: LatLng(busLocation.lat, busLocation.lng),
        width: 70, height: 54,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
              color: routeColors[selectedRoute],
              borderRadius: BorderRadius.circular(999),
              boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 6, offset: Offset(0,2))],
            ),
            child: Text(selectedBus.value.toUpperCase(),
              style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: Colors.white)),
          ),
          const SizedBox(height: 3),
          Container(
            width: 28, height: 28,
            decoration: BoxDecoration(
              color: Colors.white, shape: BoxShape.circle,
              border: Border.all(color: routeColors[selectedRoute]!, width: 2.5),
              boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 6)],
            ),
            child: Icon(Icons.directions_bus_rounded, size: 16, color: routeColors[selectedRoute]),
          ),
        ]),
      ),
    ];

    final userMarkers = userPos == null ? <CircleMarker>[] : [
      CircleMarker(
        point: LatLng(userPos.latitude, userPos.longitude),
        radius: 10, useRadiusInMeter: false,
        color: const Color(0xFF2196F3).withValues(alpha: 0.25),
        borderColor: Colors.white, borderStrokeWidth: 2,
      ),
      CircleMarker(
        point: LatLng(userPos.latitude, userPos.longitude),
        radius: 5, useRadiusInMeter: false,
        color: const Color(0xFF1976D2),
        borderColor: Colors.white, borderStrokeWidth: 1.5,
      ),
    ];

    final mapCenter = busLocation != null
        ? LatLng(busLocation.lat, busLocation.lng)
        : const LatLng(31.3271, -89.2903);

    return Stack(children: [
      Positioned.fill(
        child: FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: mapCenter,
            initialZoom: 13,
            minZoom: 10, maxZoom: 18,
            onPositionChanged: (_, hasGesture) => _onMapGesture(hasGesture),
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png',
              subdomains: const ['a','b','c','d'],
              userAgentPackageName: 'com.hubcitytransit',
            ),
            PolylineLayer(polylines: polylineLayers),
            CircleLayer(circles: userMarkers),
            MarkerLayer(markers: stopMarkers),
            MarkerLayer(markers: busMarkers),
          ],
        ),
      ),

      // ── Top bar ──────────────────────────────────────────────────────────
      Positioned(
        top: 0, left: 0, right: 0,
        child: SafeArea(
          bottom: false,
          child: AnimatedSlide(
            offset: _mapUiVisible ? Offset.zero : const Offset(0, -1.2),
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeInOut,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: Column(children: [
                // Header bar
                Container(
                  height: 56,
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerLowest.withValues(alpha: 0.95),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: cs.outlineVariant),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 12, offset: const Offset(0,4))],
                  ),
                  child: Row(children: [
                    IconButton(
                      icon: Icon(Icons.menu_rounded, color: cs.onSurface),
                      onPressed: () {},
                    ),
                    Expanded(
                      child: Text('Hub City Transit',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: cs.onSurface)),
                    ),
                    IconButton(
                      icon: Icon(Icons.search_rounded, color: cs.onSurface),
                      onPressed: () => _showSearchSheet(context),
                    ),
                  ]),
                ),
                const SizedBox(height: 8),
                // Route chips
                AnimatedOpacity(
                  opacity: _selectedStop == null ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 200),
                  child: SizedBox(
                    height: 40,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      itemCount: RouteId.values.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 6),
                      itemBuilder: (_, i) {
                        final r = RouteId.values[i];
                        final sel = r == selectedRoute;
                        return ChoiceChip(
                          showCheckmark: false,
                          selected: sel,
                          label: Text(routeNames[r] ?? r.value,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: sel ? cs.onPrimary : cs.onSurface,
                            )),
                          selectedColor: cs.primary,
                          backgroundColor: cs.surfaceContainerLowest,
                          side: BorderSide(color: sel ? cs.primary : cs.outlineVariant),
                          onSelected: (_) {
                            ref.read(selectedRouteProvider.notifier).state = r;
                            ref.read(selectedBusProvider.notifier).state = routeBusMap[r]!.first;
                            setState(() => _selectedStop = null);
                          },
                        );
                      },
                    ),
                  ),
                ),
              ]),
            ),
          ),
        ),
      ),

      // ── Location FAB ─────────────────────────────────────────────────────
      Positioned(
        right: 14,
        bottom: _selectedStop != null ? 320 : 90,
        child: AnimatedOpacity(
          opacity: _mapUiVisible ? 1 : 0,
          duration: const Duration(milliseconds: 200),
          child: GestureDetector(
            onLongPress: () => _showFabMenu(context, userPos),
            child: FloatingActionButton.small(
              heroTag: 'location-fab',
              backgroundColor: cs.surfaceContainerLowest,
              foregroundColor: cs.primary,
              elevation: 4,
              onPressed: () async {
                if (userPos != null) {
                  _flyToUser(userPos);
                } else {
                  final perm = await Geolocator.requestPermission();
                  if (perm == LocationPermission.always ||
                      perm == LocationPermission.whileInUse) {
                    ref.invalidate(userLocationProvider);
                  }
                }
              },
              child: const Icon(Icons.my_location_rounded),
            ),
          ),
        ),
      ),

      // ── Stop detail sheet ─────────────────────────────────────────────────
      if (_selectedStop != null)
        _StopDetailSheet(
          stop: _selectedStop!,
          selectedRoute: selectedRoute,
          userPos: userPos,
          allStopsByRouteAsync: allStopsByRouteAsync,
          stopsAsync: stopsAsync,
          selectedBus: selectedBus,
          etaLoading: _etaLoading,
          etaRequested: _etaRequested,
          etaMinutes: _etaMinutes,
          etaNearestStop: _etaNearestStop,
          etaError: _etaError,
          onClose: () => setState(() => _selectedStop = null),
          onGetEta: () {
            if (userPos != null) _fetchEta(selectedBus, userPos);
          },
          onSwitchRoute: (r) {
            ref.read(selectedRouteProvider.notifier).state = r;
            ref.read(selectedBusProvider.notifier).state = routeBusMap[r]!.first;
            setState(() => _selectedStop = null);
          },
        ),
    ]);
  }
}
