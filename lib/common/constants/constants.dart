// ignore_for_file: non_constant_identifier_names

import 'package:flutter/material.dart';

/// Used to define constants for the application.
/// This class contains static variables for screen width, corner radius, and also colors.
/// It is used to maintain a consistent design throughout the app.
class Constants {
  final double screenWidth;
  final double screenHeight;

  Constants(BuildContext context)
      : screenWidth = MediaQuery.of(context).size.width,
        screenHeight = MediaQuery.of(context).size.height;

  static double CORNER_RADIUS = 20;
  static double CONTAINER_HEIGHT = 50;
  static double BOX_SHADOW = 5;

  static Color GRADIENT_COLOR_1 = const Color(0xFF00CC58);
  static Color GRADIENT_COLOR_2 = const Color(0xFF88CB0C);

  static Color GREEN_COLOR = const Color(0xFF00CC58);
  static Color GREEN_COLOR_LIGHT = const Color(0xFFA3E7C1);
  static Color GREEN_COLOR_DARK = const Color(0xFF0F311E);

  static Color RED_COLOR = const Color(0xFFD7481D);
  static Color YELLOW_COLOR = const Color(0xFFFFCE21);

  static Color WHITE_COLOR_LIGHT_DARK = const Color(0xFFCCEEDB);
  static Color WHITE_COLOR = const Color(0xFFF5F5F5);

  static Color GREY_COLOR = Colors.grey.shade300;

  static Color BLACK_COLOR = const Color(0xFF121212);
  static Color SWITCH_GREY_COLOR_DARK = const Color(0xFF383838);
  static Color SWITCH_GREY_COLOR = const Color(0xFF848484);
}
