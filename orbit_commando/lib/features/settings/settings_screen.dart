import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/ui/pixel.dart';
import '../../app/ui/route.dart';
import '../../core/ads/consent.dart';
import '../../core/audio/audio.dart';
import '../../core/monetization/catalog.dart';
import '../../core/monetization/store.dart';
import '../../core/settings/settings.dart';
import '../../engine/render/palette.g.dart';
import '../../game/sim/balance.dart';
import '../../l10n/app_localizations.dart';
import '../shop/shop_screen.dart';
import 'controls_editor.dart';
import 'privacy_screen.dart';

/// Settings: audio, video (CRT), game, controls, privacy and spending.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final s = ref.watch(settingsProvider);
    final c = ref.read(settingsProvider.notifier);
    Future<void> set(Settings Function(Settings) f) async {
      await c.update(f);
      final n = ref.read(settingsProvider);
      ref
          .read(audioProvider)
          .setVolumes(music: n.musicVolume, sfx: n.sfxVolume);
    }

    String vol(double v) => '${(v * 10).round()}/10';
    final volumes = {for (var i = 0; i <= 10; i++) i / 10: vol(i / 10)};
    return PixelScreen(
      title: l.menuSettings,
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        children: [
          PixelText(l.setAudio, scale: 1.2, color: Pal.aqua6),
          PixelChoice<double>(
            label: l.setMusic,
            value: (s.musicVolume * 10).round() / 10,
            options: volumes,
            onChanged: (v) => set((x) => x.copyWith(musicVolume: v)),
          ),
          PixelChoice<double>(
            label: l.setSfx,
            value: (s.sfxVolume * 10).round() / 10,
            options: volumes,
            onChanged: (v) => set((x) => x.copyWith(sfxVolume: v)),
          ),
          const SizedBox(height: 8),
          PixelText(l.setVideo, scale: 1.2, color: Pal.aqua6),
          PixelChoice<CrtPreset>(
            label: l.setCrt,
            value: s.crt,
            options: {
              CrtPreset.off: l.crtOff,
              CrtPreset.arcade: l.crtArcade,
              CrtPreset.tv: l.crtTv,
            },
            onChanged: (v) => set((x) => x.copyWith(crt: v)),
          ),
          const SizedBox(height: 8),
          PixelText(l.setGame, scale: 1.2, color: Pal.aqua6),
          PixelChoice<Difficulty>(
            label: l.difficulty,
            value: s.difficulty,
            options: {
              Difficulty.easy: l.diffEasy,
              Difficulty.normal: l.diffNormal,
              Difficulty.arcade: l.diffArcade,
            },
            onChanged: (v) => set((x) => x.copyWith(difficulty: v)),
          ),
          PixelChoice<bool>(
            label: l.setCamera,
            value: s.rotatingCamera,
            options: {true: l.cameraRotating, false: l.cameraFixed},
            onChanged: (v) => set((x) => x.copyWith(rotatingCamera: v)),
          ),
          PixelToggle(
            label: l.setAutoAim,
            value: s.autoAim,
            onText: l.on,
            offText: l.off,
            onChanged: (v) => set((x) => x.copyWith(autoAim: v)),
          ),
          PixelToggle(
            label: l.setVibration,
            value: s.vibration,
            onText: l.on,
            offText: l.off,
            onChanged: (v) => set((x) => x.copyWith(vibration: v)),
          ),
          PixelChoice<String>(
            label: l.setLanguage,
            value: s.locale,
            options: {
              'system': l.langSystem,
              'it': 'ITALIANO',
              'en': 'ENGLISH',
            },
            onChanged: (v) => set((x) => x.copyWith(locale: v)),
          ),
          const SizedBox(height: 4),
          PixelButton(
            label: l.setControls,
            onPressed: () =>
                Navigator.of(context).push(PixelRoute(const ControlsEditor())),
          ),
          const SizedBox(height: 8),
          PixelText(l.setPrivacy, scale: 1.2, color: Pal.aqua6),
          PixelToggle(
            label: l.setAnalytics,
            value: s.analyticsOptIn,
            onText: l.on,
            offText: l.off,
            onChanged: (v) => set((x) => x.copyWith(analyticsOptIn: v)),
          ),
          PixelToggle(
            label: l.setChat,
            value: s.chatEnabled,
            onText: l.on,
            offText: l.off,
            onChanged: (v) => set((x) => x.copyWith(chatEnabled: v)),
          ),
          PixelToggle(
            label: l.setNotifications,
            value: s.pushOptIn,
            onText: l.on,
            offText: l.off,
            onChanged: (v) => set((x) => x.copyWith(pushOptIn: v)),
          ),
          PixelChoice<int?>(
            label: l.setSpendLimit,
            value: s.monthlySpendLimitCents,
            options: {
              null: l.noLimit,
              500: Catalog.euro(500),
              1000: Catalog.euro(1000),
              2000: Catalog.euro(2000),
              5000: Catalog.euro(5000),
              10000: Catalog.euro(10000),
            },
            onChanged: (v) => set(
              (x) => v == null
                  ? x.copyWith(clearSpendLimit: true)
                  : x.copyWith(monthlySpendLimitCents: v),
            ),
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              PixelButton(
                label: l.setConsent,
                scale: 0.8,
                onPressed: () => ref.read(consentProvider).showPrivacyOptions(),
              ),
              PixelButton(
                label: l.purchaseHistory,
                scale: 0.8,
                onPressed: () =>
                    Navigator.of(context).push(PixelRoute(const ShopScreen())),
              ),
              PixelButton(
                label: l.restorePurchases,
                scale: 0.8,
                onPressed: () => ref.read(storeProvider.notifier).restore(),
              ),
              PixelButton(
                label: l.privacyPolicy,
                scale: 0.8,
                onPressed: () =>
                    Navigator.of(context)
                        .push(PixelRoute(const PrivacyScreen())),
              ),
            ],
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
