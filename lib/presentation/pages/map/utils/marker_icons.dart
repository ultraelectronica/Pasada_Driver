import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class MarkerIcons {
  static BitmapDescriptor? pinGreen;
  static BitmapDescriptor? pinOrange;
  static BitmapDescriptor? pinRed;

  static Future<void>? _loadingFuture;

  /// Ensure icons are loaded once.
  static Future<void> ensureLoaded() async {
    if (pinGreen != null && pinOrange != null && pinRed != null) {
      return;
    }
    _loadingFuture ??= _load();
    await _loadingFuture;
  }

  static Future<void> _load() async {
    pinGreen = await BitmapDescriptor.asset(
      const ImageConfiguration(size: Size(48, 48)),
      'assets/png/green_pin.png',
    );
    pinOrange = await BitmapDescriptor.asset(
      const ImageConfiguration(size: Size(48, 48)),
      'assets/png/orange_pin.png',
    );
    pinRed = await BitmapDescriptor.asset(
      const ImageConfiguration(size: Size(48, 48)),
      'assets/png/red_pin.png',
    );
  }
}
