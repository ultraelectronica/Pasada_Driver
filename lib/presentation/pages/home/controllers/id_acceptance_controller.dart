import 'package:flutter/material.dart';
import 'package:pasada_driver_side/data/repositories/booking_repository.dart';
import 'package:pasada_driver_side/data/repositories/supabase_booking_repository.dart';

class IdAcceptanceController {
  IdAcceptanceController({BookingRepository? repository})
      : _repository = repository ?? SupabaseBookingRepository();

  final BookingRepository _repository;

  Future<void> acceptID(String id) async {
    try {
      debugPrint('[ID_ACCEPT] Attempting to accept ID for booking: $id');
      final bool isIDAccepted = await _repository.updateIdAccepted(id, true);
      debugPrint('[ID_ACCEPT] Repository update result: $isIDAccepted');
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
