import 'package:flutter/material.dart';

class Styles {
  static const Color customWhite = Color(0xFFF5F5F5);
  static const Color customBlack = Color(0xFF121212);

  static const FontWeight normalWeight = FontWeight.normal;
  static const FontWeight w700Weight = FontWeight.w700;
  static const FontWeight w600Weight = FontWeight.w600;
  static const FontWeight w500Weight = FontWeight.w500;

  TextStyle textStyle(double size, FontWeight weight, Color color) {
    return TextStyle(
      fontSize: size,
      fontFamily: 'Inter',
      fontWeight: weight,
      color: color,
    );
  }
}
