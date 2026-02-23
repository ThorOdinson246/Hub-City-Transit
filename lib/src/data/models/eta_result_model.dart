import 'package:freezed_annotation/freezed_annotation.dart';

part 'eta_result_model.freezed.dart';
part 'eta_result_model.g.dart';

@freezed
abstract class EtaResultModel with _$EtaResultModel {
  const factory EtaResultModel({
    int? etaMinutes,
    int? nearestStopId,
    String? nearestStopName,
    required String busId,
    required String status,
    String? message,
  }) = _EtaResultModel;

  factory EtaResultModel.fromJson(Map<String, dynamic> json) =>
      _$EtaResultModelFromJson(json);
}
