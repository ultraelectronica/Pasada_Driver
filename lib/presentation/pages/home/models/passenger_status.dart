import 'package:pasada_driver_side/data/models/booking_model.dart';

/// Model to track passenger proximity and status information related to a booking.
class PassengerStatus {
  final Booking booking;
  final double distance;
  final bool isNearPickup;
  final bool isNearDropoff;
  final bool isApproachingPickup;
  final bool isApproachingDropoff;

  const PassengerStatus({
    required this.booking,
    required this.distance,
    this.isNearPickup = false,
    this.isNearDropoff = false,
    this.isApproachingPickup = false,
    this.isApproachingDropoff = false,
  });

  PassengerStatus copyWith({
    Booking? booking,
    double? distance,
    bool? isNearPickup,
    bool? isNearDropoff,
    bool? isApproachingPickup,
    bool? isApproachingDropoff,
  }) {
    return PassengerStatus(
      booking: booking ?? this.booking,
      distance: distance ?? this.distance,
      isNearPickup: isNearPickup ?? this.isNearPickup,
      isNearDropoff: isNearDropoff ?? this.isNearDropoff,
      isApproachingPickup: isApproachingPickup ?? this.isApproachingPickup,
      isApproachingDropoff: isApproachingDropoff ?? this.isApproachingDropoff,
    );
  }
}
