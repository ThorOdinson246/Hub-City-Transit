import 'package:flutter_dotenv/flutter_dotenv.dart';

const String appName = 'Hub City Transit';
const Duration busRefreshInterval = Duration(seconds: 3);
const Duration etaRefreshInterval = Duration(seconds: 30);
const Duration busStaleThreshold = Duration(seconds: 90);
const Duration etaCacheTtl = Duration(seconds: 30);
const Duration requestTimeout = Duration(seconds: 12);

const String localRouteAssetPath = 'assets/data/routes_wgs84.json';
const String localStopsAssetPath = 'assets/data/stops.json';
const String localScheduleAssetPath = 'assets/data/schedules.json';

String get arcGisUrl => dotenv.env['ARCGIS_URL'] ?? '';
String get googleMapsApiKey => dotenv.env['GOOGLE_MAPS_API_KEY'] ?? '';
String get baseApiUrl => dotenv.env['HCT_BASE_API_URL'] ?? '';
