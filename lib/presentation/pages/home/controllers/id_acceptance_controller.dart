import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class IdAcceptanceController {
  IdAcceptanceController();

  final SupabaseClient supabase = Supabase.instance.client;

  Future<void> acceptID(String id) async {
    try {
      final response = await supabase.from('bookings').update({
        'is_id_accepted': true,
      }).eq('booking_id', id);

      debugPrint('ID acceptance response: $response');
    } catch (e) {
      debugPrint('Error accepting ID: $e');
      rethrow;
    }
  }

  Future<void> declineID(String id) async {
    try {
      final response = await supabase.from('bookings').update({
        'is_id_accepted': false,
      }).eq('booking_id', id);

      debugPrint('ID decline response: $response');
    } catch (e) {
      debugPrint('Error declining ID: $e');
      rethrow;
    }
  }
}
