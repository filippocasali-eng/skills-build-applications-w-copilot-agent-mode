import '../core/models/achievements.dart';
import '../core/models/profile.dart';

/// Localized game content that is data-driven (items, trophies, lessons,
/// nickname parts). UI strings live in the ARB files.
class ContentText {
  ContentText(String languageCode) : _it = languageCode == 'it';

  final bool _it;

  static const _animalsIt = [
    'Volpe',
    'Tigre',
    'Panda',
    'Delfino',
    'Gufo',
    'Koala',
    'Lupo',
    'Pinguino',
    'Drago',
    'Gatto',
    'Riccio',
    'Polpo',
  ];
  static const _animalsEn = [
    'Fox',
    'Tiger',
    'Panda',
    'Dolphin',
    'Owl',
    'Koala',
    'Wolf',
    'Penguin',
    'Dragon',
    'Cat',
    'Hedgehog',
    'Octopus',
  ];
  static const _adjIt = [
    'Turbo',
    'Lampo',
    'Razzo',
    'Neon',
    'Laser',
    'Stella',
    'Arcobaleno',
    'Cometa',
    'Tuono',
    'Pixel',
    'Jet',
    'Zoom',
  ];
  static const _adjEn = [
    'Turbo',
    'Flash',
    'Rocket',
    'Neon',
    'Laser',
    'Star',
    'Rainbow',
    'Comet',
    'Thunder',
    'Pixel',
    'Jet',
    'Zoom',
  ];

  String nickname(Nickname n) {
    final a = (_it ? _animalsIt : _animalsEn)[n.animal % 12];
    final j = (_it ? _adjIt : _adjEn)[n.adjective % 12];
    return _it ? '$a $j ${n.number}' : '$j $a ${n.number}';
  }

  static const Map<String, (String, String)> _items = {
    'skin_classic': ('Mixo classico', 'Classic Mixo'),
    'skin_cap': ('Berretto', 'Cap'),
    'skin_bow': ('Fiocco', 'Bow'),
    'skin_glasses': ('Occhiali', 'Glasses'),
    'skin_flower': ('Fiore', 'Flower'),
    'skin_crown': ('Corona', 'Crown'),
    'skin_wizard': ('Mago', 'Wizard'),
    'skin_ninja': ('Ninja', 'Ninja'),
    'skin_headphones': ('Cuffie', 'Headphones'),
    'skin_antenna': ('Antenne', 'Antennae'),
    'skin_chef': ('Cuoco', 'Chef'),
    'skin_horns': ('Cornetti', 'Horns'),
    'skin_pirate': ('Pirata', 'Pirate'),
    'skin_halo': ('Aureola', 'Halo'),
    'skin_golden': ('Re d\'oro', 'Golden King'),
    'skin_astro': ('Astronauta', 'Astronaut'),
    'skin_dragon': ('Draghetto', 'Little Dragon'),
    'skin_dino': ('Dino', 'Dino'),
    'skin_stego': ('Stego', 'Stego'),
    'skin_alien': ('Alieno', 'Alien'),
    'skin_robot': ('Robot', 'Robot'),
    'skin_cupcake': ('Cupcake', 'Cupcake'),
    'skin_bunny': ('Coniglietto', 'Bunny'),
    'trail_none': ('Nessuna scia', 'No trail'),
    'trail_sparkle': ('Scintille', 'Sparkles'),
    'trail_bubbles': ('Bolle', 'Bubbles'),
    'trail_hearts': ('Cuoricini', 'Hearts'),
    'trail_fire': ('Fuoco', 'Fire'),
    'trail_stars': ('Stelline', 'Stars'),
    'trail_notes': ('Note', 'Notes'),
    'trail_rainbow': ('Arcobaleno', 'Rainbow'),
    'trail_leaves': ('Foglie', 'Leaves'),
    'trail_comet': ('Cometa', 'Comet'),
    'trail_candy': ('Confettini', 'Sprinkles'),
    'theme_space': ('Spazio', 'Space'),
    'theme_ocean': ('Oceano', 'Ocean'),
    'theme_forest': ('Foresta', 'Forest'),
    'theme_volcano': ('Vulcano', 'Volcano'),
    'theme_candy': ('Caramelle', 'Candy'),
    'theme_neon': ('Neon City', 'Neon City'),
    'theme_aurora': ('Aurora', 'Aurora'),
    'badge_supporter': ('Distintivo Sostenitore', 'Supporter badge'),
  };

  String item(String id) {
    final t = _items[id];
    if (t == null) return id;
    return _it ? t.$1 : t.$2;
  }

  static const Map<String, (String, String)> _products = {
    'mixo_supporter_pack': ('Pacchetto Sostenitore', 'Supporter Pack'),
    'mixo_pack_dino': ('Pacchetto Dino', 'Dino Pack'),
    'mixo_pack_space': ('Pacchetto Spazio', 'Space Pack'),
    'mixo_pack_sweet': ('Pacchetto Dolcetti', 'Sweet Pack'),
  };

  String product(String id) {
    final t = _products[id];
    if (t == null) return id;
    return _it ? t.$1 : t.$2;
  }

