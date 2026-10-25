import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/ui/pixel.dart';
import '../../core/audio/audio.dart';
import '../../core/progress/progress.dart';
import '../../engine/render/palette.g.dart';
import '../../l10n/app_localizations.dart';

/// Juke-box: the chiptune soundtrack, unlocked with cassettes.
class JukeboxScreen extends ConsumerStatefulWidget {
  const JukeboxScreen({super.key});

  @override
  ConsumerState<JukeboxScreen> createState() => _JukeboxScreenState();
}

class _JukeboxScreenState extends ConsumerState<JukeboxScreen> {
  Track? _playing;

  static const _tracks = [
    (Track.title, 'ORBIT COMMANDO THEME', 0),
    (Track.world1, 'QUIET BELT SHUFFLE', 3),
    (Track.world2, 'PIZZA-STATION FUNK', 9),
    (Track.world3, 'GLORBO PRIME MARCH', 15),
    (Track.boss, 'FORM 27-B BOSS FIGHT', 21),
    (Track.victory, 'STAMPED: APPROVED', 27),
  ];

  @override
  void dispose() {
    ref.read(audioProvider).music(Track.title);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final tapes = ref.watch(progressProvider).totalCassettes;
    return PixelScreen(
      title: l.menuJukebox,
      trailing: PixelText(l.cassettesFound(tapes, 36), color: Pal.neon6),
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          for (final (i, (track, name, need)) in _tracks.indexed)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: PixelButton(
                label: tapes >= need ? '${i + 1}. $name' : '${i + 1}. ???',
                subtitle: tapes >= need
                    ? (_playing == track ? l.nowPlaying : null)
                    : '$need TAPES',
                width: double.infinity,
                autofocus: i == 0,
                enabled: tapes >= need,
                color: _playing == track ? Pal.gold7 : Pal.gold5,
                onPressed: () {
                  ref.read(audioProvider).music(track);
                  setState(() => _playing = track);
                },
              ),
            ),
        ],
      ),
    );
  }
}
