import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mixo_color_rush/app/app.dart';
import 'package:mixo_color_rush/core/providers.dart';
import 'package:mixo_color_rush/core/services/game_data.dart';
import 'package:mixo_color_rush/core/services/key_value_store.dart';

import 'test_data.dart';

/// Shared test container: real game data, in-memory storage, fixed clock.
ProviderContainer testContainer({MemoryStore? store, DateTime? now}) =>
    ProviderContainer(
      overrides: [
        gameDataProvider.overrideWithValue(
          GameData(library: loadLibrary(), director: loadDirector()),
        ),
        storeProvider.overrideWithValue(store ?? MemoryStore()),
        clockProvider.overrideWithValue(
          () => now ?? DateTime(2026, 10, 24, 16),
        ),
      ],
    );

Widget testApp(ProviderContainer c, {Widget? home, String locale = 'it'}) =>
    UncontrolledProviderScope(
      container: c,
      child: MixoApp(locale: Locale(locale), home: home),
    );
