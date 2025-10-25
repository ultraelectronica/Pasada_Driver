import 'package:pasada_driver_side/data/models/allowed_stop_model.dart';
import 'package:pasada_driver_side/data/repositories/allowed_stop_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';

/// Supabase implementation of AllowedStopRepository.
class SupabaseAllowedStopRepository implements AllowedStopRepository {
  final SupabaseClient _supabase = Supabase.instance.client;

  @override
  Future<List<AllowedStop>> fetchStopsByRoute(int officialRouteId) async {
    try {
      final response = await _supabase
          .from('allowed_stops')
          .select()
          .eq('officialroute_id', officialRouteId)
          .eq('is_active', true)
          .order('stop_order', ascending: true);

      return (response as List)
          .map((json) => AllowedStop.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('Error fetching stops by route: $e');
      return [];
    }
  }

  @override
  Future<List<AllowedStop>> fetchAllActiveStops() async {
    try {
      final response = await _supabase
          .from('allowed_stops')
          .select()
          .eq('is_active', true)
          .order('officialroute_id', ascending: true)
          .order('stop_order', ascending: true);

      return (response as List)
          .map((json) => AllowedStop.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('Error fetching all active stops: $e');
      return [];
    }
  }

  @override
  Future<AllowedStop?> fetchStopById(String allowedStopId) async {
    try {
      final response = await _supabase
          .from('allowed_stops')
          .select()
          .eq('allowedstop_id', allowedStopId)
          .single();

      return AllowedStop.fromJson(response);
    } catch (e) {
      debugPrint('Error fetching stop by ID: $e');
      return null;
    }
  }
}
