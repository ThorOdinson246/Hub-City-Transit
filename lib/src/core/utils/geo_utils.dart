class GeoUtils {
  /// Validates that latitude and longitude are not null and are finite numbers.
  /// This prevents flutter_map from throwing Red Screen exceptions on invalid data.
  static bool isValidLatLng(double? lat, double? lng) {
    if (lat == null || lng == null) return false;
    if (lat.isNaN || lng.isNaN) return false;
    if (lat.isInfinite || lng.isInfinite) return false;
    // Basic bounds checking for WGS84
    if (lat < -90 || lat > 90) return false;
    if (lng < -180 || lng > 180) return false;
    return true;
  }
}
