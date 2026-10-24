import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../core/models/run_result.dart';
import '../../core/profile_controller.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/mixo_avatar.dart';
import '../../l10n/generated/app_localizations.dart';
import '../home/home_screen.dart';

/// Ghost Challenge: race against the replay of your best run on a fixed
/// track (foundation of the future asynchronous multiplayer).
class GhostScreen extends ConsumerWidget {
  const GhostScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final p = ref.watch(profileProvider);
    final hasGhost = p.ghostReplay != null;
    return MixoPage(
      title: l.ghost,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Opacity(
            opacity: 0.55,
            child: Center(child: MixoAvatar(size: 160, cycleColors: false)),
          ),
          MixoCard(
            child: Text(
              l.ghostInfo,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18),
            ),
          ),
          const SizedBox(height: 12),
          MixoCard(
            child: Text(
              hasGhost ? l.ghostBest(p.ghostScore) : l.ghostNone,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w900,
                color: MixoColors.sun,
              ),
            ),
          ),
          const SizedBox(height: 24),
          BigButton(
            key: const Key('ghost-play'),
            label: l.play,
            icon: Icons.play_arrow_rounded,
            onPressed: () => startMode(context, GameMode.ghost),
          ),
        ],
      ),
    );
  }
}
