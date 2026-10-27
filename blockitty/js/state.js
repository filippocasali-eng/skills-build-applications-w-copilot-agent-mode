// Persistent player state and the whole economy (currencies, unlocks, boxes,
// missions, Paw Pass). Pure logic plus a localStorage adapter.

import { mulberry32, hashString } from './core.js';
import {
  ALL_ITEMS, ITEM_BY_KEY, itemKey, DEFAULTS, RARITIES, RARITY_ORDER, BOXES, PITY_EPIC, PITY_LEGENDARY,
  SHOP_PRICES, MISSION_POOL, MISSION_XP, LOGIN_REWARDS, PASS_TIERS, PASS_XP_PER_TIER, SEASON_DAYS,
  SEASON_EPOCH, PASS_FREE, PASS_PREMIUM, PASS_PRICE_GEMS, CATS, SETS, POWERUPS, SPIN_SEGMENTS,
} from './data.js';

const KEY = 'blockitty-save-v1';

export function freshState() {
  return {
    v: 1,
    coins: 500,
    gems: 60,
    yarn: 0,
    freePulls: 1,
    xp: 0,
    level: 1,
    best: { classic: 0, challenge: 0 },
    owned: [`cat:${DEFAULTS.cat}`, `skin:${DEFAULTS.skin}`, `theme:${DEFAULTS.theme}`, `fx:${DEFAULTS.fx}`],
    seen: [`cat:${DEFAULTS.cat}`, `skin:${DEFAULTS.skin}`, `theme:${DEFAULTS.theme}`, `fx:${DEFAULTS.fx}`],
    equip: { ...DEFAULTS },
    power: { hammer: 2, bomb: 1, shuffle: 2 },
    stats: { games: 0, lines: 0, pieces: 0, bestCombo: 0, perfects: 0, boxes: 0 },
    daily: null,
    loginDay: 0,
    pass: { season: -1, xp: 0, premium: false, free: [], prem: [] },
    pity: { epic: 0, legendary: 0 },
    setsClaimed: [],
    purchases: { starter: false, history: [] },
    settings: { sound: true, haptics: true },
    tutorialDone: false,
    created: Date.now(),
  };
}

let storage = typeof localStorage !== 'undefined' ? localStorage : null;
export function setStorage(s) { storage = s; }

export let S = freshState();

export function load() {
  try {
    const raw = storage && storage.getItem(KEY);
    if (raw) {
      const data = JSON.parse(raw);
      const base = freshState();
      S = { ...base, ...data, best: { ...base.best, ...data.best }, power: { ...base.power, ...data.power }, stats: { ...base.stats, ...data.stats }, settings: { ...base.settings, ...data.settings }, purchases: { ...base.purchases, ...data.purchases }, equip: { ...base.equip, ...data.equip } };
    } else {
      S = freshState();
    }
  } catch {
    S = freshState();
  }
  return S;
}

export function save() {
  try { storage && storage.setItem(KEY, JSON.stringify(S)); } catch { /* storage full or blocked */ }
}

export function resetAll() {
  S = freshState();
  save();
}

