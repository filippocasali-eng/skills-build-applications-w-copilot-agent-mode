// Menus, shop, boxes, collection, pass and every modal.

import {
  S, save, owns, equip, equipped, dailyShop, shopPrice, buyItem, buyPower, openBox, setProgress, claimSet,
  yarnPrice, craftWithYarn, claimMission, missionDef, missionsClaimable, spin, buyExtraSpin, claimLogin,
  passTier, claimPass, buyPremiumPass, passClaimable, seasonInfo, fmtDuration, msToMidnight, xpForLevel,
  rewardText, grant, spendGems, newItemsCount, markSeen, resetAll, recordPurchase, finishGame, dayKey,
} from './state.js';
import {
  CATS, SKINS, THEMES, EFFECTS, SETS, RARITIES, RARITY_ORDER, ITEM_BY_KEY, itemKey, BOXES, PITY_EPIC,
  PITY_LEGENDARY, POWERUPS, GEM_PACKS, STARTER_PACK, PASS_PRICE_GEMS, PASS_TIERS, PASS_XP_PER_TIER,
  PASS_FREE, PASS_PREMIUM, LOGIN_REWARDS, SPIN_SEGMENTS, CHALLENGE_TARGET, CHALLENGE_REWARD, REVIVE_GEMS,
} from './data.js';
import { catSVG } from './cats.js';
import { skinPreview } from './skins.js';
import { sfx, setAudio } from './audio.js';
import { confettiRain } from './fx.js';
import { purchase, isDemo } from './billing.js';
import * as game from './game.js';

const $ = (id) => document.getElementById(id);
const FX_ICONS = { sparkle: '✨', confetti: '🎊', hearts: '💖', paws: '🐾', fish: '🐟', stars: '🌟', bubbles: '🫧', rainbow: '🌈' };
const TYPE_NAMES = { cat: 'Cat', skin: 'Block Skin', theme: 'Theme', fx: 'Clear Effect' };
let currentScreen = 'home';
let shopTimer = null;

// ---------- generic helpers ----------
export function toast(text) {
  const el = document.createElement('div');
  el.className = 'toast';
  el.textContent = text;
  $('toast-root').appendChild(el);
  setTimeout(() => el.remove(), 2400);
}

export function modal(html, { cls = '', dismiss = true, onClose } = {}) {
  const wrap = document.createElement('div');
  wrap.className = 'modal-back';
  wrap.innerHTML = `<div class="modal ${cls}">${dismiss ? '<button class="modal-x" data-close aria-label="Close">✕</button>' : ''}${html}</div>`;
  const close = () => { wrap.remove(); onClose && onClose(); };
  wrap.addEventListener('click', (e) => {
    if ((dismiss && e.target === wrap) || e.target.closest('[data-close]')) { sfx.tap(); close(); }
  });
  $('modal-root').appendChild(wrap);
  hydrate(wrap);
  wrap.close = close;
  return wrap;
}

function closeAllModals() { $('modal-root').innerHTML = ''; }

function rarityBadge(r) {
  return `<span class="rarity" style="--rc:${RARITIES[r].color}">${RARITIES[r].name}</span>`;
}

export function preview(item, size = 84) {
  switch (item.type) {
    case 'cat': return `<div class="prev cat-prev" style="width:${size}px;height:${size}px">${catSVG(item.look)}</div>`;
    case 'skin': return `<div class="prev skin-prev" data-skin="${item.id}" data-size="${size}" style="width:${size}px;height:${size}px"></div>`;
    case 'theme': return `<div class="prev theme-prev" style="width:${size}px;height:${size}px;background:${item.bg}"><div style="background:${item.board}"></div></div>`;
    case 'fx': return `<div class="prev fx-prev" style="width:${size}px;height:${size}px;font-size:${size * 0.5}px">${FX_ICONS[item.id] || '✨'}</div>`;
    default: return '';
  }
}

function hydrate(root) {
  root.querySelectorAll('.skin-prev:empty').forEach((el) => {
    const sk = SKINS.find((s) => s.id === el.dataset.skin);
    if (sk) el.appendChild(skinPreview(sk, Number(el.dataset.size) - 8));
  });
}

function priceTag(p) {
  if (!p) return '';
  return p.coins ? `🪙 ${p.coins.toLocaleString()}` : `💎 ${p.gems.toLocaleString()}`;
}

// ---------- top bar & nav ----------
export function refreshTop() {
  $('coins').textContent = S.coins.toLocaleString();
  $('gems').textContent = S.gems.toLocaleString();
  $('lvl').textContent = S.level;
  $('lvl-fill').style.width = `${Math.min(100, (S.xp / xpForLevel(S.level)) * 100)}%`;
  $('dot-pass').classList.toggle('on', passClaimable() > 0);
  $('dot-boxes').classList.toggle('on', S.freePulls > 0);
  $('dot-collection').classList.toggle('on', newItemsCount() > 0 || SETS.some((s) => { const p = setProgress(s.id); return p.have === p.total && !S.setsClaimed.includes(s.id); }));
  document.body.style.background = equipped('theme').bg;
}

