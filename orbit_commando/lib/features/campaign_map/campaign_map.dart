import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/level_names.dart';
import '../../app/ui/pixel.dart';
import '../../app/ui/route.dart';
import '../../core/campaign.dart';
import '../../core/monetization/wallet.dart';
import '../../core/progress/progress.dart';
import '../../core/settings/settings.dart';
import '../../engine/render/palette.g.dart';
import '../../game/play_config.dart';
import '../../game/roster.dart';
import '../../game/sim/balance.dart';
import '../../l10n/app_localizations.dart';
import '../play/play_screen.dart';
import '../run/run.dart';
import '../shop/shop_screen.dart';

/// Solar-system map: pick a world, a level, your commando and difficulty.
class CampaignMap extends ConsumerStatefulWidget {
  const CampaignMap({super.key});

  @override
  ConsumerState<CampaignMap> createState() => _CampaignMapState();
}

class _CampaignMapState extends ConsumerState<CampaignMap> {
  int _world = 1;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final campaign = ref.watch(campaignProvider);
    final p = ref.watch(progressProvider);
    final s = ref.watch(settingsProvider);
    final w = ref.watch(walletProvider);
    return PixelScreen(
      title: l.menuCampaign,
      child: campaign.when(
        loading: () => Center(child: PixelText(l.loading)),
        error: (e, _) => Center(child: PixelText('$e')),
        data: (c) {
          final worldLocked = _world > 1 && !w.fullCartridge;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // World selector + level list.
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          for (var i = 1; i <= 3; i++) ...[
                            PixelButton(
                              label: l.worldN(i),
                              color: i == _world ? Pal.gold7 : Pal.ink5,
                              autofocus: i == 1,
                              onPressed: () => setState(() => _world = i),
                            ),
                            const SizedBox(width: 6),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      PixelText(
                        switch (_world) {
                          1 => l.world1Name,
                          2 => l.world2Name,
                          _ => l.world3Name,
                        },
                        scale: 1.1,
                        color: Pal.aqua6,
                      ),
                      const SizedBox(height: 6),
                      if (worldLocked)
                        PixelPanel(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              PixelText(
                                l.shopCartridge,
                                scale: 1.3,
                                color: Pal.gold6,
                              ),
                              SizedBox(
                                width: 420,
                                child: PixelText(
                                  l.shopCartridgeDesc,
                                  scale: 0.8,
                                ),
                              ),
                              const SizedBox(height: 8),
                              PixelButton(
                                label: l.menuShop,
                                onPressed: () =>
                                    Navigator.of(context)
                                        .push(PixelRoute(const ShopScreen())),
                              ),
                            ],
                          ),
                        )
                      else
                        Expanded(
                          child: ListView(
                            children: [
                              for (final e in c.world(_world))
                                _LevelTile(
                                  entry: e,
                                  record: p.record(e.id),
                                  unlocked: p.unlocked(c.order, e.id),
                                  onPlay: () => _play(e, p, s),
                                ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                // Commando + difficulty.
                SizedBox(
                  width: 300,
                  child: ListView(
                    children: [
                      PixelText(l.chooseHero, color: Pal.ink6),
                      const SizedBox(height: 4),
                      for (final h in Commando.values)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: PixelButton(
                            label: h.displayName,
                            width: double.infinity,
                            color: p.selectedHero == h.atlas
                                ? Pal.gold7
                                : Pal.ink6,
                            subtitle: p.heroes.contains(h.atlas)
                                ? switch (h) {
                                    Commando.roxy => l.heroRoxy,
                                    Commando.brutus => l.heroBrutus,
                                    Commando.nyx => l.heroNyxBio,
                                    Commando.doc => l.heroDocBio,
                                  }
                                : (h == Commando.nyx ? l.heroNyx : l.heroDoc),
                            enabled: p.heroes.contains(h.atlas),
                            onPressed: () => ref
                                .read(progressProvider.notifier)
                                .selectHero(h),
                          ),
                        ),
                      const SizedBox(height: 8),
                      PixelChoice<Difficulty>(
                        label: l.difficulty,
                        value: s.difficulty,
                        options: {
                          Difficulty.easy: l.diffEasy,
                          Difficulty.normal: l.diffNormal,
                          if (p.arcadeUnlocked) Difficulty.arcade: l.diffArcade,
                        },
                        onChanged: (d) => ref
                            .read(settingsProvider.notifier)
                            .update((x) => x.copyWith(difficulty: d)),
                      ),
                      PixelText(
                        switch (s.difficulty) {
                          Difficulty.easy => l.diffEasyHelp,
                          Difficulty.normal => l.diffNormalHelp,
                          Difficulty.arcade => l.diffArcadeHelp,
                        },
                        scale: 0.7,
                        color: Pal.ink5,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _play(CampaignEntry e, Progress p, Settings s) {
    final hero = Commando.values.firstWhere(
      (h) => h.atlas == p.selectedHero,
      orElse: () => Commando.roxy,
    );
    Navigator.of(context).push(
      PixelRoute(
        PlayScreen(
          run: RunSpec(
            mode: GameMode.campaign,
            levels: [e],
            difficulty: s.difficulty,
            hero: hero,
            arcadeCredits: 3,
          ),
        ),
      ),
    );
  }
}

class _LevelTile extends StatelessWidget {
  const _LevelTile({
    required this.entry,
    required this.record,
    required this.unlocked,
    required this.onPlay,
  });

  final CampaignEntry entry;
  final LevelRecord record;
  final bool unlocked;
  final VoidCallback onPlay;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final title = entry.boss
        ? '${l.bossStage}: ${levelName(l, entry.id, entry.name)}'
        : '${entry.world}-${entry.index}  ${levelName(l, entry.id, entry.name)}';
    final tapes = entry.boss
        ? ''
        : '  ${'*' * record.cassetteCount}${'.' * (3 - record.cassetteCount)}';
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: PixelButton(
        label: unlocked ? title : '${entry.world}-${entry.index}  ${l.locked}',
        width: double.infinity,
        color: entry.boss ? Pal.ember5 : Pal.gold6,
        subtitle: record.cleared
            ? '${l.rank} ${record.rank}   ${l.bestScore(record.bestScore)}$tapes'
            : null,
        enabled: unlocked,
        onPressed: onPlay,
      ),
    );
  }
}
