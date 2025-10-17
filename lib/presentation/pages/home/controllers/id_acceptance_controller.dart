import 'package:flutter/material.dart';
import 'package:pasada_driver_side/data/repositories/booking_repository.dart';
import 'package:pasada_driver_side/data/repositories/supabase_booking_repository.dart';
import 'package:pasada_driver_side/domain/services/fare_recalculation.dart';

class IdAcceptanceController {
  IdAcceptanceController({BookingRepository? repository})
      : _repository = repository ?? SupabaseBookingRepository();

  final BookingRepository _repository;

  Future<void> acceptID(String id) async {
    try {
      debugPrint('[ID_ACCEPT] Attempting to accept ID for booking: $id');
      final bool isIDAccepted = await _repository.updateIdAccepted(id, true);
      debugPrint('[ID_ACCEPT] Repository update result: $isIDAccepted');

      if (isIDAccepted) {
        // Recalculate fare with discount and persist
        final int? currentFare = await _repository.fetchFare(id);
        if (currentFare != null) {
          final double discounted =
              FareService.applyDiscount(currentFare.toDouble());
          final int newFare = discounted.round();
          final bool fareOk = await _repository.updateFare(id, newFare);
          debugPrint(
              '[ID_ACCEPT] Fare recalculated from $currentFare -> $newFare, updated=$fareOk');
        } else {
          debugPrint(
              '[ID_ACCEPT] No current fare found to recalculate. Skipping.');
        }
      }
    } catch (e, st) {
      debugPrint('[ID_ACCEPT][ERROR] $e');
      debugPrint(st.toString());
      rethrow;
    }
  }

  Future<void> declineID(String id) async {
    try {
      debugPrint('[ID_DECLINE] Attempting to decline ID for booking: $id');
      final bool ok = await _repository.updateIdAccepted(id, false);
      debugPrint('[ID_DECLINE] Repository update result: $ok');
    } catch (e, st) {
      debugPrint('[ID_DECLINE][ERROR] $e');
      debugPrint(st.toString());
      rethrow;
    }
  }
}
