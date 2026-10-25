import '../../game/sim/game_sim.dart';
import 'progress.dart';

/// A local achievement (mirrored to Play Games when available, v2).
class Trophy {
  const Trophy(this.id, this.it, this.en, this.descIt, this.descEn);

  final String id;
  final String it, en, descIt, descEn;

  String title(String lang) => lang == 'it' ? it : en;
  String desc(String lang) => lang == 'it' ? descIt : descEn;
}

typedef _Check = bool Function(Progress p, LevelResult? r, String? levelId);

class Trophies {
  static const all = <Trophy>[
    Trophy(
      'first_blood',
      'Primo Timbro',
      'First Stamp',
      'Completa un livello.',
      'Clear a level.',
    ),
    Trophy(
      'world1',
      'Cintura Allacciata',
      'Belt Buckled',
      'Completa il Mondo 1.',
      'Clear World 1.',
    ),
    Trophy(
      'world2',
      'Pizza Consegnata',
      'Pizza Delivered',
      'Completa il Mondo 2.',
      'Clear World 2.',
    ),
    Trophy(
      'world3',
      'Fine Pratica',
      'Case Closed',
      'Completa la campagna.',
      'Beat the campaign.',
    ),
    Trophy(
      'boss_stamper',
      'Respinto!',
      'Rejected!',
      'Batti il Timbratore Supremo.',
      'Beat the Supreme Stamper.',
    ),
    Trophy(
      'boss_washer',
      'Ciclo Delicati',
      'Delicate Cycle',
      'Batti la Lavatrice Cosmica.',
      'Beat the Cosmic Washer.',
    ),
    Trophy(
      'boss_emperor',
      'Abdicazione',
      'Abdication',
      "Batti l'Imperatore Glorbo.",
      'Beat Emperor Glorbo.',
    ),
    Trophy(
      'rank_s',
      'Voto S',
      'S Grade',
      'Ottieni un rank S.',
      'Get an S rank.',
    ),
    Trophy(
      'rank_s5',
      'Secchione Spaziale',
      'Space Nerd',
      'Ottieni 5 rank S.',
      'Get 5 S ranks.',
    ),
    Trophy(
      'no_death',
      'Intoccabile',
      'Untouchable',
      'Finisci un livello senza morire.',
      'Clear a level without dying.',
    ),
    Trophy(
      'all_hostages',
      'Nessuno Indietro',
      'Nobody Left Behind',
      'Salva tutti gli ostaggi di un livello.',
      'Rescue every hostage in a level.',
    ),
    Trophy(
      'speedrun',
      'Turbo',
      'Turbo',
      'Batti il tempo record di un livello.',
      'Beat a level par time.',
    ),
    Trophy(
      'tape_1',
      'Prima Cassetta',
      'First Tape',
      'Trova una musicassetta.',
      'Find a cassette.',
    ),
    Trophy(
      'tape_15',
      'Mixtape',
      'Mixtape',
      'Trova 15 musicassette.',
      'Find 15 cassettes.',
    ),
    Trophy(
      'tape_all',
      'Collezionista',
      'Collector',
      'Trova tutte le 36 musicassette.',
      'Find all 36 cassettes.',
    ),
    Trophy(
      'kills_100',
      'Cento Pratiche',
      'Hundred Forms',
      'Sconfiggi 100 nemici.',
      'Defeat 100 enemies.',
    ),
    Trophy(
      'kills_1000',
      'Ufficio Chiuso',
      'Office Closed',
      'Sconfiggi 1000 nemici.',
      'Defeat 1000 enemies.',
    ),
    Trophy(
      'hostages_25',
      'Taxi Spaziale',
      'Space Taxi',
      'Salva 25 ostaggi.',
      'Rescue 25 hostages.',
    ),
    Trophy(
      'score_50k',
      'Punteggio da Bar',
      'Arcade Score',
      'Fai 50.000 punti in un livello.',
      'Score 50,000 in one level.',
    ),
    Trophy(
      'score_100k',
      'Record del Bar',
      'Arcade Record',
      'Fai 100.000 punti in un livello.',
      'Score 100,000 in one level.',
    ),
    Trophy(
      'pilot_5',
      'Pilota Esperto',
      'Seasoned Pilot',
      'Raggiungi il grado pilota 5.',
      'Reach pilot rank 5.',
    ),
    Trophy(
      'pilot_10',
      'Asso dello Spazio',
      'Space Ace',
      'Raggiungi il grado pilota 10.',
      'Reach pilot rank 10.',
    ),
    Trophy(
      'hero_nyx',
      'Nuova Recluta',
      'New Recruit',
      'Sblocca Nyx.',
      'Unlock Nyx.',
    ),
    Trophy(
      'hero_doc',
      'Il Dottore è In',
      'The Doc Is In',
      'Sblocca Doc.',
      'Unlock Doc.',
    ),
    Trophy(
      'upgrade_1',
      'Officina Aperta',
      'Garage Open',
      "Compra una miglioria all'Officina.",
      'Buy a Workshop upgrade.',
    ),
    Trophy(
      'upgrade_max',
      'Tuning Totale',
      'Fully Tuned',
      'Porta una miglioria al massimo.',
      'Max out an upgrade.',
    ),
    Trophy(
      'arcade_clear',
      'Una Moneta Sola',
      'One Coin Clear',
      'Completa la modalità Arcade.',
      'Clear Arcade Mode.',
    ),
    Trophy(
      'bossrush_clear',
      'Maratona Boss',
      'Boss Marathon',
      'Completa il Boss Rush.',
      'Clear Boss Rush.',
    ),
    Trophy(
      'weekly',
      'Sfidante',
      'Challenger',
      'Completa una Sfida Settimanale.',
      'Finish a Weekly Challenge.',
    ),
    Trophy(
      'cheat',
      'Codice Segreto',
      'Secret Code',
      'Inserisci un codice segreto.',
      'Enter a secret code.',
    ),
    Trophy(
      'pong',
      'Vecchia Scuola',
      'Old School',
      'Gioca al cabinato segreto.',
      'Play the secret cabinet.',
    ),
    Trophy(
      'playtime_1h',
      'Ancora Una!',
      'One More Go!',
      'Gioca per un\'ora in totale.',
      'Play for an hour in total.',
    ),
  ];

