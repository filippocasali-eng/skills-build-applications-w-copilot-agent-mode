import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/level_names.dart';
import '../../app/ui/pixel.dart';
import '../../core/ads/ad_provider.dart';
import '../../core/analytics/analytics.dart';
import '../../core/audio/audio.dart';
import '../../core/campaign.dart';
import '../../core/meta/workshop.dart';
import '../../core/monetization/wallet.dart';
import '../../core/multiplayer/multiplayer.dart';
import '../../core/progress/progress.dart';
import '../../core/settings/settings.dart';
import '../../engine/render/palette.g.dart';
import '../../engine/render/pixel_renderer.dart';
import '../../engine/replay/replay.dart';
import '../../app/ui/route.dart';
import '../../game/controls_config.dart';
import '../../game/input/input_source.dart';
import '../../game/levels/level_data.dart';
import '../../game/play_config.dart';
import '../../game/play_game.dart';
import '../../game/sim/balance.dart';
import '../../game/sim/events.dart';
import '../../game/sim/game_sim.dart';
import '../../l10n/app_localizations.dart';
import '../results/results_screen.dart';
import '../run/run.dart';
import 'play_view.dart';

/// Plays the current level of a [RunSpec] and handles pause, continue,
/// the dynamic assistant and the hand-off to the results screen.
class PlayScreen extends ConsumerStatefulWidget {
  const PlayScreen({super.key, required this.run, this.input});

  final RunSpec run;

  /// Scripted input instead of the player (integration tests).
  @visibleForTesting
  final InputSource? input;

  @override
  ConsumerState<PlayScreen> createState() => _PlayScreenState();
}

class _PlayScreenState extends ConsumerState<PlayScreen> {
  PlayGame? _game;
  LevelData? _level;
  int _countdown = 9;
  Timer? _timer;
  bool _infiniteCredits = false;

  RunSpec get run => widget.run;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _start();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _start() async {
    final level = await Campaign.loadLevel(
      DefaultAssetBundle.of(context),
      run.current,
    );
    if (!mounted) return;
    final l = AppLocalizations.of(context);
    final settings = ref.read(settingsProvider);
    final progress = ref.read(progressProvider);
    final wallet = ref.read(walletProvider);
    var balance = const Balance();
    if (run.weekly != null) balance = Weekly.balanceFor(run.weekly!, balance);
    _infiniteCredits = run.mode == GameMode.campaign && wallet.fullCartridge;
    Replay? ghost;
    if (run.ghostMode) {
      ghost = await ref.read(multiplayerProvider).bestGhost(run.scoreTable!);
    }
    final config = PlayConfig(
      level: level,
      levelNumber: run.current.number,
      mode: run.mode,
      difficulty: run.difficulty,
      hero: run.hero,
      balance: balance,
      seed: run.seed,
      autoAim: settings.autoAim && run.difficulty != Difficulty.arcade,
      rotatingCamera: settings.rotatingCamera,
      loadout: Workshop.loadoutFor(
        progress,
        difficulty: run.difficulty,
        ranked: run.ranked,
        balance: balance,
        dashUnlocked: run.mode != GameMode.campaign,
        forcedWeapon: run.weekly == null ? null : Weekly.weaponFor(run.weekly!),
      ),
      credits: _credits,
      target: run.challenge?.target,
      title: levelName(l, level.id, level.name),
      controls: _controls(settings),
      cheats: progress.cheats,
      crt: progress.cheats.contains('brokenTube')
          ? CrtParams.broken
          : switch (settings.crt) {
              CrtPreset.off => null,
              CrtPreset.arcade => CrtParams.arcade,
              CrtPreset.tv => CrtParams.tv,
            },
    );
    final audio = ref.read(audioProvider);
    audio.music(_trackFor(level));
    ref.read(analyticsProvider).log('level_start', {
      'level': level.id,
      'mode': run.mode.name,
      'difficulty': run.difficulty.name,
    });
    setState(() {
      _level = level;
      _game = PlayGame(
        config: config,
        input: widget.input,
        recordGhost: run.ghostMode,
        ghost: ghost?.ghost,
        callbacks: PlayCallbacks(
          onEvent: _onEvent,
          onPause: () {
            audio.pauseMusic();
            _game!.overlays.add('pause');
          },
          onGameOver: _onGameOver,
          onComplete: _onComplete,
          onAssistOffer: () => _game!.overlays.add('assist'),
        ),
      );
    });
  }

  ControlsConfig _controls(Settings s) =>
      ControlsConfig(layout: s.controls, vibration: s.vibration);

  int get _credits {
    if (_infiniteCredits) return 99;
    if (run.mode == GameMode.arcade || run.difficulty == Difficulty.arcade) {
      return run.arcadeCredits;
    }
    return ref.read(progressProvider).credits;
  }

