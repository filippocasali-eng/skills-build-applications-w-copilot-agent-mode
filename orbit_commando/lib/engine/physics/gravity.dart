import 'dart:math' as math;

/// How gravity works in a region of the level.
enum GravityKind { uniform, zero, radial }

/// A gravity source. Radial fields belong to planetoids; uniform and zero
/// fields are axis-aligned rectangles (stations, space sections).
class GravityZone {
  const GravityZone.uniform({
    required this.x0,
    required this.y0,
    required this.x1,
    required this.y1,
    this.gx = 0,
    this.gy = 1,
  }) : kind = GravityKind.uniform,
       cx = 0,
       cy = 0,
       surface = 0,
       influence = 0,
       strength = 1;

  const GravityZone.zero({
    required this.x0,
    required this.y0,
    required this.x1,
    required this.y1,
  }) : kind = GravityKind.zero,
       gx = 0,
       gy = 0,
       cx = 0,
       cy = 0,
       surface = 0,
       influence = 0,
       strength = 0;

  const GravityZone.radial({
    required this.cx,
    required this.cy,
    required this.surface,
    required this.influence,
    this.strength = 1,
  }) : kind = GravityKind.radial,
       x0 = 0,
       y0 = 0,
       x1 = 0,
       y1 = 0,
       gx = 0,
       gy = 0;

  final GravityKind kind;
  final double x0, y0, x1, y1; // rect zones
  final double gx, gy; // uniform direction (unit)
  final double cx, cy, surface, influence; // radial
  /// Multiplier on the level's base gravity.
  final double strength;

  bool containsRect(double x, double y) =>
      x >= x0 && x <= x1 && y >= y0 && y <= y1;
}

/// Gravity sampled at a point: unit direction (dx,dy) and magnitude scale.
class GravitySample {
  double dx = 0, dy = 1, scale = 1;
  GravityKind kind = GravityKind.uniform;

  /// Index of the radial zone in charge, or -1.
  int radialIndex = -1;

  bool get isZero => kind == GravityKind.zero || scale == 0;
}

/// Resolves which gravity applies where.
///
/// Rules: the radial field whose surface is closest wins among those whose
/// influence contains the point ("nearest field wins" in overlaps); otherwise
/// the last rectangular zone containing the point; otherwise the level
/// default.
class GravityField {
  GravityField({
    required this.zones,
    this.defaultKind = GravityKind.uniform,
    this.defaultGx = 0,
    this.defaultGy = 1,
  });

  final List<GravityZone> zones;
  final GravityKind defaultKind;
  final double defaultGx, defaultGy;

  void sample(double x, double y, GravitySample out) {
    var best = -1;
    var bestDist = double.infinity;
    for (var i = 0; i < zones.length; i++) {
      final z = zones[i];
      if (z.kind != GravityKind.radial) continue;
      final ex = x - z.cx, ey = y - z.cy;
      final d2 = ex * ex + ey * ey;
      if (d2 > z.influence * z.influence) continue;
      final dist = math.sqrt(d2) - z.surface;
      if (dist < bestDist) {
        bestDist = dist;
        best = i;
      }
    }
    if (best >= 0) {
      final z = zones[best];
      final ex = z.cx - x, ey = z.cy - y;
      final d = math.sqrt(ex * ex + ey * ey);
      out
        ..kind = GravityKind.radial
        ..radialIndex = best
        ..scale = z.strength
        ..dx = d < 1e-6 ? 0 : ex / d
        ..dy = d < 1e-6 ? 1 : ey / d;
      return;
    }
    out.radialIndex = -1;
    for (var i = zones.length - 1; i >= 0; i--) {
      final z = zones[i];
      if (z.kind == GravityKind.radial || !z.containsRect(x, y)) continue;
      out.kind = z.kind;
      if (z.kind == GravityKind.zero) {
        out.scale = 0;
      } else {
        out
          ..scale = z.strength
          ..dx = z.gx
          ..dy = z.gy;
      }
      return;
    }
    out.kind = defaultKind;
    if (defaultKind == GravityKind.zero) {
      out.scale = 0;
    } else {
      out
        ..scale = 1
        ..dx = defaultGx
        ..dy = defaultGy;
    }
  }
}
