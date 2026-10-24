import 'dart:async';

import 'package:flame_audio/flame_audio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

enum Sfx {
  gateOk('gate_ok'),
  gateFail('gate_fail'),
  drop('drop'),
  lane('lane'),
  jump('jump'),
  combo('combo'),
  nearMiss('near_miss'),
  gameOver('game_over'),
  record('record'),
  click('click'),
  unlock('unlock');

  const Sfx(this.file);

  final String file;
}

/// Audio output used by the game and the UI.
abstract class GameAudio {
  bool soundOn = true;
  bool musicOn = true;

  void sfx(Sfx s);
  void startMusic();
  void stopMusic();

  /// [level] 1..3 picks the music layer, [rate] follows the game speed.
  void musicIntensity(int level, double rate);
}

class SilentAudio extends GameAudio {
  @override
  void sfx(Sfx s) {}
  @override
  void startMusic() {}
  @override
  void stopMusic() {}
  @override
  void musicIntensity(int level, double rate) {}
}

/// flame_audio implementation. Every call is fire-and-forget and never
/// throws: missing audio must never break the game.
class FlameGameAudio extends GameAudio {
  final Map<Sfx, AudioPool> _pools = {};
  int _level = 0;
  double _rate = 1;
  bool _musicPlaying = false;

  Future<void> init() async {
    try {
      FlameAudio.updatePrefix('assets/generated/audio/');
      await FlameAudio.audioCache.loadAll([
        for (final s in Sfx.values) '${s.file}.wav',
        'music_1.wav',
        'music_2.wav',
        'music_3.wav',
      ]);
      for (final s in const [Sfx.gateOk, Sfx.lane, Sfx.drop]) {
        _pools[s] = await FlameAudio.createPool('${s.file}.wav', maxPlayers: 4);
      }
      unawaited(FlameAudio.bgm.initialize());
    } catch (e) {
      debugPrint('Audio init failed: $e');
    }
  }

  void _safe(Future<void> Function() f) {
    unawaited(f().catchError((Object e) => debugPrint('Audio error: $e')));
  }

  @override
  void sfx(Sfx s) {
    if (!soundOn) return;
    final pool = _pools[s];
    _safe(() async {
      if (pool != null) {
        await pool.start(volume: 0.7);
      } else {
        await FlameAudio.play('${s.file}.wav', volume: 0.8);
      }
    });
  }

  @override
  void startMusic() {
    if (!musicOn) return;
    _level = 0;
    _musicPlaying = true;
    musicIntensity(1, 1);
  }

  @override
  void stopMusic() {
    _musicPlaying = false;
    _level = 0;
    _safe(FlameAudio.bgm.stop);
  }

  @override
  void musicIntensity(int level, double rate) {
    if (!musicOn || !_musicPlaying) return;
    if (level != _level) {
      _level = level;
      _safe(() => FlameAudio.bgm.play('music_$level.wav', volume: 0.45));
      _rate = 1;
    }
    if ((rate - _rate).abs() > 0.03) {
      _rate = rate;
      _safe(() => FlameAudio.bgm.audioPlayer.setPlaybackRate(rate));
    }
  }
}

/// Short haptic feedback (≈10–30 ms system patterns). Can be disabled.
class Haptics {
  bool enabled = true;

  void light() {
    if (enabled) unawaited(HapticFeedback.lightImpact());
  }

  void medium() {
    if (enabled) unawaited(HapticFeedback.mediumImpact());
  }

  void heavy() {
    if (enabled) unawaited(HapticFeedback.heavyImpact());
  }
}
