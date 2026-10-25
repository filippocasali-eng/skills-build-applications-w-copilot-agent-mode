import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/ui/pixel.dart';
import '../../app/ui/route.dart';
import '../../core/audio/audio.dart';
import '../../core/profile/profile.dart';
import '../../engine/render/palette.g.dart';
import '../../l10n/app_localizations.dart';
import '../title/title_screen.dart';
import 'age_gate.dart';

/// Studio logo with its 8-bit jingle (< 2 s), then age gate (first launch
/// only), then the title screen.
class Splash extends ConsumerStatefulWidget {
  const Splash({super.key});

  @override
  ConsumerState<Splash> createState() => _SplashState();
}

class _SplashState extends ConsumerState<Splash> {
  Timer? _t;

  @override
  void initState() {
    super.initState();
    ref.read(audioProvider).jingle(Jingle.studio);
    _t = Timer(const Duration(milliseconds: 1700), _next);
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  void _next() {
    if (!mounted) return;
    final nav = Navigator.of(context);
    if (!ref.read(profileProvider).ageKnown) {
      nav.pushReplacement(
        PixelRoute(
          AgeGate(
            onDone: () => nav.pushReplacement(PixelRoute(const TitleScreen())),
          ),
        ),
      );
    } else {
      nav.pushReplacement(PixelRoute(const TitleScreen()));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: Pal.ink0,
      body: GestureDetector(
        onTap: _next,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Pal.aqua5, width: 6),
                ),
                child: Center(
                  child: Container(width: 18, height: 18, color: Pal.gold6),
                ),
              ),
              const SizedBox(height: 12),
              const PixelText(
                'PIXEL ORBIT STUDIO',
                scale: 1.6,
                color: Pal.aqua6,
              ),
              PixelText(l.studioPresents, scale: 0.8, color: Pal.ink5),
            ],
          ),
        ),
      ),
    );
  }
}
