import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:pasada_driver_side/common/constants/booking_constants.dart';

/// Model representing a booking with all necessary details
class Booking {
  final String id;
  final String? passengerId; // Nullable for manual bookings
  final String rideStatus;
  final String? pickupAddress;
  final LatLng pickupLocation;
  final String? dropoffAddress;
  final LatLng dropoffLocation;
  final String seatType;
  final String? passengerIdImagePath;
  final bool? isIdAccepted;
  final String? passengerType; // e.g. Regular, Student, Senior Citizen, PWD

  // Optional calculated fields
  final double? distanceToDriver;

  const Booking({
    required this.id,
    this.passengerId, // Nullable for manual bookings
    required this.rideStatus,
    this.pickupAddress,
    required this.pickupLocation,
    this.dropoffAddress,
    required this.dropoffLocation,
    required this.seatType,
    this.passengerIdImagePath,
    this.isIdAccepted,
    this.passengerType,
    this.distanceToDriver,
  });

  /// Create a Booking from JSON with validation
  factory Booking.fromJson(Map<String, dynamic> json) {
    // Validate required fields
    final bookingId = json[BookingConstants.fieldBookingId];
    final passengerId = json[BookingConstants.fieldPassengerId];
    final rideStatus = json[BookingConstants.fieldRideStatus];
    final pickupAddress = json[BookingConstants.fieldPickupAddress] as String?;
    final pickupLat = json[BookingConstants.fieldPickupLat];
    final pickupLng = json[BookingConstants.fieldPickupLng];
    final dropoffAddress =
        json[BookingConstants.fieldDropoffAddress] as String?;
    final dropoffLat = json[BookingConstants.fieldDropoffLat];
    final dropoffLng = json[BookingConstants.fieldDropoffLng];

    if (bookingId == null) {
      throw ArgumentError(
          'Missing required field: ${BookingConstants.fieldBookingId}');
    }
    // Note: passengerId can be null for manual bookings
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

    // Debug: Log the passengerIdImagePath value
    final imagePath =
        json[BookingConstants.fieldPassengerIdImagePath] as String?;
    if (kDebugMode) {
      debugPrint('Booking $bookingId: passengerIdImagePath = $imagePath');
    }
    final bool? isIdAccepted =
        json.containsKey(BookingConstants.fieldIsIdAccepted)
            ? (json[BookingConstants.fieldIsIdAccepted] as bool?)
            : null;

    final String? passengerType =
        json[BookingConstants.fieldPassengerType] as String?;

    return Booking(
      id: bookingId.toString(),
      passengerId: passengerId?.toString(), // Nullable for manual bookings
      rideStatus: rideStatus as String,
      pickupAddress: pickupAddress,
      pickupLocation: LatLng(
        (pickupLat as num).toDouble(),
        (pickupLng as num).toDouble(),
      ),
      dropoffAddress: dropoffAddress,
      dropoffLocation: LatLng(
        (dropoffLat as num).toDouble(),
        (dropoffLng as num).toDouble(),
      ),
      seatType: json[BookingConstants.fieldSeatType] as String? ??
          BookingConstants.defaultSeatType,
      passengerIdImagePath: imagePath,
      isIdAccepted: isIdAccepted,
      passengerType: passengerType,
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      BookingConstants.fieldBookingId: id,
      BookingConstants.fieldPassengerId: passengerId,
      BookingConstants.fieldRideStatus: rideStatus,
      BookingConstants.fieldPickupAddress: pickupAddress,
      BookingConstants.fieldPickupLat: pickupLocation.latitude,
      BookingConstants.fieldPickupLng: pickupLocation.longitude,
      BookingConstants.fieldDropoffAddress: dropoffAddress,
      BookingConstants.fieldDropoffLat: dropoffLocation.latitude,
      BookingConstants.fieldDropoffLng: dropoffLocation.longitude,
      BookingConstants.fieldSeatType: seatType,
      BookingConstants.fieldPassengerIdImagePath: passengerIdImagePath,
      BookingConstants.fieldIsIdAccepted: isIdAccepted,
      BookingConstants.fieldPassengerType: passengerType,
    };
  }

  /// Create a copy with some fields updated
  Booking copyWith({
    String? id,
    String? passengerId,
    String? rideStatus,
    String? pickupAddress,
    LatLng? pickupLocation,
    String? dropoffAddress,
    LatLng? dropoffLocation,
    String? seatType,
    String? passengerIdImagePath,
    bool? isIdAccepted,
    String? passengerType,
    double? distanceToDriver,
  }) {
    return Booking(
      id: id ?? this.id,
      passengerId: passengerId ?? this.passengerId,
      rideStatus: rideStatus ?? this.rideStatus,
      pickupAddress: pickupAddress ?? this.pickupAddress,
      pickupLocation: pickupLocation ?? this.pickupLocation,
      dropoffAddress: dropoffAddress ?? this.dropoffAddress,
      dropoffLocation: dropoffLocation ?? this.dropoffLocation,
      seatType: seatType ?? this.seatType,
      passengerIdImagePath: passengerIdImagePath ?? this.passengerIdImagePath,
      isIdAccepted: isIdAccepted ?? this.isIdAccepted,
      passengerType: passengerType ?? this.passengerType,
      distanceToDriver: distanceToDriver ?? this.distanceToDriver,
    );
  }

  /// Check if booking is in a valid state
  bool get isValid {
    return id.isNotEmpty &&
        rideStatus.isNotEmpty &&
        _isValidStatus(rideStatus) &&
        _isValidLocation(pickupLocation) &&
        _isValidLocation(dropoffLocation);
  }

  /// Check if this is a manual booking (no passenger account)
  bool get isManualBooking => passengerId == null || passengerId!.isEmpty;

  /// Normalized discount type label: Student / Senior / PWD, or null if none/regular.
  String? get discountLabel {
    final type = passengerType;
    if (type == null || type.isEmpty) return null;
    final normalized = type.toLowerCase();
    if (normalized.contains('student')) return 'Student';
    if (normalized.contains('senior')) return 'Senior';
    if (normalized == 'pwd' || normalized.contains('pwd')) return 'PWD';
    return null;
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
        'pickup: $pickupAddress (${pickupLocation.latitude}, ${pickupLocation.longitude}), '
        'dropoff: $dropoffAddress (${dropoffLocation.latitude}, ${dropoffLocation.longitude}), '
        'seatType: $seatType, passengerIdImagePath: $passengerIdImagePath, '
        'isIdAccepted: $isIdAccepted, passengerType: $passengerType, distance: $distanceToDriver)';
  }

  @override
  bool operator ==(Object other) {
    return other is Booking && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
