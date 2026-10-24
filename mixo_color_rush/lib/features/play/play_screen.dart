import 'dart:async';

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../core/models/cosmetics.dart';
import '../../core/models/profile.dart';
import '../../core/models/run_result.dart';
import '../../core/profile_controller.dart';
import '../../core/progression.dart';
import '../../core/providers.dart';
import '../../core/services/feedback.dart';
import '../../core/services/wellbeing.dart';
import '../../core/widgets/color_badge.dart';
import '../../game/ai/adaptive_director.dart';
import '../../game/mixo_game.dart';
import '../../game/sim/game_simulation.dart';
import '../../l10n/generated/app_localizations.dart';
import '../academy/lessons.dart';
import 'mechanic_text.dart';
import 'results_panel.dart';
import 'run_setup.dart';
import 'swipe_detector.dart';

int _seedCounter = 0;
int freshSeed() =>
    (DateTime.now().microsecondsSinceEpoch ^ (++_seedCounter * 0x9E3779B1)) &
    0x7FFFFFFF;

/// Data shown by the results panel.
class RunOutcome {
  const RunOutcome({
    required this.result,
    required this.rewards,
    required this.bestScore,
    this.lessonStars,
    this.ghostBeaten = false,
    this.dailyBest,
  });

  final RunResult result;
  final int bestScore;
  final RunRewards rewards;
  final int? lessonStars;
  final bool ghostBeaten;
  final int? dailyBest;
}

class PlayScreen extends ConsumerStatefulWidget {
  const PlayScreen({super.key, this.mode = GameMode.free, this.lessonIndex});

  final GameMode mode;
  final int? lessonIndex;

  @override
  ConsumerState<PlayScreen> createState() => _PlayScreenState();
}

enum _Overlay {
  none,
  paused,
  intro,
  results,
  wellbeingBreak,
  limit,
  onboardingDone,
}

