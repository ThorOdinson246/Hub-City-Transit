import 'package:freezed_annotation/freezed_annotation.dart';

part 'route_schedule_model.freezed.dart';
part 'route_schedule_model.g.dart';

@freezed
abstract class RouteScheduleModel with _$RouteScheduleModel {
  const factory RouteScheduleModel({
    required List<String> stops,
    required List<List<String>> trips,
  }) = _RouteScheduleModel;

  factory RouteScheduleModel.fromJson(Map<String, dynamic> json) =>
      _$RouteScheduleModelFromJson(json);
}
