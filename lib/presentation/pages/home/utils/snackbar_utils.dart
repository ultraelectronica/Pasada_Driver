import 'package:flutter/material.dart';

/// Simple helper for notifications.
class SnackBarUtils {
  const SnackBarUtils._();

  /// Show a basic notification
  static void show(
    BuildContext ctx,
    String message,
    Color background, {
    Duration duration = const Duration(seconds: 2),
  }) {
    if (ctx.mounted) {
      ScaffoldMessenger.of(ctx).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: background,
          duration: duration,
        ),
      );
    }
  }

  /// Pop a notification immediately (replaces current one)
  static void pop(BuildContext ctx, String message, {Color? backgroundColor}) {
    if (ctx.mounted) {
      ScaffoldMessenger.of(ctx).clearSnackBars();
      ScaffoldMessenger.of(ctx).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: backgroundColor ?? Colors.blue,
          duration: const Duration(milliseconds: 800),
        ),
      );
    }
  }

  // Common helpers
  static void showSuccess(BuildContext ctx, String message) {
    show(ctx, message, Colors.green);
  }

  static void showError(BuildContext ctx, String message) {
    show(ctx, message, Colors.red);
  }
}