class _PlayScreenState extends ConsumerState<PlayScreen>
    with WidgetsBindingObserver {
  late RunSetup _setup;
  late final MixoGame _game;
  _Overlay _overlay = _Overlay.none;
  RunOutcome? _outcome;
  bool _hint = true;
  bool _praised = false;
  Timer? _hintTimer;
  Timer? _ticker;
  Timer? _introTimer;
  int _accountedMs = 0;

  ProfileController get _profile => ref.read(profileProvider.notifier);
  PlayerProfile get _p => ref.read(profileProvider);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final data = ref.read(gameDataProvider);
    _setup = _createSetup();
    final p = _p;
    ref.read(hapticsProvider).enabled = p.settings.haptics;
    _game = MixoGame(
      library: data.library,
      seed: _setup.seed,
      params: _setup.params,
      audio: ref.read(audioProvider),
      haptics: ref.read(hapticsProvider),
      look: _look(p),
      onGameOver: _onGameOver,
    );
    if (_setup.ghost != null) {
      _game.startRun(
        seed: _setup.seed,
        params: _setup.params,
        ghostReplay: _setup.ghost,
      );
    }
    _hintTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) setState(() => _hint = false);
    });
    _ticker = Timer.periodic(
      const Duration(seconds: 1),
      (_) => _checkWellbeing(),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => _afterStart());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final l = AppLocalizations.of(context);
    _game.labels = GameLabels(nearMiss: l.nearMiss, combo: l.combo);
  }

  GameLook _look(PlayerProfile p) => GameLook(
    accessory: Catalog.get(p.skin).accessory,
    trail: Catalog.get(p.trail).trail,
    palette: Catalog.paletteOf(p.theme),
    symbols: p.settings.symbolsAlways,
    reduceEffects: p.settings.reduceEffects,
  );

  RunSetup _createSetup() {
    final data = ref.read(gameDataProvider);
    return _profile.silent(
      (p) => RunSetup.create(
        widget.mode,
        p,
        data.director,
        lessonIndex: widget.lessonIndex,
        now: ref.read(clockProvider)(),
        freshSeed: freshSeed(),
      ),
    );
  }

  void _afterStart() {
    if (!mounted) return;
    if (Wellbeing.limitReached(_p, ref.read(clockProvider)())) {
      _game.pauseEngine();
      setState(() => _overlay = _Overlay.limit);
      return;
    }
    if (_setup.introducing != null) {
      _game.pauseEngine();
      setState(() => _overlay = _Overlay.intro);
      _introTimer = Timer(const Duration(seconds: 2), _endIntro);
    }
  }

  void _endIntro() {
    _introTimer?.cancel();
    if (!mounted || _overlay != _Overlay.intro) return;
    setState(() => _overlay = _Overlay.none);
    _game.resumeEngine();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _hintTimer?.cancel();
    _ticker?.cancel();
    _introTimer?.cancel();
    _accountPlay();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed &&
        _overlay == _Overlay.none &&
        !_game.sim.isOver) {
      _togglePause();
    }
  }

  /// Adds unaccounted play time to today's total and the session.
  void _accountPlay() {
    final ms = (_game.playSeconds * 1000).round() - _accountedMs;
    if (ms <= 0) return;
    _accountedMs += ms;
    ref.read(sessionProvider).addPlay(ms);
    if (widget.mode != GameMode.onboarding) {
      _profile.silent(
        (p) => Wellbeing.addPlay(p, ms, ref.read(clockProvider)()),
      );
    }
  }

  void _checkWellbeing() {
    if (!mounted || _overlay != _Overlay.none || _game.sim.isOver) return;
    _accountPlay();
    if (ref.read(sessionProvider).needsBreak) {
      _game.pauseEngine();
      setState(() => _overlay = _Overlay.wellbeingBreak);
    }
  }

  void _onGameOver(GameSimulation sim) {
    _accountPlay();
    final data = ref.read(gameDataProvider);
    final result = RunResult.fromSim(sim, _setup.mode);

    if (_setup.mode == GameMode.onboarding) {
      _profile.update((p) => p.onboardingDone = true);
      setState(() => _overlay = _Overlay.onboardingDone);
      Future<void>.delayed(const Duration(milliseconds: 1600), () {
        if (!mounted) return;
        unawaited(
          Navigator.of(context).pushReplacement(
            MaterialPageRoute<void>(builder: (_) => const PlayScreen()),
          ),
        );
      });
      return;
    }

    final outcome = _profile.update((p) {
      final rewards = Progression.applyRun(
        p,
        result,
        data.director,
        jumpEnabled: sim.params.jumpEnabled,
      );
      int? lessonStars;
      var ghostBeaten = false;
      int? dailyBest;
      switch (_setup.mode) {
        case GameMode.academy:
          lessonStars = Lessons.starsFor(
            completed: result.completed,
            heartsLeft: result.heartsLeft,
          );
          final i = _setup.lessonIndex ?? 0;
          if (lessonStars > (p.academyStars[i] ?? 0)) {
            p.academyStars[i] = lessonStars;
          }
        case GameMode.ghost:
          if (_setup.ghost != null && result.score > _setup.ghostScore) {
            ghostBeaten = true;
            p.stats.ghostWins++;
          }
          if (result.score > p.ghostScore && result.replay != null) {
            p
              ..ghostReplay = result.replay
              ..ghostScore = result.score;
          }
        case GameMode.daily:
          final today = Wellbeing.dayKey(ref.read(clockProvider)());
          if (p.daily.date != today) p.daily = DailyChallengeState(date: today);
          p.daily.plays++;
          if (result.score > p.daily.bestScore) {
            p.daily.bestScore = result.score;
          }
          dailyBest = p.daily.bestScore;
        case GameMode.free:
        case GameMode.onboarding:
          break;
      }
      final extra = Progression.checkAchievements(p);
      rewards.newAchievements.addAll(extra);
      return RunOutcome(
        result: result,
        rewards: rewards,
        bestScore: p.stats.bestScore,
        lessonStars: lessonStars,
        ghostBeaten: ghostBeaten,
        dailyBest: dailyBest,
      );
    });
    if (outcome.rewards.isRecord || outcome.ghostBeaten) {
      ref.read(audioProvider).sfx(Sfx.record);
    }
    if (outcome.rewards.newUnlocks.isNotEmpty ||
        outcome.rewards.newAchievements.isNotEmpty) {
      ref.read(audioProvider).sfx(Sfx.unlock);
    }

    // Let the dizzy face show for a moment before freezing.
    Future<void>.delayed(const Duration(milliseconds: 450), () {
      if (!mounted || _game.sim != sim) return;
      _game.pauseEngine();
      setState(() {
        _outcome = outcome;
        _overlay = _Overlay.results;
      });
    });
  }

  void _restart() {
    if (Wellbeing.limitReached(_p, ref.read(clockProvider)())) {
      setState(() => _overlay = _Overlay.limit);
      return;
    }
    if (ref.read(sessionProvider).needsBreak) {
      setState(() => _overlay = _Overlay.wellbeingBreak);
      return;
    }
    _setup = _createSetup();
    _accountedMs = 0;
    _praised = false;
    setState(() {
      _outcome = null;
      _overlay = _Overlay.none;
    });
    _game
      ..look = _look(_p)
      ..startRun(
        seed: _setup.seed,
        params: _setup.params,
        ghostReplay: _setup.ghost,
      );
    _afterStart();
  }

  void _togglePause() {
    if (_overlay == _Overlay.paused) {
      setState(() => _overlay = _Overlay.none);
      _game.resumeEngine();
    } else if (_overlay == _Overlay.none) {
      _accountPlay();
      setState(() => _overlay = _Overlay.paused);
      _game.pauseEngine();
    }
  }

  void _home() => Navigator.of(context).popUntil((r) => r.isFirst);

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final p = ref.watch(profileProvider);
    final onboarding = widget.mode == GameMode.onboarding;
    return PopScope(
      canPop: _overlay != _Overlay.none && _overlay != _Overlay.intro,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _togglePause();
      },
      child: Scaffold(
        body: Stack(
          fit: StackFit.expand,
          children: [
            SwipeDetector(
              mode: p.settings.controlMode,
              onAction: (a) {
                if (_overlay == _Overlay.none) _game.input(a);
              },
              child: GameWidget(game: _game),
            ),
            SafeArea(
              child: _Hud(
                game: _game,
                onPause: onboarding ? null : _togglePause,
                onFirstGate: onboarding && !_praised
                    ? () => setState(() => _praised = true)
                    : null,
              ),
            ),
            if (_hint && _overlay == _Overlay.none)
              IgnorePointer(
                child: Align(
                  alignment: const Alignment(0, 0.35),
                  child: _HintBubble(
                    text: onboarding
                        ? '${l.onboardingHint}\n←  ${l.swipeHint}  →'
                        : '${l.matchHint}\n←  ${l.swipeHint}  →',
                  ),
                ),
              ),
            if (onboarding && _praised && _overlay == _Overlay.none)
              const IgnorePointer(child: _PraiseBadge()),
            if (_overlay == _Overlay.intro && _setup.introducing != null)
              GestureDetector(
                onTap: _endIntro,
                child: _IntroCard(mechanic: _setup.introducing!),
              ),
            if (_overlay == _Overlay.paused)
              _PausePanel(onResume: _togglePause, onHome: _home),
            if (_overlay == _Overlay.results && _outcome != null)
              ResultsPanel(
                outcome: _outcome!,
                mode: _setup.mode,
                onAgain: _restart,
                onHome: _home,
              ),
            if (_overlay == _Overlay.wellbeingBreak)
              _WellbeingPanel(
                onContinue: () {
                  ref.read(sessionProvider).tookBreak();
                  setState(() => _overlay = _Overlay.none);
                  if (_game.sim.isOver) {
                    _restart();
                  } else {
                    _game.resumeEngine();
                  }
                },
                onBreak: _home,
              ),
            if (_overlay == _Overlay.limit) _LimitPanel(onHome: _home),
            if (_overlay == _Overlay.onboardingDone) const _BravoPanel(),
          ],
        ),
      ),
    );
  }
}

