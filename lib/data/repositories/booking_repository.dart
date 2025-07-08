import 'dart:async';

import 'package:pasada_driver_side/data/models/booking_model.dart';

/// Abstract repository that defines all data-access operations surrounding
/// bookings, irrespective of the underlying data source.
abstract class BookingRepository {
  /// Fetch active (requested / accepted / ongoing) bookings for the driver.
  Future<List<Booking>> fetchActiveBookings(String driverId);

  /// Count how many completed bookings the driver already has.
  Future<int> fetchCompletedBookingsCount(String driverId);

  /// Update the ride status of a particular booking.
  Future<bool> updateBookingStatus(String bookingId, String newStatus);

  /// Real-time stream of the driver's active bookings.
  Stream<List<Booking>> activeBookingsStream(String driverId);
}
