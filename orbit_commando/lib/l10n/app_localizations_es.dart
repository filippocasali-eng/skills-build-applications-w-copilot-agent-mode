// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get appTitle => 'Orbit Commando \'94';

  @override
  String get pressStart => 'Pulsa start';

  @override
  String get insertCoin => 'Inserta moneda';

  @override
  String creditsLabel(int count) {
    return 'Créditos $count';
  }

  @override
  String get sandboxLabel => 'Sandbox';

  @override
  String get studioPresents => 'Pixel Orbit Studio presenta';

  @override
  String get copyright => '(c) 1994 Pixel Orbit Studio';

  @override
  String get back => 'Atrás';

  @override
  String get ok => 'OK';

  @override
  String get cancel => 'Cancelar';

  @override
  String get yes => 'Sí';

  @override
  String get no => 'No';

  @override
  String get next => 'Siguiente';

  @override
  String get play => 'Jugar';

  @override
  String get locked => 'Bloqueado';

  @override
  String get loading => 'Cargando...';

  @override
  String get comingSoon => 'Disponible online en la v2';

  @override
  String get menuCampaign => 'Campaña';

  @override
  String get menuArcade => 'Modo arcade';

  @override
  String get menuBossRush => 'Boss rush';

  @override
  String get menuWeekly => 'Reto semanal';

  @override
  String get menuWorkshop => 'Taller';

  @override
  String get menuGallery => 'Galería';

  @override
  String get menuJukebox => 'Rocola';

  @override
  String get menuShop => 'Tienda';

  @override
  String get menuTrophies => 'Trofeos';

  @override
  String get menuScores => 'Récords';

  @override
  String get menuSettings => 'Ajustes';

  @override
  String get menuChat => 'Chat de escuadrón';

  @override
  String get unlockArcade => 'Supera el Mundo 1 para desbloquear';

  @override
  String get unlockBossRush => 'Supera la campaña para desbloquear';

  @override
  String pilotRank(int rank) {
    return 'Rango de piloto $rank';
  }

  @override
  String tokens(int count) {
    return 'Fichas $count';
  }

  @override
  String worldN(int n) {
    return 'Mundo $n';
  }

  @override
  String get world1Name => 'Cinturón de Asteroides Tranquilo';

  @override
  String get world2Name => 'Estación Orbital Pizza-Station';

  @override
  String get world3Name => 'Planeta Glorbo Prime';

  @override
  String levelN(int n) {
    return 'Nivel $n';
  }

  @override
  String get bossStage => 'Jefe';

  @override
  String bestScore(int score) {
    return 'Récord $score';
  }

  @override
  String get difficulty => 'Dificultad';

  @override
  String get diffEasy => 'Fácil';

  @override
  String get diffNormal => 'Normal';

  @override
  String get diffArcade => 'Arcade';

  @override
  String get diffEasyHelp =>
      '3 puntos de vida, apuntado asistido, enemigos más lentos';

  @override
  String get diffNormalHelp => 'Un golpe, una vida';

  @override
  String get diffArcadeHelp => 'Como Normal, créditos limitados, sin mejoras';

  @override
  String get chooseHero => 'Elige a tu comando';

  @override
  String get heroLocked => 'Bloqueado';

  @override
  String get heroRoxy => 'Rápida y sin miedo. Nunca falla un salto.';

  @override
  String get heroBrutus => 'Armas grandes, corazón aún más grande.';

  @override
  String get heroNyx => 'Desbloquear: supera el Mundo 2.';

  @override
  String get heroDoc => 'Desbloquear: supera la campaña.';

  @override
  String get heroNyxBio => 'Pistolas gemelas, cero paciencia.';

  @override
  String get heroDocBio => 'Se fabricó su propio cañón. Con una tostadora.';

  @override
  String get paused => 'Pausa';

  @override
  String get resume => 'Continuar';

  @override
  String get restart => 'Reiniciar';

  @override
  String get quitToMap => 'Volver al mapa';

  @override
  String get quitToTitle => 'Volver al título';

  @override
  String get continueQuestion => '¿Continuar?';

  @override
  String get continueCost => '1 crédito';

  @override
  String get gameOver => 'Game over';

  @override
  String get noCredits => 'Sin créditos';

  @override
  String get watchAdCredit => 'Mira un vídeo: +1 crédito';

  @override
  String get assistTitle => '¿Te echo una mano?';

  @override
  String get assistBody => '¿Un escudo de 10 segundos? Sin penalización.';

  @override
  String get assistYes => 'Activar escudo';

  @override
  String get assistNo => 'Yo puedo';

  @override
  String get stageClear => '¡Nivel superado!';

  @override
  String get score => 'Puntos';

  @override
  String get timeBonus => 'Bonus de tiempo';

  @override
  String get noDeathBonus => 'Bonus sin morir';

  @override
  String get total => 'Total';

  @override
  String get rank => 'Rango';

  @override
  String get time => 'Tiempo';

  @override
  String get hostages => 'Rehenes';

  @override
  String get cassettes => 'Casetes';

  @override
  String get kills => 'Bajas';

  @override
  String get medalNoDeath => 'Sin morir';

  @override
  String get medalHostages => 'Todos los rehenes';

  @override
  String get medalSpeedrun => 'Speedrun';

  @override
  String get newRecord => '¡Nuevo récord!';

  @override
  String earnedTokens(int count) {
    return '+$count fichas';
  }

  @override
  String get earnedCredit => '+1 crédito';

  @override
  String get unlockedArcade => '¡Modo arcade desbloqueado!';

  @override
  String get unlockedBossRush => '¡Boss rush desbloqueado!';

  @override
  String unlockedHero(String name) {
    return '¡Nuevo comando: $name!';
  }

  @override
  String trophyUnlocked(String name) {
    return 'Trofeo: $name';
  }

  @override
  String get enterInitials => 'Escribe tus iniciales';

  @override
  String get doubleTokensAd => 'Mira un vídeo: fichas dobles';

  @override
  String get campaignComplete =>
      'El Imperio Glorbo queda archivado. ¡Gracias, comando!';

  @override
  String get setAudio => 'Audio';

  @override
  String get setMusic => 'Música';

  @override
  String get setSfx => 'Efectos';

  @override
  String get setVideo => 'Vídeo';

  @override
  String get setCrt => 'Filtro CRT';

  @override
  String get crtOff => 'Apagado';

  @override
  String get crtArcade => 'Máquina recreativa';

  @override
  String get crtTv => 'Tele del salón';

  @override
  String get setGame => 'Juego';

  @override
  String get setCamera => 'Cámara';

  @override
  String get cameraRotating => 'Giratoria';

  @override
  String get cameraFixed => 'Fija (menos movimiento)';

  @override
  String get setAutoAim => 'Apuntado asistido';

  @override
  String get setVibration => 'Vibración';

  @override
  String get setLanguage => 'Idioma';

  @override
  String get langSystem => 'Sistema';

  @override
  String get setControls => 'Disposición de controles';

  @override
  String get controlsHelp =>
      'Arrastra los botones para moverlos. Usa +/- para cambiar su tamaño.';

  @override
  String get opacity => 'Opacidad';

  @override
  String get resetDefaults => 'Restablecer';

  @override
  String get setPrivacy => 'Privacidad';

  @override
  String get setAnalytics => 'Compartir estadísticas anónimas';

  @override
  String get setChat => 'Chat';

  @override
  String get setNotifications => 'Notificaciones de ofertas';

  @override
  String get setConsent => 'Consentimiento de anuncios';

  @override
  String get setSpendLimit => 'Límite de gasto mensual';

  @override
  String get noLimit => 'Sin límite';

  @override
  String get purchaseHistory => 'Historial de compras';

  @override
  String get restorePurchases => 'Restaurar compras';

  @override
  String get privacyPolicy => 'Política de privacidad';

  @override
  String get deleteData => 'Borrar mis datos';

  @override
  String get on => 'Sí';

  @override
  String get off => 'No';

  @override
  String get upDamage => 'Daño de armas';

  @override
  String get upHp => 'Puntos de vida extra';

  @override
  String get upShield => 'Escudo inicial';

  @override
  String get upFireRate => 'Cadencia de disparo';

  @override
  String get upGrenades => 'Granadas iniciales';

  @override
  String upLevel(int level, int max) {
    return 'Nv $level/$max';
  }

  @override
  String buyTokens(int count) {
    return '$count fichas';
  }

  @override
  String buyGems(int count) {
    return '$count gemas';
  }

  @override
  String get maxed => 'Máx';

  @override
  String get notEnough => 'No alcanza';

  @override
  String get arcadeNoUpgrades =>
      'Las mejoras están desactivadas en dificultad Arcade.';

  @override
  String get galleryLocked => 'Encuentra más casetes para desbloquear';

  @override
  String cassettesFound(int count, int total) {
    return 'Casetes $count/$total';
  }

  @override
  String get nowPlaying => 'Sonando';

  @override
  String trophiesCount(int count, int total) {
    return '$count/$total trofeos';
  }

  @override
  String get tip1 => 'Manual p.12: las granadas rebotan. Tus excusas también.';

  @override
  String get tip2 => 'Manual p.4: sopla en el cartucho si el planeta no carga.';

  @override
  String get tip3 =>
      'Manual p.9: en un planetoide, abajo es donde están tus pies.';

  @override
  String get tip4 =>
      'Manual p.21: los Glorbo solo temen dos cosas: a ti y a los formularios mal rellenados.';

  @override
  String get tip5 =>
      'Manual p.7: los enemigos gritan antes de disparar. Escúchalos.';

  @override
  String get tip6 => 'Manual p.30: los rehenes dan buena propina. En granadas.';

  @override
  String get tip7 => 'Manual p.16: caminar boca abajo no anula la garantía.';

  @override
  String get tip8 => 'Manual p.2: no alimentes a la lavadora. En serio.';

  @override
  String get cheatBigHeads => '¡Cabezones!';

  @override
  String get cheatGiantPixels => '¡Píxeles gigantes!';

  @override
  String get cheatBrokenTube => '¡Modo tubo roto!';

  @override
  String get shopCartridge => 'Cartucho Completo';

  @override
  String get shopCartridgeDesc =>
      'Mundos 2-3, Boss Rush, créditos infinitos en campaña, sin anuncios. Como comprar el cartucho: una sola vez.';

  @override
  String get owned => 'Comprado';

  @override
  String get gems => 'Gemas Quásar';

  @override
  String gemsApprox(String price) {
    return 'aprox. $price';
  }

  @override
  String get capsules => 'Cápsulas cósmicas';

  @override
  String get capsuleOpen => 'Abrir cápsula';

  @override
  String get capsuleFree => 'Cápsula gratis del día';

  @override
  String get capsuleOdds => 'Probabilidades';

  @override
  String get capsuleOddsTitle => 'Probabilidades exactas';

  @override
  String pityCounter(int count) {
    return 'Legendaria garantizada en $count aperturas';
  }

  @override
  String get rarityCommon => 'Común';

  @override
  String get rarityRare => 'Rara';

  @override
  String get rarityEpic => 'Épica';

  @override
  String get rarityLegendary => 'Legendaria';

  @override
  String get paidCapsulesBlocked =>
      'Las cápsulas de pago no están disponibles en tu país. Las gratis sí.';

  @override
  String get paidCapsulesMinor =>
      'Las cápsulas de pago están desactivadas para menores de 18 años.';

  @override
  String get dailyShop => 'Tienda del día';

  @override
  String refreshesIn(String time) {
    return 'Se renueva en $time';
  }

  @override
  String get flashOffer => 'Oferta relámpago';

  @override
  String endsIn(String time) {
    return 'Termina en $time';
  }

  @override
  String get seasonPass => 'Pase de temporada';

  @override
  String seasonEndsIn(String time) {
    return 'La temporada termina en $time';
  }

  @override
  String get freeTrack => 'Gratis';

  @override
  String get premiumTrack => 'Premium';

  @override
  String get dailyLogin => 'Entrada diaria';

  @override
  String dayN(int n) {
    return 'Día $n';
  }

  @override
  String get claim => 'Recoger';

  @override
  String get claimed => 'Recogido';

  @override
  String get buy => 'Comprar';

  @override
  String get storeUnavailable => 'Tienda no disponible en este dispositivo.';

  @override
  String get spendLimitReached => 'Límite de gasto mensual alcanzado.';

  @override
  String get purchasePending => 'Compra pendiente...';

  @override
  String get purchaseDone => '¡Gracias!';

  @override
  String get starterPack => 'Pack de inicio';

  @override
  String get weeklyEvent => 'Evento semanal';

  @override
  String get noPurchases => 'Aún no hay compras.';

  @override
  String get ageGateTitle => '¿Cuándo naciste?';

  @override
  String get ageGateBody =>
      'Lo preguntamos una sola vez, para activar las funciones adecuadas a tu edad.';

  @override
  String get year => 'Año';

  @override
  String get month => 'Mes';

  @override
  String get confirm => 'Confirmar';

  @override
  String get onlineUnder16 =>
      'Las funciones online están disponibles a partir de los 16 años.';

  @override
  String get chatEmotesOnly => 'Solo mensajes rápidos (menores de 18).';

  @override
  String get chatSignIn => 'Inicia sesión con Google para chatear';

  @override
  String get chatGlobal => 'Global';

  @override
  String get chatSquadron => 'Escuadrón';

  @override
  String get chatFriends => 'Amigos';

  @override
  String get chatSend => 'Enviar';

  @override
  String get chatReport => 'Denunciar';

  @override
  String get chatBlock => 'Bloquear';

  @override
  String get chatSlowDown => 'Más despacio: 1 mensaje cada 3 segundos.';

  @override
  String get chatFiltered => 'Mensaje bloqueado por el filtro.';

  @override
  String get chatMuted => 'Estás silenciado durante un rato.';

  @override
  String get chatDisabled => 'El chat está desactivado en Ajustes.';

  @override
  String get chatOffline => 'El chat necesita conexión.';

  @override
  String get reported => 'Denunciado. ¡Gracias!';

  @override
  String get emoteNiceShot => '¡Buen tiro!';

  @override
  String get emoteHelpBoss => '¿Ayuda con el jefe?';

  @override
  String get emoteGG => 'GG';

  @override
  String get emoteHi => '¡Hola!';

  @override
  String get emoteThanks => '¡Gracias!';

  @override
  String get emoteOneMore => '¡Otra más!';

  @override
  String get squadGoal => 'Objetivo semanal del escuadrón';

  @override
  String get maxCombo => 'Combo máx';

  @override
  String get shareChallenge => 'Retar a amigos';

  @override
  String get shareCardBeat => '¿Puedes superarme?';

  @override
  String shareText(int score, String code) {
    return '¡Hice $score puntos en Orbit Commando \'94! Mismo nivel, misma semilla: supérame con el código $code';
  }

  @override
  String get menuDaily => 'Órbita del día';

  @override
  String get menuChallenges => 'Retos';

  @override
  String get dailyDesc =>
      'Hoy, el mismo nivel y el mismo remix para todos los jugadores del mundo.';

  @override
  String get challengeCodeTitle => 'Código de reto de un amigo';

  @override
  String get challengeCodeHint =>
      'Pega o escribe el código, p. ej. OC-7K2M9-QX4TB';

  @override
  String get challengeInvalid =>
      'Código no válido. Revísalo e inténtalo de nuevo.';

  @override
  String challengeTarget(int score) {
    return 'Supera $score';
  }

  @override
  String get challengeBeaten => '¡Reto superado! Devuélvelo.';

  @override
  String get challengeLost => 'Esta vez no. ¿Otra?';

  @override
  String get paste => 'Pegar';

  @override
  String get lvlW1L1 => 'Cinturón Tranquilo';

  @override
  String get lvlW1L2 => 'Campo de Rocas';

  @override
  String get lvlW1L3 => 'El Mech de Muelles';

  @override
  String get lvlW1L4 => 'Cara Oculta de la Roca';

  @override
  String get lvlW1L5 => 'Sellador Supremo';

  @override
  String get lvlW2L1 => 'Pasillo Margarita';

  @override
  String get lvlW2L2 => 'Sala Antigravedad';

  @override
  String get lvlW2L3 => 'Moto-Cohete Express';

  @override
  String get lvlW2L4 => 'Anillos de Pizza';

  @override
  String get lvlW2L5 => 'La Gran Lavadora Cósmica';

  @override
  String get lvlW3L1 => 'Archipiélago Glorbo';

  @override
  String get lvlW3L2 => 'Lanzadera en el Vacío';

  @override
  String get lvlW3L3 => 'Fábrica de Formularios';

  @override
  String get lvlW3L4 => 'Última Ventanilla';

  @override
  String get lvlW3L5 => 'Emperador Glorbo';
}
