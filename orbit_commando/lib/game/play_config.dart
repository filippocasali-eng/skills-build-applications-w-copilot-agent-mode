import '../engine/render/pixel_renderer.dart';
import 'controls_config.dart';
import 'levels/level_data.dart';
import 'roster.dart';
import 'sim/balance.dart';
import 'sim/game_sim.dart';

enum GameMode { campaign, arcade, bossRush, weekly, attract, daily, challenge }

/// Everything needed to start one level.
class PlayConfig {
  const PlayConfig({
    required this.level,
    required this.levelNumber,
    this.mode = GameMode.campaign,
    this.difficulty = Difficulty.normal,
    this.hero = Commando.roxy,
    this.loadout = const Loadout(),
    this.balance = const Balance(),
    this.seed = 1994,
    this.autoAim = false,
    this.rotatingCamera = true,
    this.controls = const ControlsConfig(),
    this.credits = 3,
    this.showTouchControls = true,
    this.cheats = const {},
    this.crt,
    this.target,
  });

  final LevelData level;

  /// 1..15 in campaign order.
  final int levelNumber;
  final GameMode mode;
  final Difficulty difficulty;
  final Commando hero;
  final Loadout loadout;
  final Balance balance;
  final int seed;
  final bool autoAim;
  final bool rotatingCamera;
  final ControlsConfig controls;

  /// Credits available for CONTINUE (UI only; the sim doesn't count them).
  final int credits;
  final bool showTouchControls;

  /// Active secret codes: 'bigHeads', 'giantPixels', 'brokenTube'.
  final Set<String> cheats;

  /// CRT post-process parameters (null = sharp pixels).
  final CrtParams? crt;

  /// Score to beat (friend's challenge), shown in the HUD.
  final int? target;
}
