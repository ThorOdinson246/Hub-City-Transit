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

  /// Null for anything unrecognised, including null input.
  ///
  /// [fromValue] falls back to blue, which is wrong for a URL parameter: absent
  /// has to mean "no override" and a typo'd route has to mean "no override"
  /// too, not "silently show blue".
  static RouteId? tryParse(String? raw) {
    if (raw == null) return null;
    for (final item in RouteId.values) {
      if (item.name == raw) return item;
    }
    return null;
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
