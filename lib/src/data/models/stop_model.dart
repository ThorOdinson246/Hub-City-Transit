import 'package:freezed_annotation/freezed_annotation.dart';

part 'stop_model.freezed.dart';
part 'stop_model.g.dart';

@freezed
abstract class StopModel with _$StopModel {
  const factory StopModel({
    required int stopId,
    required String location,
    required double lat,
    required double lng,
    required String direction,
  }) = _StopModel;

  factory StopModel.fromJson(Map<String, dynamic> json) =>
      _$StopModelFromJson(json);
}
