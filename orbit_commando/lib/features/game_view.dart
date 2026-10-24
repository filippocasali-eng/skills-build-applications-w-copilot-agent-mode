import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import '../engine/render/palette.g.dart';
import '../game/game_strings.dart';
import '../game/orbit_game.dart';
import '../l10n/app_localizations.dart';

/// Hosts an [OrbitGame] and keeps it alive across rebuilds.
class GameView extends StatefulWidget {
  const GameView({super.key, required this.scene});

  final StartScene scene;

  @override
  State<GameView> createState() => _GameViewState();
}

class _GameViewState extends State<GameView> {
  OrbitGame? _game;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final l = AppLocalizations.of(context);
    _game ??= OrbitGame(
      startScene: widget.scene,
      strings: GameStrings(
        title: l.appTitle,
        pressStart: l.pressStart,
        credits: l.creditsLabel(3),
        sandbox: l.sandboxLabel,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Always fill the parent: while loading, an unsized child would collapse
    // to 0x0 and swallow taps meant for the screen.
    return SizedBox.expand(
      child: GameWidget(
        game: _game!,
        loadingBuilder: (_) =>
            const SizedBox.expand(child: ColoredBox(color: Pal.ink0)),
      ),
    );
  }
}
