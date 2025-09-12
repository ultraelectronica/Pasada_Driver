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

  static Color GREEN_COLOR = const Color(0xff067837);
  static Color WHITE_COLOR = const Color(0xFFF2F2F2);
  static Color BLACK_COLOR = const Color(0xFF121212);
}
