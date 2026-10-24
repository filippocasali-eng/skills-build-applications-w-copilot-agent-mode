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
  String get cancel => 'Cancel';

  @override
  String get loading => 'Loading…';

  @override
  String get swipeHint => 'Swipe to change lane';

  @override
  String get matchHint => 'Go through gates of YOUR colour!';

  @override
  String get onboardingHint => 'This is Mixo! Reach the gate of his colour.';

  @override
  String get onboardingDone => 'You\'re ready. Let\'s run!';

  @override
  String get bravo => 'Great!';

  @override
  String hearts(int count) {
    return 'Hearts: $count';
  }

  @override
  String comboLabel(int multiplier) {
    return 'Combo x$multiplier';
  }

  @override
  String get combo => 'COMBO';

  @override
  String get nearMiss => 'CLOSE CALL!';

  @override
  String timeLabel(int seconds) {
    return '$seconds s';
  }

  @override
  String levelShort(int level) {
    return 'Lv. $level';
  }

  @override
  String levelUp(int level) {
    return 'LEVEL $level!';
  }

  @override
  String get newMechanic => 'NEW!';

  @override
  String get mechDrops => 'Drops change your colour!';

  @override
  String get mechObstacles => 'Dodge the blocks!';

  @override
  String get mechMixing => 'Colours MIX! Red + Blue = Purple';

  @override
  String get mechSecondary => 'Mixed-colour gates!';

  @override
  String get mechSpecials => 'Special drops: White, Rainbow, Invert';

  @override
  String get mechFiveLanes => 'EXPERT: 5 lanes!';

  @override
  String get mechJump => 'Tap to JUMP over low blocks';

  @override
  String get mechDive => 'Swipe down to DIVE (bonus!)';

  @override
  String get tipMix => 'Remember this mix:';

  @override
  String get tipBrown => 'Brown? Look for a white drop to clean Mixo!';

  @override
  String get tipSymbol => 'Look at Mixo\'s symbol and find the same gate.';

  @override
  String get tipDodge => 'Change lane early to dodge the blocks.';

  @override
  String get tipJump => 'Tap to jump over the low blocks.';

  @override
  String get tipLookAhead => 'Look far ahead: the gates come fast!';

  @override
  String get tipCombo => 'No mistakes for a while = combo x5!';

  @override
  String get tipGreat => 'Amazing run! Can you go even faster?';

  @override
  String get missionDone => 'Mission complete';

  @override
  String get unlocked => 'Unlocked';

  @override
  String get lessonComplete => 'LESSON COMPLETE!';

  @override
  String get lessonFailed => 'Almost! Try again';

  @override
  String get ghostBeaten => 'YOU BEAT THE GHOST!';

  @override
  String ghostAhead(int points) {
    return 'Ghost +$points';
  }

  @override
  String ghostBehind(int points) {
    return 'You +$points';
  }

  @override
  String get breakTitle => 'Great session! Take a break?';

  @override
  String get breakBody =>
      'You have been playing for 30 minutes. Stretch, drink some water, look out of the window!';

  @override
  String get takeBreak => 'Take a break';

  @override
  String get keepPlaying => 'Keep playing';

  @override
  String get limitTitle => 'That\'s all for today!';

  @override
  String get limitBody => 'Mixo is tired too. See you tomorrow!';

  @override
  String get daily => 'Daily';

  @override
  String get dailyInfo =>
      'The same track for everyone, all day long. Play it as many times as you like. Skipping a day is fine!';

  @override
  String dailyBest(int score) {
    return 'Today\'s best: $score';
  }

  @override
  String dailyPlays(int count) {
    return 'Runs today: $count';
  }

  @override
  String get academy => 'Academy';

  @override
  String get mandatory => 'to unlock modes';

  @override
  String get lockedAcademyFirst =>
      'Complete the first 2 Academy lessons first!';

  @override
  String get ghost => 'Ghost';

  @override
  String get ghostInfo =>
      'Race against your best run on the same track. Beat your ghost!';

  @override
  String ghostBest(int score) {
    return 'Ghost to beat: $score';
  }

  @override
  String get ghostNone => 'No ghost yet: your first run becomes the ghost!';

  @override
  String get collection => 'Collection';

  @override
  String get skins => 'Mixo';

  @override
  String get trails => 'Trails';

  @override
  String get themes => 'Worlds';

  @override
  String get equip => 'Use';

  @override
  String get equipped => 'In use';

  @override
  String get inShop => 'Shop';

  @override
  String reachLevel(int level) {
    return 'Reach level $level to unlock it!';
  }

  @override
  String get findInShop => 'Available in the shop (ask a grown-up).';

  @override
  String buyWithStars(int price) {
    return 'Unlock for $price stars?';
  }

  @override
  String get unlock => 'Unlock';

  @override
  String get notEnoughStars => 'Not enough stars';

  @override
  String get missions => 'Missions';

  @override
  String get missionsInfo =>
      'Complete a mission and a new one appears. No rush, no timers!';

  @override
  String get trophies => 'Trophies';

  @override
  String get stats => 'Stats';

  @override
  String mColorGates(int count, String color) {
    return 'Pass $count $color gates';
  }

  @override
  String mCombo(int count) {
    return 'Reach a combo of $count';
  }

  @override
  String mSurvive(int count) {
    return 'Run for $count seconds';
  }

  @override
  String mScore(int count) {
    return 'Score $count points in one run';
  }

  @override
  String mDrops(int count) {
    return 'Collect $count drops';
  }

  @override
  String mNearMiss(int count) {
    return 'Make $count close calls';
  }

  @override
  String mRuns(int count) {
    return 'Play $count runs';
  }

  @override
  String mMixGates(int count) {
    return 'Pass $count mixed-colour gates';
  }

  @override
  String mJumps(int count) {
    return 'Jump over $count blocks';
  }

  @override
  String get colorRed => 'red';

  @override
  String get colorYellow => 'yellow';

  @override
  String get colorBlue => 'blue';

  @override
  String get colorOrange => 'orange';

  @override
  String get colorGreen => 'green';

  @override
  String get colorPurple => 'purple';

  @override
  String get colorBrown => 'brown';

  @override
  String get statBest => 'Best score';

  @override
  String get statCombo => 'Best combo';

  @override
  String get statLongest => 'Longest run';

  @override
  String get statRuns => 'Runs played';

  @override
  String get statTime => 'Total time';

  @override
  String get statGates => 'Gates passed';

  @override
  String get statDrops => 'Drops collected';

  @override
  String get statNearMiss => 'Close calls';

  @override
  String get statMix => 'Mixed gates';

  @override
  String get statDaily => 'Daily challenges';

  @override
  String get statColors => 'Gates by colour';

  @override
  String get shop => 'Shop';

  @override
  String get shopInfo =>
      'Only looks for Mixo: they never make the game easier. Real prices, no surprises.';

  @override
  String get packContains => 'This pack contains:';

  @override
  String buyFor(String price) {
    return 'Buy for $price';
  }

  @override
  String get owned => 'Owned';

  @override
  String get priceUnavailable => 'Price unavailable';

  @override
  String get storeUnavailable =>
      'The store is not available right now. The game works fine without it!';

  @override
  String get purchasesDisabled =>
      'Purchases are turned off in the parent area.';

  @override
  String get restorePurchases => 'Restore purchases';

  @override
  String get purchasePending => 'Purchase pending…';

  @override
  String get purchaseDone => 'Thank you! Your items are in the Collection.';

  @override
  String get purchasesRestored => 'Purchases restored.';

  @override
  String get purchaseError => 'Something went wrong. No money was taken.';

  @override
  String get purchaseCancelled => 'Purchase cancelled.';

  @override
  String get settings => 'Settings';

  @override
  String get sound => 'Sound effects';

  @override
  String get music => 'Music';

  @override
  String get vibration => 'Vibration';

  @override
  String get symbolsAlways => 'Colour symbols always on';

  @override
  String get reduceEffects => 'Calmer effects (no shake)';

  @override
  String get controls => 'Controls';

  @override
  String get controlSwipe => 'Swipe';

  @override
  String get controlTap => 'Tap sides';

  @override
  String get language => 'Language';

  @override
  String get languageSystem => 'Device';

  @override
  String get parentArea => 'Parent area';

  @override
  String get privacy => 'Privacy policy';

  @override
  String get credits => 'Credits';

  @override
  String get pickName => 'Pick your name';

  @override
  String get gateTitle => 'Ask a grown-up';

  @override
  String get gateHold => 'Grown-ups: hold the button for 3 seconds.';

  @override
  String get gateWrong => 'Not quite. Try this one.';

  @override
  String get dailyLimit => 'Daily play limit';

  @override
  String playedToday(int minutes) {
    return 'Played today: $minutes min';
  }

  @override
  String get noLimit => 'No limit';

  @override
  String get extend15 => '+15 minutes today';

  @override
  String get purchasesEnabled => 'Allow purchases';

  @override
  String get purchasesInfo =>
      'Every purchase also asks for the parental check.';

  @override
  String get parentPrivacyTitle => 'No personal data collected';

  @override
  String get parentPrivacyBody =>
      'No account, no chat, no ads, no tracking. Progress stays on this device only. The internet is used only by Google Play for optional purchases.';

  @override
  String get resetProgress => 'Reset all progress';

  @override
  String get resetConfirm =>
      'This deletes levels, stars and collection on this device. Purchases can be restored from the shop.';

  @override
  String get reset => 'Reset';

  @override
  String get privacyText =>
      'MIXO: Color Rush — Privacy policy (summary)\n\n• We do not collect personal data. There are no accounts, no email, no real names, no location and no advertising ID.\n• Your nickname is generated from a list: nobody can type personal information.\n• There is no chat and no communication between players.\n• There are no ads and no analytics or tracking tools.\n• Game progress (levels, stars, settings) is saved only on this device. Uninstalling the app deletes it.\n• Optional purchases are handled entirely by Google Play under Google\'s privacy policy. We receive no payment details.\n• Purchases require a parental check and can be disabled in the parent area.\n\nQuestions: see the contact e-mail on the Google Play page of the app.';

  @override
  String get creditsText =>
      'MIXO: Color Rush\n\nGame design, code, graphics, music and sound effects created for this project: every image is drawn by code and every sound is synthesised by a script included in the source.\n\nBuilt with Flutter and the Flame engine (open source, BSD/MIT licences).\n\nThank you for playing!';
}
