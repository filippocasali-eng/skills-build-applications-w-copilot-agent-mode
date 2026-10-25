/// Records and replays packed input frames. With the deterministic
/// simulation, (level, seed, loadout, frames) reproduces a run exactly:
/// the basis for ghosts, attract mode and future rollback netcode.
class InputRecorder {
  final List<int> frames = [];

  void add(int packed) => frames.add(packed);

  /// Compact run-length encoding: [value, count, value, count, ...].
  List<int> encode() {
    final out = <int>[];
    for (final f in frames) {
      if (out.length >= 2 && out[out.length - 2] == f) {
        out[out.length - 1]++;
      } else {
        out
          ..add(f)
          ..add(1);
      }
    }
    return out;
  }

  static List<int> decode(List<int> rle) {
    final out = <int>[];
    for (var i = 0; i + 1 < rle.length; i += 2) {
      for (var k = 0; k < rle[i + 1]; k++) {
        out.add(rle[i]);
      }
    }
    return out;
  }
}

/// A recorded run plus what is needed to reproduce it.
class Replay {
  const Replay({
    required this.levelId,
    required this.seed,
    required this.frames,
    this.hero = 'roxy',
    this.score = 0,
    this.ghost = const [],
  });

  factory Replay.fromJson(Map<String, dynamic> j) => Replay(
    levelId: j['level'] as String,
    seed: j['seed'] as int,
    hero: j['hero'] as String? ?? 'roxy',
    score: j['score'] as int? ?? 0,
    frames: InputRecorder.decode([
      for (final v in j['input'] as List<dynamic>) v as int,
    ]),
    ghost: [
      for (final v in (j['ghost'] as List<dynamic>? ?? const []))
        (v as num).toDouble(),
    ],
  );

  final String levelId;
  final int seed;
  final String hero;
  final int score;
  final List<int> frames;

  /// Sampled player path: x0,y0,a0, x1,y1,a1, ... every [ghostStride] ticks.
  final List<double> ghost;

  static const ghostStride = 4;

  Map<String, Object> toJson() {
    final r = InputRecorder()..frames.addAll(frames);
    return {
      'level': levelId,
      'seed': seed,
      'hero': hero,
      'score': score,
      'input': r.encode(),
      'ghost': [for (final v in ghost) (v * 10).round() / 10],
    };
  }
}
