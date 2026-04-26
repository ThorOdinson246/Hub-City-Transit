import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter/widgets.dart';

void main() {
  final fit = CameraFit.bounds(bounds: LatLngBounds(const LatLng(0,0), const LatLng(1,1)));
  print(fit.toString());
}
