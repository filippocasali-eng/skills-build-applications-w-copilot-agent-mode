import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/profile_controller.dart';
import '../features/splash/splash_screen.dart';
import '../l10n/generated/app_localizations.dart';
import 'theme.dart';

/// Root widget of MIXO: Color Rush.
class MixoApp extends ConsumerWidget {
  const MixoApp({super.key, this.locale, this.home});

  /// Forces a locale (tests); null follows settings or the device.
  final Locale? locale;

  /// Overrides the first screen (tests).
  final Widget? home;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final code = ref.watch(
      profileProvider.select((p) => p.settings.localeCode),
    );
    return MaterialApp(
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      debugShowCheckedModeBanner: false,
      theme: buildMixoTheme(),
      locale: locale ?? (code == null ? null : Locale(code)),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: home ?? const SplashScreen(),
    );
  }
}
