import 'dart:math' as math;

import 'package:flutter/services.dart';

import '../sim/input_frame.dart';

/// A touch button in virtual-screen coordinates (640x360).
class ButtonSpec {
  const ButtonSpec(this.x, this.y, this.radius);

  factory ButtonSpec.fromJson(Map<String, dynamic> j) => ButtonSpec(
    (j['x'] as num).toDouble(),
    (j['y'] as num).toDouble(),
    (j['r'] as num).toDouble(),
  );

  final double x, y, radius;

  Map<String, Object> toJson() => {'x': x, 'y': y, 'r': radius};

  ButtonSpec copyWith({double? x, double? y, double? radius}) =>
      ButtonSpec(x ?? this.x, y ?? this.y, radius ?? this.radius);
}

enum ControlButton { fire, jump, grenade, dash }

/// Customisable on-screen layout (position, size, opacity).
class ControlsLayout {
  const ControlsLayout({
    this.buttons = defaults,
    this.opacity = 0.55,
    this.stickRadius = 30,
  });

  factory ControlsLayout.fromJson(Map<String, dynamic> j) => ControlsLayout(
    buttons: {
      for (final b in ControlButton.values)
        b: j[b.name] is Map<String, dynamic>
            ? ButtonSpec.fromJson(j[b.name] as Map<String, dynamic>)
            : defaults[b]!,
    },
    opacity: (j['opacity'] as num?)?.toDouble() ?? 0.55,
    stickRadius: (j['stickRadius'] as num?)?.toDouble() ?? 30,
  );

  static const defaults = {
    ControlButton.fire: ButtonSpec(520, 302, 34),
    ControlButton.jump: ButtonSpec(598, 268, 32),
    ControlButton.grenade: ButtonSpec(604, 186, 22),
    ControlButton.dash: ButtonSpec(530, 220, 22),
  };

  final Map<ControlButton, ButtonSpec> buttons;
  final double opacity;
  final double stickRadius;

  Map<String, Object> toJson() => {
    for (final e in buttons.entries) e.key.name: e.value.toJson(),
    'opacity': opacity,
    'stickRadius': stickRadius,
  };

  ControlsLayout copyWith({
    Map<ControlButton, ButtonSpec>? buttons,
    double? opacity,
  }) => ControlsLayout(
    buttons: buttons ?? this.buttons,
    opacity: opacity ?? this.opacity,
    stickRadius: stickRadius,
  );
}

/// Raw controls in SCREEN space: a direction (x right, y down) and buttons.
/// Converted to the player's local frame by [toLocal].
class ScreenIntent {
  double sx = 0, sy = 0;
  bool jump = false, fire = false, grenade = false, dash = false;

  void clear() {
    sx = sy = 0;
    jump = fire = grenade = dash = false;
  }

