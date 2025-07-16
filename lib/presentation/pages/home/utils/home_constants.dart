/// Constants specific to the Home (driver map) module.
class HomeConstants {
  const HomeConstants._();

  /// Maximum passengers shown in the top-nearest list.
  static const int maxNearbyPassengers = 3;

  /// Cool-down between proximity notifications (seconds).
  static const int proximityNotificationCooldownSeconds = 15;

  // UI layout fractions
  static const double actionButtonBottomFraction = 0.025;
  static const double actionButtonHorizontalInsetFraction = 0.2;

  static const double resetButtonBottomFraction = 0.33;
  static const double sideButtonRightFraction = 0.05;

  static const double capacityTotalBottomFraction = 0.1;
  static const double capacityStandingBottomFraction = 0.175;
  static const double capacitySittingBottomFraction = 0.25;
}
