import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../game/input/controls.dart';
import '../../game/sim/balance.dart';
import '../providers.dart';

enum CrtPreset { off, arcade, tv }

/// Everything on the Settings screen. Persisted in the save's `settings`.
class Settings {
  const Settings({
    this.musicVolume = 0.7,
    this.sfxVolume = 0.9,
    this.crt = CrtPreset.arcade,
    this.rotatingCamera = true,
    this.autoAim = true,
    this.vibration = true,
    this.difficulty = Difficulty.easy,
    this.locale = 'system',
    this.controls = const ControlsLayout(),
    this.analyticsOptIn = false,
    this.chatEnabled = true,
    this.pushOptIn = false,
    this.monthlySpendLimitCents,
  });

  factory Settings.fromJson(Map<String, dynamic> j) {
    const d = Settings();
    return Settings(
      musicVolume: (j['musicVolume'] as num?)?.toDouble() ?? d.musicVolume,
      sfxVolume: (j['sfxVolume'] as num?)?.toDouble() ?? d.sfxVolume,
      crt: CrtPreset.values.asNameMap()[j['crt']] ?? d.crt,
      rotatingCamera: j['rotatingCamera'] as bool? ?? d.rotatingCamera,
      autoAim: j['autoAim'] as bool? ?? d.autoAim,
      vibration: j['vibration'] as bool? ?? d.vibration,
      difficulty:
          Difficulty.values.asNameMap()[j['difficulty']] ?? d.difficulty,
      locale: j['locale'] as String? ?? d.locale,
      controls: j['controls'] is Map<String, dynamic>
          ? ControlsLayout.fromJson(j['controls'] as Map<String, dynamic>)
          : d.controls,
      analyticsOptIn: j['analyticsOptIn'] as bool? ?? d.analyticsOptIn,
      chatEnabled: j['chatEnabled'] as bool? ?? d.chatEnabled,
      pushOptIn: j['pushOptIn'] as bool? ?? d.pushOptIn,
      monthlySpendLimitCents: j['monthlySpendLimitCents'] as int?,
    );
  }

  final double musicVolume;
  final double sfxVolume;
  final CrtPreset crt;
  final bool rotatingCamera;

  /// Auto-aim (on by default in Easy).
  final bool autoAim;
  final bool vibration;
  final Difficulty difficulty;

  /// 'system', 'it' or 'en'.
  final String locale;
  final ControlsLayout controls;
  final bool analyticsOptIn;
  final bool chatEnabled;
  final bool pushOptIn;

  /// Optional self-imposed monthly spending cap (euro cents).
  final int? monthlySpendLimitCents;

  Map<String, Object?> toJson() => {
    'musicVolume': musicVolume,
    'sfxVolume': sfxVolume,
    'crt': crt.name,
    'rotatingCamera': rotatingCamera,
    'autoAim': autoAim,
    'vibration': vibration,
    'difficulty': difficulty.name,
    'locale': locale,
    'controls': controls.toJson(),
    'analyticsOptIn': analyticsOptIn,
    'chatEnabled': chatEnabled,
    'pushOptIn': pushOptIn,
    'monthlySpendLimitCents': monthlySpendLimitCents,
  };

  Settings copyWith({
    double? musicVolume,
    double? sfxVolume,
    CrtPreset? crt,
    bool? rotatingCamera,
    bool? autoAim,
    bool? vibration,
    Difficulty? difficulty,
    String? locale,
    ControlsLayout? controls,
    bool? analyticsOptIn,
    bool? chatEnabled,
    bool? pushOptIn,
    int? monthlySpendLimitCents,
    bool clearSpendLimit = false,
  }) => Settings(
    musicVolume: musicVolume ?? this.musicVolume,
    sfxVolume: sfxVolume ?? this.sfxVolume,
    crt: crt ?? this.crt,
    rotatingCamera: rotatingCamera ?? this.rotatingCamera,
    autoAim: autoAim ?? this.autoAim,
    vibration: vibration ?? this.vibration,
    difficulty: difficulty ?? this.difficulty,
    locale: locale ?? this.locale,
    controls: controls ?? this.controls,
    analyticsOptIn: analyticsOptIn ?? this.analyticsOptIn,
    chatEnabled: chatEnabled ?? this.chatEnabled,
    pushOptIn: pushOptIn ?? this.pushOptIn,
    monthlySpendLimitCents: clearSpendLimit
        ? null
        : monthlySpendLimitCents ?? this.monthlySpendLimitCents,
  );
}

class SettingsController extends Notifier<Settings> {
  @override
  Settings build() {
    final store = ref.watch(saveStoreProvider);
    return Settings.fromJson(store.section('settings'));
  }

  Future<void> update(Settings Function(Settings s) change) async {
    state = change(state);
    final store = ref.read(saveStoreProvider);
    store.section('settings')
      ..clear()
      ..addAll(state.toJson());
    await store.flush();
  }
}

final settingsProvider = NotifierProvider<SettingsController, Settings>(
  SettingsController.new,
);
