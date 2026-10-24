import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../core/widgets/mixo_avatar.dart';
import '../../l10n/generated/app_localizations.dart';
import '../play/play_screen.dart';
import '../play/session_providers.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final best = ref.watch(bestScoreProvider);
    return Scaffold(
      body: DecoratedBox(
        decoration: mixoBackground,
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'MIXO',
                    style: TextStyle(
                      fontSize: 64,
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
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 8,
                    ),
                  ),
                  const SizedBox(height: 24),
                  const MixoAvatar(size: 200),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: 280,
                    height: 96,
                    child: FilledButton.icon(
                      key: const Key('play-button'),
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const PlayScreen(),
                        ),
                      ),
                      icon: const Icon(Icons.play_arrow_rounded, size: 48),
                      label: Text(l.play, style: const TextStyle(fontSize: 36)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (best > 0)
                    Text(l.best(best), style: const TextStyle(fontSize: 20)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
