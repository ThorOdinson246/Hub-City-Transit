import '../constants/transit_ids.dart';
import '../../data/models/stop_model.dart';

/// A transfer connection between two stops on different routes.
class TransferStopConnection {
  const TransferStopConnection({
    required this.routeId,
    required this.stopId,
    required this.location,
  });

  final RouteId routeId;
  final int stopId;
  final String location;
}

const _kTransferMap = <String, List<(String routeId, int stopId, String location)>>{
  // ===== TRAIN DEPOT — Brown ↔ Orange ↔ Purple =====
  'brown-1': [('orange', 1, 'Train Depot'), ('purple', 1, 'Train Depot')],
  'brown-33': [('orange', 29, 'Train Depot (return)'), ('purple', 35, 'Train Depot (return)')],
  'orange-1': [('brown', 1, 'Train Depot'), ('purple', 1, 'Train Depot')],
  'orange-29': [('brown', 33, 'Train Depot (return)'), ('purple', 35, 'Train Depot (return)')],
  'purple-1': [('brown', 1, 'Train Depot'), ('orange', 1, 'Train Depot')],
  'purple-35': [('brown', 33, 'Train Depot (return)'), ('orange', 29, 'Train Depot (return)')],

  // ===== WALMART / HWY 49 — Green ↔ Orange ↔ Red =====
  'green-1': [('orange', 18, 'Service Rd at Walmart'), ('red', 23, 'Walmart (return)')],
  'orange-18': [('green', 1, 'Walmart at Hwy 49'), ('red', 23, 'Walmart (return)')],
  'red-23': [('green', 1, 'Walmart at Hwy 49'), ('orange', 18, 'Service Rd at Walmart')],

  // ===== HARDY ST — Blue ↔ Gold =====
  'blue-11': [('gold', 6, 'Hardy St and 31st Ave')],
  'gold-6': [('blue', 11, 'Hardy St and 31st Ave')],

  // ===== HARDY ST — Blue ↔ Green =====
  'blue-30': [('green', 12, 'Hardy St at Midtown Market Shopping Center')],
  'green-12': [('blue', 30, 'Hardy St at Midtown Market Place')],
  'blue-31': [('green', 13, 'Hardy St and 34th Ave')],
  'green-13': [('blue', 31, 'Hardy St and 34th Ave')],
  'blue-32': [('green', 14, 'Hardy St and 30th Ave')],
  'green-14': [('blue', 32, 'Hardy St and 30th Ave')],
  'blue-33': [('green', 15, 'S 29th Ave and Hardy St')],
  'green-15': [('blue', 33, 'S 29th and Hardy St')],

  // ===== FRONT ST / CITY HALL — Blue ↔ Orange =====
  'blue-44': [('orange', 28, 'Front St and Forrest St at City Hall')],
  'orange-28': [('blue', 44, 'Front St and Forrest St at City Hall')],

  // ===== EDWARDS ST — Orange ↔ Purple =====
  'orange-7': [
    ('purple', 5, 'Edwards St and Katie Ave'),
    ('purple', 31, 'Edwards St and Katie Ave (return)'),
    ('purple', 32, 'Edwards St and Katie St (return)'),
  ],
  'orange-8': [
    ('purple', 6, 'Edwards St and Duke Ave'),
    ('purple', 10, 'Edwards St and Duke Ave (return)'),
  ],
  'orange-9': [
    ('purple', 7, 'Edwards St and Tuscan Ave'),
    ('purple', 30, 'Edwards St and Tuscan Ave (return)'),
  ],
  'purple-5': [('orange', 7, 'Edwards St and Katie Ave')],
  'purple-31': [('orange', 7, 'Edwards St and Katie Ave')],
  'purple-32': [('orange', 7, 'Edwards St and Katie Ave')],
  'purple-6': [('orange', 8, 'Edwards St and Duke Ave')],
  'purple-10': [('orange', 8, 'Edwards St and Duke Ave')],
  'purple-7': [('orange', 9, 'Edwards St and Tuscan Ave')],
  'purple-30': [('orange', 9, 'Edwards St and Tuscan Ave')],

  // ===== BROADWAY / LINCOLN — Orange ↔ Red =====
  'orange-17': [('red', 1, 'Bartur St and Broadway Dr')],
  'red-1': [('orange', 17, 'Bartur St and Broadway Dr')],
  'orange-22': [('red', 3, 'Service Dr and W Pine St')],
  'red-3': [('orange', 22, 'W Pine St and Service Dr')],
  'orange-21': [('red', 4, 'Lincoln Rd and Hill St')],
  'red-4': [('orange', 21, 'Lincoln Rd and Hill St')],

  // ===== TUSCAN / WILLIAM CAREY PKWY — Orange ↔ Red =====
  'orange-10': [('red', 19, 'Tuscan Ave and William Carey Pkwy')],
  'red-19': [('orange', 10, 'Tuscan Ave and William Carey Parkway')],

  // ===== MAIN ST AND SHORT ST — Brown ↔ Orange =====
  'brown-32': [('orange', 12, 'Main St and Short St')],
  'orange-12': [('brown', 32, 'Main St and Short St')],

  // ===== HILLCREST AREA — Brown ↔ Green =====
  'brown-24': [('green', 4, 'W 7th St at Hillcrest Lot')],
  'green-4': [('brown', 24, 'W 7th St and Service Dr at Hillcrest Lot')],
};

/// Returns true if [stopId] on [routeId] is a designated transfer stop.
bool isTransferStop(RouteId routeId, int stopId) {
  return _kTransferMap.containsKey('${routeId.value}-$stopId');
}

/// Returns the list of connecting routes/stops for a given stop.
/// Returns an empty list if [stopId] on [routeId] is not a transfer stop.
List<TransferStopConnection> findTransferConnections({
  required RouteId selectedRoute,
  required StopModel stop,
  // ignored — kept for backwards-compat call signature
  Map<RouteId, List<StopModel>>? allStopsByRoute,
  double thresholdMeters = 110,
}) {
  final key = '${selectedRoute.value}-${stop.stopId}';
  final entries = _kTransferMap[key] ?? const [];

  return entries
      .map((t) {
        final routeId = RouteId.values.firstWhere(
          (r) => r.value == t.$1,
          orElse: () => RouteId.blue,
        );
        return TransferStopConnection(
          routeId: routeId,
          stopId: t.$2,
          location: t.$3,
        );
      })
      .toList();
}
