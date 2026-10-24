import 'package:flutter/services.dart';

import '../../game/ai/adaptive_director.dart';
import '../../game/ai/patterns.dart';

/// Static game data loaded once from assets.
class GameData {
  const GameData({required this.library, required this.director});

  static Future<GameData> load(AssetBundle bundle) async {
    final docs = await Future.wait(
      PatternLibrary.assetFiles.map(bundle.loadString),
    );
    final config = await bundle.loadString(
      'assets/data/difficulty_config.json',
    );
    return GameData(
      library: PatternLibrary.fromJsonStrings(docs),
      director: AdaptiveDirector.fromJsonString(config),
    );
  }

  final PatternLibrary library;
  final AdaptiveDirector director;
}
