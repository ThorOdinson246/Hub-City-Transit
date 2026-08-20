import 'package:flutter/material.dart';

import 'transit_ids.dart';

const Map<RouteId, Color> routeColors = {
  RouteId.blue: Color(0xFF1C73B8),
  RouteId.gold: Color(0xFFF5CE0A),
  RouteId.green: Color(0xFF16A34A),
  RouteId.brown: Color(0xFF8B5E34),
  RouteId.orange: Color(0xFFF97316),
  RouteId.red: Color(0xFFDC2626),
  RouteId.purple: Color(0xFF7C3AED),
};

/// Foreground colour that stays legible on [routeColors] for [route].
///
/// Hardcoding white was failing WCAG badly on the lighter routes — white on
/// gold (`#F5CE0A`) is about 1.5:1 against a 4.5:1 requirement. Picking by
/// luminance keeps every route readable without hand-maintaining a second map.
Color onRouteColor(RouteId route) {
  final color = routeColors[route];
  if (color == null) return const Color(0xFFFFFFFF);
  return color.computeLuminance() > 0.5
      ? const Color(0xFF101418)
      : const Color(0xFFFFFFFF);
}

const Map<RouteId, String> routeNames = {
  RouteId.blue: 'Blue Route',
  RouteId.gold: 'Gold Route',
  RouteId.green: 'Green Route',
  RouteId.brown: 'Brown Route',
  RouteId.orange: 'Orange Route',
  RouteId.red: 'Red Route',
  RouteId.purple: 'Purple Route',
};

const Map<RouteId, String> routeDescriptions = {
  RouteId.blue: 'Hardy St · Midtown · Turtle Creek',
  RouteId.gold: 'USM',
  RouteId.green: '4th Street · USM · Midtown',
  RouteId.brown: '7th Street · Hwy 42 · Downtown',
  RouteId.orange: 'Broadway · William Carey · James St',
  RouteId.red: 'Country Club · Cloverleaf · William Carey',
  RouteId.purple: 'Palmer\'s Crossing · Edwards St',
};
