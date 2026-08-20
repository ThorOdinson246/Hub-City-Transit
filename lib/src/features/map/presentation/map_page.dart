import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../../../app/providers.dart';
import '../../../core/constants/route_metadata.dart';
import '../../../core/constants/transit_ids.dart';
import '../../../core/utils/geo_utils.dart';
import '../../../core/utils/haversine.dart';
import '../../../core/utils/transfer_connections.dart';
import '../../../data/models/bus_location_model.dart';
import '../../../data/models/stop_model.dart';
import '../../../domain/usecases/schedule_adjustment_use_case.dart';
import '../../../data/services/nominatim_service.dart';
import '../../../core/utils/analytics_service.dart';

part 'map_page_stop_sheet.dart';
part 'map_page_navigation.dart';

abstract class SearchResultItem {}
class StopResult extends SearchResultItem {
  StopResult({required this.route, required this.stop, required this.isFav});
  final RouteId route;
  final StopModel stop;
  final bool isFav;
}
class LandmarkResult extends SearchResultItem {
  LandmarkResult(this.place);
  final NominatimPlace place;
}

class MapPage extends ConsumerStatefulWidget {
  const MapPage({super.key});
  @override
  ConsumerState<MapPage> createState() => _MapPageState();
}

class _MapPageState extends ConsumerState<MapPage> with TickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    if (kIsWeb) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Hub City Transit is best experienced on our mobile app!'),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 8),
            action: SnackBarAction(
              label: 'Dismiss',
              onPressed: () {},
            ),
          ),
        );
      });
    }
  }

  final _mapController = MapController();
  StopModel? _selectedStop;
  bool _headerVisible = true;
  final _searchCtrl = TextEditingController();
  final _searchFocus = FocusNode();
  String _searchQuery = '';
  double _currentZoom = 13.0;

  final _nominatim = NominatimService();
  List<dynamic> _landmarkResults = [];
  Timer? _searchDebounce;

  bool _busInfoExpanded = true;
  bool _isTrackingBus = false;

  Timer? _gestureTimer;
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
    final points = <LatLng>[];
    if (userPos != null && GeoUtils.isValidLatLng(userPos.latitude, userPos.longitude)) {
      points.add(LatLng(userPos.latitude, userPos.longitude));
    }
    if (GeoUtils.isValidLatLng(trip.destinationPoint.latitude, trip.destinationPoint.longitude)) {
      points.add(trip.destinationPoint);
    }
    if (GeoUtils.isValidLatLng(trip.boardStop.lat, trip.boardStop.lng)) {
      points.add(LatLng(trip.boardStop.lat, trip.boardStop.lng));
    }
    if (GeoUtils.isValidLatLng(trip.destStop.lat, trip.destStop.lng)) {
      points.add(LatLng(trip.destStop.lat, trip.destStop.lng));
    }
    
    if (points.isEmpty) return;
    
    final bounds = LatLngBounds.fromPoints(points);
    final fit = CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(50));
    final targetCamera = fit.fit(_mapController.camera);
    _animatedMapMove(targetCamera.center, targetCamera.zoom);
  }

  List<LatLng> _getRouteSlice(List<List<double>> rawPolyline, LatLng start, LatLng end) {
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
        if (GeoUtils.isValidLatLng(rawPolyline[i][0], rawPolyline[i][1])) {
          points.add(LatLng(rawPolyline[i][0], rawPolyline[i][1]));
        }
      }
    } else {
      for (int i=startIdx; i<rawPolyline.length; i++) {
        if (GeoUtils.isValidLatLng(rawPolyline[i][0], rawPolyline[i][1])) {
          points.add(LatLng(rawPolyline[i][0], rawPolyline[i][1]));
        }
      }
      for (int i=0; i<=endIdx; i++) {
        if (GeoUtils.isValidLatLng(rawPolyline[i][0], rawPolyline[i][1])) {
          points.add(LatLng(rawPolyline[i][0], rawPolyline[i][1]));
        }
      }
    }
    return points;
  }

  @override
  void dispose() {
    _gestureTimer?.cancel();
    _searchDebounce?.cancel();
    _searchCtrl.dispose();
    _searchFocus.dispose();
    _mapController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    setState(() => _searchQuery = query);
    if (_searchDebounce?.isActive ?? false) _searchDebounce!.cancel();
    if (query.trim().length < 3) {
      setState(() => _landmarkResults = []);
      return;
    }
    _searchDebounce = Timer(const Duration(milliseconds: 600), () async {
      try {
        final results = await _nominatim.search(query);
        if (mounted) setState(() { _landmarkResults = results; });
      } catch (e) {
        // Ignored or handled elsewhere
      }
    });
  }

  void _onMapEvent(MapEvent event) {
    if (event.source == MapEventSource.onDrag || event.source == MapEventSource.onMultiFinger) {
      _isTrackingBus = false;
    }
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

  void _openTripPlanner(BuildContext ctx, dynamic userPos, {NominatimPlace? defaultDestination}) {
    ref.read(analyticsProvider).logEvent('open_trip_planner');
    final cs = Theme.of(ctx).colorScheme;
    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: cs.surfaceContainerLowest,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => TripPlannerSheet(
        userPos: userPos,
        defaultDestination: defaultDestination,
        onTripCalculated: (res) {
          setState(() { _activeTrip = res; _headerVisible = false; });
          _fitTripBounds(res, userPos);
          Navigator.pop(ctx);
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
    
    ref.listen<AsyncValue<BusLocationModel?>>(busLocationPollingProvider, (previous, next) {
      if (_isTrackingBus) {
        final loc = next.value;
        if (loc != null && GeoUtils.isValidLatLng(loc.lat, loc.lng)) {
          // Calculate distance between current center and new bus location
          final currentCenter = _mapController.camera.center;
          final dist = haversineMeters(currentCenter.latitude, currentCenter.longitude, loc.lat, loc.lng);
          // Only pan if it moved more than 2 meters to avoid jittering
          if (dist > 2.0) {
            _animatedMapMove(LatLng(loc.lat, loc.lng), _currentZoom);
          }
        }
      }
    });

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
          points: r.polyline.where((p) => p.length == 2 && GeoUtils.isValidLatLng(p[0], p[1])).map((p) => LatLng(p[0], p[1])).toList(),
          strokeWidth: rId == selectedRoute ? 4.5 : 2,
          color: routeColors[rId]!.withValues(alpha: rId == selectedRoute ? 0.9 : 0.2),
        );
      }).toList() ?? [];
    }

    final stopMarkers = stopsAsync.asData?.value.where((stop) => GeoUtils.isValidLatLng(stop.lat, stop.lng)).map((stop) => Marker(
      point: LatLng(stop.lat, stop.lng),
      width: markerRadius * 2 + 10,
      height: markerRadius * 2 + 10,
      child: Semantics(
        button: true,
        label: 'Stop at ${stop.location}, ID ${stop.stopId}',
        child: GestureDetector(
        onTap: () {
          _animatedMapMove(LatLng(stop.lat, stop.lng), 16);
          setState(() {
            _selectedStop = stop;
            _activeTrip = null; // Close active trip if they tap a stop
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
    ),
    )).toList() ?? [];

    final busLocation = busAsync.asData?.value;
    // Use last-known location for offline state (ghost marker)
    final effectiveBusLocation = busLocation;
    final busMarkers = (effectiveBusLocation == null || !GeoUtils.isValidLatLng(effectiveBusLocation.lat, effectiveBusLocation.lng)) ? <Marker>[] : [
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
            setState(() { _selectedStop = null; _activeTrip = null; _busInfoExpanded = true; _isTrackingBus = true; });
          },
        ),
      ),
    ];


    final compassEvent = ref.watch(compassProvider).asData?.value;
    final heading = compassEvent?.heading;

    final userMarkers = (userPos == null || !GeoUtils.isValidLatLng(userPos.latitude, userPos.longitude)) ? <Marker>[] : [
      Marker(
        point: LatLng(userPos.latitude, userPos.longitude),
        width: 80, height: 80, // give enough room for the cone
        child: buildUserLocationMarker(userPos, heading),
      ),
    ];

    // Guard against NaN/null GPS coordinates
    final busLat = busLocation?.lat;
    final busLng = busLocation?.lng;
    final busLocValid = GeoUtils.isValidLatLng(busLat, busLng);

    final LatLng mapCenter;
    if (busLocValid) {
      mapCenter = LatLng(busLat!, busLng!);
    } else {
      mapCenter = const LatLng(31.3271, -89.2903); // Hattiesburg, MS
    }


    final favoritesList = ref.watch(favoritesProvider);

    final isSearchActive = _searchFocus.hasFocus || _searchQuery.isNotEmpty;

    // Search-filtered stops or favorites
    final stopResults = _searchQuery.length >= 2
        ? (allStopsAsync.asData?.value.entries.expand((e) =>
            e.value.where((s) => s.location.toLowerCase().contains(_searchQuery.toLowerCase()))
              .map((s) => StopResult(route: e.key, stop: s, isFav: favoritesList.contains(s.stopId.toString())))
          ).take(12).toList() ?? <StopResult>[])
        : (isSearchActive && _searchQuery.isEmpty && favoritesList.isNotEmpty)
            ? (allStopsAsync.asData?.value.entries.expand((e) =>
                e.value.where((s) => favoritesList.contains(s.stopId.toString()))
                  .map((s) => StopResult(route: e.key, stop: s, isFav: true))
              ).take(12).toList() ?? <StopResult>[])
            : <StopResult>[];

    final searchResults = <SearchResultItem>[
      ...stopResults,
      ..._landmarkResults.map((p) => LandmarkResult(p as NominatimPlace)),
    ];

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
            onTap: (_, _) {
              _searchFocus.unfocus();
              if (_searchQuery.isNotEmpty) {
                setState(() => _searchQuery = '');
                _searchCtrl.clear();
              }
            },
          ),
          children: [
            TileLayer(urlTemplate: tileUrl,
              subdomains: const ['a','b','c','d'],
              userAgentPackageName: 'com.hubcitytransit'),
            PolylineLayer(polylines: polylines),
            MarkerLayer(markers: userMarkers),
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
                    const CustomPaint(
                      size: Size(10, 7),
                      painter: _TrianglePainter(color: Color(0xFF1976D2)),
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
                      decoration: const BoxDecoration(
                        color: Color(0xFF16A34A),
                        shape: BoxShape.circle,
                        boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 4)],
                      ),
                      child: const Icon(Icons.location_on_rounded, color: Colors.white, size: 14),
                    ),
                    const CustomPaint(
                      size: Size(10, 7),
                      painter: _TrianglePainter(color: Color(0xFF16A34A)),
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
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(10, 8, 10, 0),
              child: TapRegion(
                onTapOutside: (event) {
                  _searchFocus.unfocus();
                  if (_searchQuery.isNotEmpty) {
                    setState(() => _searchQuery = '');
                    _searchCtrl.clear();
                  }
                },
                child: Column(children: [
                // Search / brand bar
                Container(
                  height: 52,
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerLowest.withValues(alpha: 0.96),
                    borderRadius: BorderRadius.circular(999),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.10), blurRadius: 10, offset: const Offset(0, 3))],
                  ),
                  child: Row(children: [
                    Padding(
                      padding: const EdgeInsets.only(left: 14),
                      child: Icon(Icons.search_rounded, color: cs.primary, size: 22),
                    ),
                    Expanded(
                      child: Stack(
                        alignment: Alignment.centerLeft,
                        children: [
                          if (!isSearchActive)
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                              child: _TypewriterBrandBar(cs: cs),
                            ),
                          TextField(
                            controller: _searchCtrl,
                            focusNode: _searchFocus,
                            decoration: const InputDecoration(
                              hintText: '', // Hint is handled by Typewriter
                              border: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              errorBorder: InputBorder.none,
                              disabledBorder: InputBorder.none,
                              filled: false,
                              contentPadding: EdgeInsets.symmetric(horizontal: 8),
                            ),
                            style: TextStyle(color: cs.onSurface, fontSize: 15),
                            onChanged: _onSearchChanged,
                          ),
                        ],
                      ),
                    ),
                    if (_searchQuery.isNotEmpty)
                      IconButton(
                        icon: Icon(Icons.close_rounded, color: cs.onSurfaceVariant, size: 20),
                        onPressed: () {
                          _searchCtrl.clear();
                          _onSearchChanged('');
                        },
                        visualDensity: VisualDensity.compact,
                      ),
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
                if (isSearchActive && searchResults.isNotEmpty) ...[
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
                          final item = searchResults[i];
                          if (item is StopResult) {
                            return MouseRegion(
                              cursor: SystemMouseCursors.click,
                              child: ListTile(
                                dense: true,
                                minLeadingWidth: 20,
                                leading: Icon(item.isFav ? Icons.favorite_rounded : Icons.directions_bus_rounded, color: item.isFav ? Colors.red : cs.primary),
                                title: Text(item.stop.location, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                                subtitle: Text('Route ${item.route.name}', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
                                onTap: () {
                                  if (GeoUtils.isValidLatLng(item.stop.lat, item.stop.lng)) {
                                    _animatedMapMove(LatLng(item.stop.lat, item.stop.lng), 15);
                                  }
                                  ref.read(selectedRouteProvider.notifier).state = item.route;
                                  ref.read(selectedBusProvider.notifier).state = routeBusMap[item.route]!.first;
                                  
                                  ref.read(analyticsProvider).logEvent('stop_search_selected', {
                                    'stop_id': item.stop.stopId,
                                    'route': item.route.name,
                                  });

                                  setState(() {
                                    _selectedStop = item.stop;
                                    _searchQuery = '';
                                  });
                                  _searchCtrl.clear();
                                  _searchFocus.unfocus();
                                },
                              ),
                            );
                          } else if (item is LandmarkResult) {
                            final parts = item.place.displayName.split(',');
                            final mainText = parts.first;
                            final subText = parts.skip(1).join(',').trim();
                            return MouseRegion(
                              cursor: SystemMouseCursors.click,
                              child: ListTile(
                                dense: true,
                                minLeadingWidth: 20,
                                leading: Icon(Icons.place_rounded, color: cs.secondary),
                                title: Text(mainText, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                                subtitle: Text(subText, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
                                onTap: () {
                                  _openTripPlanner(context, locationAsync.asData?.value, defaultDestination: item.place);
                                  setState(() => _searchQuery = '');
                                  _searchCtrl.clear();
                                  _searchFocus.unfocus();
                                },
                              ),
                            );
                          }
                          return const SizedBox.shrink();
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
            child: Tooltip(
              message: userPos != null ? 'Locate me' : 'Request location permission',
              child: Icon(
                userPos != null ? Icons.my_location_rounded : Icons.location_searching_rounded,
                semanticLabel: userPos != null ? 'Center map on my location' : 'Request location access',
              ),
            ),
          ),
        ),
      ),

      // ── Bottom panel (bus info, stop detail, or active trip) ────────────────────────────
      if (_activeTrip != null)
        Positioned(
          bottom: 24, left: 16, right: 16,
          child: SafeArea(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: TripActiveCard(
                  result: _activeTrip!,
                  cs: cs,
                  tt: Theme.of(context).textTheme,
                  onClose: () => setState(() => _activeTrip = null),
                ),
              ),
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
          onClose: () => setState(() { _selectedStop = null; }),
          onSwitchRoute: (r) {
            ref.read(analyticsProvider).logEvent('route_switched_from_stop', {'new_route': r.name});
            ref.read(selectedRouteProvider.notifier).state = r;
            ref.read(selectedBusProvider.notifier).state = routeBusMap[r]!.first;
            setState(() { _selectedStop = null; _isTrackingBus = true; });
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
            ref.read(analyticsProvider).logEvent('route_switched_from_panel', {'new_route': r.name});
            ref.read(selectedRouteProvider.notifier).state = r;
            ref.read(selectedBusProvider.notifier).state = routeBusMap[r]!.first;
            setState(() => _isTrackingBus = true);
          },
          onBusChange: (b) {
            ref.read(selectedBusProvider.notifier).state = b;
            setState(() => _isTrackingBus = true);
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
