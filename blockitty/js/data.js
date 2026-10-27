// Static catalog: cats, cosmetics, sets, economy tables.

export const RARITIES = {
  common: { name: 'Common', color: '#9aa5b1', rate: 55, yarn: 5 },
  rare: { name: 'Rare', color: '#3b9cff', rate: 30, yarn: 15 },
  epic: { name: 'Epic', color: '#b05cff', rate: 11, yarn: 40 },
  legendary: { name: 'Legendary', color: '#ffb000', rate: 3.5, yarn: 120 },
  mythic: { name: 'Mythic', color: '#ff3d7f', rate: 0.5, yarn: 300 },
};
export const RARITY_ORDER = ['common', 'rare', 'epic', 'legendary', 'mythic'];

// Cat look: fur, fur2 (pattern color), pattern, eyes, acc
const cat = (id, name, rarity, set, fur, fur2, pattern, eyes, acc, extra = {}) => ({
  type: 'cat', id, name, rarity, set, look: { fur, fur2, pattern, eyes, acc }, ...extra,
});

export const CATS = [
  cat('mochi', 'Mochi', 'common', 'street', '#f6a04d', '#d9772a', 'tabby', '#3aa655', 'none'),
  cat('pepper', 'Pepper', 'common', 'street', '#2f2f3a', '#1d1d26', 'solid', '#f2c230', 'none'),
  cat('biscuit', 'Biscuit', 'common', 'street', '#f3dcb2', '#e0bd85', 'tabby', '#5a8dee', 'none'),
  cat('smokey', 'Smokey', 'rare', 'street', '#8c93a3', '#6b7180', 'tabby', '#f2c230', 'bandana'),
  cat('socks', 'Socks', 'rare', 'street', '#26262e', '#ffffff', 'tux', '#7bd36b', 'bow'),

  cat('duchess', 'Duchess', 'rare', 'fancy', '#fbf7f2', '#efe4d8', 'solid', '#4fa3ff', 'bow'),
  cat('earl', 'Earl Grey', 'rare', 'fancy', '#9aa0ad', '#7b8190', 'solid', '#e8a33a', 'glasses'),
  cat('tiara', 'Tiara', 'epic', 'fancy', '#fff4e6', '#f08a2c', 'calico', '#3aa655', 'crown'),
  cat('velvet', 'Velvet', 'epic', 'fancy', '#f1e3cf', '#5a4033', 'siamese', '#4fa3ff', 'flower'),
  cat('whiskers', 'Sir Whiskers', 'legendary', 'fancy', '#22222a', '#ffffff', 'tux', '#f2c230', 'tophat'),

  cat('sushi', 'Sushi', 'common', 'snack', '#fff4e6', '#f08a2c', 'calico', '#7a5230', 'bandana'),
  cat('nugget', 'Nugget', 'common', 'snack', '#f2b84b', '#d48d1f', 'solid', '#3aa655', 'none'),
  cat('boba', 'Boba', 'rare', 'snack', '#8a5a3c', '#5e3a24', 'spots', '#f2c230', 'none'),
  cat('waffle', 'Waffle', 'rare', 'snack', '#f0c987', '#c99545', 'tabby', '#7a5230', 'bow'),
  cat('cupcake', 'Cupcake', 'epic', 'snack', '#ffb6d2', '#ff7fb0', 'spots', '#7a3cff', 'bow'),

  cat('riff', 'Riff', 'rare', 'rock', '#1f1f27', '#3a3a48', 'solid', '#ff4d6d', 'headphones'),
  cat('drummer', 'Drummer', 'rare', 'rock', '#f39a3d', '#3a2a1a', 'tiger', '#3aa655', 'bandana'),
  cat('glam', 'Glam', 'epic', 'rock', '#b57cff', '#8a4fe0', 'spots', '#ffe14d', 'glasses'),
  cat('diva', 'Diva', 'epic', 'rock', '#ffffff', '#ffc1dc', 'solid', '#ff4da6', 'crown'),
  cat('amp', 'Amp', 'legendary', 'rock', '#38e07b', '#13a24f', 'tiger', '#1f1f27', 'headphones'),

  cat('frost', 'Frost', 'rare', 'mystic', '#bfe6ff', '#86c7f2', 'tabby', '#2a6bd1', 'none'),
  cat('ember', 'Ember', 'epic', 'mystic', '#ff5a36', '#b8240f', 'tiger', '#ffe14d', 'horns'),
  cat('luna', 'Luna', 'epic', 'mystic', '#3b2a6b', '#9b7bff', 'galaxy', '#bfe6ff', 'halo'),
  cat('merlin', 'Merlin', 'legendary', 'mystic', '#5a7dff', '#2b47c7', 'spots', '#ffe14d', 'wizard'),
  cat('zodiac', 'Zodiac', 'mythic', 'mystic', '#1c1440', '#ff7ad9', 'galaxy', '#ffe14d', 'crown'),

  cat('orbit', 'Orbit', 'rare', 'space', '#a7adbb', '#7f8696', 'solid', '#4fa3ff', 'astronaut'),
  cat('comet', 'Comet', 'rare', 'space', '#6fa8ff', '#3f73cc', 'tabby', '#ffe14d', 'glasses'),
  cat('cosmo', 'Cosmo', 'epic', 'space', '#ffffff', '#d8dce6', 'solid', '#3aa655', 'astronaut'),
  cat('nova', 'Nova', 'legendary', 'space', '#ffd34d', '#f0a500', 'tabby', '#ff4d6d', 'halo'),
  cat('nebula', 'Nebula', 'mythic', 'space', '#2a1a5e', '#3ee8ff', 'galaxy', '#ff7ad9', 'wizard'),

  // Exclusives (not in boxes)
  cat('lucky', 'Lucky', 'epic', 'exclusive', '#ffe08a', '#e8a33a', 'calico', '#3aa655', 'crown', { exclusive: 'starter' }),
  cat('ninja', 'Ninja', 'epic', 'exclusive', '#16161c', '#c0263b', 'solid', '#ffe14d', 'bandana', { exclusive: 'pass' }),
  cat('captain', 'Captain Purr', 'legendary', 'exclusive', '#f3f3f3', '#22222a', 'tux', '#4fa3ff', 'tophat', { exclusive: 'pass' }),
];

