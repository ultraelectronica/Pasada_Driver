import 'dart:io';
import 'package:flutter/services.dart';

class MinimizeApp {
  static const MethodChannel _channel = MethodChannel('app.minimize');

  static Future<void> moveToBackground() async {
    if (!Platform.isAndroid) {
      return;
    }
    try {
      await _channel.invokeMethod('moveTaskToBack');
    } catch (_) {
      // Fallback to avoid crash if channel is unavailable for some reason
      try {
        await SystemNavigator.pop();
      } catch (_) {}
    }
  }
}
