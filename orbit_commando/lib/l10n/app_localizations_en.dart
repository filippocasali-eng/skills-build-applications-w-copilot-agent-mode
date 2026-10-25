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
  String get sandboxLabel => 'Sandbox';

  @override
  String get studioPresents => 'Pixel Orbit Studio presents';

  @override
  String get copyright => '(c) 1994 Pixel Orbit Studio';

  @override
  String get back => 'Back';

  @override
  String get ok => 'OK';

  @override
  String get cancel => 'Cancel';

  @override
  String get yes => 'Yes';

  @override
  String get no => 'No';

  @override
  String get next => 'Next';

  @override
  String get play => 'Play';

  @override
  String get locked => 'Locked';

  @override
  String get loading => 'Loading...';

  @override
  String get comingSoon => 'Available online in v2';

  @override
  String get menuCampaign => 'Campaign';

  @override
  String get menuArcade => 'Arcade mode';

  @override
  String get menuBossRush => 'Boss rush';

  @override
  String get menuWeekly => 'Weekly challenge';

  @override
  String get menuWorkshop => 'Workshop';

  @override
  String get menuGallery => 'Gallery';

  @override
  String get menuJukebox => 'Juke-box';

  @override
  String get menuShop => 'Shop';

  @override
  String get menuTrophies => 'Trophies';

  @override
  String get menuScores => 'High scores';

  @override
  String get menuSettings => 'Settings';

  @override
  String get menuChat => 'Squadron chat';

  @override
  String get unlockArcade => 'Clear World 1 to unlock';

  @override
  String get unlockBossRush => 'Beat the campaign to unlock';

  @override
  String pilotRank(int rank) {
    return 'Pilot rank $rank';
  }

  @override
  String tokens(int count) {
    return 'Tokens $count';
  }

  @override
  String worldN(int n) {
    return 'World $n';
  }

  @override
  String get world1Name => 'Quiet Asteroid Belt';

  @override
  String get world2Name => 'Pizza-Station Orbital';

  @override
  String get world3Name => 'Planet Glorbo Prime';

  @override
  String levelN(int n) {
    return 'Level $n';
  }

  @override
  String get bossStage => 'Boss';

  @override
  String bestScore(int score) {
    return 'Best $score';
  }

  @override
  String get difficulty => 'Difficulty';

  @override
  String get diffEasy => 'Easy';

  @override
  String get diffNormal => 'Normal';

  @override
  String get diffArcade => 'Arcade';

  @override
  String get diffEasyHelp => '3 hit points, auto-aim, slower enemies';

  @override
  String get diffNormalHelp => 'One hit, one life';

  @override
  String get diffArcadeHelp => 'Like Normal, limited credits, no upgrades';

  @override
  String get chooseHero => 'Choose your commando';

  @override
  String get heroLocked => 'Locked';

  @override
  String get heroRoxy => 'Fast and fearless. Never misses a jump.';

  @override
  String get heroBrutus => 'Big guns, bigger heart.';

  @override
  String get heroNyx => 'Unlock: beat World 2.';

  @override
  String get heroDoc => 'Unlock: beat the campaign.';

  @override
  String get heroNyxBio => 'Twin pistols, zero patience.';

  @override
  String get heroDocBio => 'Built his own cannon. From a toaster.';

  @override
  String get paused => 'Pause';

  @override
  String get resume => 'Resume';

  @override
  String get restart => 'Restart';

  @override
  String get quitToMap => 'Quit to map';

  @override
  String get quitToTitle => 'Quit to title';

  @override
  String get continueQuestion => 'Continue?';

  @override
  String get continueCost => '1 credit';

  @override
  String get gameOver => 'Game over';

  @override
  String get noCredits => 'No credits left';

  @override
  String get watchAdCredit => 'Watch a video: +1 credit';

  @override
  String get assistTitle => 'Need a hand?';

  @override
  String get assistBody => 'Take a 10 second shield? No penalty.';

  @override
  String get assistYes => 'Shield on';

  @override
  String get assistNo => 'I got this';

  @override
  String get stageClear => 'Stage clear!';

  @override
  String get score => 'Score';

  @override
  String get timeBonus => 'Time bonus';

  @override
  String get noDeathBonus => 'No death bonus';

  @override
  String get total => 'Total';

  @override
  String get rank => 'Rank';

  @override
  String get time => 'Time';

  @override
  String get hostages => 'Hostages';

  @override
  String get cassettes => 'Cassettes';

  @override
  String get kills => 'Kills';

  @override
  String get medalNoDeath => 'No death';

  @override
  String get medalHostages => 'All hostages';

  @override
  String get medalSpeedrun => 'Speedrun';

  @override
  String get newRecord => 'New record!';

  @override
  String earnedTokens(int count) {
    return '+$count tokens';
  }

  @override
  String get earnedCredit => '+1 credit';

  @override
  String get unlockedArcade => 'Arcade mode unlocked!';

  @override
  String get unlockedBossRush => 'Boss rush unlocked!';

  @override
  String unlockedHero(String name) {
    return 'New commando: $name!';
  }

  @override
  String trophyUnlocked(String name) {
    return 'Trophy: $name';
  }

  @override
  String get enterInitials => 'Enter your initials';

  @override
  String get doubleTokensAd => 'Watch a video: double tokens';

  @override
  String get campaignComplete =>
      'The Glorbo Empire is filed away. Thank you, commando!';

  @override
  String get setAudio => 'Audio';

  @override
  String get setMusic => 'Music';

  @override
  String get setSfx => 'Effects';

  @override
  String get setVideo => 'Video';

  @override
  String get setCrt => 'CRT filter';

  @override
  String get crtOff => 'Off';

  @override
  String get crtArcade => 'Arcade cabinet';

  @override
  String get crtTv => 'Living room TV';

  @override
  String get setGame => 'Game';

  @override
  String get setCamera => 'Camera';

  @override
  String get cameraRotating => 'Rotating';

  @override
  String get cameraFixed => 'Fixed (less motion)';

  @override
  String get setAutoAim => 'Auto-aim';

  @override
  String get setVibration => 'Vibration';

  @override
  String get setLanguage => 'Language';

  @override
  String get langSystem => 'System';

  @override
  String get setControls => 'Controls layout';

  @override
  String get controlsHelp =>
      'Drag buttons to move them. Pinch or use +/- to resize.';

  @override
  String get opacity => 'Opacity';

  @override
  String get resetDefaults => 'Reset';

  @override
  String get setPrivacy => 'Privacy';

  @override
  String get setAnalytics => 'Share anonymous stats';

  @override
  String get setChat => 'Chat';

  @override
  String get setNotifications => 'Offer notifications';

  @override
  String get setConsent => 'Ad consent';

  @override
  String get setSpendLimit => 'Monthly spending limit';

  @override
  String get noLimit => 'No limit';

  @override
  String get purchaseHistory => 'Purchase history';

  @override
  String get restorePurchases => 'Restore purchases';

  @override
  String get privacyPolicy => 'Privacy policy';

  @override
  String get deleteData => 'Delete my data';

  @override
  String get on => 'On';

  @override
  String get off => 'Off';

  @override
  String get upDamage => 'Weapon damage';

  @override
  String get upHp => 'Extra hit points';

  @override
  String get upShield => 'Spawn shield';

  @override
  String get upFireRate => 'Fire rate';

  @override
  String get upGrenades => 'Starting grenades';

  @override
  String upLevel(int level, int max) {
    return 'Lv $level/$max';
  }

  @override
  String buyTokens(int count) {
    return '$count tokens';
  }

  @override
  String buyGems(int count) {
    return '$count gems';
  }

  @override
  String get maxed => 'Max';

  @override
  String get notEnough => 'Not enough';

  @override
  String get arcadeNoUpgrades => 'Upgrades are off in Arcade difficulty.';

  @override
  String get galleryLocked => 'Find more cassettes to unlock';

  @override
  String cassettesFound(int count, int total) {
    return 'Cassettes $count/$total';
  }

  @override
  String get nowPlaying => 'Now playing';

  @override
  String trophiesCount(int count, int total) {
    return '$count/$total trophies';
  }

  @override
  String get tip1 => 'Manual p.12: grenades bounce. So do your excuses.';

  @override
  String get tip2 =>
      'Manual p.4: blow into the cartridge if the planet won\'t load.';

  @override
  String get tip3 =>
      'Manual p.9: on a planetoid, down is wherever your feet are.';

  @override
  String get tip4 =>
      'Manual p.21: the Glorbo fear only two things: you and paperwork errors.';

  @override
  String get tip5 => 'Manual p.7: enemies shout before shooting. Listen.';

  @override
  String get tip6 => 'Manual p.30: hostages tip well. In grenades.';

  @override
  String get tip7 => 'Manual p.16: walking upside down voids no warranty.';

  @override
  String get tip8 => 'Manual p.2: do not feed the washing machine. Seriously.';

  @override
  String get cheatBigHeads => 'Big heads!';

  @override
  String get cheatGiantPixels => 'Giant pixels!';

  @override
  String get cheatBrokenTube => 'Broken tube mode!';

  @override
  String get shopCartridge => 'Full Cartridge';

  @override
  String get shopCartridgeDesc =>
      'Worlds 2-3, Boss Rush, infinite campaign credits, no ads. Like buying the cartridge: once.';

  @override
  String get owned => 'Owned';

  @override
  String get gems => 'Quasar gems';

  @override
  String gemsApprox(String price) {
    return 'about $price';
  }

  @override
  String get capsules => 'Cosmic capsules';

  @override
  String get capsuleOpen => 'Open capsule';

  @override
  String get capsuleFree => 'Free daily capsule';

  @override
  String get capsuleOdds => 'Odds';

  @override
  String get capsuleOddsTitle => 'Exact drop odds';

  @override
  String pityCounter(int count) {
    return 'Legendary guaranteed in $count opens';
  }

  @override
  String get rarityCommon => 'Common';

  @override
  String get rarityRare => 'Rare';

  @override
  String get rarityEpic => 'Epic';

  @override
  String get rarityLegendary => 'Legendary';

  @override
  String get paidCapsulesBlocked =>
      'Paid capsules are not available in your country. Free capsules still work.';

  @override
  String get paidCapsulesMinor =>
      'Paid capsules are disabled for players under 18.';

  @override
  String get dailyShop => 'Shop of the day';

  @override
  String refreshesIn(String time) {
    return 'Refreshes in $time';
  }

  @override
  String get flashOffer => 'Flash offer';

  @override
  String endsIn(String time) {
    return 'Ends in $time';
  }

  @override
  String get seasonPass => 'Season pass';

  @override
  String seasonEndsIn(String time) {
    return 'Season ends in $time';
  }

  @override
  String get freeTrack => 'Free';

  @override
  String get premiumTrack => 'Premium';

  @override
  String get dailyLogin => 'Daily login';

  @override
  String dayN(int n) {
    return 'Day $n';
  }

  @override
  String get claim => 'Claim';

  @override
  String get claimed => 'Claimed';

  @override
  String get buy => 'Buy';

  @override
  String get storeUnavailable => 'Store not available on this device.';

  @override
  String get spendLimitReached => 'Monthly spending limit reached.';

  @override
  String get purchasePending => 'Purchase pending...';

  @override
  String get purchaseDone => 'Thank you!';

  @override
  String get starterPack => 'Starter pack';

  @override
  String get weeklyEvent => 'Weekly event';

  @override
  String get noPurchases => 'No purchases yet.';

  @override
  String get ageGateTitle => 'When were you born?';

  @override
  String get ageGateBody =>
      'We ask once, to set the right features for your age.';

  @override
  String get year => 'Year';

  @override
  String get month => 'Month';

  @override
  String get confirm => 'Confirm';

  @override
  String get onlineUnder16 => 'Online features are available from age 16.';

  @override
  String get chatEmotesOnly => 'Quick messages only (under 18).';

  @override
  String get chatSignIn => 'Sign in with Google to chat';

  @override
  String get chatGlobal => 'Global';

  @override
  String get chatSquadron => 'Squadron';

  @override
  String get chatFriends => 'Friends';

  @override
  String get chatSend => 'Send';

  @override
  String get chatReport => 'Report';

  @override
  String get chatBlock => 'Block';

  @override
  String get chatSlowDown => 'Slow down: 1 message every 3 seconds.';

  @override
  String get chatFiltered => 'Message blocked by the filter.';

  @override
  String get chatMuted => 'You are muted for a while.';

  @override
  String get chatDisabled => 'Chat is turned off in Settings.';

  @override
  String get chatOffline => 'Chat needs a connection.';

  @override
  String get reported => 'Reported. Thanks!';

  @override
  String get emoteNiceShot => 'Nice shot!';

  @override
  String get emoteHelpBoss => 'Help with the boss?';

  @override
  String get emoteGG => 'GG';

  @override
  String get emoteHi => 'Hi!';

  @override
  String get emoteThanks => 'Thanks!';

  @override
  String get emoteOneMore => 'One more!';

  @override
  String get squadGoal => 'Weekly squadron goal';
}
