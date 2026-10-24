import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:orbit_commando/core/storage/save_migrations.dart';
import 'package:orbit_commando/core/storage/save_store.dart';

void main() {
  group('migrate', () {
    test('empty save is upgraded to the current schema', () {
      final out = migrate({});
      expect(out[schemaVersionKey], currentSchemaVersion);
      expect(out['settings'], isA<Map<String, dynamic>>());
    });

    test('runs steps in order and keeps unknown data', () {
      final out = migrate(
        {'keep': 1},
        target: 2,
        steps: {
          0: (d) => {...d, 'a': 1},
          1: (d) => {...d, 'b': (d['a'] as int) + 1},
        },
      );
      expect(out, {'keep': 1, 'a': 1, 'b': 2, schemaVersionKey: 2});
    });

    test('refuses saves from a newer build', () {
      expect(
        () => migrate({schemaVersionKey: currentSchemaVersion + 1}),
        throwsStateError,
      );
    });

    test('fails loudly on a gap in the migration table', () {
      expect(
        () => migrate({}, target: 2, steps: {0: (d) => d}),
        throwsStateError,
      );
    });
  });

  group('SaveStore', () {
    late Directory dir;

    setUp(() async {
      dir = await Directory.systemTemp.createTemp('orbit_save');
      Hive.init(dir.path);
    });

    tearDown(() async {
      await Hive.close();
      await dir.delete(recursive: true);
    });

    test('persists sections across reopen', () async {
      final s1 = await SaveStore.open();
      expect(s1.schemaVersion, currentSchemaVersion);
      s1.section('progress')['world1'] = 3;
      await s1.flush();
      await Hive.close();

      Hive.init(dir.path);
      final s2 = await SaveStore.open();
      expect(s2.section('progress')['world1'], 3);
    });
  });
}
