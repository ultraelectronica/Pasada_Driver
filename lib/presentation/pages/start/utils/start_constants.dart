import 'package:flutter/material.dart';

/// Constants specific to the onboarding / start flow.
/// Using named values instead of magic numbers improves readability and makes
/// it easy to tweak the onboarding design in one place.
class StartConstants {
  // Layout fractions
  static const double welcomeLogoTopFraction = 0.15;
  static const double welcomeLogoSizeFraction = 0.4;
  static const double nextButtonVerticalPaddingFraction = 0.1;
  static const double pageIndicatorBottomFraction = 0.05;

  // Page indicator dimensions
  static const double indicatorActiveWidth = 22;
  static const double indicatorInactiveSize = 8;
  static const double indicatorActiveHeight = 12;
  static const Duration indicatorAnimDuration = Duration(milliseconds: 200);

  // Page transition
  static const Duration pageTransitionDuration = Duration(milliseconds: 400);
  static const Curve pageTransitionCurve = Curves.easeInOutExpo;
}
