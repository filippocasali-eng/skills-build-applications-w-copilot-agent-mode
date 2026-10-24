import 'dart:io';

import 'package:mixo_color_rush/game/ai/adaptive_director.dart';
import 'package:mixo_color_rush/game/ai/patterns.dart';

/// Loads game data straight from the asset files (unit tests, no bundle).
PatternLibrary loadLibrary() => PatternLibrary.fromJsonStrings(
  PatternLibrary.assetFiles.map((f) => File(f).readAsStringSync()),
);

AdaptiveDirector loadDirector() => AdaptiveDirector.fromJsonString(
  File('assets/data/difficulty_config.json').readAsStringSync(),
);
