import 'dart:math' as math;

import '../../engine/math/det_random.dart';
import '../../engine/physics/geometry.dart';
import '../../engine/physics/gravity.dart';
import '../bosses/bosses.dart';
import '../enemies/enemies.dart';
import '../levels/level_data.dart';
import '../pickups/items.dart';
import '../player/player.dart';
import '../vehicles/vehicles.dart';
import '../weapons/weapons.dart';
import 'balance.dart';
import 'events.dart';
import 'input_frame.dart';

enum SimState { playing, gameOver, complete }

/// Permanent bonuses from the Workshop and character choice.
class Loadout {
  const Loadout({
    this.damageMult = 1,
    this.fireRateMult = 1,
    this.extraHp = 0,
    this.shieldTicks = 0,
    this.extraGrenades = 0,
    this.dashUnlocked = false,
    this.forcedWeapon,
  });

  final double damageMult;

  /// < 1 means faster (cooldowns are multiplied).
  final double fireRateMult;
  final int extraHp;

  /// Shield at every (re)spawn, in ticks.
  final int shieldTicks;
  final int extraGrenades;

  /// Unlocks the dash before level 3 (e.g. replays, Boss Rush).
  final bool dashUnlocked;

  /// Weekly-challenge modifier: start with (and keep) this weapon.
  final WeaponKind? forcedWeapon;
}

/// End-of-level summary.
class LevelResult {
  const LevelResult({
    required this.score,
    required this.timeBonus,
    required this.noDeathBonus,
    required this.total,
    required this.rank,
    required this.deaths,
    required this.hostagesFreed,
    required this.hostagesTotal,
    required this.cassettes,
    required this.seconds,
    required this.kills,
  });

  final int score, timeBonus, noDeathBonus, total;
  final String rank;
  final int deaths, hostagesFreed, hostagesTotal, cassettes, seconds, kills;

  bool get medalNoDeath => deaths == 0;
  bool get medalAllHostages => hostagesFreed == hostagesTotal;
  bool medalSpeedrun(int parTime) => seconds <= parTime;
}

/// The whole deterministic game state for one level.
///
/// Advance it with [step] once per 60 Hz tick. Same level + seed + loadout +
/// input sequence => same state, on every run.
class GameSim {
  GameSim({
    required this.level,
    this.balance = const Balance(),
    this.difficulty = Difficulty.normal,
    this.loadout = const Loadout(),
    this.seed = 1,
    this.levelNumber = 1,
    this.autoAim = false,
  }) : world = level.buildWorld(),
       gravity = level.buildGravity(),
       rng = DetRandom(seed) {
    player = Player(this);
    bullets = BulletPool(this);
    items = Items(this);
    spawner = Spawner(this);
    vehicles = Vehicles(this);
    bosses = Bosses(this);
    player.spawnAt(level.playerStart.x, level.playerStart.y, initial: true);
  }

  final LevelData level;
  final Balance balance;
  final Difficulty difficulty;
  final Loadout loadout;
  final int seed;

  /// Campaign position (1..15): gates the dash unlock.
  final int levelNumber;
  final bool autoAim;

  final StaticWorld world;
  final GravityField gravity;
  final DetRandom rng;
  final EventQueue events = EventQueue();

  late final Player player;
  late final BulletPool bullets;
  late final Items items;
  late final Spawner spawner;
  late final Vehicles vehicles;
  late final Bosses bosses;

  final List<Enemy> enemies = [];

  SimState state = SimState.playing;
  int tick = 0;

  /// Ticks of gameplay (excludes hit-stop), for the time bonus.
  int playTicks = 0;

  /// While > 0 the world freezes for impact (hit-stop).
  int hitStop = 0;

  /// While > 0 the renderer plays slow motion (boss finale).
  int slowMo = 0;
  int score = 0;
  int combo = 1;
  int comboTimer = 0;
  int kills = 0;
  int deaths = 0;
  int _completeDelay = -1;
  int _nextId = 1;

  /// Final summary once [state] is [SimState.complete].
  LevelResult? result;

  double get enemySpeedMult =>
      difficulty == Difficulty.easy ? balance.easyEnemySpeed : 1.0;

  int nextId() => _nextId++;

  void step(InputFrame input) {
    tick++;
    events.clear();
    if (state != SimState.playing) {
      return;
    }
    if (slowMo > 0) slowMo--;
    if (hitStop > 0) {
      hitStop--;
      player.bufferInput(input);
      return;
    }
    playTicks++;

    if (comboTimer > 0 && --comboTimer == 0) combo = 1;

    spawner.update();
    player.update(input);
    vehicles.update(input);
    for (var i = 0; i < enemies.length; i++) {
      final e = enemies[i];
      if (e.alive) e.update();
    }
    bosses.update();
    bullets.update();
    items.update();

    enemies.removeWhere((e) => !e.alive && e.removeTimer <= 0);
    for (final e in enemies) {
      if (!e.alive) e.removeTimer--;
    }

    _checkExit();
    if (_completeDelay > 0 && --_completeDelay == 0) _finish();
  }

