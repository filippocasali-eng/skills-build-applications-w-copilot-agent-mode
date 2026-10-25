import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_commando/app/ui/atlas_sprite.dart';

/// Runs before every test file: each test starts with empty asset caches, so
/// a load left pending by the previous test's fake clock is never awaited.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    rootBundle.clear();
    AtlasCache.clear();
  });
  await testMain();
}
