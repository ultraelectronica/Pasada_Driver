import 'package:pasada_driver_side/data/models/allowed_stop_model.dart';

/// Abstract repository that defines all data-access operations for allowed stops.
abstract class AllowedStopRepository {
  /// Fetch all active stops for a specific route, ordered by stop_order
  Future<List<AllowedStop>> fetchStopsByRoute(int officialRouteId);

  /// Fetch all active stops (for all routes)
  Future<List<AllowedStop>> fetchAllActiveStops();

  /// Fetch a single stop by ID
  Future<AllowedStop?> fetchStopById(String allowedStopId);
}
