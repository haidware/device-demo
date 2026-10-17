import 'package:flutter/material.dart';

abstract final class AppColors {
  static const background = Color(0xFF080A0E);
  static const surface = Color(0xFF101318);
  static const raisedSurface = Color(0xFF171B20);
  static const border = Color(0xFF30343A);
  static const gold = Color(0xFFD9A441);
  static const goldLight = Color(0xFFF1C45E);
  static const text = Color(0xFFF4F1EB);
  static const muted = Color(0xFFA5A9AE);
  static const green = Color(0xFF48B96B);
  static const red = Color(0xFFE16363);
}

ThemeData buildAppTheme() {
  return ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: AppColors.background,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.gold,
      brightness: Brightness.dark,
    ),
    fontFamily: 'Roboto',
    useMaterial3: true,
  );
}
