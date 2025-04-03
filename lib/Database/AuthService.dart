import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:pasada_driver_side/UI/message.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class Authservice {
  final supabase = Supabase.instance.client;
  static const _storage = FlutterSecureStorage();
  static const allKeys = [
    'session_token',
    'expiration_time',
    'driver_id',
    'route_id',
    'vehicle_id'
  ];

  static Future<void> saveCredentials(
      {required String sessionToken,
      required String driverId,
      required String routeId,
      required String vehicleId,
      required String expiresAt}) async {
    //generate expiration time
    final expirationTime =
        DateTime.now().add(const Duration(minutes: 1)).toIso8601String();

    await _storage.write(key: 'session_token', value: sessionToken);
    await _storage.write(key: 'expiration_time', value: expirationTime);
    await _storage.write(key: 'driver_id', value: driverId);
    await _storage.write(key: 'route_id', value: routeId);
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
      ShowMessage().showToast('Session Expired');
      await deleteSession();
      return {};
    }

    Authservice.printStorageContents();

    // Return valid session data
    return {
      'session_token': sessionToken,
      'driver_id': await _storage.read(key: 'driver_id'),
      'route_id': await _storage.read(key: 'route_id'),
      'vehicle_id': await _storage.read(key: 'vehicle_id'),
    };
  }

  static Future<void> deleteSession() async {
    for (final key in allKeys) {
      await _storage.delete(key: key);
    }
    if (kDebugMode) {
      ShowMessage().showToast('Pasada local credentials has been removed.');
    }
  }

  static Future<void> printStorageContents() async {
    if (kDebugMode) {
      print('Storage contents:');

      for (final key in allKeys) {
        final value = await _storage.read(key: key);
        print('$key: $value');
      }
    }
  }

  String generateSecureToken() {
    final random = Random.secure();
    return base64Url.encode(List.generate(32, (_) => random.nextInt(256)));
  }
}
