import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_commando/game/sim/balance.dart';

void main() {
  const path = 'assets/data/balance.json';

  test('balance.json matches the code defaults (regenerate with '
      'UPDATE_BALANCE=1 flutter test)', () {
    final json = const JsonEncoder.withIndent('  ')
        .convert(const Balance().toJson());
    if (Platform.environment['UPDATE_BALANCE'] == '1') {
      File(path).writeAsStringSync('$json\n');
    }
    final onDisk = jsonDecode(File(path).readAsStringSync());
    expect(onDisk, jsonDecode(json));
  });

  test('JSON round-trip and overrides', () {
    final b = Balance.fromJson({
      ...const Balance().toJson(),
      'jumpSpeed': 10,
      'weapons': {
        'spread': {'pellets': 7},
      },
      'ranked_allow_paid_upgrades': false,
    });
    expect(b.jumpSpeed, 10);
    expect(b.weapons[WeaponKind.spread]!.pellets, 7);
    expect(b.weapons[WeaponKind.spread]!.ammo, 40, reason: 'default kept');
    expect(b.rankedAllowPaidUpgrades, isFalse);
  });

  test('golden rule: every enemy attack has a tell of at least 300 ms', () {
    for (final e in const Balance().enemies.entries) {
      expect(e.value.tell, greaterThanOrEqualTo(18), reason: e.key);
    }
  });
}
