import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_commando/engine/render/bitmap_font.dart';
import 'package:orbit_commando/engine/render/palette.g.dart';
import 'package:orbit_commando/engine/render/sprite_atlas.dart';
import 'package:orbit_commando/game/game_resources.dart';
import 'package:orbit_commando/game/roster.dart';

Map<String, dynamic> _json(String path) =>
    jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;

void main() {
  group('palette', () {
    test('has 64 unique opaque colours', () {
      expect(Pal.all.length, 64);
      expect(Pal.all.toSet().length, 64);
      expect(Pal.all.every((c) => c.a == 1.0), isTrue);
    });
  });

  group('sprite atlases', () {
    for (final name in GameResources.atlasNames) {
      test('$name.json parses and its image exists', () {
        final data = AtlasData.fromJson(_json('assets/sprites/$name.json'));
        expect(File('assets/sprites/${data.image}').existsSync(), isTrue);
        expect(data.frames, isNotEmpty);
        expect(data.animations, isNotEmpty);
      });
    }

    for (final id in [
      ...Commando.values.map((h) => h.atlas),
      ...EnemyKind.values.map((e) => e.atlas),
    ]) {
      test('$id has the character animations, feet on the last row', () {
        final data = AtlasData.fromJson(_json('assets/sprites/$id.json'));
        expect(data.animations.keys, containsAll(requiredCharacterAnimations));
        expect(data.animations['run']!.frames.length, 4);
        expect(data.animations['attack']!.frames.length, 4);
        expect(data.frames.length, 8);
        final h = data.frames.first.height;
        expect(data.origin.dy, h - 1);
        // Characters are sized for the 640x360 screen (~19% of its height).
        expect(h, inInclusiveRange(60, 90));
      });
    }

    test('rejects animations pointing at missing frames', () {
      expect(
        () => AtlasData.fromJson({
          'version': 1,
          'image': 'x.png',
          'origin': {'x': 0, 'y': 0},
          'frames': [
            {'x': 0, 'y': 0, 'w': 8, 'h': 8},
          ],
          'animations': {
            'a': {
              'frames': [3],
              'fps': 1,
              'loop': true,
            },
          },
        }),
        throwsFormatException,
      );
    });
  });

  group('bitmap font', () {
    final font = BitmapFontData.fromJson(_json('assets/fonts/orbit5.json'));

    test('covers every character of every localised string', () {
      for (final f in Directory('lib/l10n').listSync()) {
        if (!f.path.endsWith('.arb')) continue;
        final arb = _json(f.path);
        arb.forEach((key, value) {
          if (key.startsWith('@') || value is! String) return;
          // Strip ICU placeholders like {count}.
          final text = value.replaceAll(RegExp(r'\{[^}]*\}'), '');
          expect(
            font.supports(text),
            isTrue,
            reason: '${f.path}:$key "$value" has unsupported glyphs',
          );
        });
      }
    });

    test('supports Italian accented capitals', () {
      expect(font.supports('più città perché è così'), isTrue);
    });

    test('measure adds 1px spacing between glyphs', () {
      expect(font.measure(''), 0);
      expect(font.measure('A'), 5);
      expect(font.measure('AA'), 11);
      expect(font.measure('aa'), 11);
    });
  });
}
