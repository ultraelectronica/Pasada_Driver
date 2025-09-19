import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:pasada_driver_side/Services/encryption_service.dart';

/// Service to resolve and fetch ID images stored in Supabase Storage.
///
/// Responsibilities:
/// - Accept raw value from DB that may be encrypted, a storage URL, or an object path
/// - Decrypt if needed
/// - Resolve to bucket/objectPath
/// - Download via public URL (if bucket public) or a fresh signed URL
class IdImageFetchService {
  static final SupabaseClient _supabase = Supabase.instance.client;

  /// Fetch image bytes for display. Returns null if not accessible.
  static Future<Uint8List?> fetchImageBytes(String rawValue) async {
    try {
      final encryptionService = EncryptionService();
      await encryptionService.initialize();

      // Decrypt if needed
      String value = rawValue.trim();
      if (encryptionService.isEncrypted(value) ||
          encryptionService.isEncryptedImage(value)) {
        value = (await encryptionService.decryptUserData(value)).trim();
      }

      // Try URL first (public/signed storage URLs)
      if (_isSupabaseStorageUrl(value)) {
        final bytes = await _fetchFromStorageUrl(value);
        if (bytes != null) return bytes;

        // If URL failed, try to extract bucket/object and re-mint
        final bucket = _extractBucketFromSupabaseUrl(value);
        final objectPath = bucket == null
            ? null
            : _extractObjectPathFromSupabaseUrl(value, bucket);
        if (bucket != null && objectPath != null) {
          return await _fetchViaPublicOrSigned(bucket, objectPath);
        }
        return null;
      }

      // supabase://bucket/path format
      if (value.startsWith('supabase://')) {
        final uri = Uri.parse(value);
        final bucket = uri.host;
        final objectPath =
            uri.path.startsWith('/') ? uri.path.substring(1) : uri.path;
        if (bucket.isNotEmpty && objectPath.isNotEmpty) {
          return await _fetchViaPublicOrSigned(bucket, objectPath);
        }
        return null;
      }

      // Plain storage object path. Use configured bucket or default.
      if (value.contains('/') && value.contains('.')) {
        final configuredBucket =
            dotenv.env['SUPABASE_BUCKET_PAX_IDS']?.trim() ?? 'id-verification';

        String bucket = configuredBucket;
        String objectPath;

        if (value.startsWith('$configuredBucket/')) {
          objectPath = value.substring(configuredBucket.length + 1);
        } else {
          objectPath = value;
        }

        objectPath = _sanitizeObjectPath(objectPath);

        if (bucket.isNotEmpty && objectPath.isNotEmpty) {
          return await _fetchViaPublicOrSigned(bucket, objectPath);
        }
      }

      return null;
    } catch (e) {
      debugPrint('IdImageFetchService error: $e');
      return null;
    }
  }

  static bool _isSupabaseStorageUrl(String value) {
    return value.startsWith('http') && value.contains('/storage/v1/object');
  }

  static Future<Uint8List?> _fetchFromStorageUrl(String url) async {
    try {
      final resp = await http.get(Uri.parse(url));
      if (resp.statusCode == 200) {
        return Uint8List.fromList(resp.bodyBytes);
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  static Future<Uint8List?> _fetchViaPublicOrSigned(
      String bucket, String objectPath,
      {int expirySeconds = 3600}) async {
    try {
      objectPath = _sanitizeObjectPath(objectPath);

      // Try public URL (works if bucket is public)
      try {
        final publicUrl =
            _supabase.storage.from(bucket).getPublicUrl(objectPath);
        final pubResp = await http.get(Uri.parse(publicUrl));
        if (pubResp.statusCode == 200) {
          return Uint8List.fromList(pubResp.bodyBytes);
        }
      } catch (_) {}

      // Fallback to signed URL (private buckets or if public was disabled)
      final signedUrl = await _supabase.storage
          .from(bucket)
          .createSignedUrl(objectPath, expirySeconds);
      final resp = await http.get(Uri.parse(signedUrl));
      if (resp.statusCode == 200) {
        return Uint8List.fromList(resp.bodyBytes);
      }
      return null;
    } catch (e) {
      debugPrint('Public/Signed URL fetch failed: $e');
      return null;
    }
  }

  static String _sanitizeObjectPath(String path) {
    String p = path.trim();
    if (p.startsWith('/')) p = p.substring(1);
    if ((p.startsWith('"') && p.endsWith('"')) ||
        (p.startsWith("'") && p.endsWith("'"))) {
      p = p.substring(1, p.length - 1);
    }
    return p;
  }

  static String? _extractBucketFromSupabaseUrl(String url) {
    try {
      final uri = Uri.parse(url);
      final segments = uri.pathSegments;
      final idx = segments.indexOf('object');
      if (idx != -1 && idx < segments.length - 1) {
        int bucketIdx = idx + 1;
        if (segments[bucketIdx] == 'public' || segments[bucketIdx] == 'sign') {
          bucketIdx++;
        } else if (segments[bucketIdx] == 'auth') {
          if (bucketIdx + 1 < segments.length &&
              segments[bucketIdx + 1] == 'sign') {
            bucketIdx += 2;
          }
        }
        if (bucketIdx < segments.length) {
          return segments[bucketIdx];
        }
      }
    } catch (_) {}
    return null;
  }

  static String? _extractObjectPathFromSupabaseUrl(String url, String bucket) {
    try {
      final uri = Uri.parse(url);
      final segments = uri.pathSegments;
      final bucketIndex = segments.indexOf(bucket);
      if (bucketIndex != -1 && bucketIndex < segments.length - 1) {
        return segments.sublist(bucketIndex + 1).join('/');
      }
    } catch (_) {}
    return null;
  }
}
