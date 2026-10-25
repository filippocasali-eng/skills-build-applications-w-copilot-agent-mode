import 'dart:math' as math;

import '../../engine/physics/geometry.dart';
import '../../engine/physics/gravity.dart';
import '../enemies/enemies.dart';
import '../sim/game_sim.dart';
import '../sim/input_frame.dart';

/// Where a tick's input comes from.
abstract interface class InputSource {
  InputFrame next(GameSim sim);
}

/// Plays back recorded frames, then idles.
class ReplayInput implements InputSource {
  ReplayInput(this.frames);

  final List<int> frames;
  int _i = 0;

  bool get finished => _i >= frames.length;

  @override
  InputFrame next(GameSim sim) =>
      _i < frames.length ? InputFrame.unpack(frames[_i++]) : InputFrame.none;
}

/// A simple bot: runs towards the exit, jumps walls and gaps, shoots what
/// it sees. Drives the attract mode and the end-to-end test.
class AutoPilot implements InputSource {
  AutoPilot({this.aggressive = true});

  final bool aggressive;
  final RayHit _ray = RayHit();
  final GravitySample _g = GravitySample();
  int _jumpHold = 0;
  int _stuck = 0;
  double _lastX = 0;
  int _reverse = 0;
  int _grenadeCd = 0;
  bool _dashNow = false;

  @override
  InputFrame next(GameSim sim) {
    final p = sim.player;
    final b = p.inVehicle ? sim.vehicles.current!.body : p.body;
    if (_grenadeCd > 0) _grenadeCd--;

    // Goal: the exit, or the boss arena / weak point.
    var gx = sim.level.exit != null
        ? (sim.level.exit!.x0 + sim.level.exit!.x1) / 2
        : sim.level.width;
    var gy = sim.level.exit?.y1 ?? b.y;
    final weak = sim.bosses.nearestWeakPoint(p.cx, p.cy);
    final boss = sim.bosses.boss;
    if (sim.bosses.fighting && weak != null && boss != null) {
      // Stand at ~45 degrees from the weak point (diagonal shots hit it),
      // on the side with more room, drifting a little to dodge.
      final height = (b.y - weak.y).abs().clamp(60.0, 220.0);
      final roomLeft = weak.x - boss.arena.x0,
          roomRight = boss.arena.x1 - weak.x;
      final away = roomLeft > roomRight ? -1.0 : 1.0;
      gx = weak.x + away * height + math.sin(sim.tick / 40) * 30;
      gy = b.y;
    }

    // Direction to goal in local frame.
    final wx = gx - b.x, wy = gy - b.y;
    var dx = (wx * b.rx + wy * b.ry) > 8
        ? 1
        : ((wx * b.rx + wy * b.ry) < -8 ? -1 : 0);
    var dy = 0;

    // Progress check (stuck behind something): back off and jump.
    if (sim.tick % 60 == 0) {
      if ((b.x - _lastX).abs() < 6 && !sim.bosses.fighting) {
        _stuck++;
      } else {
        _stuck = 0;
      }
      _lastX = b.x;
      if (_stuck >= 2) {
        _reverse = 30;
        _stuck = 0;
      }
    }
    if (_reverse > 0) {
      _reverse--;
      dx = -dx == 0 ? -1 : -dx;
    }

    sim.gravity.sample(b.x, b.y, _g);
    final zeroG = _g.isZero;
    var jump = false;
    if (zeroG) {
      // Jetpack straight at the goal.
      final u = wx * b.ux + wy * b.uy;
      dy = u > 20 ? 1 : (u < -20 ? -1 : 0);
    } else {
      final f = dx == 0 ? p.facing : dx;
      // Wall ahead at knee height?
      final kx = b.x + b.ux * 20, ky = b.y + b.uy * 20;
      final wall = sim.world.raycast(kx, ky, b.rx * f, b.ry * f, 30, _ray);
      // Gap ahead? Probe the ground a stride ahead (further when fast).
      final look = 26 + b.vr.abs() * 4;
      final px = b.x + b.rx * f * look - b.ux * 4;
      final py = b.y + b.ry * f * look - b.uy * 4;
      final gap = b.grounded && !sim.world.pointBlocked(px, py, 8);
      if ((wall || gap) && b.grounded) {
        _jumpHold = 18;
        // Too slow for a long gap: add a dash (when unlocked).
        if (gap && b.vr.abs() < 2.2) _dashNow = true;
      }
      // On a planetoid: leap off when "up" points at the next planetoid
      // (or at the goal, for the last one).
      if (b.grounded && _g.kind == GravityKind.radial) {
        final here = sim.level.planets.isEmpty
            ? null
            : sim.gravity.zones[_g.radialIndex];
        if (here != null) {
          var bestDot = -1.0;
          for (final pl in sim.level.planets) {
            if (pl.cx == here.cx && pl.cy == here.cy) continue;
            if ((pl.cx - b.x) * (gx - b.x) < 0 && (pl.cx - here.cx).abs() > 1) {
              continue; // behind us
            }
            final ex = pl.cx - b.x, ey = pl.cy - b.y;
            final d = math.sqrt(ex * ex + ey * ey);
            if (d - pl.radius > 190) continue;
            bestDot = math.max(bestDot, (ex * b.ux + ey * b.uy) / d);
          }
          final gd = math.sqrt(wx * wx + wy * wy);
          final toGoal = (wx * b.ux + wy * b.uy) / gd;
          if (bestDot > 0.8 || (bestDot < 0 && toGoal > 0.55)) _jumpHold = 18;
        }
      }
      if (_stuck > 0 && b.grounded) _jumpHold = 18;
      if (_jumpHold > 0) {
        jump = true;
        _jumpHold--;
      }
    }

    // Shoot whatever is near; aim up/down at things above or below.
    var fire = false;
    var grenade = false;
    Enemy? target;
    var best = 340.0 * 340.0;
    for (final e in sim.enemies) {
      if (!e.alive) continue;
      final ex = e.x - p.cx, ey = e.cy - p.cy;
      final d2 = ex * ex + ey * ey;
      if (d2 < best) {
        best = d2;
        target = e;
      }
    }
    if (target != null) {
      fire = true;
      final ex = target.x - p.cx, ey = target.cy - p.cy;
      final r = ex * b.rx + ey * b.ry, u = ex * b.ux + ey * b.uy;
      if (u > 50 && r.abs() < 140) dy = 1;
      if (aggressive && dx == 0) dx = r > 0 ? 1 : -1;
      if ((target.type == 'bulwark' || target.type == 'cyclops') &&
          best < 200 * 200 &&
          _grenadeCd == 0) {
        grenade = true;
        _grenadeCd = 90;
      }
    }
    if (weak != null && sim.bosses.fighting) {
      fire = true;
      final ex = weak.x - p.cx, ey = weak.y - p.cy;
      final u = ex * b.ux + ey * b.uy, r = ex * b.rx + ey * b.ry;
      // Aim: diagonal when the weak point is above and to the side.
      if (u > 40) dy = 1;
      if (r.abs() > 30) dx = r > 0 ? 1 : -1;
      if (r.abs() < 20 && u > 40) dx = 0;
      // Dodge incoming boss shots by hopping.
      if (sim.tick % 55 == 0) _jumpHold = 14;
    }
    // While shooting at a target, face it even if walking away.
    final dash = _dashNow && !p.inVehicle;
    _dashNow = false;
    return InputFrame(
      dx: dx,
      dy: dy,
      jump: jump,
      fire: fire,
      grenade: grenade,
      dash: dash,
    );
  }
}
