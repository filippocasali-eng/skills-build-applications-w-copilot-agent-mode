import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../core/models/run_result.dart';
import '../../core/progression.dart';
import '../../game/ai/coach.dart';
import '../../l10n/content.dart';
import '../../l10n/generated/app_localizations.dart';
import '../missions/mission_text.dart';
import 'mechanic_text.dart';
import 'play_screen.dart';

/// Game over / results: score, record, animated XP bar, one coach tip,
/// missions and trophies, and a huge AGAIN button (one tap restart).
class ResultsPanel extends StatelessWidget {
  const ResultsPanel({
    super.key,
    required this.outcome,
    required this.mode,
    required this.onAgain,
    required this.onHome,
  });

  final RunOutcome outcome;
  final GameMode mode;
  final VoidCallback onAgain;
  final VoidCallback onHome;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final content = ContentText(Localizations.localeOf(context).languageCode);
    final r = outcome.result;
    final rw = outcome.rewards;
    return ColoredBox(
      color: Colors.black54,
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Container(
              padding: const EdgeInsets.all(20),
              constraints: const BoxConstraints(maxWidth: 440),
              decoration: BoxDecoration(
                color: MixoColors.violet,
                borderRadius: BorderRadius.circular(32),
                border: Border.all(color: Colors.white24, width: 2),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Details scroll; the AGAIN / Home buttons below stay
                  // visible however many rewards the run produced.
                  Flexible(
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (mode == GameMode.academy) ...[
                            Text(
                              r.completed ? l.lessonComplete : l.lessonFailed,
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w900,
                                color: MixoColors.sun,
                              ),
                            ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                for (var i = 0; i < 3; i++)
                                  Icon(
                                    i < (outcome.lessonStars ?? 0)
                                        ? Icons.star_rounded
                                        : Icons.star_border_rounded,
                                    size: 48,
                                    color: MixoColors.sun,
                                  ),
                              ],
                            ),
                          ],
                          if (rw.isRecord) _Banner(text: l.newRecord),
                          if (outcome.ghostBeaten) _Banner(text: l.ghostBeaten),
                          Text(l.score, style: const TextStyle(fontSize: 18)),
                          Text(
                            '${r.score}',
                            key: const Key('results-score'),
                            style: const TextStyle(
                              fontSize: 56,
                              fontWeight: FontWeight.w900,
                              height: 1.1,
                            ),
                          ),
                          if (mode == GameMode.daily &&
                              outcome.dailyBest != null)
                            Text(
                              l.dailyBest(outcome.dailyBest!),
                              style: const TextStyle(fontSize: 16),
                            )
                          else
                            Text(
                              l.best(outcome.bestScore),
                              style: const TextStyle(fontSize: 16),
                            ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 14,
                            alignment: WrapAlignment.center,
                            children: [
                              _Stat(
                                icon: Icons.timer_rounded,
                                text: l.timeLabel(r.durationMs ~/ 1000),
                              ),
                              _Stat(
                                icon: Icons.door_front_door_rounded,
                                text: '${r.gatesOk}',
                              ),
                              _Stat(
                                icon: Icons.bolt_rounded,
                                text: 'x${r.maxMultiplier}',
                              ),
                              _Stat(
                                icon: Icons.star_rounded,
                                text: '+${rw.starsGained}',
                                color: MixoColors.sun,
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          _XpBar(rewards: rw),
                          const SizedBox(height: 12),
                          _CoachBubble(tip: rw.tip),
                          for (final m in rw.completedMissions)
                            _Line(
                              icon: Icons.flag_rounded,
                              text:
                                  '${l.missionDone}: ${missionText(l, m)}  +${m.reward}★',
                            ),
                          for (final a in rw.newAchievements)
                            _Line(
                              icon: Icons.emoji_events_rounded,
                              text:
                                  '${content.achievementTitle(a)}  +${a.reward}★',
                            ),
                          for (final u in rw.newUnlocks)
                            _Line(
                              icon: Icons.lock_open_rounded,
                              text: '${l.unlocked}: ${content.item(u)}',
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 84,
                    child: FilledButton.icon(
                      key: const Key('again-button'),
                      onPressed: onAgain,
                      icon: const Icon(Icons.replay_rounded, size: 40),
                      label: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          l.again,
                          style: const TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    key: const Key('home-button'),
                    onPressed: onHome,
                    icon: const Icon(Icons.home_rounded),
                    label: Text(l.home, style: const TextStyle(fontSize: 18)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.5, end: 1),
      duration: const Duration(milliseconds: 600),
      curve: Curves.elasticOut,
      builder: (context, s, child) => Transform.scale(scale: s, child: child),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 26,
          fontWeight: FontWeight.w900,
          color: MixoColors.sun,
        ),
      ),
    );
  }
}

class _XpBar extends StatelessWidget {
  const _XpBar({required this.rewards});

  final RunRewards rewards;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final from = rewards.leveledUp
        ? 0.0
        : rewards.xpBefore / Progression.xpToNext(rewards.levelBefore);
    final to = rewards.xpAfter / Progression.xpToNext(rewards.levelAfter);
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              l.levelShort(rewards.levelAfter),
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
            ),
            Text(
              '+${rewards.xpGained} XP',
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                color: MixoColors.mint,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        TweenAnimationBuilder<double>(
          tween: Tween(begin: from, end: to),
          duration: const Duration(milliseconds: 1200),
          curve: Curves.easeOutCubic,
          builder: (context, v, _) => ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: v.clamp(0.0, 1.0),
              minHeight: 16,
              color: MixoColors.mint,
              backgroundColor: Colors.white24,
            ),
          ),
        ),
        if (rewards.leveledUp)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: _Banner(text: l.levelUp(rewards.levelAfter)),
          ),
      ],
    );
  }
}

class _CoachBubble extends StatelessWidget {
  const _CoachBubble({required this.tip});

  final CoachTip tip;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black26,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.lightbulb_rounded, color: MixoColors.sun),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  coachText(l, tip),
                  key: const Key('coach-tip'),
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          if (tip.kind == CoachTipKind.mixRecipe && tip.a != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: RecipeRow(a: tip.a!, b: tip.b!, result: tip.result!),
              ),
            ),
        ],
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        children: [
          Icon(icon, color: MixoColors.sun, size: 22),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({
    required this.icon,
    required this.text,
    this.color = Colors.white70,
  });

  final IconData icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(width: 4),
        Text(
          text,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}
