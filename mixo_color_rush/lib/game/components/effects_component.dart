import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flutter/painting.dart';

import '../mixo_game.dart';

/// Speed "warp" lines and floating text popups (near miss, combo).
class EffectsComponent extends Component with HasGameReference<MixoGame> {
  EffectsComponent() : super(priority: 40);

  static const int _lines = 36;
  static const int _maxPopups = 6;

  final List<double> _angle = List.generate(
    _lines,
    (i) => i * 2 * math.pi / _lines + (i * 0.37) % 0.2,
  );
  final List<double> _phase = List.generate(_lines, (i) => (i * 0.618) % 1);
  final Paint _line = Paint()..strokeCap = StrokeCap.round;

  final Map<String, TextPainter> _textCache = {};
  final List<String?> _popupText = List.filled(_maxPopups, null);
  final List<double> _popupAge = List.filled(_maxPopups, 0);
  final List<Color> _popupColor = List.filled(
    _maxPopups,
    const Color(0xFFFFFFFF),
  );
  int _nextPopup = 0;

  void popup(String text, Color color) {
    _popupText[_nextPopup] = text;
    _popupAge[_nextPopup] = 0;
    _popupColor[_nextPopup] = color;
    _nextPopup = (_nextPopup + 1) % _maxPopups;
  }

  void clear() {
    for (var i = 0; i < _maxPopups; i++) {
      _popupText[i] = null;
    }
  }

  TextPainter _painter(String text, Color color) {
    final key = '$text|${color.toARGB32()}';
    return _textCache.putIfAbsent(key, () {
      final size = game.projection.width * 0.085;
      return TextPainter(
        text: TextSpan(
          text: text,
          style: TextStyle(
            fontSize: size,
            fontWeight: FontWeight.w900,
            color: color,
            shadows: const [Shadow(blurRadius: 10, color: Color(0xAA000000))],
          ),
        ),
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.center,
      )..layout();
    });
  }

  @override
  void update(double dt) {
    final speedFactor = game.sim.speed * 0.06;
    for (var i = 0; i < _lines; i++) {
      _phase[i] = (_phase[i] + dt * speedFactor) % 1;
    }
    for (var i = 0; i < _maxPopups; i++) {
      if (_popupText[i] != null) {
        _popupAge[i] += dt;
        if (_popupAge[i] > 1.0) _popupText[i] = null;
      }
    }
  }

  @override
  void render(Canvas canvas) {
    final p = game.projection;
    final warp = ((game.sim.speed - 14) / 8).clamp(0.0, 1.0);
    if (warp > 0) {
      final cx = p.centerX;
      final cy = p.horizonY;
      final maxR = p.height;
      for (var i = 0; i < _lines; i++) {
        final ph = _phase[i];
        final r0 = maxR * ph * ph;
        final r1 = r0 + maxR * 0.08 * (0.3 + ph);
        final a = _angle[i];
        _line
          ..strokeWidth = 1 + 3 * ph
          ..color = Color.fromRGBO(255, 255, 255, 0.35 * warp * ph);
        canvas.drawLine(
          Offset(cx + math.cos(a) * r0, cy + math.sin(a) * r0),
          Offset(cx + math.cos(a) * r1, cy + math.sin(a) * r1),
          _line,
        );
      }
    }

    for (var i = 0; i < _maxPopups; i++) {
      final text = _popupText[i];
      if (text == null) continue;
      final age = _popupAge[i];
      final tp = _painter(text, _popupColor[i]);
      final scale = age < 0.12
          ? 0.6 + age / 0.12 * 0.5
          : 1.1 - (age - 0.12) * 0.1;
      final alpha = age > 0.7 ? (1 - (age - 0.7) / 0.3).clamp(0.0, 1.0) : 1.0;
      final y = p.groundY - p.laneWidth * 1.4 - age * p.laneWidth * 0.5;
      canvas
        ..save()
        ..translate(p.centerX, y)
        ..scale(scale);
      if (alpha < 1) {
        canvas.saveLayer(null, Paint()..color = Color.fromRGBO(0, 0, 0, alpha));
      }
      tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
      if (alpha < 1) canvas.restore();
      canvas.restore();
    }
  }
}
