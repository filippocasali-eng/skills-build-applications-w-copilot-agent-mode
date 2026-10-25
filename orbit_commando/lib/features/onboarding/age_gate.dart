import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/ui/pixel.dart';
import '../../core/profile/profile.dart';
import '../../engine/render/palette.g.dart';
import '../../l10n/app_localizations.dart';

/// Neutral age gate on first launch: year and month, no default that
/// nudges towards "adult".
class AgeGate extends ConsumerStatefulWidget {
  const AgeGate({super.key, required this.onDone});

  final VoidCallback onDone;

  @override
  ConsumerState<AgeGate> createState() => _AgeGateState();
}

class _AgeGateState extends ConsumerState<AgeGate> {
  int? _year;
  int? _month;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final now = DateTime.now().year;
    return Scaffold(
      backgroundColor: Pal.space0,
      body: Stack(
        children: [
          Center(
            child: PixelPanel(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  PixelText(l.ageGateTitle, scale: 1.6, color: Pal.gold6),
                  SizedBox(
                    width: 420,
                    child: PixelText(
                      l.ageGateBody,
                      scale: 0.8,
                      align: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: 420,
                    child: PixelChoice<int?>(
                      label: l.year,
                      value: _year,
                      options: {
                        null: '----',
                        for (var y = now; y >= now - 100; y--) y: '$y',
                      },
                      onChanged: (v) => setState(() => _year = v),
                    ),
                  ),
                  SizedBox(
                    width: 420,
                    child: PixelChoice<int?>(
                      label: l.month,
                      value: _month,
                      options: {
                        null: '--',
                        for (var m = 1; m <= 12; m++)
                          m: m.toString().padLeft(2, '0'),
                      },
                      onChanged: (v) => setState(() => _month = v),
                    ),
                  ),
                  const SizedBox(height: 10),
                  PixelButton(
                    label: l.confirm,
                    autofocus: true,
                    enabled: _year != null && _month != null,
                    onPressed: () async {
                      await ref
                          .read(profileProvider.notifier)
                          .set(
                            (p) => p.copyWith(
                              birthYear: _year,
                              birthMonth: _month,
                            ),
                          );
                      widget.onDone();
                    },
                  ),
                ],
              ),
            ),
          ),
          const Scanlines(),
        ],
      ),
    );
  }
}
