import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/ui/pixel.dart';
import '../../core/audio/audio.dart';
import '../../core/meta/workshop.dart';
import '../../core/monetization/catalog.dart';
import '../../core/monetization/remote_config.dart';
import '../../core/monetization/store.dart';
import '../../core/monetization/wallet.dart';
import '../../core/progress/progress.dart';
import '../../engine/render/palette.g.dart';
import '../../l10n/app_localizations.dart';

/// Workshop: power upgrades for tokens or Quasar gems.
class WorkshopScreen extends ConsumerWidget {
  const WorkshopScreen({super.key});

  String _name(AppLocalizations l, String id) => switch (id) {
    'damage' => l.upDamage,
    'hp' => l.upHp,
    'shield' => l.upShield,
    'fireRate' => l.upFireRate,
    _ => l.upGrenades,
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final p = ref.watch(progressProvider);
    final w = ref.watch(walletProvider);
    final rc = ref.watch(remoteConfigProvider).value;
    return PixelScreen(
      title: l.menuWorkshop,
      trailing: Row(
        children: [
          PixelText(l.tokens(p.tokens), color: Pal.gold6),
          const SizedBox(width: 10),
          PixelText('${l.gems} ${w.gems}', color: Pal.neon6),
        ],
      ),
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          PixelText(l.arcadeNoUpgrades, scale: 0.7, color: Pal.ink5),
          const SizedBox(height: 6),
          for (final u in Workshop.upgrades)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: PixelPanel(
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          PixelText(
                            _name(l, u.id),
                            scale: 1.2,
                            color: Pal.gold6,
                          ),
                          Row(
                            children: [
                              for (var i = 0; i < u.maxLevel; i++)
                                Container(
                                  width: 22,
                                  height: 10,
                                  margin: const EdgeInsets.only(
                                    right: 3,
                                    top: 4,
                                  ),
                                  color: i < (p.upgrades[u.id] ?? 0)
                                      ? Pal.moss5
                                      : Pal.ink2,
                                ),
                              const SizedBox(width: 8),
                              PixelText(
                                l.upLevel(p.upgrades[u.id] ?? 0, u.maxLevel),
                                scale: 0.8,
                              ),
                              const SizedBox(width: 8),
                              PixelText(
                                '${w.inventory['frag_${u.id}'] ?? 0}/10 frag',
                                scale: 0.6,
                                color: Pal.ink5,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    if ((p.upgrades[u.id] ?? 0) >= u.maxLevel)
                      PixelText(l.maxed, color: Pal.moss6)
                    else ...[
                      PixelButton(
                        label: l.buyTokens(u.tokenCosts[p.upgrades[u.id] ?? 0]),
                        enabled:
                            p.tokens >= u.tokenCosts[p.upgrades[u.id] ?? 0],
                        onPressed: () async {
                          final lv = p.upgrades[u.id] ?? 0;
                          await ref
                              .read(progressProvider.notifier)
                              .set(
                                (x) => x.copyWith(
                                  tokens: x.tokens - u.tokenCosts[lv],
                                  upgrades: {...x.upgrades, u.id: lv + 1},
                                ),
                              );
                          ref.read(audioProvider).sfx(Sfx.coin);
                          await _trophies(ref);
                        },
                      ),
                      const SizedBox(width: 6),
                      PixelButton(
                        label:
                            '${l.buyGems(u.gemCosts[p.upgrades[u.id] ?? 0])}${rc == null ? '' : ' (${Catalog.money(rc.gemsToCents(u.gemCosts[p.upgrades[u.id] ?? 0]))})'}',
                        color: Pal.neon6,
                        enabled: w.gems >= u.gemCosts[p.upgrades[u.id] ?? 0],
                        onPressed: () async {
                          if (await ref
                              .read(storeProvider.notifier)
                              .buyUpgradeWithGems(u.id)) {
                            ref.read(audioProvider).sfx(Sfx.coin);
                            await _trophies(ref);
                          }
                        },
                      ),
                    ],
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _trophies(WidgetRef ref) async {
    final n = ref.read(progressProvider.notifier);
    await n.unlockTrophy('upgrade_1');
    if (ref.read(progressProvider).upgrades.values.any((v) => v >= 5)) {
      await n.unlockTrophy('upgrade_max');
    }
  }
}
