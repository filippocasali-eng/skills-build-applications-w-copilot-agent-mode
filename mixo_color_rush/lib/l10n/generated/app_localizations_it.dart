// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Italian (`it`).
class AppLocalizationsIt extends AppLocalizations {
  AppLocalizationsIt([String locale = 'it']) : super(locale);

  @override
  String get appTitle => 'MIXO: Color Rush';

  @override
  String get play => 'GIOCA';

  @override
  String get again => 'ANCORA!';

  @override
  String get home => 'Home';

  @override
  String get score => 'Punteggio';

  @override
  String best(int score) {
    return 'Record: $score';
  }

  @override
  String get newRecord => 'NUOVO RECORD!';

  @override
  String get paused => 'Pausa';

  @override
  String get resume => 'Riprendi';

  @override
  String get pause => 'Pausa';

  @override
  String get cancel => 'Annulla';

  @override
  String get loading => 'Caricamento…';

  @override
  String get swipeHint => 'Scorri per cambiare corsia';

  @override
  String get matchHint => 'Passa dalle porte del TUO colore!';

  @override
  String get onboardingHint =>
      'Questo è Mixo! Raggiungi la porta del suo colore.';

  @override
  String get onboardingDone => 'Sei pronto. Si corre!';

  @override
  String get bravo => 'Bravo!';

  @override
  String hearts(int count) {
    return 'Cuori: $count';
  }

  @override
  String comboLabel(int multiplier) {
    return 'Combo x$multiplier';
  }

  @override
  String get combo => 'COMBO';

  @override
  String get nearMiss => 'PER UN PELO!';

  @override
  String timeLabel(int seconds) {
    return '$seconds s';
  }

  @override
  String levelShort(int level) {
    return 'Liv. $level';
  }

  @override
  String levelUp(int level) {
    return 'LIVELLO $level!';
  }

  @override
  String get newMechanic => 'NOVITÀ!';

  @override
  String get mechDrops => 'Le gocce cambiano il tuo colore!';

  @override
  String get mechObstacles => 'Evita i blocchi!';

  @override
  String get mechMixing => 'I colori si MESCOLANO! Rosso + Blu = Viola';

  @override
  String get mechSecondary => 'Porte di colori misti!';

  @override
  String get mechSpecials => 'Gocce speciali: Bianca, Arcobaleno, Inverti';

  @override
  String get mechFiveLanes => 'ESPERTO: 5 corsie!';

  @override
  String get mechJump => 'Tocca per SALTARE i blocchi bassi';

  @override
  String get mechDive => 'Scorri giù per il TUFFO (bonus!)';

  @override
  String get tipMix => 'Ricorda questo mix:';

  @override
  String get tipBrown => 'Marrone? Cerca una goccia bianca per pulire Mixo!';

  @override
  String get tipSymbol => 'Guarda il simbolo su Mixo e cerca la porta uguale.';

  @override
  String get tipDodge => 'Cambia corsia presto per evitare i blocchi.';

  @override
  String get tipJump => 'Tocca per saltare i blocchi bassi.';

  @override
  String get tipLookAhead => 'Guarda lontano: le porte arrivano veloci!';

  @override
  String get tipCombo => 'Niente errori per un po\' = combo x5!';

  @override
  String get tipGreat =>
      'Corsa fantastica! Riesci ad andare ancora più veloce?';

  @override
  String get missionDone => 'Missione completata';

  @override
  String get unlocked => 'Sbloccato';

  @override
  String get lessonComplete => 'LEZIONE COMPLETATA!';

  @override
  String get lessonFailed => 'Quasi! Riprova';

  @override
  String get ghostBeaten => 'HAI BATTUTO IL FANTASMA!';

  @override
  String ghostAhead(int points) {
    return 'Fantasma +$points';
  }

  @override
  String ghostBehind(int points) {
    return 'Tu +$points';
  }

  @override
  String get breakTitle => 'Ottima sessione! Fai una pausa?';

  @override
  String get breakBody =>
      'Giochi da 30 minuti. Sgranchisciti, bevi un po\' d\'acqua, guarda fuori dalla finestra!';

  @override
  String get takeBreak => 'Faccio una pausa';

  @override
  String get keepPlaying => 'Continua a giocare';

  @override
  String get limitTitle => 'Per oggi basta!';

