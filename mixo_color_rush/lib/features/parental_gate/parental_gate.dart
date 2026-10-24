import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../l10n/generated/app_localizations.dart';

/// Shows the parental gate. Resolves to true only if an adult held the
/// button for 3 seconds AND solved a two-digit multiplication.
Future<bool> showParentalGate(
  BuildContext context, {
  math.Random? random,
}) async {
  final ok = await showDialog<bool>(
    context: context,
    barrierDismissible: true,
    builder: (_) => ParentalGateDialog(random: random),
  );
  return ok ?? false;
}

class ParentalGateDialog extends StatefulWidget {
  const ParentalGateDialog({super.key, this.random});

  final math.Random? random;

  static const holdDuration = Duration(seconds: 3);

  @override
  State<ParentalGateDialog> createState() => _ParentalGateDialogState();
}

class _ParentalGateDialogState extends State<ParentalGateDialog>
    with SingleTickerProviderStateMixin {
  late final math.Random _rng = widget.random ?? math.Random();
  late final AnimationController _hold =
      AnimationController(
        vsync: this,
        duration: ParentalGateDialog.holdDuration,
      )..addStatusListener((s) {
        if (s == AnimationStatus.completed) setState(() => _held = true);
      });
  bool _held = false;
  late int _a;
  late int _b;
  String _answer = '';
  int _attempts = 0;
  bool _wrong = false;

  @override
  void initState() {
    super.initState();
    _newQuestion();
  }

  void _newQuestion() {
    _a = 12 + _rng.nextInt(8); // 12..19
    _b = 3 + _rng.nextInt(7); // 3..9
    _answer = '';
  }

  @override
  void dispose() {
    _hold.dispose();
    super.dispose();
  }

  void _digit(String d) {
    if (_answer.length >= 3) return;
    setState(() {
      _answer += d;
      _wrong = false;
    });
  }

  void _submit() {
    if (int.tryParse(_answer) == _a * _b) {
      Navigator.of(context).pop(true);
      return;
    }
    _attempts++;
    if (_attempts >= 3) {
      Navigator.of(context).pop(false);
      return;
    }
    setState(() {
      _wrong = true;
      _newQuestion();
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Dialog(
      backgroundColor: MixoColors.violet,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.family_restroom_rounded,
              size: 48,
              color: MixoColors.sun,
            ),
            Text(
              l.gateTitle,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            if (!_held) ...[
              Text(
                l.gateHold,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 16),
              GestureDetector(
                key: const Key('gate-hold'),
                onTapDown: (_) => _hold.forward(),
                onTapUp: (_) {
                  if (!_held) _hold.reverse();
                },
                onTapCancel: () {
                  if (!_held) _hold.reverse();
                },
                child: AnimatedBuilder(
                  animation: _hold,
                  builder: (context, _) => SizedBox.square(
                    dimension: 110,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox.expand(
                          child: CircularProgressIndicator(
                            value: _hold.value,
                            strokeWidth: 10,
                            color: MixoColors.sun,
                            backgroundColor: Colors.white24,
                          ),
                        ),
                        const Icon(Icons.touch_app_rounded, size: 48),
                      ],
                    ),
                  ),
                ),
              ),
            ] else ...[
              Text(
                '$_a × $_b = ?',
                key: const Key('gate-question'),
                style: const TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                width: 160,
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black26,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _wrong ? MixoColors.candy : Colors.white24,
                    width: 2,
                  ),
                ),
                child: Text(
                  _answer.isEmpty ? ' ' : _answer,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              if (_wrong)
                Text(
                  l.gateWrong,
                  style: const TextStyle(color: MixoColors.candy),
                ),
              const SizedBox(height: 8),
              _Pad(
                onDigit: _digit,
                onBack: () => setState(
                  () => _answer = _answer.isEmpty
                      ? ''
                      : _answer.substring(0, _answer.length - 1),
                ),
                onOk: _answer.isEmpty ? null : _submit,
              ),
            ],
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(l.cancel),
            ),
          ],
        ),
      ),
    );
  }
}

class _Pad extends StatelessWidget {
  const _Pad({required this.onDigit, required this.onBack, required this.onOk});

  final void Function(String) onDigit;
  final VoidCallback onBack;
  final VoidCallback? onOk;

  @override
  Widget build(BuildContext context) {
    Widget key(Widget child, VoidCallback? onTap, {Key? k}) => Padding(
      padding: const EdgeInsets.all(4),
      child: SizedBox(
        width: 64,
        height: 56,
        child: FilledButton.tonal(
          key: k,
          style: FilledButton.styleFrom(padding: EdgeInsets.zero),
          onPressed: onTap,
          child: child,
        ),
      ),
    );
    Widget digit(String d) => key(
      Text(
        d,
        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
      ),
      () => onDigit(d),
      k: Key('gate-digit-$d'),
    );
    return Column(
      children: [
        for (final row in const [
          ['1', '2', '3'],
          ['4', '5', '6'],
          ['7', '8', '9'],
        ])
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [for (final d in row) digit(d)],
          ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            key(const Icon(Icons.backspace_rounded), onBack),
            digit('0'),
            key(
              const Icon(Icons.check_rounded, size: 30),
              onOk,
              k: const Key('gate-ok'),
            ),
          ],
        ),
      ],
    );
  }
}
