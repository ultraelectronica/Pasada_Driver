/// Configuration class to centralize app timing and threshold settings
class AppConfig {
  // Debounce times (in seconds)
  static const int fetchDebounceTime =
      5; // Minimum time between booking fetches
  static const int periodicFetchInterval =
      20; // Regular interval for fetching bookings
  static const int proximityCheckInterval =
      4; // How often to check driver proximity to passengers
  static const int notificationCooldown =
      15; // Minimum time between similar notifications

  // Timeouts (in seconds)
  static const int databaseOperationTimeout = 10; // Timeout for DB operations
  static const int locationFetchTimeout = 10; // Timeout for location fetching

  // Distance thresholds (in meters)
  // PICKUP
  static const double pickupProximityThreshold =
      200; // Distance to mark driver as "at pickup location"
  static const double pickupApproachThreshold =
      250; // Distance to mark driver as "approaching pickup"

  // DROP OFF
  static const double dropoffProximityThreshold =
      200; // Distance to mark driver as "at dropoff location"
  static const double dropoffApproachThreshold =
      250; // Distance to mark driver as "approaching dropoff"

  // DISTANCE BETWEEN PASSENGER AND DRIVER
  static const double minPassengerAheadDistance =
      100; // Minimum distance passenger should be ahead of driver
  static const double maxPickupDistanceThreshold =
      3000; // Maximum distance for valid pickup
  static const double maxDistanceSecondaryCheck =
      5000; // Maximum distance for secondary validation check

  // BEARING AND DIRECTION THRESHOLDS (in degrees)
  static const double bearingAngleThreshold =
      60.0; // Angle threshold for "ahead" calculation
  static const double behindDriverMinBearing =
      270.0; // Minimum bearing considered "behind" driver
  static const double behindDriverMaxBearing =
      360.0; // Maximum bearing considered "behind" driver

  // TEST MODE VALUES
  static const bool isTestMode = true; // Set to false for production values
  static const double testPickupProximityThreshold = 10000;
  static const double testPickupApproachThreshold = 10000;
  static const double testDropoffProximityThreshold = 10000;
  static const double testDropoffApproachThreshold = 10000;

  // Getters that return either test or production values based on mode

  /// "At pickup" location proximity threshold
  static double get activePickupProximityThreshold =>
      isTestMode ? testPickupProximityThreshold : pickupProximityThreshold;

  /// "Approaching pickup" location proximity threshold
  static double get activePickupApproachThreshold =>
      isTestMode ? testPickupApproachThreshold : pickupApproachThreshold;

  /// "At dropoff" location proximity threshold
  static double get activeDropoffProximityThreshold =>
      isTestMode ? testDropoffProximityThreshold : dropoffProximityThreshold;

  /// "Approaching dropoff" location proximity threshold
  static double get activeDropoffApproachThreshold =>
      isTestMode ? testDropoffApproachThreshold : dropoffApproachThreshold;
}
