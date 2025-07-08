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
}