export function show(name) {
  currentScreen = name;
  document.querySelectorAll('.screen').forEach((s) => s.classList.toggle('active', s.id === `screen-${name}`));
  document.querySelectorAll('[data-nav]').forEach((b) => b.classList.toggle('active', b.dataset.nav === name));
  document.body.classList.toggle('in-game', name === 'game');
  clearInterval(shopTimer);
  const renderers = { home: renderHome, shop: renderShop, boxes: renderBoxes, collection: renderCollection, pass: renderPass };
  if (renderers[name]) renderers[name]();
  refreshTop();
}

export function rerender() { show(currentScreen); }

// ---------- HOME ----------
function renderHome() {
  const catItem = equipped('cat');
  const challengeDone = S.daily?.challengeDone;
  const missions = missionsClaimable();
  const el = $('screen-home');
  el.innerHTML = `
    <div class="home">
      <div class="side left">
        <button class="side-btn" data-act="missions"><span>📋</span>Missions${missions ? `<i class="badge">${missions}</i>` : ''}</button>
        <button class="side-btn" data-act="spin"><span>🎡</span>Spin${S.daily?.spin ? '<i class="badge">1</i>' : ''}</button>
        <button class="side-btn" data-act="login"><span>📅</span>Daily${S.daily && !S.daily.loginClaimed ? '<i class="badge">!</i>' : ''}</button>
      </div>
      <div class="side right">
        ${!S.purchases.starter ? '<button class="side-btn hot" data-act="starter"><span>🎁</span>Starter<i class="badge">-80%</i></button>' : ''}
        <button class="side-btn" data-act="gems"><span>💎</span>Gems</button>
        <button class="side-btn" data-nav-go="pass"><span>🎟️</span>Pass</button>
      </div>
      <h1 class="logo">Block<span>itty</span></h1>
      <div class="hero-cat" data-act="pet">${catSVG(catItem.look, 'idle', 'idle-bob')}</div>
      <div class="hero-name">${catItem.name} ${rarityBadge(catItem.rarity)}</div>
      <div class="best-line">👑 Best: ${(S.best.classic || 0).toLocaleString()}</div>
      ${game.hasSavedRun() ? '<button class="big-btn green" data-act="continue">▶ CONTINUE</button>' : ''}
      <button class="big-btn" data-act="play">${game.hasSavedRun() ? 'NEW GAME' : '▶ PLAY'}</button>
      <button class="big-btn purple small ${challengeDone ? 'done' : ''}" data-act="challenge">
        🏆 Daily Challenge ${challengeDone ? '✓' : `<small>Score ${CHALLENGE_TARGET.toLocaleString()} → 💎${CHALLENGE_REWARD.gems}</small>`}
      </button>
    </div>`;
}

// ---------- SHOP ----------
function renderShop() {
  const items = dailyShop();
  const el = $('screen-shop');
  el.innerHTML = `
    <div class="page">
      ${!S.purchases.starter ? `
      <div class="offer" data-act="starter">
        <div class="offer-tag">ONE-TIME OFFER</div>
        <div class="offer-body">
          <div class="offer-cat">${catSVG(ITEM_BY_KEY['cat:lucky'].look, 'happy')}</div>
          <div><h3>Starter Pack</h3><p>Lucky the Epic cat + Candy Gloss skin + 💎500 + 🪙5,000</p>
          <div class="offer-price"><s>${STARTER_PACK.worth}</s> <b>${STARTER_PACK.price}</b></div></div>
        </div>
      </div>` : ''}
      <h2>Daily Deals <span class="timer" id="shop-timer">${fmtDuration(msToMidnight())}</span></h2>
      <div class="grid">
        ${items.map((it, i) => {
          const key = itemKey(it), own = owns(key);
          return `<button class="card ${i === 0 ? 'featured' : ''} ${own ? 'owned' : ''}" style="--rc:${RARITIES[it.rarity].color}" data-buy="${key}">
            ${i === 0 ? '<div class="ribbon">FEATURED</div>' : ''}
            ${preview(it, i === 0 ? 110 : 76)}
            <div class="card-name">${it.name}</div>
            <div class="card-type">${TYPE_NAMES[it.type]}</div>
            <div class="price">${own ? 'Owned ✓' : priceTag(shopPrice(it))}</div>
          </button>`;
        }).join('')}
      </div>
      <h2>Power-ups</h2>
      <div class="grid three">
        ${Object.entries(POWERUPS).map(([id, p]) => `<button class="card" data-power-buy="${id}">
          <div class="pw-icon">${p.icon}</div><div class="card-name">${p.name} ×3</div><div class="card-type">${p.desc} · have ${S.power[id]}</div>
          <div class="price">🪙 ${(p.coins * 3).toLocaleString()}</div></button>`).join('')}
      </div>
      <h2>Gems ${isDemo() ? '<span class="demo-tag">DEMO – no real charges</span>' : ''}</h2>
      <div class="grid three">
        ${GEM_PACKS.map((g) => `<button class="card gem-card" data-iap="${g.sku}">
          ${g.tag ? `<div class="ribbon">${g.tag}</div>` : ''}
          <div class="gem-ico">${'💎'.repeat(Math.min(3, GEM_PACKS.indexOf(g) + 1))}</div>
          <div class="card-name">${(g.gems + (g.bonus || 0)).toLocaleString()}</div>
          <div class="card-type">${g.label}${g.bonus ? ` · +${g.bonus} bonus` : ''}</div>
          <div class="price iap">${g.price}</div></button>`).join('')}
      </div>
      <p class="fine">Cosmetics never affect scoring. Box odds are shown in the Boxes tab.</p>
    </div>`;
  hydrate(el);
  shopTimer = setInterval(() => { const t = $('shop-timer'); if (t) t.textContent = fmtDuration(msToMidnight()); }, 1000);
}

