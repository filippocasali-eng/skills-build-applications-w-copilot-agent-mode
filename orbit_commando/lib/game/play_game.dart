import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/cache.dart';
import 'package:flame/camera.dart';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' show KeyEventResult;

import '../engine/loop/fixed_step_clock.dart';
import '../engine/physics/gravity.dart';
import '../engine/render/palette.g.dart';
import '../engine/render/pixel_renderer.dart';
import '../engine/render/virtual_screen.dart';
import '../engine/replay/replay.dart';
import 'game_resources.dart';
import 'input/controls.dart';
import 'input/input_source.dart';
import 'levels/level_data.dart';
import 'play_config.dart';
import 'sim/events.dart';
import 'sim/game_sim.dart';
import 'sim/input_frame.dart';
import 'view/backdrop.dart';
import 'view/fx.dart';
import 'view/hud.dart';
import 'view/world_renderer.dart';

/// Callbacks from the game to the Flutter shell (screens, audio, haptics).
class PlayCallbacks {
  const PlayCallbacks({
    this.onEvent,
    this.onGameOver,
    this.onComplete,
    this.onPause,
    this.onAssistOffer,
  });

  /// Every simulation event (audio, haptics, analytics).
  final void Function(SimEvent e)? onEvent;
  final void Function()? onGameOver;
  final void Function(LevelResult result)? onComplete;
  final void Function()? onPause;

  /// The dynamic assistant suggests a shield after repeated deaths.
  final void Function()? onAssistOffer;
}

/// Gameplay host: owns a [GameSim], feeds it input at 60 Hz, renders it at
/// 640x360 and reports outcomes.
class PlayGame extends FlameGame with PixelPerfectRender, KeyboardEvents {
  PlayGame({
    required this.config,
    this.callbacks = const PlayCallbacks(),
    InputSource? input,
    this.recordGhost = false,
    this.ghost,
  }) : _scripted = input,
       super(
         camera: CameraComponent(
           viewport: FixedSizeViewport(
             VirtualScreen.width.toDouble(),
             VirtualScreen.height.toDouble(),
           ),
         ),
       ) {
    images = Images(prefix: 'assets/');
    assets = AssetsCache(prefix: 'assets/');
    touch = TouchControls(layout: config.controls.layout);
  }

  final PlayConfig config;
  final PlayCallbacks callbacks;

  /// Scripted input (attract mode, replays). Null = live player.
  final InputSource? _scripted;
  final bool recordGhost;

  /// Ghost path to race against (weekly challenge), see [Replay.ghost].
  final List<double>? ghost;

  late final GameResources res;
  late final GameSim sim;
  late final Fx fx;
  late final TouchControls touch;
  final KeyControls keys = KeyControls();
  final ScreenIntent _intent = ScreenIntent();
  final FixedStepClock clock = FixedStepClock();
  final InputRecorder recorder = InputRecorder();
  final List<double> ghostTrace = [];

  /// Seconds of (scaled) game time, for animations.
  double time = 0;
  bool userPaused = false;
  bool _reportedEnd = false;
  bool _assistOffered = false;
  int ticksSinceShot = 999;

  /// Last screen intent (HUD draws the stick knob from it).
  ScreenIntent get intent => _intent;
  bool get isAttract => _scripted != null;

  final Map<String, Image> _textures = {};
  final Set<String> _hintsDone = {};

  String get heroAtlas => config.hero.atlas;

  bool hintDone(String icon) => _hintsDone.contains(icon);

  Image textureFor(String theme) => _textures[theme]!;

  Image? planetImage(PlanetDef p) =>
      res.images[GameResources.planetPath(p.style, p.radius.round())];

  // Camera rig state.
  double _camX = 0, _camY = 0, _camAngle = 0;

  @override
  Color backgroundColor() => Pal.ink0;

  @override
  Future<void> onLoad() async {
    res = await GameResources.load(images: images, assets: assets);
    await res.loadPlanets([
      for (final p in config.level.planets) (p.style, p.radius.round()),
    ]);
    // Cut each terrain texture out of the atlas so it can tile as a shader.
    final tex = res.textures;
    for (final theme in LevelTheme.values) {
      final r = tex.data.frames[tex.data.animations[theme.name]!.frames.first];
      final rec = PictureRecorder();
      Canvas(rec).drawImageRect(
        tex.image,
        r,
        Rect.fromLTWH(0, 0, r.width, r.height),
        Paint()..filterQuality = FilterQuality.none,
      );
      _textures[theme.name] = rec.endRecording().toImageSync(
        r.width.toInt(),
        r.height.toInt(),
      );
    }
    sim = GameSim(
      level: config.level,
      balance: config.balance,
      difficulty: config.difficulty,
      loadout: config.loadout,
      seed: config.seed,
      levelNumber: config.levelNumber,
      autoAim: config.autoAim,
    );
    fx = Fx(res);
    final p = sim.player.body;
    _camX = p.cx;
    _camY = p.cy;
    camera.backdrop.add(Backdrop());
    world.add(WorldRenderer());
    camera.viewport.add(Hud());
    _updateCamera(1);
  }

