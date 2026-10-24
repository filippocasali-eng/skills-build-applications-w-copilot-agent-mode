import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../core/models/cosmetics.dart';
import '../../core/models/profile.dart';
import '../../core/models/run_result.dart';
import '../../core/profile_controller.dart';
import '../../core/progression.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/mixo_avatar.dart';
import '../../l10n/content.dart';
import '../../l10n/generated/app_localizations.dart';
import '../academy/academy_screen.dart';
import '../academy/lessons.dart';
import '../collection/collection_screen.dart';
import '../daily/daily_screen.dart';
import '../ghost/ghost_screen.dart';
import '../missions/missions_screen.dart';
import '../parental_gate/parental_gate.dart';
import '../play/play_screen.dart';
import '../settings/settings_screen.dart';
import '../shop/shop_screen.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  void _open(BuildContext context, Widget page) =>
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final p = ref.watch(profileProvider);
    final content = ContentText(Localizations.localeOf(context).languageCode);
    final unlockedModes = Lessons.mandatoryDone(p.academyStars);
    final missionsDone = p.missions.where((m) => m.done).length;
    final academyStars = p.academyStars.values.fold(0, (a, b) => a + b);

    void lockedInfo() =>
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(l.lockedAcademyFirst)));

    return Scaffold(
      body: DecoratedBox(
        decoration: mixoBackground,
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, box) {
              final avatar = math.min(190.0, box.maxHeight * 0.24);
              return SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: box.maxHeight - 16),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              borderRadius: BorderRadius.circular(20),
                              onTap: () => _rename(context, ref),
                              child: Padding(
                                padding: const EdgeInsets.all(4),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      content.nickname(p.nickname),
                                      key: const Key('nickname'),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    _LevelBar(profile: p),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          InfoChip(
                            icon: Icons.star_rounded,
                            text: '${p.stars}',
                          ),
                          IconButton(
                            key: const Key('settings-button'),
                            tooltip: l.settings,
                            iconSize: 32,
                            constraints: const BoxConstraints(
                              minWidth: 56,
                              minHeight: 56,
                            ),
                            onPressed: () =>
                                _open(context, const SettingsScreen()),
                            icon: const Icon(Icons.settings_rounded),
                          ),
                        ],
                      ),
                      Column(
                        children: [
                          const Text(
                            'MIXO',
                            style: TextStyle(
                              fontSize: 52,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 6,
                              color: MixoColors.sun,
                              shadows: [
                                Shadow(blurRadius: 16, color: MixoColors.candy),
                              ],
                            ),
                          ),
                          const Text(
                            'COLOR RUSH',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 8,
                            ),
                          ),
                          GestureDetector(
                            onTap: () =>
                                _open(context, const CollectionScreen()),
                            child: MixoAvatar(
                              size: avatar,
                              accessory: Catalog.get(p.skin).accessory,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(
                        width: double.infinity,
                        height: 96,
                        child: FilledButton.icon(
                          key: const Key('play-button'),
                          onPressed: () => _open(context, const PlayScreen()),
                          icon: const Icon(Icons.play_arrow_rounded, size: 52),
                          label: Text(
                            l.play,
                            style: const TextStyle(
                              fontSize: 40,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      GridView.count(
                        crossAxisCount: 3,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        mainAxisSpacing: 10,
                        crossAxisSpacing: 10,
                        childAspectRatio: 1.05,
                        children: [
                          MenuTile(
                            key: const Key('tile-daily'),
                            icon: Icons.calendar_today_rounded,
                            label: l.daily,
                            color: const Color(0xFFE65100),
                            locked: !unlockedModes,
                            onTap: unlockedModes
                                ? () => _open(context, const DailyScreen())
                                : lockedInfo,
                          ),
                          MenuTile(
                            key: const Key('tile-academy'),
                            icon: Icons.school_rounded,
                            label: l.academy,
                            subtitle: '$academyStars/24 ★',
                            color: const Color(0xFF00897B),
                            onTap: () => _open(context, const AcademyScreen()),
                          ),
                          MenuTile(
                            key: const Key('tile-ghost'),
                            icon: Icons.blur_on_rounded,
                            label: l.ghost,
                            color: const Color(0xFF5C6BC0),
                            locked: !unlockedModes,
                            onTap: unlockedModes
                                ? () => _open(context, const GhostScreen())
                                : lockedInfo,
                          ),
                          MenuTile(
                            key: const Key('tile-collection'),
                            icon: Icons.palette_rounded,
                            label: l.collection,
                            color: const Color(0xFFD81B60),
                            onTap: () =>
                                _open(context, const CollectionScreen()),
                          ),
                          MenuTile(
                            key: const Key('tile-missions'),
                            icon: Icons.flag_rounded,
                            label: l.missions,
                            color: const Color(0xFF43A047),
                            badge: missionsDone > 0 ? '$missionsDone' : null,
                            onTap: () => _open(context, const MissionsScreen()),
                          ),
                          MenuTile(
                            key: const Key('tile-shop'),
                            icon: Icons.shopping_bag_rounded,
                            label: l.shop,
                            color: const Color(0xFF6D4C41),
                            onTap: () async {
                              if (await showParentalGate(context) &&
                                  context.mounted) {
                                _open(context, const ShopScreen());
                              }
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Future<void> _rename(BuildContext context, WidgetRef ref) async {
    final l = AppLocalizations.of(context);
    final content = ContentText(Localizations.localeOf(context).languageCode);
    final rng = math.Random();
    final options = [
      for (var i = 0; i < 4; i++)
        Nickname(
          rng.nextInt(Nickname.animals),
          rng.nextInt(Nickname.adjectives),
          10 + rng.nextInt(90),
        ),
    ];
    final picked = await showModalBottomSheet<Nickname>(
      context: context,
      backgroundColor: MixoColors.violet,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                l.pickName,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              for (final n in options)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: FilledButton.tonal(
                      onPressed: () => Navigator.of(context).pop(n),
                      child: Text(
                        content.nickname(n),
                        style: const TextStyle(fontSize: 20),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
    if (picked != null) {
      ref.read(profileProvider.notifier).update((p) => p.nickname = picked);
    }
  }
}

class _LevelBar extends StatelessWidget {
  const _LevelBar({required this.profile});

  final PlayerProfile profile;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Row(
      children: [
        Text(
          l.levelShort(profile.level),
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            color: MixoColors.mint,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: profile.xp / Progression.xpToNext(profile.level),
              minHeight: 8,
              color: MixoColors.mint,
              backgroundColor: Colors.white24,
            ),
          ),
        ),
      ],
    );
  }
}

/// Re-export so other screens can start a mode easily.
void startMode(BuildContext context, GameMode mode, {int? lesson}) =>
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PlayScreen(mode: mode, lessonIndex: lesson),
      ),
    );