function itemModal(key) {
  const it = ITEM_BY_KEY[key];
  const own = owns(key);
  const price = shopPrice(it);
  const isEq = S.equip[it.type] === it.id;
  const inShop = dailyShop().some((x) => itemKey(x) === key);
  const canCraft = !own && !it.exclusive;
  const how = it.exclusive === 'pass' ? 'Paw Pass exclusive' : it.exclusive === 'starter' ? 'Starter Pack exclusive' : 'Found in Mystery Boxes';
  const m = modal(`
    <div class="item-detail" style="--rc:${RARITIES[it.rarity].color}">
      <div class="detail-prev">${preview(it, 150)}</div>
      <h2>${it.name}</h2>
      <div>${rarityBadge(it.rarity)} <span class="muted">${TYPE_NAMES[it.type]}</span></div>
      ${it.set ? `<p class="muted">Set: ${SETS.find((s) => s.id === it.set)?.name || 'Exclusive'}</p>` : ''}
      ${own
        ? (isEq ? '<button class="big-btn small done" disabled>Equipped ✓</button>' : '<button class="big-btn small green" data-eq>Equip</button>')
        : `
        ${inShop && price ? `<button class="big-btn small" data-buyit>Buy ${priceTag(price)}</button>` : ''}
        ${canCraft ? `<button class="big-btn small purple" data-craft>Craft 🧶 ${yarnPrice(it)} <small>(you have ${S.yarn})</small></button>` : ''}
        <p class="muted">${how}</p>`}
    </div>`);
  m.querySelector('[data-eq]')?.addEventListener('click', () => {
    equip(it.type, it.id); sfx.coin(); toast(`${it.name} equipped!`); m.close(); rerender();
  });
  m.querySelector('[data-buyit]')?.addEventListener('click', () => { m.close(); tryBuy(key); });
  m.querySelector('[data-craft]')?.addEventListener('click', () => {
    if (craftWithYarn(key)) { sfx.reveal(2); toast(`Crafted ${it.name}!`); m.close(); revealSingle(it); rerender(); }
    else { sfx.invalid(); toast('Not enough yarn 🧶 — get duplicates from boxes'); }
  });
}

function tryBuy(key) {
  const it = ITEM_BY_KEY[key];
  if (owns(key)) { itemModal(key); return; }
  const price = shopPrice(it);
  if (buyItem(key)) {
    sfx.coin();
    revealSingle(it);
    rerender();
  } else if (price.gems) {
    sfx.invalid();
    gemsModal(`You need 💎${price.gems - S.gems} more gems`);
  } else {
    sfx.invalid();
    toast('Not enough coins 🪙 — play more or open the Gem shop!');
  }
}

function revealSingle(it) {
  confettiRain(60);
  const m = modal(`
    <div class="reveal-one" style="--rc:${RARITIES[it.rarity].color}">
      <div class="burst-bg"></div>
      ${preview(it, 160)}
      <h2>${it.name}</h2>${rarityBadge(it.rarity)}
      <button class="big-btn small green" data-eq>Equip now</button>
    </div>`, { cls: 'glow' });
  m.querySelector('[data-eq]').addEventListener('click', () => { equip(it.type, it.id); m.close(); rerender(); toast('Equipped!'); });
}

// ---------- IAP ----------
function demoConfirm(label, price) {
  return new Promise((resolve) => {
    const m = modal(`
      <h2>Confirm purchase</h2>
      <p>${label}</p>
      <p class="big-price">${price}</p>
      <p class="demo-note">DEMO MODE: no money will be charged. In the Play Store build this opens Google Play Billing.</p>
      <div class="row"><button class="big-btn small gray" data-no>Cancel</button><button class="big-btn small green" data-yes>Buy</button></div>`,
    { onClose: () => resolve(false) });
    m.querySelector('[data-yes]').addEventListener('click', () => { m.remove(); resolve(true); });
    m.querySelector('[data-no]').addEventListener('click', () => { m.remove(); resolve(false); });
  });
}

async function buyGems(sku) {
  const pack = GEM_PACKS.find((g) => g.sku === sku);
  const ok = await purchase(sku, () => demoConfirm(`${(pack.gems + (pack.bonus || 0)).toLocaleString()} Gems`, pack.price));
  if (!ok) return;
  grant({ gems: pack.gems + (pack.bonus || 0) });
  recordPurchase(sku);
  sfx.coin(); confettiRain(60);
  toast(`+${(pack.gems + (pack.bonus || 0)).toLocaleString()} 💎 Thank you!`);
  refreshTop(); rerender();
}