  // ---------------------------------------------------------------- input --

  @override
  KeyEventResult onKeyEvent(
    KeyEvent event,
    Set<LogicalKeyboardKey> keysPressed,
  ) {
    keys.onKey(event);
    return KeyEventResult.handled;
  }

  /// Physical pointer events from the Flutter layer.
  void pointerDown(int id, Offset physical) {
    final v = layout.toVirtual(physical);
    touch.down(id, v.dx, v.dy);
  }

  void pointerMove(int id, Offset physical) {
    final v = layout.toVirtual(physical);
    touch.move(id, v.dx, v.dy);
  }

  void pointerUp(int id) => touch.up(id);

  InputFrame _liveInput() {
    _intent.clear();
    touch.writeTo(_intent);
    keys.writeTo(_intent);
    final b = sim.player.inVehicle
        ? sim.vehicles.current!.body
        : sim.player.body;
    return _intent.toLocal(cameraAngle: _camAngle, ux: b.ux, uy: b.uy);
  }

  // --------------------------------------------------------------- update --

  @override
  void update(double dt) {
    if (touch.pauseRequested || keys.pauseRequested) {
      touch.pauseRequested = keys.pauseRequested = false;
      if (!userPaused && !isAttract) {
        pause();
        callbacks.onPause?.call();
      }
    }
    if (userPaused) {
      super.update(0);
      return;
    }
    // Boss finale slow motion.
    final scale = sim.slowMo > 0 ? 0.35 : 1.0;
    time += dt * scale;
    final steps = clock.advance(dt * scale);
    for (var i = 0; i < steps; i++) {
      final input = _scripted?.next(sim) ?? _liveInput();
      _trackHints(input);
      recorder.add(input.pack());
      sim.step(input);
      if (recordGhost && sim.tick % Replay.ghostStride == 0) {
        ghostTrace
          ..add(sim.player.body.x)
          ..add(sim.player.body.y)
          ..add(sim.player.body.angle);
      }
      _handleEvents();
      if (sim.state != SimState.playing) break;
    }
    fx.update(dt * scale);
    _updateCamera(dt);
    _checkEnd();
    super.update(dt);
  }

  void pause() {
    userPaused = true;
    touch.reset();
  }

  void resume() {
    userPaused = false;
    keys.held.clear();
  }

  /// After GAME OVER, when the player spends a credit.
  void continueGame() {
    sim.continueGame();
    _reportedEnd = false;
    resume();
  }

  void acceptAssist() {
    sim.grantAssistShield();
    resume();
  }

  void _checkEnd() {
    if (_reportedEnd) return;
    if (sim.state == SimState.gameOver) {
      _reportedEnd = true;
      if (!isAttract) {
        userPaused = true;
        callbacks.onGameOver?.call();
      }
    } else if (sim.state == SimState.complete) {
      _reportedEnd = true;
      callbacks.onComplete?.call(sim.result!);
    }
  }

  void _trackHints(InputFrame f) {
    if (f.dx != 0) _hintsDone.add('move');
    if (f.jump) _hintsDone.add('jump');
    if (f.fire) _hintsDone.add('fire');
    if (f.grenade) _hintsDone.add('grenade');
    if (f.dash) _hintsDone.add('dash');
    if (f.dy > 0 && f.fire) _hintsDone.add('aim_up');
    final g = sim.player.body.gravity;
    if (g.kind == GravityKind.zero && (f.dx != 0 || f.dy != 0)) {
      _hintsDone.add('jetpack');
    }
    if (g.kind == GravityKind.uniform && g.dy < 0) _hintsDone.add('gravity');
  }

