import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../core/models/run_result.dart';
import '../../core/profile_controller.dart';
import '../../core/providers.dart';
import '../../core/services/wellbeing.dart';
import '../../core/widgets/common.dart';
import '../../l10n/generated/app_localizations.dart';
import '../home/home_screen.dart';

/// Daily Challenge: same track for everyone today. Skipping a day is
/// never punished (no streaks).
class DailyScreen extends ConsumerWidget {
  const DailyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final p = ref.watch(profileProvider);
    final today = Wellbeing.dayKey(ref.watch(clockProvider)());
    final best = p.daily.date == today ? p.daily.bestScore : 0;
    final plays = p.daily.date == today ? p.daily.plays : 0;
    return MixoPage(
      title: l.daily,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Icon(
            Icons.calendar_today_rounded,
            size: 96,
            color: MixoColors.sun,
          ),
          Text(
            today,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          MixoCard(
            child: Text(
              l.dailyInfo,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18),
            ),
          ),
          const SizedBox(height: 12),
          MixoCard(
            child: Column(
              children: [
                Text(
                  l.dailyBest(best),
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  l.dailyPlays(plays),
                  style: const TextStyle(fontSize: 16, color: Colors.white70),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          BigButton(
            key: const Key('daily-play'),
            label: l.play,
            icon: Icons.play_arrow_rounded,
            onPressed: () => startMode(context, GameMode.daily),
          ),
        ],
      ),
    );
  }
}
