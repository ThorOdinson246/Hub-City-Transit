import 'package:dio/dio.dart';

void main() async {
  final dio = Dio();
  final url = 'https://utility.arcgis.com/usrsvcs/servers/b02066689d504f5f9428029f7268e060/rest/services/Hosted/8bd5047cc5bf4195887cc5237cf0d3e0_Track_View/FeatureServer/1/query';
  try {
    final response = await dio.get(
      url,
      queryParameters: {
        'f': 'json',
        'where': "LOWER(full_name) = 'hct blue2'",
        'outFields': 'full_name,speed,course,location_timestamp',
        'returnGeometry': 'true',
        'outSR': '4326',
      },
    );
    print(response.statusCode);
    print(response.data);
  } catch (e) {
    print(e);
  }
}
