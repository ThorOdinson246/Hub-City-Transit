enum RouteId {
  blue,
  gold,
  green,
  brown,
  orange,
  red,
  purple;

  String get value => name;

  static RouteId fromValue(String raw) {
    return RouteId.values.firstWhere(
      (item) => item.name == raw,
      orElse: () => RouteId.blue,
    );
  }
}

enum BusId {
  blue1,
  blue2,
  gold1,
  gold2,
  green,
  brown,
  orange,
  red,
  purple;

  String get value => name;

  static BusId fromValue(String raw) {
    return BusId.values.firstWhere(
      (item) => item.name == raw,
      orElse: () => BusId.blue1,
    );
  }
}

RouteId busIdToRouteId(BusId busId) {
  final raw = busId.value;
  if (raw.startsWith('blue')) {
    return RouteId.blue;
  }
  if (raw.startsWith('gold')) {
    return RouteId.gold;
  }
  return RouteId.fromValue(raw);
}

const Map<RouteId, List<BusId>> routeBusMap = {
  RouteId.blue: [BusId.blue1, BusId.blue2],
  RouteId.gold: [BusId.gold1, BusId.gold2],
  RouteId.green: [BusId.green],
  RouteId.brown: [BusId.brown],
  RouteId.orange: [BusId.orange],
  RouteId.red: [BusId.red],
  RouteId.purple: [BusId.purple],
};
