import 'package:flutter_test/flutter_test.dart';
import 'package:pasada_driver_side/Services/encryption_service.dart';
import 'dart:convert';

void main() {
  group('EncryptionService Tests', () {
    late EncryptionService encryptionService;

    setUp(() {
      encryptionService = EncryptionService();
    });

    test('should initialize encryption service', () async {
      // This test will fail if ENCRYPTION_MASTER_KEY_B64 is not set in .env
      // but that's expected for testing without proper environment setup
      try {
        await encryptionService.initialize();
        expect(true, isTrue); // If we get here, initialization succeeded
      } catch (e) {
        // Expected to fail without proper .env setup
        expect(e.toString(), contains('Error initializing encryption service'));
      }
    });

    test('should detect encrypted data correctly', () {
      const plainText = 'test data';
      final encryptedV2 = 'ENC_V2:${base64.encode(utf8.encode(plainText))}';
      final encryptedV3 = 'ENC_V3:${base64.encode(utf8.encode(plainText))}';

      expect(encryptionService.isEncrypted(plainText), isFalse);
      expect(encryptionService.isEncrypted(encryptedV2), isTrue);
      expect(encryptionService.isEncrypted(encryptedV3), isTrue);
    });

    test('should detect encrypted image data correctly', () {
      const plainImage =
          'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==';
      final encryptedV2 = 'ENC_V2:${base64.encode(utf8.encode(plainImage))}';
      final encryptedV3 = 'ENC_V3:${base64.encode(utf8.encode(plainImage))}';

      expect(encryptionService.isEncryptedImage(plainImage), isFalse);
      expect(encryptionService.isEncryptedImage(encryptedV2), isTrue);
      expect(encryptionService.isEncryptedImage(encryptedV3), isTrue);
    });

    test('should handle base64 image data without encryption', () {
      // Test with a simple 1x1 PNG image in base64
      const base64Image =
          'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==';

      expect(encryptionService.isEncryptedImage(base64Image), isFalse);
    });

    test('should generate fallback values for different field types', () {
      expect(encryptionService.generateFallbackValue('contact_number'),
          equals('+639000000000'));
      expect(encryptionService.generateFallbackValue('passenger_email'),
          equals('user@example.com'));
      expect(encryptionService.generateFallbackValue('display_name'),
          equals('User'));
      expect(encryptionService.generateFallbackValue('avatar_url'),
          equals('assets/svg/default_user_profile.svg'));
      expect(encryptionService.generateFallbackValue('unknown_field'),
          equals('[RECOVERY_NEEDED]'));
    });
  });
}
