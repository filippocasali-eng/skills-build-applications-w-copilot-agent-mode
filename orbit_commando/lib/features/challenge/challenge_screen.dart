import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/ui/pixel.dart';
import '../../app/ui/route.dart';
import '../../core/campaign.dart';
import '../../core/progress/progress.dart';
import '../../core/social/challenge.dart';
import '../../engine/render/palette.g.dart';
import '../../game/roster.dart';
import '../../l10n/app_localizations.dart';
import '../play/play_screen.dart';
import '../run/run.dart';

/// Orbit of the Day and friends' challenge codes.
class ChallengeScreen extends ConsumerStatefulWidget {
  const ChallengeScreen({super.key, this.initialCode});

  final String? initialCode;

  @override
  ConsumerState<ChallengeScreen> createState() => _ChallengeScreenState();
}

class _ChallengeScreenState extends ConsumerState<ChallengeScreen> {
  late final TextEditingController _code = TextEditingController(
    text: widget.initialCode ?? '',
  );
  bool _invalid = false;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Commando _hero() {
    final sel = ref.read(progressProvider).selectedHero;
    return Commando.values.firstWhere(
      (h) => h.atlas == sel,
      orElse: () => Commando.roxy,
    );
  }

  Future<void> _daily() async {
    final c = await ref.read(campaignProvider.future);
    if (!mounted) return;
    Navigator.of(context).push(
      PixelRoute(PlayScreen(run: RunSpec.daily(c, _hero(), DateTime.now()))),
    );
  }

  Future<void> _play() async {
    final ch = Challenge.decode(_code.text);
    if (ch == null) {
      setState(() => _invalid = true);
      return;
    }
    final c = await ref.read(campaignProvider.future);
    if (!mounted) return;
    Navigator.of(context)
        .push(PixelRoute(PlayScreen(run: RunSpec.fromChallenge(c, ch))));
  }

  Future<void> _paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text ?? '';
    // Pull the code out of a whole shared message.
    final m = RegExp(r'OC[\s\-]?[0-9A-Za-z]{5}[\s\-]?[0-9A-Za-z]{5}')
        .firstMatch(text);
    setState(() {
      _code.text = m?.group(0) ?? text.trim();
      _invalid = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final now = DateTime.now();
    final left = Daily.dayEnd(now).difference(now);
    final day = Daily.dayIndex(now);
    return PixelScreen(
      title: l.menuChallenges,
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          PixelPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                PixelText(
                  '${l.menuDaily}  #$day',
                  scale: 1.4,
                  color: Pal.gold6,
                ),
                const SizedBox(height: 4),
                PixelText(l.dailyDesc, scale: 0.8, color: Pal.ink6),
                PixelText(
                  l.refreshesIn('${left.inHours}h ${left.inMinutes % 60}m'),
                  scale: 0.8,
                  color: Pal.aqua6,
                ),
                const SizedBox(height: 8),
                PixelButton(
                  label: l.play,
                  scale: 1.3,
                  autofocus: true,
                  onPressed: _daily,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          PixelPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                PixelText(l.challengeCodeTitle, scale: 1.2, color: Pal.neon6),
                const SizedBox(height: 4),
                PixelText(l.challengeCodeHint, scale: 0.8, color: Pal.ink6),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _code,
                        textCapitalization: TextCapitalization.characters,
                        style: PixelText.style(scale: 1.4, color: Pal.ink7),
                        cursorColor: Pal.gold6,
                        decoration: const InputDecoration(
                          isDense: true,
                          filled: true,
                          fillColor: Pal.ink0,
                          hintText: 'OC-XXXXX-XXXXX',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.zero,
                          ),
                        ),
                        onChanged: (_) => setState(() => _invalid = false),
                        onSubmitted: (_) => _play(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    PixelButton(label: l.paste, onPressed: _paste),
                    const SizedBox(width: 8),
                    PixelButton(
                      label: l.play,
                      color: Pal.neon6,
                      onPressed: _play,
                    ),
                  ],
                ),
                if (_invalid) ...[
                  const SizedBox(height: 6),
                  PixelText(l.challengeInvalid, color: Pal.ember6),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
