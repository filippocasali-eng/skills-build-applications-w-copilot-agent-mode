import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/ui/pixel.dart';
import '../../app/ui/route.dart';
import '../../core/ads/ad_provider.dart';
import '../../core/analytics/analytics.dart';
import '../../core/audio/audio.dart';
import '../../core/campaign.dart';
import '../../core/monetization/wallet.dart';
import '../../core/progress/progress.dart';
import '../../core/settings/settings.dart';
import '../../core/social/share.dart';
import '../../engine/render/palette.g.dart';
import '../../game/levels/level_data.dart';
import '../../game/play_config.dart';
import '../../game/sim/game_sim.dart';
import '../../l10n/app_localizations.dart';
import '../play/play_screen.dart';
import '../run/run.dart';
import '../share/share_card.dart';

/// End-of-level tally: points count up "tic-tic-tic", then the rank is
/// stamped, then medals and rewards.
class ResultsScreen extends ConsumerStatefulWidget {
  const ResultsScreen({
    super.key,
    required this.run,
    required this.result,
    required this.rewards,
    required this.level,
  });

  final RunSpec run;
  final LevelResult result;
  final LevelRewards rewards;
  final LevelData level;

  @override
  ConsumerState<ResultsScreen> createState() => _ResultsScreenState();
}

class _ResultsScreenState extends ConsumerState<ResultsScreen> {
  int _shownScore = 0, _shownTime = 0, _shownNoDeath = 0, _shownTotal = 0;
  bool _stamped = false;
  bool _doubled = false;
  final GlobalKey _cardKey = GlobalKey();
  String _code = '';
  bool _sharing = false;
  Timer? _timer;

  LevelResult get r => widget.result;

  @override
  void initState() {
    super.initState();
    _tally();
    _makeCode();
  }

  Future<void> _makeCode() async {
    final c = await ref.read(campaignProvider.future);
    if (!mounted) return;
    setState(() => _code = widget.run.challengeFor(c, r.total).encode());
  }

