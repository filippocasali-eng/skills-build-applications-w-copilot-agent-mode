import 'package:flutter/widgets.dart';

import '../../game/sim/replay.dart';

enum ControlMode { swipe, tapSides }

/// Full-screen, low-latency gesture layer. A swipe fires as soon as the
/// finger has moved past the threshold (no need to lift it).
class SwipeDetector extends StatefulWidget {
  const SwipeDetector({
    super.key,
    required this.onAction,
    required this.child,
    this.mode = ControlMode.swipe,
  });

  final void Function(InputAction action) onAction;
  final ControlMode mode;
  final Widget child;

  @override
  State<SwipeDetector> createState() => _SwipeDetectorState();
}

class _SwipeDetectorState extends State<SwipeDetector> {
  static const double _threshold = 22;
  static const double _tapSlop = 14;
  static const Duration _tapMax = Duration(milliseconds: 250);

  int? _pointer;
  Offset _start = Offset.zero;
  Duration _startTime = Duration.zero;
  bool _fired = false;

  void _down(PointerDownEvent e) {
    if (_pointer != null) return;
    _pointer = e.pointer;
    _start = e.localPosition;
    _startTime = e.timeStamp;
    _fired = false;
  }

  void _move(PointerMoveEvent e) {
    if (e.pointer != _pointer || _fired) return;
    if (widget.mode == ControlMode.tapSides) return;
    final d = e.localPosition - _start;
    if (d.dx.abs() > _threshold && d.dx.abs() > d.dy.abs()) {
      _fired = true;
      widget.onAction(d.dx < 0 ? InputAction.left : InputAction.right);
    } else if (d.dy > _threshold * 1.4 && d.dy > d.dx.abs()) {
      _fired = true;
      widget.onAction(InputAction.dive);
    }
  }

  void _up(PointerUpEvent e) {
    if (e.pointer != _pointer) return;
    _pointer = null;
    if (_fired) return;
    final d = e.localPosition - _start;
    if (d.distance > _tapSlop || e.timeStamp - _startTime > _tapMax) return;
    if (widget.mode == ControlMode.tapSides) {
      final w = context.size?.width ?? 0;
      widget.onAction(
        e.localPosition.dx < w / 2 ? InputAction.left : InputAction.right,
      );
    } else {
      widget.onAction(InputAction.jump);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: _down,
      onPointerMove: _move,
      onPointerUp: _up,
      onPointerCancel: (e) {
        if (e.pointer == _pointer) _pointer = null;
      },
      child: widget.child,
    );
  }
}
