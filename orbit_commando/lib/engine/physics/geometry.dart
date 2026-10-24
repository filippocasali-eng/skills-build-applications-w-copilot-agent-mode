import 'dart:math' as math;

/// Static collision geometry: line segments (terrain outlines, platforms) and
/// solid discs (planetoids). Pure Dart, no allocations in queries.
///
/// Coordinates are world pixels, y grows downwards.
class Seg {
  Seg(this.ax, this.ay, this.bx, this.by, {this.oneWay = false, this.tag = 0})
    : len = math.sqrt((bx - ax) * (bx - ax) + (by - ay) * (by - ay)) {
    dx = (bx - ax) / len;
    dy = (by - ay) / len;
    // Solid side is on the right of a->b in screen coordinates, so the free
    // side (normal) is on the left: rotate the direction by -90 degrees.
    nx = dy;
    ny = -dx;
  }

  final double ax, ay, bx, by, len;
  late final double dx, dy, nx, ny;

  /// One-way platforms only block bodies coming from the normal side.
  final bool oneWay;

  /// Free-form tag (e.g. surface material for footstep sounds).
  final int tag;

  double get minX => math.min(ax, bx);
  double get maxX => math.max(ax, bx);
  double get minY => math.min(ay, by);
  double get maxY => math.max(ay, by);
}

class Disc {
  const Disc(this.cx, this.cy, this.r, {this.tag = 0});

  final double cx, cy, r;
  final int tag;
}

/// Result of a contact query, reused to avoid allocations.
class Contact {
  double nx = 0, ny = 0, depth = 0, px = 0, py = 0;
  bool oneWay = false;
  bool hit = false;
}

/// Result of a ray cast.
class RayHit {
  bool hit = false;
  double x = 0, y = 0, nx = 0, ny = 0, t = 0;
}

/// Uniform grid over segments for fast neighbourhood queries.
class StaticWorld {
  StaticWorld({
    required List<Seg> segments,
    required List<Disc> discs,
    this.cell = 128,
  }) : segments = List.unmodifiable(segments),
       discs = List.unmodifiable(discs) {
    for (var i = 0; i < this.segments.length; i++) {
      final s = this.segments[i];
      final x0 = (s.minX / cell).floor(), x1 = (s.maxX / cell).floor();
      final y0 = (s.minY / cell).floor(), y1 = (s.maxY / cell).floor();
      for (var gy = y0; gy <= y1; gy++) {
        for (var gx = x0; gx <= x1; gx++) {
          (_grid[_key(gx, gy)] ??= <int>[]).add(i);
        }
      }
    }
  }

  final List<Seg> segments;
  final List<Disc> discs;
  final int cell;
  final Map<int, List<int>> _grid = {};

  // Query scratch: segment indices visited in the current query.
  final List<int> _scratch = [];
  int _stamp = 0;
  late final List<int> _visited = List<int>.filled(segments.length, 0);

  static int _key(int gx, int gy) => (gx & 0xFFFF) << 16 | (gy & 0xFFFF);

  /// Indices of segments whose grid cells overlap the box. The returned list
  /// is reused by the next query: iterate it immediately.
  List<int> query(double x0, double y0, double x1, double y1) {
    _scratch.clear();
    _stamp++;
    final gx0 = (x0 / cell).floor(), gx1 = (x1 / cell).floor();
    final gy0 = (y0 / cell).floor(), gy1 = (y1 / cell).floor();
    for (var gy = gy0; gy <= gy1; gy++) {
      for (var gx = gx0; gx <= gx1; gx++) {
        final list = _grid[_key(gx, gy)];
        if (list == null) continue;
        for (final i in list) {
          if (_visited[i] == _stamp) continue;
          _visited[i] = _stamp;
          _scratch.add(i);
        }
      }
    }
    return _scratch;
  }

