import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
// import 'package:pasada_driver_side/UI/message.dart'; // Removed UI dependency
// import 'package:supabase_flutter/supabase_flutter.dart'; // Removed if supabase client is not used

// Renamed class to follow PascalCase convention
class AuthService {
  // Removed unused supabase client instance
  // final supabase = Supabase.instance.client;
  static const _storage = FlutterSecureStorage();

  // Define constants for storage keys
  static const String _keySessionToken = 'session_token';
  static const String _keyExpirationTime = 'expiration_time';
  static const String _keyDriverId = 'driver_id';
  static const String _keyRouteId = 'route_id';
  static const String _keyVehicleId = 'vehicle_id';

  // List of all keys managed by this service
  static const _allKeys = [
    _keySessionToken,
    _keyExpirationTime,
    _keyDriverId,
    _keyRouteId,
    _keyVehicleId
  ];

  static Future<void> saveCredentials({
    required String sessionToken,
    required String driverId,
    required String routeId,
    required String vehicleId,
    // Removed expiresAt parameter as expiration is generated internally
    // required String expiresAt
  }) async {
    // TODO: Review session duration (currently 1 minute)
    final expirationTime =
        DateTime.now().add(const Duration(minutes: 1)).toIso8601String();

    // Use await for all writes
    await _storage.write(key: _keySessionToken, value: sessionToken);
    await _storage.write(key: _keyExpirationTime, value: expirationTime);
    await _storage.write(key: _keyDriverId, value: driverId);
    await _storage.write(key: _keyRouteId, value: routeId);
    await _storage.write(key: _keyVehicleId, value: vehicleId);
    // Removed write for 'expires_at'
    // await _storage.write(key: 'expires_at', value: expiresAt);
  }

  static Future<Map<String, String?>> getSession() async {
    final sessionToken = await _storage.read(key: _keySessionToken);
    final expirationTimeString = await _storage.read(key: _keyExpirationTime);

    // Check if token exists and is not expired
    if (sessionToken == null || expirationTimeString == null) {
      return {}; // No valid session found
    }

    DateTime expirationTime;
    try {
      expirationTime = DateTime.parse(expirationTimeString);
    } catch (e) {
      // Handle parsing error, e.g., corrupted data
      if (kDebugMode) {
        print('Error parsing expiration time: $e');
      }
      await deleteSession(); // Clear corrupted session data
      return {};
    }

    if (expirationTime.isBefore(DateTime.now())) {
      // Token expired: Clear storage
      // ShowMessage().showToast('Session Expired'); // Removed UI call
      if (kDebugMode) {
        print('Session expired. Deleting stored credentials.');
      }
      await deleteSession();
      return {}; // Return empty map to indicate expired/no session
    }

    // Removed automatic printing of storage contents
    // AuthService.printStorageContents();

    // Return valid session data using key constants
    // Consider using readAll() if performance becomes an issue
    return {
      _keySessionToken: sessionToken,
      _keyDriverId: await _storage.read(key: _keyDriverId),
      _keyRouteId: await _storage.read(key: _keyRouteId),
      _keyVehicleId: await _storage.read(key: _keyVehicleId),
    };
  }

  static Future<void> deleteSession() async {
    // Use defined list of keys
    for (final key in _allKeys) {
      await _storage.delete(key: key);
    }
    if (kDebugMode) {
      // ShowMessage().showToast('Pasada local credentials has been removed.'); // Removed UI call
      print('Pasada local credentials have been removed.');
    }
  }

  // Optional: Keep for explicit debugging if needed
  static Future<void> printStorageContents() async {
    if (kDebugMode) {
      print('Secure Storage contents:');
      // Use defined list of keys
      for (final key in _allKeys) {
        final value = await _storage.read(key: key);
        print('  $key: $value');
      }
      // Optionally check for unexpected keys (though readAll might be better here)
    }
  }

  // Made static as it doesn't depend on instance state
  static String generateSecureToken() {
    final random = Random.secure();
    // Generate 32 bytes (256 bits) of random data
    final values = List<int>.generate(32, (i) => random.nextInt(256));
    // Encode as Base64 URL-safe string
    return base64Url.encode(values);
  }
}
