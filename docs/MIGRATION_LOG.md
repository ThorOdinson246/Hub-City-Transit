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

### Risks/Notes
- Exact visual parity requires custom Flutter widgets for the web sidebar/bottom-sheet behavior.
- API base URL currently defaults to production domain; environment override uses `--dart-define=HCT_BASE_API_URL=...`.
- Build blocker detail: `sdkmanager` is not available on PATH in this environment, so NDK license acceptance must be done via Android Studio SDK Manager or machine-level SDK tooling before APK builds can pass.

### Handoff Continuation Instructions
1. Run `flutter pub get`.
2. Run code generation with build_runner.
3. Run `flutter analyze` and fix all issues.
4. Implement `flutter_map` page layers.
5. Port schedule adjustment logic and write unit tests against known scenarios.
6. Update this log and parity matrix after each milestone.
