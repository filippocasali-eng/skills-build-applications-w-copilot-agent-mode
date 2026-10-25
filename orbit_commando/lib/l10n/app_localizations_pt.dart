// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Portuguese (`pt`).
class AppLocalizationsPt extends AppLocalizations {
  AppLocalizationsPt([String locale = 'pt']) : super(locale);

  @override
  String get appTitle => 'Orbit Commando \'94';

  @override
  String get pressStart => 'Aperte start';

  @override
  String get insertCoin => 'Insira a ficha';

  @override
  String creditsLabel(int count) {
    return 'Créditos $count';
  }

  @override
  String get sandboxLabel => 'Sandbox';

  @override
  String get studioPresents => 'Pixel Orbit Studio apresenta';

  @override
  String get copyright => '(c) 1994 Pixel Orbit Studio';

  @override
  String get back => 'Voltar';

  @override
  String get ok => 'OK';

  @override
  String get cancel => 'Cancelar';

  @override
  String get yes => 'Sim';

  @override
  String get no => 'Não';

  @override
  String get next => 'Avançar';

  @override
  String get play => 'Jogar';

  @override
  String get locked => 'Bloqueado';

  @override
  String get loading => 'Carregando...';

  @override
  String get comingSoon => 'Disponível online na v2';

  @override
  String get menuCampaign => 'Campanha';

  @override
  String get menuArcade => 'Modo arcade';

  @override
  String get menuBossRush => 'Boss rush';

  @override
  String get menuWeekly => 'Desafio semanal';

  @override
  String get menuWorkshop => 'Oficina';

  @override
  String get menuGallery => 'Galeria';

  @override
  String get menuJukebox => 'Jukebox';

  @override
  String get menuShop => 'Loja';

  @override
  String get menuTrophies => 'Troféus';

  @override
  String get menuScores => 'Recordes';

  @override
  String get menuSettings => 'Configurações';

  @override
  String get menuChat => 'Chat do esquadrão';

  @override
  String get unlockArcade => 'Termine o Mundo 1 para desbloquear';

  @override
  String get unlockBossRush => 'Termine a campanha para desbloquear';

