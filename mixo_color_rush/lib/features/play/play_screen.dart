import 'dart:async';

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../core/providers.dart';
import '../../core/widgets/color_badge.dart';
import '../../game/mixo_game.dart';
import '../../game/sim/difficulty.dart';
import '../../game/sim/game_simulation.dart';
import '../../l10n/generated/app_localizations.dart';
import 'session_providers.dart';
import 'swipe_detector.dart';

int _seedCounter = 0;
int _freshSeed() =>
    (DateTime.now().microsecondsSinceEpoch ^ (++_seedCounter * 0x9E3779B1)) &
    0x7FFFFFFF;

/// Snapshot of a finished run for the results panel.
class RunSummary {
  const RunSummary({
    required this.score,
    required this.durationMs,
    required this.gatesOk,
    required this.maxCombo,
    required this.isRecord,
  });

  final int score;
  final int durationMs;
  final int gatesOk;
  final int maxCombo;
  final bool isRecord;
}

class PlayScreen extends ConsumerStatefulWidget {
  const PlayScreen({super.key, this.params = const DifficultyParams()});

  final DifficultyParams params;

  @override
  ConsumerState<PlayScreen> createState() => _PlayScreenState();
}

class _PlayScreenState extends ConsumerState<PlayScreen> {
  late final MixoGame _game = MixoGame(
    library: ref.read(gameDataProvider).library,
    seed: _freshSeed(),
    params: widget.params,
    onGameOver: _onGameOver,
  );

  bool _paused = false;
  bool _hint = true;
  RunSummary? _result;
  Timer? _hintTimer;

  @override
  void initState() {
    super.initState();
    _hintTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _hint = false);
    });
  }

  @override
  void dispose() {
    _hintTimer?.cancel();
    super.dispose();
  }

  void _onGameOver(GameSimulation sim) {
    final isRecord = ref
        .read(bestScoreProvider.notifier)
        .submit(sim.score.score);
    // Let the dizzy face show for a moment before freezing.
    Future<void>.delayed(const Duration(milliseconds: 450), () {
      if (!mounted || _game.sim != sim) return;
      _game.pauseEngine();
      setState(() {
        _result = RunSummary(
          score: sim.score.score,
          durationMs: sim.elapsedMs,
          gatesOk: sim.gatesOk,
          maxCombo: sim.score.maxCombo,
          isRecord: isRecord,
        );
      });
    });
  }

  void _restart() {
    setState(() {
      _result = null;
      _paused = false;
    });
    _game.startRun(seed: _freshSeed(), params: widget.params);
  }

  void _togglePause() {
    if (_result != null) return;
    setState(() => _paused = !_paused);
    _paused ? _game.pauseEngine() : _game.resumeEngine();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return PopScope(
      canPop: _paused || _result != null,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _togglePause();
      },
      child: Scaffold(
        body: Stack(
          fit: StackFit.expand,
          children: [
            SwipeDetector(
              onAction: (a) {
                if (!_paused && _result == null) _game.input(a);
              },
              child: GameWidget(game: _game),
            ),
            SafeArea(
              child: _Hud(game: _game, onPause: _togglePause),
            ),
            if (_hint && _result == null)
              IgnorePointer(
                child: Align(
                  alignment: const Alignment(0, 0.35),
                  child: _HintBubble(
                    text: '${l.matchHint}\n←  ${l.swipeHint}  →',
                  ),
                ),
              ),
            if (_paused)
              _PausePanel(
                onResume: _togglePause,
                onHome: () => Navigator.of(context).pop(),
              ),
            if (_result != null)
              _ResultsPanel(
                result: _result!,
                best: ref.watch(bestScoreProvider),
                onAgain: _restart,
                onHome: () => Navigator.of(context).pop(),
              ),
          ],
        ),
      ),
    );
  }
}

class _Hud extends StatelessWidget {
  const _Hud({required this.game, required this.onPause});

