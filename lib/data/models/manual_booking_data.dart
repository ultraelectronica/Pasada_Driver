import 'package:pasada_driver_side/data/models/allowed_stop_model.dart';

/// Data model for manually added passengers from the bottom sheet
class ManualBookingData {
  // Passenger counts by discount type
  final int regularCount;
  final int studentCount;
  final int seniorCount;
  final int pwdCount;

  // Location information
  final AllowedStop pickupStop;
  final AllowedStop destinationStop;

  // Seat type ('Standing' or 'Sitting')
  final String seatType;

  // Calculated fare
  final double totalFare;

  // Timestamp
  final DateTime createdAt;

  ManualBookingData({
    required this.regularCount,
    required this.studentCount,
    required this.seniorCount,
    required this.pwdCount,
    required this.pickupStop,
    required this.destinationStop,
    required this.seatType,
    required this.totalFare,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  /// Total number of passengers
  int get totalPassengers =>
      regularCount + studentCount + seniorCount + pwdCount;

  /// Check if there are any discount passengers
  bool get hasDiscountPassengers =>
      studentCount > 0 || seniorCount > 0 || pwdCount > 0;

  /// Get breakdown of passenger types
  Map<String, int> get passengerBreakdown => {
        'regular': regularCount,
        'student': studentCount,
        'senior': seniorCount,
        'pwd': pwdCount,
      };

  /// Convert to JSON for database storage
  Map<String, dynamic> toJson() {
    return {
      'regular_count': regularCount,
      'student_count': studentCount,
      'senior_count': seniorCount,
      'pwd_count': pwdCount,
      'pickup_stop_id': pickupStop.allowedStopId,
      'pickup_stop_name': pickupStop.stopName,
      'pickup_lat': pickupStop.stopLat,
      'pickup_lng': pickupStop.stopLng,
      'destination_stop_id': destinationStop.allowedStopId,
      'destination_stop_name': destinationStop.stopName,
      'destination_lat': destinationStop.stopLat,
      'destination_lng': destinationStop.stopLng,
      'seat_type': seatType,
      'total_fare': totalFare,
      'total_passengers': totalPassengers,
      'created_at': createdAt.toIso8601String(),
    };
  }

  /// Create a readable summary string
  String toSummaryString() {
    final passengers = <String>[];
    if (regularCount > 0) passengers.add('$regularCount Regular');
    if (studentCount > 0) passengers.add('$studentCount Student');
    if (seniorCount > 0) passengers.add('$seniorCount Senior');
    if (pwdCount > 0) passengers.add('$pwdCount PWD');

    return '''
Manual Booking Summary:
- Passengers: ${passengers.join(', ')} (Total: $totalPassengers)
- Seat Type: $seatType
- Pickup: ${pickupStop.stopName}
- Destination: ${destinationStop.stopName}
- Fare: ₱${totalFare.toStringAsFixed(2)}
- Created: ${createdAt.toString()}
''';
  }

  @override
  String toString() => toSummaryString();
}
