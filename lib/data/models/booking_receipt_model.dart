import 'package:pasada_driver_side/common/constants/booking_constants.dart';

/// Enhanced model for displaying booking receipts with all necessary details
class BookingReceipt {
  // Basic booking info
  final String bookingId;
  final String? passengerId;
  final String rideStatus;

  // Timestamps
  final DateTime? createdAt;
  final DateTime? assignedAt;
  final DateTime? completedAt;
  final String? startTime;

  // Location details
  final String? pickupAddress;
  final double pickupLat;
  final double pickupLng;
  final String? dropoffAddress;
  final double dropoffLat;
  final double dropoffLng;

  // Payment details
  final int? fare;
  final String? paymentMethod;
  final String? paymentStatus;
  final String seatType;
  final String? passengerType;

  // Route info
  final int? routeId;

  const BookingReceipt({
    required this.bookingId,
    this.passengerId,
    required this.rideStatus,
    this.createdAt,
    this.assignedAt,
    this.completedAt,
    this.startTime,
    this.pickupAddress,
    required this.pickupLat,
    required this.pickupLng,
    this.dropoffAddress,
    required this.dropoffLat,
    required this.dropoffLng,
    this.fare,
    this.paymentMethod,
    this.paymentStatus,
    required this.seatType,
    this.passengerType,
    this.routeId,
  });

  /// Create from JSON response
  factory BookingReceipt.fromJson(Map<String, dynamic> json) {
    return BookingReceipt(
      bookingId: json[BookingConstants.fieldBookingId]?.toString() ?? '',
      passengerId: json[BookingConstants.fieldPassengerId]?.toString(),
      rideStatus: json[BookingConstants.fieldRideStatus] as String? ??
          BookingConstants.statusCompleted,
      // Parse as UTC and keep as-is (database stores Philippines local time as UTC)
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String).toUtc()
          : null,
      assignedAt: json['assigned_at'] != null
          ? DateTime.parse(json['assigned_at'] as String).toUtc()
          : null,
      completedAt: json['completed_at'] != null
          ? DateTime.parse(json['completed_at'] as String).toUtc()
          : null,
      startTime: json['start_time'] as String?,
      pickupAddress: json['pickup_address'] as String?,
      pickupLat:
          (json[BookingConstants.fieldPickupLat] as num?)?.toDouble() ?? 0.0,
      pickupLng:
          (json[BookingConstants.fieldPickupLng] as num?)?.toDouble() ?? 0.0,
      dropoffAddress: json['dropoff_address'] as String?,
      dropoffLat:
          (json[BookingConstants.fieldDropoffLat] as num?)?.toDouble() ?? 0.0,
      dropoffLng:
          (json[BookingConstants.fieldDropoffLng] as num?)?.toDouble() ?? 0.0,
      fare: (json[BookingConstants.fieldFare] as num?)?.toInt(),
      paymentMethod: json['payment_method'] as String?,
      paymentStatus: json['payment_status'] as String?,
      seatType: json[BookingConstants.fieldSeatType] as String? ??
          BookingConstants.defaultSeatType,
      passengerType: json['passenger_type'] as String?,
      routeId: json['route_id'] as int?,
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      BookingConstants.fieldBookingId: bookingId,
      BookingConstants.fieldPassengerId: passengerId,
      BookingConstants.fieldRideStatus: rideStatus,
      'created_at': createdAt?.toIso8601String(),
      'assigned_at': assignedAt?.toIso8601String(),
      'completed_at': completedAt?.toIso8601String(),
      'start_time': startTime,
      'pickup_address': pickupAddress,
      BookingConstants.fieldPickupLat: pickupLat,
      BookingConstants.fieldPickupLng: pickupLng,
      'dropoff_address': dropoffAddress,
      BookingConstants.fieldDropoffLat: dropoffLat,
      BookingConstants.fieldDropoffLng: dropoffLng,
      BookingConstants.fieldFare: fare,
      'payment_method': paymentMethod,
      'payment_status': paymentStatus,
      BookingConstants.fieldSeatType: seatType,
      'passenger_type': passengerType,
      'route_id': routeId,
    };
  }

  /// Check if booking is completed
  bool get isCompleted => rideStatus == BookingConstants.statusCompleted;

  /// Check if this is a manual booking (no passenger account)
  bool get isManualBooking => passengerId == null || passengerId!.isEmpty;

  /// Get formatted route string (e.g., "Pickup → Destination")
  String get routeString {
    final pickup = pickupAddress ?? 'Unknown Pickup';
    final dropoff = dropoffAddress ?? 'Unknown Destination';
    return '$pickup → $dropoff';
  }

  /// Get formatted fare string with currency
  String get fareString {
    if (fare == null) return '₱0.00';
    return '₱${fare!.toStringAsFixed(2)}';
  }

  @override
  String toString() {
    return 'BookingReceipt(id: $bookingId, fare: $fare, status: $rideStatus)';
  }
}
