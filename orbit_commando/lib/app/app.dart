import 'package:flutter/material.dart';

import '../features/play/play_screen.dart';
import '../features/title/title_screen.dart';
import '../l10n/app_localizations.dart';
import 'theme.dart';

abstract final class Routes {
  static const title = '/';
  static const play = '/play';
}

class OrbitApp extends StatelessWidget {
  const OrbitApp({super.key, this.locale});

  /// Forces a locale (tests); null follows the device.
  final Locale? locale;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      onGenerateTitle: (c) => AppLocalizations.of(c).appTitle,
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      initialRoute: Routes.title,
      routes: {
        Routes.title: (_) => const TitleScreen(),
        Routes.play: (_) => const PlayScreen(),
      },
    );
  }
}
