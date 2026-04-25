// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'route_schedule_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_RouteScheduleModel _$RouteScheduleModelFromJson(Map<String, dynamic> json) =>
    _RouteScheduleModel(
      stops: (json['stops'] as List<dynamic>).map((e) => e as String).toList(),
      trips: (json['trips'] as List<dynamic>)
          .map((e) => (e as List<dynamic>).map((e) => e as String).toList())
          .toList(),
    );

Map<String, dynamic> _$RouteScheduleModelToJson(_RouteScheduleModel instance) =>
    <String, dynamic>{'stops': instance.stops, 'trips': instance.trips};
