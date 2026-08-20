import 'package:flutter_dotenv/flutter_dotenv.dart';

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

String get arcGisUrl => dotenv.env['ARCGIS_URL'] ?? '';
String get baseApiUrl => dotenv.env['HCT_BASE_API_URL'] ?? '';

/// Absolute URL of the announcements document. Empty until the API tier exists,
/// in which case the app falls back to cache and then to the bundled asset —
/// the feature degrades to "no alerts" rather than breaking.
String get announcementsEndpoint => dotenv.env['HCT_ANNOUNCEMENTS_URL'] ?? '';