  /// Converts to a local [InputFrame].
  ///
  /// [cameraAngle] rotates screen space into world space; ([ux],[uy]) is the
  /// player's "up" in world space. Directions snap to 8 ways.
  InputFrame toLocal({
    required double cameraAngle,
    required double ux,
    required double uy,
  }) {
    var dx = 0, dy = 0;
    final len = math.sqrt(sx * sx + sy * sy);
    if (len > 0.3) {
      final c = math.cos(cameraAngle), s = math.sin(cameraAngle);
      final wx = (sx * c - sy * s) / len, wy = (sx * s + sy * c) / len;
      final r = wx * -uy + wy * ux; // along right = (-uy, ux)
      final u = wx * ux + wy * uy; // along up
      // 8-way snap: a component counts if it's at least ~22.5 deg strong.
      if (r > 0.38) dx = 1;
      if (r < -0.38) dx = -1;
      if (u > 0.38) dy = 1;
      if (u < -0.38) dy = -1;
    }
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

/// Multi-touch state machine: floating stick on the left, buttons on the
/// right. Fed with virtual-screen coordinates by the Flutter layer.
class TouchControls {
  TouchControls({this.layout = const ControlsLayout()});

  ControlsLayout layout;

  int? _stickPointer;
  double stickOriginX = 0, stickOriginY = 0;
  double stickX = 0, stickY = 0; // knob offset, clamped to the radius
  final Map<int, ControlButton> _buttonPointers = {};
  final Set<ControlButton> pressed = {};

  /// Taps on the pause icon (top-right corner).
  bool pauseRequested = false;

  bool get stickActive => _stickPointer != null;

  void down(int pointer, double x, double y) {
    if (x > 600 && y < 40) {
      pauseRequested = true;
      return;
    }
    final b = _hit(x, y);
    if (b != null) {
      _buttonPointers[pointer] = b;
      pressed.add(b);
      return;
    }
    if (x < 320 && _stickPointer == null) {
      _stickPointer = pointer;
      stickOriginX = x;
      stickOriginY = y;
      stickX = stickY = 0;
    }
  }

  void move(int pointer, double x, double y) {
    if (pointer == _stickPointer) {
      var dx = x - stickOriginX, dy = y - stickOriginY;
      final r = layout.stickRadius;
      final d = math.sqrt(dx * dx + dy * dy);
      if (d > r) {
        // Drag the base along so direction changes stay responsive.
        stickOriginX += dx / d * (d - r);
        stickOriginY += dy / d * (d - r);
        dx = dx / d * r;
        dy = dy / d * r;
      }
      stickX = dx;
      stickY = dy;
      return;
    }
    // Sliding a thumb between buttons (e.g. fire -> jump) re-targets it.
    final b = _hit(x, y);
    final old = _buttonPointers[pointer];
    if (b != null && old != null && b != old) {
      pressed.remove(old);
      _buttonPointers[pointer] = b;
      pressed.add(b);
    }
  }

  void up(int pointer) {
    if (pointer == _stickPointer) {
      _stickPointer = null;
      stickX = stickY = 0;
    }
    final b = _buttonPointers.remove(pointer);
    if (b != null && !_buttonPointers.containsValue(b)) pressed.remove(b);
  }

  void reset() {
    _stickPointer = null;
    stickX = stickY = 0;
    _buttonPointers.clear();
    pressed.clear();
  }

  ControlButton? _hit(double x, double y) {
    ControlButton? best;
    var bestD = double.infinity;
    for (final e in layout.buttons.entries) {
      final dx = x - e.value.x, dy = y - e.value.y;
      final d = dx * dx + dy * dy;
      // A little forgiving: 25% bigger than drawn.
      final r = e.value.radius * 1.25;
      if (d < r * r && d < bestD) {
        bestD = d;
        best = e.key;
      }
    }
    return best;
  }

  void writeTo(ScreenIntent out) {
    final r = layout.stickRadius;
    if (stickActive) {
      out.sx += stickX / r;
      out.sy += stickY / r;
    }
    out.fire |= pressed.contains(ControlButton.fire);
    out.jump |= pressed.contains(ControlButton.jump);
    out.grenade |= pressed.contains(ControlButton.grenade);
    out.dash |= pressed.contains(ControlButton.dash);
  }
}

/// Keyboard and Bluetooth controller (Android maps pad buttons to keys).
///
/// Default mapping (4-button layout): A = jump, X = fire, B = grenade,
/// Y / R1 = dash, Start = pause; D-pad or arrows to move.
class KeyControls {
  final Set<LogicalKeyboardKey> held = {};
  bool pauseRequested = false;

  Map<String, List<LogicalKeyboardKey>> bindings = defaultBindings;

  static final defaultBindings = <String, List<LogicalKeyboardKey>>{
    'left': [LogicalKeyboardKey.arrowLeft, LogicalKeyboardKey.keyA],
    'right': [LogicalKeyboardKey.arrowRight, LogicalKeyboardKey.keyD],
    'up': [LogicalKeyboardKey.arrowUp, LogicalKeyboardKey.keyW],
    'down': [LogicalKeyboardKey.arrowDown, LogicalKeyboardKey.keyS],
    'jump': [
      LogicalKeyboardKey.space,
      LogicalKeyboardKey.keyJ,
      LogicalKeyboardKey.gameButtonA,
    ],
    'fire': [
      LogicalKeyboardKey.keyK,
      LogicalKeyboardKey.controlLeft,
      LogicalKeyboardKey.gameButtonX,
    ],
    'grenade': [LogicalKeyboardKey.keyL, LogicalKeyboardKey.gameButtonB],
    'dash': [
      LogicalKeyboardKey.shiftLeft,
      LogicalKeyboardKey.gameButtonY,
      LogicalKeyboardKey.gameButtonRight1,
    ],
    'pause': [
      LogicalKeyboardKey.escape,
      LogicalKeyboardKey.keyP,
      LogicalKeyboardKey.gameButtonStart,
    ],
  };

  bool _any(String action) => (bindings[action] ?? const []).any(held.contains);

  void onKey(KeyEvent e) {
    if (e is KeyDownEvent) {
      held.add(e.logicalKey);
      if ((bindings['pause'] ?? const []).contains(e.logicalKey)) {
        pauseRequested = true;
      }
    } else if (e is KeyUpEvent) {
      held.remove(e.logicalKey);
    }
  }

  void writeTo(ScreenIntent out) {
    if (_any('left')) out.sx -= 1;
    if (_any('right')) out.sx += 1;
    if (_any('up')) out.sy -= 1;
    if (_any('down')) out.sy += 1;
    out.jump |= _any('jump');
    out.fire |= _any('fire');
    out.grenade |= _any('grenade');
    out.dash |= _any('dash');
  }
}

/// Converts a physical pointer position into virtual-screen coordinates.
typedef ToVirtual = Offset Function(Offset physical);