  final MixoGame game;
  final VoidCallback onPause;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return ValueListenableBuilder<HudData>(
      valueListenable: game.hud,
      builder: (context, hud, _) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Semantics(
                      label: l.hearts(hud.hearts),
                      child: Row(
                        children: [
                          for (var i = 0; i < GameSimulation.startHearts; i++)
                            Icon(
                              i < hud.hearts
                                  ? Icons.favorite
                                  : Icons.favorite_border,
                              color: MixoColors.candy,
                              size: 30,
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    ColorBadge(color: hud.color),
                  ],
                ),
              ),
              Column(
                children: [
                  Text(
                    '${hud.score}',
                    style: const TextStyle(
                      fontSize: 40,
                      fontWeight: FontWeight.w900,
                      shadows: [Shadow(blurRadius: 8, color: Colors.black54)],
                    ),
                  ),
                  AnimatedOpacity(
                    opacity: hud.multiplier > 1 ? 1 : 0,
                    duration: const Duration(milliseconds: 150),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: MixoColors.sun,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        l.comboLabel(hud.multiplier),
                        style: const TextStyle(
                          color: MixoColors.ink,
                          fontWeight: FontWeight.w900,
                          fontSize: 18,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              Expanded(
                child: Align(
                  alignment: Alignment.topRight,
                  child: IconButton.filledTonal(
                    tooltip: l.pause,
                    iconSize: 32,
                    constraints: const BoxConstraints(
                      minWidth: 56,
                      minHeight: 56,
                    ),
                    onPressed: onPause,
                    icon: const Icon(Icons.pause_rounded),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _HintBubble extends StatelessWidget {
  const _HintBubble({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black54,
      child: Center(
        child: Container(
          margin: const EdgeInsets.all(24),
          padding: const EdgeInsets.all(24),
          constraints: const BoxConstraints(maxWidth: 420),
          decoration: BoxDecoration(
            color: MixoColors.violet,
            borderRadius: BorderRadius.circular(32),
            border: Border.all(color: Colors.white24, width: 2),
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: children),
        ),
      ),
    );
  }
}

class _PausePanel extends StatelessWidget {
  const _PausePanel({required this.onResume, required this.onHome});

  final VoidCallback onResume;
  final VoidCallback onHome;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return _Panel(
      children: [
        Text(
          l.paused,
          style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          height: 72,
          child: FilledButton.icon(
            onPressed: onResume,
            icon: const Icon(Icons.play_arrow_rounded, size: 36),
            label: Text(l.resume),
          ),
        ),
        const SizedBox(height: 12),
        TextButton.icon(
          onPressed: onHome,
          icon: const Icon(Icons.home_rounded),
          label: Text(l.home, style: const TextStyle(fontSize: 18)),
        ),
      ],
    );
  }
}

class _ResultsPanel extends StatelessWidget {
  const _ResultsPanel({
    required this.result,
    required this.best,
    required this.onAgain,
    required this.onHome,
  });

  final RunSummary result;
  final int best;
  final VoidCallback onAgain;
  final VoidCallback onHome;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return _Panel(
      children: [
        if (result.isRecord)
          Text(
            l.newRecord,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: MixoColors.sun,
            ),
          ),
        Text(l.score, style: const TextStyle(fontSize: 20)),
        Text(
          '${result.score}',
          key: const Key('results-score'),
          style: const TextStyle(fontSize: 56, fontWeight: FontWeight.w900),
        ),
        Text(l.best(best), style: const TextStyle(fontSize: 18)),
        const SizedBox(height: 12),
        Wrap(
          spacing: 16,
          alignment: WrapAlignment.center,
          children: [
            _Stat(
              icon: Icons.timer_rounded,
              text: l.timeLabel(result.durationMs ~/ 1000),
            ),
            _Stat(
              icon: Icons.door_front_door_rounded,
              text: l.gatesLabel(result.gatesOk),
            ),
            _Stat(icon: Icons.bolt_rounded, text: '${result.maxCombo}'),
          ],
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          height: 80,
          child: FilledButton.icon(
            key: const Key('again-button'),
            onPressed: onAgain,
            icon: const Icon(Icons.replay_rounded, size: 36),
            label: Text(l.again, style: const TextStyle(fontSize: 30)),
          ),
        ),
        const SizedBox(height: 12),
        TextButton.icon(
          onPressed: onHome,
          icon: const Icon(Icons.home_rounded),
          label: Text(l.home, style: const TextStyle(fontSize: 18)),
        ),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 20, color: Colors.white70),
        const SizedBox(width: 4),
        Text(text, style: const TextStyle(fontSize: 18)),
      ],
    );
  }
}
