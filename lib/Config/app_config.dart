/// Configuration class to centralize app timing and threshold settings
class AppConfig {
  // Debounce times (in seconds)
  static const int fetchDebounceTime =
      5; // Minimum time between booking fetches
  static const int periodicFetchInterval =
      30; // Regular interval for fetching bookings
  static const int proximityCheckInterval =
      5; // How often to check driver proximity to passengers
  static const int notificationCooldown =
      15; // Minimum time between similar notifications

  // Distance thresholds (in meters)
  static const double pickupProximityThreshold =
      50; // Distance to mark driver as "at pickup location"
  static const double pickupApproachThreshold =
      200; // Distance to mark driver as "approaching pickup"
  static const double dropoffProximityThreshold =
      50; // Distance to mark driver as "at dropoff location"
  static const double dropoffApproachThreshold =
      200; // Distance to mark driver as "approaching dropoff"
  static const double minPassengerAheadDistance =
      20; // Minimum distance passenger should be ahead of driver

  // Test mode values (much larger for testing purposes)
  static const bool isTestMode = true; // Set to false for production values
  static const double testPickupProximityThreshold = 5000;
  static const double testPickupApproachThreshold = 10000;
  static const double testDropoffProximityThreshold = 10000;
  static const double testDropoffApproachThreshold = 10000;

  // Getters that return either test or production values based on mode
  static double get activePickupProximityThreshold =>
      isTestMode ? testPickupProximityThreshold : pickupProximityThreshold;

  static double get activePickupApproachThreshold =>
      isTestMode ? testPickupApproachThreshold : pickupApproachThreshold;

  static double get activeDropoffProximityThreshold =>
      isTestMode ? testDropoffProximityThreshold : dropoffProximityThreshold;

  static double get activeDropoffApproachThreshold =>
      isTestMode ? testDropoffApproachThreshold : dropoffApproachThreshold;
}
