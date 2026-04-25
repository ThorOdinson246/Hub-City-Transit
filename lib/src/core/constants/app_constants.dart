const String appName = 'Hub City Transit';
const Duration busRefreshInterval = Duration(seconds: 3);
const Duration etaRefreshInterval = Duration(seconds: 30);
const Duration busStaleThreshold = Duration(seconds: 90);
const Duration etaCacheTtl = Duration(seconds: 30);
const Duration requestTimeout = Duration(seconds: 12);

const String localRouteAssetPath = 'assets/data/routes_wgs84.json';
const String localStopsAssetPath = 'assets/data/stops.json';

const String baseApiUrl = String.fromEnvironment(
  'HCT_BASE_API_URL',
  defaultValue: String.fromEnvironment(
    'NEXT_PUBLIC_SITE_URL',
    defaultValue: '',
  ),
);
