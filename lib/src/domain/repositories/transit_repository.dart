import '../../data/models/bus_location_model.dart';
import '../../data/models/eta_result_model.dart';
import '../../data/models/route_polyline_model.dart';
import '../../data/models/route_schedule_model.dart';
import '../../data/models/stop_model.dart';

abstract interface class TransitRepository {
  Future<List<RoutePolylineModel>> getRoutes();

  Future<List<StopModel>> getStops({String? routeId});

  Future<RouteScheduleModel?> getSchedule(String routeId);

  Future<BusLocationModel?> getBusLocation(String busId);

  Future<EtaResultModel> getEta({
    required String busId,
    required double userLat,
    required double userLng,
  });
}