  // ------------------------------------------------------------- scoring ---

  void addScore(int points, double x, double y, {bool combos = false}) {
    final mult = combos ? combo : 1;
    score += points * mult;
    if (combos) {
      if (combo < balance.comboMax) {
        combo++;
        if (combo >= 3) events.add(SimEventType.combo, x, y, a: combo);
      }
      comboTimer = balance.comboWindow;
    }
  }

  /// Called by weapons/vehicles/bosses when something should shake.
  void impact({int stop = 2}) {
    if (stop > hitStop) hitStop = stop;
  }

  // ------------------------------------------------------------- damage ---

  /// Damages everything in [radius]: enemies and bosses if [byPlayer],
  /// otherwise the player.
  void explode(
    double x,
    double y,
    double radius,
    double damage, {
    required bool byPlayer,
    int size = 1,
  }) {
    events.add(SimEventType.explosion, x, y, a: size, b: radius);
    if (byPlayer) {
      for (final e in enemies) {
        if (!e.alive) continue;
        final d = e.distanceTo(x, y);
        if (d < radius + e.spec.radius) {
          e.damage(damage, x, y, explosive: true);
        }
      }
      bosses.damageArea(x, y, radius, damage);
    } else {
      if (player.distanceTo(x, y) < radius) player.hurt(x, y);
    }
    impact(stop: size >= 2 ? 4 : 2);
  }

  // ------------------------------------------------------------ level end ---

  void _checkExit() {
    if (_completeDelay >= 0) return;
    final exit = level.exit;
    final bossDone = !level.isBoss || bosses.defeated;
    if (level.isBoss && bosses.defeated) {
      _completeDelay = 150; // let the finale play out
      return;
    }
    if (exit != null &&
        bossDone &&
        !player.dead &&
        exit.contains(player.cx, player.cy)) {
      _completeDelay = 30;
      events.add(SimEventType.levelComplete, player.cx, player.cy);
    }
  }

  void _finish() {
    final seconds = (playTicks / 60).floor();
    final timeBonus =
        math.max(0, level.parTime - seconds) * balance.timeBonusPerSecond;
    final noDeath = deaths == 0 ? balance.noDeathBonus : 0;
    final total = score + timeBonus + noDeath;
    result = LevelResult(
      score: score,
      timeBonus: timeBonus,
      noDeathBonus: noDeath,
      total: total,
      rank: rankFor(
        total: total,
        target: level.targetScore,
        deaths: deaths,
        allHostages: items.hostagesFreed == items.hostagesTotal,
      ),
      deaths: deaths,
      hostagesFreed: items.hostagesFreed,
      hostagesTotal: items.hostagesTotal,
      cassettes: items.cassettesFound,
      seconds: seconds,
      kills: kills,
    );
    state = SimState.complete;
  }

  /// Rank rules: S needs the target score, no deaths and every hostage.
  static String rankFor({
    required int total,
    required int target,
    required int deaths,
    required bool allHostages,
  }) {
    final r = total / math.max(1, target);
    if (r >= 1.0 && deaths == 0 && allHostages) return 'S';
    if (r >= 0.8) return 'A';
    if (r >= 0.6) return 'B';
    if (r >= 0.4) return 'C';
    return 'D';
  }

  /// Continue after GAME OVER (the caller pays the credit).
  void continueGame() {
    if (state != SimState.gameOver) return;
    state = SimState.playing;
    player.lives = balance.startLives;
    score = 0; // arcade rule: continuing resets the score
    player.respawn();
  }

  /// Dynamic assistant: temporary shield offered after repeated deaths.
  void grantAssistShield() {
    if (difficulty == Difficulty.arcade) return;
    player.shieldTicks = balance.assistShieldTicks;
  }

  /// Hash of the state that matters for determinism tests and replays.
  int stateHash() {
    var h = 17;
    int mix(int v) => h = (h * 31 + v) & 0x3FFFFFFF;
    double q(double v) => (v * 1000).roundToDouble();
    mix(tick);
    mix(score);
    mix(q(player.body.x).toInt());
    mix(q(player.body.y).toInt());
    mix(q(player.body.vx).toInt());
    mix(q(player.body.vy).toInt());
    mix(player.lives);
    for (final e in enemies) {
      mix(e.id);
      mix(q(e.x).toInt());
      mix(q(e.cy).toInt());
      mix(q(e.hp).toInt());
    }
    mix(bullets.activeCount);
    mix(rng.state);
    return h;
  }

  /// Gravity kind at the player (HUD hint, camera behaviour).
  GravityKind get playerGravityKind => player.body.gravity.kind;
}
