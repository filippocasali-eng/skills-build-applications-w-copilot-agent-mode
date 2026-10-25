import 'dart:math' as math;

import '../../engine/physics/body.dart';
import '../../engine/physics/gravity.dart';
import '../sim/balance.dart';
import '../sim/events.dart';
import '../sim/game_sim.dart';
import '../sim/input_frame.dart';

enum PlayerState {
  idle,
  run,
  jump,
  fall,
  crouch,
  dash,
  jetpack,
  hurt,
  dead,
  vehicle,
}

/// The commando. All motion is computed in the body's local frame, so the
/// same code runs on flat ground, round planetoids and in zero gravity.
class Player {
  Player(this.sim)
    : body = Body(radius: 11, height: 58),
      lives = sim.balance.startLives;

  final GameSim sim;
  final Body body;

  PlayerState state = PlayerState.idle;
  int lives;
  int hp = 1;
  int grenades = 0;
  WeaponKind weapon = WeaponKind.blaster;
  int ammo = 0;

  /// +1 facing right, -1 facing left (local frame).
  int facing = 1;

  /// Current aim direction in local frame (unit-ish, 8 directions).
  double aimR = 1, aimU = 0;

  int invuln = 0;
  int shieldTicks = 0;
  int fireCooldown = 0;
  int dashTimer = 0;
  int dashCooldown = 0;
  int jumpBuffer = 0;
  int deadTimer = 0;
  int meleeTimer = 0;
  int hurtTimer = 0;
  bool _jumpHeld = false;
  bool _jumpCut = false;
  bool _grenadeHeld = false;
  bool _dashHeld = false;
  bool _wasGrounded = true;

  /// Deaths since the last checkpoint (dynamic assistant).
  int deathsHere = 0;

  /// Respawn point (feet).
  double checkpointX = 0, checkpointY = 0;

  /// Laser beam for this tick (renderer + damage).
  bool laserOn = false;
  double laserX0 = 0, laserY0 = 0, laserX1 = 0, laserY1 = 0;

  /// Set while riding a vehicle; the player body is parked.
  bool inVehicle = false;

  bool get dead => state == PlayerState.dead;
  bool get crouching => state == PlayerState.crouch;
  bool get dashing => dashTimer > 0;
  bool get dashUnlocked =>
      sim.loadout.dashUnlocked ||
      sim.levelNumber >= sim.balance.dashUnlockLevel;
  int get maxHp =>
      (sim.difficulty == Difficulty.easy ? sim.balance.easyHp : 1) +
      sim.loadout.extraHp;

  double get cx => body.cx;
  double get cy => body.cy;

  /// Muzzle position in world space.
  double get muzzleX =>
      body.x +
      body.ux * (crouching ? 20 : 36) +
      (body.rx * aimR + body.ux * aimU) * 18;
  double get muzzleY =>
      body.y +
      body.uy * (crouching ? 20 : 36) +
      (body.ry * aimR + body.uy * aimU) * 18;

  /// Aim direction in world space.
  double get aimX => body.rx * aimR + body.ux * aimU;
  double get aimY => body.ry * aimR + body.uy * aimU;

  void spawnAt(double x, double y, {bool initial = false}) {
    checkpointX = x;
    checkpointY = y;
    body
      ..x = x
      ..y = y
      ..vx = 0
      ..vy = 0;
    body.updateFrame(sim.gravity);
    if (initial) {
      grenades = sim.balance.startGrenades + sim.loadout.extraGrenades;
    }
    hp = maxHp;
    final forced = sim.loadout.forcedWeapon;
    if (forced != null) {
      weapon = forced;
      ammo = 1 << 30;
    }
    state = PlayerState.idle;
    invuln = initial ? 0 : sim.balance.invulnTicks;
    shieldTicks = sim.loadout.shieldTicks;
  }

  void respawn() {
    weapon = WeaponKind.blaster;
    ammo = 0;
    spawnAt(checkpointX, checkpointY);
    grenades = math.max(grenades, sim.balance.startGrenades);
    inVehicle = false;
    sim.vehicles.onPlayerRespawn();
    sim.events.add(SimEventType.playerRespawn, cx, cy);
  }

