const String appName = 'Hub City Transit';
const Duration busRefreshInterval = Duration(seconds: 3);
const Duration busStaleThreshold = Duration(seconds: 90);
const Duration requestTimeout = Duration(seconds: 12);

const String localRouteAssetPath = 'assets/data/routes_wgs84.json';
const String localStopsAssetPath = 'assets/data/stops.json';
const String localScheduleAssetPath = 'assets/data/schedules.json';

/// How often the announcements document is re-checked while the app is in the
/// foreground. Conditional requests, so a no-change poll costs a 304.
const Duration announcementsPollInterval = Duration(minutes: 5);

/// Faster cadence while a severe alert is live, when a correction or an
/// all-clear is most time-sensitive.
const Duration announcementsUrgentPollInterval = Duration(minutes: 1);

/// A cached document older than this is presented as possibly out of date
/// rather than as current fact.
const Duration announcementsStaleAfter = Duration(minutes: 30);

// Compile-time configuration, supplied with --dart-define-from-file=env/dart_defines.json.
// Not an asset: on web a bundled asset is served at a public URL, and a value baked into the
// binary at least cannot be swapped without a rebuild. Nothing here is secret — the app holds
// no credential, which is what makes a static host viable at all.
const String arcGisUrl = String.fromEnvironment('ARCGIS_URL');
const String baseApiUrl = String.fromEnvironment('HCT_BASE_API_URL');

/// Absolute URL of the announcements document. Empty until one is published, in which case the
/// app falls back to cache and then to the bundled asset — the feature degrades to "no alerts"
/// rather than breaking.
const String announcementsEndpoint = String.fromEnvironment('HCT_ANNOUNCEMENTS_URL');

/// Public Mapbox token (`pk.…`), scoped to directions:read. Empty falls back to
/// straight-line walk estimates, so the app works without it.
const String mapboxToken = String.fromEnvironment('MAPBOX_TOKEN');

const String localTransitAssetPath = 'assets/data/transit.json';
