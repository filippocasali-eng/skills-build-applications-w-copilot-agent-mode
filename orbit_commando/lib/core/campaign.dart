import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../game/levels/level_data.dart';
import '../game/levels/tiled_loader.dart';

class CampaignEntry {
  const CampaignEntry({
    required this.id,
    required this.name,
    required this.world,
    required this.index,
    required this.boss,
    required this.file,
  });

  final String id, name, file;
  final int world, index;
  final bool boss;

  /// 1..15 in play order.
  int get number => (world - 1) * 5 + index;
}

/// The campaign index (assets/levels/campaign.json) and level loading.
class Campaign {
  const Campaign(this.entries);

  final List<CampaignEntry> entries;

  List<String> get order => [for (final e in entries) e.id];

  CampaignEntry byId(String id) => entries.firstWhere((e) => e.id == id);

  CampaignEntry? next(String id) {
    final i = order.indexOf(id);
    return i >= 0 && i + 1 < entries.length ? entries[i + 1] : null;
  }

  List<CampaignEntry> world(int w) =>
      entries.where((e) => e.world == w).toList();

  List<CampaignEntry> get bosses => entries.where((e) => e.boss).toList();

  static Future<Campaign> load(AssetBundle bundle) async {
    final json = jsonDecode(
      await bundle.loadString('assets/levels/campaign.json'),
    ) as Map<String, dynamic>;
    return Campaign([
      for (final l in json['levels'] as List<dynamic>)
        CampaignEntry(
          id: (l as Map<String, dynamic>)['id'] as String,
          name: l['name'] as String,
          world: l['world'] as int,
          index: l['index'] as int,
          boss: l['boss'] as bool,
          file: l['file'] as String,
        ),
    ]);
  }

  static Future<LevelData> loadLevel(
    AssetBundle bundle,
    CampaignEntry e,
  ) async => TiledLoader.parse(await bundle.loadString('assets/${e.file}'));
}

final campaignProvider = FutureProvider<Campaign>(
  (ref) => Campaign.load(rootBundle),
);
