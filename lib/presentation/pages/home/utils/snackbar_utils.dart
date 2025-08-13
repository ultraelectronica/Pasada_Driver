import 'package:flutter/material.dart';

/// Simple helper to reduce SnackBar boiler-plate.
class SnackBarUtils {
  const SnackBarUtils._();

  static void show(BuildContext ctx, String message, Color background,
      {Duration duration = const Duration(seconds: 2)}) {
    if (ctx.mounted) {
      ScaffoldMessenger.of(ctx).showSnackBar(
        SnackBar(
            content: Text(message),
            backgroundColor: background,
            duration: duration),
      );
    }
  }

  // Capacity-specific helpers
  static void showManualAdded(BuildContext ctx, String seatType) {
    show(ctx, '$seatType passenger added manually', Colors.blue);
  }

  static void showManualRemoved(BuildContext ctx, String seatType) {
    show(ctx, '$seatType passenger removed manually', Colors.red);
  }

  static void showSuccess(BuildContext ctx, String message) {
    show(ctx, message, Colors.green);
  }

  static void showWarning(BuildContext ctx, String message) {
    show(ctx, message, Colors.orange);
  }

  static void showError(BuildContext ctx, String message) {
    show(ctx, message, Colors.red);
  }
}
