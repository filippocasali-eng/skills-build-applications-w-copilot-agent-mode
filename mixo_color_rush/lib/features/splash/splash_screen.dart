import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../core/models/run_result.dart';
import '../../core/profile_controller.dart';
import '../../core/widgets/mixo_avatar.dart';
import '../home/home_screen.dart';
import '../play/play_screen.dart';

/// Short splash (< 2 s). First launch goes straight to the played
/// onboarding; afterwards to Home.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({
    super.key,
    this.duration = const Duration(milliseconds: 1100),
  });

  final Duration duration;

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(widget.duration, _go);
  }

  void _go() {
    if (!mounted) return;
    final onboarded = ref.read(profileProvider).onboardingDone;
    final nav = Navigator.of(context);
    unawaited(
      nav.pushReplacement(
        MaterialPageRoute<void>(builder: (_) => const HomeScreen()),
      ),
    );
    if (!onboarded) {
      unawaited(
        nav.push(
          MaterialPageRoute<void>(
            builder: (_) => const PlayScreen(mode: GameMode.onboarding),
          ),
        ),
      );
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: DecoratedBox(
        decoration: mixoBackground,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              MixoAvatar(size: 180),
              Text(
                'MIXO',
                style: TextStyle(
                  fontSize: 64,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 6,
                  color: MixoColors.sun,
                  shadows: [Shadow(blurRadius: 16, color: MixoColors.candy)],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
