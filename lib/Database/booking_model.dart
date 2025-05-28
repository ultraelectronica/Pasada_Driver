import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'booking_constants.dart';

// ==================== MODELS ====================

/// Model representing a booking with all necessary details
class Booking {
  final String id;
  final String passengerId;
  final String rideStatus;
  final LatLng pickupLocation;
  final LatLng dropoffLocation;
  final String seatType;

  // Optional calculated fields
  final double? distanceToDriver;

  const Booking({
    required this.id,
    required this.passengerId,
    required this.rideStatus,
    required this.pickupLocation,
    required this.dropoffLocation,
    required this.seatType,
    this.distanceToDriver,
  });

  /// Create a Booking from JSON with validation
  factory Booking.fromJson(Map<String, dynamic> json) {
    // Validate required fields
    final bookingId = json[BookingConstants.fieldBookingId];
    final passengerId = json[BookingConstants.fieldPassengerId];
    final rideStatus = json[BookingConstants.fieldRideStatus];
    final pickupLat = json[BookingConstants.fieldPickupLat];
    final pickupLng = json[BookingConstants.fieldPickupLng];
    final dropoffLat = json[BookingConstants.fieldDropoffLat];
    final dropoffLng = json[BookingConstants.fieldDropoffLng];

    if (bookingId == null) {
      throw ArgumentError(
          'Missing required field: ${BookingConstants.fieldBookingId}');
    }
    if (passengerId == null) {
      throw ArgumentError(
          'Missing required field: ${BookingConstants.fieldPassengerId}');
    }
    if (rideStatus == null) {
      throw ArgumentError(
          'Missing required field: ${BookingConstants.fieldRideStatus}');
    }
    if (pickupLat == null || pickupLng == null) {
      throw ArgumentError('Missing required pickup location fields');
    }
    if (dropoffLat == null || dropoffLng == null) {
      throw ArgumentError('Missing required dropoff location fields');
    }

    return Booking(
      id: bookingId.toString(),
      passengerId: passengerId.toString(),
      rideStatus: rideStatus as String,
      pickupLocation: LatLng(
        (pickupLat as num).toDouble(),
        (pickupLng as num).toDouble(),
      ),
      dropoffLocation: LatLng(
        (dropoffLat as num).toDouble(),
        (dropoffLng as num).toDouble(),
      ),
      seatType: json[BookingConstants.fieldSeatType] as String? ??
          BookingConstants.defaultSeatType,
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      BookingConstants.fieldBookingId: id,
      BookingConstants.fieldPassengerId: passengerId,
      BookingConstants.fieldRideStatus: rideStatus,
      BookingConstants.fieldPickupLat: pickupLocation.latitude,
      BookingConstants.fieldPickupLng: pickupLocation.longitude,
      BookingConstants.fieldDropoffLat: dropoffLocation.latitude,
      BookingConstants.fieldDropoffLng: dropoffLocation.longitude,
      BookingConstants.fieldSeatType: seatType,
    };
  }

  /// Create a copy with some fields updated
  Booking copyWith({
    String? id,
    String? passengerId,
    String? rideStatus,
    LatLng? pickupLocation,
    LatLng? dropoffLocation,
    String? seatType,
    double? distanceToDriver,
  }) {
    return Booking(
      id: id ?? this.id,
      passengerId: passengerId ?? this.passengerId,
      rideStatus: rideStatus ?? this.rideStatus,
      pickupLocation: pickupLocation ?? this.pickupLocation,
      dropoffLocation: dropoffLocation ?? this.dropoffLocation,
      seatType: seatType ?? this.seatType,
      distanceToDriver: distanceToDriver ?? this.distanceToDriver,
    );
  }

  /// Check if booking is in a valid state
  bool get isValid {
    return id.isNotEmpty &&
        passengerId.isNotEmpty &&
        rideStatus.isNotEmpty &&
        _isValidStatus(rideStatus) &&
        _isValidLocation(pickupLocation) &&
        _isValidLocation(dropoffLocation);
  }

  /// Check if ride status is valid
  bool _isValidStatus(String status) {
    return [
      BookingConstants.statusRequested,
      BookingConstants.statusAccepted,
      BookingConstants.statusOngoing,
      BookingConstants.statusCompleted,
      BookingConstants.statusCancelled,
    ].contains(status);
  }

  /// Check if location coordinates are valid
  bool _isValidLocation(LatLng location) {
    return location.latitude >= -90 &&
        location.latitude <= 90 &&
        location.longitude >= -180 &&
        location.longitude <= 180;
  }

  /// Check if booking is active (not completed or cancelled)
  bool get isActive {
    return rideStatus == BookingConstants.statusRequested ||
        rideStatus == BookingConstants.statusAccepted ||
        rideStatus == BookingConstants.statusOngoing;
  }

  /// Check if booking is completed
  bool get isCompleted => rideStatus == BookingConstants.statusCompleted;

  /// Check if booking is cancelled
  bool get isCancelled => rideStatus == BookingConstants.statusCancelled;

  @override
  String toString() {
    return 'Booking(id: $id, passengerId: $passengerId, status: $rideStatus, '
        'pickup: (${pickupLocation.latitude}, ${pickupLocation.longitude}), '
        'dropoff: (${dropoffLocation.latitude}, ${dropoffLocation.longitude}), '
        'seatType: $seatType, distance: $distanceToDriver)';
  }

  @override
  bool operator ==(Object other) {
    return other is Booking && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