  @override
  String get limitBody => 'Anche Mixo è stanco. Ci vediamo domani!';

  @override
  String get daily => 'Del Giorno';

  @override
  String get dailyInfo =>
      'Una pista uguale per tutti, per tutto il giorno. Giocala quante volte vuoi. Se salti un giorno, nessun problema!';

  @override
  String dailyBest(int score) {
    return 'Record di oggi: $score';
  }

  @override
  String dailyPlays(int count) {
    return 'Partite di oggi: $count';
  }

  @override
  String get academy => 'Accademia';

  @override
  String get mandatory => 'per sbloccare le modalità';

  @override
  String get lockedAcademyFirst =>
      'Completa prima le prime 2 lezioni dell\'Accademia!';

  @override
  String get ghost => 'Fantasma';

  @override
  String get ghostInfo =>
      'Gareggia contro la tua miglior corsa sulla stessa pista. Batti il tuo fantasma!';

  @override
  String ghostBest(int score) {
    return 'Fantasma da battere: $score';
  }

  @override
  String get ghostNone =>
      'Ancora nessun fantasma: la tua prima corsa diventa il fantasma!';

  @override
  String get collection => 'Collezione';

  @override
  String get skins => 'Mixo';

  @override
  String get trails => 'Scie';

  @override
  String get themes => 'Mondi';

  @override
  String get equip => 'Usa';

  @override
  String get equipped => 'In uso';

  @override
  String get inShop => 'Negozio';

  @override
  String reachLevel(int level) {
    return 'Raggiungi il livello $level per sbloccarlo!';
  }

  @override
  String get findInShop => 'Disponibile nel negozio (chiedi a un adulto).';

  @override
  String buyWithStars(int price) {
    return 'Sbloccare per $price stelle?';
  }

  @override
  String get unlock => 'Sblocca';

  @override
  String get notEnoughStars => 'Stelle insufficienti';

  @override
  String get missions => 'Missioni';

  @override
  String get missionsInfo =>
      'Completa una missione e ne arriva una nuova. Nessuna fretta, nessun timer!';

  @override
  String get trophies => 'Trofei';

  @override
  String get stats => 'Statistiche';

  @override
  String mColorGates(int count, String color) {
    return 'Passa $count porte $color';
  }

  @override
  String mCombo(int count) {
    return 'Raggiungi una combo di $count';
  }

  @override
  String mSurvive(int count) {
    return 'Corri per $count secondi';
  }

  @override
  String mScore(int count) {
    return 'Fai $count punti in una partita';
  }

  @override
  String mDrops(int count) {
    return 'Raccogli $count gocce';
  }

  @override
  String mNearMiss(int count) {
    return 'Fai $count \"per un pelo\"';
  }

  @override
  String mRuns(int count) {
    return 'Gioca $count partite';
  }

  @override
  String mMixGates(int count) {
    return 'Passa $count porte di colori misti';
  }

  @override
  String mJumps(int count) {
    return 'Salta $count blocchi';
  }

  @override
  String get colorRed => 'rosse';

  @override
  String get colorYellow => 'gialle';

  @override
  String get colorBlue => 'blu';

  @override
  String get colorOrange => 'arancioni';

  @override
  String get colorGreen => 'verdi';

  @override
  String get colorPurple => 'viola';

  @override
  String get colorBrown => 'marroni';

  @override
  String get statBest => 'Record';

  @override
  String get statCombo => 'Combo migliore';

  @override
  String get statLongest => 'Corsa più lunga';

  @override
  String get statRuns => 'Partite giocate';

  @override
  String get statTime => 'Tempo totale';

  @override
  String get statGates => 'Porte attraversate';

  @override
  String get statDrops => 'Gocce raccolte';

  @override
  String get statNearMiss => 'Per un pelo';

  @override
  String get statMix => 'Porte miste';

  @override
  String get statDaily => 'Sfide del giorno';

  @override
  String get statColors => 'Porte per colore';

  @override
  String get shop => 'Negozio';

  @override
  String get shopInfo =>
      'Solo aspetti per Mixo: non rendono mai il gioco più facile. Prezzi reali, nessuna sorpresa.';

  @override
  String get packContains => 'Questo pacchetto contiene:';

  @override
  String buyFor(String price) {
    return 'Acquista a $price';
  }

  @override
  String get owned => 'Già tuo';

