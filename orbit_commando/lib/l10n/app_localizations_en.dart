// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Orbit Commando \'94';

  @override
  String get pressStart => 'Press start';

  @override
  String get insertCoin => 'Insert coin';

  @override
  String creditsLabel(int count) {
    return 'Credits $count';
  }

  @override
  String get sandboxLabel => 'M1 sandbox';

  @override
  String get back => 'Back';
}
