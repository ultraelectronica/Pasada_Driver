import 'dart:async';

import 'package:pasada_driver_side/data/models/booking_model.dart';
import 'package:pasada_driver_side/data/models/booking_receipt_model.dart';

/// Abstract repository that defines all data-access operations surrounding
/// bookings, irrespective of the underlying data source.
abstract class BookingRepository {
  /// Fetch active (requested / accepted / ongoing) bookings for the driver.
  Future<List<Booking>> fetchActiveBookings(String driverId);

  /// Count how many completed bookings the driver already has.
  Future<int> fetchCompletedBookingsCount(String driverId);

  /// Update the ride status of a particular booking.
  Future<bool> updateBookingStatus(String bookingId, String newStatus);

  /// Update the ID acceptance flag for a particular booking.
  Future<bool> updateIdAccepted(String bookingId, bool accepted);

  /// Fetch current fare for a booking (returns null if absent)
  Future<int?> fetchFare(String bookingId);

  /// Update fare for a booking (stored as integer cents or whole currency as per schema)
  Future<bool> updateFare(String bookingId, int newFare);

  /// Real-time stream of the driver's active bookings.
  Stream<List<Booking>> activeBookingsStream(String driverId);

  /// Fetch bookings for today with receipt details
  Future<List<BookingReceipt>> fetchTodayBookings(String driverId);

  /// Fetch bookings for a specific date range with receipt details
  Future<List<BookingReceipt>> fetchBookingsByDateRange(
    String driverId,
    DateTime startDate,
    DateTime endDate,
  );
}