async function buyStarter() {
  if (S.purchases.starter) return;
  const ok = await purchase(STARTER_PACK.sku, () => demoConfirm('Starter Pack: Lucky (Epic cat), Candy Gloss skin, 💎500, 🪙5,000', STARTER_PACK.price));
  if (!ok) return;
  S.purchases.starter = true;
  grant({ gems: STARTER_PACK.gems, coins: STARTER_PACK.coins, item: `cat:${STARTER_PACK.cat}` });
  grant({ item: `skin:${STARTER_PACK.skin}` });
  recordPurchase(STARTER_PACK.sku);
  revealSingle(ITEM_BY_KEY['cat:lucky']);
  refreshTop(); rerender();
}

function gemsModal(reason = '') {
  const m = modal(`
    <h2>💎 Get Gems</h2>${reason ? `<p class="warn">${reason}</p>` : ''}
    ${isDemo() ? '<p class="demo-note">DEMO – no real charges</p>' : ''}
    <div class="grid three">${GEM_PACKS.map((g) => `<button class="card gem-card" data-iap="${g.sku}">${g.tag ? `<div class="ribbon">${g.tag}</div>` : ''}
      <div class="card-name">💎 ${(g.gems + (g.bonus || 0)).toLocaleString()}</div><div class="price iap">${g.price}</div></button>`).join('')}</div>`);
  m.querySelectorAll('[data-iap]').forEach((b) => b.addEventListener('click', () => { m.close(); buyGems(b.dataset.iap); }));
}

// ---------- BOXES ----------
function renderBoxes() {
  const el = $('screen-boxes');
  const pityE = PITY_EPIC - S.pity.epic, pityL = PITY_LEGENDARY - S.pity.legendary;
  el.innerHTML = `
    <div class="page">
      <div class="box-hero">
        <div class="box-art premium"><div class="box-lid"></div><div class="box-body">?</div></div>
        <h2>Mystery Litter Box</h2>
        <p class="muted">Cats · Skins · Themes · Effects — including <b style="color:${RARITIES.mythic.color}">Mythic</b> drops!</p>
        <div class="pity">Epic+ guaranteed in <b>${pityE}</b> · Legendary+ in <b>${pityL}</b></div>
        <div class="row">
          ${S.freePulls > 0 ? `<button class="big-btn small green" data-open="free">FREE ×1 <small>(${S.freePulls} left)</small></button>` : `<button class="big-btn small" data-open="p1">Open ×1 <small>💎${BOXES.premium.price}</small></button>`}
          <button class="big-btn small purple" data-open="p10">Open ×10 <small>💎${BOXES.premium.price10} <s>${BOXES.premium.price * 10}</s></small></button>
        </div>
        <button class="link" data-act="odds">View drop rates</button>
      </div>
      <div class="box-hero small">
        <div class="box-art basic"><div class="box-lid"></div><div class="box-body">📦</div></div>
        <h3>Cardboard Box</h3>
        <p class="muted">Common &amp; Rare items, small Epic chance</p>
        <button class="big-btn small" data-open="basic">Open <small>🪙${BOXES.basic.price.toLocaleString()}</small></button>
      </div>
      <div class="yarn-line">🧶 Yarn: <b>${S.yarn}</b> <span class="muted">— duplicates turn into yarn. Craft any item in the Cats tab.</span></div>
    </div>`;
}

function oddsModal() {
  modal(`<h2>Drop rates</h2>
    <table class="odds"><tr><th>Rarity</th><th>Mystery</th><th>Cardboard</th></tr>
    ${RARITY_ORDER.map((r) => `<tr><td>${rarityBadge(r)}</td><td>${RARITIES[r].rate}%</td><td>${BOXES.basic.rates[r]}%</td></tr>`).join('')}</table>
    <p class="muted">Mystery Box: Epic or better guaranteed every ${PITY_EPIC} opens, Legendary or better within ${PITY_LEGENDARY}. Unowned items are favored. Duplicates convert to 🧶 yarn.</p>`);
}

function doOpen(kind) {
  let res;
  if (kind === 'free') res = openBox('premium', 1, { free: true });
  else if (kind === 'p1') res = openBox('premium', 1);
  else if (kind === 'p10') res = openBox('premium', 10);
  else res = openBox('basic', 1);
  if (!res) {
    sfx.invalid();
    if (kind === 'basic') toast('Not enough coins 🪙');
    else gemsModal('Not enough gems for this box');
    return;
  }
  refreshTop();
  revealBoxes(res);
}

function revealBoxes(results) {
  const best = Math.max(...results.map((r) => RARITY_ORDER.indexOf(r.item.rarity)));
  const m = modal(`
    <div class="opening" style="--rc:${RARITIES[RARITY_ORDER[best]].color}">
      <div class="box-art premium shake"><div class="box-lid"></div><div class="box-body">?</div></div>
      <p class="muted">Tap to open!</p>
    </div>`, { cls: 'reveal', dismiss: false });
  const opening = m.querySelector('.opening');
  const go = () => {
    opening.removeEventListener('click', go);
    sfx.reveal(best);
    if (best >= 3) confettiRain(120);
    const modalEl = m.querySelector('.modal');
    modalEl.innerHTML = `
      <h2>${results.length > 1 ? 'Your haul!' : 'You got…'}</h2>
      <div class="reveal-grid ${results.length > 1 ? 'many' : ''}">
        ${results.map((r, i) => `<div class="reveal-card r-${r.item.rarity}" style="--rc:${RARITIES[r.item.rarity].color};animation-delay:${i * 0.12}s">
          ${r.isNew ? '<div class="new">NEW!</div>' : ''}
          ${preview(r.item, results.length > 1 ? 50 : 140)}
          <div class="card-name">${r.item.name}</div>
          ${rarityBadge(r.item.rarity)}
          ${r.dup ? `<div class="dup">+${r.yarn} 🧶</div>` : ''}
        </div>`).join('')}
      </div>
      <div class="row"><button class="big-btn small green" data-close>Awesome!</button></div>`;
    hydrate(modalEl);
    modalEl.querySelector('[data-close]').addEventListener('click', () => { m.close(); rerender(); });
  };
  opening.addEventListener('click', go);
  setTimeout(() => { if (opening.isConnected) go(); }, 1600);
}

