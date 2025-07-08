import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:pasada_driver_side/common/config/app_config.dart';
import 'package:pasada_driver_side/data/models/booking_model.dart';
import 'package:pasada_driver_side/common/geo/location_service.dart';

/// Service to filter bookings based on various criteria
class BookingFilterService {
  BookingFilterService._();

  static List<Booking> filterValidRequestedBookings({
    required List<Booking> bookings,
    required LatLng driverLocation,
    required LatLng destinationLocation,
    String requiredStatus = 'requested',
  }) {
    try {
      if (bookings.isEmpty) return [];
      if (!LocationService.isValidLocation(driverLocation) ||
          !LocationService.isValidLocation(destinationLocation)){
            return [];
          }

      final requested = bookings
          .where((b) => b.rideStatus == requiredStatus && b.isValid)
          .toList();
      if (requested.isEmpty) return [];

      final List<Booking> valid = [];
      for (final b in requested) {
        final isValid = LocationService.isPickupAheadOfDriver(
          pickupLocation: b.pickupLocation,
          driverLocation: driverLocation,
          destinationLocation: destinationLocation,
          minRequiredDistance: AppConfig.minPassengerAheadDistance,
        );
        if (isValid) {
          final dist = LocationService.calculateDistance(
              driverLocation, b.pickupLocation);
          valid.add(b.copyWith(distanceToDriver: dist));
        }
      }
      return valid;
    } catch (_) {
      return [];
    }
  }

  static Booking? findNearestBooking(List<Booking> bookings) {
    final withDist = bookings.where((b) => b.distanceToDriver != null).toList();
    if (withDist.isEmpty) return null;
    withDist.sort((a, b) => (a.distanceToDriver ?? double.infinity)
        .compareTo(b.distanceToDriver ?? double.infinity));
    return withDist.first;
  }

  static List<Booking> filterByStatus(List<Booking> bookings, String status) =>
      bookings.where((b) => b.rideStatus == status && b.isValid).toList();

  static List<Booking> getActiveBookings(List<Booking> bookings) =>
      bookings.where((b) => b.isActive).toList();

  static List<Booking> sortByDistance(List<Booking> bookings) {
    final s = List<Booking>.from(bookings);
    s.sort((a, b) => (a.distanceToDriver ?? double.infinity)
        .compareTo(b.distanceToDriver ?? double.infinity));
    return s;
  }

  static Map<String, List<Booking>> groupByStatus(List<Booking> bookings) {
    final Map<String, List<Booking>> g = {};
    for (final b in bookings) {
      if (!b.isValid) continue;
      g.putIfAbsent(b.rideStatus, () => []).add(b);
    }
    return g;
  }
}
