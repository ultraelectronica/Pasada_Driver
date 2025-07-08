import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:pasada_driver_side/data/repositories/booking_repository.dart';
import 'package:pasada_driver_side/data/repositories/supabase_booking_repository.dart';
import 'package:pasada_driver_side/domain/services/booking_filter_service.dart';
import 'package:pasada_driver_side/common/geo/location_service.dart';
import 'package:pasada_driver_side/common/constants/booking_constants.dart';
import 'package:pasada_driver_side/data/models/booking_model.dart';

/// Stateless (but holds repository) processor that turns raw active bookings
/// into the prioritised list the UI needs.
class BookingProcessor {
  BookingProcessor({BookingRepository? repository})
      : _repository = repository ?? SupabaseBookingRepository();

  final BookingRepository _repository;

  /// Main entry-point: given the driver's [activeBookings] and contextual
  /// location data, produce a prioritised list (pick-ups first, then drop-offs)
  /// with distance pre-computed.
  Future<List<Booking>> process({
    required List<Booking> activeBookings,
    required LatLng driverLocation,
    required LatLng endingLocation,
    required String driverId,
  }) async {
    // 1. Split by status --------------------------------------------------
    final Map<String, List<Booking>> byStatus =
        _categorizeByStatus(activeBookings);
    final List<Booking> requested = byStatus['requested']!;

    if (kDebugMode) {
      final totalAcceptedOngoing = byStatus['acceptedOngoing']!.length;
      debugPrint(
          'BOOKINGS (before validation) -> Requested: ${requested.length}, Accepted/Ongoing: $totalAcceptedOngoing');
    }

    // 2. Validate requested bookings --------------------------------------
    final List<Booking> validRequested =
        BookingFilterService.filterValidRequestedBookings(
      bookings: requested,
      driverLocation: driverLocation,
      destinationLocation: endingLocation,
    );

    // 3. Update DB statuses for requested bookings ------------------------
    if (requested.isNotEmpty) {
      await _updateStatuses(requested, validRequested);
    }

    // 4. Re-query DB so we include newly accepted bookings ----------------
    final List<Booking> refreshed =
        await _repository.fetchActiveBookings(driverId);

    // 5. Calculate distances and prioritise -------------------------------
    return _prioritise(refreshed, driverLocation);
  }

  // ───────────────────────── helpers ─────────────────────────

  Map<String, List<Booking>> _categorizeByStatus(List<Booking> bookings) {
    final List<Booking> requested = bookings
        .where((b) => b.rideStatus == BookingConstants.statusRequested)
        .toList();
    final List<Booking> acceptedOngoing = bookings
        .where((b) =>
            b.rideStatus == BookingConstants.statusAccepted ||
            b.rideStatus == BookingConstants.statusOngoing)
        .toList();
    return {
      'requested': requested,
      'acceptedOngoing': acceptedOngoing,
    };
  }

  Future<void> _updateStatuses(
      List<Booking> requested, List<Booking> validRequested) async {
    final List<Future<void>> updates = [];
    for (final booking in requested) {
      final bool isValid = validRequested.any((v) => v.id == booking.id);
      try {
        final Future<bool> fut = _repository.updateBookingStatus(
          booking.id,
          isValid
              ? BookingConstants.statusAccepted
              : BookingConstants.statusCancelled,
        );
        updates.add(fut.then((_) => null));
      } catch (_) {
        // swallow; other updates should proceed
      }
    }
    await Future.wait(updates);
  }

  List<Booking> _prioritise(List<Booking> bookings, LatLng driverLocation) {
    final List<Booking> pickups = [];
    final List<Booking> dropoffs = [];

    for (final booking in bookings) {
      double distance;
      if (booking.rideStatus == BookingConstants.statusAccepted) {
        distance = LocationService.calculateDistance(
            driverLocation, booking.pickupLocation);
        pickups.add(booking.copyWith(distanceToDriver: distance));
      } else if (booking.rideStatus == BookingConstants.statusOngoing) {
        distance = LocationService.calculateDistance(
            driverLocation, booking.dropoffLocation);
        dropoffs.add(booking.copyWith(distanceToDriver: distance));
      }
    }

    pickups.sort((a, b) => (a.distanceToDriver ?? double.infinity)
        .compareTo(b.distanceToDriver ?? double.infinity));
    dropoffs.sort((a, b) => (a.distanceToDriver ?? double.infinity)
        .compareTo(b.distanceToDriver ?? double.infinity));

    return [...pickups, ...dropoffs];
  }
}