// ---------- COLLECTION ----------
let colTab = 'cats';
function renderCollection() {
  const el = $('screen-collection');
  const tabs = [['cats', '🐱 Cats'], ['skin', '🧱 Skins'], ['theme', '🖼️ Themes'], ['fx', '✨ Effects']];
  const totalOwned = S.owned.length;
  const total = CATS.length + SKINS.length + THEMES.length + EFFECTS.length;
  let body = '';
  if (colTab === 'cats') {
    body = [...SETS, { id: 'exclusive', name: 'Exclusives' }].map((set) => {
      const p = setProgress(set.id);
      const claimed = S.setsClaimed.includes(set.id);
      const complete = p.have === p.total;
      return `<div class="set">
        <div class="set-head"><h3>${set.name}</h3><span>${p.have}/${p.total}</span></div>
        ${set.reward ? `<div class="set-bar"><div style="width:${(p.have / p.total) * 100}%"></div></div>
        <div class="set-reward">${claimed ? 'Reward claimed ✓' : complete ? `<button class="big-btn small green" data-claim-set="${set.id}">Claim ${rewardText(set.reward)}</button>` : `Complete set: ${rewardText(set.reward)}`}</div>` : ''}
        <div class="grid four">${p.cats.map((c) => cardHtml(c)).join('')}</div>
      </div>`;
    }).join('');
  } else {
    const list = { skin: SKINS, theme: THEMES, fx: EFFECTS }[colTab];
    body = `<div class="grid four">${list.map((it) => cardHtml(it)).join('')}</div>`;
  }
  el.innerHTML = `<div class="page">
    <div class="col-head"><h2>Collection</h2><span class="muted">${totalOwned}/${total} · 🧶 ${S.yarn}</span></div>
    <div class="tabs">${tabs.map(([k, n]) => `<button class="${colTab === k ? 'on' : ''}" data-tab="${k}">${n}</button>`).join('')}</div>
    ${body}</div>`;
  hydrate(el);
  markSeen();
}

function cardHtml(it) {
  const key = itemKey(it);
  const own = owns(key);
  const eq = S.equip[it.type] === it.id;
  return `<button class="card mini ${own ? '' : 'locked'} ${eq ? 'equipped' : ''}" style="--rc:${RARITIES[it.rarity].color}" data-item="${key}">
    ${!S.seen.includes(key) && own ? '<div class="new">NEW</div>' : ''}
    ${preview(it, 58)}
    <div class="card-name">${own ? it.name : '???'}</div>
    ${eq ? '<div class="eq-tag">✓</div>' : ''}
  </button>`;
}

// ---------- PASS ----------
function renderPass() {
  const el = $('screen-pass');
  const tier = passTier();
  const info = seasonInfo();
  const inTier = S.pass.xp - tier * PASS_XP_PER_TIER;
  const rows = [];
  for (let t = 1; t <= PASS_TIERS; t++) {
    const fr = PASS_FREE(t), pr = PASS_PREMIUM(t);
    const unlocked = t <= tier;
    const fC = S.pass.free.includes(t), pC = S.pass.prem.includes(t);
    const cellHtml = (r, claimed, prem) => {
      const item = r.item ? ITEM_BY_KEY[r.item] : null;
      const can = unlocked && !claimed && (!prem || S.pass.premium);
      return `<button class="pass-cell ${prem ? 'prem' : ''} ${claimed ? 'claimed' : ''} ${can ? 'can' : ''}" data-pass="${t}:${prem ? 1 : 0}" ${item ? `style="--rc:${RARITIES[item.rarity].color}"` : ''}>
        ${item ? preview(item, 44) : `<div class="pass-r">${rewardText(r)}</div>`}
        ${item ? `<div class="pass-r small">${item.name}</div>` : ''}
        ${claimed ? '<i>✓</i>' : prem && !S.pass.premium ? '<i>🔒</i>' : ''}
      </button>`;
    };
    rows.push(`<div class="pass-row ${unlocked ? 'unlocked' : ''}"><div class="tier-num">${t}</div>${cellHtml(fr, fC, false)}${cellHtml(pr, pC, true)}</div>`);
  }
  el.innerHTML = `<div class="page">
    <div class="pass-head">
      <h2>🎟️ Paw Pass · Season ${info.number}</h2>
      <div class="muted">Ends in ${fmtDuration(info.left)}</div>
      <div class="pass-progress"><b>Tier ${tier}/${PASS_TIERS}</b><div class="set-bar"><div style="width:${tier >= PASS_TIERS ? 100 : (inTier / PASS_XP_PER_TIER) * 100}%"></div></div><span>${tier >= PASS_TIERS ? 'MAX' : `${inTier}/${PASS_XP_PER_TIER} XP`}</span></div>
      ${S.pass.premium ? '<div class="prem-on">⭐ Premium active</div>' : `
        <button class="big-btn purple" data-act="buy-pass">Unlock Premium 💎${PASS_PRICE_GEMS}<small>2 exclusive cats · Mythic theme · Rainbow FX · 960+ 💎 back</small></button>`}
      <p class="muted small">Earn XP by playing and finishing missions.</p>
    </div>
    <div class="pass-cols"><span></span><b>FREE</b><b class="gold">PREMIUM</b></div>
    ${rows.join('')}
  </div>`;
  hydrate(el);
}

