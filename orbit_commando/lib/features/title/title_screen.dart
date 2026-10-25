import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/ui/pixel.dart';
import '../../app/ui/route.dart';
import '../../core/audio/audio.dart';
import '../../core/campaign.dart';
import '../../core/progress/progress.dart';
import '../../core/settings/settings.dart';
import '../../engine/render/palette.g.dart';
import '../../game/input/input_source.dart';
import '../../game/play_config.dart';
import '../../game/play_game.dart';
import '../../game/roster.dart';
import '../../game/sim/balance.dart';
import '../../l10n/app_localizations.dart';
import '../cheats/cheats.dart';
import '../menu/main_menu.dart';
import '../play/play_view.dart';

/// Title + attract mode: the bot plays demo levels behind the logo, the
/// high-score table cycles in, and secret codes are listened for.
class TitleScreen extends ConsumerStatefulWidget {
  const TitleScreen({super.key});

  @override
  ConsumerState<TitleScreen> createState() => _TitleScreenState();
}

class _TitleScreenState extends ConsumerState<TitleScreen> {
  static const _demoLevels = ['w1_l2', 'w3_l1', 'w2_l1', 'w2_l3', 'w1_l3'];
  PlayGame? _demo;
  int _demoIndex = 0;
  bool _showScores = false;
  Timer? _cycle;
  final CheatDetector _cheats = CheatDetector();
  String? _cheatMessage;

  @override
  void initState() {
    super.initState();
    _startDemo();
    ref.read(audioProvider).music(Track.title);
    _cycle = Timer.periodic(const Duration(seconds: 22), (_) {
      if (!mounted) return;
      setState(() => _showScores = !_showScores);
      if (!_showScores) _startDemo();
    });
  }

  @override
  void dispose() {
    _cycle?.cancel();
    super.dispose();
  }

  Future<void> _startDemo() async {
    final campaign = await ref.read(campaignProvider.future);
    if (!mounted) return;
    final entry = campaign.byId(_demoLevels[_demoIndex++ % _demoLevels.length]);
    final level = await Campaign.loadLevel(
      DefaultAssetBundle.of(context),
      entry,
    );
    if (!mounted) return;
    final settings = ref.read(settingsProvider);
    setState(() {
      _demo = PlayGame(
        config: PlayConfig(
          level: level,
          levelNumber: 9,
          difficulty: Difficulty.easy,
          hero: Commando.values[_demoIndex % Commando.values.length],
          rotatingCamera: settings.rotatingCamera,
          showTouchControls: false,
          seed: _demoIndex,
        ),
        input: AutoPilot(),
      );
    });
  }

  void _start() {
    ref.read(audioProvider).jingle(Jingle.oneUp);
    Navigator.of(context).push(PixelRoute(const MainMenu())).then((_) {
      if (mounted) ref.read(audioProvider).music(Track.title);
    });
  }