export const SETS = [
  { id: 'street', name: 'Street Squad', reward: { coins: 1500, gems: 50 } },
  { id: 'fancy', name: 'Fancy Felines', reward: { coins: 3000, gems: 150 } },
  { id: 'snack', name: 'Snack Attack', reward: { coins: 2000, gems: 80 } },
  { id: 'rock', name: 'Rock Cats', reward: { coins: 3000, gems: 150 } },
  { id: 'mystic', name: 'Mystic Meows', reward: { coins: 5000, gems: 300 } },
  { id: 'space', name: 'Space Paws', reward: { coins: 5000, gems: 300 } },
];

// Block skins. Palettes are 7 colors used for piece colors 1..7.
export const SKINS = [
  { type: 'skin', id: 'classic', name: 'Classic', rarity: 'common', style: 'bevel', palette: ['#ff5a5f', '#ffb400', '#ffe14d', '#3ddc84', '#2bb5ff', '#7a5cff', '#ff7ad9'] },
  { type: 'skin', id: 'pastel', name: 'Pastel Dream', rarity: 'common', style: 'flat', palette: ['#ffb3ba', '#ffdfba', '#fff6a8', '#baffc9', '#bae1ff', '#d5baff', '#ffc8f0'] },
  { type: 'skin', id: 'candy', name: 'Candy Gloss', rarity: 'rare', style: 'gloss', palette: ['#ff3b6b', '#ff9a1f', '#ffd400', '#1fe07a', '#18b7ff', '#8f5bff', '#ff5ce1'] },
  { type: 'skin', id: 'pixel', name: '8-Bit', rarity: 'rare', style: 'pixel', palette: ['#e43b44', '#f77622', '#feae34', '#63c74d', '#0099db', '#68386c', '#f6757a'] },
  { type: 'skin', id: 'neon', name: 'Neon Nights', rarity: 'epic', style: 'neon', palette: ['#ff2e63', '#ff9f1c', '#f9f871', '#08f7fe', '#09fbd3', '#a16ae8', '#fe53bb'] },
  { type: 'skin', id: 'jelly', name: 'Jelly Jam', rarity: 'epic', style: 'jelly', palette: ['#ff4f81', '#ff9f43', '#feca57', '#1dd1a1', '#54a0ff', '#5f27cd', '#ff9ff3'] },
  { type: 'skin', id: 'paw', name: 'Paw Prints', rarity: 'epic', style: 'paw', palette: ['#ff6b6b', '#ffa94d', '#ffd43b', '#69db7c', '#4dabf7', '#9775fa', '#f783ac'] },
  { type: 'skin', id: 'galaxy', name: 'Galaxy', rarity: 'legendary', style: 'galaxy', palette: ['#ff4d8d', '#ff8a3d', '#ffd23f', '#3dffb4', '#3dc5ff', '#8a5cff', '#ff5cf0'] },
  { type: 'skin', id: 'gold', name: '24K Gold', rarity: 'legendary', style: 'metal', palette: ['#ffd700', '#f5c542', '#ffe680', '#e6b422', '#fff1a8', '#d4a017', '#ffcf40'] },
  { type: 'skin', id: 'gem', name: 'Crystal Gems', rarity: 'mythic', style: 'gem', palette: ['#ff1f5a', '#ff7b00', '#ffe600', '#00e676', '#00b0ff', '#7c4dff', '#ff40c4'] },
  { type: 'skin', id: 'fishy', name: 'Fishy Business', rarity: 'legendary', style: 'fish', palette: ['#ff7a7a', '#ffb36b', '#ffe07a', '#7af0b0', '#7ad3ff', '#a98bff', '#ff9bd9'], exclusive: 'pass' },
];