// ---------- DAILY MODALS ----------
function missionsModal() {
  const ms = S.daily.missions;
  const m = modal(`<h2>📋 Daily Missions</h2>
    <p class="muted">New missions in ${fmtDuration(msToMidnight())}</p>
    ${ms.map((x, i) => {
      const d = missionDef(x.id);
      return `<div class="mission ${x.claimed ? 'claimed' : ''}">
        <div><div>${d.text.replace('{n}', d.n.toLocaleString())}</div>
        <div class="set-bar"><div style="width:${(x.p / d.n) * 100}%"></div></div>
        <small>${Math.min(x.p, d.n).toLocaleString()}/${d.n.toLocaleString()} · ${rewardText(d.reward)} ⭐150</small></div>
        ${x.claimed ? '<span>✓</span>' : x.done ? `<button class="big-btn small green" data-m="${i}">Claim</button>` : ''}
      </div>`;
    }).join('')}`);
  m.querySelectorAll('[data-m]').forEach((b) => b.addEventListener('click', () => {
    const r = claimMission(Number(b.dataset.m));
    if (r) { sfx.coin(); toast(rewardText(r)); m.close(); missionsModal(); refreshTop(); rerender(); }
  }));
}

function spinModal() {
  const n = SPIN_SEGMENTS.length;
  const seg = 360 / n;
  const colors = ['#ff6a88', '#ffb400', '#3ddc84', '#2bb5ff', '#7a5cff', '#ff7ad9', '#ff9a3c', '#20c3c3'];
  const grad = SPIN_SEGMENTS.map((_, i) => `${colors[i]} ${i * seg}deg ${(i + 1) * seg}deg`).join(',');
  const m = modal(`<h2>🎡 Lucky Spin</h2>
    <div class="wheel-wrap"><div class="pointer">▼</div>
      <div class="wheel" style="background:conic-gradient(${grad})">
        ${SPIN_SEGMENTS.map((s, i) => `<div class="wl" style="transform:rotate(${i * seg + seg / 2}deg)"><span>${s.icon}${s.label}</span></div>`).join('')}
      </div></div>
    ${S.daily.spin ? '<button class="big-btn green" data-spin>SPIN!</button>' : `<button class="big-btn small purple" data-extra>Spin again 💎25</button><p class="muted">Free spin resets in ${fmtDuration(msToMidnight())}</p>`}`);
  const wheel = m.querySelector('.wheel');
  const doSpin = () => {
    const idx = spin();
    if (idx === null) return;
    m.querySelectorAll('[data-spin],[data-extra]').forEach((b) => (b.disabled = true));
    const final = 360 * 6 + (360 - (idx * seg + seg / 2));
    wheel.style.transition = 'transform 3.6s cubic-bezier(.12,.75,.12,1)';
    wheel.style.transform = `rotate(${final}deg)`;
    let ticks = 0;
    const t = setInterval(() => { sfx.spinTick(); if (++ticks > 24) clearInterval(t); }, 130);
    setTimeout(() => {
      sfx.coin(); confettiRain(40);
      toast(`You won ${rewardText(SPIN_SEGMENTS[idx].reward)}!`);
      refreshTop(); m.close(); spinModal(); rerender();
    }, 3800);
  };
  m.querySelector('[data-spin]')?.addEventListener('click', doSpin);
  m.querySelector('[data-extra]')?.addEventListener('click', () => {
    if (buyExtraSpin()) { refreshTop(); doSpin(); } else gemsModal('Not enough gems');
  });
}

export function loginModal() {
  const m = modal(`<h2>📅 Daily Rewards</h2>
    <div class="login-grid">${LOGIN_REWARDS.map((r, i) => {
      const past = i < S.loginDay || (i === S.loginDay && S.daily.loginClaimed);
      const today = i === S.loginDay && !S.daily.loginClaimed;
      return `<div class="login-day ${past ? 'past' : ''} ${today ? 'today' : ''} ${i === 6 ? 'big' : ''}"><b>Day ${i + 1}</b><div>${rewardText(r)}</div>${past ? '<i>✓</i>' : ''}</div>`;
    }).join('')}</div>
    ${S.daily.loginClaimed ? '<p class="muted">Come back tomorrow!</p>' : '<button class="big-btn green" data-claim>Claim</button>'}`);
  m.querySelector('[data-claim]')?.addEventListener('click', () => {
    const r = claimLogin();
    if (r) { sfx.coin(); confettiRain(40); toast(rewardText(r)); refreshTop(); m.close(); rerender(); }
  });
}

