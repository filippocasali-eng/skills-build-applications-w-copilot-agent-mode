import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/ui/atlas_sprite.dart';
import '../../app/ui/pixel.dart';
import '../../core/monetization/wallet.dart';
import '../../core/progress/progress.dart';
import '../../engine/render/palette.g.dart';
import '../../l10n/app_localizations.dart';

/// A collectible "trading card" in the gallery.
class Card90s {
  const Card90s(this.atlas, this.name, this.anim, this.cassettesNeeded);

  final String atlas, name, anim;
  final int cassettesNeeded;
}

/// Gallery of memorabilia: figurine cards unlocked with cassettes, plus
/// stickers and cosmetics from capsules.
class GalleryScreen extends ConsumerWidget {
  const GalleryScreen({super.key});

  static const cards = [
    Card90s('roxy', 'ROXY', 'run', 0),
    Card90s('brutus', 'BRUTUS', 'attack', 0),
    Card90s('grunt', 'GRUNT', 'run', 2),
    Card90s('clerk', 'GLORBO CLERK', 'run', 4),
    Card90s('drone', 'FAN DRONE', 'run', 6),
    Card90s('turret', 'CRAWL TURRET', 'run', 8),
    Card90s('roller', 'ROLLER', 'run', 10),
    Card90s('rocket', 'ROCKET', 'attack', 12),
    Card90s('sniper', 'SNIPER', 'tell', 14),
    Card90s('jelly', 'SPACE JELLY', 'run', 16),
    Card90s('swarm', 'SWARM BUG', 'run', 18),
    Card90s('minimech', 'MINI-MECH', 'run', 20),
    Card90s('cyclops', 'CYCLOPS', 'attack', 22),
    Card90s('bulwark', 'BULWARK', 'attack', 24),
    Card90s('nyx', 'NYX', 'run', 26),
    Card90s('doc', 'DOC', 'attack', 28),
    Card90s('mech', 'SPRING MECH', 'run', 30),
    Card90s('bike', 'ROCKET BIKE', 'run', 32),
    Card90s('shuttle', 'SHUTTLE', 'idle', 34),
    Card90s('stamper_body', 'SUPREME STAMPER', 'idle', 36),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final p = ref.watch(progressProvider);
    final w = ref.watch(walletProvider);
    final tapes = p.totalCassettes;
    return PixelScreen(
      title: l.menuGallery,
      trailing: PixelText(l.cassettesFound(tapes, 36), color: Pal.neon6),
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final c in cards)
                SizedBox(
                  width: 150,
                  child: PixelPanel(
                    padding: const EdgeInsets.all(6),
                    border: tapes >= c.cassettesNeeded ? Pal.gold5 : Pal.ink3,
                    child: Column(
                      children: [
                        SizedBox(
                          height: 110,
                          child: Center(
                            child: FittedBox(
                              child: AtlasSprite(
                                c.atlas,
                                anim: c.anim,
                                scale: 1.4,
                                silhouette: tapes < c.cassettesNeeded,
                              ),
                            ),
                          ),
                        ),
                        PixelText(
                          tapes >= c.cassettesNeeded ? c.name : '???',
                          scale: 0.7,
                          color: Pal.gold6,
                          align: TextAlign.center,
                        ),
                        if (tapes < c.cassettesNeeded)
                          PixelText(
                            '${c.cassettesNeeded} TAPES',
                            scale: 0.6,
                            color: Pal.ink5,
                          ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          PixelText(l.capsules, color: Pal.aqua6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final id in w.owned.where(
                (o) =>
                    o.startsWith('sticker_') ||
                    o.startsWith('skin_') ||
                    o.startsWith('crt_') ||
                    o.startsWith('weapon_'),
              ))
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Pal.ink1,
                    border: Border.all(color: Pal.neon4, width: 2),
                  ),
                  child: PixelText(
                    id.replaceAll('_', ' ').toUpperCase(),
                    scale: 0.7,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
