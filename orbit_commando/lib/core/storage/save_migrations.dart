/// Save-game schema migrations.
///
/// The save is a plain JSON-like map stored in Hive. Each migration upgrades
/// the map from version N to N+1. Never edit an existing migration once it has
/// shipped: add a new one and bump [currentSchemaVersion].
typedef Migration = Map<String, dynamic> Function(Map<String, dynamic> data);

const int currentSchemaVersion = 1;
const String schemaVersionKey = 'schemaVersion';

final Map<int, Migration> migrations = {
  // 0 -> 1: initial layout.
  0: (d) => {
    ...d,
    'settings': d['settings'] ?? <String, dynamic>{},
    'progress': d['progress'] ?? <String, dynamic>{},
  },
};

/// Applies every pending migration to [data] and returns the upgraded map.
/// Throws [StateError] for saves newer than this build (downgrade).
Map<String, dynamic> migrate(
  Map<String, dynamic> data, {
  int target = currentSchemaVersion,
  Map<int, Migration>? steps,
}) {
  final table = steps ?? migrations;
  var version = data[schemaVersionKey] as int? ?? 0;
  if (version > target) {
    throw StateError('Save version $version is newer than supported $target');
  }
  var out = Map<String, dynamic>.of(data);
  while (version < target) {
    final step = table[version];
    if (step == null) {
      throw StateError('Missing migration $version -> ${version + 1}');
    }
    out = step(out);
    version++;
    out[schemaVersionKey] = version;
  }
  return out;
}
