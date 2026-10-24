import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'storage/save_store.dart';

/// Overridden in main() once the save has been opened.
final saveStoreProvider = Provider<SaveStore>(
  (ref) => throw UnimplementedError('saveStoreProvider not overridden'),
);
