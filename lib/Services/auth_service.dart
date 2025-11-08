import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AuthService {
  static const _storage = FlutterSecureStorage();

  static const String _keySessionToken = 'session_token';
  static const String _keyExpirationTime = 'expiration_time';
  static const String _keyDriverId = 'driver_id';
  static const String _keyRouteId = 'route_id';
  static const String _keyVehicleId = 'vehicle_id';
  static const String _keySoftSessionExpiresAt = 'soft_session_expires_at';

  // List of all keys managed by this service
  static const _allKeys = [
    _keySessionToken,
    _keyExpirationTime,
    _keyDriverId,
    _keyRouteId,
    _keyVehicleId,
    _keySoftSessionExpiresAt,
  ];

  static Future<void> saveCredentials({
    required String sessionToken,
    required String driverId,
    required String routeId,
    required String vehicleId,
  }) async {
    // Prefer storing Supabase session token if provided, but local context is primary.
    final expirationTime =
        DateTime.now().add(const Duration(hours: 1)).toIso8601String();

    if (sessionToken.isNotEmpty) {
      await _storage.write(key: _keySessionToken, value: sessionToken);
      await _storage.write(key: _keyExpirationTime, value: expirationTime);
    }
    await _storage.write(key: _keyDriverId, value: driverId);
    await _storage.write(key: _keyRouteId, value: routeId);
    await _storage.write(key: _keyVehicleId, value: vehicleId);
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
      if (kDebugMode) {
        print('Error parsing expiration time: $e');
      }
      await deleteSession(); // Clear corrupted session data
      return {};
    }

    if (expirationTime.isBefore(DateTime.now())) {
      // Token expired: Clear storage
      if (kDebugMode) {
        print('Session expired. Deleting stored credentials.');
      }
      await deleteSession();
      return {}; // Return empty map to indicate expired/no session
    }
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
      print('Pasada local credentials have been removed.');
    }
  }

  // ───────────────────────── DRIVER CONTEXT HELPERS (JWT-friendly) ─────────────────────────
  // Store only domain context; JWT/session is handled by supabase_flutter internally.
  static Future<void> saveDriverContext({
    required String driverId,
    required String routeId,
    required String vehicleId,
  }) async {
    await _storage.write(key: _keyDriverId, value: driverId);
    await _storage.write(key: _keyRouteId, value: routeId);
    await _storage.write(key: _keyVehicleId, value: vehicleId);
  }

  static Future<Map<String, String?>> getDriverContext() async {
    return {
      _keyDriverId: await _storage.read(key: _keyDriverId),
      _keyRouteId: await _storage.read(key: _keyRouteId),
      _keyVehicleId: await _storage.read(key: _keyVehicleId),
    };
  }

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

  static String generateSecureToken() {
    final random = Random.secure();
    // Generate 32 bytes (256 bits) of random data
    final values = List<int>.generate(32, (i) => random.nextInt(256));
    // Encode as Base64 URL-safe string
    return base64Url.encode(values);
  }

  // ───────────────────────── SOFT SESSION EXPIRY (CLIENT-SIDE) ─────────────────────────
  static Future<void> setSessionExpiry(Duration duration) async {
    final expiresAt = DateTime.now().add(duration).toIso8601String();
    await _storage.write(key: _keySoftSessionExpiresAt, value: expiresAt);
  }

  static Future<DateTime?> getSessionExpiry() async {
    final s = await _storage.read(key: _keySoftSessionExpiresAt);
    if (s == null) return null;
    try {
      return DateTime.parse(s);
    } catch (_) {
      return null;
    }
  }

  static Future<bool> isSessionExpired() async {
    final dt = await getSessionExpiry();
    if (dt == null) return false; // not set, treat as not expired
    return dt.isBefore(DateTime.now());
  }
}
