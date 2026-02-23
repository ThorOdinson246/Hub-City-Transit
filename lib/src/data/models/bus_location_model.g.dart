// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'bus_location_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_BusLocationModel _$BusLocationModelFromJson(Map<String, dynamic> json) =>
    _BusLocationModel(
      lat: (json['lat'] as num).toDouble(),
      lng: (json['lng'] as num).toDouble(),
      busId: json['busId'] as String,
      lastSeen: DateTime.parse(json['lastSeen'] as String),
      heading: (json['heading'] as num?)?.toDouble(),
      speed: (json['speed'] as num?)?.toDouble(),
    );

Map<String, dynamic> _$BusLocationModelToJson(_BusLocationModel instance) =>
    <String, dynamic>{
      'lat': instance.lat,
      'lng': instance.lng,
      'busId': instance.busId,
      'lastSeen': instance.lastSeen.toIso8601String(),
      'heading': instance.heading,
      'speed': instance.speed,
    };