  @override
  String pilotRank(int rank) {
    return 'Patente de piloto $rank';
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
  String get world1Name => 'Cinturão de Asteroides Tranquilo';

  @override
  String get world2Name => 'Estação Orbital Pizza-Station';

  @override
  String get world3Name => 'Planeta Glorbo Prime';

  @override
  String levelN(int n) {
    return 'Fase $n';
  }

  @override
  String get bossStage => 'Chefe';

  @override
  String bestScore(int score) {
    return 'Recorde $score';
  }

  @override
  String get difficulty => 'Dificuldade';

  @override
  String get diffEasy => 'Fácil';

  @override
  String get diffNormal => 'Normal';

  @override
  String get diffArcade => 'Arcade';

  @override
  String get diffEasyHelp =>
      '3 pontos de vida, mira assistida, inimigos mais lentos';

  @override
  String get diffNormalHelp => 'Um tiro, uma vida';

  @override
  String get diffArcadeHelp =>
      'Como o Normal, créditos limitados, sem melhorias';

  @override
  String get chooseHero => 'Escolha seu comando';

  @override
  String get heroLocked => 'Bloqueado';

  @override
  String get heroRoxy => 'Rápida e destemida. Nunca erra um pulo.';

  @override
  String get heroBrutus => 'Armas grandes, coração maior ainda.';

  @override
  String get heroNyx => 'Desbloquear: termine o Mundo 2.';

  @override
  String get heroDoc => 'Desbloquear: termine a campanha.';

  @override
  String get heroNyxBio => 'Pistolas gêmeas, zero paciência.';

  @override
  String get heroDocBio => 'Construiu o próprio canhão. Com uma torradeira.';

  @override
  String get paused => 'Pausa';

  @override
  String get resume => 'Continuar';

  @override
  String get restart => 'Reiniciar';

  @override
  String get quitToMap => 'Voltar ao mapa';

  @override
  String get quitToTitle => 'Voltar ao título';

  @override
  String get continueQuestion => 'Continuar?';

  @override
  String get continueCost => '1 crédito';

  @override
  String get gameOver => 'Game over';

  @override
  String get noCredits => 'Sem créditos';

  @override
  String get watchAdCredit => 'Assista a um vídeo: +1 crédito';

  @override
  String get assistTitle => 'Precisa de uma ajuda?';

  @override
  String get assistBody => 'Quer um escudo de 10 segundos? Sem penalidade.';

  @override
  String get assistYes => 'Ativar escudo';

  @override
  String get assistNo => 'Eu consigo';

  @override
  String get stageClear => 'Fase concluída!';

  @override
  String get score => 'Pontos';

  @override
  String get timeBonus => 'Bônus de tempo';

  @override
  String get noDeathBonus => 'Bônus sem mortes';

  @override
  String get total => 'Total';

  @override
  String get rank => 'Rank';

  @override
  String get time => 'Tempo';

  @override
  String get hostages => 'Reféns';

  @override
  String get cassettes => 'Fitas';

  @override
  String get kills => 'Abates';

  @override
  String get medalNoDeath => 'Sem mortes';

  @override
  String get medalHostages => 'Todos os reféns';

  @override
  String get medalSpeedrun => 'Speedrun';

  @override
  String get newRecord => 'Novo recorde!';

  @override
  String earnedTokens(int count) {
    return '+$count fichas';
  }

  @override
  String get earnedCredit => '+1 crédito';

  @override
  String get unlockedArcade => 'Modo arcade desbloqueado!';

  @override
  String get unlockedBossRush => 'Boss rush desbloqueado!';

  @override
  String unlockedHero(String name) {
    return 'Novo comando: $name!';
  }

  @override
  String trophyUnlocked(String name) {
    return 'Troféu: $name';
  }

  @override
  String get enterInitials => 'Digite suas iniciais';

  @override
  String get doubleTokensAd => 'Assista a um vídeo: fichas em dobro';

  @override
  String get campaignComplete =>
      'O Império Glorbo foi arquivado. Valeu, comando!';

  @override
  String get setAudio => 'Áudio';

  @override
  String get setMusic => 'Música';

  @override
  String get setSfx => 'Efeitos';

  @override
  String get setVideo => 'Vídeo';

  @override
  String get setCrt => 'Filtro CRT';

  @override
  String get crtOff => 'Desligado';

  @override
  String get crtArcade => 'Fliperama';

  @override
  String get crtTv => 'TV da sala';

  @override
  String get setGame => 'Jogo';

  @override
  String get setCamera => 'Câmera';

  @override
  String get cameraRotating => 'Giratória';

  @override
  String get cameraFixed => 'Fixa (menos movimento)';

  @override
  String get setAutoAim => 'Mira assistida';

  @override
  String get setVibration => 'Vibração';

  @override
  String get setLanguage => 'Idioma';

  @override
  String get langSystem => 'Sistema';

  @override
  String get setControls => 'Layout dos controles';

  @override
  String get controlsHelp =>
      'Arraste os botões para movê-los. Use +/- para redimensionar.';

  @override
  String get opacity => 'Opacidade';

  @override
  String get resetDefaults => 'Restaurar';

  @override
  String get setPrivacy => 'Privacidade';

  @override
  String get setAnalytics => 'Compartilhar estatísticas anônimas';

  @override
  String get setChat => 'Chat';

  @override
  String get setNotifications => 'Notificações de ofertas';

  @override
  String get setConsent => 'Consentimento de anúncios';

  @override
  String get setSpendLimit => 'Limite de gastos mensal';

  @override
  String get noLimit => 'Sem limite';

  @override
  String get purchaseHistory => 'Histórico de compras';

  @override
  String get restorePurchases => 'Restaurar compras';

  @override
  String get privacyPolicy => 'Política de privacidade';

  @override
  String get deleteData => 'Apagar meus dados';

  @override
  String get on => 'Sim';

  @override
  String get off => 'Não';

  @override
  String get upDamage => 'Dano das armas';

  @override
  String get upHp => 'Pontos de vida extras';

  @override
  String get upShield => 'Escudo inicial';

  @override
  String get upFireRate => 'Cadência de tiro';

  @override
  String get upGrenades => 'Granadas iniciais';

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
  String get notEnough => 'Não dá';

  @override
  String get arcadeNoUpgrades =>
      'As melhorias ficam desativadas na dificuldade Arcade.';

  @override
  String get galleryLocked => 'Encontre mais fitas para desbloquear';

  @override
  String cassettesFound(int count, int total) {
    return 'Fitas $count/$total';
  }

  @override
  String get nowPlaying => 'Tocando agora';

  @override
  String trophiesCount(int count, int total) {
    return '$count/$total troféus';
  }

  @override
  String get tip1 => 'Manual p.12: granadas quicam. Suas desculpas também.';

  @override
  String get tip2 =>
      'Manual p.4: assopre o cartucho se o planeta não carregar.';

  @override
  String get tip3 =>
      'Manual p.9: num planetoide, embaixo é onde estão seus pés.';

  @override
  String get tip4 =>
      'Manual p.21: os Glorbo só temem duas coisas: você e formulário preenchido errado.';

  @override
  String get tip5 =>
      'Manual p.7: os inimigos gritam antes de atirar. Preste atenção.';

  @override
  String get tip6 => 'Manual p.30: reféns dão boas gorjetas. Em granadas.';

  @override
  String get tip7 =>
      'Manual p.16: andar de cabeça para baixo não anula a garantia.';

  @override
  String get tip8 => 'Manual p.2: não alimente a máquina de lavar. Sério.';

  @override
  String get cheatBigHeads => 'Cabeçudos!';

  @override
  String get cheatGiantPixels => 'Pixels gigantes!';

  @override
  String get cheatBrokenTube => 'Modo tubo quebrado!';

  @override
  String get shopCartridge => 'Cartucho Completo';

  @override
  String get shopCartridgeDesc =>
      'Mundos 2-3, Boss Rush, créditos infinitos na campanha, sem anúncios. Como comprar o cartucho: uma vez só.';

  @override
  String get owned => 'Comprado';

  @override
  String get gems => 'Gemas Quasar';

  @override
  String gemsApprox(String price) {
    return 'cerca de $price';
  }

  @override
  String get capsules => 'Cápsulas cósmicas';

  @override
  String get capsuleOpen => 'Abrir cápsula';

  @override
  String get capsuleFree => 'Cápsula grátis do dia';

  @override
  String get capsuleOdds => 'Chances';

  @override
  String get capsuleOddsTitle => 'Chances exatas';

  @override
  String pityCounter(int count) {
    return 'Lendária garantida em $count aberturas';
  }

  @override
  String get rarityCommon => 'Comum';

  @override
  String get rarityRare => 'Rara';

  @override
  String get rarityEpic => 'Épica';

  @override
  String get rarityLegendary => 'Lendária';

  @override
  String get paidCapsulesBlocked =>
      'Cápsulas pagas não estão disponíveis no seu país. As grátis continuam valendo.';

  @override
  String get paidCapsulesMinor =>
      'Cápsulas pagas ficam desativadas para menores de 18 anos.';

  @override
  String get dailyShop => 'Loja do dia';

  @override
  String refreshesIn(String time) {
    return 'Renova em $time';
  }

  @override
  String get flashOffer => 'Oferta relâmpago';

  @override
  String endsIn(String time) {
    return 'Termina em $time';
  }

  @override
  String get seasonPass => 'Passe de temporada';

  @override
  String seasonEndsIn(String time) {
    return 'A temporada termina em $time';
  }

  @override
  String get freeTrack => 'Grátis';

  @override
  String get premiumTrack => 'Premium';

  @override
  String get dailyLogin => 'Login diário';

  @override
  String dayN(int n) {
    return 'Dia $n';
  }

  @override
  String get claim => 'Resgatar';

  @override
  String get claimed => 'Resgatado';

  @override
  String get buy => 'Comprar';

  @override
  String get storeUnavailable => 'Loja indisponível neste aparelho.';

  @override
  String get spendLimitReached => 'Limite de gastos mensal atingido.';

  @override
  String get purchasePending => 'Compra pendente...';

  @override
  String get purchaseDone => 'Valeu!';

  @override
  String get starterPack => 'Pacote inicial';

  @override
  String get weeklyEvent => 'Evento da semana';

  @override
  String get noPurchases => 'Nenhuma compra ainda.';

  @override
  String get ageGateTitle => 'Quando você nasceu?';

  @override
  String get ageGateBody =>
      'Perguntamos só uma vez, para ativar os recursos certos para sua idade.';

  @override
  String get year => 'Ano';

  @override
  String get month => 'Mês';

  @override
  String get confirm => 'Confirmar';

  @override
  String get onlineUnder16 =>
      'Os recursos online estão disponíveis a partir dos 16 anos.';

  @override
  String get chatEmotesOnly => 'Só mensagens rápidas (menores de 18).';

  @override
  String get chatSignIn => 'Entre com o Google para conversar';

  @override
  String get chatGlobal => 'Global';

  @override
  String get chatSquadron => 'Esquadrão';

  @override
  String get chatFriends => 'Amigos';

  @override
  String get chatSend => 'Enviar';

  @override
  String get chatReport => 'Denunciar';

  @override
  String get chatBlock => 'Bloquear';

  @override
  String get chatSlowDown => 'Calma: 1 mensagem a cada 3 segundos.';

  @override
  String get chatFiltered => 'Mensagem bloqueada pelo filtro.';

  @override
  String get chatMuted => 'Você está silenciado por um tempo.';

  @override
  String get chatDisabled => 'O chat está desativado nas Configurações.';

  @override
  String get chatOffline => 'O chat precisa de conexão.';

  @override
  String get reported => 'Denunciado. Valeu!';

  @override
  String get emoteNiceShot => 'Belo tiro!';

  @override
  String get emoteHelpBoss => 'Ajuda com o chefe?';

  @override
  String get emoteGG => 'GG';

  @override
  String get emoteHi => 'Oi!';

  @override
  String get emoteThanks => 'Valeu!';

  @override
  String get emoteOneMore => 'Mais uma!';

  @override
  String get squadGoal => 'Meta semanal do esquadrão';

  @override
  String get maxCombo => 'Combo máx';

  @override
  String get shareChallenge => 'Desafiar amigos';

  @override
  String get shareCardBeat => 'Consegue me superar?';

  @override
  String shareText(int score, String code) {
    return 'Fiz $score pontos no Orbit Commando \'94! Mesma fase, mesma seed: me supere com o código $code';
  }

  @override
  String get menuDaily => 'Órbita do dia';

  @override
  String get menuChallenges => 'Desafios';

  @override
  String get dailyDesc =>
      'Hoje, a mesma fase e o mesmo remix para todos os jogadores do mundo.';

  @override
  String get challengeCodeTitle => 'Código de desafio de um amigo';

  @override
  String get challengeCodeHint => 'Cole ou digite o código, ex. OC-7K2M9-QX4TB';

  @override
  String get challengeInvalid => 'Código inválido. Confira e tente de novo.';

  @override
  String challengeTarget(int score) {
    return 'Supere $score';
  }

  @override
  String get challengeBeaten => 'Desafio vencido! Devolva o desafio.';

  @override
  String get challengeLost => 'Não foi dessa vez. Mais uma?';

  @override
  String get paste => 'Colar';

  @override
  String get lvlW1L1 => 'Cinturão Tranquilo';

  @override
  String get lvlW1L2 => 'Campo de Pedras';

  @override
  String get lvlW1L3 => 'O Mech de Mola';

  @override
  String get lvlW1L4 => 'Lado Escuro da Pedra';

  @override
  String get lvlW1L5 => 'Carimbador Supremo';

  @override
  String get lvlW2L1 => 'Corredor Margherita';

  @override
  String get lvlW2L2 => 'Sala Antigravidade';

  @override
  String get lvlW2L3 => 'Moto-Foguete Expresso';

  @override
  String get lvlW2L4 => 'Anéis de Pizza';

  @override
  String get lvlW2L5 => 'A Grande Lavadora Cósmica';

  @override
  String get lvlW3L1 => 'Arquipélago Glorbo';

  @override
  String get lvlW3L2 => 'Nave no Vazio';

  @override
  String get lvlW3L3 => 'Fábrica de Formulários';

  @override
  String get lvlW3L4 => 'Último Guichê';

  @override
  String get lvlW3L5 => 'Imperador Glorbo';
}
