import 'package:freezed_annotation/freezed_annotation.dart';

part 'bus_location_model.freezed.dart';
part 'bus_location_model.g.dart';

@freezed
abstract class BusLocationModel with _$BusLocationModel {
  const factory BusLocationModel({
    required double lat,
    required double lng,
    required String busId,
    required DateTime lastSeen,
    double? heading,
    double? speed,
  }) = _BusLocationModel;

  factory BusLocationModel.fromJson(Map<String, dynamic> json) =>
      _$BusLocationModelFromJson(json);
}