function settingsModal() {
  const m = modal(`<h2>⚙️ Settings</h2>
    <label class="toggle"><input type="checkbox" data-s="sound" ${S.settings.sound ? 'checked' : ''}> Sound</label>
    <label class="toggle"><input type="checkbox" data-s="haptics" ${S.settings.haptics ? 'checked' : ''}> Vibration</label>
    <div class="stats">
      <div>Games <b>${S.stats.games}</b></div><div>Lines <b>${S.stats.lines}</b></div>
      <div>Best combo <b>x${S.stats.bestCombo}</b></div><div>Perfect clears <b>${S.stats.perfects}</b></div>
      <div>Best classic <b>${(S.best.classic || 0).toLocaleString()}</b></div><div>Boxes opened <b>${S.stats.boxes}</b></div>
    </div>
    <button class="link danger" data-reset>Reset all progress</button>
    <p class="fine">Blockitty v1.0 · ${isDemo() ? 'Demo store' : 'Google Play Billing'}</p>`);
  m.querySelectorAll('[data-s]').forEach((c) => c.addEventListener('change', () => {
    S.settings[c.dataset.s] = c.checked; save(); setAudio(S.settings.sound, S.settings.haptics);
  }));
  m.querySelector('[data-reset]').addEventListener('click', () => {
    if (confirm('Delete ALL progress? This cannot be undone.')) { resetAll(); game.clearSavedRun(); location.reload(); }
  });
}

function profileModal() {
  modal(`<h2>Level ${S.level}</h2>
    <div class="set-bar"><div style="width:${(S.xp / xpForLevel(S.level)) * 100}%"></div></div>
    <p class="muted">${S.xp}/${xpForLevel(S.level)} XP to level ${S.level + 1} · each level gives 🪙 and 💎</p>
    <p>Collection: <b>${S.owned.length}</b> items · Yarn: <b>${S.yarn}</b> 🧶</p>`);
}

function powerOffer(id) {
  const p = POWERUPS[id];
  const m = modal(`<h2>${p.icon} ${p.name}</h2><p>${p.desc}</p>
    <div class="row"><button class="big-btn small" data-c="1">×1 🪙${p.coins}</button><button class="big-btn small green" data-c="3">×3 🪙${p.coins * 3}</button></div>`);
  m.querySelectorAll('[data-c]').forEach((b) => b.addEventListener('click', () => {
    if (buyPower(id, Number(b.dataset.c))) { sfx.coin(); refreshTop(); game.refresh(); m.close(); toast(`+${b.dataset.c} ${p.icon}`); rerender(); }
    else { sfx.invalid(); toast('Not enough coins 🪙'); }
  }));
}

// ---------- GAME FLOW ----------
function startGame(mode, resume = false) {
  closeAllModals();
  show('game');
  game.start(mode, resume);
}

export function gameHooks() {
  return {
    onPause() {
      const m = modal(`<h2>Paused</h2>
        <button class="big-btn green" data-close>▶ Resume</button>
        <button class="big-btn small" data-restart>Restart</button>
        <button class="big-btn small gray" data-home>Save &amp; Home</button>`);
      m.querySelector('[data-restart]').addEventListener('click', () => { m.close(); const run = game.current(); finishRun(game.end(), false); startGame(run.mode); });
      m.querySelector('[data-home]').addEventListener('click', () => { m.close(); show('home'); });
    },
    offerPower: powerOffer,
    onChallengeHit() {
      if (S.daily && !S.daily.challengeDone) {
        S.daily.challengeDone = true;
        grant(CHALLENGE_REWARD);
        confettiRain(100); sfx.perfect();
        toast(`Daily Challenge complete! ${rewardText(CHALLENGE_REWARD)}`);
        refreshTop();
      } else toast('Goal reached! 🏆');
    },
    onStuck({ canRevive, havePowers }) {
      const free = S.daily?.freeRevive;
      const m = modal(`<div class="stuck"><h2>No space left! 😿</h2>
        <div class="stuck-cat">${catSVG(equipped('cat').look, 'shock')}</div>
        <p>Score: <b>${game.current().score.toLocaleString()}</b></p>
        ${canRevive ? `<button class="big-btn green" data-rev>${free ? '🐾 Revive FREE' : `🐾 Revive 💎${REVIVE_GEMS}`}<small>Clears the center & new pieces</small></button>` : ''}
        ${havePowers ? '<button class="big-btn small" data-pw>Use a power-up</button>' : ''}
        <button class="big-btn small gray" data-end>End game</button></div>`, { dismiss: false });
      m.querySelector('[data-rev]')?.addEventListener('click', () => {
        if (free) { S.daily.freeRevive = false; save(); }
        else if (!spendGems(REVIVE_GEMS)) { gemsModal('Not enough gems to revive'); return; }
        m.close(); refreshTop(); game.revive();
      });
      m.querySelector('[data-pw]')?.addEventListener('click', () => m.close());
      m.querySelector('[data-end]').addEventListener('click', () => { m.close(); finishRun(game.end(), true); });
    },
  };
}

