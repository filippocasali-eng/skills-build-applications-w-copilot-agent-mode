import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/ui/pixel.dart';
import '../../core/settings/settings.dart';
import '../../engine/render/palette.g.dart';
import '../../engine/render/virtual_screen.dart';
import '../../game/input/controls.dart';
import '../../l10n/app_localizations.dart';

/// Drag the touch buttons where your thumbs like them.
class ControlsEditor extends ConsumerStatefulWidget {
  const ControlsEditor({super.key});

  @override
  ConsumerState<ControlsEditor> createState() => _ControlsEditorState();
}

class _ControlsEditorState extends ConsumerState<ControlsEditor> {
  late ControlsLayout _layout = ref.read(settingsProvider).controls;
  ControlButton _selected = ControlButton.fire;

  Future<void> _save() => ref
      .read(settingsProvider.notifier)
      .update((s) => s.copyWith(controls: _layout));

  void _move(ControlButton b, Offset virtualDelta) {
    final spec = _layout.buttons[b]!;
    setState(() {
      _layout = _layout.copyWith(
        buttons: {
          ..._layout.buttons,
          b: spec.copyWith(
            x: (spec.x + virtualDelta.dx).clamp(
              320,
              VirtualScreen.width - 10.0,
            ),
            y: (spec.y + virtualDelta.dy).clamp(
              40,
              VirtualScreen.height - 10.0,
            ),
          ),
        },
      );
    });
  }

  void _resize(double d) {
    final spec = _layout.buttons[_selected]!;
    setState(() {
      _layout = _layout.copyWith(
        buttons: {
          ..._layout.buttons,
          _selected: spec.copyWith(radius: (spec.radius + d).clamp(16, 48)),
        },
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return PixelScreen(
      title: l.setControls,
      onBack: () async {
        await _save();
        if (context.mounted) Navigator.of(context).pop();
      },
      trailing: Row(
        children: [
          PixelButton(label: '-', onPressed: () => _resize(-2)),
          PixelButton(label: '+', onPressed: () => _resize(2)),
          const SizedBox(width: 8),
          PixelChoice<double>(
            label: l.opacity,
            value: _layout.opacity,
            options: {
              for (final o in const [0.25, 0.4, 0.55, 0.7, 0.85])
                o: '${(o * 100).round()}%',
            },
            onChanged: (o) =>
                setState(() => _layout = _layout.copyWith(opacity: o)),
          ),
          const SizedBox(width: 8),
          PixelButton(
            label: l.resetDefaults,
            onPressed: () => setState(() => _layout = const ControlsLayout()),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, box) {
          final layout = LetterboxLayout.compute(
            box.biggest,
            mode: ScaleMode.fit,
          );
          return Stack(
            children: [
              Positioned.fromRect(
                rect: layout.dest,
                child: const ColoredBox(color: Pal.space1),
              ),
              Positioned(
                left: layout.dest.left + 10,
                top: layout.dest.top + 10,
                child: SizedBox(
                  width: 300,
                  child: PixelText(l.controlsHelp, scale: 0.7, color: Pal.ink5),
                ),
              ),
              for (final e in _layout.buttons.entries)
                Builder(
                  builder: (context) {
                    final c = layout.toScreen(Offset(e.value.x, e.value.y));
                    final r = e.value.radius * layout.scale;
                    final sel = e.key == _selected;
                    return Positioned(
                      left: c.dx - r,
                      top: c.dy - r,
                      child: GestureDetector(
                        onTap: () => setState(() => _selected = e.key),
                        onPanStart: (_) => setState(() => _selected = e.key),
                        onPanUpdate: (d) =>
                            _move(e.key, d.delta / layout.scale),
                        child: Opacity(
                          opacity: _layout.opacity.clamp(0.25, 1.0),
                          child: Container(
                            width: r * 2,
                            height: r * 2,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Pal.space3,
                              border: Border.all(
                                color: sel ? Pal.gold6 : Pal.ink6,
                                width: 3,
                              ),
                            ),
                            child: Center(
                              child: PixelText(
                                e.key.name.toUpperCase(),
                                scale: 0.6,
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
            ],
          );
        },
      ),
    );
  }
}
