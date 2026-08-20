import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/providers.dart';
import '../../../core/constants/route_metadata.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/transit_ids.dart';
import '../../../core/utils/geo_utils.dart';
import '../../../core/utils/haversine.dart';
import '../../../core/utils/transfer_connections.dart';
import '../../../data/models/bus_location_model.dart';
import '../../../data/models/stop_model.dart';
import '../../../domain/usecases/schedule_adjustment_use_case.dart';
import '../../../data/services/nominatim_service.dart';
import '../../../core/utils/analytics_service.dart';
import '../../announcements/presentation/announcement_banner.dart';
import '../../../data/models/transit_dataset.dart';
import '../../../domain/usecases/trip_planner.dart';
import '../../trip/application/active_trip.dart';
import '../../trip/presentation/trip_map_layers.dart';
import '../../trip/presentation/trip_planner_sheet.dart';

part 'map_page_stop_sheet.dart';

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
  const MapPage({this.routeId, this.stopId, super.key});

  /// Route named by `?route=`, or null to leave the current selection alone.
  final RouteId? routeId;

  /// Stop named by `?stop=`, or null for no open sheet.
  final String? stopId;

  @override
  ConsumerState<MapPage> createState() => _MapPageState();
}

class _MapPageState extends ConsumerState<MapPage> with TickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  final _mapController = MapController();
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

  @override
  void initState() {
    super.initState();
    // Nothing listened to focus, so the favourites shortlist never appeared and
    // the typewriter never stepped aside until the first keystroke.
    _searchFocus.addListener(_onSearchFocusChanged);
    _syncRouteFromUrl();
  }

  @override
  void didUpdateWidget(MapPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.routeId != oldWidget.routeId) _syncRouteFromUrl();
  }

  /// Points the shared route selection at whatever `?route=` names.
  ///
  /// Deferred to after the frame because this runs from `initState` and
  /// `didUpdateWidget`, where writing a provider lands inside the build phase.
  /// The selected *stop* needs no equivalent — it is derived in `build` from the
  /// URL, so it cannot fall out of step.
  void _syncRouteFromUrl() {
    final routeId = widget.routeId;
    if (routeId == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || routeId == ref.read(selectedRouteProvider)) return;
      ref.read(selectedRouteProvider.notifier).state = routeId;
      ref.read(selectedBusProvider.notifier).state = routeBusMap[routeId]!.first;
    });
  }

  /// The stop named by `?stop=`, once the stop list has loaded.
  ///
  /// Derived rather than stored. A cold deep link arrives before the stops do,
  /// so anything that resolved this once — in `initState` or a post-frame
  /// callback — would give up and never retry: `ref.read` does not subscribe,
  /// and the widget's parameters have not changed, so `didUpdateWidget` never
  /// fires again. Resolving here means the sheet simply appears on the build
  /// that follows the stops arriving.
  StopModel? _resolveSelectedStop(List<StopModel>? stops) {
    final stopId = widget.stopId;
    if (stopId == null || stops == null) return null;
    return stops
        .where((candidate) => candidate.stopId.toString() == stopId)
        .firstOrNull;
  }

  int? _flownToStopId;

  /// Centres the map on a stop the first time it becomes the selected one, so a
  /// shared link lands on the stop rather than the default camera. Skipped for
  /// a stop the user tapped, which has already been flown to.
  void _flyToSelectedStop(StopModel? stop) {
    if (stop == null) {
      _flownToStopId = null;
      return;
    }
    if (_flownToStopId == stop.stopId) return;
    _flownToStopId = stop.stopId;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _animatedMapMove(LatLng(stop.lat, stop.lng), 16);
    });
  }

  /// Rewrites the URL to match a selection, so it can be shared and so Back
  /// steps through selections rather than out of the app.
  void _pushSelection({RouteId? route, StopModel? stop}) {
    final RouteId routeId = route ?? ref.read(selectedRouteProvider);
    final query = {
      'route': routeId.value,
      if (stop != null) 'stop': stop.stopId.toString(),
    };
    context.go(Uri(path: '/map', queryParameters: query).toString());
  }

  void _onSearchFocusChanged() {
    if (mounted) setState(() {});
  }

  /// Only one bottom panel renders at a time, so a single key measures whichever
  /// is up. The FAB previously sat at a guessed offset and ended up behind the
  /// stop sheet, which can be 65% of the screen tall.
  final GlobalKey _panelKey = GlobalKey();
  double _panelHeight = 96;

  void _measurePanel() {
    if (!mounted) return;
    final box = _panelKey.currentContext?.findRenderObject() as RenderBox?;
    final height = box?.size.height;
    if (height == null) return;
    if ((height - _panelHeight).abs() > 1) {
      setState(() => _panelHeight = height);
    }
  }

  void _animatedMapMove(LatLng destLocation, double destZoom) {
    // Last line of defence: flutter_map throws on a non-finite LatLng, and a
    // single bad coordinate anywhere upstream would otherwise take out the map.
    if (!destLocation.latitude.isFinite ||
        !destLocation.longitude.isFinite ||
        !destZoom.isFinite) {
      return;
    }
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

  void _fitTripBounds(PlannedTrip trip) {
    final points = <LatLng>[];
    void add(double lat, double lng) {
      if (GeoUtils.isValidLatLng(lat, lng)) points.add(LatLng(lat, lng));
    }

    add(trip.originLat, trip.originLng);
    add(trip.destLat, trip.destLng);
    for (final leg in trip.itinerary.legs) {
      if (leg.fromStop case final stop?) add(stop.lat, stop.lng);
      if (leg.toStop case final stop?) add(stop.lat, stop.lng);
    }
    
    if (points.isEmpty) return;

    // Zero-area bounds make CameraFit divide down to an infinite zoom, which
    // surfaces as LatLng(NaN, NaN) inside flutter_map. Needs two points that are
    // actually apart.
    final spread = points.any((p) =>
        (p.latitude - points.first.latitude).abs() > 1e-6 ||
        (p.longitude - points.first.longitude).abs() > 1e-6);
    if (!spread) {
      _animatedMapMove(points.first, 16);
      return;
    }

    final bounds = LatLngBounds.fromPoints(points);
    final fit = CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(50));
    final targetCamera = fit.fit(_mapController.camera);
    _animatedMapMove(targetCamera.center, targetCamera.zoom);
  }


  @override
  void dispose() {
    _searchFocus.removeListener(_onSearchFocusChanged);
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

  static double _markerRadiusFor(double zoom) =>
      zoom >= 15 ? 9.0 : (zoom >= 13 ? 6.0 : 4.0);

  /// Camera gestures that mean "the user is driving the map", so bus-follow
  /// should let go.
  ///
  /// Every deliberate zoom or pan belongs here, not just dragging. Miss one and
  /// follow stays engaged, so the next poll re-centres and undoes the gesture
  /// three seconds later — which is what scroll-wheel zoom did on desktop.
  static const _userDrivenSources = {
    MapEventSource.onDrag,
    MapEventSource.onMultiFinger,
    MapEventSource.scrollWheel,
    MapEventSource.doubleTapZoomAnimationController,
    MapEventSource.doubleTapHold,
    MapEventSource.keyboard,
  };

  void _onMapEvent(MapEvent event) {
    if (_userDrivenSources.contains(event.source)) {
      _isTrackingBus = false;
    }

    // Every camera move carries the resulting zoom. Reading it only from
    // MapEventMoveEnd missed scroll-wheel zoom entirely — MapEventScrollWheelZoom
    // is a sibling class, not a MoveEnd — so _currentZoom went stale on desktop
    // and the bus-follow re-centre below then restored that stale value.
    //
    // Tracked without setState: MapEventWithMove fires every frame of a zoom, and
    // a rebuild here re-materialises ~4,300 polyline points. The only thing the
    // zoom feeds into the tree is a three-bucket marker radius, so a rebuild is
    // only warranted when it crosses a bucket edge.
    if (event is MapEventWithMove && event.camera.zoom != _currentZoom) {
      final crossedBucket = _markerRadiusFor(event.camera.zoom) !=
          _markerRadiusFor(_currentZoom);
      _currentZoom = event.camera.zoom;
      if (crossedBucket) setState(() {});
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

  bool _locationRequestInFlight = false;

  /// Asks for location and always says something about the outcome.
  ///
  /// Two web-specific hazards the previous version walked into. `geolocator_web`
  /// implements `requestPermission` as a bare `getCurrentPosition`, which never
  /// completes while the browser's permission bubble sits unanswered — so the
  /// button appeared dead with no feedback. And once an origin is blocked the
  /// page cannot re-prompt at all: `openAppSettings` throws `UnsupportedError`
  /// on web, so the only route back is the browser's own site settings, which
  /// the user has to be told about.
  Future<void> _requestLocation() async {
    if (_locationRequestInFlight) return;
    setState(() => _locationRequestInFlight = true);
    try {
      // Piggy-backs on this tap because iOS Safari only grants device
      // orientation from inside a user gesture. No-op on every other platform.
      unawaited(ref.read(headingSourceProvider).ensurePermission());

      final permission = await Geolocator.requestPermission()
          .timeout(const Duration(seconds: 20));
      if (!mounted) return;

      switch (permission) {
        case LocationPermission.always:
        case LocationPermission.whileInUse:
          ref.invalidate(userLocationProvider);
        case LocationPermission.denied:
          _showLocationMessage('Location access was dismissed. Tap again to retry.');
        case LocationPermission.deniedForever:
        case LocationPermission.unableToDetermine:
          _showLocationMessage(
            kIsWeb
                ? 'Location is blocked for this site. Use the lock icon in the address bar to allow it.'
                : 'Location is blocked. Enable it for Hub City Transit in your device settings.',
          );
      }
    } on TimeoutException {
      if (!mounted) return;
      _showLocationMessage('Location request timed out. Tap again to retry.');
    } finally {
      if (mounted) setState(() => _locationRequestInFlight = false);
    }
  }

  void _showLocationMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }


  @override
  Widget build(BuildContext context) {
    super.build(context); // required for AutomaticKeepAliveClientMixin

    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final selectedRoute = ref.watch(selectedRouteProvider);
    final activeTrip = ref.watch(activeTripProvider);
    final plannerOpen = ref.watch(plannerOpenProvider);
    WidgetsBinding.instance.addPostFrameCallback((_) => _measurePanel());
    ref.listen<PlannedTrip?>(activeTripProvider, (previous, next) {
      if (next == null || next == previous) return;
      // MapController throws if touched before FlutterMap has rendered once, and
      // this fires mid-build on arrival from the Plan tab.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _fitTripBounds(next);
      });
    });
    final selectedBus = ref.watch(selectedBusProvider);
    final routesAsync = ref.watch(routesProvider);
    final stopsAsync = ref.watch(stopsBySelectedRouteProvider);
    final selectedStop = _resolveSelectedStop(stopsAsync.asData?.value);
    _flyToSelectedStop(selectedStop);
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
    final markerRadius = _markerRadiusFor(_currentZoom);

    List<Polyline> polylines = [];
    if (activeTrip != null) {
      final used = activeTrip.itinerary.routeIds
          .map(RouteId.tryParse)
          .whereType<RouteId>()
          .toSet();
      polylines = (routesAsync.asData?.value ?? const [])
          .map((r) {
            final rId = RouteId.fromValue(r.routeId);
            return Polyline(
              points: r.polyline
                  .where((p) => p.length == 2 && GeoUtils.isValidLatLng(p[0], p[1]))
                  .map((p) => LatLng(p[0], p[1]))
                  .toList(),
              strokeWidth: 3,
              color: routeColor(rId)
                  .withValues(alpha: used.contains(rId) ? 0.22 : 0.08),
            );
          })
          .toList();
    } else {
      polylines = routesAsync.asData?.value.map((r) {
        final rId = RouteId.fromValue(r.routeId);
        return Polyline(
          points: r.polyline.where((p) => p.length == 2 && GeoUtils.isValidLatLng(p[0], p[1])).map((p) => LatLng(p[0], p[1])).toList(),
          strokeWidth: rId == selectedRoute ? 4.5 : 2,
          color: routeColor(rId).withValues(alpha: rId == selectedRoute ? 0.9 : 0.2),
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
          ref.read(activeTripProvider.notifier).state = null;
          _pushSelection(stop: stop);
        },
        child: Center(
          child: Container(
            width: markerRadius * 2,
            height: markerRadius * 2,
            decoration: BoxDecoration(
              color: selectedStop?.stopId == stop.stopId ? Colors.white : routeColors[selectedRoute],
              shape: BoxShape.circle,
              border: Border.all(
                color: selectedStop?.stopId == stop.stopId ? routeColor(selectedRoute) : Colors.white,
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
        // buildBusMarker is 80x90; anything shorter clips the OFFLINE label.
        width: 80, height: 92,
        child: buildBusMarker(
          busLocation: effectiveBusLocation,
          busStatus: busStatus,
          selectedRoute: selectedRoute,
          selectedBus: selectedBus,
          onTap: () {
            _animatedMapMove(LatLng(effectiveBusLocation.lat, effectiveBusLocation.lng), 16);
            ref.read(activeTripProvider.notifier).state = null;
            setState(() { _busInfoExpanded = true; _isTrackingBus = true; });
            _pushSelection();
          },
        ),
      ),
    ];


    final heading = ref.watch(compassProvider).asData?.value;

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
              // KeyboardOptions defaults to autofocus, which puts the map first
              // in the tab order and lets it swallow the arrow keys the search
              // results need. Panning by keyboard is no loss on a map that also
              // pans by drag; R/F zooming is what a keyboard user actually
              // lacked, since arrow-panning alone cannot change zoom.
              keyboardOptions: KeyboardOptions(
                autofocus: false,
                enableArrowKeysPanning: false,
                enableRFZooming: true,
              ),
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
            if (activeTrip != null)
              TripPolylineLayer(
                trip: activeTrip,
                routes: routesAsync.asData?.value ?? const [],
              ),
            MarkerLayer(markers: userMarkers),
            MarkerLayer(markers: stopMarkers),
            MarkerLayer(markers: busMarkers),
            if (activeTrip != null) TripMarkerLayer(trip: activeTrip),

            // Licence requirement, not decoration — ODbL and CARTO's terms both
            // want credit. Last so it paints above the layers.
            RichAttributionWidget(
              alignment: AttributionAlignment.bottomLeft,
              showFlutterMapAttribution: false,
              attributions: [
                TextSourceAttribution(
                  'OpenStreetMap contributors',
                  onTap: () => launchUrl(
                    Uri.parse('https://www.openstreetmap.org/copyright'),
                    mode: LaunchMode.externalApplication,
                  ),
                ),
                TextSourceAttribution(
                  'CARTO',
                  onTap: () => launchUrl(
                    Uri.parse('https://carto.com/attributions'),
                    mode: LaunchMode.externalApplication,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),

      // Sibling of the header, not nested in it, so panning the map can't hide an
      // active alert. Offset 68 = 8 padding + 52 bar + 8 gap; hardcoded because the
      // header is built inline below with no measurable key.
      Positioned(
        top: 0,
        left: 0,
        right: 0,
        child: SafeArea(
          bottom: false,
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 68, 10, 0),
                child: AnnouncementBanner(routeId: selectedRoute.value),
              ),
            ),
          ),
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
                      onPressed: () =>
                          ref.read(plannerOpenProvider.notifier).state = true,
                      visualDensity: VisualDensity.compact,
                      tooltip: 'Plan a trip',
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
                                  ref.read(analyticsProvider).logEvent('stop_search_selected', {
                                    'stop_id': item.stop.stopId,
                                    'route': item.route.name,
                                  });

                                  setState(() => _searchQuery = '');
                                  _searchCtrl.clear();
                                  _searchFocus.unfocus();
                                  _pushSelection(route: item.route, stop: item.stop);
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
                                  ref
                                      .read(pendingDestinationProvider.notifier)
                                      .state = PendingDestination(
                                    label: mainText,
                                    lat: item.place.lat,
                                    lng: item.place.lon,
                                  );
                                  ref.read(plannerOpenProvider.notifier).state =
                                      true;
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
      AnimatedPositioned(
          duration: const Duration(milliseconds: 250),
          curve: Curves.fastOutSlowIn,
          right: 12,
          bottom: _panelHeight + 16,
        child: GestureDetector(
          child: FloatingActionButton.small(
            heroTag: 'loc-fab',
            backgroundColor: cs.surfaceContainerLowest,
            foregroundColor: cs.primary,
            elevation: 4,
            onPressed: () {
              if (userPos != null) {
                _flyToUser(userPos);
              } else {
                _requestLocation();
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

      if (plannerOpen) const TripPlannerSheet(),

      // ── Bottom panel (bus info, stop detail, or active trip) ────────────────────────────
      if (activeTrip != null && !plannerOpen)
        Positioned(
          key: _panelKey,
          bottom: 24, left: 16, right: 16,
          child: SafeArea(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: _ActiveTripCard(
                  trip: activeTrip,
                  cs: cs,
                  tt: Theme.of(context).textTheme,
                  onClose: () =>
                      ref.read(activeTripProvider.notifier).state = null,
                ),
              ),
            ),
          ),
        )
      else if (selectedStop != null && !plannerOpen)
        _StopDetailSheet(
          key: _panelKey,
          stop: selectedStop,
          selectedRoute: selectedRoute,
          userPos: userPos,
          allStopsAsync: allStopsAsync,
          stopsAsync: stopsAsync,
          selectedBus: selectedBus,
          // Closing goes through the URL so browser Back and this button agree.
          onClose: () => _pushSelection(),
          onSwitchRoute: (r) {
            ref.read(analyticsProvider).logEvent('route_switched_from_stop', {'new_route': r.name});
            setState(() => _isTrackingBus = true);
            _pushSelection(route: r);
          },
        )
      else if (!plannerOpen)
        _BusInfoPanel(
          key: _panelKey,
          selectedRoute: selectedRoute,
          selectedBus: selectedBus,
          busAsync: busAsync,
          busStatus: busStatus,
          expanded: _busInfoExpanded,
          onToggleExpanded: () => setState(() => _busInfoExpanded = !_busInfoExpanded),
          onRouteChange: (r) {
            ref.read(analyticsProvider).logEvent('route_switched_from_panel', {'new_route': r.name});
            setState(() => _isTrackingBus = true);
            _pushSelection(route: r);
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

/// Summary of the itinerary currently drawn on the map.
class _ActiveTripCard extends StatelessWidget {
  const _ActiveTripCard({
    required this.trip,
    required this.cs,
    required this.tt,
    required this.onClose,
  });

  final PlannedTrip trip;
  final ColorScheme cs;
  final TextTheme tt;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final it = trip.itinerary;
    final rides = it.legs.where((l) => l.kind == TripLegKind.ride).toList();

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 14),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 14),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${it.durationMinutes} min · ${formatClock(it.departureMinutes)}'
                  ' – ${formatClock(it.arrivalMinutes)}',
                  style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded, size: 20),
                tooltip: 'Clear trip',
                constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                onPressed: onClose,
              ),
            ],
          ),
          const SizedBox(height: 2),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              for (final leg in rides)
                if (RouteId.tryParse(leg.routeId) case final route?)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: routeColors[route],
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      routeNames[route] ?? leg.routeId!,
                      style: tt.labelSmall?.copyWith(
                        color: onRouteColor(route),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
              Text(
                '${it.totalWalkMetres.round()} m walk'
                '${it.transferCount > 0 ? " · ${it.transferCount} transfer" : ""}',
                style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
              ),
            ],
          ),
          if (trip.destLabel case final String label) ...[
            const SizedBox(height: 6),
            Text('To $label',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
          ],
        ],
      ),
    );
  }
}
