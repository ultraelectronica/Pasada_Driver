import 'package:pasada_driver_side/data/models/manual_booking_data.dart';
import 'package:pasada_driver_side/data/repositories/manual_booking_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:pasada_driver_side/common/utils/booking_id_generator.dart';
import 'package:pasada_driver_side/domain/services/fare_recalculation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:pasada_driver_side/common/geo/location_service.dart';

/// Supabase implementation for creating manual bookings
class SupabaseManualBookingRepository implements ManualBookingRepository {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Generate a unique booking ID that doesn't exist in the database
  /// Retries up to 5 times if there's a collision (extremely rare)
  Future<int> _generateUniqueBookingId() async {
    const maxRetries = 5;

    for (int attempt = 0; attempt < maxRetries; attempt++) {
      final bookingId = BookingIdGenerator.generateBookingIdAsInt();

      try {
        // Check if this ID already exists
        final existing = await _supabase
            .from('bookings')
            .select('booking_id')
            .eq('booking_id', bookingId)
            .maybeSingle();

        if (existing == null) {
          // ID is unique, return it
          return bookingId;
        }

        debugPrint(
            'Booking ID collision detected: $bookingId, retrying... (attempt ${attempt + 1})');
      } catch (e) {
        debugPrint('Error checking booking ID uniqueness: $e');
        // On error, return the generated ID anyway
        return bookingId;
      }
    }

    // After max retries, just return a generated ID
    debugPrint(
        'Max retries reached for booking ID generation, using last generated ID');
    return BookingIdGenerator.generateBookingIdAsInt();
  }

  @override
  Future<int> createManualBookings({
    required ManualBookingData bookingData,
    required String driverId,
    required int routeId,
  }) async {
    int successCount = 0;

    try {
      // Create booking records for each passenger type
      final bookingsToInsert = <Map<String, dynamic>>[];

      // Add regular passengers
      for (int i = 0; i < bookingData.regularCount; i++) {
        final record = await _createBookingRecord(
          driverId: driverId,
          routeId: routeId,
          bookingData: bookingData,
          passengerType: 'Regular',
          farePerPassenger: _calculateFarePerType('regular', bookingData),
        );
        bookingsToInsert.add(record);
      }

      // Add student passengers
      for (int i = 0; i < bookingData.studentCount; i++) {
        final record = await _createBookingRecord(
          driverId: driverId,
          routeId: routeId,
          bookingData: bookingData,
          passengerType: 'Student',
          farePerPassenger: _calculateFarePerType('student', bookingData),
        );
        bookingsToInsert.add(record);
      }

      // Add senior passengers
      for (int i = 0; i < bookingData.seniorCount; i++) {
        final record = await _createBookingRecord(
          driverId: driverId,
          routeId: routeId,
          bookingData: bookingData,
          passengerType: 'Senior Citizen',
          farePerPassenger:
              _calculateFarePerType('senior citizen', bookingData),
        );
        bookingsToInsert.add(record);
      }

      // Add PWD passengers
      for (int i = 0; i < bookingData.pwdCount; i++) {
        final record = await _createBookingRecord(
          driverId: driverId,
          routeId: routeId,
          bookingData: bookingData,
          passengerType: 'PWD',
          farePerPassenger: _calculateFarePerType('pwd', bookingData),
        );
        bookingsToInsert.add(record);
      }

      debugPrint(
          'Creating ${bookingsToInsert.length} manual booking records...');

      // Insert all bookings in a single batch
      if (bookingsToInsert.isNotEmpty) {
        final response =
            await _supabase.from('bookings').insert(bookingsToInsert).select();

        successCount = (response as List).length;
        debugPrint('Successfully created $successCount booking records');
      }

      return successCount;
    } catch (e) {
      debugPrint('Error creating manual bookings: $e');
      return successCount;
    }
  }

  /// Create a single booking record
  Future<Map<String, dynamic>> _createBookingRecord({
    required String driverId,
    required int routeId,
    required ManualBookingData bookingData,
    required String passengerType,
    required double farePerPassenger,
  }) async {
    final now = DateTime.now();

    // Generate unique booking ID in format: 10000XXXXXX
    final bookingId = await _generateUniqueBookingId();

    debugPrint('Generated booking ID: $bookingId for $passengerType passenger');

    return {
      'booking_id': bookingId,
      'driver_id': driverId,
      'route_id': routeId,
      'ride_status': 'ongoing', // Manual bookings are immediately ongoing
      'pickup_address': bookingData.pickupStop.stopAddress,
      'pickup_lat': bookingData.pickupStop.stopLat,
      'pickup_lng': bookingData.pickupStop.stopLng,
      'dropoff_address': bookingData.destinationStop.stopAddress,
      'dropoff_lat': bookingData.destinationStop.stopLat,
      'dropoff_lng': bookingData.destinationStop.stopLng,
      'start_time':
          '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}',
      'fare':
          farePerPassenger.toInt(), // Store as integer without decimal point
      'passenger_id':
          null, // Manual booking - no passenger account (NULL is valid for manual bookings)
      'seat_type': bookingData.seatType, // Standing or Sitting
      'payment_method': 'Cash', // Default for manual bookings
      'passenger_type': passengerType,
      'payment_status': 'pending', // Or 'paid' if cash collected immediately
      'is_id_accepted': null, // Not applicable for manual bookings
      'passenger_id_image_path': null,
      'assigned_at': now.toIso8601String(),
      'created_at': now.toIso8601String(),
    };
  }

  /// Calculate fare per passenger based on type and distance
  /// Uses FareService for distance-based calculation with proper discounts
  double _calculateFarePerType(
      String passengerType, ManualBookingData bookingData) {
    try {
      // Calculate distance between pickup and destination
      final pickupLatLng = LatLng(
        bookingData.pickupStop.stopLat,
        bookingData.pickupStop.stopLng,
      );
      final destinationLatLng = LatLng(
        bookingData.destinationStop.stopLat,
        bookingData.destinationStop.stopLng,
      );

      final distanceInMeters =
          LocationService.calculateDistance(pickupLatLng, destinationLatLng);

      // Convert to kilometers
      final distanceInKm =
          distanceInMeters.isFinite ? distanceInMeters / 1000.0 : 0.0;

      // Calculate base fare using FareService and round it
      final baseFare =
          FareService.calculateFare(distanceInKm).round().toDouble();

      // Apply discount for eligible passenger types
      switch (passengerType.toLowerCase()) {
        case 'regular':
          return baseFare; // No discount
        case 'student':
        case 'senior citizen':
        case 'pwd':
          // Apply 20% discount and round the result
          return FareService.applyDiscount(baseFare).round().toDouble();
        default:
          return baseFare;
      }
    } catch (e) {
      debugPrint('Error calculating fare per type: $e');
      // Fallback to base fare if calculation fails
      return FareService.baseFare;
    }
  }
}
