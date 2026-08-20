# Migration Log

## 2026-04-23 - Phase 1 + Foundation Start

### Completed
- Audited source spec and progress tracker.
- Captured source git timeline for milestone mirroring.
- Created Android-first Flutter app scaffold at `flutter_app`.
- Added production dependencies: Riverpod, Dio, go_router, Freezed/json, flutter_map, connectivity, shared_preferences, intl, logger.
- Enabled stricter analyzer settings (`implicit-casts: false`, `implicit-dynamic: false`).
- Established modular architecture folders: `core`, `data`, `domain`, `features`, `shared`.
- Ported core IDs and mapping (`RouteId`, `BusId`, `routeBusMap`) and route metadata (colors/names/descriptions).
- Copied WGS84 polyline asset into Flutter assets.
- Implemented repository abstraction and initial implementation for routes/stops/bus-location/eta.
- Implemented app shell and routing (`/map`, `/schedule`, `/about`) with bottom navigation.
- Implemented baseline providers: selected route/bus, routes load, stops load, 3-second bus polling.
- Added root repo ignore safeguards for Flutter artifacts and Android secret files.

### In Progress
- Porting schedule adjustment algorithm from web `scheduleAdjust.ts`.
- Porting bus status tri-state (`live/connecting/offline`) and stale timing UX.

### Validation (current)
- `flutter pub get` completed successfully.
- `build_runner` generated Freezed/json files successfully.
- `flutter analyze` passes with no issues.
- `flutter test` passes.
- `flutter build apk --debug` is blocked by local Android SDK NDK license acceptance in this environment.

### Additional Completed Delta
- Fixed route polyline repository parsing to support the real route-keyed JSON asset shape (`{ routeId: [[lat,lng], ...] }`).
- Added Android location permissions and Flutter geolocation dependency for ETA flow.
- Added on-demand ETA card behavior in map UI with:
	- explicit location enable action
	- one-tap ETA fetch
	- periodic ETA refresh every 30 seconds after first request
	- offline/error/retry handling
- Added route parsing regression unit test for map JSON payload shape.
- Implemented `flutter_map` rendering with:
	- OpenStreetMap tile layer
	- all route polylines
	- selected-route emphasis
	- selected-route stop markers
	- live bus marker from polled API data
- Added in-map live status card for selected bus.
- Ported schedule adjustment domain use case with:
	- GPS stop snapping (haversine)
	- GPS-aware trip selection for multi-trip routes
	- bounded/smoothed live delta application
	- adjusted stop time projection
- Implemented tri-state bus status derivation (`live`, `connecting`, `offline`) using stale threshold parity.
- Added unit tests for schedule adjustment and bus status derivation.
- Upgraded schedule page with stop search/filter UX for Android parity progression.

## 2026-04-24 - Production Hardening + Validation Pass

### Completed
- Stabilized widget tests by overriding the all-route stops provider to prevent background network timers during teardown.
- Hardened network layer with explicit app user-agent and one-shot retry for transient timeout/connection/server failures.
- Added repository-level user-friendly error mapping for timeout/offline/server-unavailable scenarios.
- Hardened Android manifest defaults:
	- cleartext traffic disabled
	- app backup/data extraction disabled
	- network security policy pinned
	- production app label set to `Hub City Transit`
- Added Android release hardening:
	- `key.properties`-based release signing support
	- release minification and resource shrinking enabled
	- `proguard-rules.pro` added
	- signing secrets ignored in `.gitignore`
- Replaced placeholder README with concrete dev/release/deploy guidance for Play Store.

### Validation (current)
- `flutter analyze` passes with no issues.
- `flutter test` passes.
- `flutter build appbundle --release` remains blocked by environment-level Android NDK license acceptance on this machine.

### Risks/Notes
- Exact visual parity requires custom Flutter widgets for the web sidebar/bottom-sheet behavior.
- Flutter is moving to standalone runtime behavior with bundled route/stop/schedule data.
- Live bus location uses `ARCGIS_URL`, and ETA uses `GOOGLE_MAPS_API_KEY`, matching the web app's upstream service env names.
- Build blocker detail: `sdkmanager` is not available on PATH in this environment, so NDK license acceptance must be done via Android Studio SDK Manager or machine-level SDK tooling before APK builds can pass.

### Handoff Continuation Instructions
1. Run `flutter pub get`.
2. Run code generation with build_runner.
3. Run `flutter analyze` and fix all issues.
4. Implement `flutter_map` page layers.
5. Port schedule adjustment logic and write unit tests against known scenarios.
6. Update this log and parity matrix after each milestone.

## 2026-04-24 - Standalone data/runtime migration

### Completed
- Generated Flutter-bundled stops and schedules directly from the web source of truth using `tool/extract_web_data.mjs`.
- Added `assets/data/stops.json` and `assets/data/schedules.json` to the Flutter asset bundle.
- Reworked `TransitRepositoryImpl` to:
  - load routes, stops, and schedules from bundled assets
  - call ArcGIS directly for live bus positions using `ARCGIS_URL`
  - compute ETA directly against Google Directions using `GOOGLE_MAPS_API_KEY`
- Added `RouteScheduleModel` and `selectedRouteScheduleProvider`.
- Upgraded the schedule page from a basic stop list to a timed, GPS-aware schedule view with transfer chips.
- Re-aligned env/docs to the standalone architecture.

### Validation
- `dart run build_runner build --delete-conflicting-outputs`
- `flutter analyze`
- `flutter test`

### Notes
- The Flutter app no longer requires the Next.js `/api/*` layer for routes, stops, schedules, bus polling, or ETA.
- Remaining work is primarily UX parity and release-device verification, not core backend parity.

## 2026-04-25 - Final UI Polish & Readiness

### Completed
- Added direct Map UI integration for Search logic to simulate Google Maps UX natively.
- Removed bottom sheet overlay navigation for Search and replaced it with an integrated inline header.
- Scaled map stop markers dynamically based on map zoom levels (zoomed-out stops are smaller to reduce clutter).
- Enhanced Bottom Sheets:
  - Added swipe-down-to-dismiss gesture on the Stop Detail Panel.
  - Added swipe-down-to-collapse gesture on the Bus Info Panel.
- Added comprehensive telemetry layout for the bus tracker (heading direction, speed strings, last seen intervals).
- Enabled dynamically adjusting Map floating action buttons (Location FAB) that animate smoothly when the bottom info sheet transitions heights.
- Created Dark Basemap functionality configured through `SharedPreferences` toggle in Settings, allowing deep dark UX integration in `flutter_map`.
- Bound placeholder buttons in Settings to `SnackBar` hints for immediate production deployment cleanly.
- Resolved ArcGis trailing space parsing in `.env` variable ingestion.
