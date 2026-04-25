# Flutter Migration Parity Matrix (Snapshot: current Next.js repo)

## Implemented In This Pass

| Web Feature | Flutter Status | Notes |
|---|---|---|
| Route/Bus IDs and mapping | Implemented | `RouteId`, `BusId`, `routeBusMap` ported |
| Route color/name metadata | Implemented | Color and display names mirrored |
| Route polyline data source | Implemented | Loads WGS84 from `assets/data/routes_wgs84.json` |
| Stops data | Implemented | Bundled from web source into `assets/data/stops.json` |
| Schedule data | Implemented | Bundled from web source into `assets/data/schedules.json` |
| Bus location fetch | Implemented | Direct ArcGIS polling using `ARCGIS_URL` |
| ETA fetch | Implemented | In-app Google Directions batching logic using `GOOGLE_MAPS_API_KEY` |
| Polling cadence | Partially implemented | Bus polling every 3s plus ETA auto-refresh every 30s after user requests ETA |
| Route and stop rendering on map | Implemented | `flutter_map` renders all route polylines, selected route stop markers, and live bus marker |
| Stop detail interactions and transfer chips | Implemented | Stop selection card on map with transfer route chips and route-switch action |
| Schedule transfer filtering | Implemented | Transfer-only filter and transfer route chips on schedule list |
| Schedule/timeline rendering | Partially implemented | Route schedule view now renders bundled times with GPS-aware highlighting, but full mobile parity still needs richer bus/stop detail timelines |
| Mobile nav shell (Map/Schedule/About) | Implemented | Bottom navigation via `go_router` shell |

## Pending For Full Parity

| Feature | Gap | Planned Module |
|---|---|---|
| Advanced map UX parity (recenter, detail interactions, bottom sheet behavior) | Base map rendering works but advanced parity interactions are pending | `features/map/presentation` |
| GPS-aware schedule adjustment algorithm | Implemented | Core use case ports GPS snap + bounded/smoothed delta against bundled schedules |
| Multi-bus trip disambiguation (`identifyTripByBusPosition`) | Implemented | Ported in schedule adjustment domain use case |
| Stale tri-state (`live/connecting/offline`) with thresholds | Implemented | Provider-derived status and map status card are live |
| ETA refresh and nearest-stop experience parity | Partially implemented | On-demand ETA card with location permission flow and 30s refresh is live; richer stop-by-stop ETA storytelling is still pending |
| Transfer chip behavior and detailed stop panels | Implemented | Delivered within `features/map` and `features/schedule` presentation layers |
| Search and advanced sidebar interactions | Not implemented | `features/map` UI layer |
| Android release hardening | Implemented | Network security config, no-backup policy, minify/shrink, and release-signing support via `key.properties` |

## Platform Differences To Track

1. Browser geolocation flow maps to Android runtime permission flow.
2. The Flutter app now bundles web-derived static transit data and only depends on upstream live/ETA services, not the Next.js `/api/*` layer.
3. Bottom sheet interactions will be rebuilt with Flutter modal/persistent sheets preserving behavior, not DOM layout.
