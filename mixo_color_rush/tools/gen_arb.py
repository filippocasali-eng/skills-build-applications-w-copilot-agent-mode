#!/usr/bin/env python3
"""Writes lib/l10n/app_en.arb and app_it.arb from one table, so the two
languages can never drift apart. Run after editing STRINGS."""
import json
import os

# key: (english, italian, {placeholder: type})
STRINGS = {
    'appTitle': ('MIXO: Color Rush', 'MIXO: Color Rush', {}),
    'play': ('PLAY', 'GIOCA', {}),
    'again': ('AGAIN!', 'ANCORA!', {}),
    'home': ('Home', 'Home', {}),
    'score': ('Score', 'Punteggio', {}),
    'best': ('Best: {score}', 'Record: {score}', {'score': 'int'}),
    'newRecord': ('NEW RECORD!', 'NUOVO RECORD!', {}),
    'paused': ('Paused', 'Pausa', {}),
    'resume': ('Resume', 'Riprendi', {}),
    'pause': ('Pause', 'Pausa', {}),
    'cancel': ('Cancel', 'Annulla', {}),
    'loading': ('Loading…', 'Caricamento…', {}),
    'swipeHint': ('Swipe to change lane', 'Scorri per cambiare corsia', {}),
    'matchHint': ('Go through gates of YOUR colour!', 'Passa dalle porte del TUO colore!', {}),
    'onboardingHint': ('This is Mixo! Reach the gate of his colour.', 'Questo è Mixo! Raggiungi la porta del suo colore.', {}),
    'onboardingDone': ("You're ready. Let's run!", 'Sei pronto. Si corre!', {}),
    'bravo': ('Great!', 'Bravo!', {}),
    'hearts': ('Hearts: {count}', 'Cuori: {count}', {'count': 'int'}),
    'comboLabel': ('Combo x{multiplier}', 'Combo x{multiplier}', {'multiplier': 'int'}),
    'combo': ('COMBO', 'COMBO', {}),
    'nearMiss': ('CLOSE CALL!', 'PER UN PELO!', {}),
    'timeLabel': ('{seconds} s', '{seconds} s', {'seconds': 'int'}),
    'levelShort': ('Lv. {level}', 'Liv. {level}', {'level': 'int'}),
    'levelUp': ('LEVEL {level}!', 'LIVELLO {level}!', {'level': 'int'}),
    'newMechanic': ('NEW!', 'NOVITÀ!', {}),
    'mechDrops': ('Drops change your colour!', 'Le gocce cambiano il tuo colore!', {}),
    'mechObstacles': ('Dodge the blocks!', 'Evita i blocchi!', {}),
    'mechMixing': ('Colours MIX! Red + Blue = Purple', 'I colori si MESCOLANO! Rosso + Blu = Viola', {}),
    'mechSecondary': ('Mixed-colour gates!', 'Porte di colori misti!', {}),
    'mechSpecials': ('Special drops: White, Rainbow, Invert', 'Gocce speciali: Bianca, Arcobaleno, Inverti', {}),
    'mechFiveLanes': ('EXPERT: 5 lanes!', 'ESPERTO: 5 corsie!', {}),
    'mechJump': ('Tap to JUMP over low blocks', 'Tocca per SALTARE i blocchi bassi', {}),
    'mechDive': ('Swipe down to DIVE (bonus!)', 'Scorri giù per il TUFFO (bonus!)', {}),
    'tipMix': ('Remember this mix:', 'Ricorda questo mix:', {}),
    'tipBrown': ('Brown? Look for a white drop to clean Mixo!', 'Marrone? Cerca una goccia bianca per pulire Mixo!', {}),
    'tipSymbol': ("Look at Mixo's symbol and find the same gate.", 'Guarda il simbolo su Mixo e cerca la porta uguale.', {}),
    'tipDodge': ('Change lane early to dodge the blocks.', 'Cambia corsia presto per evitare i blocchi.', {}),
    'tipJump': ('Tap to jump over the low blocks.', 'Tocca per saltare i blocchi bassi.', {}),
    'tipLookAhead': ('Look far ahead: the gates come fast!', 'Guarda lontano: le porte arrivano veloci!', {}),
    'tipCombo': ('No mistakes for a while = combo x5!', 'Niente errori per un po\' = combo x5!', {}),
    'tipGreat': ('Amazing run! Can you go even faster?', 'Corsa fantastica! Riesci ad andare ancora più veloce?', {}),
    'missionDone': ('Mission complete', 'Missione completata', {}),
    'unlocked': ('Unlocked', 'Sbloccato', {}),
    'lessonComplete': ('LESSON COMPLETE!', 'LEZIONE COMPLETATA!', {}),
    'lessonFailed': ('Almost! Try again', 'Quasi! Riprova', {}),
    'ghostBeaten': ('YOU BEAT THE GHOST!', 'HAI BATTUTO IL FANTASMA!', {}),
    'ghostAhead': ('Ghost +{points}', 'Fantasma +{points}', {'points': 'int'}),
    'ghostBehind': ('You +{points}', 'Tu +{points}', {'points': 'int'}),
    'breakTitle': ('Great session! Take a break?', 'Ottima sessione! Fai una pausa?', {}),
    'breakBody': ('You have been playing for 30 minutes. Stretch, drink some water, look out of the window!', 'Giochi da 30 minuti. Sgranchisciti, bevi un po\' d\'acqua, guarda fuori dalla finestra!', {}),
    'takeBreak': ('Take a break', 'Faccio una pausa', {}),
    'keepPlaying': ('Keep playing', 'Continua a giocare', {}),
    'limitTitle': ("That's all for today!", 'Per oggi basta!', {}),
    'limitBody': ('Mixo is tired too. See you tomorrow!', 'Anche Mixo è stanco. Ci vediamo domani!', {}),
    'daily': ('Daily', 'Del Giorno', {}),
    'dailyInfo': ('The same track for everyone, all day long. Play it as many times as you like. Skipping a day is fine!', 'Una pista uguale per tutti, per tutto il giorno. Giocala quante volte vuoi. Se salti un giorno, nessun problema!', {}),
    'dailyBest': ("Today's best: {score}", 'Record di oggi: {score}', {'score': 'int'}),
    'dailyPlays': ('Runs today: {count}', 'Partite di oggi: {count}', {'count': 'int'}),
    'academy': ('Academy', 'Accademia', {}),
    'mandatory': ('to unlock modes', 'per sbloccare le modalità', {}),
    'lockedAcademyFirst': ('Complete the first 2 Academy lessons first!', 'Completa prima le prime 2 lezioni dell\'Accademia!', {}),
    'ghost': ('Ghost', 'Fantasma', {}),
    'ghostInfo': ('Race against your best run on the same track. Beat your ghost!', 'Gareggia contro la tua miglior corsa sulla stessa pista. Batti il tuo fantasma!', {}),
    'ghostBest': ('Ghost to beat: {score}', 'Fantasma da battere: {score}', {'score': 'int'}),
    'ghostNone': ('No ghost yet: your first run becomes the ghost!', 'Ancora nessun fantasma: la tua prima corsa diventa il fantasma!', {}),
    'collection': ('Collection', 'Collezione', {}),
    'skins': ('Mixo', 'Mixo', {}),
    'trails': ('Trails', 'Scie', {}),
    'themes': ('Worlds', 'Mondi', {}),
    'equip': ('Use', 'Usa', {}),
    'equipped': ('In use', 'In uso', {}),
    'inShop': ('Shop', 'Negozio', {}),
    'reachLevel': ('Reach level {level} to unlock it!', 'Raggiungi il livello {level} per sbloccarlo!', {'level': 'int'}),
    'findInShop': ('Available in the shop (ask a grown-up).', 'Disponibile nel negozio (chiedi a un adulto).', {}),
    'buyWithStars': ('Unlock for {price} stars?', 'Sbloccare per {price} stelle?', {'price': 'int'}),
    'unlock': ('Unlock', 'Sblocca', {}),
    'notEnoughStars': ('Not enough stars', 'Stelle insufficienti', {}),
    'missions': ('Missions', 'Missioni', {}),
    'missionsInfo': ('Complete a mission and a new one appears. No rush, no timers!', 'Completa una missione e ne arriva una nuova. Nessuna fretta, nessun timer!', {}),
    'trophies': ('Trophies', 'Trofei', {}),
    'stats': ('Stats', 'Statistiche', {}),
    'mColorGates': ('Pass {count} {color} gates', 'Passa {count} porte {color}', {'count': 'int', 'color': 'String'}),
    'mCombo': ('Reach a combo of {count}', 'Raggiungi una combo di {count}', {'count': 'int'}),
    'mSurvive': ('Run for {count} seconds', 'Corri per {count} secondi', {'count': 'int'}),
    'mScore': ('Score {count} points in one run', 'Fai {count} punti in una partita', {'count': 'int'}),
    'mDrops': ('Collect {count} drops', 'Raccogli {count} gocce', {'count': 'int'}),
    'mNearMiss': ('Make {count} close calls', 'Fai {count} "per un pelo"', {'count': 'int'}),
    'mRuns': ('Play {count} runs', 'Gioca {count} partite', {'count': 'int'}),
    'mMixGates': ('Pass {count} mixed-colour gates', 'Passa {count} porte di colori misti', {'count': 'int'}),
    'mJumps': ('Jump over {count} blocks', 'Salta {count} blocchi', {'count': 'int'}),
    'colorRed': ('red', 'rosse', {}),
    'colorYellow': ('yellow', 'gialle', {}),
    'colorBlue': ('blue', 'blu', {}),
    'colorOrange': ('orange', 'arancioni', {}),
    'colorGreen': ('green', 'verdi', {}),
    'colorPurple': ('purple', 'viola', {}),
    'colorBrown': ('brown', 'marroni', {}),
    'statBest': ('Best score', 'Record', {}),
    'statCombo': ('Best combo', 'Combo migliore', {}),
    'statLongest': ('Longest run', 'Corsa più lunga', {}),
    'statRuns': ('Runs played', 'Partite giocate', {}),
    'statTime': ('Total time', 'Tempo totale', {}),
    'statGates': ('Gates passed', 'Porte attraversate', {}),
    'statDrops': ('Drops collected', 'Gocce raccolte', {}),
    'statNearMiss': ('Close calls', 'Per un pelo', {}),
    'statMix': ('Mixed gates', 'Porte miste', {}),
    'statDaily': ('Daily challenges', 'Sfide del giorno', {}),
    'statColors': ('Gates by colour', 'Porte per colore', {}),
    'shop': ('Shop', 'Negozio', {}),
    'shopInfo': ('Only looks for Mixo: they never make the game easier. Real prices, no surprises.', 'Solo aspetti per Mixo: non rendono mai il gioco più facile. Prezzi reali, nessuna sorpresa.', {}),
    'packContains': ('This pack contains:', 'Questo pacchetto contiene:', {}),
    'buyFor': ('Buy for {price}', 'Acquista a {price}', {'price': 'String'}),
    'owned': ('Owned', 'Già tuo', {}),
    'priceUnavailable': ('Price unavailable', 'Prezzo non disponibile', {}),
    'storeUnavailable': ('The store is not available right now. The game works fine without it!', 'Il negozio ora non è disponibile. Il gioco funziona benissimo lo stesso!', {}),
    'purchasesDisabled': ('Purchases are turned off in the parent area.', 'Gli acquisti sono disattivati nell\'area genitori.', {}),
    'restorePurchases': ('Restore purchases', 'Ripristina acquisti', {}),
    'purchasePending': ('Purchase pending…', 'Acquisto in attesa…', {}),
    'purchaseDone': ('Thank you! Your items are in the Collection.', 'Grazie! Trovi gli oggetti nella Collezione.', {}),
    'purchasesRestored': ('Purchases restored.', 'Acquisti ripristinati.', {}),
    'purchaseError': ('Something went wrong. No money was taken.', 'Qualcosa è andato storto. Nessun addebito.', {}),
    'purchaseCancelled': ('Purchase cancelled.', 'Acquisto annullato.', {}),
    'settings': ('Settings', 'Impostazioni', {}),
    'sound': ('Sound effects', 'Effetti sonori', {}),
    'music': ('Music', 'Musica', {}),
    'vibration': ('Vibration', 'Vibrazione', {}),
    'symbolsAlways': ('Colour symbols always on', 'Simboli dei colori sempre visibili', {}),
    'reduceEffects': ('Calmer effects (no shake)', 'Effetti più calmi (niente scossoni)', {}),
    'controls': ('Controls', 'Controlli', {}),
    'controlSwipe': ('Swipe', 'Scorri', {}),
    'controlTap': ('Tap sides', 'Tocca i lati', {}),
    'language': ('Language', 'Lingua', {}),
    'languageSystem': ('Device', 'Dispositivo', {}),
    'parentArea': ('Parent area', 'Area genitori', {}),
    'privacy': ('Privacy policy', 'Informativa privacy', {}),
    'credits': ('Credits', 'Crediti', {}),
    'pickName': ('Pick your name', 'Scegli il tuo nome', {}),
    'gateTitle': ('Ask a grown-up', 'Chiedi a un adulto', {}),
    'gateHold': ('Grown-ups: hold the button for 3 seconds.', 'Adulti: tenete premuto il pulsante per 3 secondi.', {}),
    'gateWrong': ('Not quite. Try this one.', 'Non è giusto. Prova questa.', {}),
    'dailyLimit': ('Daily play limit', 'Limite di gioco giornaliero', {}),
    'playedToday': ('Played today: {minutes} min', 'Giocato oggi: {minutes} min', {'minutes': 'int'}),
    'noLimit': ('No limit', 'Nessun limite', {}),
    'extend15': ('+15 minutes today', '+15 minuti oggi', {}),
    'purchasesEnabled': ('Allow purchases', 'Consenti acquisti', {}),
    'purchasesInfo': ('Every purchase also asks for the parental check.', 'Ogni acquisto richiede comunque la verifica genitore.', {}),
    'parentPrivacyTitle': ('No personal data collected', 'Nessun dato personale raccolto', {}),
    'parentPrivacyBody': ('No account, no chat, no ads, no tracking. Progress stays on this device only. The internet is used only by Google Play for optional purchases.', 'Nessun account, nessuna chat, nessuna pubblicità, nessun tracciamento. I progressi restano solo su questo dispositivo. Internet serve solo a Google Play per gli acquisti facoltativi.', {}),
    'resetProgress': ('Reset all progress', 'Azzera tutti i progressi', {}),
    'resetConfirm': ('This deletes levels, stars and collection on this device. Purchases can be restored from the shop.', 'Cancella livelli, stelle e collezione su questo dispositivo. Gli acquisti si possono ripristinare dal negozio.', {}),
    'reset': ('Reset', 'Azzera', {}),
    'privacyText': (
        'MIXO: Color Rush — Privacy policy (summary)\n\n'
        '• We do not collect personal data. There are no accounts, no email, no real names, no location and no advertising ID.\n'
        '• Your nickname is generated from a list: nobody can type personal information.\n'
        '• There is no chat and no communication between players.\n'
        '• There are no ads and no analytics or tracking tools.\n'
        '• Game progress (levels, stars, settings) is saved only on this device. Uninstalling the app deletes it.\n'
        '• Optional purchases are handled entirely by Google Play under Google\'s privacy policy. We receive no payment details.\n'
        '• Purchases require a parental check and can be disabled in the parent area.\n\n'
        'Questions: see the contact e-mail on the Google Play page of the app.',
        'MIXO: Color Rush — Informativa privacy (sintesi)\n\n'
        '• Non raccogliamo dati personali. Non ci sono account, email, nomi reali, posizione né ID pubblicitario.\n'
        '• Il soprannome è generato da una lista: nessuno può scrivere informazioni personali.\n'
        '• Non c\'è chat né comunicazione tra giocatori.\n'
        '• Non ci sono pubblicità né strumenti di analisi o tracciamento.\n'
        '• I progressi (livelli, stelle, impostazioni) sono salvati solo su questo dispositivo. Disinstallando l\'app vengono cancellati.\n'
        '• Gli acquisti facoltativi sono gestiti interamente da Google Play secondo l\'informativa di Google. Non riceviamo dati di pagamento.\n'
        '• Gli acquisti richiedono la verifica di un genitore e si possono disattivare nell\'area genitori.\n\n'
        'Domande: vedi l\'indirizzo email di contatto nella pagina Google Play dell\'app.',
        {},
    ),
    'creditsText': (
        'MIXO: Color Rush\n\n'
        'Game design, code, graphics, music and sound effects created for this project: every image is drawn by code and every sound is synthesised by a script included in the source.\n\n'
        'Built with Flutter and the Flame engine (open source, BSD/MIT licences).\n\n'
        'Thank you for playing!',
        'MIXO: Color Rush\n\n'
        'Game design, codice, grafica, musica ed effetti sonori creati per questo progetto: ogni immagine è disegnata dal codice e ogni suono è sintetizzato da uno script incluso nel sorgente.\n\n'
        'Realizzato con Flutter e il motore Flame (open source, licenze BSD/MIT).\n\n'
        'Grazie per aver giocato!',
        {},
    ),
}


def main():
    root = os.path.join(os.path.dirname(__file__), '..', 'lib', 'l10n')
    en = {'@@locale': 'en'}
    it = {'@@locale': 'it'}
    for key, (e, i, ph) in STRINGS.items():
        en[key] = e
        it[key] = i
        if ph:
            en['@' + key] = {'placeholders': {k: {'type': t} for k, t in ph.items()}}
    for name, data in (('app_en.arb', en), ('app_it.arb', it)):
        with open(os.path.join(root, name), 'w', encoding='utf-8') as f:
            json.dump(data, f, ensure_ascii=False, indent=2)
            f.write('\n')
    print(f'{len(STRINGS)} strings written')


if __name__ == '__main__':
    main()
