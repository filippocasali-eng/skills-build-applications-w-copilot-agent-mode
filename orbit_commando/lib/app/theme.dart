import 'package:flutter/material.dart';

import '../engine/render/palette.g.dart';

ThemeData buildTheme() => ThemeData(
  brightness: Brightness.dark,
  scaffoldBackgroundColor: Pal.ink0,
  colorScheme: const ColorScheme.dark(
    primary: Pal.gold5,
    secondary: Pal.aqua5,
    surface: Pal.ink1,
    error: Pal.ember4,
  ),
);
