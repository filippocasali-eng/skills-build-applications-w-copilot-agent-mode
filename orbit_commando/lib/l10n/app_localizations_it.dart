// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Italian (`it`).
class AppLocalizationsIt extends AppLocalizations {
  AppLocalizationsIt([String locale = 'it']) : super(locale);

  @override
  String get appTitle => 'Orbit Commando \'94';

  @override
  String get pressStart => 'Premi start';

  @override
  String get insertCoin => 'Inserisci gettone';

  @override
  String creditsLabel(int count) {
    return 'Crediti $count';
  }

  @override
  String get sandboxLabel => 'Sandbox M1';

  @override
  String get back => 'Indietro';
}
