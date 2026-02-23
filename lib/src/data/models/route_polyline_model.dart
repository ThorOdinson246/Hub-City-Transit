import 'package:freezed_annotation/freezed_annotation.dart';

part 'route_polyline_model.freezed.dart';
part 'route_polyline_model.g.dart';

@freezed
abstract class RoutePolylineModel with _$RoutePolylineModel {
  const factory RoutePolylineModel({
    required String routeId,
    required List<List<double>> polyline,
  }) = _RoutePolylineModel;

  factory RoutePolylineModel.fromJson(Map<String, dynamic> json) =>
      _$RoutePolylineModelFromJson(json);
}
