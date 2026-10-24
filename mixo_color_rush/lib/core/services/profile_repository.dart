import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../game/ai/adaptive_director.dart';
import '../models/profile.dart';
import '../progression.dart';
import 'key_value_store.dart';

/// Loads and saves the [PlayerProfile] as a versioned JSON document.
class ProfileRepository {
  ProfileRepository(this.store, this.director);

  static const key = 'mixo.profile';
  static const backupKey = 'mixo.profile.bak';

  final KeyValueStore store;
  final AdaptiveDirector director;

  /// Upgrades older documents step by step to [PlayerProfile.schemaVersion].
  static Map<String, Object?> migrate(Map<String, Object?> j) {
    var v = j['schemaVersion'] as int? ?? 0;
    final out = Map<String, Object?>.of(j);
    while (v < PlayerProfile.schemaVersion) {
      switch (v) {
        case 0:
          // v0 (pre-release prototype): flat bestScore/stars, no stats.
          final best = out.remove('bestScore') as int? ?? 0;
          out['stats'] = {
            'bestScore': best,
            ...?(out['stats'] as Map<Object?, Object?>?)
                ?.cast<String, Object?>(),
          };
          out['nickname'] ??= {'a': 0, 'j': 0, 'n': 42};
      }
      v++;
      out['schemaVersion'] = v;
    }
    return out;
  }

  PlayerProfile load({int? seed}) {
    for (final k in const [key, backupKey]) {
      final raw = store.getString(k);
      if (raw == null) continue;
      try {
        final j = migrate((jsonDecode(raw) as Map<Object?, Object?>).cast());
        if (j['skill'] == null) j['skill'] = director.newSkill().toJson();
        return PlayerProfile.fromJson(j);
      } catch (e) {
        debugPrint('Profile "$k" unreadable: $e');
      }
    }
    final p = Progression.newProfile(
      seed ?? DateTime.now().microsecondsSinceEpoch,
      director,
    );
    Progression.ensureMissions(p, jumpLevel: director.jumpLevel);
    return p;
  }

  Future<void> save(PlayerProfile p) async {
    final raw = jsonEncode(p.toJson());
    final previous = store.getString(key);
    if (previous != null) await store.setString(backupKey, previous);
    await store.setString(key, raw);
  }
}
