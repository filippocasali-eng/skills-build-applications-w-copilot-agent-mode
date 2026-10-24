/// The playable characters and enemy troopers from the character pack
/// (art_source/characters). Atlas names match `assets/sprites/<id>.json`.
enum Hero {
  roxy('Roxy'),
  brutus('Brutus'),
  nyx('Nyx'),
  doc('Doc');

  const Hero(this.displayName);

  final String displayName;
  String get atlas => name;
}

enum EnemyKind {
  grunt('Grunt'),
  rocket('Rocket'),
  cyclops('Cyclops'),
  bulwark('Bulwark');

  const EnemyKind(this.displayName);

  final String displayName;
  String get atlas => name;
}

/// Animations every character atlas must provide.
const requiredCharacterAnimations = ['run', 'attack', 'idle', 'jump'];