// ---------- time helpers ----------
export function dayKey(d = new Date()) {
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`;
}
export function msToMidnight(now = new Date()) {
  const m = new Date(now); m.setHours(24, 0, 0, 0);
  return m - now;
}
export function fmtDuration(ms) {
  const s = Math.max(0, Math.floor(ms / 1000));
  const d = Math.floor(s / 86400), h = Math.floor((s % 86400) / 3600), m = Math.floor((s % 3600) / 60), sec = s % 60;
  if (d > 0) return `${d}d ${h}h`;
  if (h > 0) return `${h}h ${m}m`;
  return `${m}m ${String(sec).padStart(2, '0')}s`;
}

// ---------- rewards ----------
export function grant(reward) {
  if (!reward) return [];
  const got = [];
  for (const [k, v] of Object.entries(reward)) {
    if (k === 'coins') { S.coins += v; got.push({ k, v }); }
    else if (k === 'gems') { S.gems += v; got.push({ k, v }); }
    else if (k === 'yarn') { S.yarn += v; got.push({ k, v }); }
    else if (k === 'freePulls') { S.freePulls += v; got.push({ k, v }); }
    else if (k === 'xp') addXp(v);
    else if (POWERUPS[k]) { S.power[k] += v; got.push({ k, v }); }
    else if (k === 'item') { const r = unlock(v); got.push({ k, v, ...r }); }
  }
  save();
  return got;
}

export function rewardText(reward) {
  const parts = [];
  for (const [k, v] of Object.entries(reward)) {
    if (k === 'coins') parts.push(`🪙 ${v.toLocaleString()}`);
    else if (k === 'gems') parts.push(`💎 ${v}`);
    else if (k === 'yarn') parts.push(`🧶 ${v}`);
    else if (k === 'freePulls') parts.push(`🎁 ${v} Box${v > 1 ? 'es' : ''}`);
    else if (POWERUPS[k]) parts.push(`${POWERUPS[k].icon} ×${v}`);
    else if (k === 'item') parts.push(`✨ ${ITEM_BY_KEY[v]?.name || v}`);
    else if (k === 'xp') parts.push(`⭐ ${v} XP`);
  }
  return parts.join('  ');
}

// ---------- XP, levels, pass ----------
export const xpForLevel = (lvl) => 300 + lvl * 150;

export function seasonInfo(now = Date.now()) {
  const len = SEASON_DAYS * 86400000;
  const idx = Math.floor((now - SEASON_EPOCH) / len);
  const end = SEASON_EPOCH + (idx + 1) * len;
  return { idx, end, left: end - now, number: idx + 1 };
}

function syncSeason() {
  const { idx } = seasonInfo();
  if (S.pass.season !== idx) S.pass = { season: idx, xp: 0, premium: false, free: [], prem: [] };
}

export function addXp(n) {
  syncSeason();
  S.xp += n;
  S.pass.xp += n;
  const ups = [];
  let need = xpForLevel(S.level);
  while (S.xp >= need) {
    S.xp -= need;
    S.level += 1;
    const reward = { coins: 200 + S.level * 20, gems: 10 };
    grant(reward);
    ups.push({ level: S.level, reward });
    need = xpForLevel(S.level);
  }
  save();
  return ups;
}

export function passTier() {
  syncSeason();
  return Math.min(PASS_TIERS, Math.floor(S.pass.xp / PASS_XP_PER_TIER));
}

export function claimPass(tier, premium) {
  syncSeason();
  if (tier > passTier()) return null;
  const list = premium ? S.pass.prem : S.pass.free;
  if (list.includes(tier)) return null;
  if (premium && !S.pass.premium) return null;
  list.push(tier);
  const reward = premium ? PASS_PREMIUM(tier) : PASS_FREE(tier);
  grant(reward);
  return reward;
}

export function buyPremiumPass() {
  syncSeason();
  if (S.pass.premium || S.gems < PASS_PRICE_GEMS) return false;
  S.gems -= PASS_PRICE_GEMS;
  S.pass.premium = true;
  save();
  return true;
}

export function passClaimable() {
  const t = passTier();
  let n = 0;
  for (let i = 1; i <= t; i++) {
    if (!S.pass.free.includes(i)) n++;
    if (S.pass.premium && !S.pass.prem.includes(i)) n++;
  }
  return n;
}

// ---------- items ----------
export const owns = (key) => S.owned.includes(key);

export function unlock(key) {
  const item = ITEM_BY_KEY[key];
  if (!item) return { dup: false, yarn: 0 };
  if (owns(key)) {
    const yarn = RARITIES[item.rarity].yarn;
    S.yarn += yarn;
    return { dup: true, yarn };
  }
  S.owned.push(key);
  return { dup: false, yarn: 0, isNew: true };
}

export function equip(type, id) {
  if (!owns(`${type}:${id}`)) return false;
  S.equip[type] = id;
  save();
  return true;
}

export function equipped(type) {
  return ITEM_BY_KEY[`${type}:${S.equip[type]}`];
}

export function setProgress(setId) {
  const cats = CATS.filter((c) => c.set === setId);
  const have = cats.filter((c) => owns(itemKey(c))).length;
  return { have, total: cats.length, cats };
}

export function claimSet(setId) {
  const set = SETS.find((s) => s.id === setId);
  const p = setProgress(setId);
  if (!set || p.have < p.total || S.setsClaimed.includes(setId)) return null;
  S.setsClaimed.push(setId);
  grant(set.reward);
  return set.reward;
}

export function yarnPrice(item) {
  return RARITIES[item.rarity].yarn * 4;
}

export function craftWithYarn(key) {
  const item = ITEM_BY_KEY[key];
  if (!item || owns(key) || item.exclusive) return false;
  const price = yarnPrice(item);
  if (S.yarn < price) return false;
  S.yarn -= price;
  unlock(key);
  save();
  return true;
}

// ---------- shop ----------
export function shopPrice(item) {
  return SHOP_PRICES[item.rarity] || null;
}

export function dailyShop(date = dayKey()) {
  const rng = mulberry32(hashString(`shop-${date}`));
  const pool = ALL_ITEMS.filter((i) => !i.exclusive && i.rarity !== 'mythic' && shopPrice(i) && !(i.type === 'cat' && i.id === DEFAULTS.cat) && !Object.values(DEFAULTS).includes(i.id));
  const picks = [];
  // One featured legendary/epic + 5 others
  const premium = pool.filter((i) => i.rarity === 'legendary' || i.rarity === 'epic');
  picks.push(premium[Math.floor(rng() * premium.length)]);
  while (picks.length < 6) {
    const it = pool[Math.floor(rng() * pool.length)];
    if (!picks.includes(it)) picks.push(it);
  }
  return picks;
}

export function buyItem(key) {
  const item = ITEM_BY_KEY[key];
  const price = item && shopPrice(item);
  if (!price || owns(key)) return false;
  if (price.coins) { if (S.coins < price.coins) return false; S.coins -= price.coins; }
  if (price.gems) { if (S.gems < price.gems) return false; S.gems -= price.gems; }
  unlock(key);
  save();
  return true;
}

export function buyPower(id, qty = 1) {
  const cost = POWERUPS[id].coins * qty;
  if (S.coins < cost) return false;
  S.coins -= cost;
  S.power[id] += qty;
  save();
  return true;
}

export function spendGems(n) {
  if (S.gems < n) return false;
  S.gems -= n;
  save();
  return true;
}

// ---------- boxes (gacha with pity) ----------
function rollRarity(rng, rates) {
  const total = RARITY_ORDER.reduce((s, r) => s + (rates[r] || 0), 0);
  let roll = rng() * total;
  for (const r of RARITY_ORDER) {
    roll -= rates[r] || 0;
    if (roll <= 0) return r;
  }
  return 'common';
}

const PREMIUM_RATES = Object.fromEntries(RARITY_ORDER.map((r) => [r, RARITIES[r].rate]));

export function boxPool() {
  return ALL_ITEMS.filter((i) => !i.exclusive && !Object.values(DEFAULTS).includes(i.id));
}

export function pullOne(boxId, rng = Math.random) {
  const box = BOXES[boxId];
  let rarity;
  if (boxId === 'premium') {
    S.pity.epic += 1;
    S.pity.legendary += 1;
    rarity = rollRarity(rng, PREMIUM_RATES);
    if (S.pity.legendary >= PITY_LEGENDARY && RARITY_ORDER.indexOf(rarity) < 3) rarity = 'legendary';
    else if (S.pity.epic >= PITY_EPIC && RARITY_ORDER.indexOf(rarity) < 2) rarity = 'epic';
    if (RARITY_ORDER.indexOf(rarity) >= 2) S.pity.epic = 0;
    if (RARITY_ORDER.indexOf(rarity) >= 3) S.pity.legendary = 0;
  } else {
    rarity = rollRarity(rng, box.rates);
  }
  const pool = boxPool().filter((i) => i.rarity === rarity);
  // Prefer items the player doesn't own yet (60%) to keep collecting exciting.
  const fresh = pool.filter((i) => !owns(itemKey(i)));
  const from = fresh.length && rng() < 0.6 ? fresh : pool;
  const item = from[Math.floor(rng() * from.length)];
  const res = unlock(itemKey(item));
  S.stats.boxes += 1;
  bumpMission('boxes', 1);
  return { item, ...res };
}

export function openBox(boxId, count = 1, { free = false } = {}) {
  const box = BOXES[boxId];
  if (free) {
    if (S.freePulls < 1) return null;
    S.freePulls -= 1;
  } else if (box.currency === 'gems') {
    const cost = count === 10 ? box.price10 : box.price * count;
    if (S.gems < cost) return null;
    S.gems -= cost;
  } else {
    const cost = box.price * count;
    if (S.coins < cost) return null;
    S.coins -= cost;
  }
  const results = [];
  for (let i = 0; i < count; i++) results.push(pullOne(boxId));
  save();
  return results;
}

// ---------- daily: login, missions, spin, challenge ----------
export function ensureDaily() {
  const today = dayKey();
  if (S.daily && S.daily.date === today) return false;
  const rng = mulberry32(hashString(`missions-${today}`));
  const pool = MISSION_POOL.slice();
  const missions = [];
  while (missions.length < 3) {
    const m = pool.splice(Math.floor(rng() * pool.length), 1)[0];
    missions.push({ id: m.id, p: 0, done: false, claimed: false });
  }
  const firstEver = !S.daily;
  if (!firstEver) S.loginDay = (S.loginDay + 1) % LOGIN_REWARDS.length;
  S.daily = { date: today, missions, spin: true, challengeDone: false, freeRevive: true, loginClaimed: false };
  save();
  return true;
}

export function claimLogin() {
  if (!S.daily || S.daily.loginClaimed) return null;
  S.daily.loginClaimed = true;
  const r = LOGIN_REWARDS[S.loginDay];
  grant(r);
  return r;
}

export function missionDef(id) { return MISSION_POOL.find((m) => m.id === id); }

export function bumpMission(stat, value, mode = 'add') {
  if (!S.daily) return;
  for (const m of S.daily.missions) {
    const def = missionDef(m.id);
    if (def.stat !== stat || m.done) continue;
    m.p = mode === 'max' ? Math.max(m.p, value) : m.p + value;
    if (m.p >= def.n) { m.p = def.n; m.done = true; }
  }
}

export function claimMission(idx) {
  const m = S.daily?.missions[idx];
  if (!m || !m.done || m.claimed) return null;
  m.claimed = true;
  const def = missionDef(m.id);
  grant(def.reward);
  addXp(MISSION_XP);
  return { ...def.reward, xp: MISSION_XP };
}

export function missionsClaimable() {
  return S.daily ? S.daily.missions.filter((m) => m.done && !m.claimed).length : 0;
}

export function spin(rng = Math.random) {
  if (!S.daily?.spin) return null;
  S.daily.spin = false;
  const total = SPIN_SEGMENTS.reduce((s, x) => s + x.w, 0);
  let roll = rng() * total;
  let idx = 0;
  for (let i = 0; i < SPIN_SEGMENTS.length; i++) { roll -= SPIN_SEGMENTS[i].w; if (roll <= 0) { idx = i; break; } }
  grant(SPIN_SEGMENTS[idx].reward);
  return idx;
}

export function buyExtraSpin(cost = 25) {
  if (!S.daily || S.daily.spin || S.gems < cost) return false;
  S.gems -= cost;
  S.daily.spin = true;
  save();
  return true;
}

// ---------- end of game bookkeeping ----------
export function finishGame({ mode, score, lines, pieces, bestCombo, powers, multis, perfects }) {
  const newBest = score > (S.best[mode] || 0);
  if (newBest) S.best[mode] = score;
  S.stats.games += 1;
  S.stats.lines += lines;
  S.stats.pieces += pieces;
  S.stats.perfects += perfects;
  S.stats.bestCombo = Math.max(S.stats.bestCombo, bestCombo);
  bumpMission('games', 1);
  bumpMission('lines', lines);
  bumpMission('pieces', pieces);
  bumpMission('bestGame', score, 'max');
  bumpMission('bestCombo', bestCombo, 'max');
  bumpMission('powers', powers);
  bumpMission('multis', multis);
  const coins = Math.floor(score / 15) + lines * 3;
  const xp = Math.min(500, Math.floor(score / 8) + lines * 2 + 20);
  S.coins += coins;
  const ups = addXp(xp);
  save();
  return { coins, xp, newBest, ups };
}

export function recordPurchase(sku) {
  S.purchases.history.push({ sku, at: Date.now() });
  save();
}

export function newItemsCount() {
  return S.owned.filter((k) => !S.seen.includes(k)).length;
}
export function markSeen() {
  S.seen = S.owned.slice();
  save();
}
