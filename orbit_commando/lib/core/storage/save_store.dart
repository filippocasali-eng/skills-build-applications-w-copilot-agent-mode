import 'dart:convert';

import 'package:hive/hive.dart';

import 'save_migrations.dart';

/// Persistent save data. Stored as a single JSON document in a Hive box so
/// migrations stay simple, plain-map transformations.
class SaveStore {
  SaveStore._(this._box, this._data);

  static const _boxName = 'orbit_save';
  static const _key = 'save';

  final Box<String> _box;
  final Map<String, dynamic> _data;

  /// Opens the box (call `Hive.initFlutter()` or `Hive.init(path)` first)
  /// and migrates the stored save to the current schema.
  static Future<SaveStore> open() async {
    final box = await Hive.openBox<String>(_boxName);
    final raw = box.get(_key);
    final decoded = raw == null
        ? <String, dynamic>{}
        : jsonDecode(raw) as Map<String, dynamic>;
    final store = SaveStore._(box, migrate(decoded));
    if (decoded[schemaVersionKey] != currentSchemaVersion) await store.flush();
    return store;
  }

  int get schemaVersion => _data[schemaVersionKey] as int;

  Map<String, dynamic> section(String name) =>
      _data.putIfAbsent(name, () => <String, dynamic>{})
          as Map<String, dynamic>;

  Future<void> flush() => _box.put(_key, jsonEncode(_data));
}
