// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Italian (`it`).
class AppLocalizationsIt extends AppLocalizations {
  AppLocalizationsIt([String locale = 'it']) : super(locale);

  @override
  String get appTitle => 'MIXO: Color Rush';

  @override
  String get play => 'GIOCA';

  @override
  String get again => 'ANCORA!';

  @override
  String get home => 'Home';

  @override
  String get score => 'Punteggio';

  @override
  String best(int score) {
    return 'Record: $score';
  }

  @override
  String get newRecord => 'NUOVO RECORD!';

  @override
  String get paused => 'Pausa';

  @override
  String get resume => 'Riprendi';

  @override
  String get pause => 'Pausa';

  @override
  String get swipeHint => 'Scorri per cambiare corsia';

  @override
  String get matchHint => 'Passa dalle porte del TUO colore!';

  @override
  String hearts(int count) {
    return 'Cuori: $count';
  }

  @override
  String comboLabel(int multiplier) {
    return 'Combo x$multiplier';
  }

  @override
  String timeLabel(int seconds) {
    return '$seconds s';
  }

  @override
  String gatesLabel(int count) {
    return 'Porte: $count';
  }
}
