import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../core/models/profile.dart';
import '../../core/profile_controller.dart';
import '../../core/providers.dart';
import '../../core/widgets/common.dart';
import '../../l10n/generated/app_localizations.dart';
import '../parental_gate/parental_gate.dart';
import 'info_page.dart';
import 'parent_area_screen.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final p = ref.watch(profileProvider);
    final ctrl = ref.read(profileProvider.notifier);
    final s = p.settings;

    void set(void Function(Settings s) f) {
      ctrl.update((p) => f(p.settings));
      final audio = ref.read(audioProvider)
        ..soundOn = p.settings.sound
        ..musicOn = p.settings.music;
      if (!p.settings.music) audio.stopMusic();
      ref.read(hapticsProvider).enabled = p.settings.haptics;
    }

    Widget toggle(
      String key,
      IconData icon,
      String label,
      bool value,
      void Function(bool) onChanged,
    ) => SwitchListTile(
      key: Key(key),
      secondary: Icon(icon, size: 30, color: MixoColors.sun),
      title: Text(
        label,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
      ),
      value: value,
      onChanged: onChanged,
    );

    return MixoPage(
      title: l.settings,
      child: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          toggle(
            'set-sound',
            Icons.volume_up_rounded,
            l.sound,
            s.sound,
            (v) => set((s) => s.sound = v),
          ),
          toggle(
            'set-music',
            Icons.music_note_rounded,
            l.music,
            s.music,
            (v) => set((s) => s.music = v),
          ),
          toggle(
            'set-haptics',
            Icons.vibration_rounded,
            l.vibration,
            s.haptics,
            (v) => set((s) => s.haptics = v),
          ),
          toggle(
            'set-symbols',
            Icons.category_rounded,
            l.symbolsAlways,
            s.symbolsAlways,
            (v) => set((s) => s.symbolsAlways = v),
          ),
          toggle(
            'set-effects',
            Icons.motion_photos_off_rounded,
            l.reduceEffects,
            s.reduceEffects,
            (v) => set((s) => s.reduceEffects = v),
          ),
          ListTile(
            leading: const Icon(
              Icons.swipe_rounded,
              size: 30,
              color: MixoColors.sun,
            ),
            title: Text(
              l.controls,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: SegmentedButton<ControlMode>(
                segments: [
                  ButtonSegment(
                    value: ControlMode.swipe,
                    label: Text(l.controlSwipe),
                    icon: const Icon(Icons.swipe_rounded),
                  ),
                  ButtonSegment(
                    value: ControlMode.tapSides,
                    label: Text(l.controlTap),
                    icon: const Icon(Icons.touch_app_rounded),
                  ),
                ],
                selected: {s.controlMode},
                onSelectionChanged: (v) => set((s) => s.controlMode = v.first),
              ),
            ),
          ),
          ListTile(
            leading: const Icon(
              Icons.language_rounded,
              size: 30,
              color: MixoColors.sun,
            ),
            title: Text(
              l.language,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: SegmentedButton<String>(
                segments: [
                  ButtonSegment(value: 'system', label: Text(l.languageSystem)),
                  const ButtonSegment(value: 'it', label: Text('IT')),
                  const ButtonSegment(value: 'en', label: Text('EN')),
                ],
                selected: {s.localeCode ?? 'system'},
                onSelectionChanged: (v) => set(
                  (s) => s.localeCode = v.first == 'system' ? null : v.first,
                ),
              ),
            ),
          ),
          const Divider(),
          ListTile(
            key: const Key('parent-area'),
            leading: const Icon(
              Icons.family_restroom_rounded,
              size: 30,
              color: MixoColors.candy,
            ),
            title: Text(
              l.parentArea,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            trailing: const Icon(Icons.lock_rounded),
            onTap: () async {
              if (await showParentalGate(context) && context.mounted) {
                await Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const ParentAreaScreen(),
                  ),
                );
              }
            },
          ),
          ListTile(
            leading: const Icon(Icons.privacy_tip_rounded, size: 30),
            title: Text(l.privacy, style: const TextStyle(fontSize: 18)),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => InfoPage(title: l.privacy, body: l.privacyText),
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.favorite_rounded, size: 30),
            title: Text(l.credits, style: const TextStyle(fontSize: 18)),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => InfoPage(title: l.credits, body: l.creditsText),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