export const THEMES = [
  { type: 'theme', id: 'cozy', name: 'Cozy Home', rarity: 'common', bg: 'linear-gradient(160deg,#ffcf9f 0%,#ff9a8b 55%,#ff6a88 100%)', board: '#3b2440', cell: '#4e3255' },
  { type: 'theme', id: 'midnight', name: 'Midnight', rarity: 'rare', bg: 'linear-gradient(160deg,#141e30 0%,#243b55 100%)', board: '#0e1626', cell: '#1a2538' },
  { type: 'theme', id: 'sakura', name: 'Sakura', rarity: 'rare', bg: 'linear-gradient(160deg,#fbd3e9 0%,#f6a5c0 50%,#bb377d 100%)', board: '#5b2140', cell: '#74304f' },
  { type: 'theme', id: 'ocean', name: 'Deep Ocean', rarity: 'epic', bg: 'linear-gradient(180deg,#2bc0e4 0%,#1b6dbf 50%,#0b2a5b 100%)', board: '#0a2247', cell: '#123264' },
  { type: 'theme', id: 'arcade', name: 'Arcade', rarity: 'epic', bg: 'repeating-linear-gradient(0deg,#120024 0 22px,#1d0040 22px 24px),#120024', board: '#07000f', cell: '#1a0833' },
  { type: 'theme', id: 'space', name: 'Outer Space', rarity: 'legendary', bg: 'radial-gradient(ellipse at 30% 20%,#5b2a86 0%,#1b0f3b 45%,#05030f 100%)', board: '#0b0720', cell: '#1a1240' },
  { type: 'theme', id: 'candyland', name: 'Candyland', rarity: 'legendary', bg: 'repeating-linear-gradient(45deg,#ffd1e8 0 26px,#ffe9f4 26px 52px)', board: '#7a2e5a', cell: '#94406f' },
  { type: 'theme', id: 'royal', name: 'Royal Palace', rarity: 'mythic', bg: 'radial-gradient(circle at 50% 0%,#ffe9a8 0%,#d4a017 35%,#5a2d0c 100%)', board: '#3a1f08', cell: '#55300f', exclusive: 'pass' },
];

export const EFFECTS = [
  { type: 'fx', id: 'sparkle', name: 'Sparkles', rarity: 'common' },
  { type: 'fx', id: 'confetti', name: 'Confetti', rarity: 'rare' },
  { type: 'fx', id: 'hearts', name: 'Lovestruck', rarity: 'rare' },
  { type: 'fx', id: 'paws', name: 'Paw Party', rarity: 'epic' },
  { type: 'fx', id: 'fish', name: 'Fish Rain', rarity: 'epic' },
  { type: 'fx', id: 'stars', name: 'Starburst', rarity: 'legendary' },
  { type: 'fx', id: 'bubbles', name: 'Bubble Pop', rarity: 'rare' },
  { type: 'fx', id: 'rainbow', name: 'Rainbow Blast', rarity: 'mythic', exclusive: 'pass' },
];

export const ALL_ITEMS = [...CATS, ...SKINS, ...THEMES, ...EFFECTS];
export const ITEM_BY_KEY = Object.fromEntries(ALL_ITEMS.map((i) => [`${i.type}:${i.id}`, i]));
export const itemKey = (i) => `${i.type}:${i.id}`;

export const DEFAULTS = { cat: 'mochi', skin: 'classic', theme: 'cozy', fx: 'sparkle' };

// Box (gacha) definitions
export const BOXES = {
  basic: { id: 'basic', name: 'Cardboard Box', currency: 'coins', price: 1500, rates: { common: 70, rare: 27, epic: 3, legendary: 0, mythic: 0 } },
  premium: { id: 'premium', name: 'Mystery Litter Box', currency: 'gems', price: 100, price10: 900 },
};
export const PITY_EPIC = 10;
export const PITY_LEGENDARY = 60;

// Shop prices for direct purchases (mythics are box-only)
export const SHOP_PRICES = {
  common: { coins: 800 },
  rare: { coins: 2500 },
  epic: { gems: 320 },
  legendary: { gems: 880 },
};