  void setCheckpoint(double x, double y) {
    if (checkpointX == x && checkpointY == y) return;
    checkpointX = x;
    checkpointY = y;
    deathsHere = 0;
  }

  /// During hit-stop we still remember a fresh jump press.
  void bufferInput(InputFrame input) {
    if (input.jump && !_jumpHeld) jumpBuffer = sim.balance.jumpBufferTicks;
    _jumpHeld = input.jump;
  }

  double distanceTo(double x, double y) {
    // Distance from point to the capsule's axis segment.
    final ax = body.x + body.ux * body.radius;
    final ay = body.y + body.uy * body.radius;
    final h = (crouching ? 30.0 : body.height) - body.radius * 2;
    final t = ((x - ax) * body.ux + (y - ay) * body.uy).clamp(0.0, h);
    final qx = ax + body.ux * t, qy = ay + body.uy * t;
    return math.sqrt((x - qx) * (x - qx) + (y - qy) * (y - qy)) - body.radius;
  }

  void update(InputFrame input) {
    laserOn = false;
    if (shieldTicks > 0) shieldTicks--;
    if (invuln > 0) invuln--;
    if (dead) {
      if (--deadTimer <= 0) {
        if (lives > 0) {
          respawn();
        } else {
          sim.state = SimState.gameOver;
          sim.events.add(SimEventType.gameOver, cx, cy);
        }
      }
      return;
    }
    if (inVehicle) {
      state = PlayerState.vehicle;
      return;
    }

    final b = sim.balance;
    if (fireCooldown > 0) fireCooldown--;
    if (dashCooldown > 0) dashCooldown--;
    if (meleeTimer > 0) meleeTimer--;
    if (hurtTimer > 0) hurtTimer--;
    if (jumpBuffer > 0) jumpBuffer--;
    if (input.jump && !_jumpHeld) jumpBuffer = b.jumpBufferTicks;

    final zeroG = body.gravity.kind == GravityKind.zero;
    if (input.dx != 0) facing = input.dx;

    // ---- aim (8 directions, local frame) ----
    var ar = input.dx.toDouble(), au = input.dy.toDouble();
    final wantsCrouch = body.grounded && input.dy < 0 && !zeroG;
    if (wantsCrouch || (ar == 0 && au == 0)) {
      ar = facing.toDouble();
      au = 0;
    }
    final al = math.sqrt(ar * ar + au * au);
    aimR = ar / al;
    aimU = au / al;
    if (sim.autoAim) sim.bullets.applyAutoAim(this);

    // ---- movement ----
    var vr = body.vr, vu = body.vu;
    if (dashTimer > 0) {
      dashTimer--;
      vr = facing * b.dashSpeed;
      if (!zeroG) vu = math.max(vu, 0);
      if (dashTimer == 0) vr = facing * b.runSpeed;
    } else if (zeroG) {
      // Jetpack: light inertia, thrust in the stick direction.
      vr = (vr + input.dx * b.jetpackAccel) * b.jetpackDrag;
      vu = (vu + input.dy * b.jetpackAccel) * b.jetpackDrag;
      if (input.jump) vu += b.jetpackAccel * 0.6;
      final sp = math.sqrt(vr * vr + vu * vu);
      if (sp > b.jetpackMax) {
        vr *= b.jetpackMax / sp;
        vu *= b.jetpackMax / sp;
      }
    } else {
      final target = wantsCrouch ? 0.0 : input.dx * b.runSpeed;
      final accel = body.grounded ? b.runAccel : b.airAccel;
      if (input.dx == 0 && body.grounded) {
        vr = _approach(vr, 0, b.friction);
      } else {
        vr = _approach(vr, target, accel);
      }
      // Jump (buffer + coyote time), or drop through a platform.
      final canJump = body.grounded || body.airTicks <= b.coyoteTicks;
      if (jumpBuffer > 0 && canJump && vu <= 0.5) {
        jumpBuffer = 0;
        if (input.dy < 0 && body.grounded) {
          body.dropThrough = 14;
          vu = -1;
        } else {
          vu = b.jumpSpeed;
          _jumpCut = false;
          sim.events.add(SimEventType.jump, body.x, body.y);
        }
      }
      // Variable height: releasing early cuts the jump.
      if (!input.jump && vu > 0 && !_jumpCut && !body.grounded) {
        vu *= b.jumpCut;
        _jumpCut = true;
      }
    }

    // Dash (edge-triggered).
    if (input.dash &&
        !_dashHeld &&
        dashUnlocked &&
        dashCooldown == 0 &&
        dashTimer == 0) {
      dashTimer = b.dashTicks;
      dashCooldown = b.dashCooldown;
      vr = facing * b.dashSpeed;
      sim.events.add(SimEventType.dash, cx, cy, a: facing);
    }
    body.setLocal(vr, vu);
    body.step(sim.world, sim.gravity, g: b.gravity, maxFall: b.maxFall);
    if (body.grounded && !_wasGrounded) {
      sim.events.add(SimEventType.land, body.x, body.y);
    }
    _wasGrounded = body.grounded;

    // ---- attacks ----
    if (input.grenade && !_grenadeHeld && grenades > 0) {
      grenades--;
      sim.bullets.throwGrenade(this);
    }
    if (input.fire) sim.bullets.playerFire(this);

    _grenadeHeld = input.grenade;
    _dashHeld = input.dash;
    _jumpHeld = input.jump;

    // ---- state for animation ----
    if (dashTimer > 0) {
      state = PlayerState.dash;
    } else if (hurtTimer > 0) {
      state = PlayerState.hurt;
    } else if (zeroG) {
      state = PlayerState.jetpack;
    } else if (!body.grounded) {
      state = body.vu > 0 ? PlayerState.jump : PlayerState.fall;
    } else if (wantsCrouch) {
      state = PlayerState.crouch;
    } else if (body.vr.abs() > 0.3) {
      state = PlayerState.run;
    } else {
      state = PlayerState.idle;
    }

    // Fell out of the level.
    final lv = sim.level;
    if (body.y > lv.height + 200 ||
        body.y < -600 ||
        body.x < -600 ||
        body.x > lv.width + 600) {
      die(force: true);
    }
  }

