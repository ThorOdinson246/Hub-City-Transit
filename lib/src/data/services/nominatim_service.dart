import 'package:dio/dio.dart';

class NominatimPlace {
  const NominatimPlace({
    required this.displayName,
    required this.lat,
    required this.lon,
  });

  final String displayName;
  final double lat;
  final double lon;

  factory NominatimPlace.fromJson(Map<String, dynamic> json) {
    return NominatimPlace(
      displayName: json['display_name'] as String,
      lat: double.parse(json['lat'] as String),
      lon: double.parse(json['lon'] as String),
    );
  }
}

class NominatimService {
  static const String _baseUrl = 'https://nominatim.openstreetmap.org/search';
  
  // Hattiesburg bounding box roughly:
  // minLon, minLat, maxLon, maxLat
  static const String _viewbox = '-89.4,31.4,-89.2,31.2';
  
  final Dio _dio = Dio(BaseOptions(
    baseUrl: _baseUrl,
    headers: {'User-Agent': 'HubCityTransitApp/1.0'},
  ));

  Future<List<NominatimPlace>> search(String query) async {
    try {
      final res = await _dio.get('', queryParameters: {
        'q': query,
        'format': 'json',
        'viewbox': _viewbox,
        'bounded': '1',
        'limit': '5',
      });
      
      if (res.statusCode != 200) return [];
      
      final List<dynamic> data = res.data;
      return data.map((json) => NominatimPlace.fromJson(json as Map<String, dynamic>)).toList();
    } catch (e) {
      return [];
    }
  }
}

