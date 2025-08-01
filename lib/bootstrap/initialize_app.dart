import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:pasada_driver_side/Services/permissions.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:pasada_driver_side/common/logging.dart';

/// Performs application bootstrap tasks such as loading environment variables,
/// initializing Supabase, checking runtime permissions, and preparing a list of
/// assets that should be precached once the first [BuildContext] becomes
/// available.
///
/// The returned [Future] completes with the list of [AssetImage] objects to be
/// precached by the UI layer.
Future<List<AssetImage>> initializeApp() async {
  // 1. Load environment variables
  await dotenv.load(fileName: '.env');

  // 2. Initialize Supabase with a timeout safeguard
  await Supabase.initialize(
    anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
    url: dotenv.env['SUPABASE_URL']!,
  ).timeout(
    const Duration(seconds: 10),
    onTimeout: () =>
        throw TimeoutException('Supabase initialization timed out'),
  );

  // 3. Ensure required OS-level permissions
  await CheckPermissions().checkPermissions();

  // 4. Build the list of frequently-used assets to preload
  final List<AssetImage> assetsToPreload = [
    const AssetImage('assets/png/PasadaLogo.png'),
    // TODO: Add additional assets here as needed
  ];

  logDebug('initializeApp completed. assets: $assetsToPreload');

  return assetsToPreload;
}
