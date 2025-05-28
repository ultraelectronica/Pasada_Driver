import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:pasada_driver_side/Config/app_config.dart';
import 'booking_model.dart';
import 'location_service.dart';
import 'booking_constants.dart';

/// Service to filter bookings based on various criteria
class BookingFilterService {
  // Private constructor to prevent instantiation
  BookingFilterService._();

  /// Filters requested bookings to find valid ones where passenger is ahead by required distance
  static List<Booking> filterValidRequestedBookings({
    required List<Booking> bookings,
    required LatLng driverLocation,
    required LatLng destinationLocation,
    String requiredStatus = 'requested',
  }) {
    try {
      // Validate input parameters
      if (bookings.isEmpty) return [];
      if (!LocationService.isValidLocation(driverLocation) ||
          !LocationService.isValidLocation(destinationLocation)) {
        if (kDebugMode) {
          debugPrint('Invalid driver or destination location provided');
        }
        return [];
      }

      // Get only bookings with requested status and validate them
      final requestedBookings = bookings
          .where((booking) =>
              booking.rideStatus == requiredStatus && booking.isValid)
          .toList();

      if (requestedBookings.isEmpty) return [];

      final List<Booking> validBookings = [];

      if (kDebugMode) {
        debugPrint(
            'Driver location: ${driverLocation.latitude}, ${driverLocation.longitude}');
        debugPrint(
            'Destination: ${destinationLocation.latitude}, ${destinationLocation.longitude}');
      }

      for (final booking in requestedBookings) {
        if (kDebugMode) {
          debugPrint('===== ANALYZING BOOKING ${booking.id} =====');
          debugPrint(
              'Pickup: ${booking.pickupLocation.latitude}, ${booking.pickupLocation.longitude}');
          debugPrint(
              'Dropoff: ${booking.dropoffLocation.latitude}, ${booking.dropoffLocation.longitude}');
        }

        // Check if passenger is ahead of driver by required distance
        final isValid = LocationService.isPickupAheadOfDriver(
          pickupLocation: booking.pickupLocation,
          driverLocation: driverLocation,
          destinationLocation: destinationLocation,
          minRequiredDistance: AppConfig.minPassengerAheadDistance,
        );

        if (isValid) {
          // Calculate distance to driver
          final distanceToDriver = LocationService.calculateDistance(
            driverLocation,
            booking.pickupLocation,
          );

          if (kDebugMode) {
            debugPrint(
                'Booking ${booking.id} is VALID - Distance to driver: ${distanceToDriver.toStringAsFixed(2)}m');
          }

          // Add to valid bookings with distance calculated
          validBookings
              .add(booking.copyWith(distanceToDriver: distanceToDriver));
        } else {
          if (kDebugMode) {
            debugPrint(
                'Booking ${booking.id} is INVALID - Failed validation checks');
          }
        }
      }

      if (kDebugMode) {
        debugPrint(
            'Found ${validBookings.length} valid bookings (passengers ahead by >${AppConfig.minPassengerAheadDistance} m)');
      }

      return validBookings;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error in filterValidRequestedBookings: $e');
      }
      return [];
    }
  }

  /// Find the nearest booking from a list of bookings based on distance to driver
  static Booking? findNearestBooking(List<Booking> bookings) {
    try {
      if (bookings.isEmpty) return null;

      // Filter out bookings without distance data
      final bookingsWithDistance = bookings
          .where((booking) => booking.distanceToDriver != null)
          .toList();

      if (bookingsWithDistance.isEmpty) return null;

      // Sort by distance to driver (ascending)
      final sortedBookings = List<Booking>.from(bookingsWithDistance);
      sortedBookings.sort((a, b) {
        final aDistance = a.distanceToDriver ?? double.infinity;
        final bDistance = b.distanceToDriver ?? double.infinity;
        return aDistance.compareTo(bDistance);
      });

      return sortedBookings.first;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error in findNearestBooking: $e');
      }
      return null;
    }
  }

  /// Filter bookings by status
  static List<Booking> filterByStatus(List<Booking> bookings, String status) {
    try {
      return bookings
          .where((booking) => booking.rideStatus == status && booking.isValid)
          .toList();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error in filterByStatus: $e');
      }
      return [];
    }
  }

  /// Get active bookings (requested, accepted, ongoing)
  static List<Booking> getActiveBookings(List<Booking> bookings) {
    try {
      return bookings.where((booking) => booking.isActive).toList();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error in getActiveBookings: $e');
      }
      return [];
    }
  }

  /// Sort bookings by distance to driver
  static List<Booking> sortByDistance(List<Booking> bookings) {
    try {
      final sortedBookings = List<Booking>.from(bookings);
      sortedBookings.sort((a, b) {
        final aDistance = a.distanceToDriver ?? double.infinity;
        final bDistance = b.distanceToDriver ?? double.infinity;
        return aDistance.compareTo(bDistance);
      });
      return sortedBookings;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error in sortByDistance: $e');
      }
      return bookings; // Return original list if sorting fails
    }
  }

  /// Group bookings by status
  static Map<String, List<Booking>> groupByStatus(List<Booking> bookings) {
    try {
      final Map<String, List<Booking>> grouped = {};

      for (final booking in bookings) {
        if (!booking.isValid) continue;

        grouped.putIfAbsent(booking.rideStatus, () => []).add(booking);
      }

      return grouped;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error in groupByStatus: $e');
      }
      return {};
    }
  }
}
