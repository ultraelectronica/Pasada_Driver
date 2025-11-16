// ignore_for_file: constant_identifier_names

/// Central configuration for vehicle passenger capacity limits.
///
/// This is used by both the capacity service and the manual booking
/// seat-assignment service to ensure they always stay in sync.
class CapacityConfig {
  static const int MAX_SITTING_CAPACITY = 28;
  static const int MAX_STANDING_CAPACITY = 5;
  static const int MAX_TOTAL_CAPACITY =
      MAX_SITTING_CAPACITY + MAX_STANDING_CAPACITY;
}