  Track _trackFor(LevelData l) {
    if (l.isBoss) return Track.boss;
    return switch (l.theme) {
      LevelTheme.asteroids => Track.world1,
      LevelTheme.station => Track.world2,
      LevelTheme.glorbo => Track.world3,
    };
  }

  void _onEvent(SimEvent e) {
    ref.read(audioProvider).onSimEvent(e);
    if (!ref.read(settingsProvider).vibration) return;
    switch (e.type) {
      case SimEventType.playerDeath:
        HapticFeedback.heavyImpact();
      case SimEventType.playerHurt || SimEventType.bossDefeated:
        HapticFeedback.mediumImpact();
      case SimEventType.explosion when e.a >= 2:
        HapticFeedback.lightImpact();
      default:
        break;
    }
  }

  // ------------------------------------------------------------ continue --

  void _onGameOver() {
    final audio = ref.read(audioProvider);
    audio.stopMusic();
    audio.jingle(Jingle.continueQ);
    ref.read(analyticsProvider).log('death', {
      'level': _level!.id,
      'gameOver': true,
    });
    _countdown = 9;
    _game!.overlays.add('continue');
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      ref.read(audioProvider).sfx(Sfx.tick);
      setState(() => _countdown--);
      if (_countdown < 0) {
        t.cancel();
        _gameOver();
      }
    });
  }

  Future<void> _continue() async {
    var ok = _infiniteCredits;
    if (!ok) {
      if (run.mode == GameMode.arcade || run.difficulty == Difficulty.arcade) {
        ok = run.arcadeCredits > 0;
        if (ok) run.arcadeCredits--;
      } else {
        ok = await ref.read(progressProvider.notifier).spendCredit();
      }
    }
    if (!ok) return;
    _timer?.cancel();
    ref.read(analyticsProvider).log('continue_used', {'level': _level!.id});
    _game!.overlays.remove('continue');
    ref.read(audioProvider).music(_trackFor(_level!));
    _game!.continueGame();
  }

  Future<void> _watchAdForCredit() async {
    final ok = await ref.read(adProvider).showRewarded('continue_credit');
    if (!ok) return;
    if (run.mode == GameMode.arcade || run.difficulty == Difficulty.arcade) {
      run.arcadeCredits++;
    } else {
      await ref.read(progressProvider.notifier).addCredits(1);
    }
    setState(() {});
  }

  void _gameOver() {
    ref.read(audioProvider).jingle(Jingle.gameOver);
    _timer?.cancel();
    _game!.overlays.remove('continue');
    _game!.overlays.add('gameover');
    Future.delayed(const Duration(seconds: 3), () {
      if (!mounted) return;
      final table = run.scoreTable;
      final total = run.totalScore + (_game?.sim.score ?? 0);
      if (table != null &&
          ref.read(progressProvider).isHighScore(total, table)) {
        Navigator.of(context).pushReplacement(
          PixelRoute(InitialsScreen(score: total, table: table)),
        );
      } else {
        Navigator.of(context).pop();
      }
    });
  }

  // ------------------------------------------------------------- results --

  Future<void> _onComplete(LevelResult result) async {
    final level = _level!;
    final audio = ref.read(audioProvider);
    audio.stopMusic();
    audio.jingle(result.rank == 'S' ? Jingle.rankS : Jingle.stageClear);
    ref.read(analyticsProvider).log('level_complete', {
      'level': level.id,
      'score': result.total,
      'rank': result.rank,
      'deaths': result.deaths,
      'seconds': result.seconds,
    });
    final rewards = await ref
        .read(progressProvider.notifier)
        .recordLevel(
          levelId: level.id,
          result: result,
          parTime: level.parTime,
          kills: result.kills,
          earnsCredit: run.mode == GameMode.campaign,
          campaignProgress:
              run.mode == GameMode.campaign ||
              run.mode == GameMode.arcade ||
              run.mode == GameMode.bossRush,
        );
    if (run.ghostMode && _game != null) {
      await ref
          .read(multiplayerProvider)
          .submit(
            run.scoreTable!,
            Replay(
              levelId: level.id,
              seed: run.seed,
              frames: _game!.recorder.frames,
              score: result.total,
              hero: run.hero.atlas,
              ghost: _game!.ghostTrace,
            ),
          );
      await ref.read(progressProvider.notifier).unlockTrophy('weekly');
    }
    run.totalScore += result.total;
    run.totalDeaths += result.deaths;
    if (!mounted) return;
    await Future<void>.delayed(const Duration(milliseconds: 1200));
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PixelRoute(
        ResultsScreen(run: run, result: result, rewards: rewards, level: level),
      ),
    );
  }

  // ------------------------------------------------------------- overlays --

  Widget _overlayBox(Widget child) => Center(
    child: PixelPanel(padding: const EdgeInsets.all(16), child: child),
  );

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final game = _game;
    if (game == null) {
      return Scaffold(
        backgroundColor: Pal.ink0,
        body: Center(child: PixelText(l.loading, scale: 1.5)),
      );
    }
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (!game.userPaused) {
          game.pause();
          game.overlays.add('pause');
        }
      },
      child: Scaffold(
        backgroundColor: Pal.ink0,
        body: PlayView(
          game: game,
          overlays: {
            'pause': (context, g) => _overlayBox(
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  PixelText(l.paused, scale: 2, color: Pal.gold6),
                  const SizedBox(height: 12),
                  PixelButton(
                    label: l.resume,
                    autofocus: true,
                    width: 220,
                    onPressed: () {
                      g.overlays.remove('pause');
                      ref.read(audioProvider).resumeMusic();
                      g.resume();
                    },
                  ),
                  const SizedBox(height: 6),
                  PixelButton(
                    label: l.restart,
                    width: 220,
                    onPressed: () {
                      Navigator.of(context)
                          .pushReplacement(PixelRoute(PlayScreen(run: run)));
                    },
                  ),
                  const SizedBox(height: 6),
                  PixelButton(
                    label: run.mode == GameMode.campaign
                        ? l.quitToMap
                        : l.quitToTitle,
                    width: 220,
                    onPressed: () {
                      ref.read(audioProvider).stopMusic();
                      Navigator.of(context).pop();
                    },
                  ),
                ],
              ),
            ),
            'assist': (context, g) => _overlayBox(
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  PixelText(l.assistTitle, scale: 1.6, color: Pal.aqua6),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: 380,
                    child: PixelText(l.assistBody, align: TextAlign.center),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      PixelButton(
                        label: l.assistYes,
                        autofocus: true,
                        onPressed: () {
                          g.overlays.remove('assist');
                          g.acceptAssist();
                        },
                      ),
                      const SizedBox(width: 12),
                      PixelButton(
                        label: l.assistNo,
                        onPressed: () {
                          g.overlays.remove('assist');
                          g.resume();
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
            'continue': (context, g) => _ContinueOverlay(
              countdown: _countdown,
              credits: _credits,
              infinite: _infiniteCredits,
              canWatchAd:
                  !ref.read(walletProvider).fullCartridge &&
                  ref.read(adProvider).available,
              onContinue: _continue,
              onWatchAd: _watchAdForCredit,
              onGiveUp: () {
                _countdown = -1;
                _gameOver();
              },
            ),
            'gameover': (context, g) => Center(
              child: PixelText(
                l.gameOver,
                scale: 4,
                color: Pal.ember5,
                shadow: Pal.ink0,
              ),
            ),
          },
        ),
      ),
    );
  }
}