  Future<void> _dir(Dir d) async {
    ref.read(audioProvider).sfx(Sfx.select);
    final cheat = _cheats.feed(d);
    if (cheat == null) return;
    final l = AppLocalizations.of(context);
    ref.read(audioProvider).sfx(Sfx.yeah);
    await ref.read(progressProvider.notifier).set((p) {
      final c = {...p.cheats};
      // Codes toggle on and off.
      if (!c.remove(cheat.name)) c.add(cheat.name);
      return p.copyWith(cheats: c);
    });
    await ref.read(progressProvider.notifier).unlockTrophy('cheat');
    setState(() {
      _cheatMessage = switch (cheat) {
        Cheat.bigHeads => l.cheatBigHeads,
        Cheat.giantPixels => l.cheatGiantPixels,
        Cheat.brokenTube => l.cheatBrokenTube,
      };
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final progress = ref.watch(progressProvider);
    return Scaffold(
      backgroundColor: Pal.ink0,
      body: KeyboardListener(
        focusNode: FocusNode()..requestFocus(),
        onKeyEvent: (e) {
          if (e is! KeyDownEvent) return;
          final k = e.logicalKey;
          if (k == LogicalKeyboardKey.arrowUp) _dir(Dir.up);
          if (k == LogicalKeyboardKey.arrowDown) _dir(Dir.down);
          if (k == LogicalKeyboardKey.arrowLeft) _dir(Dir.left);
          if (k == LogicalKeyboardKey.arrowRight) _dir(Dir.right);
          if (k == LogicalKeyboardKey.enter ||
              k == LogicalKeyboardKey.gameButtonStart ||
              k == LogicalKeyboardKey.gameButtonA) {
            _start();
          }
        },
        child: GestureDetector(
          key: const Key('title.tap'),
          behavior: HitTestBehavior.opaque,
          onTap: _start,
          onPanEnd: (d) {
            final v = d.velocity.pixelsPerSecond;
            if (v.distance < 200) return;
            if (v.dx.abs() > v.dy.abs()) {
              _dir(v.dx > 0 ? Dir.right : Dir.left);
            } else {
              _dir(v.dy > 0 ? Dir.down : Dir.up);
            }
          },
          child: Stack(
            children: [
              if (_demo != null && !_showScores)
                Positioned.fill(
                  child: IgnorePointer(
                    child: PlayView(key: ValueKey(_demo), game: _demo!),
                  ),
                ),
              if (_showScores)
                Positioned.fill(child: _ScoreTable(progress: progress)),
              Positioned.fill(
                child: SafeArea(
                  child: Column(
                    children: [
                      const SizedBox(height: 18),
                      const _Logo(),
                      const Spacer(),
                      Blink(
                        child: PixelText(
                          progress.credits > 0 ? l.pressStart : l.insertCoin,
                          scale: 2,
                          color: Pal.ink7,
                        ),
                      ),
                      const SizedBox(height: 6),
                      PixelText(
                        l.creditsLabel(progress.credits),
                        color: Pal.gold6,
                      ),
                      if (_cheatMessage != null)
                        PixelText(_cheatMessage!, color: Pal.neon6, scale: 1.2),
                      const SizedBox(height: 4),
                      PixelText(l.copyright, scale: 0.7, color: Pal.ink5),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ),
              const Scanlines(),
            ],
          ),
        ),
      ),
    );
  }
}

class _Logo extends StatefulWidget {
  const _Logo();

  @override
  State<_Logo> createState() => _LogoState();
}

class _LogoState extends State<_Logo> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 3),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _c,
    builder: (_, _) {
      final wobble = math.sin(_c.value * math.pi * 2) * 3;
      return Transform.translate(
        offset: Offset(0, wobble.roundToDouble()),
        child: Column(
          children: [
            const PixelText(
              'ORBIT',
              scale: 5,
              color: Pal.gold6,
              shadow: Pal.ember2,
            ),
            Transform.translate(
              offset: const Offset(0, -8),
              child: const PixelText(
                "COMMANDO '94",
                scale: 3,
                color: Pal.ember5,
                shadow: Pal.ink0,
              ),
            ),
          ],
        ),
      );
    },
  );
}

class _ScoreTable extends StatelessWidget {
  const _ScoreTable({required this.progress});

  final Progress progress;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final scores = progress.scoresFor('arcade');
    return ColoredBox(
      color: Pal.space0,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 120),
            PixelText(l.menuScores, scale: 1.6, color: Pal.aqua6),
            const SizedBox(height: 8),
            for (var i = 0; i < 5; i++)
              PixelText(
                i < scores.length
                    ? '${i + 1}. ${scores[i].initials}  ${scores[i].score.toString().padLeft(8)}'
                    : '${i + 1}. ---  ${'0'.padLeft(8)}',
                scale: 1.2,
                color: i == 0 ? Pal.gold6 : Pal.ink6,
              ),
          ],
        ),
      ),
    );
  }
}