class _Hud extends StatefulWidget {
  const _Hud({required this.game, required this.onPause, this.onFirstGate});

  final MixoGame game;
  final VoidCallback? onPause;
  final VoidCallback? onFirstGate;

  @override
  State<_Hud> createState() => _HudState();
}

class _HudState extends State<_Hud> {
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return ValueListenableBuilder<HudData>(
      valueListenable: widget.game.hud,
      builder: (context, hud, _) {
        if (hud.score > 0 && widget.onFirstGate != null) {
          WidgetsBinding.instance.addPostFrameCallback(
            (_) => widget.onFirstGate?.call(),
          );
        }
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Column(
            children: [
              Row(
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
                              for (
                                var i = 0;
                                i < GameSimulation.startHearts;
                                i++
                              )
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
                          fontFeatures: [FontFeature.tabularFigures()],
                          shadows: [
                            Shadow(blurRadius: 8, color: Colors.black54),
                          ],
                        ),
                      ),
                      AnimatedOpacity(
                        opacity: hud.multiplier > 1 ? 1 : 0,
                        duration: const Duration(milliseconds: 150),
                        child: _Pill(
                          text: l.comboLabel(hud.multiplier),
                          color: MixoColors.sun,
                        ),
                      ),
                      if (hud.ghostDelta != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: _Pill(
                            text: hud.ghostDelta! > 0
                                ? l.ghostAhead(hud.ghostDelta!)
                                : l.ghostBehind(-hud.ghostDelta!),
                            color: hud.ghostDelta! > 0
                                ? Colors.white70
                                : MixoColors.mint,
                            icon: Icons.blur_on_rounded,
                          ),
                        ),
                    ],
                  ),
                  Expanded(
                    child: Align(
                      alignment: Alignment.topRight,
                      child: widget.onPause == null
                          ? const SizedBox.shrink()
                          : IconButton.filledTonal(
                              tooltip: l.pause,
                              iconSize: 32,
                              constraints: const BoxConstraints(
                                minWidth: 56,
                                minHeight: 56,
                              ),
                              onPressed: widget.onPause,
                              icon: const Icon(Icons.pause_rounded),
                            ),
                    ),
                  ),
                ],
              ),
              if (hud.progress != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: hud.progress,
                      minHeight: 10,
                      color: MixoColors.mint,
                      backgroundColor: Colors.white24,
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

class _Pill extends StatelessWidget {
  const _Pill({required this.text, required this.color, this.icon});

  final String text;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) Icon(icon, size: 18, color: MixoColors.ink),
          Text(
            text,
            style: const TextStyle(
              color: MixoColors.ink,
              fontWeight: FontWeight.w900,
              fontSize: 16,
            ),
          ),
        ],
      ),
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