/// "CONTINUE? 9...8...7..." with credits.
class _ContinueOverlay extends StatelessWidget {
  const _ContinueOverlay({
    required this.countdown,
    required this.credits,
    required this.infinite,
    required this.canWatchAd,
    required this.onContinue,
    required this.onWatchAd,
    required this.onGiveUp,
  });

  final int countdown;
  final int credits;
  final bool infinite;
  final bool canWatchAd;
  final VoidCallback onContinue, onWatchAd, onGiveUp;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final hasCredit = infinite || credits > 0;
    return ColoredBox(
      color: const Color(0xCC0B0A14),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            PixelText(
              l.continueQuestion,
              scale: 3,
              color: Pal.gold6,
              shadow: Pal.ember2,
            ),
            const SizedBox(height: 8),
            PixelText(
              '${countdown.clamp(0, 9)}',
              scale: 6,
              color: countdown <= 3 ? Pal.ember5 : Pal.ink7,
            ),
            const SizedBox(height: 8),
            PixelText(
              infinite ? l.creditsLabel(99) : l.creditsLabel(credits),
              color: Pal.gold6,
            ),
            const SizedBox(height: 12),
            if (hasCredit)
              PixelButton(
                label: '${l.insertCoin} (${l.continueCost})',
                autofocus: true,
                scale: 1.2,
                onPressed: onContinue,
              )
            else
              PixelText(l.noCredits, color: Pal.ember5),
            if (canWatchAd && !infinite) ...[
              const SizedBox(height: 8),
              PixelButton(label: l.watchAdCredit, onPressed: onWatchAd),
            ],
            const SizedBox(height: 8),
            PixelButton(
              label: l.quitToTitle,
              color: Pal.ink5,
              onPressed: onGiveUp,
            ),
          ],
        ),
      ),
    );
  }
}
