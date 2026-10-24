import 'package:flutter/material.dart';

import '../../game/orbit_game.dart';
import '../../l10n/app_localizations.dart';
import '../game_view.dart';

/// Gameplay host. In M1 it shows the render-pipeline sandbox.
class PlayScreen extends StatelessWidget {
  const PlayScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          const Positioned.fill(child: GameView(scene: StartScene.sandbox)),
          Positioned(
            right: 8,
            top: 8,
            child: SafeArea(
              child: IconButton(
                key: const Key('play.back'),
                tooltip: AppLocalizations.of(context).back,
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).maybePop(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
