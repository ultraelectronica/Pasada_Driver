import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AuthService {
  static const _storage = FlutterSecureStorage();

  // Public key names so other layers (e.g. AuthGate) can reference them safely.
  static const String keySessionToken = 'session_token';
  static const String keyExpirationTime = 'expiration_time';
  static const String keyDriverId = 'driver_id';
  static const String keyRouteId = 'route_id';
  static const String keyVehicleId = 'vehicle_id';
  static const String keySoftSessionExpiresAt = 'soft_session_expires_at';

  // List of all keys managed by this service
  static const _allKeys = [
    keySessionToken,
    keyExpirationTime,
    keyDriverId,
    keyRouteId,
    keyVehicleId,
    keySoftSessionExpiresAt,
  ];

  static Future<void> deleteSession() async {
    // Use defined list of keys
    for (final key in _allKeys) {
      await _storage.delete(key: key);
    }
    if (kDebugMode) {
      print('Pasada local credentials have been removed.');
    }
  }

  static Future<void> saveDriverContext({
    required String driverId,
    required String routeId,
    required String vehicleId,
  }) async {
    await _storage.write(key: keyDriverId, value: driverId);
    await _storage.write(key: keyRouteId, value: routeId);
    await _storage.write(key: keyVehicleId, value: vehicleId);
  }

  static Future<Map<String, String?>> getDriverContext() async {
    return {
      keyDriverId: await _storage.read(key: keyDriverId),
      keyRouteId: await _storage.read(key: keyRouteId),
      keyVehicleId: await _storage.read(key: keyVehicleId),
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
    }
  }

  static String generateSecureToken() {
    final random = Random.secure();
    // Generate 32 bytes (256 bits) of random data
    final values = List<int>.generate(32, (i) => random.nextInt(256));
    // Encode as Base64 URL-safe string
    return base64Url.encode(values);
  }

  static Future<void> setSessionExpiry(Duration duration) async {
    final expiresAt = DateTime.now().add(duration).toIso8601String();
    await _storage.write(key: keySoftSessionExpiresAt, value: expiresAt);
  }

  static Future<DateTime?> getSessionExpiry() async {
    final s = await _storage.read(key: keySoftSessionExpiresAt);
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
