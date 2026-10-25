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
/// import 'l10n/app_localizations.dart';
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
  /// **'Orbit Commando \'94'**
  String get appTitle;

  /// No description provided for @pressStart.
  ///
  /// In en, this message translates to:
  /// **'Press start'**
  String get pressStart;

  /// No description provided for @insertCoin.
  ///
  /// In en, this message translates to:
  /// **'Insert coin'**
  String get insertCoin;

  /// No description provided for @creditsLabel.
  ///
  /// In en, this message translates to:
  /// **'Credits {count}'**
  String creditsLabel(int count);

  /// No description provided for @sandboxLabel.
  ///
  /// In en, this message translates to:
  /// **'Sandbox'**
  String get sandboxLabel;

  /// No description provided for @studioPresents.
  ///
  /// In en, this message translates to:
  /// **'Pixel Orbit Studio presents'**
  String get studioPresents;

  /// No description provided for @copyright.
  ///
  /// In en, this message translates to:
  /// **'(c) 1994 Pixel Orbit Studio'**
  String get copyright;

  /// No description provided for @back.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get back;

  /// No description provided for @ok.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get ok;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @yes.
  ///
  /// In en, this message translates to:
  /// **'Yes'**
  String get yes;

  /// No description provided for @no.
  ///
  /// In en, this message translates to:
  /// **'No'**
  String get no;

  /// No description provided for @next.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get next;

  /// No description provided for @play.
  ///
  /// In en, this message translates to:
  /// **'Play'**
  String get play;

  /// No description provided for @locked.
  ///
  /// In en, this message translates to:
  /// **'Locked'**
  String get locked;

  /// No description provided for @loading.
  ///
  /// In en, this message translates to:
  /// **'Loading...'**
  String get loading;

  /// No description provided for @comingSoon.
  ///
  /// In en, this message translates to:
  /// **'Available online in v2'**
  String get comingSoon;

  /// No description provided for @menuCampaign.
  ///
  /// In en, this message translates to:
  /// **'Campaign'**
  String get menuCampaign;

  /// No description provided for @menuArcade.
  ///
  /// In en, this message translates to:
  /// **'Arcade mode'**
  String get menuArcade;

  /// No description provided for @menuBossRush.
  ///
  /// In en, this message translates to:
  /// **'Boss rush'**
  String get menuBossRush;

  /// No description provided for @menuWeekly.
  ///
  /// In en, this message translates to:
  /// **'Weekly challenge'**
  String get menuWeekly;

  /// No description provided for @menuWorkshop.
  ///
  /// In en, this message translates to:
  /// **'Workshop'**
  String get menuWorkshop;

  /// No description provided for @menuGallery.
  ///
  /// In en, this message translates to:
  /// **'Gallery'**
  String get menuGallery;

  /// No description provided for @menuJukebox.
  ///
  /// In en, this message translates to:
  /// **'Juke-box'**
  String get menuJukebox;

  /// No description provided for @menuShop.
  ///
  /// In en, this message translates to:
  /// **'Shop'**
  String get menuShop;

  /// No description provided for @menuTrophies.
  ///
  /// In en, this message translates to:
  /// **'Trophies'**
  String get menuTrophies;

  /// No description provided for @menuScores.
  ///
  /// In en, this message translates to:
  /// **'High scores'**
  String get menuScores;

  /// No description provided for @menuSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get menuSettings;

  /// No description provided for @menuChat.
  ///
  /// In en, this message translates to:
  /// **'Squadron chat'**
  String get menuChat;

  /// No description provided for @unlockArcade.
  ///
  /// In en, this message translates to:
  /// **'Clear World 1 to unlock'**
  String get unlockArcade;

  /// No description provided for @unlockBossRush.
  ///
  /// In en, this message translates to:
  /// **'Beat the campaign to unlock'**
  String get unlockBossRush;

  /// No description provided for @pilotRank.
  ///
  /// In en, this message translates to:
  /// **'Pilot rank {rank}'**
  String pilotRank(int rank);

  /// No description provided for @tokens.
  ///
  /// In en, this message translates to:
  /// **'Tokens {count}'**
  String tokens(int count);

  /// No description provided for @worldN.
  ///
  /// In en, this message translates to:
  /// **'World {n}'**
  String worldN(int n);

  /// No description provided for @world1Name.
  ///
  /// In en, this message translates to:
  /// **'Quiet Asteroid Belt'**
  String get world1Name;

  /// No description provided for @world2Name.
  ///
  /// In en, this message translates to:
  /// **'Pizza-Station Orbital'**
  String get world2Name;

  /// No description provided for @world3Name.
  ///
  /// In en, this message translates to:
  /// **'Planet Glorbo Prime'**
  String get world3Name;

  /// No description provided for @levelN.
  ///
  /// In en, this message translates to:
  /// **'Level {n}'**
  String levelN(int n);

  /// No description provided for @bossStage.
  ///
  /// In en, this message translates to:
  /// **'Boss'**
  String get bossStage;

  /// No description provided for @bestScore.
  ///
  /// In en, this message translates to:
  /// **'Best {score}'**
  String bestScore(int score);

  /// No description provided for @difficulty.
  ///
  /// In en, this message translates to:
  /// **'Difficulty'**
  String get difficulty;

  /// No description provided for @diffEasy.
  ///
  /// In en, this message translates to:
  /// **'Easy'**
  String get diffEasy;

  /// No description provided for @diffNormal.
  ///
  /// In en, this message translates to:
  /// **'Normal'**
  String get diffNormal;

  /// No description provided for @diffArcade.
  ///
  /// In en, this message translates to:
  /// **'Arcade'**
  String get diffArcade;

  /// No description provided for @diffEasyHelp.
  ///
  /// In en, this message translates to:
  /// **'3 hit points, auto-aim, slower enemies'**
  String get diffEasyHelp;

  /// No description provided for @diffNormalHelp.
  ///
  /// In en, this message translates to:
  /// **'One hit, one life'**
  String get diffNormalHelp;

  /// No description provided for @diffArcadeHelp.
  ///
  /// In en, this message translates to:
  /// **'Like Normal, limited credits, no upgrades'**
  String get diffArcadeHelp;

  /// No description provided for @chooseHero.
  ///
  /// In en, this message translates to:
  /// **'Choose your commando'**
  String get chooseHero;

  /// No description provided for @heroLocked.
  ///
  /// In en, this message translates to:
  /// **'Locked'**
  String get heroLocked;

  /// No description provided for @heroRoxy.
  ///
  /// In en, this message translates to:
  /// **'Fast and fearless. Never misses a jump.'**
  String get heroRoxy;

  /// No description provided for @heroBrutus.
  ///
  /// In en, this message translates to:
  /// **'Big guns, bigger heart.'**
  String get heroBrutus;

  /// No description provided for @heroNyx.
  ///
  /// In en, this message translates to:
  /// **'Unlock: beat World 2.'**
  String get heroNyx;

  /// No description provided for @heroDoc.
  ///
  /// In en, this message translates to:
  /// **'Unlock: beat the campaign.'**
  String get heroDoc;

  /// No description provided for @heroNyxBio.
  ///
  /// In en, this message translates to:
  /// **'Twin pistols, zero patience.'**
  String get heroNyxBio;

  /// No description provided for @heroDocBio.
  ///
  /// In en, this message translates to:
  /// **'Built his own cannon. From a toaster.'**
  String get heroDocBio;

  /// No description provided for @paused.
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get paused;

  /// No description provided for @resume.
  ///
  /// In en, this message translates to:
  /// **'Resume'**
  String get resume;

  /// No description provided for @restart.
  ///
  /// In en, this message translates to:
  /// **'Restart'**
  String get restart;

  /// No description provided for @quitToMap.
  ///
  /// In en, this message translates to:
  /// **'Quit to map'**
  String get quitToMap;

  /// No description provided for @quitToTitle.
  ///
  /// In en, this message translates to:
  /// **'Quit to title'**
  String get quitToTitle;

  /// No description provided for @continueQuestion.
  ///
  /// In en, this message translates to:
  /// **'Continue?'**
  String get continueQuestion;

  /// No description provided for @continueCost.
  ///
  /// In en, this message translates to:
  /// **'1 credit'**
  String get continueCost;

  /// No description provided for @gameOver.
  ///
  /// In en, this message translates to:
  /// **'Game over'**
  String get gameOver;

  /// No description provided for @noCredits.
  ///
  /// In en, this message translates to:
  /// **'No credits left'**
  String get noCredits;

  /// No description provided for @watchAdCredit.
  ///
  /// In en, this message translates to:
  /// **'Watch a video: +1 credit'**
  String get watchAdCredit;

  /// No description provided for @assistTitle.
  ///
  /// In en, this message translates to:
  /// **'Need a hand?'**
  String get assistTitle;

  /// No description provided for @assistBody.
  ///
  /// In en, this message translates to:
  /// **'Take a 10 second shield? No penalty.'**
  String get assistBody;

  /// No description provided for @assistYes.
  ///
  /// In en, this message translates to:
  /// **'Shield on'**
  String get assistYes;

  /// No description provided for @assistNo.
  ///
  /// In en, this message translates to:
  /// **'I got this'**
  String get assistNo;

  /// No description provided for @stageClear.
  ///
  /// In en, this message translates to:
  /// **'Stage clear!'**
  String get stageClear;

  /// No description provided for @score.
  ///
  /// In en, this message translates to:
  /// **'Score'**
  String get score;

  /// No description provided for @timeBonus.
  ///
  /// In en, this message translates to:
  /// **'Time bonus'**
  String get timeBonus;

  /// No description provided for @noDeathBonus.
  ///
  /// In en, this message translates to:
  /// **'No death bonus'**
  String get noDeathBonus;

  /// No description provided for @total.
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get total;

  /// No description provided for @rank.
  ///
  /// In en, this message translates to:
  /// **'Rank'**
  String get rank;

  /// No description provided for @time.
  ///
  /// In en, this message translates to:
  /// **'Time'**
  String get time;

  /// No description provided for @hostages.
  ///
  /// In en, this message translates to:
  /// **'Hostages'**
  String get hostages;

  /// No description provided for @cassettes.
  ///
  /// In en, this message translates to:
  /// **'Cassettes'**
  String get cassettes;

  /// No description provided for @kills.
  ///
  /// In en, this message translates to:
  /// **'Kills'**
  String get kills;

  /// No description provided for @medalNoDeath.
  ///
  /// In en, this message translates to:
  /// **'No death'**
  String get medalNoDeath;

  /// No description provided for @medalHostages.
  ///
  /// In en, this message translates to:
  /// **'All hostages'**
  String get medalHostages;

  /// No description provided for @medalSpeedrun.
  ///
  /// In en, this message translates to:
  /// **'Speedrun'**
  String get medalSpeedrun;

  /// No description provided for @newRecord.
  ///
  /// In en, this message translates to:
  /// **'New record!'**
  String get newRecord;

  /// No description provided for @earnedTokens.
  ///
  /// In en, this message translates to:
  /// **'+{count} tokens'**
  String earnedTokens(int count);

  /// No description provided for @earnedCredit.
  ///
  /// In en, this message translates to:
  /// **'+1 credit'**
  String get earnedCredit;

  /// No description provided for @unlockedArcade.
  ///
  /// In en, this message translates to:
  /// **'Arcade mode unlocked!'**
  String get unlockedArcade;

  /// No description provided for @unlockedBossRush.
  ///
  /// In en, this message translates to:
  /// **'Boss rush unlocked!'**
  String get unlockedBossRush;

  /// No description provided for @unlockedHero.
  ///
  /// In en, this message translates to:
  /// **'New commando: {name}!'**
  String unlockedHero(String name);

  /// No description provided for @trophyUnlocked.
  ///
  /// In en, this message translates to:
  /// **'Trophy: {name}'**
  String trophyUnlocked(String name);

  /// No description provided for @enterInitials.
  ///
  /// In en, this message translates to:
  /// **'Enter your initials'**
  String get enterInitials;

  /// No description provided for @doubleTokensAd.
  ///
  /// In en, this message translates to:
  /// **'Watch a video: double tokens'**
  String get doubleTokensAd;

  /// No description provided for @campaignComplete.
  ///
  /// In en, this message translates to:
  /// **'The Glorbo Empire is filed away. Thank you, commando!'**
  String get campaignComplete;

  /// No description provided for @setAudio.
  ///
  /// In en, this message translates to:
  /// **'Audio'**
  String get setAudio;

  /// No description provided for @setMusic.
  ///
  /// In en, this message translates to:
  /// **'Music'**
  String get setMusic;

  /// No description provided for @setSfx.
  ///
  /// In en, this message translates to:
  /// **'Effects'**
  String get setSfx;

  /// No description provided for @setVideo.
  ///
  /// In en, this message translates to:
  /// **'Video'**
  String get setVideo;

  /// No description provided for @setCrt.
  ///
  /// In en, this message translates to:
  /// **'CRT filter'**
  String get setCrt;

  /// No description provided for @crtOff.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get crtOff;

  /// No description provided for @crtArcade.
  ///
  /// In en, this message translates to:
  /// **'Arcade cabinet'**
  String get crtArcade;

  /// No description provided for @crtTv.
  ///
  /// In en, this message translates to:
  /// **'Living room TV'**
  String get crtTv;

  /// No description provided for @setGame.
  ///
  /// In en, this message translates to:
  /// **'Game'**
  String get setGame;

  /// No description provided for @setCamera.
  ///
  /// In en, this message translates to:
  /// **'Camera'**
  String get setCamera;

  /// No description provided for @cameraRotating.
  ///
  /// In en, this message translates to:
  /// **'Rotating'**
  String get cameraRotating;

  /// No description provided for @cameraFixed.
  ///
  /// In en, this message translates to:
  /// **'Fixed (less motion)'**
  String get cameraFixed;

  /// No description provided for @setAutoAim.
  ///
  /// In en, this message translates to:
  /// **'Auto-aim'**
  String get setAutoAim;

  /// No description provided for @setVibration.
  ///
  /// In en, this message translates to:
  /// **'Vibration'**
  String get setVibration;

  /// No description provided for @setLanguage.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get setLanguage;

  /// No description provided for @langSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get langSystem;

  /// No description provided for @setControls.
  ///
  /// In en, this message translates to:
  /// **'Controls layout'**
  String get setControls;

  /// No description provided for @controlsHelp.
  ///
  /// In en, this message translates to:
  /// **'Drag buttons to move them. Pinch or use +/- to resize.'**
  String get controlsHelp;

  /// No description provided for @opacity.
  ///
  /// In en, this message translates to:
  /// **'Opacity'**
  String get opacity;

  /// No description provided for @resetDefaults.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get resetDefaults;

  /// No description provided for @setPrivacy.
  ///
  /// In en, this message translates to:
  /// **'Privacy'**
  String get setPrivacy;

  /// No description provided for @setAnalytics.
  ///
  /// In en, this message translates to:
  /// **'Share anonymous stats'**
  String get setAnalytics;

  /// No description provided for @setChat.
  ///
  /// In en, this message translates to:
  /// **'Chat'**
  String get setChat;

  /// No description provided for @setNotifications.
  ///
  /// In en, this message translates to:
  /// **'Offer notifications'**
  String get setNotifications;

  /// No description provided for @setConsent.
  ///
  /// In en, this message translates to:
  /// **'Ad consent'**
  String get setConsent;

  /// No description provided for @setSpendLimit.
  ///
  /// In en, this message translates to:
  /// **'Monthly spending limit'**
  String get setSpendLimit;

  /// No description provided for @noLimit.
  ///
  /// In en, this message translates to:
  /// **'No limit'**
  String get noLimit;

  /// No description provided for @purchaseHistory.
  ///
  /// In en, this message translates to:
  /// **'Purchase history'**
  String get purchaseHistory;

  /// No description provided for @restorePurchases.
  ///
  /// In en, this message translates to:
  /// **'Restore purchases'**
  String get restorePurchases;

  /// No description provided for @privacyPolicy.
  ///
  /// In en, this message translates to:
  /// **'Privacy policy'**
  String get privacyPolicy;

  /// No description provided for @deleteData.
  ///
  /// In en, this message translates to:
  /// **'Delete my data'**
  String get deleteData;

  /// No description provided for @on.
  ///
  /// In en, this message translates to:
  /// **'On'**
  String get on;

  /// No description provided for @off.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get off;

  /// No description provided for @upDamage.
  ///
  /// In en, this message translates to:
  /// **'Weapon damage'**
  String get upDamage;

  /// No description provided for @upHp.
  ///
  /// In en, this message translates to:
  /// **'Extra hit points'**
  String get upHp;

  /// No description provided for @upShield.
  ///
  /// In en, this message translates to:
  /// **'Spawn shield'**
  String get upShield;

  /// No description provided for @upFireRate.
  ///
  /// In en, this message translates to:
  /// **'Fire rate'**
  String get upFireRate;

  /// No description provided for @upGrenades.
  ///
  /// In en, this message translates to:
  /// **'Starting grenades'**
  String get upGrenades;

  /// No description provided for @upLevel.
  ///
  /// In en, this message translates to:
  /// **'Lv {level}/{max}'**
  String upLevel(int level, int max);

  /// No description provided for @buyTokens.
  ///
  /// In en, this message translates to:
  /// **'{count} tokens'**
  String buyTokens(int count);

  /// No description provided for @buyGems.
  ///
  /// In en, this message translates to:
  /// **'{count} gems'**
  String buyGems(int count);

  /// No description provided for @maxed.
  ///
  /// In en, this message translates to:
  /// **'Max'**
  String get maxed;

  /// No description provided for @notEnough.
  ///
  /// In en, this message translates to:
  /// **'Not enough'**
  String get notEnough;

  /// No description provided for @arcadeNoUpgrades.
  ///
  /// In en, this message translates to:
  /// **'Upgrades are off in Arcade difficulty.'**
  String get arcadeNoUpgrades;

  /// No description provided for @galleryLocked.
  ///
  /// In en, this message translates to:
  /// **'Find more cassettes to unlock'**
  String get galleryLocked;

  /// No description provided for @cassettesFound.
  ///
  /// In en, this message translates to:
  /// **'Cassettes {count}/{total}'**
  String cassettesFound(int count, int total);

  /// No description provided for @nowPlaying.
  ///
  /// In en, this message translates to:
  /// **'Now playing'**
  String get nowPlaying;

  /// No description provided for @trophiesCount.
  ///
  /// In en, this message translates to:
  /// **'{count}/{total} trophies'**
  String trophiesCount(int count, int total);

  /// No description provided for @tip1.
  ///
  /// In en, this message translates to:
  /// **'Manual p.12: grenades bounce. So do your excuses.'**
  String get tip1;

  /// No description provided for @tip2.
  ///
  /// In en, this message translates to:
  /// **'Manual p.4: blow into the cartridge if the planet won\'t load.'**
  String get tip2;

  /// No description provided for @tip3.
  ///
  /// In en, this message translates to:
  /// **'Manual p.9: on a planetoid, down is wherever your feet are.'**
  String get tip3;

  /// No description provided for @tip4.
  ///
  /// In en, this message translates to:
  /// **'Manual p.21: the Glorbo fear only two things: you and paperwork errors.'**
  String get tip4;

  /// No description provided for @tip5.
  ///
  /// In en, this message translates to:
  /// **'Manual p.7: enemies shout before shooting. Listen.'**
  String get tip5;

  /// No description provided for @tip6.
  ///
  /// In en, this message translates to:
  /// **'Manual p.30: hostages tip well. In grenades.'**
  String get tip6;

  /// No description provided for @tip7.
  ///
  /// In en, this message translates to:
  /// **'Manual p.16: walking upside down voids no warranty.'**
  String get tip7;

  /// No description provided for @tip8.
  ///
  /// In en, this message translates to:
  /// **'Manual p.2: do not feed the washing machine. Seriously.'**
  String get tip8;

  /// No description provided for @cheatBigHeads.
  ///
  /// In en, this message translates to:
  /// **'Big heads!'**
  String get cheatBigHeads;

  /// No description provided for @cheatGiantPixels.
  ///
  /// In en, this message translates to:
  /// **'Giant pixels!'**
  String get cheatGiantPixels;

  /// No description provided for @cheatBrokenTube.
  ///
  /// In en, this message translates to:
  /// **'Broken tube mode!'**
  String get cheatBrokenTube;

  /// No description provided for @shopCartridge.
  ///
  /// In en, this message translates to:
  /// **'Full Cartridge'**
  String get shopCartridge;

  /// No description provided for @shopCartridgeDesc.
  ///
  /// In en, this message translates to:
  /// **'Worlds 2-3, Boss Rush, infinite campaign credits, no ads. Like buying the cartridge: once.'**
  String get shopCartridgeDesc;

  /// No description provided for @owned.
  ///
  /// In en, this message translates to:
  /// **'Owned'**
  String get owned;

  /// No description provided for @gems.
  ///
  /// In en, this message translates to:
  /// **'Quasar gems'**
  String get gems;

  /// No description provided for @gemsApprox.
  ///
  /// In en, this message translates to:
  /// **'about {price}'**
  String gemsApprox(String price);

  /// No description provided for @capsules.
  ///
  /// In en, this message translates to:
  /// **'Cosmic capsules'**
  String get capsules;

  /// No description provided for @capsuleOpen.
  ///
  /// In en, this message translates to:
  /// **'Open capsule'**
  String get capsuleOpen;

  /// No description provided for @capsuleFree.
  ///
  /// In en, this message translates to:
  /// **'Free daily capsule'**
  String get capsuleFree;

  /// No description provided for @capsuleOdds.
  ///
  /// In en, this message translates to:
  /// **'Odds'**
  String get capsuleOdds;

  /// No description provided for @capsuleOddsTitle.
  ///
  /// In en, this message translates to:
  /// **'Exact drop odds'**
  String get capsuleOddsTitle;

  /// No description provided for @pityCounter.
  ///
  /// In en, this message translates to:
  /// **'Legendary guaranteed in {count} opens'**
  String pityCounter(int count);

  /// No description provided for @rarityCommon.
  ///
  /// In en, this message translates to:
  /// **'Common'**
  String get rarityCommon;

  /// No description provided for @rarityRare.
  ///
  /// In en, this message translates to:
  /// **'Rare'**
  String get rarityRare;

  /// No description provided for @rarityEpic.
  ///
  /// In en, this message translates to:
  /// **'Epic'**
  String get rarityEpic;

  /// No description provided for @rarityLegendary.
  ///
  /// In en, this message translates to:
  /// **'Legendary'**
  String get rarityLegendary;

  /// No description provided for @paidCapsulesBlocked.
  ///
  /// In en, this message translates to:
  /// **'Paid capsules are not available in your country. Free capsules still work.'**
  String get paidCapsulesBlocked;

  /// No description provided for @paidCapsulesMinor.
  ///
  /// In en, this message translates to:
  /// **'Paid capsules are disabled for players under 18.'**
  String get paidCapsulesMinor;

  /// No description provided for @dailyShop.
  ///
  /// In en, this message translates to:
  /// **'Shop of the day'**
  String get dailyShop;

  /// No description provided for @refreshesIn.
  ///
  /// In en, this message translates to:
  /// **'Refreshes in {time}'**
  String refreshesIn(String time);

  /// No description provided for @flashOffer.
  ///
  /// In en, this message translates to:
  /// **'Flash offer'**
  String get flashOffer;

  /// No description provided for @endsIn.
  ///
  /// In en, this message translates to:
  /// **'Ends in {time}'**
  String endsIn(String time);

  /// No description provided for @seasonPass.
  ///
  /// In en, this message translates to:
  /// **'Season pass'**
  String get seasonPass;

  /// No description provided for @seasonEndsIn.
  ///
  /// In en, this message translates to:
  /// **'Season ends in {time}'**
  String seasonEndsIn(String time);

  /// No description provided for @freeTrack.
  ///
  /// In en, this message translates to:
  /// **'Free'**
  String get freeTrack;

  /// No description provided for @premiumTrack.
  ///
  /// In en, this message translates to:
  /// **'Premium'**
  String get premiumTrack;

  /// No description provided for @dailyLogin.
  ///
  /// In en, this message translates to:
  /// **'Daily login'**
  String get dailyLogin;

  /// No description provided for @dayN.
  ///
  /// In en, this message translates to:
  /// **'Day {n}'**
  String dayN(int n);

  /// No description provided for @claim.
  ///
  /// In en, this message translates to:
  /// **'Claim'**
  String get claim;

  /// No description provided for @claimed.
  ///
  /// In en, this message translates to:
  /// **'Claimed'**
  String get claimed;

  /// No description provided for @buy.
  ///
  /// In en, this message translates to:
  /// **'Buy'**
  String get buy;

  /// No description provided for @storeUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Store not available on this device.'**
  String get storeUnavailable;

  /// No description provided for @spendLimitReached.
  ///
  /// In en, this message translates to:
  /// **'Monthly spending limit reached.'**
  String get spendLimitReached;

  /// No description provided for @purchasePending.
  ///
  /// In en, this message translates to:
  /// **'Purchase pending...'**
  String get purchasePending;

  /// No description provided for @purchaseDone.
  ///
  /// In en, this message translates to:
  /// **'Thank you!'**
  String get purchaseDone;

  /// No description provided for @starterPack.
  ///
  /// In en, this message translates to:
  /// **'Starter pack'**
  String get starterPack;

  /// No description provided for @weeklyEvent.
  ///
  /// In en, this message translates to:
  /// **'Weekly event'**
  String get weeklyEvent;

  /// No description provided for @noPurchases.
  ///
  /// In en, this message translates to:
  /// **'No purchases yet.'**
  String get noPurchases;

  /// No description provided for @ageGateTitle.
  ///
  /// In en, this message translates to:
  /// **'When were you born?'**
  String get ageGateTitle;

  /// No description provided for @ageGateBody.
  ///
  /// In en, this message translates to:
  /// **'We ask once, to set the right features for your age.'**
  String get ageGateBody;

  /// No description provided for @year.
  ///
  /// In en, this message translates to:
  /// **'Year'**
  String get year;

  /// No description provided for @month.
  ///
  /// In en, this message translates to:
  /// **'Month'**
  String get month;

  /// No description provided for @confirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get confirm;

  /// No description provided for @onlineUnder16.
  ///
  /// In en, this message translates to:
  /// **'Online features are available from age 16.'**
  String get onlineUnder16;

  /// No description provided for @chatEmotesOnly.
  ///
  /// In en, this message translates to:
  /// **'Quick messages only (under 18).'**
  String get chatEmotesOnly;

  /// No description provided for @chatSignIn.
  ///
  /// In en, this message translates to:
  /// **'Sign in with Google to chat'**
  String get chatSignIn;

  /// No description provided for @chatGlobal.
  ///
  /// In en, this message translates to:
  /// **'Global'**
  String get chatGlobal;

  /// No description provided for @chatSquadron.
  ///
  /// In en, this message translates to:
  /// **'Squadron'**
  String get chatSquadron;

  /// No description provided for @chatFriends.
  ///
  /// In en, this message translates to:
  /// **'Friends'**
  String get chatFriends;

  /// No description provided for @chatSend.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get chatSend;

  /// No description provided for @chatReport.
  ///
  /// In en, this message translates to:
  /// **'Report'**
  String get chatReport;

  /// No description provided for @chatBlock.
  ///
  /// In en, this message translates to:
  /// **'Block'**
  String get chatBlock;

  /// No description provided for @chatSlowDown.
  ///
  /// In en, this message translates to:
  /// **'Slow down: 1 message every 3 seconds.'**
  String get chatSlowDown;

  /// No description provided for @chatFiltered.
  ///
  /// In en, this message translates to:
  /// **'Message blocked by the filter.'**
  String get chatFiltered;

  /// No description provided for @chatMuted.
  ///
  /// In en, this message translates to:
  /// **'You are muted for a while.'**
  String get chatMuted;

  /// No description provided for @chatDisabled.
  ///
  /// In en, this message translates to:
  /// **'Chat is turned off in Settings.'**
  String get chatDisabled;

  /// No description provided for @chatOffline.
  ///
  /// In en, this message translates to:
  /// **'Chat needs a connection.'**
  String get chatOffline;

  /// No description provided for @reported.
  ///
  /// In en, this message translates to:
  /// **'Reported. Thanks!'**
  String get reported;

  /// No description provided for @emoteNiceShot.
  ///
  /// In en, this message translates to:
  /// **'Nice shot!'**
  String get emoteNiceShot;

  /// No description provided for @emoteHelpBoss.
  ///
  /// In en, this message translates to:
  /// **'Help with the boss?'**
  String get emoteHelpBoss;

  /// No description provided for @emoteGG.
  ///
  /// In en, this message translates to:
  /// **'GG'**
  String get emoteGG;

  /// No description provided for @emoteHi.
  ///
  /// In en, this message translates to:
  /// **'Hi!'**
  String get emoteHi;

  /// No description provided for @emoteThanks.
  ///
  /// In en, this message translates to:
  /// **'Thanks!'**
  String get emoteThanks;

  /// No description provided for @emoteOneMore.
  ///
  /// In en, this message translates to:
  /// **'One more!'**
  String get emoteOneMore;

  /// No description provided for @squadGoal.
  ///
  /// In en, this message translates to:
  /// **'Weekly squadron goal'**
  String get squadGoal;
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
