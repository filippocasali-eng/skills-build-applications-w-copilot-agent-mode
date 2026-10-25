import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../engine/render/palette.g.dart';

/// Size of one font pixel in logical pixels for UI text.
const double kPx = 2;

/// Text in the original ORBIT-5 pixel font. [scale] multiplies the 5x7
/// glyphs (1 = 10 logical px line height at kPx=2... tuned for menus).
class PixelText extends StatelessWidget {
  const PixelText(
    this.text, {
    super.key,
    this.scale = 1,
    this.color = Pal.ink7,
    this.shadow = Pal.ink0,
    this.align = TextAlign.left,
    this.maxLines,
  });

  final String text;
  final double scale;
  final Color color;
  final Color? shadow;
  final TextAlign align;
  final int? maxLines;

  static TextStyle style({
    double scale = 1,
    Color color = Pal.ink7,
    Color? shadow = Pal.ink0,
  }) => TextStyle(
    fontFamily: 'Orbit5',
    fontSize: 10 * kPx * scale,
    height: 1.15,
    color: color,
    letterSpacing: 0,
    shadows: shadow == null
        ? null
        : [Shadow(color: shadow, offset: Offset(kPx * scale, kPx * scale))],
  );

  @override
  Widget build(BuildContext context) => Text(
    text,
    textAlign: align,
    maxLines: maxLines,
    overflow: maxLines == null ? null : TextOverflow.ellipsis,
    style: style(scale: scale, color: color, shadow: shadow),
  );
}

/// Blinks its child (arcade "PRESS START" style).
class Blink extends StatefulWidget {
  const Blink({
    super.key,
    required this.child,
    this.period = const Duration(milliseconds: 500),
  });

  final Widget child;
  final Duration period;

  @override
  State<Blink> createState() => _BlinkState();
}

class _BlinkState extends State<Blink> {
  late final Timer _t;
  bool _on = true;

  @override
  void initState() {
    super.initState();
    _t = Timer.periodic(widget.period, (_) => setState(() => _on = !_on));
  }

  @override
  void dispose() {
    _t.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      Opacity(opacity: _on ? 1 : 0, child: widget.child);
}

/// A chunky bevelled panel.
class PixelPanel extends StatelessWidget {
  const PixelPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(12),
    this.color = Pal.ink1,
    this.border = Pal.space4,
  });

  final Widget child;
  final EdgeInsets padding;
  final Color color;
  final Color border;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: color,
      border: Border.all(color: Pal.ink0, width: kPx * 2),
      boxShadow: const [
        BoxShadow(color: Pal.ink0, offset: Offset(kPx * 3, kPx * 3)),
      ],
    ),
    child: DecoratedBox(
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: border, width: kPx),
          left: BorderSide(color: border, width: kPx),
          right: BorderSide(color: Pal.ink0, width: kPx),
          bottom: BorderSide(color: Pal.ink0, width: kPx),
        ),
      ),
      child: Padding(padding: padding, child: child),
    ),
  );
}

/// Global hook for UI sounds/haptics (set by the app shell).
class UiFeedback {
  static void Function()? onTap;
  static void Function()? onFocus;
}

/// Menu button: works with touch, keyboard and gamepad (focus + A/Enter).
class PixelButton extends StatefulWidget {
  const PixelButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.scale = 1,
    this.color = Pal.gold6,
    this.subtitle,
    this.autofocus = false,
    this.width,
    this.icon,
    this.enabled = true,
  });

  final String label;
  final String? subtitle;
  final VoidCallback? onPressed;
  final double scale;
  final Color color;
  final bool autofocus;
  final double? width;
  final Widget? icon;
  final bool enabled;

  @override
  State<PixelButton> createState() => _PixelButtonState();
}

class _PixelButtonState extends State<PixelButton> {
  bool _focus = false;
  bool _down = false;

  bool get _enabled => widget.enabled && widget.onPressed != null;

  void _activate() {
    if (!_enabled) return;
    UiFeedback.onTap?.call();
    widget.onPressed!();
  }

