import 'package:flutter/material.dart';

import '../../app/app.dart';
import '../../game/orbit_game.dart';
import '../game_view.dart';

/// Title + (future) attract mode. One tap anywhere starts the game.
class TitleScreen extends StatelessWidget {
  const TitleScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GestureDetector(
        key: const Key('title.tap'),
        behavior: HitTestBehavior.opaque,
        onTap: () => Navigator.of(context).pushNamed(Routes.play),
        child: const GameView(scene: StartScene.title),
      ),
    );
  }
}
