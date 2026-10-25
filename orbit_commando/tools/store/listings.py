"""Google Play store listings in 8 languages -> fastlane/metadata/android.

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
    "es-ES": dict(
        title="Orbit Commando '94",
        short="Run & gun de los 90 en planetas diminutos. ¡Supera a tus amigos!",
        full="""Vuelve 1994. ORBIT COMMANDO '94 es un run & gun en pixel art donde el suelo es redondo.

LA GRAVEDAD ES REDONDA
Corre alrededor de planetas diminutos, salta entre campos gravitatorios y flota en gravedad cero. Cada salto es un puzle, cada planeta una nueva arena.

HAZTE ORBITAL
Encadena bajas y sube el combo: GROOVY! RADICAL! TUBULAR! ...ORBITAL!! En cada hito la acción se congela un instante. Lo vas a sentir.

RETA A QUIEN QUIERAS
Termina un nivel y comparte tu tarjeta de puntuación. Lleva un código de reto: tu amigo juega exactamente el mismo nivel, remix y semilla, con tu puntuación a batir en pantalla. Sin cuenta.

ÓRBITA DEL DÍA
Un nivel remezclado, el mismo para todos los jugadores del planeta, nuevo cada día. Compite contra el fantasma de tu mejor partida.

UN CARTUCHO LLENO
- 15 niveles en 3 mundos, 3 jefes enormes (sí, uno es una lavadora cósmica)
- 7 armas, 3 vehículos: mech de muelles, moto-cohete, lanzadera
- Modo arcade, Boss Rush, reto semanal
- 4 comandos, 12 tipos de enemigos, 32 trofeos

PUROS 90
Filtro CRT, modo demo, códigos secretos, rocola chiptune, casetes coleccionables y un falso manual lleno de malos consejos.

JUSTO
El Mundo 1 es gratis. El Cartucho Completo desbloquea todo el juego y quita los anuncios con una sola compra. Los modos clasificatorios nunca venden poder. Las compras opcionales incluyen objetos aleatorios: las probabilidades exactas se muestran en el juego antes de comprar.

Se juega sin conexión.""",
    ),
    "pt-BR": dict(
        title="Orbit Commando '94",
        short="Run & gun anos 90 em planetinhas. Supere a pontuação dos amigos!",
        full="""1994 está de volta. ORBIT COMMANDO '94 é um run & gun em pixel art onde o chão é redondo.

A GRAVIDADE É REDONDA
Corra ao redor de planetinhas, pule entre campos gravitacionais e flutue em gravidade zero. Cada pulo é um quebra-cabeça, cada planeta uma nova arena.

FIQUE ORBITAL
Encadeie abates e suba o combo: GROOVY! RADICAL! TUBULAR! ...ORBITAL!! A cada marco a ação congela por um instante. Você vai sentir.

DESAFIE QUALQUER UM
Termine uma fase e compartilhe seu cartão de pontuação. Ele traz um código de desafio: seu amigo joga exatamente a mesma fase, remix e seed, com sua pontuação para superar na tela. Sem conta.

ÓRBITA DO DIA
Uma fase remixada, igual para todos os jogadores do planeta, nova todo dia. Corra contra o fantasma da sua melhor partida.

UM CARTUCHO CHEIO
- 15 fases em 3 mundos, 3 chefes gigantes (sim, um é uma máquina de lavar cósmica)
- 7 armas, 3 veículos: mech de mola, moto-foguete, nave
- Modo arcade, Boss Rush, desafio semanal
- 4 comandos, 12 tipos de inimigos, 32 troféus

ANOS 90 RAIZ
Filtro CRT, modo demonstração, códigos secretos, jukebox chiptune, fitas colecionáveis e um manual falso cheio de péssimos conselhos.

JUSTO
O Mundo 1 é grátis. O Cartucho Completo libera o jogo inteiro e tira os anúncios com uma única compra. Os modos ranqueados nunca vendem poder. As compras opcionais incluem itens aleatórios: as chances exatas aparecem no jogo antes da compra.

Funciona offline.""",
    ),
    "fr-FR": dict(
        title="Orbit Commando '94",
        short="Run & gun années 90 sur des mini-planètes. Bats tes amis !",
        full="""Retour en 1994. ORBIT COMMANDO '94 est un run & gun en pixel art où le sol est rond.

