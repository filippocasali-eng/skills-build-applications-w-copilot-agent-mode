import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'services/game_data.dart';
import 'services/key_value_store.dart';

/// Overridden in `main()` once assets are loaded.
final gameDataProvider = Provider<GameData>(
  (ref) => throw UnimplementedError('gameDataProvider must be overridden'),
);

/// Overridden in `main()` with [SharedPrefsStore]; tests use [MemoryStore].
final storeProvider = Provider<KeyValueStore>((ref) => MemoryStore());
