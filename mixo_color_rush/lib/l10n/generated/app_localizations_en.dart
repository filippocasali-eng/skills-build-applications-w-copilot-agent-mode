// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'MIXO: Color Rush';

  @override
  String get play => 'PLAY';

  @override
  String get again => 'AGAIN!';

  @override
  String get home => 'Home';

  @override
  String get score => 'Score';

  @override
  String best(int score) {
    return 'Best: $score';
  }

  @override
  String get newRecord => 'NEW RECORD!';

  @override
  String get paused => 'Paused';

  @override
  String get resume => 'Resume';

  @override
  String get pause => 'Pause';

  @override
  String get swipeHint => 'Swipe to change lane';

  @override
  String get matchHint => 'Go through gates of YOUR colour!';

  @override
  String hearts(int count) {
    return 'Hearts: $count';
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
    return 'Gates: $count';
  }
}
