import 'package:flutter/material.dart';

import '../features/home/home_screen.dart';
import '../l10n/generated/app_localizations.dart';
import 'theme.dart';

/// Root widget of MIXO: Color Rush.
class MixoApp extends StatelessWidget {
  const MixoApp({super.key, this.locale});

  /// Forces a locale (tests); null follows the device.
  final Locale? locale;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      debugShowCheckedModeBanner: false,
      theme: buildMixoTheme(),
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const HomeScreen(),
    );
  }
}
