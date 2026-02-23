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