  void _handleEvents() {
    ticksSinceShot++;
    final ev = sim.events;
    final p = sim.player;
    for (var i = 0; i < ev.length; i++) {
      final e = ev[i];
      callbacks.onEvent?.call(e);
      switch (e.type) {
        case SimEventType.shot:
          ticksSinceShot = 0;
          if (e.a != 2) fx.muzzle(e.x, e.y); // no flash for the laser
          if (e.a == 0 && sim.tick % 2 == 0) {
            fx.shell(p.cx, p.cy, p.body.rx * p.facing, p.body.ry * p.facing);
          }
        case SimEventType.enemyShot:
          fx.muzzle(e.x, e.y);
        case SimEventType.hit:
          fx.spark(e.x, e.y);
        case SimEventType.shieldHit:
          fx.spark(e.x, e.y);
          fx.text('TINK', e.x, e.y - 10, Pal.ink6, life: 0.3);
        case SimEventType.explosion:
          fx.explosion(
            e.x,
            e.y,
            size: e.a,
            gx: -p.body.ux * 0.2,
            gy: -p.body.uy * 0.2,
          );
        case SimEventType.enemyDeath:
          fx.explosion(
            e.x,
            e.y,
            size: 1,
            gx: -p.body.ux * 0.2,
            gy: -p.body.uy * 0.2,
          );
          fx.text(
            _screams[sim.tick % _screams.length],
            e.x,
            e.y - 40,
            Pal.gold7,
            life: 0.6,
          );
        case SimEventType.playerDeath:
          fx.explosion(e.x, e.y, size: 2);
          if (!_assistOffered &&
              e.a >= sim.balance.assistDeaths &&
              !isAttract &&
              config.difficulty.name != 'arcade') {
            _assistOffered = true;
            userPaused = true;
            callbacks.onAssistOffer?.call();
          }
        case SimEventType.combo:
          fx.text('x${e.a}', e.x, e.y - 50, Pal.ember6);
        case SimEventType.hostageFreed:
          fx.text('THANKS!', e.x, e.y - 40, Pal.aqua7, life: 1.2);
        case SimEventType.cassette:
          fx.text('TAPE!', e.x, e.y - 20, Pal.neon6, life: 1.2);
        case SimEventType.weaponPickup:
          fx.text(_weaponNames[e.a], e.x, e.y - 24, Pal.gold7);
        case SimEventType.oneUp:
          fx.text('1UP', e.x, e.y - 24, Pal.moss6, life: 1.2);
        case SimEventType.checkpoint:
          fx.text('CHECKPOINT', e.x, e.y - 70, Pal.aqua6, life: 1.2);
        case SimEventType.vehicleEject:
          fx.text('EJECT!', e.x, e.y - 50, Pal.ember6, life: 1);
        case SimEventType.bossDefeated:
          fx.flash = 0.2;
          fx.shake = 10;
        case SimEventType.land:
          if (e.a >= 1) fx.shake = math.max(fx.shake, 3);
        default:
          break;
      }
    }
  }

  static const _screams = ['AAH!', 'EEK!', 'NOO!', 'WAH!', 'YIPE!', 'OOF!'];
  static const _weaponNames = [
    'BLASTER',
    'SPREAD!',
    'LASER!',
    'PLASMA!',
    'HOMING!',
    'FLAME!',
    'RICOCHET!',
  ];

  // --------------------------------------------------------------- camera --

  void _updateCamera(double dt) {
    final p = sim.player;
    final b = p.inVehicle ? sim.vehicles.current!.body : p.body;
    final up = config.rotatingCamera ? 1.0 : 0.0;
    // Look ahead in the facing direction, a little above the player.
    var tx = b.cx + b.rx * p.facing * 60 + b.ux * 24 * up;
    var ty =
        b.cy + b.ry * p.facing * 60 + (config.rotatingCamera ? b.uy * 24 : -24);
    final boss = sim.bosses.boss;
    if (boss != null && boss.active && !boss.dead) {
      tx = (boss.arena.x0 + boss.arena.x1) / 2;
      ty = boss.arena.y1 - VirtualScreen.height / 2 + 10;
    }
    final k = math.min(1.0, dt * 7);
    _camX += (tx - _camX) * k;
    _camY += (ty - _camY) * k;

    var targetAngle = 0.0;
    if (config.rotatingCamera && !(boss?.active ?? false)) {
      targetAngle = b.angle;
    }
    var d = targetAngle - _camAngle;
    while (d > math.pi) {
      d -= 2 * math.pi;
    }
    while (d < -math.pi) {
      d += 2 * math.pi;
    }
    _camAngle += d * math.min(1.0, dt * 5);
    if (_camAngle.abs() < 0.002) _camAngle = 0;

    // Keep the view inside the level when it isn't rotated.
    if (_camAngle == 0) {
      final lv = sim.level;
      _camX = _camX.clamp(
        VirtualScreen.width / 2,
        math.max(VirtualScreen.width / 2, lv.width - VirtualScreen.width / 2),
      );
      _camY = math.min(_camY, lv.height - VirtualScreen.height / 2 - 80);
    }

    final shake = fx.shake;
    final sx = shake > 0 ? (math.Random().nextDouble() - 0.5) * shake : 0.0;
    final sy = shake > 0 ? (math.Random().nextDouble() - 0.5) * shake : 0.0;
    final vf = camera.viewfinder;
    // Note: Viewfinder.position returns a copy; assign a new vector.
    vf.position = Vector2(
      _camAngle == 0 ? (_camX + sx).roundToDouble() : _camX + sx,
      _camAngle == 0 ? (_camY + sy).roundToDouble() : _camY + sy,
    );
    vf.angle = _camAngle;
  }

  double get cameraAngle => _camAngle;
}
