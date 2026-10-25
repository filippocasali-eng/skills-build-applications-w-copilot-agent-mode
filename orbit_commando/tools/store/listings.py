"""Google Play store listings (en-US first: the launch market; it-IT) -> fastlane/metadata/android.

    python3 tools/store/listings.py

Writes title.txt (<= 30 chars), short_description.txt (<= 80) and
full_description.txt (<= 4000) per locale, ready for `fastlane supply`
or copy-paste into Play Console. Limits are asserted.
"""
import os

LISTINGS = {
    "en-US": dict(
        title="Orbit Commando '94",
        short="90s run & gun on tiny planets. Beat your friends' scores!",
        full="""It's 1994 again. ORBIT COMMANDO '94 is a pixel-art run & gun where the ground is round.

GRAVITY IS ROUND
Run all the way around tiny planets, leap between gravity fields and float through zero-g. Every jump is a puzzle, every planet a new arena.

GO ORBITAL
Chain kills to climb the combo meter: GROOVY! RADICAL! TUBULAR! ...ORBITAL!! Every milestone freezes the action for a heartbeat. You will feel it.

CHALLENGE ANYONE
Finish a level and share your score card. It carries a challenge code: your friend plays exactly the same level, remix and seed, with your score to beat on screen. No account needed.

ORBIT OF THE DAY
One remixed level, the same for every player on Earth, new every day. Race the ghost of your best run.

A FULL CARTRIDGE OF CONTENT
- 15 levels across 3 worlds, 3 huge bosses (yes, one is a cosmic washing machine)
- 7 weapons, 3 vehicles: spring mech, rocket bike, shuttle
- Arcade mode, Boss Rush, weekly challenge
- 4 commandos, 12 enemy types, 32 trophies

PURE 90s
CRT filter, attract mode, secret codes, chiptune juke-box, collectible cassettes and a fake instruction manual full of bad advice.

FAIR TO PLAY
World 1 is free. The Full Cartridge unlocks the whole game and removes ads with a single purchase. Ranked modes never sell power. Optional purchases include random items; exact odds are shown in the game before you buy.

Plays offline. Made for controllers and touch.""",
    ),
    "it-IT": dict(
        title="Orbit Commando '94",
        short="Run & gun anni '90 sui pianeti. Batti i punteggi dei tuoi amici!",
        full="""Torna il 1994. ORBIT COMMANDO '94 è un run & gun in pixel art dove il pavimento è rotondo.

LA GRAVITÀ È ROTONDA
Corri tutto intorno a piccoli pianeti, salta da un campo gravitazionale all'altro e fluttua a gravità zero. Ogni salto è un enigma, ogni pianeta una nuova arena.

DIVENTA ORBITALE
Concatena le uccisioni e scala il combo: GROOVY! RADICAL! TUBULAR! ...ORBITAL!! A ogni traguardo l'azione si congela per un istante. Lo sentirai.

SFIDA CHIUNQUE
Finisci un livello e condividi la tua cartolina punteggio. Contiene un codice sfida: il tuo amico gioca esattamente lo stesso livello, remix e seed, con il tuo punteggio da battere sullo schermo. Nessun account richiesto.

ORBITA DEL GIORNO
Un livello remixato, uguale per tutti i giocatori della Terra, nuovo ogni giorno. Sfida il fantasma della tua run migliore.

UNA CARTUCCIA PIENA
- 15 livelli in 3 mondi, 3 boss enormi (sì, uno è una lavatrice cosmica)
- 7 armi, 3 veicoli: mech a molla, moto-razzo, navetta
- Modalità arcade, Boss Rush, sfida settimanale
- 4 commando, 12 tipi di nemici, 32 trofei

ANNI '90 PURI
Filtro CRT, attract mode, codici segreti, juke-box chiptune, cassette da collezionare e un finto manuale pieno di pessimi consigli.

GIUSTO
Il Mondo 1 è gratis. La Cartuccia Completa sblocca tutto il gioco e toglie la pubblicità con un solo acquisto. Le modalità classificate non vendono potenza. Gli acquisti facoltativi includono oggetti casuali: le probabilità esatte sono mostrate nel gioco prima dell'acquisto.

Si gioca offline. Pensato per controller e touch.""",
    ),
}


def main():
    root = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "fastlane", "metadata", "android")
    for loc, d in LISTINGS.items():
        assert len(d["title"]) <= 30, (loc, "title", len(d["title"]))
        assert len(d["short"]) <= 80, (loc, "short", len(d["short"]))
        assert len(d["full"]) <= 4000, (loc, "full", len(d["full"]))
        out = os.path.join(root, loc)
        os.makedirs(out, exist_ok=True)
        for name, key in (("title.txt", "title"), ("short_description.txt", "short"), ("full_description.txt", "full")):
            with open(os.path.join(out, name), "w", encoding="utf-8") as f:
                f.write(d[key].strip() + "\n")
        print(f"{loc}: short {len(d['short'])}/80, full {len(d['full'])}/4000")


if __name__ == "__main__":
    main()
