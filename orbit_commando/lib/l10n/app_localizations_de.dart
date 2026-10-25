// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for German (`de`).
class AppLocalizationsDe extends AppLocalizations {
  AppLocalizationsDe([String locale = 'de']) : super(locale);

  @override
  String get appTitle => 'Orbit Commando \'94';

  @override
  String get pressStart => 'Drück Start';

  @override
  String get insertCoin => 'Münze einwerfen';

  @override
  String creditsLabel(int count) {
    return 'Credits $count';
  }

  @override
  String get sandboxLabel => 'Sandbox';

  @override
  String get studioPresents => 'Pixel Orbit Studio präsentiert';

  @override
  String get copyright => '(c) 1994 Pixel Orbit Studio';

  @override
  String get back => 'Zurück';

  @override
  String get ok => 'OK';

  @override
  String get cancel => 'Abbrechen';

  @override
  String get yes => 'Ja';

  @override
  String get no => 'Nein';

  @override
  String get next => 'Weiter';

  @override
  String get play => 'Spielen';

  @override
  String get locked => 'Gesperrt';

  @override
  String get loading => 'Lädt...';

  @override
  String get comingSoon => 'Online verfügbar in v2';

  @override
  String get menuCampaign => 'Kampagne';

  @override
  String get menuArcade => 'Arcade-Modus';

  @override
  String get menuBossRush => 'Boss Rush';

  @override
  String get menuWeekly => 'Wochen-Challenge';

  @override
  String get menuWorkshop => 'Werkstatt';

  @override
  String get menuGallery => 'Galerie';

  @override
  String get menuJukebox => 'Jukebox';

  @override
  String get menuShop => 'Shop';

  @override
  String get menuTrophies => 'Trophäen';

  @override
  String get menuScores => 'Bestenliste';

  @override
  String get menuSettings => 'Einstellungen';

  @override
  String get menuChat => 'Staffel-Chat';

  @override
  String get unlockArcade => 'Schließe Welt 1 ab zum Freischalten';

  @override
  String get unlockBossRush => 'Schließe die Kampagne ab zum Freischalten';

  @override
  String pilotRank(int rank) {
    return 'Pilotenrang $rank';
  }

  @override
  String tokens(int count) {
    return 'Marken $count';
  }

  @override
  String worldN(int n) {
    return 'Welt $n';
  }

  @override
  String get world1Name => 'Ruhiger Asteroidengürtel';

