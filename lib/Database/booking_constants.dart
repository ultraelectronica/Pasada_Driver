/// Constants for booking operations
class BookingConstants {
  // Booking status constants
  static const String statusRequested = 'requested';
  static const String statusAccepted = 'accepted';
  static const String statusOngoing = 'ongoing';
  static const String statusCompleted = 'completed';
  static const String statusCancelled = 'cancelled';

  // Error types for better error handling
  static const String errorTypeNetwork = 'network_error';
  static const String errorTypeDatabase = 'database_error';
  static const String errorTypeTimeout = 'timeout_error';
  static const String errorTypeUnknown = 'unknown_error';

  // Database field names
  static const String fieldBookingId = 'booking_id';
  static const String fieldPassengerId = 'passenger_id';
  static const String fieldDriverId = 'driver_id';
  static const String fieldRideStatus = 'ride_status';
  static const String fieldPickupLat = 'pickup_lat';
  static const String fieldPickupLng = 'pickup_lng';
  static const String fieldDropoffLat = 'dropoff_lat';
  static const String fieldDropoffLng = 'dropoff_lng';
  static const String fieldSeatType = 'seat_type';

  // Default values
  static const String defaultSeatType = 'sitting';
  static const String defaultLogType = 'INFO';
  static const String logFileName = 'pasada_bookings.log';

  // Validation thresholds
  static const double nearDestinationThreshold = 10.0; // meters

  // Retry configuration
  static const int defaultMaxRetries = 2;
  static const Duration defaultRetryDelay = Duration(seconds: 1);

  // Private constructor to prevent instantiation
  BookingConstants._();
}
