import 'package:flutter/material.dart';

abstract final class MixoColors {
  static const night = Color(0xFF120A33);
  static const violet = Color(0xFF3B1C7A);
  static const grape = Color(0xFF6A2BB0);
  static const candy = Color(0xFFFF4FA3);
  static const sun = Color(0xFFFFD21F);
  static const mint = Color(0xFF2BD66B);
  static const ink = Color(0xFF1B1035);
}

ThemeData buildMixoTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: MixoColors.grape,
    brightness: Brightness.dark,
    primary: MixoColors.sun,
    onPrimary: MixoColors.ink,
    secondary: MixoColors.candy,
    surface: MixoColors.night,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: MixoColors.night,
    textTheme: Typography.whiteMountainView.apply(
      fontFamily: 'Roboto',
      bodyColor: Colors.white,
      displayColor: Colors.white,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(56, 56),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        textStyle: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
      ),
    ),
  );
}

const mixoBackground = BoxDecoration(
  gradient: LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [MixoColors.night, MixoColors.violet, MixoColors.grape],
  ),
);
