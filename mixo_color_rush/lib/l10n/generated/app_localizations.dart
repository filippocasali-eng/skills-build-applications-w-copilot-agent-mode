import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_it.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('it'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'MIXO: Color Rush'**
  String get appTitle;

  /// No description provided for @play.
  ///
  /// In en, this message translates to:
  /// **'PLAY'**
  String get play;

  /// No description provided for @again.
  ///
  /// In en, this message translates to:
  /// **'AGAIN!'**
  String get again;

  /// No description provided for @home.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get home;

  /// No description provided for @score.
  ///
  /// In en, this message translates to:
  /// **'Score'**
  String get score;

  /// No description provided for @best.
  ///
  /// In en, this message translates to:
  /// **'Best: {score}'**
  String best(int score);

  /// No description provided for @newRecord.
  ///
  /// In en, this message translates to:
  /// **'NEW RECORD!'**
  String get newRecord;

  /// No description provided for @paused.
  ///
  /// In en, this message translates to:
  /// **'Paused'**
  String get paused;

  /// No description provided for @resume.
  ///
  /// In en, this message translates to:
  /// **'Resume'**
  String get resume;

  /// No description provided for @pause.
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get pause;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @loading.
  ///
  /// In en, this message translates to:
  /// **'Loading…'**
  String get loading;

  /// No description provided for @swipeHint.
  ///
  /// In en, this message translates to:
  /// **'Swipe to change lane'**
  String get swipeHint;

  /// No description provided for @matchHint.
  ///
  /// In en, this message translates to:
  /// **'Go through gates of YOUR colour!'**
  String get matchHint;

  /// No description provided for @onboardingHint.
  ///
  /// In en, this message translates to:
  /// **'This is Mixo! Reach the gate of his colour.'**
  String get onboardingHint;

  /// No description provided for @onboardingDone.
  ///
  /// In en, this message translates to:
  /// **'You\'re ready. Let\'s run!'**
  String get onboardingDone;

  /// No description provided for @bravo.
  ///
  /// In en, this message translates to:
  /// **'Great!'**
  String get bravo;

  /// No description provided for @hearts.
  ///
  /// In en, this message translates to:
  /// **'Hearts: {count}'**
  String hearts(int count);

  /// No description provided for @comboLabel.
  ///
  /// In en, this message translates to:
  /// **'Combo x{multiplier}'**
  String comboLabel(int multiplier);

  /// No description provided for @combo.
  ///
  /// In en, this message translates to:
  /// **'COMBO'**
  String get combo;

  /// No description provided for @nearMiss.
  ///
  /// In en, this message translates to:
  /// **'CLOSE CALL!'**
  String get nearMiss;

  /// No description provided for @timeLabel.
  ///
  /// In en, this message translates to:
  /// **'{seconds} s'**
  String timeLabel(int seconds);

  /// No description provided for @levelShort.
  ///
  /// In en, this message translates to:
  /// **'Lv. {level}'**
  String levelShort(int level);

  /// No description provided for @levelUp.
  ///
  /// In en, this message translates to:
  /// **'LEVEL {level}!'**
  String levelUp(int level);

  /// No description provided for @newMechanic.
  ///
  /// In en, this message translates to:
  /// **'NEW!'**
  String get newMechanic;

  /// No description provided for @mechDrops.
  ///
  /// In en, this message translates to:
  /// **'Drops change your colour!'**
  String get mechDrops;

  /// No description provided for @mechObstacles.
  ///
  /// In en, this message translates to:
  /// **'Dodge the blocks!'**
  String get mechObstacles;

  /// No description provided for @mechMixing.
  ///
  /// In en, this message translates to:
  /// **'Colours MIX! Red + Blue = Purple'**
  String get mechMixing;

  /// No description provided for @mechSecondary.
  ///
  /// In en, this message translates to:
  /// **'Mixed-colour gates!'**
  String get mechSecondary;

  /// No description provided for @mechSpecials.
  ///
  /// In en, this message translates to:
  /// **'Special drops: White, Rainbow, Invert'**
  String get mechSpecials;

  /// No description provided for @mechFiveLanes.
  ///
  /// In en, this message translates to:
  /// **'EXPERT: 5 lanes!'**
  String get mechFiveLanes;

  /// No description provided for @mechJump.
  ///
  /// In en, this message translates to:
  /// **'Tap to JUMP over low blocks'**
  String get mechJump;

  /// No description provided for @mechDive.
  ///
  /// In en, this message translates to:
  /// **'Swipe down to DIVE (bonus!)'**
  String get mechDive;

  /// No description provided for @tipMix.
  ///
  /// In en, this message translates to:
  /// **'Remember this mix:'**
  String get tipMix;

  /// No description provided for @tipBrown.
  ///
  /// In en, this message translates to:
  /// **'Brown? Look for a white drop to clean Mixo!'**
  String get tipBrown;

  /// No description provided for @tipSymbol.
  ///
  /// In en, this message translates to:
  /// **'Look at Mixo\'s symbol and find the same gate.'**
  String get tipSymbol;

  /// No description provided for @tipDodge.
  ///
  /// In en, this message translates to:
  /// **'Change lane early to dodge the blocks.'**
  String get tipDodge;

  /// No description provided for @tipJump.
  ///
  /// In en, this message translates to:
  /// **'Tap to jump over the low blocks.'**
  String get tipJump;

  /// No description provided for @tipLookAhead.
  ///
  /// In en, this message translates to:
  /// **'Look far ahead: the gates come fast!'**
  String get tipLookAhead;

  /// No description provided for @tipCombo.
  ///
  /// In en, this message translates to:
  /// **'No mistakes for a while = combo x5!'**
  String get tipCombo;

  /// No description provided for @tipGreat.
  ///
  /// In en, this message translates to:
  /// **'Amazing run! Can you go even faster?'**
  String get tipGreat;

  /// No description provided for @missionDone.
  ///
  /// In en, this message translates to:
  /// **'Mission complete'**
  String get missionDone;

  /// No description provided for @unlocked.
  ///
  /// In en, this message translates to:
  /// **'Unlocked'**
  String get unlocked;

  /// No description provided for @lessonComplete.
  ///
  /// In en, this message translates to:
  /// **'LESSON COMPLETE!'**
  String get lessonComplete;

  /// No description provided for @lessonFailed.
  ///
  /// In en, this message translates to:
  /// **'Almost! Try again'**
  String get lessonFailed;

  /// No description provided for @ghostBeaten.
  ///
  /// In en, this message translates to:
  /// **'YOU BEAT THE GHOST!'**
  String get ghostBeaten;

  /// No description provided for @ghostAhead.
  ///
  /// In en, this message translates to:
  /// **'Ghost +{points}'**
  String ghostAhead(int points);

  /// No description provided for @ghostBehind.
  ///
  /// In en, this message translates to:
  /// **'You +{points}'**
  String ghostBehind(int points);

  /// No description provided for @breakTitle.
  ///
  /// In en, this message translates to:
  /// **'Great session! Take a break?'**
  String get breakTitle;

  /// No description provided for @breakBody.
  ///
  /// In en, this message translates to:
  /// **'You have been playing for 30 minutes. Stretch, drink some water, look out of the window!'**
  String get breakBody;

  /// No description provided for @takeBreak.
  ///
  /// In en, this message translates to:
  /// **'Take a break'**
  String get takeBreak;

  /// No description provided for @keepPlaying.
  ///
  /// In en, this message translates to:
  /// **'Keep playing'**
  String get keepPlaying;

  /// No description provided for @limitTitle.
  ///
  /// In en, this message translates to:
  /// **'That\'s all for today!'**
  String get limitTitle;

  /// No description provided for @limitBody.
  ///
  /// In en, this message translates to:
  /// **'Mixo is tired too. See you tomorrow!'**
  String get limitBody;

  /// No description provided for @daily.
  ///
  /// In en, this message translates to:
  /// **'Daily'**
  String get daily;

  /// No description provided for @dailyInfo.
  ///
  /// In en, this message translates to:
  /// **'The same track for everyone, all day long. Play it as many times as you like. Skipping a day is fine!'**
  String get dailyInfo;

  /// No description provided for @dailyBest.
  ///
  /// In en, this message translates to:
  /// **'Today\'s best: {score}'**
  String dailyBest(int score);

  /// No description provided for @dailyPlays.
  ///
  /// In en, this message translates to:
  /// **'Runs today: {count}'**
  String dailyPlays(int count);

  /// No description provided for @academy.
  ///
  /// In en, this message translates to:
  /// **'Academy'**
  String get academy;

  /// No description provided for @mandatory.
  ///
  /// In en, this message translates to:
  /// **'to unlock modes'**
  String get mandatory;

  /// No description provided for @lockedAcademyFirst.
  ///
  /// In en, this message translates to:
  /// **'Complete the first 2 Academy lessons first!'**
  String get lockedAcademyFirst;

  /// No description provided for @ghost.
  ///
  /// In en, this message translates to:
  /// **'Ghost'**
  String get ghost;

  /// No description provided for @ghostInfo.
  ///
  /// In en, this message translates to:
  /// **'Race against your best run on the same track. Beat your ghost!'**
  String get ghostInfo;

  /// No description provided for @ghostBest.
  ///
  /// In en, this message translates to:
  /// **'Ghost to beat: {score}'**
  String ghostBest(int score);

  /// No description provided for @ghostNone.
  ///
  /// In en, this message translates to:
  /// **'No ghost yet: your first run becomes the ghost!'**
  String get ghostNone;

  /// No description provided for @collection.
  ///
  /// In en, this message translates to:
  /// **'Collection'**
  String get collection;

  /// No description provided for @skins.
  ///
  /// In en, this message translates to:
  /// **'Mixo'**
  String get skins;

  /// No description provided for @trails.
  ///
  /// In en, this message translates to:
  /// **'Trails'**
  String get trails;

  /// No description provided for @themes.
  ///
  /// In en, this message translates to:
  /// **'Worlds'**
  String get themes;

  /// No description provided for @equip.
  ///
  /// In en, this message translates to:
  /// **'Use'**
  String get equip;

  /// No description provided for @equipped.
  ///
  /// In en, this message translates to:
  /// **'In use'**
  String get equipped;

  /// No description provided for @inShop.
  ///
  /// In en, this message translates to:
  /// **'Shop'**
  String get inShop;

  /// No description provided for @reachLevel.
  ///
  /// In en, this message translates to:
  /// **'Reach level {level} to unlock it!'**
  String reachLevel(int level);

  /// No description provided for @findInShop.
  ///
  /// In en, this message translates to:
  /// **'Available in the shop (ask a grown-up).'**
  String get findInShop;

  /// No description provided for @buyWithStars.
  ///
  /// In en, this message translates to:
  /// **'Unlock for {price} stars?'**
  String buyWithStars(int price);

  /// No description provided for @unlock.
  ///
  /// In en, this message translates to:
  /// **'Unlock'**
  String get unlock;

  /// No description provided for @notEnoughStars.
  ///
  /// In en, this message translates to:
  /// **'Not enough stars'**
  String get notEnoughStars;

  /// No description provided for @missions.
  ///
  /// In en, this message translates to:
  /// **'Missions'**
  String get missions;

  /// No description provided for @missionsInfo.
  ///
  /// In en, this message translates to:
  /// **'Complete a mission and a new one appears. No rush, no timers!'**
  String get missionsInfo;

  /// No description provided for @trophies.
  ///
  /// In en, this message translates to:
  /// **'Trophies'**
  String get trophies;

  /// No description provided for @stats.
  ///
  /// In en, this message translates to:
  /// **'Stats'**
  String get stats;

  /// No description provided for @mColorGates.
  ///
  /// In en, this message translates to:
  /// **'Pass {count} {color} gates'**
  String mColorGates(int count, String color);

  /// No description provided for @mCombo.
  ///
  /// In en, this message translates to:
  /// **'Reach a combo of {count}'**
  String mCombo(int count);

  /// No description provided for @mSurvive.
  ///
  /// In en, this message translates to:
  /// **'Run for {count} seconds'**
  String mSurvive(int count);

  /// No description provided for @mScore.
  ///
  /// In en, this message translates to:
  /// **'Score {count} points in one run'**
  String mScore(int count);

  /// No description provided for @mDrops.
  ///
  /// In en, this message translates to:
  /// **'Collect {count} drops'**
  String mDrops(int count);

  /// No description provided for @mNearMiss.
  ///
  /// In en, this message translates to:
  /// **'Make {count} close calls'**
  String mNearMiss(int count);

  /// No description provided for @mRuns.
  ///
  /// In en, this message translates to:
  /// **'Play {count} runs'**
  String mRuns(int count);

  /// No description provided for @mMixGates.
  ///
  /// In en, this message translates to:
  /// **'Pass {count} mixed-colour gates'**
  String mMixGates(int count);

  /// No description provided for @mJumps.
  ///
  /// In en, this message translates to:
  /// **'Jump over {count} blocks'**
  String mJumps(int count);

  /// No description provided for @colorRed.
  ///
  /// In en, this message translates to:
  /// **'red'**
  String get colorRed;

  /// No description provided for @colorYellow.
  ///
  /// In en, this message translates to:
  /// **'yellow'**
  String get colorYellow;

  /// No description provided for @colorBlue.
  ///
  /// In en, this message translates to:
  /// **'blue'**
  String get colorBlue;

  /// No description provided for @colorOrange.
  ///
  /// In en, this message translates to:
  /// **'orange'**
  String get colorOrange;

  /// No description provided for @colorGreen.
  ///
  /// In en, this message translates to:
  /// **'green'**
  String get colorGreen;

  /// No description provided for @colorPurple.
  ///
  /// In en, this message translates to:
  /// **'purple'**
  String get colorPurple;

  /// No description provided for @colorBrown.
  ///
  /// In en, this message translates to:
  /// **'brown'**
  String get colorBrown;

  /// No description provided for @statBest.
  ///
  /// In en, this message translates to:
  /// **'Best score'**
  String get statBest;

  /// No description provided for @statCombo.
  ///
  /// In en, this message translates to:
  /// **'Best combo'**
  String get statCombo;

  /// No description provided for @statLongest.
  ///
  /// In en, this message translates to:
  /// **'Longest run'**
  String get statLongest;

  /// No description provided for @statRuns.
  ///
  /// In en, this message translates to:
  /// **'Runs played'**
  String get statRuns;

  /// No description provided for @statTime.
  ///
  /// In en, this message translates to:
  /// **'Total time'**
  String get statTime;

  /// No description provided for @statGates.
  ///
  /// In en, this message translates to:
  /// **'Gates passed'**
  String get statGates;

  /// No description provided for @statDrops.
  ///
  /// In en, this message translates to:
  /// **'Drops collected'**
  String get statDrops;

  /// No description provided for @statNearMiss.
  ///
  /// In en, this message translates to:
  /// **'Close calls'**
  String get statNearMiss;

  /// No description provided for @statMix.
  ///
  /// In en, this message translates to:
  /// **'Mixed gates'**
  String get statMix;

  /// No description provided for @statDaily.
  ///
  /// In en, this message translates to:
  /// **'Daily challenges'**
  String get statDaily;

  /// No description provided for @statColors.
  ///
  /// In en, this message translates to:
  /// **'Gates by colour'**
  String get statColors;

  /// No description provided for @shop.
  ///
  /// In en, this message translates to:
  /// **'Shop'**
  String get shop;

  /// No description provided for @shopInfo.
  ///
  /// In en, this message translates to:
  /// **'Only looks for Mixo: they never make the game easier. Real prices, no surprises.'**
  String get shopInfo;

  /// No description provided for @packContains.
  ///
  /// In en, this message translates to:
  /// **'This pack contains:'**
  String get packContains;

  /// No description provided for @buyFor.
  ///
  /// In en, this message translates to:
  /// **'Buy for {price}'**
  String buyFor(String price);

  /// No description provided for @owned.
  ///
  /// In en, this message translates to:
  /// **'Owned'**
  String get owned;

  /// No description provided for @priceUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Price unavailable'**
  String get priceUnavailable;

  /// No description provided for @storeUnavailable.
  ///
  /// In en, this message translates to:
  /// **'The store is not available right now. The game works fine without it!'**
  String get storeUnavailable;

  /// No description provided for @purchasesDisabled.
  ///
  /// In en, this message translates to:
  /// **'Purchases are turned off in the parent area.'**
  String get purchasesDisabled;

  /// No description provided for @restorePurchases.
  ///
  /// In en, this message translates to:
  /// **'Restore purchases'**
  String get restorePurchases;

  /// No description provided for @purchasePending.
  ///
  /// In en, this message translates to:
  /// **'Purchase pending…'**
  String get purchasePending;

  /// No description provided for @purchaseDone.
  ///
  /// In en, this message translates to:
  /// **'Thank you! Your items are in the Collection.'**
  String get purchaseDone;

  /// No description provided for @purchasesRestored.
  ///
  /// In en, this message translates to:
  /// **'Purchases restored.'**
  String get purchasesRestored;

  /// No description provided for @purchaseError.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. No money was taken.'**
  String get purchaseError;

  /// No description provided for @purchaseCancelled.
  ///
  /// In en, this message translates to:
  /// **'Purchase cancelled.'**
  String get purchaseCancelled;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @sound.
  ///
  /// In en, this message translates to:
  /// **'Sound effects'**
  String get sound;

  /// No description provided for @music.
  ///
  /// In en, this message translates to:
  /// **'Music'**
  String get music;

  /// No description provided for @vibration.
  ///
  /// In en, this message translates to:
  /// **'Vibration'**
  String get vibration;

  /// No description provided for @symbolsAlways.
  ///
  /// In en, this message translates to:
  /// **'Colour symbols always on'**
  String get symbolsAlways;

  /// No description provided for @reduceEffects.
  ///
  /// In en, this message translates to:
  /// **'Calmer effects (no shake)'**
  String get reduceEffects;

  /// No description provided for @controls.
  ///
  /// In en, this message translates to:
  /// **'Controls'**
  String get controls;

  /// No description provided for @controlSwipe.
  ///
  /// In en, this message translates to:
  /// **'Swipe'**
  String get controlSwipe;

  /// No description provided for @controlTap.
  ///
  /// In en, this message translates to:
  /// **'Tap sides'**
  String get controlTap;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @languageSystem.
  ///
  /// In en, this message translates to:
  /// **'Device'**
  String get languageSystem;

  /// No description provided for @parentArea.
  ///
  /// In en, this message translates to:
  /// **'Parent area'**
  String get parentArea;

  /// No description provided for @privacy.
  ///
  /// In en, this message translates to:
  /// **'Privacy policy'**
  String get privacy;

  /// No description provided for @credits.
  ///
  /// In en, this message translates to:
  /// **'Credits'**
  String get credits;

  /// No description provided for @pickName.
  ///
  /// In en, this message translates to:
  /// **'Pick your name'**
  String get pickName;

  /// No description provided for @gateTitle.
  ///
  /// In en, this message translates to:
  /// **'Ask a grown-up'**
  String get gateTitle;

  /// No description provided for @gateHold.
  ///
  /// In en, this message translates to:
  /// **'Grown-ups: hold the button for 3 seconds.'**
  String get gateHold;

  /// No description provided for @gateWrong.
  ///
  /// In en, this message translates to:
  /// **'Not quite. Try this one.'**
  String get gateWrong;

  /// No description provided for @dailyLimit.
  ///
  /// In en, this message translates to:
  /// **'Daily play limit'**
  String get dailyLimit;

  /// No description provided for @playedToday.
  ///
  /// In en, this message translates to:
  /// **'Played today: {minutes} min'**
  String playedToday(int minutes);

  /// No description provided for @noLimit.
  ///
  /// In en, this message translates to:
  /// **'No limit'**
  String get noLimit;

  /// No description provided for @extend15.
  ///
  /// In en, this message translates to:
  /// **'+15 minutes today'**
  String get extend15;

  /// No description provided for @purchasesEnabled.
  ///
  /// In en, this message translates to:
  /// **'Allow purchases'**
  String get purchasesEnabled;

  /// No description provided for @purchasesInfo.
  ///
  /// In en, this message translates to:
  /// **'Every purchase also asks for the parental check.'**
  String get purchasesInfo;

  /// No description provided for @parentPrivacyTitle.
  ///
  /// In en, this message translates to:
  /// **'No personal data collected'**
  String get parentPrivacyTitle;

  /// No description provided for @parentPrivacyBody.
  ///
  /// In en, this message translates to:
  /// **'No account, no chat, no ads, no tracking. Progress stays on this device only. The internet is used only by Google Play for optional purchases.'**
  String get parentPrivacyBody;

  /// No description provided for @resetProgress.
  ///
  /// In en, this message translates to:
  /// **'Reset all progress'**
  String get resetProgress;

  /// No description provided for @resetConfirm.
  ///
  /// In en, this message translates to:
  /// **'This deletes levels, stars and collection on this device. Purchases can be restored from the shop.'**
  String get resetConfirm;

  /// No description provided for @reset.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get reset;

  /// No description provided for @privacyText.
  ///
  /// In en, this message translates to:
  /// **'MIXO: Color Rush — Privacy policy (summary)\n\n• We do not collect personal data. There are no accounts, no email, no real names, no location and no advertising ID.\n• Your nickname is generated from a list: nobody can type personal information.\n• There is no chat and no communication between players.\n• There are no ads and no analytics or tracking tools.\n• Game progress (levels, stars, settings) is saved only on this device. Uninstalling the app deletes it.\n• Optional purchases are handled entirely by Google Play under Google\'s privacy policy. We receive no payment details.\n• Purchases require a parental check and can be disabled in the parent area.\n\nQuestions: see the contact e-mail on the Google Play page of the app.'**
  String get privacyText;

  /// No description provided for @creditsText.
  ///
  /// In en, this message translates to:
  /// **'MIXO: Color Rush\n\nGame design, code, graphics, music and sound effects created for this project: every image is drawn by code and every sound is synthesised by a script included in the source.\n\nBuilt with Flutter and the Flame engine (open source, BSD/MIT licences).\n\nThank you for playing!'**
  String get creditsText;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'it'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'it':
      return AppLocalizationsIt();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