export const POWERUPS = {
  hammer: { name: 'Hammer', icon: '🔨', desc: 'Smash one block', coins: 400 },
  bomb: { name: 'Bomb', icon: '💣', desc: 'Clear a 3×3 area', coins: 900 },
  shuffle: { name: 'Shuffle', icon: '🔄', desc: 'New set of pieces', coins: 600 },
};

// Real-money products (Google Play Billing SKUs).
export const GEM_PACKS = [
  { sku: 'gems_80', gems: 80, price: '$0.99', label: 'Handful' },
  { sku: 'gems_500', gems: 500, bonus: 50, price: '$4.99', label: 'Pouch', tag: 'Popular' },
  { sku: 'gems_1200', gems: 1200, bonus: 200, price: '$9.99', label: 'Chest' },
  { sku: 'gems_2600', gems: 2600, bonus: 600, price: '$19.99', label: 'Vault', tag: 'Best Value' },
  { sku: 'gems_7000', gems: 7000, bonus: 2000, price: '$49.99', label: 'Cat Castle' },
];
export const STARTER_PACK = { sku: 'starter_pack', price: '$2.99', gems: 500, coins: 5000, cat: 'lucky', skin: 'candy', worth: '$14.99' };
export const PASS_PRICE_GEMS = 950;

export const LOGIN_REWARDS = [
  { coins: 200 },
  { gems: 20 },
  { coins: 500 },
  { hammer: 2, bomb: 1 },
  { gems: 40 },
  { coins: 1000, shuffle: 2 },
  { gems: 100, freePulls: 1 },
];

export const SPIN_SEGMENTS = [
  { label: '100', icon: '🪙', reward: { coins: 100 }, w: 24 },
  { label: '10', icon: '💎', reward: { gems: 10 }, w: 16 },
  { label: '300', icon: '🪙', reward: { coins: 300 }, w: 18 },
  { label: '🔨', icon: '', reward: { hammer: 1 }, w: 12 },
  { label: '750', icon: '🪙', reward: { coins: 750 }, w: 10 },
  { label: '30', icon: '💎', reward: { gems: 30 }, w: 8 },
  { label: '💣', icon: '', reward: { bomb: 1 }, w: 8 },
  { label: '100', icon: '💎', reward: { gems: 100 }, w: 4 },
];

export const MISSION_POOL = [
  { id: 'play', text: 'Play {n} games', stat: 'games', n: 3, reward: { coins: 300 } },
  { id: 'lines', text: 'Clear {n} lines', stat: 'lines', n: 25, reward: { coins: 400 } },
  { id: 'blocks', text: 'Place {n} blocks', stat: 'pieces', n: 60, reward: { coins: 300 } },
  { id: 'score', text: 'Score {n} in one game', stat: 'bestGame', n: 2000, reward: { gems: 15 } },
  { id: 'combo', text: 'Reach a x{n} combo', stat: 'bestCombo', n: 4, reward: { gems: 15 } },
  { id: 'power', text: 'Use {n} power-ups', stat: 'powers', n: 2, reward: { coins: 300 } },
  { id: 'multi', text: 'Clear 3+ lines at once {n} times', stat: 'multis', n: 2, reward: { gems: 20 } },
  { id: 'box', text: 'Open {n} box', stat: 'boxes', n: 1, reward: { coins: 500 } },
];
export const MISSION_XP = 150;

export const PASS_TIERS = 30;
export const PASS_XP_PER_TIER = 250;
export const SEASON_DAYS = 28;
export const SEASON_EPOCH = Date.UTC(2026, 0, 5);

// Pass reward tables. Premium returns more gems than it costs over the season.
export const PASS_FREE = (tier) => {
  if (tier % 10 === 0) return { freePulls: 1 };
  if (tier % 5 === 0) return { gems: 30 };
  if (tier % 3 === 0) return { hammer: 1 };
  return { coins: 150 + tier * 10 };
};
export const PASS_PREMIUM = (tier) => {
  const special = {
    1: { item: 'cat:ninja' },
    5: { item: 'fx:rainbow' },
    10: { item: 'skin:fishy' },
    15: { freePulls: 3 },
    20: { item: 'theme:royal' },
    25: { freePulls: 5 },
    30: { item: 'cat:captain' },
  };
  if (special[tier]) return special[tier];
  if (tier % 2 === 0) return { gems: 80 };
  return { coins: 600, bomb: 1 };
};

export const CHALLENGE_TARGET = 1500;
export const CHALLENGE_REWARD = { gems: 50, coins: 500 };
export const REVIVE_GEMS = 50;