  @override
  String get world2Name => 'Orbitalstation Pizza-Station';

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
    return 'Rekord $score';
  }

  @override
  String get difficulty => 'Schwierigkeit';

  @override
  String get diffEasy => 'Leicht';

  @override
  String get diffNormal => 'Normal';

  @override
  String get diffArcade => 'Arcade';

  @override
  String get diffEasyHelp => '3 Lebenspunkte, Zielhilfe, langsamere Gegner';

  @override
  String get diffNormalHelp => 'Ein Treffer, ein Leben';

  @override
  String get diffArcadeHelp => 'Wie Normal, begrenzte Credits, keine Upgrades';

  @override
  String get chooseHero => 'Wähle dein Kommando';

  @override
  String get heroLocked => 'Gesperrt';

  @override
  String get heroRoxy => 'Schnell und furchtlos. Verpatzt nie einen Sprung.';

  @override
  String get heroBrutus => 'Dicke Wummen, noch dickeres Herz.';

  @override
  String get heroNyx => 'Freischalten: Welt 2 abschließen.';

  @override
  String get heroDoc => 'Freischalten: Kampagne abschließen.';

  @override
  String get heroNyxBio => 'Zwillingspistolen, null Geduld.';

  @override
  String get heroDocBio => 'Hat seine Kanone selbst gebaut. Aus einem Toaster.';

  @override
  String get paused => 'Pause';

  @override
  String get resume => 'Weiter';

  @override
  String get restart => 'Neustart';

  @override
  String get quitToMap => 'Zur Karte';

  @override
  String get quitToTitle => 'Zum Titel';

  @override
  String get continueQuestion => 'Weiterspielen?';

  @override
  String get continueCost => '1 Credit';

  @override
  String get gameOver => 'Game over';

  @override
  String get noCredits => 'Keine Credits mehr';

  @override
  String get watchAdCredit => 'Video ansehen: +1 Credit';

  @override
  String get assistTitle => 'Brauchst du Hilfe?';

  @override
  String get assistBody => 'Einen Schild für 10 Sekunden? Ohne Strafe.';

  @override
  String get assistYes => 'Schild an';

  @override
  String get assistNo => 'Ich schaff das';

  @override
  String get stageClear => 'Level geschafft!';

  @override
  String get score => 'Punkte';

  @override
  String get timeBonus => 'Zeitbonus';

  @override
  String get noDeathBonus => 'Ohne-Tod-Bonus';

  @override
  String get total => 'Gesamt';

  @override
  String get rank => 'Rang';

  @override
  String get time => 'Zeit';

  @override
  String get hostages => 'Geiseln';

  @override
  String get cassettes => 'Kassetten';

  @override
  String get kills => 'Gegner';

  @override
  String get medalNoDeath => 'Ohne Tod';

  @override
  String get medalHostages => 'Alle Geiseln';

  @override
  String get medalSpeedrun => 'Speedrun';

  @override
  String get newRecord => 'Neuer Rekord!';

  @override
  String earnedTokens(int count) {
    return '+$count Marken';
  }

  @override
  String get earnedCredit => '+1 Credit';

  @override
  String get unlockedArcade => 'Arcade-Modus freigeschaltet!';

  @override
  String get unlockedBossRush => 'Boss Rush freigeschaltet!';

  @override
  String unlockedHero(String name) {
    return 'Neues Kommando: $name!';
  }

  @override
  String trophyUnlocked(String name) {
    return 'Trophäe: $name';
  }

  @override
  String get enterInitials => 'Gib deine Initialen ein';

  @override
  String get doubleTokensAd => 'Video ansehen: doppelte Marken';

  @override
  String get campaignComplete =>
      'Das Glorbo-Imperium ist abgeheftet. Danke, Kommando!';

  @override
  String get setAudio => 'Audio';

  @override
  String get setMusic => 'Musik';

  @override
  String get setSfx => 'Effekte';

  @override
  String get setVideo => 'Video';

  @override
  String get setCrt => 'CRT-Filter';

  @override
  String get crtOff => 'Aus';

  @override
  String get crtArcade => 'Spielautomat';

  @override
  String get crtTv => 'Wohnzimmer-TV';

  @override
  String get setGame => 'Spiel';

  @override
  String get setCamera => 'Kamera';

  @override
  String get cameraRotating => 'Mitdrehend';

  @override
  String get cameraFixed => 'Fest (weniger Bewegung)';

  @override
  String get setAutoAim => 'Zielhilfe';

  @override
  String get setVibration => 'Vibration';

  @override
  String get setLanguage => 'Sprache';

  @override
  String get langSystem => 'System';

  @override
  String get setControls => 'Tastenlayout';

  @override
  String get controlsHelp =>
      'Ziehe die Tasten, um sie zu verschieben. Mit +/- änderst du die Größe.';

  @override
  String get opacity => 'Deckkraft';

  @override
  String get resetDefaults => 'Zurücksetzen';

  @override
  String get setPrivacy => 'Datenschutz';

  @override
  String get setAnalytics => 'Anonyme Statistiken teilen';

  @override
  String get setChat => 'Chat';

  @override
  String get setNotifications => 'Angebots-Mitteilungen';

  @override
  String get setConsent => 'Werbe-Einwilligung';

  @override
  String get setSpendLimit => 'Monatliches Ausgabenlimit';

  @override
  String get noLimit => 'Kein Limit';

  @override
  String get purchaseHistory => 'Kaufverlauf';

  @override
  String get restorePurchases => 'Käufe wiederherstellen';

  @override
  String get privacyPolicy => 'Datenschutzerklärung';

  @override
  String get deleteData => 'Meine Daten löschen';

  @override
  String get on => 'An';

  @override
  String get off => 'Aus';

  @override
  String get upDamage => 'Waffenschaden';

  @override
  String get upHp => 'Extra-Lebenspunkte';

  @override
  String get upShield => 'Startschild';

  @override
  String get upFireRate => 'Feuerrate';

  @override
  String get upGrenades => 'Startgranaten';

  @override
  String upLevel(int level, int max) {
    return 'St $level/$max';
  }

  @override
  String buyTokens(int count) {
    return '$count Marken';
  }

  @override
  String buyGems(int count) {
    return '$count Juwelen';
  }

  @override
  String get maxed => 'Max';

  @override
  String get notEnough => 'Zu wenig';

  @override
  String get arcadeNoUpgrades =>
      'Upgrades sind im Schwierigkeitsgrad Arcade aus.';

  @override
  String get galleryLocked => 'Finde mehr Kassetten zum Freischalten';

  @override
  String cassettesFound(int count, int total) {
    return 'Kassetten $count/$total';
  }

  @override
  String get nowPlaying => 'Läuft gerade';

  @override
  String trophiesCount(int count, int total) {
    return '$count/$total Trophäen';
  }

  @override
  String get tip1 => 'Handbuch S.12: Granaten prallen ab. Deine Ausreden auch.';

  @override
  String get tip2 =>
      'Handbuch S.4: Puste in das Modul, wenn der Planet nicht lädt.';

  @override
  String get tip3 =>
      'Handbuch S.9: Auf einem Planetoiden ist unten da, wo deine Füße sind.';

  @override
  String get tip4 =>
      'Handbuch S.21: Die Glorbo fürchten nur zwei Dinge: dich und falsch ausgefüllte Formulare.';

  @override
  String get tip5 =>
      'Handbuch S.7: Gegner schreien, bevor sie schießen. Hör hin.';

  @override
  String get tip6 =>
      'Handbuch S.30: Geiseln geben gutes Trinkgeld. In Granaten.';

  @override
  String get tip7 =>
      'Handbuch S.16: Kopfüber laufen hebt die Garantie nicht auf.';

  @override
  String get tip8 => 'Handbuch S.2: Füttere nicht die Waschmaschine. Im Ernst.';

  @override
  String get cheatBigHeads => 'Großköpfe!';

  @override
  String get cheatGiantPixels => 'Riesenpixel!';

  @override
  String get cheatBrokenTube => 'Kaputte-Röhre-Modus!';

  @override
  String get shopCartridge => 'Komplettes Modul';

  @override
  String get shopCartridgeDesc =>
      'Welten 2-3, Boss Rush, unendliche Credits in der Kampagne, keine Werbung. Wie das Modul kaufen: einmal.';

  @override
  String get owned => 'Gekauft';

  @override
  String get gems => 'Quasar-Juwelen';

  @override
  String gemsApprox(String price) {
    return 'ca. $price';
  }

  @override
  String get capsules => 'Kosmische Kapseln';

  @override
  String get capsuleOpen => 'Kapsel öffnen';

  @override
  String get capsuleFree => 'Gratis-Kapsel des Tages';

  @override
  String get capsuleOdds => 'Chancen';

  @override
  String get capsuleOddsTitle => 'Genaue Drop-Chancen';

  @override
  String pityCounter(int count) {
    return 'Legendär garantiert in $count Öffnungen';
  }

  @override
  String get rarityCommon => 'Gewöhnlich';

  @override
  String get rarityRare => 'Selten';

  @override
  String get rarityEpic => 'Episch';

  @override
  String get rarityLegendary => 'Legendär';

  @override
  String get paidCapsulesBlocked =>
      'Bezahlte Kapseln sind in deinem Land nicht verfügbar. Gratis-Kapseln schon.';

  @override
  String get paidCapsulesMinor =>
      'Bezahlte Kapseln sind für Spieler unter 18 deaktiviert.';

  @override
  String get dailyShop => 'Shop des Tages';

  @override
  String refreshesIn(String time) {
    return 'Neu in $time';
  }

  @override
  String get flashOffer => 'Blitzangebot';

  @override
  String endsIn(String time) {
    return 'Endet in $time';
  }

  @override
  String get seasonPass => 'Saisonpass';

  @override
  String seasonEndsIn(String time) {
    return 'Die Saison endet in $time';
  }

  @override
  String get freeTrack => 'Gratis';

  @override
  String get premiumTrack => 'Premium';

  @override
  String get dailyLogin => 'Täglicher Login';

  @override
  String dayN(int n) {
    return 'Tag $n';
  }

  @override
  String get claim => 'Abholen';

  @override
  String get claimed => 'Abgeholt';

  @override
  String get buy => 'Kaufen';

  @override
  String get storeUnavailable => 'Shop auf diesem Gerät nicht verfügbar.';

  @override
  String get spendLimitReached => 'Monatliches Ausgabenlimit erreicht.';

  @override
  String get purchasePending => 'Kauf ausstehend...';

  @override
  String get purchaseDone => 'Danke!';

  @override
  String get starterPack => 'Startpaket';

  @override
  String get weeklyEvent => 'Wochen-Event';

  @override
  String get noPurchases => 'Noch keine Käufe.';

  @override
  String get ageGateTitle => 'Wann bist du geboren?';

  @override
  String get ageGateBody =>
      'Wir fragen nur einmal, um die passenden Funktionen für dein Alter zu aktivieren.';

  @override
  String get year => 'Jahr';

  @override
  String get month => 'Monat';

  @override
  String get confirm => 'Bestätigen';

  @override
  String get onlineUnder16 => 'Online-Funktionen gibt es ab 16 Jahren.';

  @override
  String get chatEmotesOnly => 'Nur Schnellnachrichten (unter 18).';

  @override
  String get chatSignIn => 'Mit Google anmelden, um zu chatten';

  @override
  String get chatGlobal => 'Global';

  @override
  String get chatSquadron => 'Staffel';

  @override
  String get chatFriends => 'Freunde';

  @override
  String get chatSend => 'Senden';

  @override
  String get chatReport => 'Melden';

  @override
  String get chatBlock => 'Blockieren';

  @override
  String get chatSlowDown => 'Langsam: 1 Nachricht alle 3 Sekunden.';

  @override
  String get chatFiltered => 'Nachricht vom Filter blockiert.';

  @override
  String get chatMuted => 'Du bist eine Weile stummgeschaltet.';

  @override
  String get chatDisabled => 'Der Chat ist in den Einstellungen aus.';

  @override
  String get chatOffline => 'Der Chat braucht eine Verbindung.';

  @override
  String get reported => 'Gemeldet. Danke!';

  @override
  String get emoteNiceShot => 'Guter Schuss!';

  @override
  String get emoteHelpBoss => 'Hilfe beim Boss?';

  @override
  String get emoteGG => 'GG';

  @override
  String get emoteHi => 'Hi!';

  @override
  String get emoteThanks => 'Danke!';

  @override
  String get emoteOneMore => 'Noch eine!';

  @override
  String get squadGoal => 'Wochenziel der Staffel';

  @override
  String get maxCombo => 'Max. Combo';

  @override
  String get shareChallenge => 'Freunde herausfordern';

  @override
  String get shareCardBeat => 'Schaffst du mehr?';

  @override
  String shareText(int score, String code) {
    return 'Ich habe $score Punkte in Orbit Commando \'94! Gleiches Level, gleicher Seed: schlag mich mit dem Code $code';
  }

  @override
  String get menuDaily => 'Orbit des Tages';

  @override
  String get menuChallenges => 'Challenges';

  @override
  String get dailyDesc =>
      'Heute dasselbe Level und derselbe Remix für alle Spieler der Welt.';

  @override
  String get challengeCodeTitle => 'Challenge-Code eines Freundes';

  @override
  String get challengeCodeHint =>
      'Füge den Code ein oder tippe ihn, z. B. OC-7K2M9-QX4TB';

  @override
  String get challengeInvalid =>
      'Ungültiger Code. Prüfe ihn und versuch es nochmal.';

  @override
  String challengeTarget(int score) {
    return 'Schlag $score';
  }

  @override
  String get challengeBeaten => 'Challenge geschafft! Schick sie zurück.';

  @override
  String get challengeLost => 'Diesmal nicht. Noch eine Runde?';

  @override
  String get paste => 'Einfügen';

  @override
  String get lvlW1L1 => 'Ruhiger Gürtel';

  @override
  String get lvlW1L2 => 'Steinfeld';

  @override
  String get lvlW1L3 => 'Der Sprungfeder-Mech';

  @override
  String get lvlW1L4 => 'Dunkle Seite des Felsens';

  @override
  String get lvlW1L5 => 'Oberster Stempler';

  @override
  String get lvlW2L1 => 'Margherita-Korridor';

  @override
  String get lvlW2L2 => 'Antigravitationshalle';

  @override
  String get lvlW2L3 => 'Raketen-Bike-Express';

  @override
  String get lvlW2L4 => 'Pizzaringe';

  @override
  String get lvlW2L5 => 'Die Große Kosmische Waschmaschine';

  @override
  String get lvlW3L1 => 'Glorbo-Archipel';

  @override
  String get lvlW3L2 => 'Shuttle im Nichts';

  @override
  String get lvlW3L3 => 'Formularfabrik';

  @override
  String get lvlW3L4 => 'Letzter Schalter';

  @override
  String get lvlW3L5 => 'Imperator Glorbo';
}
