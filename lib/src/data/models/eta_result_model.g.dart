// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'eta_result_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_EtaResultModel _$EtaResultModelFromJson(Map<String, dynamic> json) =>
    _EtaResultModel(
      etaMinutes: (json['etaMinutes'] as num?)?.toInt(),
      nearestStopId: (json['nearestStopId'] as num?)?.toInt(),
      nearestStopName: json['nearestStopName'] as String?,
      busId: json['busId'] as String,
      status: json['status'] as String,
      message: json['message'] as String?,
    );

Map<String, dynamic> _$EtaResultModelToJson(_EtaResultModel instance) =>
    <String, dynamic>{
      'etaMinutes': instance.etaMinutes,
      'nearestStopId': instance.nearestStopId,
      'nearestStopName': instance.nearestStopName,
      'busId': instance.busId,
      'status': instance.status,
      'message': instance.message,
    };