  static Trophy byId(String id) => all.firstWhere((t) => t.id == id);

  static final Map<String, _Check> _checks = {
    'first_blood': (p, r, l) => p.stat('levels') >= 1,
    'world1': (p, r, l) => p.cleared('w1_l5'),
    'world2': (p, r, l) => p.cleared('w2_l5'),
    'world3': (p, r, l) => p.cleared('w3_l5'),
    'boss_stamper': (p, r, l) => p.cleared('w1_l5'),
    'boss_washer': (p, r, l) => p.cleared('w2_l5'),
    'boss_emperor': (p, r, l) => p.cleared('w3_l5'),
    'rank_s': (p, r, l) => p.stat('sRanks') >= 1,
    'rank_s5': (p, r, l) => p.stat('sRanks') >= 5,
    'no_death': (p, r, l) => r != null && r.deaths == 0,
    'all_hostages': (p, r, l) =>
        r != null && r.hostagesTotal > 0 && r.medalAllHostages,
    'speedrun': (p, r, l) => p.levels.values.any((x) => x.speedrun),
    'tape_1': (p, r, l) => p.totalCassettes >= 1,
    'tape_15': (p, r, l) => p.totalCassettes >= 15,
    'tape_all': (p, r, l) => p.totalCassettes >= 36,
    'kills_100': (p, r, l) => p.stat('kills') >= 100,
    'kills_1000': (p, r, l) => p.stat('kills') >= 1000,
    'hostages_25': (p, r, l) => p.stat('hostages') >= 25,
    'score_50k': (p, r, l) => r != null && r.total >= 50000,
    'score_100k': (p, r, l) => r != null && r.total >= 100000,
    'pilot_5': (p, r, l) => p.pilotRank >= 5,
    'pilot_10': (p, r, l) => p.pilotRank >= 10,
    'hero_nyx': (p, r, l) => p.heroes.contains('nyx'),
    'hero_doc': (p, r, l) => p.heroes.contains('doc'),
    'upgrade_1': (p, r, l) => p.upgrades.values.any((v) => v > 0),
    'upgrade_max': (p, r, l) => p.upgrades.values.any((v) => v >= 5),
    'playtime_1h': (p, r, l) => p.stat('playSeconds') >= 3600,
  };

  /// Trophies whose condition currently holds (owned or not).
  static List<Trophy> check(
    Progress p, {
    LevelResult? lastResult,
    String? levelId,
  }) => [
    for (final t in all)
      if (_checks[t.id]?.call(p, lastResult, levelId) ?? false) t,
  ];
}
