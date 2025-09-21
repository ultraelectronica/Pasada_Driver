import 'package:flutter/material.dart';
import 'package:pasada_driver_side/common/constants/text_styles.dart';

/// Simple helper for notifications.
class SnackBarUtils {
  const SnackBarUtils._();

  /// Show a basic notification
  static void show(
    BuildContext ctx,
    String message,
    Color background, {
    AnimationController? animationController,
    Duration duration = const Duration(seconds: 2),
  }) {
    if (ctx.mounted) {
      ScaffoldMessenger.of(ctx).showSnackBar(
        SnackBar(
          content: Text(message,
              style: Styles()
                  .textStyle(16, FontWeight.w600, Styles.customWhiteFont)),
          backgroundColor: background,
          duration: duration,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          animation: animationController != null
              ? CurvedAnimation(
                  parent: animationController, curve: Curves.easeInOut)
              : null,
        ),
      );
    }
  }

  /// Pop a notification immediately (replaces current one)
  static void pop(BuildContext ctx, String message, {Color? backgroundColor}) {
    if (ctx.mounted) {
      ScaffoldMessenger.of(ctx).clearSnackBars();
      show(ctx, message, backgroundColor ?? Colors.blue,
          duration: const Duration(milliseconds: 1200));
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
