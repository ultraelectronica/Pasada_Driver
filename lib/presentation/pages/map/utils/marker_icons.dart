import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Centralized loader/cacher for custom map marker icons.
class MarkerIcons {
  static BitmapDescriptor? pinGreen;
  static BitmapDescriptor? pinOrange;
  static BitmapDescriptor? pinRed;

  static Future<void>? _loadingFuture;

  /// Ensure icons are loaded once. Safe to call multiple times.
  static Future<void> ensureLoaded() async {
    if (pinGreen != null && pinOrange != null && pinRed != null) {
      return;
    }
    _loadingFuture ??= _load();
    await _loadingFuture;
  }

  static Future<void> _load() async {
    // Use bytes approach to avoid BuildContext/MediaQuery usage here
    pinGreen = await _fromAsset('assets/png/green_pin.png', width: 60);
    pinOrange = await _fromAsset('assets/png/orange_pin.png', width: 60);
    pinRed = await _fromAsset('assets/png/red_pin.png', width: 60);
  }

  static Future<BitmapDescriptor> _fromAsset(String assetPath,
      {int width = 96}) async {
    final ByteData data = await rootBundle.load(assetPath);
    final ui.Codec codec = await ui.instantiateImageCodec(
      data.buffer.asUint8List(),
      targetWidth: width,
    );
    final ui.FrameInfo fi = await codec.getNextFrame();
    final ByteData? bytes =
        await fi.image.toByteData(format: ui.ImageByteFormat.png);
    return BitmapDescriptor.bytes(bytes!.buffer.asUint8List());
  }
}
