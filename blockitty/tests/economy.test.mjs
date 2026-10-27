import test from 'node:test';
import assert from 'node:assert/strict';
import * as st from '../js/state.js';
import { PASS_PREMIUM, PASS_TIERS, PASS_PRICE_GEMS, PITY_EPIC, RARITY_ORDER, ALL_ITEMS } from '../js/data.js';

const mem = () => { const m = new Map(); return { getItem: (k) => m.get(k) ?? null, setItem: (k, v) => m.set(k, v), removeItem: (k) => m.delete(k) }; };

test('save and load roundtrip', () => {
  st.setStorage(mem());
  st.load();
  st.S.coins = 1234;
  st.save();
  st.S.coins = 0;
  st.load();
  assert.equal(st.S.coins, 1234);
});

test('premium box pity guarantees epic+ every 10 opens', () => {
  st.setStorage(mem());
  st.load();
  st.S.gems = 100000;
  let sinceEpic = 0;
  for (let i = 0; i < 200; i++) {
    const [r] = st.openBox(1);
    sinceEpic = RARITY_ORDER.indexOf(r.item.rarity) >= 2 ? 0 : sinceEpic + 1;
    assert.ok(sinceEpic < PITY_EPIC);
  }
});

test('duplicates convert into coins, and boxes never give exclusives', () => {
  st.setStorage(mem());
  st.load();
  st.S.gems = 1e6;
  const res = st.openBox(10).concat(...Array.from({ length: 30 }, () => st.openBox(10)));
  assert.ok(res.every((r) => !r.item.exclusive));
  assert.ok(res.some((r) => r.dup && r.coins > 0));
});

test('boxes and purchases fail without currency', () => {
  st.setStorage(mem());
  st.load();
  st.S.gems = 0; st.S.coins = 0; st.S.freePulls = 0;
  assert.equal(st.openBox(1), null);
    const item = ALL_ITEMS.find((i) => i.rarity === 'epic' && !i.exclusive);
  assert.equal(st.buyItem(`${item.type}:${item.id}`), false);
});

test('premium pass pays back more gems than it costs', () => {
  let gems = 0;
  for (let t = 1; t <= PASS_TIERS; t++) gems += PASS_PREMIUM(t).gems || 0;
  assert.ok(gems >= PASS_PRICE_GEMS, `${gems} >= ${PASS_PRICE_GEMS}`);
});

test('missions progress and pay out', () => {
  st.setStorage(mem());
  st.load();
  st.ensureDaily();
  const before = st.S.coins + st.S.gems;
  for (let i = 0; i < 5; i++) {
    st.finishGame({ mode: 'classic', score: 5000, lines: 40, pieces: 80, bestCombo: 6, powers: 3, multis: 3, perfects: 0 });
  }
  st.S.daily.missions.forEach((m, i) => { if (!m.done) st.bumpMission(st.missionDef(m.id).stat, 999); st.claimMission(i); });
  assert.ok(st.S.daily.missions.every((m) => m.claimed));
  assert.ok(st.S.coins + st.S.gems > before);
  assert.ok(st.S.level > 1);
});

test('login streak advances each day', () => {
  st.setStorage(mem());
  st.load();
  st.ensureDaily();
  assert.equal(st.S.loginDay, 0);
  assert.ok(st.claimLogin());
  assert.equal(st.claimLogin(), null);
  st.S.daily.date = '2000-01-01';
  st.ensureDaily();
  assert.equal(st.S.loginDay, 1);
});

test('daily shop is stable for a date and only sells buyable items', () => {
  const a = st.dailyShop('2026-10-27').map((i) => i.id);
  const b = st.dailyShop('2026-10-27').map((i) => i.id);
  assert.deepEqual(a, b);
  assert.equal(new Set(a).size, 5);
  assert.ok(st.dailyShop('2026-10-27').every((i) => !i.exclusive && i.rarity !== 'mythic'));
});

test('streak grows on consecutive days and resets after a gap', () => {
  st.setStorage(mem());
  st.load();
  st.S.streak = { count: 4, last: '2000-01-01' };
  st.touchStreak();
  assert.equal(st.S.streak.count, 1);
  const y = new Date(); y.setDate(y.getDate() - 1);
  st.S.streak = { count: 4, last: st.dayKey(y) };
  st.touchStreak();
  assert.equal(st.S.streak.count, 5);
  assert.equal(st.touchStreak(), false);
});

test('v1 saves migrate yarn into coins', () => {
  const m = mem();
  m.setItem('blockitty-save-v1', JSON.stringify({ coins: 100, yarn: 10 }));
  st.setStorage(m);
  st.load();
  assert.equal(st.S.coins, 350);
  assert.equal(st.S.yarn, undefined);
});