  static const Map<Achievement, (String, String, String, String)> _ach = {
    Achievement.firstRun: (
      'Prima corsa',
      'Gioca la tua prima partita',
      'First run',
      'Play your first game',
    ),
    Achievement.runs10: (
      'Corridore',
      'Gioca 10 partite',
      'Runner',
      'Play 10 games',
    ),
    Achievement.runs100: (
      'Instancabile',
      'Gioca 100 partite',
      'Tireless',
      'Play 100 games',
    ),
    Achievement.score1k: (
      'Mille!',
      'Fai 1.000 punti',
      'A thousand!',
      'Score 1,000 points',
    ),
    Achievement.score5k: (
      'Cinquemila',
      'Fai 5.000 punti',
      'Five thousand',
      'Score 5,000 points',
    ),
    Achievement.score10k: (
      'Diecimila',
      'Fai 10.000 punti',
      'Ten thousand',
      'Score 10,000 points',
    ),
    Achievement.score25k: (
      'Leggenda',
      'Fai 25.000 punti',
      'Legend',
      'Score 25,000 points',
    ),
    Achievement.comboX5: (
      'Combo x5',
      'Raggiungi la combo x5',
      'Combo x5',
      'Reach combo x5',
    ),
    Achievement.comboX8: (
      'Combo x8',
      'Raggiungi la combo x8',
      'Combo x8',
      'Reach combo x8',
    ),
    Achievement.survive60: (
      'Un minuto',
      'Corri per 60 secondi',
      'One minute',
      'Run for 60 seconds',
    ),
    Achievement.survive120: (
      'Due minuti',
      'Corri per 120 secondi',
      'Two minutes',
      'Run for 120 seconds',
    ),
    Achievement.survive180: (
      'Maratona',
      'Corri per 180 secondi',
      'Marathon',
      'Run for 180 seconds',
    ),
    Achievement.gates100: (
      '100 porte',
      'Attraversa 100 porte',
      '100 gates',
      'Go through 100 gates',
    ),
    Achievement.gates1000: (
      '1000 porte',
      'Attraversa 1.000 porte',
      '1000 gates',
      'Go through 1,000 gates',
    ),
    Achievement.firstMix: (
      'Piccolo pittore',
      'Passa la tua prima porta mista',
      'Little painter',
      'Pass your first mixed gate',
    ),
    Achievement.purple50: (
      'Re del viola',
      'Passa 50 porte viola',
      'Purple king',
      'Pass 50 purple gates',
    ),
    Achievement.allSecondaries: (
      'Tavolozza',
      'Passa porte arancioni, verdi e viola',
      'Palette',
      'Pass orange, green and purple gates',
    ),
    Achievement.nearMiss10: (
      'Per un pelo',
      'Fai 10 "per un pelo"',
      'Close call',
      'Make 10 near misses',
    ),
    Achievement.dailyFirst: (
      'Sfida accettata',
      'Gioca una Sfida del Giorno',
      'Challenge accepted',
      'Play a Daily Challenge',
    ),
    Achievement.daily7: (
      'Sfidante',
      'Gioca 7 Sfide del Giorno (quando vuoi)',
      'Challenger',
      'Play 7 Daily Challenges (any days)',
    ),
    Achievement.academyAll: (
      'Diplomato',
      'Completa tutta l\'Accademia',
      'Graduate',
      'Complete the whole Academy',
    ),
    Achievement.ghostBeaten: (
      'Acchiappafantasmi',
      'Batti il tuo fantasma',
      'Ghost buster',
      'Beat your ghost',
    ),
    Achievement.level5: (
      'Livello 5',
      'Raggiungi il livello 5',
      'Level 5',
      'Reach level 5',
    ),
    Achievement.level10: (
      'Livello 10',
      'Raggiungi il livello 10',
      'Level 10',
      'Reach level 10',
    ),
    Achievement.level20: (
      'Livello 20',
      'Raggiungi il livello 20',
      'Level 20',
      'Reach level 20',
    ),
    Achievement.collector5: (
      'Collezionista',
      'Sblocca 5 aspetti di Mixo',
      'Collector',
      'Unlock 5 Mixo looks',
    ),
  };

  String achievementTitle(Achievement a) => _it ? _ach[a]!.$1 : _ach[a]!.$3;
  String achievementDesc(Achievement a) => _it ? _ach[a]!.$2 : _ach[a]!.$4;

  static const _lessonsIt = [
    ('Il tuo colore', 'Passa dalle porte del colore di Mixo.'),
    ('Gocce di colore', 'Le gocce cambiano il colore di Mixo.'),
    ('Ostacoli', 'Cambia corsia per evitare i blocchi.'),
    (
      'Mescola!',
      'Rosso + Giallo = Arancione, Giallo + Blu = Verde, Rosso + Blu = Viola.',
    ),
    ('Porte miste', 'Prepara il colore giusto prima della porta.'),
    (
      'Marrone e Bianca',
      'Troppi colori fanno marrone: la goccia bianca ti pulisce.',
    ),
    (
      'Gocce speciali',
      'Arcobaleno: passi da tutte le porte. Inverti: colore opposto.',
    ),
    (
      'Salto e tuffo',
      'Tocca per saltare, scorri giù per il tuffo. Finale veloce!',
    ),
  ];
  static const _lessonsEn = [
    ('Your colour', 'Go through gates of Mixo\'s colour.'),
    ('Colour drops', 'Drops change Mixo\'s colour.'),
    ('Obstacles', 'Change lane to avoid the blocks.'),
    (
      'Mix it!',
      'Red + Yellow = Orange, Yellow + Blue = Green, Red + Blue = Purple.',
    ),
    ('Mixed gates', 'Make the right colour before the gate.'),
    (
      'Brown and White',
      'Too many colours make brown: the white drop cleans you.',
    ),
    ('Special drops', 'Rainbow: pass every gate. Invert: the opposite colour.'),
    ('Jump and dive', 'Tap to jump, swipe down to dive. Fast finale!'),
  ];

  String lessonTitle(int i) => (_it ? _lessonsIt : _lessonsEn)[i].$1;
  String lessonDesc(int i) => (_it ? _lessonsIt : _lessonsEn)[i].$2;
}
