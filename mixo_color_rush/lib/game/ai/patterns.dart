import 'dart:convert';

/// One lane token of a pattern row.
///
/// Patterns are abstract: colours are chosen when the pattern is
/// instantiated, from the colour Mixo is *planned* to have.
enum PatternToken {
  /// `.` free lane.
  empty('.'),

  /// `T` gate of the planned colour.
  target('T'),

  /// `N` gate of another colour (decoy).
  decoy('N'),

  /// `O` tall obstacle.
  obstacle('O'),

  /// `o` low obstacle (jumpable).
  lowObstacle('o'),

  /// `d` primary drop that changes the planned colour.
  mixDrop('d'),

  /// `b` trap drop: would turn Mixo brown (or into a wrong colour).
  badDrop('b'),

  /// `W` white drop: back to the base colour.
  white('W'),

  /// `R` rainbow drop: pass any gate for 3 s.
  rainbow('R'),

  /// `I` invert drop: complementary colour.
  invert('I');

  const PatternToken(this.char);

  final String char;

  static PatternToken parse(String c) => values.firstWhere(
    (t) => t.char == c,
    orElse: () => throw FormatException('Unknown pattern token "$c"'),
  );

  bool get isDrop =>
      this == mixDrop ||
      this == badDrop ||
      this == white ||
      this == rainbow ||
      this == invert;
}

/// Gameplay features a pattern needs to be enabled.
enum PatternFeature { drops, obstacles, mix, special, jump }

class PatternRow {
  const PatternRow(this.tokens, this.gap);

  final List<PatternToken> tokens;

  /// Multiplier of the base row gap before this row.
  final double gap;
}

/// A short hand-authored track segment (~3 s), always 3 lanes wide.
class Pattern {
  const Pattern({
    required this.id,
    required this.tier,
    required this.requires,
    required this.rows,
  });

  factory Pattern.fromJson(Map<String, Object?> j) {
    final rows = (j['rows']! as List<Object?>).cast<String>();
    final gaps = (j['gaps'] as List<Object?>?)?.cast<num>();
    return Pattern(
      id: j['id']! as String,
      tier: (j['tier']! as num).toInt(),
      requires: {
        for (final r in (j['req'] as List<Object?>? ?? const []).cast<String>())
          PatternFeature.values.byName(r),
      },
      rows: [
        for (var i = 0; i < rows.length; i++)
          PatternRow([
            for (final c in rows[i].split('')) PatternToken.parse(c),
          ], gaps == null ? 1 : gaps[i].toDouble()),
      ],
    );
  }

  static const int lanes = 3;

  final String id;
  final int tier;
  final Set<PatternFeature> requires;
  final List<PatternRow> rows;
}

/// All patterns, loaded from `assets/data/patterns/*.json`.
class PatternLibrary {
  PatternLibrary(this.patterns) {
    for (final p in patterns) {
      for (final r in p.rows) {
        if (r.tokens.length != Pattern.lanes) {
          throw FormatException('Pattern ${p.id}: rows must have 3 lanes');
        }
      }
    }
  }

  /// Parses one or more JSON documents of the form `{"patterns": [...]}`.
  factory PatternLibrary.fromJsonStrings(Iterable<String> docs) {
    final out = <Pattern>[];
    for (final doc in docs) {
      final j = jsonDecode(doc) as Map<String, Object?>;
      for (final p in (j['patterns']! as List<Object?>)) {
        out.add(Pattern.fromJson((p! as Map<Object?, Object?>).cast()));
      }
    }
    return PatternLibrary(out);
  }

  /// Asset paths of the pattern files.
  static const assetFiles = [
    'assets/data/patterns/basic.json',
    'assets/data/patterns/drops.json',
    'assets/data/patterns/obstacles.json',
    'assets/data/patterns/mix.json',
    'assets/data/patterns/specials.json',
    'assets/data/patterns/expert.json',
  ];

  final List<Pattern> patterns;
}
