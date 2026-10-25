import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
import '../campaign_map/campaign_map.dart';
import '../chat/chat_screen.dart';
import '../gallery/gallery_screen.dart';
import '../jukebox/jukebox_screen.dart';
import '../play/play_screen.dart';
import '../run/run.dart';
import '../settings/settings_screen.dart';
import '../shop/shop_screen.dart';
import '../trophies/trophies_screen.dart';
import '../workshop/workshop_screen.dart';

/// Arcade-style main menu.
class MainMenu extends ConsumerWidget {
  const MainMenu({super.key});

  void _go(BuildContext context, Widget page) =>
      Navigator.of(context).push(PixelRoute(page));

  Future<void> _startRun(
    BuildContext context,
    WidgetRef ref,
    GameMode mode,
  ) async {
    final campaign = await ref.read(campaignProvider.future);
    if (!context.mounted) return;
    final progress = ref.read(progressProvider);
    final settings = ref.read(settingsProvider);
    final hero = Commando.values.firstWhere(
      (h) => h.atlas == progress.selectedHero,
      orElse: () => Commando.roxy,
    );
    final week = Weekly.weekIndex(DateTime.now());
    final run = switch (mode) {
      GameMode.arcade => RunSpec(
        mode: mode,
        levels: campaign.entries,
        difficulty: Difficulty.arcade,
        hero: hero,
        arcadeCredits: 3,
      ),
      GameMode.bossRush => RunSpec(
        mode: mode,
        levels: campaign.bosses,
        difficulty: settings.difficulty == Difficulty.easy
            ? Difficulty.normal
            : settings.difficulty,
        hero: hero,
      ),
      _ => RunSpec(
        mode: GameMode.weekly,
        levels: [Weekly.level(campaign, week)],
        difficulty: Difficulty.normal,
        hero: hero,
        weekly: Weekly.modifier(week),
        week: week,
      ),
    };
    _go(context, PlayScreen(run: run));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final p = ref.watch(progressProvider);
    final w = ref.watch(walletProvider);
    final week = Weekly.weekIndex(DateTime.now());
    final mod = Weekly.modifier(week);
    return PixelScreen(
      title: l.appTitle,
      onBack: () => Navigator.of(context).pop(),
      trailing: Row(
        children: [
          PixelText(l.pilotRank(p.pilotRank), scale: 0.8, color: Pal.aqua6),
          const SizedBox(width: 10),
          PixelText(l.tokens(p.tokens), scale: 0.8, color: Pal.gold6),
          const SizedBox(width: 10),
          PixelText('${l.gems} ${w.gems}', scale: 0.8, color: Pal.neon6),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ListView(
                children: [
                  PixelButton(
                    label: l.menuCampaign,
                    autofocus: true,
                    scale: 1.6,
                    width: double.infinity,
                    onPressed: () => _go(context, const CampaignMap()),
                  ),
                  const SizedBox(height: 6),
                  PixelButton(
                    label: l.menuArcade,
                    scale: 1.2,
                    width: double.infinity,
                    subtitle: p.arcadeUnlocked
                        ? l.creditsLabel(3)
                        : l.unlockArcade,
                    enabled: p.arcadeUnlocked,
                    onPressed: () => _startRun(context, ref, GameMode.arcade),
                  ),
                  const SizedBox(height: 6),
                  PixelButton(
                    label: l.menuBossRush,
                    scale: 1.2,
                    width: double.infinity,
                    subtitle: p.bossRushUnlocked
                        ? (w.fullCartridge ? null : l.shopCartridge)
                        : l.unlockBossRush,
                    enabled: p.bossRushUnlocked && w.fullCartridge,
                    onPressed: () => _startRun(context, ref, GameMode.bossRush),
                  ),
                  const SizedBox(height: 6),
                  PixelButton(
                    label: l.menuWeekly,
                    scale: 1.2,
                    width: double.infinity,
                    subtitle: '#$week  ${_modName(mod)}',
                    onPressed: () => _startRun(context, ref, GameMode.weekly),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            SizedBox(
              width: 300,
              child: ListView(
                children: [
                  for (final (label, page) in [
                    (l.menuShop, const ShopScreen() as Widget),
                    (l.menuWorkshop, const WorkshopScreen()),
                    (l.menuGallery, const GalleryScreen()),
                    (l.menuJukebox, const JukeboxScreen()),
                    (l.menuTrophies, const TrophiesScreen()),
                    (l.menuChat, const ChatScreen()),
                    (l.menuSettings, const SettingsScreen()),
                  ]) ...[
                    PixelButton(
                      label: label,
                      width: double.infinity,
                      onPressed: () => _go(context, page),
                    ),
                    const SizedBox(height: 4),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _modName(WeeklyModifier m) => switch (m) {
    WeeklyModifier.flameOnly => 'FLAME ONLY',
    WeeklyModifier.ricochetOnly => 'RICOCHET ONLY',
    WeeklyModifier.heavyGravity => 'GRAVITY x1.6',
    WeeklyModifier.lowGravity => 'LOW GRAVITY',
  };
}