LA GRAVITÉ EST RONDE
Cours tout autour de mini-planètes, saute d'un champ gravitationnel à l'autre et flotte en apesanteur. Chaque saut est une énigme, chaque planète une nouvelle arène.

PASSE EN ORBITE
Enchaîne les ennemis et fais grimper le combo : GROOVY! RADICAL! TUBULAR! ...ORBITAL!! À chaque palier, l'action se fige un instant. Tu vas le sentir.

DÉFIE QUI TU VEUX
Termine un niveau et partage ta carte de score. Elle contient un code de défi : ton ami joue exactement le même niveau, le même remix et la même seed, avec ton score à battre à l'écran. Sans compte.

ORBITE DU JOUR
Un niveau remixé, le même pour tous les joueurs de la planète, nouveau chaque jour. Affronte le fantôme de ta meilleure partie.

UNE CARTOUCHE BIEN REMPLIE
- 15 niveaux dans 3 mondes, 3 boss énormes (oui, l'un d'eux est une machine à laver cosmique)
- 7 armes, 3 véhicules : mech à ressort, moto-fusée, navette
- Mode arcade, Boss Rush, défi de la semaine
- 4 commandos, 12 types d'ennemis, 32 trophées

100 % ANNÉES 90
Filtre CRT, mode démo, codes secrets, juke-box chiptune, cassettes à collectionner et un faux manuel plein de mauvais conseils.

ÉQUITABLE
Le Monde 1 est gratuit. La Cartouche Complète débloque tout le jeu et retire les pubs en un seul achat. Les modes classés ne vendent jamais de puissance. Les achats facultatifs incluent des objets aléatoires : les probabilités exactes sont affichées dans le jeu avant l'achat.

Jouable hors ligne.""",
    ),
    "de-DE": dict(
        title="Orbit Commando '94",
        short="90er Run & Gun auf Mini-Planeten. Schlag die Punkte deiner Freunde!",
        full="""1994 ist zurück. ORBIT COMMANDO '94 ist ein Pixel-Art Run & Gun, in dem der Boden rund ist.

DIE SCHWERKRAFT IST RUND
Renn einmal um winzige Planeten, spring zwischen Schwerefeldern und schwebe durch die Schwerelosigkeit. Jeder Sprung ist ein Rätsel, jeder Planet eine neue Arena.

WERDE ORBITAL
Verkette Abschüsse und treib die Combo hoch: GROOVY! RADICAL! TUBULAR! ...ORBITAL!! Bei jedem Meilenstein friert die Action für einen Herzschlag ein. Du wirst es spüren.

FORDERE JEDEN HERAUS
Schließ ein Level ab und teile deine Punktekarte. Sie enthält einen Challenge-Code: Dein Freund spielt genau dasselbe Level mit demselben Remix und Seed, deine Punktzahl als Ziel auf dem Bildschirm. Kein Konto nötig.

ORBIT DES TAGES
Ein Remix-Level, gleich für alle Spieler der Erde, jeden Tag neu. Tritt gegen den Geist deines besten Laufs an.

EIN VOLLES MODUL
- 15 Level in 3 Welten, 3 riesige Bosse (ja, einer ist eine kosmische Waschmaschine)
- 7 Waffen, 3 Fahrzeuge: Sprungfeder-Mech, Raketen-Bike, Shuttle
- Arcade-Modus, Boss Rush, Wochen-Challenge
- 4 Kommandos, 12 Gegnertypen, 32 Trophäen

PURE 90ER
CRT-Filter, Demo-Modus, Geheimcodes, Chiptune-Jukebox, sammelbare Kassetten und ein falsches Handbuch voller schlechter Tipps.

FAIR
Welt 1 ist gratis. Das Komplette Modul schaltet das ganze Spiel frei und entfernt die Werbung mit einem einzigen Kauf. Ranglisten-Modi verkaufen nie Stärke. Optionale Käufe enthalten Zufallsgegenstände; die genauen Chancen werden vor dem Kauf im Spiel angezeigt.

