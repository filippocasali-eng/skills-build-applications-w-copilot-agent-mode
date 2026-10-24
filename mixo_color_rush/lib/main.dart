import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'core/providers.dart';
import 'core/services/game_data.dart';
import 'core/services/key_value_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  final results = await Future.wait([
    GameData.load(rootBundle),
    SharedPrefsStore.open(),
  ]);
  runApp(
    ProviderScope(
      overrides: [
        gameDataProvider.overrideWithValue(results[0] as GameData),
        storeProvider.overrideWithValue(results[1] as KeyValueStore),
      ],
      child: const MixoApp(),
    ),
  );
}
