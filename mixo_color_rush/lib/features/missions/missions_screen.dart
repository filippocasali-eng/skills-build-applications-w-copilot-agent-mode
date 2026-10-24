import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../core/models/achievements.dart';
import '../../core/models/profile.dart';
import '../../core/profile_controller.dart';
import '../../core/widgets/common.dart';
import '../../game/systems/color_system.dart';
import '../../l10n/content.dart';
import '../../l10n/generated/app_localizations.dart';
import 'mission_text.dart';

/// Missions, trophies and personal statistics.
class MissionsScreen extends ConsumerWidget {
  const MissionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final p = ref.watch(profileProvider);
    return DefaultTabController(
      length: 3,
      child: MixoPage(
        title: l.missions,
        bottom: TabBar(
          labelStyle: const TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 16,
          ),
          tabs: [
            Tab(text: l.missions),
            Tab(text: l.trophies),
            Tab(text: l.stats),
          ],
        ),
        child: TabBarView(
          children: [
            _MissionsTab(profile: p),
            _TrophiesTab(profile: p),
            _StatsTab(profile: p),
          ],
        ),
      ),
    );
  }
}

class _MissionsTab extends StatelessWidget {
  const _MissionsTab({required this.profile});

  final PlayerProfile profile;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          l.missionsInfo,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white70, fontSize: 15),
        ),
        const SizedBox(height: 12),
        for (final m in profile.missions)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: MixoCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.flag_rounded,
                        color: MixoColors.mint,
                        size: 30,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          missionText(l, m),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      InfoChip(icon: Icons.star_rounded, text: '+${m.reward}'),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: m.progress / m.target,
                      minHeight: 12,
                      color: MixoColors.mint,
                      backgroundColor: Colors.white24,
                    ),
                  ),
                  Text(
                    '${m.progress} / ${m.target}',
                    style: const TextStyle(color: Colors.white70),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _TrophiesTab extends StatelessWidget {
  const _TrophiesTab({required this.profile});

  final PlayerProfile profile;

  @override
  Widget build(BuildContext context) {
    final content = ContentText(Localizations.localeOf(context).languageCode);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        for (final a in Achievement.values)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Opacity(
              opacity: profile.achievements.contains(a.name) ? 1 : 0.5,
              child: MixoCard(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Icon(
                      profile.achievements.contains(a.name)
                          ? Icons.emoji_events_rounded
                          : Icons.lock_rounded,
                      color: MixoColors.sun,
                      size: 34,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            content.achievementTitle(a),
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          Text(
                            content.achievementDesc(a),
                            style: const TextStyle(color: Colors.white70),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      '+${a.reward}★',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _StatsTab extends StatelessWidget {
  const _StatsTab({required this.profile});

  final PlayerProfile profile;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final s = profile.stats;
    String minutes(int ms) => '${ms ~/ 60000}′ ${(ms ~/ 1000) % 60}″';
    final rows = <(IconData, String, String)>[
      (Icons.emoji_events_rounded, l.statBest, '${s.bestScore}'),
      (
        Icons.bolt_rounded,
        l.statCombo,
        '${s.bestCombo} (x${s.bestMultiplier})',
      ),
      (Icons.timer_rounded, l.statLongest, minutes(s.longestRunMs)),
      (Icons.replay_rounded, l.statRuns, '${s.runs}'),
      (Icons.schedule_rounded, l.statTime, minutes(s.totalTimeMs)),
      (Icons.door_front_door_rounded, l.statGates, '${s.gates}'),
      (Icons.water_drop_rounded, l.statDrops, '${s.drops}'),
      (Icons.flash_on_rounded, l.statNearMiss, '${s.nearMisses}'),
      (Icons.palette_rounded, l.statMix, '${s.mixGates}'),
      (Icons.calendar_today_rounded, l.statDaily, '${s.dailyPlays}'),
    ];
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        for (final (icon, label, value) in rows)
          ListTile(
            leading: Icon(icon, color: MixoColors.sun),
            title: Text(label, style: const TextStyle(fontSize: 17)),
            trailing: Text(
              value,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ),
        const SizedBox(height: 8),
        Text(
          l.statColors,
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 12,
          runSpacing: 8,
          children: [
            for (final c in GameColor.values.where((c) => c != GameColor.brown))
              Chip(
                avatar: CircleAvatar(backgroundColor: Color(c.argb)),
                label: Text('${colorName(l, c)}: ${s.okByColor[c.index]}'),
              ),
          ],
        ),
      ],
    );
  }
}
