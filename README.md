# Hub City Transit — Flutter App

A mobile companion to the [Hub City Transit web app](https://hubcitytransitv2.mukeshpoudel.com.np/), bringing real-time bus tracking for Hattiesburg, MS to Android (and eventually iOS).

> **Work in progress** — Play Store release coming soon.

---

## Technical Architecture

The app is built using a modern, reactive stack with a focus on performance and state persistence.

### Tech Stack
- **State Management:** [Riverpod](https://riverpod.dev/) — utilized for reactive data binding and provider-to-provider dependency chaining (e.g., `AdjustmentResult` derived from `BusLocation` + `Schedule`).
- **Routing:** [GoRouter](https://pub.dev/packages/go_router) — implementing `StatefulShellRoute` to maintain independent widget trees (and map state) across navigation tabs.
- **Mapping:** [flutter_map](https://pub.dev/packages/flutter_map) — leverages OpenStreetMap (CARTO tiles) with custom `CustomPainter` implementations for high-performance marker rendering.

---

## The Schedule Adjustment Engine

The core logic of the app is a real-time "Delta Engine" that predicts arrivals based on live GPS movement:

1.  **Spatial Snapping:** The latest GPS coordinate from the ArcGIS FeatureServer is snapped to the nearest stop using the **Haversine formula**.
2.  **State Identification:** The engine identifies which scheduled trip the bus is currently serving based on the current time and stop sequence.
3.  **Delta Computation:** 
    `appliedDelta = currentTime - scheduledArrivalAtSnappedStop`
4.  **Uniform Propagation:** This delta is smoothed (0.85x coefficient) and applied to all future stops in the trip. If a bus is running 5 minutes late, every upcoming arrival time in the UI is shifted by +5 minutes.
5.  **Fallback Logic:** When GPS heartbeats exceed the `staleThreshold` (180s), the app marks the bus as `offline` and reverts to the static timetable.

---

## API & Data Integration

- **Real-time GPS:** Polled via the ArcGIS REST API (`FeatureServer/1/query`).
- **Geocoding:** Nominatim (OpenStreetMap) implementation with 600ms debouncing to respect rate limits.
- **Navigation:** Custom routing algorithm that computes the "Optimal Boarding Stop" by minimizing the sum of walking distance and transit distance.

---

## Getting started

### Prerequisites

- Flutter 3.x
- Android SDK (for Android builds)
- A `.env` file in the project root (see below)

### Setup

```bash
git clone https://github.com/ThorOdinson246/hubcitytransit
cd hubcitytransit/flutter_app
flutter pub get
flutter pub run build_runner build --delete-conflicting-outputs
```

Create a `.env` file in `flutter_app/`:

```
ARCGIS_URL=<your arcgis endpoint>
HCT_BASE_API_URL=<api base url>
GOOGLE_MAPS_API_KEY=<optional>
```

Then run:

```bash
flutter run
```

---

## Project structure

```
lib/
├── src/
│   ├── app/          providers (Riverpod), router (GoRouter)
│   ├── core/         constants, theme, network, utilities
│   ├── data/         models, repository, services
│   ├── domain/       repository interface, schedule adjustment use case
│   └── features/     map, schedule, settings, fares, onboarding, about
```

State management is Riverpod. Navigation is GoRouter with `StatefulShellRoute` so the map keeps its state when you switch tabs.

---

## Development Highlights

### 📍 Spatial Snapping & Delta Smoothing
To prevent "jumping" arrivals, the engine snaps the live GPS feed to the nearest stop and applies a smoothing coefficient to the time delta.

```dart
// Snapping live GPS to the static schedule
final snap = _snapToNearestStop(gpsStops, busLat, busLng);
if (snap != null && snap.distance < maxSnapDistanceMeters) {
  final rawDelta = nowMinutes - scheduledArrivalAtStop;
  // Apply 0.85 smoothing factor to prevent jitter
  appliedDelta = (appliedDelta * smoothingFactor) + (rawDelta * (1 - smoothingFactor));
}
```

### 🛣️ Dynamic Waypoint Slicing
The trip planner doesn't just show straight lines; it slices the circular route polylines into precise segments between your boarding and destination stops.

```dart
// Slicing a circular route polyline into a specific path segment
List<LatLng> _getRouteSlice(List<dynamic> rawPolyline, LatLng start, LatLng end) {
  int startIdx = _findNearestPointIndex(rawPolyline, start);
  int endIdx = _findNearestPointIndex(rawPolyline, end);
  
  if (startIdx <= endIdx) {
    return rawPolyline.sublist(startIdx, endIdx + 1);
  } else {
    // Handle wrap-around for circular transit loops
    return [...rawPolyline.sublist(startIdx), ...rawPolyline.sublist(0, endIdx + 1)];
  }
}
```

---

## Related

- Web app: [hubcitytransitv2.mukeshpoudel.com.np](https://hubcitytransitv2.mukeshpoudel.com.np/)