Offline spielbar.""",
    ),
    "tr-TR": dict(
        title="Orbit Commando '94",
        short="Minik gezegenlerde 90'lar run & gun. Arkadaşlarının skorunu geç!",
        full="""1994 geri döndü. ORBIT COMMANDO '94, zeminin yuvarlak olduğu piksel sanatlı bir run & gun oyunu.

YERÇEKİMİ YUVARLAK
Minik gezegenlerin etrafında koş, yerçekimi alanları arasında zıpla ve sıfır yerçekiminde süzül. Her zıplama bir bulmaca, her gezegen yeni bir arena.

YÖRÜNGEYE ÇIK
Düşmanları art arda indir ve komboyu yükselt: GROOVY! RADICAL! TUBULAR! ...ORBITAL!! Her eşikte aksiyon bir anlığına donar. Hissedeceksin.

HERKESE MEYDAN OKU
Bir bölümü bitir ve skor kartını paylaş. Kartta bir meydan okuma kodu var: arkadaşın aynı bölümü, aynı remix ve aynı seed ile oynar, geçmesi gereken skor ekranda yazar. Hesap gerekmez.

GÜNÜN YÖRÜNGESİ
Dünyadaki tüm oyuncular için aynı, her gün yenilenen bir remix bölüm. En iyi koşunun hayaletiyle yarış.

DOLU BİR KARTUŞ
- 3 dünyada 15 bölüm, 3 dev boss (evet, biri kozmik bir çamaşır makinesi)
- 7 silah, 3 araç: yaylı mech, roket motor, mekik
- Atari modu, Boss Rush, haftalık meydan okuma
- 4 komando, 12 düşman türü, 32 kupa

SAF 90'LAR
CRT filtresi, demo modu, gizli kodlar, chiptune müzik kutusu, toplanabilir kasetler ve kötü tavsiyelerle dolu sahte bir kılavuz.

ADİL
Dünya 1 ücretsiz. Tam Kartuş tek bir satın alımla tüm oyunu açar ve reklamları kaldırır. Dereceli modlar asla güç satmaz. İsteğe bağlı satın alımlar rastgele öğeler içerir; kesin olasılıklar satın almadan önce oyunda gösterilir.

Çevrim dışı oynanır.""",
    ),
    "id": dict(
        title="Orbit Commando '94",
        short="Run & gun ala 90-an di planet mungil. Kalahkan skor temanmu!",
        full="""1994 kembali. ORBIT COMMANDO '94 adalah run & gun pixel art di mana tanahnya bulat.

GRAVITASINYA BULAT
Berlari mengelilingi planet mungil, melompat antar medan gravitasi, dan melayang di nol gravitasi. Setiap lompatan adalah teka-teki, setiap planet arena baru.

JADI ORBITAL
Rangkai kill dan naikkan kombo: GROOVY! RADICAL! TUBULAR! ...ORBITAL!! Di setiap pencapaian aksi membeku sesaat. Kamu akan merasakannya.

TANTANG SIAPA SAJA
Selesaikan level dan bagikan kartu skormu. Kartu itu membawa kode tantangan: temanmu memainkan level, remix, dan seed yang sama persis, dengan skormu sebagai target di layar. Tanpa akun.

ORBIT HARI INI
Satu level remix, sama untuk semua pemain di Bumi, baru setiap hari. Balapan melawan hantu permainan terbaikmu.

SATU KASET PENUH
- 15 level di 3 dunia, 3 bos raksasa (ya, salah satunya mesin cuci kosmik)
- 7 senjata, 3 kendaraan: mech pegas, motor roket, pesawat ulang-alik
- Mode arcade, Boss Rush, tantangan mingguan
- 4 komando, 12 jenis musuh, 32 trofi

90-AN MURNI
Filter CRT, mode demo, kode rahasia, jukebox chiptune, kaset koleksi, dan buku manual palsu penuh saran buruk.

ADIL
Dunia 1 gratis. Kaset Lengkap membuka seluruh game dan menghapus iklan dengan satu kali beli. Mode peringkat tidak pernah menjual kekuatan. Pembelian opsional berisi item acak; peluang pastinya ditampilkan di game sebelum membeli.

Bisa dimainkan offline.""",
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