  static double _approach(double v, double target, double step) {
    if (v < target) return math.min(v + step, target);
    if (v > target) return math.max(v - step, target);
    return v;
  }

  void giveWeapon(WeaponKind w) {
    if (sim.loadout.forcedWeapon != null) return;
    final spec = sim.balance.weapons[w]!;
    if (weapon == w) {
      ammo += spec.ammo;
    } else {
      weapon = w;
      ammo = spec.ammo;
    }
  }

  /// A hit from (x,y). Ignored while invulnerable, dashing or shielded.
  void hurt(double x, double y) {
    if (dead || invuln > 0 || dashing || inVehicle) return;
    if (shieldTicks > 0) {
      shieldTicks = 0;
      invuln = 40;
      sim.events.add(SimEventType.shieldHit, cx, cy);
      return;
    }
    hp--;
    if (hp > 0) {
      invuln = sim.balance.hurtInvulnTicks;
      hurtTimer = 20;
      final away = ((cx - x) * body.rx + (cy - y) * body.ry) >= 0 ? 1 : -1;
      body.setLocal(away * 3.0, 4);
      sim.events.add(SimEventType.playerHurt, cx, cy, a: hp);
      return;
    }
    die();
  }

  void die({bool force = false}) {
    if (dead) return;
    if (!force && (invuln > 0 || inVehicle)) return;
    state = PlayerState.dead;
    deadTimer = sim.balance.respawnTicks;
    lives--;
    deathsHere++;
    sim.deaths++;
    sim.combo = 1;
    sim.events.add(SimEventType.playerDeath, cx, cy, a: deathsHere);
    sim.impact(stop: 4);
    body
      ..vx = 0
      ..vy = 0;
  }
}