function finishRun(run, showResults) {
  if (!run) return;
  const res = finishGame({ mode: run.mode, score: run.score, lines: run.lines, pieces: run.pieces, bestCombo: run.bestCombo, powers: run.powers, multis: run.multis, perfects: run.perfects });
  refreshTop();
  if (!showResults) return;
  if (res.newBest) confettiRain(100);
  const mood = res.newBest ? 'love' : run.score > 500 ? 'happy' : 'sleepy';
  const m = modal(`<div class="results">
    <h2>${res.newBest ? '🏆 NEW BEST!' : 'Game Over'}</h2>
    <div class="stuck-cat">${catSVG(equipped('cat').look, mood)}</div>
    <div class="final-score">${run.score.toLocaleString()}</div>
    <div class="res-grid"><div>Lines<b>${run.lines}</b></div><div>Best combo<b>x${run.bestCombo}</b></div><div>Blocks<b>${run.pieces}</b></div></div>
    <div class="earned">+🪙 ${res.coins.toLocaleString()} &nbsp; +⭐ ${res.xp} XP</div>
    ${res.ups.map((u) => `<div class="lvlup">LEVEL UP → ${u.level}! ${rewardText(u.reward)}</div>`).join('')}
    ${missionsClaimable() ? '<div class="hint">📋 Mission complete — claim it!</div>' : ''}
    ${passClaimable() ? '<div class="hint">🎟️ New Paw Pass rewards!</div>' : ''}
    <button class="big-btn green" data-again>▶ Play again</button>
    <div class="row"><button class="big-btn small gray" data-home>Home</button><button class="big-btn small purple" data-box>🎁 Boxes</button></div>
  </div>`, { dismiss: false });
  if (res.ups.length) sfx.levelUp();
  m.querySelector('[data-again]').addEventListener('click', () => { m.close(); startGame(run.mode === 'challenge' ? 'challenge' : 'classic'); });
  m.querySelector('[data-home]').addEventListener('click', () => { m.close(); show('home'); });
  m.querySelector('[data-box]').addEventListener('click', () => { m.close(); show('boxes'); });
}

// ---------- global event delegation ----------
export function initUI() {
  document.addEventListener('click', (e) => {
    const t = e.target.closest('button, [data-act], [data-item], [data-buy]');
    if (!t || t.closest('#screen-game')) return;
    const d = t.dataset;
    if (d.nav) { sfx.tap(); show(d.nav); return; }
    if (d.navGo) { sfx.tap(); show(d.navGo); return; }
    if (d.buy) { sfx.tap(); owns(d.buy) ? itemModal(d.buy) : tryBuy(d.buy); return; }
    if (d.item) { sfx.tap(); itemModal(d.item); return; }
    if (d.powerBuy) { if (buyPower(d.powerBuy, 3)) { sfx.coin(); toast(`+3 ${POWERUPS[d.powerBuy].icon}`); refreshTop(); rerender(); } else { sfx.invalid(); toast('Not enough coins 🪙'); } return; }
    if (d.iap) { if (!t.closest('.modal')) buyGems(d.iap); return; }
    if (d.open) { sfx.tap(); doOpen(d.open); return; }
    if (d.tab) { sfx.tap(); colTab = d.tab; renderCollection(); return; }
    if (d.claimSet) { const r = claimSet(d.claimSet); if (r) { sfx.perfect(); confettiRain(120); toast(`Set complete! ${rewardText(r)}`); refreshTop(); rerender(); } return; }
    if (d.pass) {
      const [tier, prem] = d.pass.split(':').map(Number);
      if (prem && !S.pass.premium) { sfx.tap(); toast('Unlock Premium to claim'); return; }
      const r = claimPass(tier, !!prem);
      if (r) { sfx.coin(); if (r.item) revealSingle(ITEM_BY_KEY[r.item]); else toast(rewardText(r)); refreshTop(); rerender(); }
      return;
    }
    switch (d.act) {
      case 'play': sfx.tap(); game.clearSavedRun(); startGame('classic'); break;
      case 'continue': sfx.tap(); startGame(null, true); break;
      case 'challenge': sfx.tap(); game.clearSavedRun(); startGame('challenge'); break;
      case 'missions': sfx.tap(); missionsModal(); break;
      case 'spin': sfx.tap(); spinModal(); break;
      case 'login': sfx.tap(); loginModal(); break;
      case 'starter': sfx.tap(); buyStarter(); break;
      case 'gems': sfx.tap(); gemsModal(); break;
      case 'odds': sfx.tap(); oddsModal(); break;
      case 'pet': sfx.meow(); t.innerHTML = catSVG(equipped('cat').look, 'love', 'idle-bob'); setTimeout(() => { if (t.isConnected) t.innerHTML = catSVG(equipped('cat').look, 'idle', 'idle-bob'); }, 1200); break;
      case 'buy-pass':
        if (buyPremiumPass()) { sfx.perfect(); confettiRain(120); toast('Premium Paw Pass unlocked! ⭐'); refreshTop(); rerender(); }
        else gemsModal(`You need 💎${PASS_PRICE_GEMS - S.gems} more gems`);
        break;
      default:
    }
  });
  $('cur-gems').addEventListener('click', () => { sfx.tap(); gemsModal(); });
  $('btn-settings').addEventListener('click', () => { sfx.tap(); settingsModal(); });
  $('btn-profile').addEventListener('click', () => { sfx.tap(); profileModal(); });
}

export { dayKey };