  @override
  Widget build(BuildContext context) {
    final active = _focus || _down;
    final color = !_enabled ? Pal.ink4 : (active ? Pal.ink7 : widget.color);
    return FocusableActionDetector(
      autofocus: widget.autofocus,
      enabled: _enabled,
      onShowFocusHighlight: (v) {
        if (v) UiFeedback.onFocus?.call();
        setState(() => _focus = v);
      },
      onShowHoverHighlight: (v) => setState(() => _focus = v),
      shortcuts: const {
        SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
        SingleActivator(LogicalKeyboardKey.gameButtonA): ActivateIntent(),
        SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
      },
      actions: {
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (_) {
            _activate();
            return null;
          },
        ),
      },
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => setState(() => _down = true),
        onTapCancel: () => setState(() => _down = false),
        onTapUp: (_) {
          setState(() => _down = false);
          _activate();
        },
        child: Container(
          width: widget.width,
          padding: EdgeInsets.symmetric(
            horizontal: 10 * kPx * widget.scale / 2,
            vertical: 4 * kPx,
          ),
          decoration: BoxDecoration(
            color: active ? Pal.space3 : Pal.ink1,
            border: Border.all(
              color: active ? Pal.gold6 : Pal.ink0,
              width: kPx,
            ),
          ),
          child: Row(
            mainAxisSize: widget.width == null
                ? MainAxisSize.min
                : MainAxisSize.max,
            children: [
              if (active) PixelText('>', scale: widget.scale, color: Pal.gold7),
              if (active) SizedBox(width: 4 * kPx),
              if (widget.icon != null) ...[
                widget.icon!,
                SizedBox(width: 4 * kPx),
              ],
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    PixelText(widget.label, scale: widget.scale, color: color),
                    if (widget.subtitle != null)
                      PixelText(widget.subtitle!, scale: 0.6, color: Pal.ink5),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Toggle row used on the Settings screen.
class PixelToggle extends StatelessWidget {
  const PixelToggle({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    required this.onText,
    required this.offText,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  final String onText, offText;

  @override
  Widget build(BuildContext context) => PixelChoice<bool>(
    label: label,
    value: value,
    options: {true: onText, false: offText},
    onChanged: onChanged,
  );
}

/// "< option >" selector, controller friendly.
class PixelChoice<T> extends StatelessWidget {
  const PixelChoice({
    super.key,
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final String label;
  final T value;
  final Map<T, String> options;
  final ValueChanged<T> onChanged;

  void _step(int d) {
    final keys = options.keys.toList();
    final i = keys.indexOf(value);
    onChanged(keys[(i + d + keys.length) % keys.length]);
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3 * kPx),
    child: Row(
      children: [
        Expanded(child: PixelText(label, scale: 0.8, color: Pal.ink6)),
        PixelButton(label: '<', scale: 0.8, onPressed: () => _step(-1)),
        SizedBox(
          width: 150 * kPx,
          child: PixelText(
            options[value] ?? '',
            scale: 0.8,
            color: Pal.gold6,
            align: TextAlign.center,
          ),
        ),
        PixelButton(label: '>', scale: 0.8, onPressed: () => _step(1)),
      ],
    ),
  );
}

/// Scanline overlay for Flutter screens (the in-game CRT is a shader).
class Scanlines extends StatelessWidget {
  const Scanlines({super.key, this.opacity = 0.18});

  final double opacity;

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: CustomPaint(painter: _ScanPainter(opacity), size: Size.infinite),
  );
}

class _ScanPainter extends CustomPainter {
  _ScanPainter(this.opacity);

  final double opacity;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = Color.fromRGBO(0, 0, 0, opacity);
    for (var y = 0.0; y < size.height; y += 3) {
      canvas.drawRect(Rect.fromLTWH(0, y, size.width, 1), p);
    }
  }

  @override
  bool shouldRepaint(_ScanPainter old) => old.opacity != opacity;
}

/// Standard screen frame: dark background, title bar, back button,
/// scanlines.
class PixelScreen extends StatelessWidget {
  const PixelScreen({
    super.key,
    required this.title,
    required this.child,
    this.onBack,
    this.trailing,
  });

  final String title;
  final Widget child;
  final VoidCallback? onBack;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Pal.space0,
    body: Stack(
      children: [
        SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  8 * kPx,
                  4 * kPx,
                  8 * kPx,
                  4 * kPx,
                ),
                child: Row(
                  children: [
                    PixelButton(
                      label: '<',
                      onPressed:
                          onBack ?? () => Navigator.of(context).maybePop(),
                    ),
                    SizedBox(width: 6 * kPx),
                    Expanded(
                      child: PixelText(
                        title,
                        scale: 1.4,
                        color: Pal.gold6,
                        shadow: Pal.ember2,
                      ),
                    ),
                    ?trailing,
                  ],
                ),
              ),
              Expanded(child: child),
            ],
          ),
        ),
        const Scanlines(),
      ],
    ),
  );
}
