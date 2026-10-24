import '../../game/sim/replay.dart';

/// A recorded opponent on a given track.
class Opponent {
  const Opponent({
    required this.replay,
    required this.score,
    required this.label,
  });

  final Replay replay;
  final int score;

  /// Display label (a generated nickname, never free text).
  final String label;
}

/// Asynchronous multiplayer abstraction. v1: [LocalGhostService] (your own
/// best run). v2: friends' runs by code; v3: leagues. See MULTIPLAYER_PLAN.md.
abstract class MultiplayerService {
  Future<Opponent?> opponentFor(String trackId);
  Future<void> submit(String trackId, Replay replay, int score);
}

/// Offline implementation backed by local storage callbacks.
class LocalGhostService implements MultiplayerService {
  LocalGhostService({
    required this.read,
    required this.write,
    required this.label,
  });

  final (Replay?, int) Function() read;
  final Future<void> Function(Replay replay, int score) write;
  final String label;

  @override
  Future<Opponent?> opponentFor(String trackId) async {
    final (replay, score) = read();
    if (replay == null) return null;
    return Opponent(replay: replay, score: score, label: label);
  }

  @override
  Future<void> submit(String trackId, Replay replay, int score) async {
    final (_, best) = read();
    if (score > best) await write(replay, score);
  }
}
