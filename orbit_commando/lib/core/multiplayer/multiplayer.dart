import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../engine/replay/replay.dart';
import '../providers.dart';
import '../storage/save_store.dart';

/// Ghosts and leaderboards. v1 races your own best ghost locally; v2 swaps
/// in an online implementation (see MULTIPLAYER_PLAN.md) without touching
/// the game code.
abstract interface class MultiplayerService {
  /// Best ghost for a board (e.g. "weekly42"), or null.
  Future<Replay?> bestGhost(String board);

  /// Submits a run; keeps it if it beats the stored one.
  Future<bool> submit(String board, Replay run);
}

class LocalGhostService implements MultiplayerService {
  LocalGhostService(this.store);

  final SaveStore store;

  Map<String, dynamic> get _ghosts => store.section('ghosts');

  @override
  Future<Replay?> bestGhost(String board) async {
    final j = _ghosts[board];
    return j is Map<String, dynamic> ? Replay.fromJson(j) : null;
  }

  @override
  Future<bool> submit(String board, Replay run) async {
    final old = await bestGhost(board);
    if (old != null && old.score >= run.score) return false;
    // Keep only the last few boards to bound the save size.
    final keys = _ghosts.keys.toList()..sort();
    while (keys.length >= 6) {
      _ghosts.remove(keys.removeAt(0));
    }
    _ghosts[board] = run.toJson();
    await store.flush();
    return true;
  }
}

final multiplayerProvider = Provider<MultiplayerService>(
  (ref) => LocalGhostService(ref.watch(saveStoreProvider)),
);
