import 'package:cherry_toast/cherry_toast.dart';
import 'package:cherry_toast/resources/arrays.dart';
import 'package:flutter/material.dart';
import 'package:pasada_driver_side/common/constants/text_styles.dart';

/// Simple helper for notifications.
class SnackBarUtils {
  const SnackBarUtils._();

  /// Shows a cherry toast snackbar
  /// [ctx] - The context of the widget to show the snackbar
  /// [message] - The message to show in the snackbar
  ///
  static void show(
    BuildContext ctx,
    String message,
    String description, {
    Color? backgroundColor,
    AnimationController? animationController,
    AnimationType? animationType,
    Duration duration = const Duration(seconds: 1),
    Position? position,
  }) {
    if (ctx.mounted) {
      CherryToast.info(
        toastPosition: position ?? Position.bottom,
        disableToastAnimation: false,
        inheritThemeColors: true,
        backgroundColor: backgroundColor ?? Colors.blue,
        autoDismiss: true,
        title: Text(
          message,
          style:
              Styles().textStyle(15, Styles.semiBold, Styles.customBlackFont),
        ),
        description: Text(
          description,
          style: Styles().textStyle(14, Styles.normal, Styles.customBlackFont),
        ),
        actionHandler: () {},
        displayCloseButton: false,
        animationType: animationType ?? AnimationType.fromBottom,
        animationDuration: const Duration(milliseconds: 1000),
        animationCurve: Curves.ease,
        enableIconAnimation: true,
        width: MediaQuery.of(ctx).size.width * 0.9,
        toastDuration: duration,
      ).show(ctx);
      // ScaffoldMessenger.of(ctx).showSnackBar(
      //   SnackBar(
      //     content: Text(
      //       message,
      //       style:
      //           Styles().textStyle(14, FontWeight.w600, Styles.customWhiteFont),
      //       textAlign: TextAlign.center,
      //     ),
      //     backgroundColor: background,
      //     duration: duration,
      //     behavior: SnackBarBehavior.floating,
      //     margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      //     shape: RoundedRectangleBorder(
      //       borderRadius: BorderRadius.circular(8),
      //     ),
      //     animation: animationController != null
      //         ? CurvedAnimation(
      //             parent: animationController, curve: Curves.easeInOut)
      //         : null,
      //   ),
      // );
    }
  }

  /// Pop a notification immediately (replaces current one)
  static void pop(BuildContext ctx, String message, String description,
      {Color? backgroundColor}) {
    if (ctx.mounted) {
      ScaffoldMessenger.of(ctx).clearSnackBars();
      show(ctx, message, description,
          backgroundColor: backgroundColor ?? Colors.blue,
          duration: const Duration(milliseconds: 1200));
    }
  }

  // Common helpers
  static void showSuccess(
    BuildContext ctx,
    String message,
    String description, {
    Position position = Position.bottom,
    AnimationType? animationType,
    Duration duration = const Duration(seconds: 2),
  }) {
    if (ctx.mounted) {
      CherryToast.success(
        toastPosition: position,
        disableToastAnimation: false,
        inheritThemeColors: true,
        autoDismiss: true,
        title: Text(
          message,
          style:
              Styles().textStyle(15, Styles.semiBold, Styles.customBlackFont),
        ),
        description: Text(
          description,
          style: Styles().textStyle(14, Styles.normal, Styles.customBlackFont),
        ),
        actionHandler: () {},
        displayCloseButton: false,
        animationType: animationType ?? AnimationType.fromBottom,
        animationDuration: const Duration(milliseconds: 1000),
        animationCurve: Curves.ease,
        enableIconAnimation: true,
        width: MediaQuery.of(ctx).size.width * 0.9,
        toastDuration: duration,
      ).show(ctx);
    }
  }

  static void showError(
    BuildContext ctx,
    String message,
    String description, {
    Position position = Position.bottom,
    AnimationType? animationType,
    Duration duration = const Duration(seconds: 1),
  }) {
    if (ctx.mounted) {
      CherryToast.error(
        toastPosition: position,
        disableToastAnimation: false,
        inheritThemeColors: true,
        autoDismiss: true,
        title: Text(
          message,
          style:
              Styles().textStyle(15, Styles.semiBold, Styles.customBlackFont),
        ),
        description: Text(
          description,
          style: Styles().textStyle(14, Styles.normal, Styles.customBlackFont),
        ),
        actionHandler: () {},
        displayCloseButton: false,
        animationType: animationType ?? AnimationType.fromBottom,
        animationDuration: const Duration(milliseconds: 500),
        animationCurve: Curves.ease,
        enableIconAnimation: true,
        width: MediaQuery.of(ctx).size.width * 0.9,
        toastDuration: duration,
      ).show(ctx);
    }
  }
}
