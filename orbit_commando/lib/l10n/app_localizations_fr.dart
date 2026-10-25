// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get appTitle => 'Orbit Commando \'94';

  @override
  String get pressStart => 'Appuie sur start';

  @override
  String get insertCoin => 'Insérez une pièce';

  @override
  String creditsLabel(int count) {
    return 'Crédits $count';
  }

  @override
  String get sandboxLabel => 'Sandbox';

  @override
  String get studioPresents => 'Pixel Orbit Studio présente';

  @override
  String get copyright => '(c) 1994 Pixel Orbit Studio';

  @override
  String get back => 'Retour';

  @override
  String get ok => 'OK';

  @override
  String get cancel => 'Annuler';

  @override
  String get yes => 'Oui';

  @override
  String get no => 'Non';

  @override
  String get next => 'Suivant';

  @override
  String get play => 'Jouer';

  @override
  String get locked => 'Verrouillé';

  @override
  String get loading => 'Chargement...';

  @override
  String get comingSoon => 'Disponible en ligne dans la v2';

  @override
  String get menuCampaign => 'Campagne';

  @override
  String get menuArcade => 'Mode arcade';

  @override
  String get menuBossRush => 'Boss rush';

  @override
  String get menuWeekly => 'Défi de la semaine';

  @override
  String get menuWorkshop => 'Atelier';

  @override
  String get menuGallery => 'Galerie';

  @override
  String get menuJukebox => 'Juke-box';

  @override
  String get menuShop => 'Boutique';

  @override
  String get menuTrophies => 'Trophées';

  @override
  String get menuScores => 'Records';

  @override
  String get menuSettings => 'Options';

  @override
  String get menuChat => 'Chat d\'escadrille';

  @override
  String get unlockArcade => 'Termine le Monde 1 pour débloquer';

  @override
  String get unlockBossRush => 'Termine la campagne pour débloquer';

  @override
  String pilotRank(int rank) {
    return 'Grade de pilote $rank';
  }

  @override
  String tokens(int count) {
    return 'Jetons $count';
  }

  @override
  String worldN(int n) {
    return 'Monde $n';
  }

  @override
  String get world1Name => 'Ceinture d\'Astéroïdes Tranquille';

  @override
  String get world2Name => 'Station Orbitale Pizza-Station';

  @override
  String get world3Name => 'Planète Glorbo Prime';

  @override
  String levelN(int n) {
    return 'Niveau $n';
  }

  @override
  String get bossStage => 'Boss';

  @override
  String bestScore(int score) {
    return 'Record $score';
  }

  @override
  String get difficulty => 'Difficulté';

  @override
  String get diffEasy => 'Facile';

  @override
  String get diffNormal => 'Normal';

  @override
  String get diffArcade => 'Arcade';

  @override
  String get diffEasyHelp =>
      '3 points de vie, visée assistée, ennemis plus lents';

  @override
  String get diffNormalHelp => 'Un coup, une vie';

  @override
  String get diffArcadeHelp =>
      'Comme Normal, crédits limités, sans améliorations';

  @override
  String get chooseHero => 'Choisis ton commando';

  @override
  String get heroLocked => 'Verrouillé';

  @override
  String get heroRoxy => 'Rapide et sans peur. Ne rate jamais un saut.';

  @override
  String get heroBrutus => 'Gros flingues, cœur encore plus gros.';

  @override
  String get heroNyx => 'Déblocage : termine le Monde 2.';

  @override
  String get heroDoc => 'Déblocage : termine la campagne.';

  @override
  String get heroNyxBio => 'Pistolets jumeaux, zéro patience.';

  @override
  String get heroDocBio => 'A fabriqué son propre canon. Avec un grille-pain.';

  @override
  String get paused => 'Pause';

  @override
  String get resume => 'Reprendre';

  @override
  String get restart => 'Recommencer';

  @override
  String get quitToMap => 'Retour à la carte';

  @override
  String get quitToTitle => 'Retour au titre';

  @override
  String get continueQuestion => 'Continuer ?';

  @override
  String get continueCost => '1 crédit';

  @override
  String get gameOver => 'Game over';

  @override
  String get noCredits => 'Plus de crédits';

  @override
  String get watchAdCredit => 'Regarde une vidéo : +1 crédit';

  @override
  String get assistTitle => 'Besoin d\'un coup de main ?';

  @override
  String get assistBody => 'Un bouclier de 10 secondes ? Sans pénalité.';

  @override
  String get assistYes => 'Activer le bouclier';

  @override
  String get assistNo => 'Je gère';

  @override
  String get stageClear => 'Niveau terminé !';

  @override
  String get score => 'Score';

  @override
  String get timeBonus => 'Bonus de temps';

  @override
  String get noDeathBonus => 'Bonus sans mort';

  @override
  String get total => 'Total';

  @override
  String get rank => 'Rang';

  @override
  String get time => 'Temps';

  @override
  String get hostages => 'Otages';

  @override
  String get cassettes => 'Cassettes';

  @override
  String get kills => 'Ennemis';

  @override
  String get medalNoDeath => 'Sans mourir';

  @override
  String get medalHostages => 'Tous les otages';

  @override
  String get medalSpeedrun => 'Speedrun';

  @override
  String get newRecord => 'Nouveau record !';

  @override
  String earnedTokens(int count) {
    return '+$count jetons';
  }

  @override
  String get earnedCredit => '+1 crédit';

  @override
  String get unlockedArcade => 'Mode arcade débloqué !';

  @override
  String get unlockedBossRush => 'Boss rush débloqué !';

  @override
  String unlockedHero(String name) {
    return 'Nouveau commando : $name !';
  }

  @override
  String trophyUnlocked(String name) {
    return 'Trophée : $name';
  }

  @override
  String get enterInitials => 'Entre tes initiales';

  @override
  String get doubleTokensAd => 'Regarde une vidéo : jetons doublés';

  @override
  String get campaignComplete =>
      'L\'Empire Glorbo est classé sans suite. Merci, commando !';

  @override
  String get setAudio => 'Audio';

  @override
  String get setMusic => 'Musique';

  @override
  String get setSfx => 'Effets';

  @override
  String get setVideo => 'Vidéo';

  @override
  String get setCrt => 'Filtre CRT';

  @override
  String get crtOff => 'Désactivé';

  @override
  String get crtArcade => 'Borne d\'arcade';

  @override
  String get crtTv => 'Télé du salon';

  @override
  String get setGame => 'Jeu';

  @override
  String get setCamera => 'Caméra';

  @override
  String get cameraRotating => 'Rotative';

  @override
  String get cameraFixed => 'Fixe (moins de mouvement)';

  @override
  String get setAutoAim => 'Visée assistée';

  @override
  String get setVibration => 'Vibration';

  @override
  String get setLanguage => 'Langue';

  @override
  String get langSystem => 'Système';

  @override
  String get setControls => 'Disposition des commandes';

  @override
  String get controlsHelp =>
      'Fais glisser les boutons pour les déplacer. Utilise +/- pour les redimensionner.';

  @override
  String get opacity => 'Opacité';

  @override
  String get resetDefaults => 'Réinitialiser';

  @override
  String get setPrivacy => 'Confidentialité';

  @override
  String get setAnalytics => 'Partager des stats anonymes';

  @override
  String get setChat => 'Chat';

  @override
  String get setNotifications => 'Notifications d\'offres';

  @override
  String get setConsent => 'Consentement publicitaire';

  @override
  String get setSpendLimit => 'Limite de dépenses mensuelle';

  @override
  String get noLimit => 'Aucune limite';

  @override
  String get purchaseHistory => 'Historique des achats';

  @override
  String get restorePurchases => 'Restaurer les achats';

  @override
  String get privacyPolicy => 'Politique de confidentialité';

  @override
  String get deleteData => 'Supprimer mes données';

  @override
  String get on => 'Oui';

  @override
  String get off => 'Non';

  @override
  String get upDamage => 'Dégâts des armes';

  @override
  String get upHp => 'Points de vie en plus';

  @override
  String get upShield => 'Bouclier de départ';

  @override
  String get upFireRate => 'Cadence de tir';

  @override
  String get upGrenades => 'Grenades de départ';

  @override
  String upLevel(int level, int max) {
    return 'Niv $level/$max';
  }

  @override
  String buyTokens(int count) {
    return '$count jetons';
  }

  @override
  String buyGems(int count) {
    return '$count gemmes';
  }

  @override
  String get maxed => 'Max';

  @override
  String get notEnough => 'Pas assez';

  @override
  String get arcadeNoUpgrades =>
      'Les améliorations sont désactivées en difficulté Arcade.';

  @override
  String get galleryLocked => 'Trouve plus de cassettes pour débloquer';

  @override
  String cassettesFound(int count, int total) {
    return 'Cassettes $count/$total';
  }

  @override
  String get nowPlaying => 'En lecture';

  @override
  String trophiesCount(int count, int total) {
    return '$count/$total trophées';
  }

  @override
  String get tip1 =>
      'Manuel p.12 : les grenades rebondissent. Tes excuses aussi.';

  @override
  String get tip2 =>
      'Manuel p.4 : souffle dans la cartouche si la planète ne charge pas.';

  @override
  String get tip3 =>
      'Manuel p.9 : sur un planétoïde, le bas, c\'est là où sont tes pieds.';

  @override
  String get tip4 =>
      'Manuel p.21 : les Glorbo ne craignent que deux choses : toi et les formulaires mal remplis.';

  @override
  String get tip5 =>
      'Manuel p.7 : les ennemis crient avant de tirer. Écoute-les.';

  @override
  String get tip6 =>
      'Manuel p.30 : les otages laissent de bons pourboires. En grenades.';

  @override
  String get tip7 =>
      'Manuel p.16 : marcher la tête en bas n\'annule pas la garantie.';

  @override
  String get tip8 =>
      'Manuel p.2 : ne nourris pas la machine à laver. Sérieusement.';

  @override
  String get cheatBigHeads => 'Grosses têtes !';

  @override
  String get cheatGiantPixels => 'Pixels géants !';

  @override
  String get cheatBrokenTube => 'Mode tube cassé !';

  @override
  String get shopCartridge => 'Cartouche Complète';

  @override
  String get shopCartridgeDesc =>
      'Mondes 2-3, Boss Rush, crédits infinis en campagne, sans pubs. Comme acheter la cartouche : une seule fois.';

  @override
  String get owned => 'Acheté';

  @override
  String get gems => 'Gemmes Quasar';

  @override
  String gemsApprox(String price) {
    return 'environ $price';
  }

  @override
  String get capsules => 'Capsules cosmiques';

  @override
  String get capsuleOpen => 'Ouvrir une capsule';

  @override
  String get capsuleFree => 'Capsule gratuite du jour';

  @override
  String get capsuleOdds => 'Probabilités';

  @override
  String get capsuleOddsTitle => 'Probabilités exactes';

  @override
  String pityCounter(int count) {
    return 'Légendaire garantie dans $count ouvertures';
  }

  @override
  String get rarityCommon => 'Commune';

  @override
  String get rarityRare => 'Rare';

  @override
  String get rarityEpic => 'Épique';

  @override
  String get rarityLegendary => 'Légendaire';

  @override
  String get paidCapsulesBlocked =>
      'Les capsules payantes ne sont pas disponibles dans ton pays. Les gratuites, si.';

  @override
  String get paidCapsulesMinor =>
      'Les capsules payantes sont désactivées pour les moins de 18 ans.';

  @override
  String get dailyShop => 'Boutique du jour';

  @override
  String refreshesIn(String time) {
    return 'Renouvelée dans $time';
  }

  @override
  String get flashOffer => 'Offre éclair';

  @override
  String endsIn(String time) {
    return 'Se termine dans $time';
  }

  @override
  String get seasonPass => 'Passe de saison';

  @override
  String seasonEndsIn(String time) {
    return 'La saison se termine dans $time';
  }

  @override
  String get freeTrack => 'Gratuit';

  @override
  String get premiumTrack => 'Premium';

  @override
  String get dailyLogin => 'Connexion quotidienne';

  @override
  String dayN(int n) {
    return 'Jour $n';
  }

  @override
  String get claim => 'Récupérer';

  @override
  String get claimed => 'Récupéré';

  @override
  String get buy => 'Acheter';

  @override
  String get storeUnavailable => 'Boutique indisponible sur cet appareil.';

  @override
  String get spendLimitReached => 'Limite de dépenses mensuelle atteinte.';

  @override
  String get purchasePending => 'Achat en attente...';

  @override
  String get purchaseDone => 'Merci !';

  @override
  String get starterPack => 'Pack de départ';

  @override
  String get weeklyEvent => 'Événement de la semaine';

  @override
  String get noPurchases => 'Aucun achat pour l\'instant.';

  @override
  String get ageGateTitle => 'Quand es-tu né(e) ?';

  @override
  String get ageGateBody =>
      'On ne le demande qu\'une fois, pour activer les bonnes fonctions selon ton âge.';

  @override
  String get year => 'Année';

  @override
  String get month => 'Mois';

  @override
  String get confirm => 'Confirmer';

  @override
  String get onlineUnder16 =>
      'Les fonctions en ligne sont disponibles à partir de 16 ans.';

  @override
  String get chatEmotesOnly => 'Messages rapides uniquement (moins de 18 ans).';

  @override
  String get chatSignIn => 'Connecte-toi avec Google pour discuter';

  @override
  String get chatGlobal => 'Global';

  @override
  String get chatSquadron => 'Escadrille';

  @override
  String get chatFriends => 'Amis';

  @override
  String get chatSend => 'Envoyer';

  @override
  String get chatReport => 'Signaler';

  @override
  String get chatBlock => 'Bloquer';

  @override
  String get chatSlowDown => 'Doucement : 1 message toutes les 3 secondes.';

  @override
  String get chatFiltered => 'Message bloqué par le filtre.';

  @override
  String get chatMuted => 'Tu es réduit au silence pour un moment.';

  @override
  String get chatDisabled => 'Le chat est désactivé dans les Options.';

  @override
  String get chatOffline => 'Le chat nécessite une connexion.';

  @override
  String get reported => 'Signalé. Merci !';

  @override
  String get emoteNiceShot => 'Joli tir !';

  @override
  String get emoteHelpBoss => 'De l\'aide pour le boss ?';

  @override
  String get emoteGG => 'GG';

  @override
  String get emoteHi => 'Salut !';

  @override
  String get emoteThanks => 'Merci !';

  @override
  String get emoteOneMore => 'Encore une !';

  @override
  String get squadGoal => 'Objectif hebdo de l\'escadrille';

  @override
  String get maxCombo => 'Combo max';

  @override
  String get shareChallenge => 'Défier des amis';

  @override
  String get shareCardBeat => 'Tu peux me battre ?';

  @override
  String shareText(int score, String code) {
    return 'J\'ai fait $score points sur Orbit Commando \'94 ! Même niveau, même seed : bats-moi avec le code $code';
  }

  @override
  String get menuDaily => 'Orbite du jour';

  @override
  String get menuChallenges => 'Défis';

  @override
  String get dailyDesc =>
      'Aujourd\'hui, le même niveau et le même remix pour tous les joueurs du monde.';

  @override
  String get challengeCodeTitle => 'Code de défi d\'un ami';

  @override
  String get challengeCodeHint => 'Colle ou tape le code, ex. OC-7K2M9-QX4TB';

  @override
  String get challengeInvalid => 'Code invalide. Vérifie-le et réessaie.';

  @override
  String challengeTarget(int score) {
    return 'Bats $score';
  }

  @override
  String get challengeBeaten => 'Défi relevé ! Renvoie-le.';

  @override
  String get challengeLost => 'Pas cette fois. On remet ça ?';

  @override
  String get paste => 'Coller';

  @override
  String get lvlW1L1 => 'Ceinture Tranquille';

  @override
  String get lvlW1L2 => 'Champ de Cailloux';

  @override
  String get lvlW1L3 => 'Le Mech à Ressort';

  @override
  String get lvlW1L4 => 'Face Cachée du Caillou';

  @override
  String get lvlW1L5 => 'Tamponneur Suprême';

  @override
  String get lvlW2L1 => 'Couloir Margherita';

  @override
  String get lvlW2L2 => 'Salle Antigravité';

  @override
  String get lvlW2L3 => 'Moto-Fusée Express';

  @override
  String get lvlW2L4 => 'Anneaux de Pizza';

  @override
  String get lvlW2L5 => 'La Grande Machine à Laver Cosmique';

  @override
  String get lvlW3L1 => 'Archipel Glorbo';

  @override
  String get lvlW3L2 => 'Navette dans le Vide';

  @override
  String get lvlW3L3 => 'Usine à Formulaires';

  @override
  String get lvlW3L4 => 'Dernier Guichet';

  @override
  String get lvlW3L5 => 'Empereur Glorbo';
}
