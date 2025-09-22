import 'package:flutter/material.dart';

class Styles {
  static const Color customWhiteFont = Color(0xFFF5F5F5);
  static const Color customBlackFont = Color(0xFF121212);

  static const FontWeight bold = FontWeight.w700;
  static const FontWeight semiBold = FontWeight.w600;
  static const FontWeight medium = FontWeight.w500;
  static const FontWeight normal = FontWeight.w400;

  TextStyle textStyle(double size, FontWeight weight, Color color) {
    return TextStyle(
      fontSize: size,
      fontFamily: 'Inter',
      fontWeight: weight,
      color: color,
    );
  }
}
