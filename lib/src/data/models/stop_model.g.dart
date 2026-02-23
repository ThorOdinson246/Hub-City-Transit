// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'stop_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_StopModel _$StopModelFromJson(Map<String, dynamic> json) => _StopModel(
  stopId: (json['stopId'] as num).toInt(),
  location: json['location'] as String,
  lat: (json['lat'] as num).toDouble(),
  lng: (json['lng'] as num).toDouble(),
  direction: json['direction'] as String,
);

Map<String, dynamic> _$StopModelToJson(_StopModel instance) =>
    <String, dynamic>{
      'stopId': instance.stopId,
      'location': instance.location,
      'lat': instance.lat,
      'lng': instance.lng,
      'direction': instance.direction,
    };
