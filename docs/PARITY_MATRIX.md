# Flutter Migration Parity Matrix (Snapshot: current Next.js repo)

## Implemented In This Pass

| Web Feature | Flutter Status | Notes |
|---|---|---|
| Route/Bus IDs and mapping | Implemented | `RouteId`, `BusId`, `routeBusMap` ported |
| Route color/name metadata | Implemented | Color and display names mirrored |
| Route polyline data source | Implemented | Loads WGS84 from `assets/data/routes_wgs84.json` |
| Stops fetch (`/api/stops`) | Implemented | Repository parses route-scoped and all-stops response forms |
| Bus location fetch (`/api/bus-location`) | Implemented | Handles `503` as offline/null |
| ETA fetch (`/api/eta`) | Implemented | Typed model and request path ready |
| Polling cadence | Partially implemented | Bus polling every 3s plus ETA auto-refresh every 30s after user requests ETA |
| Route and stop rendering on map | Implemented | `flutter_map` renders all route polylines, selected route stop markers, and live bus marker |
| Mobile nav shell (Map/Schedule/About) | Implemented | Bottom navigation via `go_router` shell |

## Pending For Full Parity

| Feature | Gap | Planned Module |
|---|---|---|
| Advanced map UX parity (recenter, detail interactions, bottom sheet behavior) | Base map rendering works but advanced parity interactions are pending | `features/map/presentation` |
| GPS-aware schedule adjustment algorithm | Partially implemented | Core use case now ports GPS snap + bounded/smoothed delta; full schedule dataset wiring is pending |
| Multi-bus trip disambiguation (`identifyTripByBusPosition`) | Implemented | Ported in schedule adjustment domain use case |
| Stale tri-state (`live/connecting/offline`) with thresholds | Implemented | Provider-derived status and map status card are live |
| ETA refresh and nearest-stop experience parity | Partially implemented | On-demand ETA card with location permission flow and 30s refresh is live; detailed stop-panel parity is pending |
| Transfer chip behavior and detailed stop panels | Not implemented | `features/stops` module |
| Search and advanced sidebar interactions | Not implemented | `features/map` UI layer |

## Platform Differences To Track

1. Browser geolocation flow maps to Android runtime permission flow.
2. Next.js API route caching headers are server-side concerns; Flutter client parity focuses on polling intervals and client-side memoization.
3. Bottom sheet interactions will be rebuilt with Flutter modal/persistent sheets preserving behavior, not DOM layout.
