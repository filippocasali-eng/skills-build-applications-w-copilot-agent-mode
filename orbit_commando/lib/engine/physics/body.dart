import 'dart:math' as math;

import 'geometry.dart';
import 'gravity.dart';

/// A character-sized capsule aligned with its local "up".
///
/// Position (x,y) is the feet point. The capsule is two circles of [radius]:
/// the feet circle centred `radius` above the feet, and the head circle
/// centred `height - radius` above them.
///
/// Gameplay code works in the local frame: `vr` (along right) and `vu`
/// (along up). Keeping the local components while "up" turns is what lets a
/// character run around a planetoid at constant speed.
class Body {
  Body({required this.radius, required this.height});

  final double radius;
  final double height;

  double x = 0, y = 0;

  /// Velocity in world space (px/tick).
  double vx = 0, vy = 0;

  /// Local up (unit). Right is (-uy, ux).
  double ux = 0, uy = -1;

  bool grounded = false;
  double groundNx = 0, groundNy = -1;

  /// Ticks since the body last touched ground (0 while grounded).
  int airTicks = 0;

  /// While > 0 one-way platforms are ignored (drop down).
  int dropThrough = 0;

  /// Set by [step] when the head hit something this tick.
  bool bumpedHead = false;

  /// Set by [step] when a side wall blocked horizontal motion.
  bool hitWall = false;

  final GravitySample gravity = GravitySample();
  final Contact _c = Contact();

  double get rx => -uy;
  double get ry => ux;

  /// Velocity along local right / up.
  double get vr => vx * rx + vy * ry;
  double get vu => vx * ux + vy * uy;

  void setLocal(double vr, double vu) {
    vx = rx * vr + ux * vu;
    vy = ry * vr + uy * vu;
  }

  /// Centre of the capsule (useful for hit tests and gravity sampling).
  double get cx => x + ux * height * 0.5;
  double get cy => y + uy * height * 0.5;

  /// Samples gravity at the feet and turns "up" to face away from it.
  /// In zero-g "up" is kept.
  ///
  /// The feet point doesn't move when "up" flips; sampling at the centre
  /// would make the body ping-pong between two fields every tick.
  void updateFrame(GravityField field) {
    field.sample(x, y, gravity);
    if (!gravity.isZero) {
      ux = -gravity.dx;
      uy = -gravity.dy;
    }
  }

  /// Integrates one tick: gravity, movement, collisions, ground snapping.
  ///
  /// [g] is the base gravity in px/tick². Local velocities are preserved
  /// across the change of frame.
  void step(
    StaticWorld world,
    GravityField field, {
    required double g,
    double maxFall = 9,
    bool snapToGround = true,
  }) {
    // Keep local components while the frame rotates smoothly (running
    // around a planetoid). On an abrupt switch (jumping into another field)
    // keep the world velocity instead, or the jump would reverse.
    final lr = vr, lu = vu;
    final oux = ux, ouy = uy;
    updateFrame(field);
    if (oux * ux + ouy * uy > 0.95) setLocal(lr, lu);

    if (!gravity.isZero) {
      var u = vu - g * gravity.scale;
      if (u < -maxFall) u = -maxFall;
      setLocal(vr, u);
    }

    final wasGrounded = grounded;
    grounded = false;
    bumpedHead = false;
    hitWall = false;

    final speed = math.sqrt(vx * vx + vy * vy);
    final steps = math.max(1, (speed / (radius * 0.5)).ceil());
    final sx = vx / steps, sy = vy / steps;
    for (var i = 0; i < steps; i++) {
      x += sx;
      y += sy;
      _resolve(world);
    }

    // Ground snapping keeps us glued on slopes and curved surfaces.
    if (snapToGround && !grounded && wasGrounded && vu <= 0.5) {
      const snap = 6.0;
      final fx = x + ux * radius - ux * snap;
      final fy = y + uy * radius - uy * snap;
      if (world.deepestContact(
            fx,
            fy,
            radius,
            _c,
            allowOneWay: dropThrough == 0,
            vx: -ux,
            vy: -uy,
          ) &&
          (_c.nx * ux + _c.ny * uy) > 0.55) {
        x -= ux * snap;
        y -= uy * snap;
        _resolve(world);
      }
    }

    if (dropThrough > 0) dropThrough--;
    airTicks = grounded ? 0 : airTicks + 1;
  }

  void _resolve(StaticWorld world) {
    for (var iter = 0; iter < 4; iter++) {
      var any = false;
      // Feet circle: may land on one-way platforms.
      final fx = x + ux * radius, fy = y + uy * radius;
      if (world.deepestContact(
        fx,
        fy,
        radius,
        _c,
        allowOneWay: dropThrough == 0,
        vx: vx,
        vy: vy,
      )) {
        any = true;
        _push(_c);
        final up = _c.nx * ux + _c.ny * uy;
        if (up > 0.55) {
          grounded = true;
          groundNx = _c.nx;
          groundNy = _c.ny;
        } else if (up.abs() < 0.55) {
          hitWall = true;
        }
      }
      // Head circle: solid geometry only.
      final hx = x + ux * (height - radius), hy = y + uy * (height - radius);
      if (world.deepestContact(hx, hy, radius, _c, allowOneWay: false)) {
        any = true;
        _push(_c);
        final up = _c.nx * ux + _c.ny * uy;
        if (up < -0.55) {
          bumpedHead = true;
        } else if (up.abs() < 0.55) {
          hitWall = true;
        }
      }
      if (!any) break;
    }
  }

  void _push(Contact c) {
    x += c.nx * c.depth;
    y += c.ny * c.depth;
    final into = vx * c.nx + vy * c.ny;
    if (into < 0) {
      vx -= c.nx * into;
      vy -= c.ny * into;
    }
  }

  /// Visual rotation in radians for a sprite whose art points up (-y).
  double get angle => math.atan2(ux, -uy);
}
