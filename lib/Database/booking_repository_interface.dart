import 'dart:async';
import 'booking_model.dart';

/// Interface for booking repository operations
abstract class IBookingRepository {
  /// Fetches all active bookings for a driver
  Future<List<Booking>> fetchActiveBookings(String driverId);

  /// Fetches completed bookings count for a driver
  Future<int> fetchCompletedBookingsCount(String driverId);

  /// Updates the status of a booking
  Future<bool> updateBookingStatus(String bookingId, String newStatus);

  /// Stream of active bookings for real-time updates
  Stream<List<Booking>> activeBookingsStream(String driverId);
}