  Future<void> _share() async {
    if (_sharing || _code.isEmpty) return;
    setState(() => _sharing = true);
    final l = AppLocalizations.of(context);
    final png = await ShareCard.capture(_cardKey);
    if (png != null) {
      ref.read(analyticsProvider).log('share_score', {
        'level': widget.level.id,
        'mode': widget.run.mode.name,
      });
      await ref
          .read(shareServiceProvider)
          .sharePng(png, '${l.shareText(r.total, _code)}\n$kStoreUrl');
    }
    if (mounted) setState(() => _sharing = false);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _tally() {
    final audio = ref.read(audioProvider);
    var phase = 0;
    _timer = Timer.periodic(const Duration(milliseconds: 30), (t) {
      if (!mounted) return;
      int step(int shown, int target) {
        // Ease out, but never slower than ~25 ticks per line.
        final d = ((target - shown) / 4).ceil().clamp(
          (target / 25).ceil().clamp(1, 1 << 30),
          1 << 30,
        );
        return shown + d > target ? target : shown + d;
      }

      setState(() {
        switch (phase) {
          case 0:
            _shownScore = step(_shownScore, r.score);
            if (_shownScore == r.score) phase = 1;
          case 1:
            _shownTime = step(_shownTime, r.timeBonus);
            if (_shownTime == r.timeBonus) phase = 2;
          case 2:
            _shownNoDeath = step(_shownNoDeath, r.noDeathBonus);
            if (_shownNoDeath == r.noDeathBonus) phase = 3;
          case 3:
            _shownTotal = step(_shownTotal, r.total);
            if (_shownTotal == r.total) phase = 4;
          default:
            t.cancel();
            _stamped = true;
            audio.sfx(Sfx.stamp);
        }
      });
      if (phase < 4 && t.tick % 2 == 0) audio.sfx(Sfx.tick);
    });
  }

  void _skip() {
    if (_stamped) return;
    _timer?.cancel();
    setState(() {
      _shownScore = r.score;
      _shownTime = r.timeBonus;
      _shownNoDeath = r.noDeathBonus;
      _shownTotal = r.total;
      _stamped = true;
    });
  }

  Future<void> _doubleTokens() async {
    final ok = await ref.read(adProvider).showRewarded('double_tokens');
    if (!ok) return;
    await ref.read(progressProvider.notifier).addTokens(widget.rewards.tokens);
    setState(() => _doubled = true);
  }

  Future<void> _next() async {
    final run = widget.run;
    final wallet = ref.read(walletProvider);
    if (!wallet.fullCartridge &&
        ref.read(interstitialPolicyProvider).onLevelComplete()) {
      await ref.read(adProvider).showInterstitial('level_complete');
    }
    if (!mounted) return;
    final nav = Navigator.of(context);
    if (run.mode != GameMode.campaign && !run.isLast) {
      run.index++;
      nav.pushReplacement(PixelRoute(PlayScreen(run: run)));
      return;
    }
    final table = run.scoreTable;
    if (table != null) {
      if (run.mode == GameMode.arcade) {
        await ref.read(progressProvider.notifier).unlockTrophy('arcade_clear');
      } else if (run.mode == GameMode.bossRush) {
        await ref
            .read(progressProvider.notifier)
            .unlockTrophy('bossrush_clear');
      }
      if (ref.read(progressProvider).isHighScore(run.totalScore, table)) {
        nav.pushReplacement(
          PixelRoute(InitialsScreen(score: run.totalScore, table: table)),
        );
        return;
      }
    }
    nav.pop();
  }

  Widget _row(
    String label,
    int value, {
    Color color = Pal.ink7,
    double scale = 1,
  }) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(
      children: [
        SizedBox(
          width: 260,
          child: PixelText(label, scale: scale, color: Pal.ink6),
        ),
        SizedBox(
          width: 200,
          child: PixelText(
            '$value',
            scale: scale,
            color: color,
            align: TextAlign.right,
          ),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final rw = widget.rewards;
    final lang = Localizations.localeOf(context).languageCode;
    final rankColor = switch (r.rank) {
      'S' => Pal.gold6,
      'A' => Pal.moss6,
      'B' => Pal.aqua6,
      'C' => Pal.space6,
      _ => Pal.ink5,
    };
    final wallet = ref.watch(walletProvider);
    final campaignEnd =
        widget.level.id == 'w3_l5' && widget.run.mode == GameMode.campaign;
    return Scaffold(
      backgroundColor: Pal.space0,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _skip,
        child: Stack(
          children: [
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            PixelText(
                              l.stageClear,
                              scale: 2.2,
                              color: Pal.gold6,
                              shadow: Pal.ember2,
                            ),
                            PixelText(
                              widget.level.name,
                              scale: 1,
                              color: Pal.ink5,
                            ),
                            const SizedBox(height: 10),
                            _row(l.score, _shownScore),
                            _row(l.timeBonus, _shownTime),
                            _row(l.noDeathBonus, _shownNoDeath),
                            const SizedBox(height: 4),
                            _row(
                              l.total,
                              _shownTotal,
                              color: Pal.gold6,
                              scale: 1.4,
                            ),
                            const SizedBox(height: 10),
                            PixelText(
                              '${l.time} ${r.seconds ~/ 60}:${(r.seconds % 60).toString().padLeft(2, '0')}   '
                              '${l.hostages} ${r.hostagesFreed}/${r.hostagesTotal}   '
                              '${l.kills} ${r.kills}   '
                              '${l.maxCombo} x${r.maxCombo}',
                              scale: 0.8,
                              color: Pal.ink6,
                            ),
                            if (_stamped && widget.run.challenge != null) ...[
                              const SizedBox(height: 8),
                              PixelText(
                                r.total > widget.run.challenge!.target
                                    ? l.challengeBeaten
                                    : l.challengeLost,
                                scale: 1.1,
                                color: r.total > widget.run.challenge!.target
                                    ? Pal.moss6
                                    : Pal.ember6,
                              ),
                            ],
                            if (_stamped) ...[
                              const SizedBox(height: 10),
                              Wrap(
                                spacing: 8,
                                runSpacing: 6,
                                children: [
                                  if (r.medalNoDeath)
                                    _medal(l.medalNoDeath, Pal.gold6),
                                  if (r.medalAllHostages)
                                    _medal(l.medalHostages, Pal.aqua6),
                                  if (r.medalSpeedrun(widget.level.parTime))
                                    _medal(l.medalSpeedrun, Pal.ember6),
                                ],
                              ),
                              const SizedBox(height: 8),
                              if (rw.newRecord)
                                PixelText(l.newRecord, color: Pal.gold7),
                              PixelText(
                                l.earnedTokens(
                                  _doubled ? rw.tokens * 2 : rw.tokens,
                                ),
                                color: Pal.gold6,
                              ),
                              if (rw.creditEarned)
                                PixelText(l.earnedCredit, color: Pal.moss6),
                              for (final u in rw.unlocks)
                                PixelText(switch (u) {
                                  'arcade' => l.unlockedArcade,
                                  'bossrush' => l.unlockedBossRush,
                                  _ => l.unlockedHero(
                                    u.split(':').last.toUpperCase(),
                                  ),
                                }, color: Pal.neon6),
                              for (final t in rw.trophies)
                                PixelText(
                                  l.trophyUnlocked(t.title(lang)),
                                  color: Pal.aqua6,
                                ),
                              if (campaignEnd) ...[
                                const SizedBox(height: 8),
                                SizedBox(
                                  width: 520,
                                  child: PixelText(
                                    l.campaignComplete,
                                    color: Pal.ink7,
                                  ),
                                ),
                              ],
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  PixelButton(
                                    label: l.next,
                                    autofocus: true,
                                    scale: 1.3,
                                    onPressed: _next,
                                  ),
                                  const SizedBox(width: 10),
                                  PixelButton(
                                    label: l.shareChallenge,
                                    color: Pal.neon6,
                                    enabled: _code.isNotEmpty && !_sharing,
                                    onPressed: _share,
                                  ),
                                  const SizedBox(width: 10),
                                  if (!_doubled &&
                                      !wallet.fullCartridge &&
                                      ref.read(adProvider).available)
                                    PixelButton(
                                      label: l.doubleTokensAd,
                                      scale: 0.8,
                                      onPressed: _doubleTokens,
                                    ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 200,
                      child: Column(
                        children: [
                          PixelText(l.rank, scale: 1.2, color: Pal.ink6),
                          AnimatedScale(
                            scale: _stamped ? 1 : 3,
                            duration: const Duration(milliseconds: 180),
                            curve: Curves.easeIn,
                            child: AnimatedOpacity(
                              opacity: _stamped ? 1 : 0,
                              duration: const Duration(milliseconds: 120),
                              child: Transform.rotate(
                                angle: -0.18,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                      color: rankColor,
                                      width: 6,
                                    ),
                                  ),
                                  child: PixelText(
                                    r.rank,
                                    scale: 8,
                                    color: rankColor,
                                    shadow: Pal.ink0,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                          if (_stamped && _code.isNotEmpty)
                            GestureDetector(
                              onTap: _share,
                              child: FittedBox(
                                child: RepaintBoundary(
                                  key: _cardKey,
                                  child: ShareCard(
                                    levelName: widget.level.name,
                                    score: r.total,
                                    rank: r.rank,
                                    maxCombo: r.maxCombo,
                                    code: _code,
                                    hero: widget.run.hero.atlas,
                                    tagline: l.shareCardBeat,
                                    comboLabel: l.maxCombo,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const Scanlines(),
          ],
        ),
      ),
    );
  }

  Widget _medal(String text, Color c) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
    decoration: BoxDecoration(
      color: Pal.ink1,
      border: Border.all(color: c, width: 2),
    ),
    child: PixelText(text, scale: 0.8, color: c),
  );
}

/// Arcade-cabinet initials entry: three letters, up/down to change.
class InitialsScreen extends ConsumerStatefulWidget {
  const InitialsScreen({super.key, required this.score, required this.table});

  final int score;
  final String table;

  @override
  ConsumerState<InitialsScreen> createState() => _InitialsScreenState();
}

class _InitialsScreenState extends ConsumerState<InitialsScreen> {
  static const _alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789.!';
  final List<int> _chars = [0, 0, 0];
  int _pos = 0;

  void _change(int d) {
    ref.read(audioProvider).sfx(Sfx.select);
    setState(() => _chars[_pos] = (_chars[_pos] + d) % _alphabet.length);
  }

  Future<void> _confirm() async {
    ref.read(audioProvider).sfx(Sfx.confirm);
    if (_pos < 2) {
      setState(() => _pos++);
      return;
    }
    final initials = _chars.map((c) => _alphabet[c]).join();
    await ref
        .read(progressProvider.notifier)
        .addHighScore(initials, widget.score, widget.table);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    ref.watch(settingsProvider);
    return Scaffold(
      backgroundColor: Pal.ink0,
      body: Stack(
        children: [
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                PixelText(
                  l.newRecord,
                  scale: 2,
                  color: Pal.gold6,
                  shadow: Pal.ember2,
                ),
                PixelText('${widget.score}', scale: 2, color: Pal.ink7),
                const SizedBox(height: 16),
                PixelText(l.enterInitials, color: Pal.ink6),
                const SizedBox(height: 12),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var i = 0; i < 3; i++)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        child: Column(
                          children: [
                            PixelButton(
                              label: '^',
                              onPressed: i == _pos ? () => _change(1) : null,
                            ),
                            i == _pos
                                ? Blink(
                                    child: PixelText(
                                      _alphabet[_chars[i]],
                                      scale: 4,
                                      color: Pal.gold7,
                                    ),
                                  )
                                : PixelText(
                                    _alphabet[_chars[i]],
                                    scale: 4,
                                    color: Pal.ink6,
                                  ),
                            PixelButton(
                              label: 'v',
                              onPressed: i == _pos ? () => _change(-1) : null,
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                PixelButton(
                  label: l.ok,
                  autofocus: true,
                  scale: 1.4,
                  onPressed: _confirm,
                ),
              ],
            ),
          ),
          const Scanlines(),
        ],
      ),
    );
  }
}
