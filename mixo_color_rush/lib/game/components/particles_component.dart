import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

import 'package:flame/components.dart';

/// Fixed-capacity particle system (struct-of-arrays, zero allocation).
class ParticlesComponent extends Component {
  ParticlesComponent({this.capacity = 320}) : super(priority: 30) {
    _x = Float32List(capacity);
    _y = Float32List(capacity);
    _vx = Float32List(capacity);
    _vy = Float32List(capacity);
    _life = Float32List(capacity);
    _max = Float32List(capacity);
    _size = Float32List(capacity);
    _color = Int32List(capacity);
    _shape = Int8List(capacity);
  }

  static const int circle = 0;
  static const int diamond = 1;
  static const int ring = 2;

  final int capacity;
  late final Float32List _x, _y, _vx, _vy, _life, _max, _size;
  late final Int32List _color;
  late final Int8List _shape;
  final Paint _ringPaint = Paint()..style = PaintingStyle.stroke;
  final Path _path = Path();
  int _next = 0;
  final math.Random _rng = math.Random(7);
  final Paint _paint = Paint();

  /// Gravity in px/s².
  double gravity = 900;

  void burst(
    double x,
    double y,
    int argb, {
    int count = 18,
    double speed = 420,
    double size = 6,
    double life = 0.6,
    double upBias = 0.4,
  }) {
    for (var i = 0; i < count; i++) {
      final k = _next;
      _next = (_next + 1) % capacity;
      final a = _rng.nextDouble() * math.pi * 2;
      final s = speed * (0.35 + _rng.nextDouble() * 0.65);
      _x[k] = x;
      _y[k] = y;
      _vx[k] = math.cos(a) * s;
      _vy[k] = math.sin(a) * s - speed * upBias;
      _max[k] = life * (0.6 + _rng.nextDouble() * 0.6);
      _life[k] = _max[k];
      _size[k] = size * (0.6 + _rng.nextDouble() * 0.8);
      _color[k] = argb;
      _shape[k] = circle;
    }
  }

  /// A single drifting particle (trails).
  void emit(
    double x,
    double y,
    int argb, {
    double size = 5,
    double life = 0.4,
    double vy = 220,
    int shape = circle,
  }) {
    final k = _next;
    _next = (_next + 1) % capacity;
    _x[k] = x + (_rng.nextDouble() - 0.5) * size * 2;
    _y[k] = y;
    _vx[k] = (_rng.nextDouble() - 0.5) * 60;
    _vy[k] = vy;
    _max[k] = life;
    _life[k] = life;
    _size[k] = size;
    _color[k] = argb;
    _shape[k] = shape;
  }

  void clear() => _life.fillRange(0, capacity, 0);

  @override
  void update(double dt) {
    for (var i = 0; i < capacity; i++) {
      if (_life[i] <= 0) continue;
      _life[i] -= dt;
      _vy[i] += gravity * dt;
      _x[i] += _vx[i] * dt;
      _y[i] += _vy[i] * dt;
    }
  }

  @override
  void render(Canvas canvas) {
    for (var i = 0; i < capacity; i++) {
      final l = _life[i];
      if (l <= 0) continue;
      final t = l / _max[i];
      final color = Color(_color[i]).withValues(alpha: t.clamp(0.0, 1.0));
      final r = _size[i] * (0.4 + 0.6 * t);
      switch (_shape[i]) {
        case diamond:
          _paint.color = color;
          _path
            ..reset()
            ..moveTo(_x[i], _y[i] - r * 1.4)
            ..lineTo(_x[i] + r, _y[i])
            ..lineTo(_x[i], _y[i] + r * 1.4)
            ..lineTo(_x[i] - r, _y[i])
            ..close();
          canvas.drawPath(_path, _paint);
        case ring:
          _ringPaint
            ..color = color
            ..strokeWidth = r * 0.35;
          canvas.drawCircle(Offset(_x[i], _y[i]), r, _ringPaint);
        default:
          _paint.color = color;
          canvas.drawCircle(Offset(_x[i], _y[i]), r, _paint);
      }
    }
  }
}
