import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class Authservice {
  final supabase = Supabase.instance.client;
  static const _storage = FlutterSecureStorage();

  static Future<void> saveCredentials(
      {required String sessionToken,
      required String driverId,
      // required String routeId,
      required String vehicleId,
      required String expiresAt}) async {
    final expirationTime =
        DateTime.now().add(const Duration(hours: 24)).toIso8601String();

    await _storage.write(key: 'session_token', value: sessionToken);
    await _storage.write(key: 'expiration_time', value: expirationTime);
    await _storage.write(key: 'driver_id', value: driverId);
    // await _storage.write(key: 'route_id', value: routeId);
    await _storage.write(key: 'vehicle_id', value: vehicleId);
    await _storage.write(key: 'expires_at', value: expiresAt);
  }

  static Future<Map<String, String?>> getSession() async {
    final sessionToken = await _storage.read(key: 'session_token');
    final expirationTimeString = await _storage.read(key: 'expiration_time');

    // Check if token exists and is not expired
    if (sessionToken == null || expirationTimeString == null) {
      return {}; // No valid session
    }

    final expirationTime = DateTime.parse(expirationTimeString);
    if (expirationTime.isBefore(DateTime.now())) {
      // Token expired: Clear storage
      await deleteSession();
      return {};
    }

    if (kDebugMode) {
      print('session_token: $sessionToken, '
          'driver_id: ${await _storage.read(key: 'driver_id')}, '
          // 'route_id: ${await _storage.read(key: 'route_id')}, '
          'vehicle_id: ${await _storage.read(key: 'vehicle_id')}');
    }

    // Return valid session data
    return {
      'session_token': sessionToken,
      'driver_id': await _storage.read(key: 'driver_id'),
      // 'route_id': await _storage.read(key: 'route_id'),
      'vehicle_id': await _storage.read(key: 'vehicle_id'),
    };
  }

  static Future<void> deleteSession() async {
    await _storage.delete(key: 'session_token');
    await _storage.delete(key: 'expiration_time');
    await _storage.delete(key: 'driver_id');
    // await _storage.delete(key: 'route_id');
    await _storage.delete(key: 'vehicle_id');
  }

  String generateSecureToken() {
    final random = Random.secure();
    return base64Url.encode(List.generate(32, (_) => random.nextInt(256)));
  }
}
