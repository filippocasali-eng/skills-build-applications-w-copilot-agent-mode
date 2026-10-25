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
  String get sandboxLabel => 'Sandbox';

  @override
  String get studioPresents => 'Pixel Orbit Studio presenta';

  @override
  String get copyright => '(c) 1994 Pixel Orbit Studio';

  @override
  String get back => 'Indietro';

  @override
  String get ok => 'OK';

  @override
  String get cancel => 'Annulla';

  @override
  String get yes => 'Si';

  @override
  String get no => 'No';

  @override
  String get next => 'Avanti';

  @override
  String get play => 'Gioca';

  @override
  String get locked => 'Bloccato';

  @override
  String get loading => 'Caricamento...';

  @override
  String get comingSoon => 'Disponibile online nella v2';

  @override
  String get menuCampaign => 'Campagna';

  @override
  String get menuArcade => 'Modalità arcade';

  @override
  String get menuBossRush => 'Boss rush';

  @override
  String get menuWeekly => 'Sfida settimanale';

  @override
  String get menuWorkshop => 'Officina';

  @override
  String get menuGallery => 'Galleria';

  @override
  String get menuJukebox => 'Juke-box';

  @override
  String get menuShop => 'Negozio';

  @override
  String get menuTrophies => 'Trofei';

  @override
  String get menuScores => 'Record';

  @override
  String get menuSettings => 'Impostazioni';

  @override
  String get menuChat => 'Chat squadriglia';

  @override
  String get unlockArcade => 'Finisci il Mondo 1 per sbloccare';

  @override
  String get unlockBossRush => 'Finisci la campagna per sbloccare';

  @override
  String pilotRank(int rank) {
    return 'Grado pilota $rank';
  }

  @override
  String tokens(int count) {
    return 'Gettoni $count';
  }

  @override
  String worldN(int n) {
    return 'Mondo $n';
  }

  @override
  String get world1Name => 'Cintura di Asteroidi Tranquilla';

  @override
  String get world2Name => 'Stazione Orbitale Pizza-Station';

  @override
  String get world3Name => 'Pianeta Glorbo Prime';

  @override
  String levelN(int n) {
    return 'Livello $n';
  }

  @override
  String get bossStage => 'Boss';

  @override
  String bestScore(int score) {
    return 'Record $score';
  }

  @override
  String get difficulty => 'Difficoltà';

  @override
  String get diffEasy => 'Facile';

  @override
  String get diffNormal => 'Normale';

  @override
  String get diffArcade => 'Arcade';

  @override
  String get diffEasyHelp => '3 punti vita, mira assistita, nemici più lenti';

  @override
  String get diffNormalHelp => 'Un colpo, una vita';

  @override
  String get diffArcadeHelp =>
      'Come Normale, crediti limitati, niente migliorie';

  @override
  String get chooseHero => 'Scegli il tuo commando';

  @override
  String get heroLocked => 'Bloccato';

  @override
  String get heroRoxy => 'Veloce e senza paura. Non sbaglia un salto.';

  @override
  String get heroBrutus => 'Armi grosse, cuore ancora più grosso.';

  @override
  String get heroNyx => 'Sblocca: finisci il Mondo 2.';

  @override
  String get heroDoc => 'Sblocca: finisci la campagna.';

  @override
  String get heroNyxBio => 'Pistole gemelle, zero pazienza.';

  @override
  String get heroDocBio => 'Si è costruito il cannone. Da un tostapane.';

  @override
  String get paused => 'Pausa';

  @override
  String get resume => 'Riprendi';

  @override
  String get restart => 'Ricomincia';

  @override
  String get quitToMap => 'Torna alla mappa';

  @override
  String get quitToTitle => 'Torna al titolo';

  @override
  String get continueQuestion => 'Continuare?';

  @override
  String get continueCost => '1 credito';

  @override
  String get gameOver => 'Game over';

  @override
  String get noCredits => 'Crediti esauriti';

  @override
  String get watchAdCredit => 'Guarda un video: +1 credito';

  @override
  String get assistTitle => 'Serve una mano?';

  @override
  String get assistBody => 'Vuoi uno scudo di 10 secondi? Nessuna penalità.';

  @override
  String get assistYes => 'Attiva scudo';

  @override
  String get assistNo => 'Ce la faccio';

  @override
  String get stageClear => 'Livello completato!';

  @override
  String get score => 'Punti';

  @override
  String get timeBonus => 'Bonus tempo';

  @override
  String get noDeathBonus => 'Bonus senza morti';

  @override
  String get total => 'Totale';

  @override
  String get rank => 'Rank';

  @override
  String get time => 'Tempo';

  @override
  String get hostages => 'Ostaggi';

  @override
  String get cassettes => 'Cassette';

  @override
  String get kills => 'Nemici';

  @override
  String get medalNoDeath => 'Nessuna morte';

  @override
  String get medalHostages => 'Tutti gli ostaggi';

  @override
  String get medalSpeedrun => 'Speedrun';

  @override
  String get newRecord => 'Nuovo record!';

  @override
  String earnedTokens(int count) {
    return '+$count gettoni';
  }

  @override
  String get earnedCredit => '+1 credito';

  @override
  String get unlockedArcade => 'Modalità arcade sbloccata!';

  @override
  String get unlockedBossRush => 'Boss rush sbloccato!';

  @override
  String unlockedHero(String name) {
    return 'Nuovo commando: $name!';
  }

  @override
  String trophyUnlocked(String name) {
    return 'Trofeo: $name';
  }

  @override
  String get enterInitials => 'Inserisci le iniziali';

  @override
  String get doubleTokensAd => 'Guarda un video: gettoni doppi';

  @override
  String get campaignComplete =>
      'L\'Impero Glorbo è archiviato. Grazie, commando!';

  @override
  String get setAudio => 'Audio';

  @override
  String get setMusic => 'Musica';

  @override
  String get setSfx => 'Effetti';

  @override
  String get setVideo => 'Video';

  @override
  String get setCrt => 'Filtro CRT';

  @override
  String get crtOff => 'Spento';

  @override
  String get crtArcade => 'Cabinato';

  @override
  String get crtTv => 'TV del salotto';

  @override
  String get setGame => 'Gioco';

  @override
  String get setCamera => 'Camera';

  @override
  String get cameraRotating => 'Rotante';

  @override
  String get cameraFixed => 'Fissa (meno movimento)';

  @override
  String get setAutoAim => 'Mira assistita';

  @override
  String get setVibration => 'Vibrazione';

  @override
  String get setLanguage => 'Lingua';

  @override
  String get langSystem => 'Sistema';

  @override
  String get setControls => 'Layout comandi';

  @override
  String get controlsHelp =>
      'Trascina i pulsanti per spostarli. Usa +/- per ridimensionarli.';

  @override
  String get opacity => 'Opacità';

  @override
  String get resetDefaults => 'Ripristina';

  @override
  String get setPrivacy => 'Privacy';

  @override
  String get setAnalytics => 'Condividi statistiche anonime';

  @override
  String get setChat => 'Chat';

  @override
  String get setNotifications => 'Notifiche offerte';

  @override
  String get setConsent => 'Consenso pubblicitario';

  @override
  String get setSpendLimit => 'Limite di spesa mensile';

  @override
  String get noLimit => 'Nessun limite';

  @override
  String get purchaseHistory => 'Storico acquisti';

  @override
  String get restorePurchases => 'Ripristina acquisti';

  @override
  String get privacyPolicy => 'Informativa privacy';

  @override
  String get deleteData => 'Cancella i miei dati';

  @override
  String get on => 'Si';

  @override
  String get off => 'No';

  @override
  String get upDamage => 'Danno armi';

  @override
  String get upHp => 'Punti vita extra';

  @override
  String get upShield => 'Scudo iniziale';

  @override
  String get upFireRate => 'Rateo di fuoco';

  @override
  String get upGrenades => 'Granate iniziali';

  @override
  String upLevel(int level, int max) {
    return 'Liv $level/$max';
  }

  @override
  String buyTokens(int count) {
    return '$count gettoni';
  }

  @override
  String buyGems(int count) {
    return '$count gemme';
  }

  @override
  String get maxed => 'Max';

  @override
  String get notEnough => 'Non basta';

  @override
  String get arcadeNoUpgrades =>
      'Le migliorie sono disattivate in difficoltà Arcade.';

  @override
  String get galleryLocked => 'Trova altre cassette per sbloccare';

  @override
  String cassettesFound(int count, int total) {
    return 'Cassette $count/$total';
  }

  @override
  String get nowPlaying => 'In riproduzione';

  @override
  String trophiesCount(int count, int total) {
    return '$count/$total trofei';
  }

  @override
  String get tip1 => 'Manuale p.12: le granate rimbalzano. Anche le scuse.';

  @override
  String get tip2 =>
      'Manuale p.4: soffia nella cartuccia se il pianeta non carica.';

  @override
  String get tip3 =>
      'Manuale p.9: su un planetoide, il basso è dove stanno i piedi.';

  @override
  String get tip4 =>
      'Manuale p.21: i Glorbo temono solo due cose: te e i moduli sbagliati.';

  @override
  String get tip5 =>
      'Manuale p.7: i nemici urlano prima di sparare. Ascoltali.';

  @override
  String get tip6 =>
      'Manuale p.30: gli ostaggi lasciano la mancia. In granate.';

  @override
  String get tip7 =>
      'Manuale p.16: camminare a testa in giù non invalida la garanzia.';

  @override
  String get tip8 =>
      'Manuale p.2: non dare da mangiare alla lavatrice. Davvero.';

  @override
  String get cheatBigHeads => 'Testoni!';

  @override
  String get cheatGiantPixels => 'Pixel giganti!';

  @override
  String get cheatBrokenTube => 'Tubo catodico rotto!';

  @override
  String get shopCartridge => 'Cartuccia Completa';

  @override
  String get shopCartridgeDesc =>
      'Mondi 2-3, Boss Rush, crediti infiniti in campagna, niente pubblicità. Come comprare la cartuccia: una volta e basta.';

  @override
  String get owned => 'Acquistato';

  @override
  String get gems => 'Gemme Quasar';

  @override
  String gemsApprox(String price) {
    return 'circa $price';
  }

  @override
  String get capsules => 'Capsule cosmiche';

  @override
  String get capsuleOpen => 'Apri capsula';

  @override
  String get capsuleFree => 'Capsula gratis del giorno';

  @override
  String get capsuleOdds => 'Probabilità';

  @override
  String get capsuleOddsTitle => 'Probabilità esatte';

  @override
  String pityCounter(int count) {
    return 'Leggendaria garantita entro $count aperture';
  }

  @override
  String get rarityCommon => 'Comune';

  @override
  String get rarityRare => 'Rara';

  @override
  String get rarityEpic => 'Epica';

  @override
  String get rarityLegendary => 'Leggendaria';

  @override
  String get paidCapsulesBlocked =>
      'Le capsule a pagamento non sono disponibili nel tuo paese. Quelle gratuite sì.';

  @override
  String get paidCapsulesMinor =>
      'Le capsule a pagamento sono disattivate sotto i 18 anni.';

  @override
  String get dailyShop => 'Negozio del giorno';

  @override
  String refreshesIn(String time) {
    return 'Si rinnova tra $time';
  }

  @override
  String get flashOffer => 'Offerta lampo';

  @override
  String endsIn(String time) {
    return 'Termina tra $time';
  }

  @override
  String get seasonPass => 'Season pass';

  @override
  String seasonEndsIn(String time) {
    return 'La stagione finisce tra $time';
  }

  @override
  String get freeTrack => 'Gratis';

  @override
  String get premiumTrack => 'Premium';

  @override
  String get dailyLogin => 'Login giornaliero';

  @override
  String dayN(int n) {
    return 'Giorno $n';
  }

  @override
  String get claim => 'Ritira';

  @override
  String get claimed => 'Ritirato';

  @override
  String get buy => 'Compra';

  @override
  String get storeUnavailable =>
      'Negozio non disponibile su questo dispositivo.';

  @override
  String get spendLimitReached => 'Limite di spesa mensile raggiunto.';

  @override
  String get purchasePending => 'Acquisto in attesa...';

  @override
  String get purchaseDone => 'Grazie!';

  @override
  String get starterPack => 'Pacchetto iniziale';

  @override
  String get weeklyEvent => 'Evento della settimana';

  @override
  String get noPurchases => 'Nessun acquisto.';

  @override
  String get ageGateTitle => 'Quando sei nato?';

  @override
  String get ageGateBody =>
      'Lo chiediamo una volta sola, per attivare le funzioni giuste per la tua età.';

  @override
  String get year => 'Anno';

  @override
  String get month => 'Mese';

  @override
  String get confirm => 'Conferma';

  @override
  String get onlineUnder16 =>
      'Le funzioni online sono disponibili dai 16 anni.';

  @override
  String get chatEmotesOnly => 'Solo messaggi rapidi (sotto i 18 anni).';

  @override
  String get chatSignIn => 'Accedi con Google per la chat';

  @override
  String get chatGlobal => 'Globale';

  @override
  String get chatSquadron => 'Squadriglia';

  @override
  String get chatFriends => 'Amici';

  @override
  String get chatSend => 'Invia';

  @override
  String get chatReport => 'Segnala';

  @override
  String get chatBlock => 'Blocca';

  @override
  String get chatSlowDown => 'Piano: 1 messaggio ogni 3 secondi.';

  @override
  String get chatFiltered => 'Messaggio bloccato dal filtro.';

  @override
  String get chatMuted => 'Sei silenziato per un po\'.';

  @override
  String get chatDisabled => 'La chat è disattivata nelle Impostazioni.';

  @override
  String get chatOffline => 'La chat richiede una connessione.';

  @override
  String get reported => 'Segnalato. Grazie!';

  @override
  String get emoteNiceShot => 'Bel colpo!';

  @override
  String get emoteHelpBoss => 'Aiuto col boss?';

  @override
  String get emoteGG => 'GG';

  @override
  String get emoteHi => 'Ciao!';

  @override
  String get emoteThanks => 'Grazie!';

  @override
  String get emoteOneMore => 'Ancora una!';

  @override
  String get squadGoal => 'Obiettivo settimanale della squadriglia';

  @override
  String get maxCombo => 'Combo max';

  @override
  String get shareChallenge => 'Sfida gli amici';

  @override
  String get shareCardBeat => 'Riesci a battermi?';

  @override
  String shareText(int score, String code) {
    return 'Ho fatto $score punti in Orbit Commando \'94! Stesso livello, stesso seed: battimi con il codice $code';
  }

  @override
  String get menuDaily => 'Orbita del giorno';

  @override
  String get menuChallenges => 'Sfide';

  @override
  String get dailyDesc =>
      'Oggi stesso livello e stesso remix per tutti i giocatori del mondo.';

  @override
  String get challengeCodeTitle => 'Codice sfida di un amico';

  @override
  String get challengeCodeHint =>
      'Incolla o scrivi il codice, es. OC-7K2M9-QX4TB';

  @override
  String get challengeInvalid => 'Codice non valido. Controllalo e riprova.';

  @override
  String challengeTarget(int score) {
    return 'Batti $score';
  }

  @override
  String get challengeBeaten => 'Sfida vinta! Rilanciala.';

  @override
  String get challengeLost => 'Non stavolta. Ci riprovi?';

  @override
  String get paste => 'Incolla';

  @override
  String get lvlW1L1 => 'Cintura Tranquilla';

  @override
  String get lvlW1L2 => 'Campo di Sassi';

  @override
  String get lvlW1L3 => 'Il Mech a Molla';

  @override
  String get lvlW1L4 => 'Lato Oscuro del Sasso';

  @override
  String get lvlW1L5 => 'Timbratore Supremo';

  @override
  String get lvlW2L1 => 'Corridoio Margherita';

  @override
  String get lvlW2L2 => 'Sala Antigravità';

  @override
  String get lvlW2L3 => 'Moto-Razzo Express';

  @override
  String get lvlW2L4 => 'Anelli della Pizza';

  @override
  String get lvlW2L5 => 'La Grande Lavatrice Cosmica';

  @override
  String get lvlW3L1 => 'Arcipelago Glorbo';

  @override
  String get lvlW3L2 => 'Navetta nel Vuoto';

  @override
  String get lvlW3L3 => 'Fabbrica di Moduli';

  @override
  String get lvlW3L4 => 'Ultimo Sportello';

  @override
  String get lvlW3L5 => 'Imperatore Glorbo';
}
