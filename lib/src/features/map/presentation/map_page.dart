import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../../../app/providers.dart';
import '../../../core/constants/route_metadata.dart';
import '../../../core/constants/transit_ids.dart';
import '../../../core/utils/transfer_connections.dart';
import '../../../data/models/bus_location_model.dart';
import '../../../data/models/stop_model.dart';
import '../../../domain/usecases/schedule_adjustment_use_case.dart' hide BusStatus, deriveBusStatus;
import '../../../data/services/nominatim_service.dart';

part 'map_page_stop_sheet.dart';
part 'map_page_navigation.dart';

class MapPage extends ConsumerStatefulWidget {
  const MapPage({super.key});
  @override
  ConsumerState<MapPage> createState() => _MapPageState();
}

class _MapPageState extends ConsumerState<MapPage> with TickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  final _mapController = MapController();
  StopModel? _selectedStop;
  bool _headerVisible = true;
  bool _isSearching = false;
  final _searchCtrl = TextEditingController();
  final _searchFocus = FocusNode();
  String _searchQuery = '';
  double _currentZoom = 13.0;

  // ETA state
  bool _etaLoading = false;
  bool _etaInFlight = false;
  bool _etaRequested = false;
  String? _etaError;
  int? _etaMinutes;
  String? _etaNearestStop;

  // Bus info panel default open
  bool _busInfoExpanded = true;

  Timer? _gestureTimer;

  // Active Trip
  TripResult? _activeTrip;

  void _animatedMapMove(LatLng destLocation, double destZoom) {
    final latTween = Tween<double>(begin: _mapController.camera.center.latitude, end: destLocation.latitude);
    final lngTween = Tween<double>(begin: _mapController.camera.center.longitude, end: destLocation.longitude);
    final zoomTween = Tween<double>(begin: _mapController.camera.zoom, end: destZoom);

    final controller = AnimationController(duration: const Duration(milliseconds: 500), vsync: this);
    final Animation<double> animation = CurvedAnimation(parent: controller, curve: Curves.fastOutSlowIn);

    controller.addListener(() {
      _mapController.move(
        LatLng(latTween.evaluate(animation), lngTween.evaluate(animation)),
        zoomTween.evaluate(animation),
      );
    });

    animation.addStatusListener((status) {
      if (status == AnimationStatus.completed || status == AnimationStatus.dismissed) {
        controller.dispose();
      }
    });

    controller.forward();
  }

  void _fitTripBounds(TripResult trip, Position? userPos) {
    final points = [
      if (userPos != null) LatLng(userPos.latitude, userPos.longitude),
      trip.destinationPoint,
      LatLng(trip.boardStop.lat, trip.boardStop.lng),
      LatLng(trip.destStop.lat, trip.destStop.lng),
    ];
    final bounds = LatLngBounds.fromPoints(points);
    
    // Animate bounds
    final fit = CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(50));
    final targetCamera = fit.fit(_mapController.camera);
    
    _animatedMapMove(targetCamera.center, targetCamera.zoom);
  }

  List<LatLng> _getRouteSlice(List<dynamic> rawPolyline, LatLng start, LatLng end) {
    if (rawPolyline.isEmpty) return [start, end];
    
    int startIdx = 0;
    double minStartDist = double.infinity;
    for (int i=0; i<rawPolyline.length; i++) {
      final pt = rawPolyline[i];
      final dist = haversineMeters(start.latitude, start.longitude, pt[0], pt[1]);
      if (dist < minStartDist) { minStartDist = dist; startIdx = i; }
    }
    
    int endIdx = 0;
    double minEndDist = double.infinity;
    for (int i=0; i<rawPolyline.length; i++) {
      final pt = rawPolyline[i];
      final dist = haversineMeters(end.latitude, end.longitude, pt[0], pt[1]);
      if (dist < minEndDist) { minEndDist = dist; endIdx = i; }
    }
    
    final points = <LatLng>[];
    if (startIdx <= endIdx) {
      for (int i=startIdx; i<=endIdx; i++) {
        points.add(LatLng(rawPolyline[i][0], rawPolyline[i][1]));
      }
    } else {
      for (int i=startIdx; i<rawPolyline.length; i++) {
        points.add(LatLng(rawPolyline[i][0], rawPolyline[i][1]));
      }
      for (int i=0; i<=endIdx; i++) {
        points.add(LatLng(rawPolyline[i][0], rawPolyline[i][1]));
      }
    }
    return points;
  }

  @override
  void dispose() {
    _gestureTimer?.cancel();
    _searchCtrl.dispose();
    _searchFocus.dispose();
    _mapController.dispose();
    super.dispose();
  }

  void _onMapEvent(MapEvent event) {
    if (event is MapEventMoveStart || event is MapEventRotateStart || event is MapEventFlingAnimation) {
      _gestureTimer?.cancel();
      if (_headerVisible) setState(() => _headerVisible = false);
    } else if (event is MapEventMoveEnd || event is MapEventRotateEnd || event is MapEventFlingAnimationEnd) {
      _gestureTimer?.cancel();
      _gestureTimer = Timer(const Duration(milliseconds: 600), () {
        if (mounted) setState(() => _headerVisible = true);
      });
      if (event is MapEventMoveEnd) {
        setState(() => _currentZoom = event.camera.zoom);
      }
    }
  }

  void _flyToUser(Position pos) {
    _animatedMapMove(LatLng(pos.latitude, pos.longitude), 15);
  }

  void _activateSearch() {
    setState(() => _isSearching = true);
    Future.delayed(const Duration(milliseconds: 80), () => _searchFocus.requestFocus());
  }

  void _openTripPlanner(BuildContext ctx, dynamic userPos) {
    final cs = Theme.of(ctx).colorScheme;
    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: cs.surfaceContainerLowest,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => TripPlannerSheet(
        userPos: userPos,
        onTripCalculated: (result) {
          Navigator.pop(ctx);
          setState(() => _activeTrip = result);
          _fitTripBounds(result, userPos);
        },
      ),
    );
  }

  void _cancelSearch() {
    setState(() {
      _isSearching = false;
      _searchQuery = '';
    });
    _searchCtrl.clear();
    _searchFocus.unfocus();
  }

  Future<void> _fetchEta(BusId bus, Position pos) async {
    if (_etaInFlight) return;
    _etaInFlight = true;
    setState(() { _etaLoading = true; _etaError = null; });
    try {
      final result = await ref.read(transitRepositoryProvider).getEta(
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

  void _showFabMenu(BuildContext ctx, dynamic userPos) {
    final cs = Theme.of(ctx).colorScheme;
    showModalBottomSheet(
      context: ctx,
      backgroundColor: cs.surfaceContainerLowest,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _FabMenuSheet(
        onPlanTrip: () {
          Navigator.pop(ctx);
          _openTripPlanner(ctx, userPos);
        },
        onNearbyStops: () {
          Navigator.pop(ctx);
          if (userPos != null) {
            _flyToUser(userPos);
          } else {
            ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Enable location first')));
          }
        },
        onShowAllRoutes: () {
          Navigator.pop(ctx);
          // Zoom out to see all of Hattiesburg
          _animatedMapMove(const LatLng(31.3271, -89.2903), 12);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // required for AutomaticKeepAliveClientMixin

    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final selectedRoute = ref.watch(selectedRouteProvider);
    final selectedBus = ref.watch(selectedBusProvider);
    final routesAsync = ref.watch(routesProvider);
    final stopsAsync = ref.watch(stopsBySelectedRouteProvider);
    final allStopsAsync = ref.watch(allStopsByRouteProvider);
    final busAsync = ref.watch(busLocationPollingProvider);
    final busStatus = ref.watch(busStatusProvider);
    final locationAsync = ref.watch(userLocationProvider);
    final userPos = locationAsync.asData?.value;
    final darkBasemap = ref.watch(darkBasemapProvider);

    final tileUrl = (isDark && darkBasemap)
        ? 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png'
        : 'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png';

    // Stop marker radius scales with zoom
    final markerRadius = (_currentZoom >= 15) ? 9.0 : (_currentZoom >= 13) ? 6.0 : 4.0;

    List<Polyline> polylines = [];
    if (_activeTrip != null) {
      final trip = _activeTrip!;
      final walkToOrigin = Polyline(
        points: [
          if (userPos != null) LatLng(userPos.latitude, userPos.longitude),
          LatLng(trip.boardStop.lat, trip.boardStop.lng),
        ],
        strokeWidth: 4.0,
        color: const Color(0xFF1976D2).withValues(alpha: 0.6),
        pattern: StrokePattern.dashed(segments: const [8, 6]),
      );
      
      final walkFromDest = Polyline(
        points: [
          LatLng(trip.destStop.lat, trip.destStop.lng),
          trip.destinationPoint,
        ],
        strokeWidth: 4.0,
        color: const Color(0xFF16A34A).withValues(alpha: 0.6),
        pattern: StrokePattern.dashed(segments: const [8, 6]),
      );

      final routeModel = routesAsync.asData?.value.firstWhere((r) => RouteId.fromValue(r.routeId) == trip.route);
      final rawPolyline = routeModel?.polyline.where((p) => p.length == 2).toList() ?? [];
      final busSlice = _getRouteSlice(
        rawPolyline,
        LatLng(trip.boardStop.lat, trip.boardStop.lng),
        LatLng(trip.destStop.lat, trip.destStop.lng),
      );

      final busRoute = Polyline(
        points: busSlice,
        strokeWidth: 5.0,
        color: routeColors[trip.route]!,
      );

      polylines = [walkToOrigin, walkFromDest, busRoute];
    } else {
      polylines = routesAsync.asData?.value.map((r) {
        final rId = RouteId.fromValue(r.routeId);
        return Polyline(
          points: r.polyline.where((p) => p.length == 2).map((p) => LatLng(p[0], p[1])).toList(),
          strokeWidth: rId == selectedRoute ? 4.5 : 2,
          color: routeColors[rId]!.withValues(alpha: rId == selectedRoute ? 0.9 : 0.2),
        );
      }).toList() ?? [];
    }

    final stopMarkers = stopsAsync.asData?.value.map((stop) => Marker(
      point: LatLng(stop.lat, stop.lng),
      width: markerRadius * 2 + 10,
      height: markerRadius * 2 + 10,
      child: GestureDetector(
        onTap: () {
          _animatedMapMove(LatLng(stop.lat, stop.lng), 16);
          setState(() {
            _selectedStop = stop;
            _activeTrip = null; // Close active trip if they tap a stop
            _etaRequested = false;
            _etaMinutes = null;
            _etaError = null;
          });
        },
        child: Center(
          child: Container(
            width: markerRadius * 2,
            height: markerRadius * 2,
            decoration: BoxDecoration(
              color: _selectedStop?.stopId == stop.stopId ? Colors.white : routeColors[selectedRoute],
              shape: BoxShape.circle,
              border: Border.all(
                color: _selectedStop?.stopId == stop.stopId ? routeColors[selectedRoute]! : Colors.white,
                width: 2,
              ),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 3)],
            ),
          ),
        ),
      ),
    )).toList() ?? [];

    final busLocation = busAsync.asData?.value;
    // Use last-known location for offline state (ghost marker)
    final effectiveBusLocation = busLocation;
    final busMarkers = effectiveBusLocation == null ? <Marker>[] : [
      Marker(
        point: LatLng(effectiveBusLocation.lat, effectiveBusLocation.lng),
        width: 80, height: 80,
        child: buildBusMarker(
          busLocation: effectiveBusLocation,
          busStatus: busStatus,
          selectedRoute: selectedRoute,
          selectedBus: selectedBus,
          onTap: () {
            _animatedMapMove(LatLng(effectiveBusLocation.lat, effectiveBusLocation.lng), 16);
            setState(() { _selectedStop = null; _activeTrip = null; _busInfoExpanded = true; });
          },
        ),
      ),
    ];


    final userCircles = userPos == null ? <CircleMarker>[] : [
      CircleMarker(
        point: LatLng(userPos.latitude, userPos.longitude),
        radius: 11, useRadiusInMeter: false,
        color: const Color(0xFF1976D2).withValues(alpha: 0.22),
        borderColor: Colors.white, borderStrokeWidth: 2,
      ),
      CircleMarker(
        point: LatLng(userPos.latitude, userPos.longitude),
        radius: 5, useRadiusInMeter: false,
        color: const Color(0xFF1976D2),
        borderColor: Colors.white, borderStrokeWidth: 1.5,
      ),
    ];

    // Guard against NaN/null GPS coordinates
    final busLat = busLocation?.lat;
    final busLng = busLocation?.lng;
    final busLocValid = busLat != null && busLng != null && !busLat.isNaN && !busLng.isNaN;

    final LatLng mapCenter;
    if (busLocValid) {
      mapCenter = LatLng(busLat!, busLng!);
    } else {
      mapCenter = const LatLng(31.3271, -89.2903); // Hattiesburg, MS
    }


    // Search-filtered stops
    final searchResults = _searchQuery.length >= 2
        ? (allStopsAsync.asData?.value.entries.expand((e) =>
            e.value.where((s) => s.location.toLowerCase().contains(_searchQuery.toLowerCase()))
              .map((s) => (route: e.key, stop: s))
          ).take(12).toList() ?? [])
        : [];

    return Stack(children: [
      // Map
      Positioned.fill(
        child: FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: mapCenter,
            initialZoom: _currentZoom,
            minZoom: 10, maxZoom: 18,
            // Lock north-up — disable rotation gestures
            interactionOptions: const InteractionOptions(
              flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
            ),
            onMapEvent: _onMapEvent,
          ),
          children: [
            TileLayer(urlTemplate: tileUrl,
              subdomains: const ['a','b','c','d'],
              userAgentPackageName: 'com.hubcitytransit'),
            PolylineLayer(polylines: polylines),
            CircleLayer(circles: userCircles),
            MarkerLayer(markers: stopMarkers),
            MarkerLayer(markers: busMarkers),
            // Trip waypoint markers (board stop + destination pin)
            if (_activeTrip != null)
              MarkerLayer(markers: [
                // Board stop — where you get on the bus
                Marker(
                  point: LatLng(_activeTrip!.boardStop.lat, _activeTrip!.boardStop.lng),
                  width: 36, height: 52,
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1976D2),
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
                      ),
                      child: const Icon(Icons.directions_walk_rounded, color: Colors.white, size: 13),
                    ),
                    CustomPaint(
                      size: const Size(10, 7),
                      painter: _TrianglePainter(color: const Color(0xFF1976D2)),
                    ),
                  ]),
                ),
                // Destination pin
                Marker(
                  point: _activeTrip!.destinationPoint,
                  width: 40, height: 52,
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF16A34A),
                        shape: BoxShape.circle,
                        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
                      ),
                      child: const Icon(Icons.location_on_rounded, color: Colors.white, size: 14),
                    ),
                    CustomPaint(
                      size: const Size(10, 7),
                      painter: _TrianglePainter(color: const Color(0xFF16A34A)),
                    ),
                  ]),
                ),
              ]),

          ],
        ),
      ),

      // ── Top header ────────────────────────────────────────────────────────
      Positioned(
        top: 0, left: 0, right: 0,
        child: SafeArea(
          bottom: false,
          child: AnimatedSlide(
            offset: _headerVisible ? Offset.zero : const Offset(0, -1.8),
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeInOut,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 0),
              child: Column(children: [
                // Search / brand bar
                Container(
                  height: 52,
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerLowest.withValues(alpha: 0.96),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: cs.outlineVariant),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.10), blurRadius: 10, offset: const Offset(0, 3))],
                  ),
                  child: Row(children: [
                    const SizedBox(width: 6),
                    if (_isSearching)
                      IconButton(
                        icon: Icon(Icons.arrow_back_rounded, color: cs.onSurface),
                        onPressed: _cancelSearch,
                        visualDensity: VisualDensity.compact,
                      )
                    else
                      Padding(
                        padding: const EdgeInsets.only(left: 10),
                        child: Icon(Icons.directions_bus_rounded, color: cs.primary, size: 22),
                      ),
                    Expanded(
                      child: _isSearching
                          ? TextField(
                              controller: _searchCtrl,
                              focusNode: _searchFocus,
                              decoration: const InputDecoration(
                                hintText: 'Search stops or routes...',
                                border: InputBorder.none,
                                filled: false,
                                contentPadding: EdgeInsets.symmetric(horizontal: 8),
                              ),
                              style: TextStyle(color: cs.onSurface, fontSize: 15),
                              onChanged: (v) => setState(() => _searchQuery = v),
                            )
                          : GestureDetector(
                              onTap: () => _openTripPlanner(context, locationAsync.asData?.value),
                              behavior: HitTestBehavior.opaque,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                                child: _TypewriterBrandBar(cs: cs),
                              ),
                            ),
                    ),
                    if (!_isSearching)
                      IconButton(
                        icon: Icon(Icons.search_rounded, color: cs.onSurface),
                        onPressed: _activateSearch,
                        visualDensity: VisualDensity.compact,
                      ),
                    if (!_isSearching)
                      IconButton(
                        icon: Icon(Icons.directions_rounded, color: cs.primary),
                        onPressed: () => _openTripPlanner(context, locationAsync.asData?.value),
                        visualDensity: VisualDensity.compact,
                        tooltip: 'Plan a Trip',
                      ),
                    const SizedBox(width: 4),
                  ]),
                ),

                // Search results inline dropdown
                if (_isSearching && searchResults.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Container(
                    constraints: const BoxConstraints(maxHeight: 220),
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerLowest,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: cs.outlineVariant),
                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 8, offset: const Offset(0, 3))],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: ListView.separated(
                        shrinkWrap: true,
                        padding: EdgeInsets.zero,
                        itemCount: searchResults.length,
                        separatorBuilder: (_, _) => Divider(height: 1, color: cs.outlineVariant.withValues(alpha: 0.4)),
                        itemBuilder: (_, i) {
                          final r = searchResults[i];
                          return ListTile(
                            dense: true,
                            leading: CircleAvatar(
                              radius: 8,
                              backgroundColor: routeColors[r.route],
                            ),
                            title: Text(r.stop.location, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: cs.onSurface)),
                            subtitle: Text(routeNames[r.route] ?? '', style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
                            onTap: () {
                              _animatedMapMove(LatLng(r.stop.lat, r.stop.lng), 15);
                              ref.read(selectedRouteProvider.notifier).state = r.route;
                              ref.read(selectedBusProvider.notifier).state = routeBusMap[r.route]!.first;
                              setState(() {
                                _selectedStop = r.stop;
                                _isSearching = false;
                                _searchQuery = '';
                              });
                              _searchCtrl.clear();
                              _searchFocus.unfocus();
                            },
                          );
                        },
                      ),
                    ),
                  ),
                ],


              ]),
            ),
          ),
        ),
      ),

      // ── Location FAB ─────────────────────────────────────────────────────
      if (_activeTrip == null)
        AnimatedPositioned(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          right: 12,
          bottom: _selectedStop != null ? 380 : (_busInfoExpanded ? 280 : 100),
        child: GestureDetector(
          onLongPress: () => _showFabMenu(context, userPos),
          child: FloatingActionButton.small(
            heroTag: 'loc-fab',
            backgroundColor: cs.surfaceContainerLowest,
            foregroundColor: cs.primary,
            elevation: 4,
            onPressed: () async {
              if (userPos != null) {
                _flyToUser(userPos);
              } else {
                final p = await Geolocator.requestPermission();
                if ((p == LocationPermission.always || p == LocationPermission.whileInUse) && mounted) {
                  ref.invalidate(userLocationProvider);
                }
              }
            },
            child: Icon(
              userPos != null ? Icons.my_location_rounded : Icons.location_searching_rounded,
            ),
          ),
        ),
      ),

      // ── Bottom panel (bus info, stop detail, or active trip) ────────────────────────────
      if (_activeTrip != null)
        Positioned(
          bottom: 24, left: 16, right: 16,
          child: SafeArea(
            child: TripActiveCard(
              result: _activeTrip!,
              cs: cs,
              tt: Theme.of(context).textTheme,
              onClose: () => setState(() => _activeTrip = null),
            ),
          ),
        )
      else if (_selectedStop != null)
        _StopDetailSheet(
          stop: _selectedStop!,
          selectedRoute: selectedRoute,
          userPos: userPos,
          allStopsAsync: allStopsAsync,
          stopsAsync: stopsAsync,
          selectedBus: selectedBus,
          etaLoading: _etaLoading,
          etaRequested: _etaRequested,
          etaMinutes: _etaMinutes,
          etaNearestStop: _etaNearestStop,
          etaError: _etaError,
          onClose: () => setState(() { _selectedStop = null; }),
          onGetEta: () {
            if (userPos != null) _fetchEta(selectedBus, userPos);
          },
          onSwitchRoute: (r) {
            ref.read(selectedRouteProvider.notifier).state = r;
            ref.read(selectedBusProvider.notifier).state = routeBusMap[r]!.first;
            setState(() => _selectedStop = null);
          },
        )
      else
        _BusInfoPanel(
          selectedRoute: selectedRoute,
          selectedBus: selectedBus,
          busAsync: busAsync,
          busStatus: busStatus,
          expanded: _busInfoExpanded,
          onToggleExpanded: () => setState(() => _busInfoExpanded = !_busInfoExpanded),
          onRouteChange: (r) {
            ref.read(selectedRouteProvider.notifier).state = r;
            ref.read(selectedBusProvider.notifier).state = routeBusMap[r]!.first;
          },
          onBusChange: (b) {
            ref.read(selectedBusProvider.notifier).state = b;
            // Pan to the new bus location when switching buses
            final loc = ref.read(busLocationPollingProvider).asData?.value;
            if (loc != null && !loc.lat.isNaN && !loc.lng.isNaN) {
              _animatedMapMove(LatLng(loc.lat, loc.lng), 15);
            }
          },
        ),
    ]);
  }
}

// ── Triangle CustomPainter for map pin tails ─────────────────────────────────
class _TrianglePainter extends CustomPainter {
  const _TrianglePainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final path = ui.Path()
      ..moveTo(size.width / 2, size.height)
      ..lineTo(0, 0)
      ..lineTo(size.width, 0)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_TrianglePainter old) => old.color != color;
}
