import 'package:flutter/foundation.dart';
import 'package:pasada_driver_side/Services/encryption_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Service to resolve and cache passenger display names from the `passenger` table.
class PassengerNameService {
  PassengerNameService._internal();
  static final PassengerNameService instance = PassengerNameService._internal();

  final SupabaseClient _supabase = Supabase.instance.client;
  final Map<String, String?> _cache = {};

  /// Returns the decrypted display name for a given passengerId, or null if unavailable.
  Future<String?> getDisplayNameForPassengerId(String passengerId) async {
    if (passengerId.isEmpty) return null;

    if (_cache.containsKey(passengerId)) {
      return _cache[passengerId];
    }

    try {
      final response = await _supabase
          .from('passenger')
          .select('display_name')
          .eq('id', passengerId)
          .maybeSingle();

      if (response == null) {
        _cache[passengerId] = null;
        return null;
      }

      final String? encryptedName = response['display_name'] as String?;
      if (encryptedName == null || encryptedName.isEmpty) {
        _cache[passengerId] = null;
        return null;
      }

      final encryption = EncryptionService();
      final decrypted = await encryption.decryptUserData(encryptedName);
      _cache[passengerId] = decrypted;
      return decrypted;
    } catch (e) {
      if (kDebugMode) {
        debugPrint(
            '[PassengerNameService] Failed to fetch/decrypt name for passengerId=$passengerId: $e');
      }
      _cache[passengerId] = null;
      return null;
    }
  }
}
