import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../core/models/run_result.dart';
import '../../core/profile_controller.dart';
import '../../core/widgets/common.dart';
import '../../l10n/content.dart';
import '../../l10n/generated/app_localizations.dart';
import '../home/home_screen.dart';
import '../play/mechanic_text.dart';
import 'lessons.dart';

/// Academy map: 8 short lessons, unlocked one after the other.
class AcademyScreen extends ConsumerWidget {
  const AcademyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final p = ref.watch(profileProvider);
    final content = ContentText(Localizations.localeOf(context).languageCode);
    return MixoPage(
      title: l.academy,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        itemCount: Lessons.all.length,
        itemBuilder: (context, i) {
          final lesson = Lessons.all[i];
          final unlocked = Lessons.unlocked(p.academyStars, i);
          final stars = p.academyStars[i] ?? 0;
          final left = i.isEven;
          return Padding(
            padding: EdgeInsets.only(
              left: left ? 0 : 60,
              right: left ? 60 : 0,
              bottom: 14,
            ),
            child: Material(
              color: unlocked ? const Color(0xFF00897B) : Colors.black38,
              borderRadius: BorderRadius.circular(28),
              child: InkWell(
                key: Key('lesson-$i'),
                borderRadius: BorderRadius.circular(28),
                onTap: unlocked ? () => _openLesson(context, i, content) : null,
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 28,
                        backgroundColor: unlocked
                            ? MixoColors.sun
                            : Colors.white24,
                        child: unlocked
                            ? Text(
                                '${i + 1}',
                                style: const TextStyle(
                                  fontSize: 26,
                                  fontWeight: FontWeight.w900,
                                  color: MixoColors.ink,
                                ),
                              )
                            : const Icon(
                                Icons.lock_rounded,
                                color: Colors.white,
                              ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              content.lessonTitle(i),
                              style: const TextStyle(
                                fontSize: 19,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            Row(
                              children: [
                                for (var s = 0; s < 3; s++)
                                  Icon(
                                    s < stars
                                        ? Icons.star_rounded
                                        : Icons.star_border_rounded,
                                    color: MixoColors.sun,
                                    size: 22,
                                  ),
                                if (lesson.mandatory && stars == 0) ...[
                                  const SizedBox(width: 6),
                                  Flexible(
                                    child: Text(
                                      l.mandatory,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        color: Colors.white70,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _openLesson(
    BuildContext context,
    int i,
    ContentText content,
  ) async {
    final l = AppLocalizations.of(context);
    final lesson = Lessons.all[i];
    final go = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: MixoColors.violet,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                content.lessonTitle(i),
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 12),
              if (lesson.mechanic != null)
                MechanicVisual(mechanic: lesson.mechanic!),
              const SizedBox(height: 12),
              Text(
                content.lessonDesc(i),
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 19),
              ),
              const SizedBox(height: 20),
              BigButton(
                key: const Key('lesson-start'),
                label: l.play,
                icon: Icons.play_arrow_rounded,
                onPressed: () => Navigator.of(context).pop(true),
              ),
            ],
          ),
        ),
      ),
    );
    if (go == true && context.mounted) {
      startMode(context, GameMode.academy, lesson: i);
    }
  }
}
