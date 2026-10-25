import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import '../../engine/render/palette.g.dart';
import '../../game/play_game.dart';

/// Hosts a [PlayGame], forwarding raw multi-touch to the game's controls
/// (the game converts to virtual coordinates itself).
class PlayView extends StatelessWidget {
  const PlayView({super.key, required this.game, this.overlays = const {}});

  final PlayGame game;
  final Map<String, OverlayWidgetBuilder<PlayGame>> overlays;

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: (e) =>
            game.pointerDown(e.pointer, e.localPosition * _dpr(context)),
        onPointerMove: (e) =>
            game.pointerMove(e.pointer, e.localPosition * _dpr(context)),
        onPointerUp: (e) => game.pointerUp(e.pointer),
        onPointerCancel: (e) => game.pointerUp(e.pointer),
        child: GameWidget<PlayGame>(
          game: game,
          autofocus: true,
          overlayBuilderMap: overlays,
          loadingBuilder: (_) =>
              const SizedBox.expand(child: ColoredBox(color: Pal.ink0)),
        ),
      ),
    );
  }

  /// Flame's canvas is in logical pixels, like pointer events.
  double _dpr(BuildContext context) => 1;
}