  /// Deepest penetration of a circle against all geometry.
  ///
  /// One-way segments are only considered when [allowOneWay] and the circle
  /// centre is on their free side and moving into them ([vx],[vy]).
  bool deepestContact(
    double cx,
    double cy,
    double r,
    Contact out, {
    bool allowOneWay = true,
    double vx = 0,
    double vy = 0,
  }) {
    out.hit = false;
    out.depth = 0;
    for (final i in query(cx - r, cy - r, cx + r, cy + r)) {
      final s = segments[i];
      final t = ((cx - s.ax) * s.dx + (cy - s.ay) * s.dy).clamp(0.0, s.len);
      final qx = s.ax + s.dx * t, qy = s.ay + s.dy * t;
      final ex = cx - qx, ey = cy - qy;
      final d2 = ex * ex + ey * ey;
      if (d2 >= r * r) continue;
      final side = (cx - s.ax) * s.nx + (cy - s.ay) * s.ny;
      if (s.oneWay) {
        if (!allowOneWay) continue;
        if (side < 0) continue; // below/behind the platform
        if (vx * s.nx + vy * s.ny > 0.01) continue; // moving away
        if (t <= 0 || t >= s.len) continue; // ignore the end caps
      }
      final d = math.sqrt(d2);
      double nx, ny, depth;
      if (d < 1e-6) {
        nx = s.nx;
        ny = s.ny;
        depth = r;
      } else {
        nx = ex / d;
        ny = ey / d;
        depth = r - d;
        // Centre past the line (tunnelled): push back to the free side.
        if (side < 0 && !s.oneWay) {
          nx = s.nx;
          ny = s.ny;
          depth = r - side;
        }
      }
      if (depth > out.depth) {
        out
          ..hit = true
          ..depth = depth
          ..nx = nx
          ..ny = ny
          ..px = qx
          ..py = qy
          ..oneWay = s.oneWay;
      }
    }
    for (final dsc in discs) {
      final ex = cx - dsc.cx, ey = cy - dsc.cy;
      final rr = dsc.r + r;
      final d2 = ex * ex + ey * ey;
      if (d2 >= rr * rr) continue;
      final d = math.sqrt(d2);
      final nx = d < 1e-6 ? 0.0 : ex / d;
      final ny = d < 1e-6 ? -1.0 : ey / d;
      final depth = rr - d;
      if (depth > out.depth) {
        out
          ..hit = true
          ..depth = depth
          ..nx = nx
          ..ny = ny
          ..px = dsc.cx + nx * dsc.r
          ..py = dsc.cy + ny * dsc.r
          ..oneWay = false;
      }
    }
    return out.hit;
  }

  /// Ray from (x0,y0) along (dx,dy) up to [maxDist]. One-way platforms are
  /// ignored (bullets pass through them).
  bool raycast(
    double x0,
    double y0,
    double dx,
    double dy,
    double maxDist,
    RayHit out,
  ) {
    out.hit = false;
    out.t = maxDist;
    final x1 = x0 + dx * maxDist, y1 = y0 + dy * maxDist;
    for (final i in query(
      math.min(x0, x1),
      math.min(y0, y1),
      math.max(x0, x1),
      math.max(y0, y1),
    )) {
      final s = segments[i];
      if (s.oneWay) continue;
      // Solve x0 + dx*t = ax + sdx*u
      final ex = s.bx - s.ax, ey = s.by - s.ay;
      final den = dx * ey - dy * ex;
      if (den.abs() < 1e-9) continue;
      final qx = s.ax - x0, qy = s.ay - y0;
      final t = (qx * ey - qy * ex) / den;
      final u = (qx * dy - qy * dx) / den;
      if (t < 0 || t >= out.t || u < 0 || u > 1) continue;
      out
        ..hit = true
        ..t = t
        ..x = x0 + dx * t
        ..y = y0 + dy * t
        ..nx = s.nx
        ..ny = s.ny;
    }
    for (final dsc in discs) {
      final fx = x0 - dsc.cx, fy = y0 - dsc.cy;
      final b = fx * dx + fy * dy;
      final c = fx * fx + fy * fy - dsc.r * dsc.r;
      final disc = b * b - c;
      if (disc < 0) continue;
      final t = -b - math.sqrt(disc);
      if (t < 0 || t >= out.t) continue;
      final hx = x0 + dx * t, hy = y0 + dy * t;
      out
        ..hit = true
        ..t = t
        ..x = hx
        ..y = hy
        ..nx = (hx - dsc.cx) / dsc.r
        ..ny = (hy - dsc.cy) / dsc.r;
    }
    return out.hit;
  }

  /// True if the point is inside a solid disc or within [r] of a solid
  /// (non one-way) segment.
  bool pointBlocked(double x, double y, double r) {
    for (final dsc in discs) {
      final ex = x - dsc.cx, ey = y - dsc.cy;
      if (ex * ex + ey * ey < (dsc.r + r) * (dsc.r + r)) return true;
    }
    for (final i in query(x - r, y - r, x + r, y + r)) {
      final s = segments[i];
      if (s.oneWay) continue;
      final t = ((x - s.ax) * s.dx + (y - s.ay) * s.dy).clamp(0.0, s.len);
      final qx = s.ax + s.dx * t, qy = s.ay + s.dy * t;
      if ((x - qx) * (x - qx) + (y - qy) * (y - qy) < r * r) return true;
    }
    return false;
  }
}
