import 'package:pasada_driver_side/data/models/manual_booking_data.dart';

/// Repository for creating manual bookings in the database
abstract class ManualBookingRepository {
  /// Create multiple booking records from manual booking data
  /// Returns the number of bookings successfully created
  Future<int> createManualBookings({
    required ManualBookingData bookingData,
    required String driverId,
    required int routeId,
  });
}
