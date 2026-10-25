import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/ui/pixel.dart';
import '../../core/progress/progress.dart';
import '../../core/progress/trophies.dart';
import '../../engine/render/palette.g.dart';
import '../../l10n/app_localizations.dart';

/// Trophies and local high scores.
class TrophiesScreen extends ConsumerWidget {
  const TrophiesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final p = ref.watch(progressProvider);
    final lang = Localizations.localeOf(context).languageCode;
    return PixelScreen(
      title: l.menuTrophies,
      trailing: PixelText(
        l.trophiesCount(p.trophies.length, Trophies.all.length),
        color: Pal.gold6,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                for (final t in Trophies.all)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      children: [
                        PixelText(
                          p.trophies.contains(t.id) ? '*' : '-',
                          color: p.trophies.contains(t.id)
                              ? Pal.gold6
                              : Pal.ink4,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              PixelText(
                                t.title(lang),
                                color: p.trophies.contains(t.id)
                                    ? Pal.gold6
                                    : Pal.ink5,
                              ),
                              PixelText(
                                t.desc(lang),
                                scale: 0.7,
                                color: Pal.ink5,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          SizedBox(
            width: 300,
            child: ListView(
              children: [
                for (final mode in const ['arcade', 'bossrush']) ...[
                  PixelText(
                    mode == 'arcade' ? l.menuArcade : l.menuBossRush,
                    color: Pal.aqua6,
                  ),
                  for (final (i, h) in p.scoresFor(mode).take(10).indexed)
                    PixelText(
                      '${i + 1}. ${h.initials}  ${h.score}',
                      scale: 0.9,
                      color: i == 0 ? Pal.gold6 : Pal.ink6,
                    ),
                  const SizedBox(height: 10),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
