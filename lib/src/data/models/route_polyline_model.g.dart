// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'route_polyline_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_RoutePolylineModel _$RoutePolylineModelFromJson(Map<String, dynamic> json) =>
    _RoutePolylineModel(
      routeId: json['routeId'] as String,
      polyline: (json['polyline'] as List<dynamic>)
          .map(
            (e) =>
                (e as List<dynamic>).map((e) => (e as num).toDouble()).toList(),
          )
          .toList(),
    );

Map<String, dynamic> _$RoutePolylineModelToJson(_RoutePolylineModel instance) =>
    <String, dynamic>{
      'routeId': instance.routeId,
      'polyline': instance.polyline,
    };