  @override
  String get priceUnavailable => 'Prezzo non disponibile';

  @override
  String get storeUnavailable =>
      'Il negozio ora non è disponibile. Il gioco funziona benissimo lo stesso!';

  @override
  String get purchasesDisabled =>
      'Gli acquisti sono disattivati nell\'area genitori.';

  @override
  String get restorePurchases => 'Ripristina acquisti';

  @override
  String get purchasePending => 'Acquisto in attesa…';

  @override
  String get purchaseDone => 'Grazie! Trovi gli oggetti nella Collezione.';

  @override
  String get purchasesRestored => 'Acquisti ripristinati.';

  @override
  String get purchaseError => 'Qualcosa è andato storto. Nessun addebito.';

  @override
  String get purchaseCancelled => 'Acquisto annullato.';

  @override
  String get settings => 'Impostazioni';

  @override
  String get sound => 'Effetti sonori';

  @override
  String get music => 'Musica';

  @override
  String get vibration => 'Vibrazione';

  @override
  String get symbolsAlways => 'Simboli dei colori sempre visibili';

  @override
  String get reduceEffects => 'Effetti più calmi (niente scossoni)';

  @override
  String get controls => 'Controlli';

  @override
  String get controlSwipe => 'Scorri';

  @override
  String get controlTap => 'Tocca i lati';

  @override
  String get language => 'Lingua';

  @override
  String get languageSystem => 'Dispositivo';

  @override
  String get parentArea => 'Area genitori';

  @override
  String get privacy => 'Informativa privacy';

  @override
  String get credits => 'Crediti';

  @override
  String get pickName => 'Scegli il tuo nome';

  @override
  String get gateTitle => 'Chiedi a un adulto';

  @override
  String get gateHold => 'Adulti: tenete premuto il pulsante per 3 secondi.';

  @override
  String get gateWrong => 'Non è giusto. Prova questa.';

  @override
  String get dailyLimit => 'Limite di gioco giornaliero';

  @override
  String playedToday(int minutes) {
    return 'Giocato oggi: $minutes min';
  }

  @override
  String get noLimit => 'Nessun limite';

  @override
  String get extend15 => '+15 minuti oggi';

  @override
  String get purchasesEnabled => 'Consenti acquisti';

  @override
  String get purchasesInfo =>
      'Ogni acquisto richiede comunque la verifica genitore.';

  @override
  String get parentPrivacyTitle => 'Nessun dato personale raccolto';

  @override
  String get parentPrivacyBody =>
      'Nessun account, nessuna chat, nessuna pubblicità, nessun tracciamento. I progressi restano solo su questo dispositivo. Internet serve solo a Google Play per gli acquisti facoltativi.';

  @override
  String get resetProgress => 'Azzera tutti i progressi';

  @override
  String get resetConfirm =>
      'Cancella livelli, stelle e collezione su questo dispositivo. Gli acquisti si possono ripristinare dal negozio.';

  @override
  String get reset => 'Azzera';

  @override
  String get privacyText =>
      'MIXO: Color Rush — Informativa privacy (sintesi)\n\n• Non raccogliamo dati personali. Non ci sono account, email, nomi reali, posizione né ID pubblicitario.\n• Il soprannome è generato da una lista: nessuno può scrivere informazioni personali.\n• Non c\'è chat né comunicazione tra giocatori.\n• Non ci sono pubblicità né strumenti di analisi o tracciamento.\n• I progressi (livelli, stelle, impostazioni) sono salvati solo su questo dispositivo. Disinstallando l\'app vengono cancellati.\n• Gli acquisti facoltativi sono gestiti interamente da Google Play secondo l\'informativa di Google. Non riceviamo dati di pagamento.\n• Gli acquisti richiedono la verifica di un genitore e si possono disattivare nell\'area genitori.\n\nDomande: vedi l\'indirizzo email di contatto nella pagina Google Play dell\'app.';

  @override
  String get creditsText =>
      'MIXO: Color Rush\n\nGame design, codice, grafica, musica ed effetti sonori creati per questo progetto: ogni immagine è disegnata dal codice e ogni suono è sintetizzato da uno script incluso nel sorgente.\n\nRealizzato con Flutter e il motore Flame (open source, licenze BSD/MIT).\n\nGrazie per aver giocato!';
}