class _PraiseBadge extends StatelessWidget {
  const _PraiseBadge();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: const Alignment(0, -0.45),
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.4, end: 1),
        duration: const Duration(milliseconds: 400),
        curve: Curves.elasticOut,
        builder: (context, s, child) => Transform.scale(scale: s, child: child),
        child: Text(
          AppLocalizations.of(context).bravo,
          style: const TextStyle(
            fontSize: 56,
            fontWeight: FontWeight.w900,
            color: MixoColors.sun,
            shadows: [Shadow(blurRadius: 16, color: MixoColors.candy)],
          ),
        ),
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
        child: SingleChildScrollView(
          child: Container(
            margin: const EdgeInsets.all(20),
            padding: const EdgeInsets.all(24),
            constraints: const BoxConstraints(maxWidth: 440),
            decoration: BoxDecoration(
              color: MixoColors.violet,
              borderRadius: BorderRadius.circular(32),
              border: Border.all(color: Colors.white24, width: 2),
            ),
            child: Column(mainAxisSize: MainAxisSize.min, children: children),
          ),
        ),
      ),
    );
  }
}

class _IntroCard extends StatelessWidget {
  const _IntroCard({required this.mechanic});

  final Mechanic mechanic;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return _Panel(
      children: [
        Text(
          l.newMechanic,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w900,
            color: MixoColors.sun,
          ),
        ),
        const SizedBox(height: 8),
        MechanicVisual(mechanic: mechanic),
        const SizedBox(height: 8),
        Text(
          mechanicText(l, mechanic),
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
        ),
      ],
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
            key: const Key('resume-button'),
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

class _WellbeingPanel extends StatelessWidget {
  const _WellbeingPanel({required this.onContinue, required this.onBreak});

  final VoidCallback onContinue;
  final VoidCallback onBreak;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return _Panel(
      children: [
        const Icon(
          Icons.self_improvement_rounded,
          size: 72,
          color: MixoColors.mint,
        ),
        Text(
          l.breakTitle,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 8),
        Text(
          l.breakBody,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 18),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          height: 72,
          child: FilledButton.icon(
            onPressed: onBreak,
            icon: const Icon(Icons.bedtime_rounded, size: 32),
            label: Text(l.takeBreak),
          ),
        ),
        const SizedBox(height: 12),
        TextButton(
          key: const Key('continue-after-break'),
          onPressed: onContinue,
          child: Text(l.keepPlaying, style: const TextStyle(fontSize: 18)),
        ),
      ],
    );
  }
}

class _LimitPanel extends StatelessWidget {
  const _LimitPanel({required this.onHome});

  final VoidCallback onHome;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return _Panel(
      children: [
        const Icon(Icons.nights_stay_rounded, size: 72, color: MixoColors.sun),
        Text(
          l.limitTitle,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 8),
        Text(
          l.limitBody,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 18),
        ),
        const SizedBox(height: 24),
        BigHomeButton(onPressed: onHome),
      ],
    );
  }
}

class BigHomeButton extends StatelessWidget {
  const BigHomeButton({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 72,
      child: FilledButton.icon(
        onPressed: onPressed,
        icon: const Icon(Icons.home_rounded, size: 32),
        label: Text(AppLocalizations.of(context).home),
      ),
    );
  }
}

class _BravoPanel extends StatelessWidget {
  const _BravoPanel();

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return _Panel(
      children: [
        Text(
          l.bravo,
          style: const TextStyle(
            fontSize: 56,
            fontWeight: FontWeight.w900,
            color: MixoColors.sun,
          ),
        ),
        Text(
          l.onboardingDone,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 20),
        ),
      ],
    );
  }
}
