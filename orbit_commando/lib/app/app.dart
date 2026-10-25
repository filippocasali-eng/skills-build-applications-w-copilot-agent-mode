import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/settings/settings.dart';
import '../features/onboarding/splash.dart';
import '../l10n/app_localizations.dart';
import 'theme.dart';

class OrbitApp extends ConsumerWidget {
  const OrbitApp({super.key, this.locale, this.home});

  /// Forces a locale (tests); otherwise Settings decides (or the device).
  final Locale? locale;

  /// Overrides the first screen (tests).
  final Widget? home;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final setting = ref.watch(settingsProvider.select((s) => s.locale));
    return MaterialApp(
      onGenerateTitle: (c) => AppLocalizations.of(c).appTitle,
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      locale: locale ?? (setting == 'system' ? null : Locale(setting)),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: home ?? const Splash(),
    );
  }
}
