// Menus, shop, collection, pass, rewards and every modal. Design rule:
// one obvious action per screen, everything else one tap away.

import {
  S, save, owns, equip, equipped, dailyShop, shopPrice, buyItem, buyPower, openBox, setProgress, claimSet,
  setsClaimable, claimMission, missionDef, missionsClaimable, spin, grantAdSpin, claimLogin, passTier, claimPass,
  claimAllPass, buyPremiumPass, passClaimable, seasonInfo, fmtDuration, msToMidnight, xpForLevel, rewardText, grant,
  spendGems, newItemsCount, markSeen, resetAll, recordPurchase, finishGame, rewardsBadge, streakAlive, dayKey,
} from './state.js';
import {
  CATS, SKINS, THEMES, EFFECTS, SETS, RARITIES, RARITY_ORDER, ITEM_BY_KEY, itemKey, BOX, PITY_EPIC,
  PITY_LEGENDARY, POWERUPS, GEM_PACKS, STARTER_PACK, NO_ADS, PASS_PRICE_GEMS, PASS_TIERS, PASS_XP_PER_TIER,
  PASS_FREE, PASS_PREMIUM, LOGIN_REWARDS, SPIN_SEGMENTS, CHALLENGE_TARGET, CHALLENGE_REWARD, REVIVE_GEMS,
} from './data.js';
import { catSVG } from './cats.js';
import { skinPreview } from './skins.js';
import { sound, setAudio, playMusic } from './audio.js';
import { confettiRain } from './fx.js';
import { purchase, isDemo, localPrice, restorePurchases } from './billing.js';
import { showRewarded, maybeInterstitial } from './ads.js';
import { scoreCard, shareContent, challengeLink } from './share.js';
import { askNotifications, scheduleReminders } from './notify.js';
import { isNative, plugin, PLAY_URL, SUPPORT_EMAIL, VERSION } from './config.js';
import * as game from './game.js';

const $ = (id) => document.getElementById(id);
const FX_ICONS = { sparkle: '✨', confetti: '🎊', hearts: '💖', paws: '🐾', fish: '🐟', stars: '🌟', bubbles: '🫧', rainbow: '🌈' };
const TYPE_NAMES = { cat: 'Cat', skin: 'Block Skin', theme: 'Theme', fx: 'Blast Effect' };
const fmt = (n) => n.toLocaleString('en-US');
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
  wrap.innerHTML = `<div class="modal ${cls}" role="dialog">${dismiss ? '<button class="modal-x" data-close aria-label="Close">✕</button>' : ''}${html}</div>`;
  let closed = false;
  const close = () => { if (closed) return; closed = true; wrap.remove(); onClose && onClose(); };
  wrap.addEventListener('click', (e) => {
    if ((dismiss && e.target === wrap) || e.target.closest('[data-close]')) { sound.tap(); close(); }
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
  return p.coins ? `🪙 ${fmt(p.coins)}` : `💎 ${fmt(p.gems)}`;
}

function bumpCurrency(id) {
  const el = $(id)?.parentElement;
  if (!el) return;
  el.classList.remove('bump'); void el.offsetWidth; el.classList.add('bump');
}

// ---------- top bar & nav ----------
export function refreshTop() {
  const c = $('coins'), g = $('gems');
  if (c.textContent !== fmt(S.coins)) { c.textContent = fmt(S.coins); bumpCurrency('coins'); }
  if (g.textContent !== fmt(S.gems)) { g.textContent = fmt(S.gems); bumpCurrency('gems'); }
  $('lvl').textContent = S.level;
  $('lvl-ring').style.setProperty('--p', `${Math.min(100, (S.xp / xpForLevel(S.level)) * 100)}`);
  $('dot-pass').classList.toggle('on', passClaimable() > 0);
  $('dot-cats').classList.toggle('on', S.freePulls > 0 || newItemsCount() > 0 || setsClaimable() > 0);
  $('dot-shop').classList.toggle('on', !S.purchases.starter && S.stats.games >= 2);
  document.body.style.background = equipped('theme').bg;
  document.body.classList.toggle('first-run', S.stats.games === 0);
}

export function show(name) {
  currentScreen = name;
  document.querySelectorAll('.screen').forEach((s) => s.classList.toggle('active', s.id === `screen-${name}`));
  document.querySelectorAll('[data-nav]').forEach((b) => b.classList.toggle('active', b.dataset.nav === name));
  document.body.classList.toggle('in-game', name === 'game');
  clearInterval(shopTimer);
  const renderers = { home: renderHome, cats: renderCats, shop: renderShop, pass: renderPass };
  if (renderers[name]) { renderers[name](); playMusic('menu'); }
  refreshTop();
}

export function rerender() { if (currentScreen !== 'game') show(currentScreen); else refreshTop(); }

// ---------- HOME ----------
function renderHome() {
  const catItem = equipped('cat');
  const badge = rewardsBadge();
  const streak = streakAlive();
  const saved = game.hasSavedRun();
  const challengeDone = S.daily?.challengeDone;
  $('screen-home').innerHTML = `
    <div class="home">
      <div class="home-top">
        <div class="streak ${streak ? 'on' : ''}" title="Daily streak">🔥 <b>${streak}</b> <span>day${streak === 1 ? '' : 's'}</span></div>
        <button class="icon-btn light" data-act="settings" aria-label="Settings">⚙️</button>
      </div>
      <h1 class="logo">Block<span>itty</span></h1>
      <div class="hero-cat" data-act="pet">${catSVG(catItem.look, 'idle', 'idle-bob')}<div class="shadow"></div></div>
      <div class="best-line">👑 Best <b>${fmt(S.best.classic || 0)}</b></div>
      <button class="big-btn play" data-act="${saved ? 'continue' : 'play'}">${saved ? '▶ CONTINUE' : '▶ PLAY'}</button>
      ${saved ? '<button class="link" data-act="play">Start a new game</button>' : ''}
      <div class="home-row">
        <button class="tile ${challengeDone ? 'done' : ''}" data-act="challenge"><span>🏆</span><b>Daily</b><small>${challengeDone ? 'Done ✓' : `💎${CHALLENGE_REWARD.gems}`}</small></button>
        <button class="tile" data-act="rewards"><span>🎁</span><b>Rewards</b><small>${badge ? `${badge} ready` : 'Come back later'}</small>${badge ? `<i class="badge">${badge}</i>` : ''}</button>
        <button class="tile" data-act="share-invite"><span>💌</span><b>Invite</b><small>Challenge friends</small></button>
      </div>
      ${!isNative() && !matchMedia('(display-mode: standalone)').matches ? '<a class="get-app" href="' + PLAY_URL + '" target="_blank" rel="noopener">📲 Get the free app</a>' : ''}
    </div>`;
}

// ---------- REWARDS (one sheet for every daily thing) ----------
function rewardsModal() {
  const d = S.daily;
  const m = modal(`
    <h2>🎁 Daily Rewards</h2>
    <div class="login-strip">${LOGIN_REWARDS.map((r, i) => {
      const past = i < S.loginDay || (i === S.loginDay && d.loginClaimed);
      const today = i === S.loginDay && !d.loginClaimed;
      return `<div class="login-day ${past ? 'past' : ''} ${today ? 'today' : ''}"><b>${i + 1}</b><div>${rewardText(r).split('  ')[0]}</div></div>`;
    }).join('')}</div>
    ${d.loginClaimed ? '' : '<button class="big-btn small green" data-r="login">Claim day ' + (S.loginDay + 1) + '</button>'}
    <div class="reward-row">
      <button class="tile" data-r="spin"><span>🎡</span><b>Lucky Spin</b><small>${d.spin ? 'FREE' : d.adSpin ? 'Tomorrow' : '▶ Watch ad'}</small></button>
      <button class="tile" data-r="box"><span>📦</span><b>Free Box</b><small>${S.freePulls > 0 ? `${S.freePulls} ready` : d.adBox ? 'Tomorrow' : '▶ Watch ad'}</small></button>
    </div>
    <h3>Missions <small class="muted">reset in ${fmtDuration(msToMidnight())}</small></h3>
    ${d.missions.map((x, i) => {
      const def = missionDef(x.id);
      return `<div class="mission ${x.claimed ? 'claimed' : ''}">
        <div><div>${def.text.replace('{n}', fmt(def.n))}</div>
        <div class="bar"><div style="width:${(x.p / def.n) * 100}%"></div></div>
        <small>${rewardText(def.reward)} · ⭐150</small></div>
        ${x.claimed ? '<span class="ok">✓</span>' : x.done ? `<button class="big-btn small green" data-m="${i}">Claim</button>` : `<span class="muted">${fmt(Math.min(x.p, def.n))}/${fmt(def.n)}</span>`}
      </div>`;
    }).join('')}`, { onClose: rerender });
  m.querySelector('[data-r="login"]')?.addEventListener('click', () => {
    const r = claimLogin();
    if (r) { sound.coin(); confettiRain(40); toast(rewardText(r)); refreshTop(); m.close(); rewardsModal(); }
  });
  m.querySelectorAll('[data-m]').forEach((b) => b.addEventListener('click', () => {
    const r = claimMission(Number(b.dataset.m));
    if (r) { sound.coin(); toast(rewardText(r)); refreshTop(); m.close(); rewardsModal(); }
  }));
  m.querySelector('[data-r="spin"]').addEventListener('click', async () => {
    if (!d.spin) {
      if (d.adSpin) { toast('Come back tomorrow!'); return; }
      if (!(await showRewarded()) || !grantAdSpin()) return;
    }
    m.close(); spinModal();
  });
  m.querySelector('[data-r="box"]').addEventListener('click', async () => {
    if (S.freePulls > 0) { m.close(); doOpen('free'); return; }
    if (d.adBox) { toast('Come back tomorrow!'); return; }
    if (await showRewarded()) { m.close(); doOpen('ad'); }
  });
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
      </div><div class="hub">🐾</div></div>
    <button class="big-btn green" data-spin ${S.daily.spin ? '' : 'disabled'}>SPIN!</button>`, { onClose: rerender });
  const wheel = m.querySelector('.wheel');
  m.querySelector('[data-spin]').addEventListener('click', (e) => {
    const idx = spin();
    if (idx === null) return;
    e.target.disabled = true;
    const final = 360 * 6 + (360 - (idx * seg + seg / 2));
    wheel.style.transition = 'transform 3.6s cubic-bezier(.12,.75,.12,1)';
    wheel.style.transform = `rotate(${final}deg)`;
    let ticks = 0;
    const t = setInterval(() => { sound.tick(); if (++ticks > 24) clearInterval(t); }, 130);
    setTimeout(() => {
      sound.coin(); confettiRain(50);
      toast(`You won ${rewardText(SPIN_SEGMENTS[idx].reward)}!`);
      refreshTop();
      setTimeout(() => m.close(), 900);
    }, 3800);
  });
}

// ---------- CATS (collection + Mystery Box) ----------
let colTab = 'cats';
function renderCats() {
  const el = $('screen-cats');
  const tabs = [['cats', '🐱 Cats'], ['skin', '🧱 Blocks'], ['theme', '🖼️ Themes'], ['fx', '✨ Effects']];
  const total = CATS.length + SKINS.length + THEMES.length + EFFECTS.length;
  const pityE = PITY_EPIC - S.pity.epic;
  let body;
  if (colTab === 'cats') {
    body = [...SETS, { id: 'exclusive', name: 'Exclusives' }].map((set) => {
      const p = setProgress(set.id);
      const claimed = S.setsClaimed.includes(set.id);
      const complete = p.have === p.total;
      return `<div class="set">
        <div class="set-head"><h3>${set.name}</h3><span>${p.have}/${p.total}</span></div>
        ${set.reward ? `<div class="bar"><div style="width:${(p.have / p.total) * 100}%"></div></div>
        <div class="set-reward">${claimed ? 'Set reward claimed ✓' : complete ? `<button class="big-btn small green" data-claim-set="${set.id}">Claim ${rewardText(set.reward)}</button>` : `Complete the set: ${rewardText(set.reward)}`}</div>` : ''}
        <div class="grid four">${p.cats.map(cardHtml).join('')}</div>
      </div>`;
    }).join('');
  } else {
    const list = { skin: SKINS, theme: THEMES, fx: EFFECTS }[colTab];
    body = `<div class="grid four">${list.map(cardHtml).join('')}</div>`;
  }
  el.innerHTML = `<div class="page">
    <div class="box-card">
      <div class="box-art"><div class="box-lid"></div><div class="box-body">?</div></div>
      <div class="box-info">
        <h2>${BOX.name}</h2>
        <p>Cats, blocks, themes & effects. Epic+ in <b>${pityE}</b> opens.</p>
        <div class="row">
          ${S.freePulls > 0 ? `<button class="big-btn small green" data-open="free">FREE ×${S.freePulls}</button>` : `<button class="big-btn small" data-open="g1">💎${BOX.price}</button>`}
          <button class="big-btn small purple" data-open="g10">×10 💎${BOX.price10}</button>
        </div>
        <button class="link small" data-act="odds">Drop rates</button>
      </div>
    </div>
    <div class="col-head"><h2>Collection</h2><span>${S.owned.length}/${total}</span></div>
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

function itemModal(key) {
  const it = ITEM_BY_KEY[key];
  const own = owns(key);
  const price = shopPrice(it);
  const isEq = S.equip[it.type] === it.id;
  const inShop = dailyShop().some((x) => itemKey(x) === key);
  const how = it.exclusive === 'pass' ? '🎟️ Paw Pass exclusive' : it.exclusive === 'starter' ? '🎁 Starter Pack exclusive' : inShop ? '🛍️ In today’s shop' : '📦 Found in Mystery Boxes';
  const m = modal(`
    <div class="item-detail" style="--rc:${RARITIES[it.rarity].color}">
      <div class="detail-prev">${preview(it, 150)}</div>
      <h2>${own ? it.name : '???'}</h2>
      <div>${rarityBadge(it.rarity)} <span class="muted">${TYPE_NAMES[it.type]}</span></div>
      ${own
        ? (isEq ? '<button class="big-btn small done" disabled>Equipped ✓</button>' : '<button class="big-btn small green" data-eq>Use it</button>')
        : `${inShop && price ? `<button class="big-btn small" data-buyit>Buy ${priceTag(price)}</button>` : ''}<p class="muted">${how}</p>`}
    </div>`);
  m.querySelector('[data-eq]')?.addEventListener('click', () => {
    equip(it.type, it.id); sound.coin(); if (it.type === 'cat') sound.meow(); toast(`${it.name} equipped!`); m.close(); rerender();
  });
  m.querySelector('[data-buyit]')?.addEventListener('click', () => { m.close(); tryBuy(key); });
}

function tryBuy(key) {
  const it = ITEM_BY_KEY[key];
  if (owns(key)) { itemModal(key); return; }
  const price = shopPrice(it);
  if (buyItem(key)) {
    sound.coin();
    revealSingle(it);
    rerender();
  } else if (price.gems) {
    sound.invalid();
    gemsModal(`You need 💎${fmt(price.gems - S.gems)} more`);
  } else {
    sound.invalid();
    toast('Not enough coins 🪙 – play a game to earn more!');
  }
}

function revealSingle(it) {
  confettiRain(60);
  sound.reveal(RARITY_ORDER.indexOf(it.rarity));
  const m = modal(`
    <div class="reveal-one" style="--rc:${RARITIES[it.rarity].color}">
      <div class="rays"></div>
      ${preview(it, 170)}
      <h2>${it.name}</h2>${rarityBadge(it.rarity)}
      <button class="big-btn small green" data-eq>Use it now</button>
    </div>`, { cls: 'glow' });
  m.querySelector('[data-eq]').addEventListener('click', () => { equip(it.type, it.id); m.close(); rerender(); toast('Equipped!'); });
}

function oddsModal() {
  modal(`<h2>Mystery Box drop rates</h2>
    <table class="odds"><tr><th>Rarity</th><th>Chance</th></tr>
    ${RARITY_ORDER.map((r) => `<tr><td>${rarityBadge(r)}</td><td>${RARITIES[r].rate}%</td></tr>`).join('')}</table>
    <p class="muted">Epic or better guaranteed at least every ${PITY_EPIC} opens, Legendary or better within ${PITY_LEGENDARY}. Items you don't own yet are favored. Duplicates turn into coins.</p>`);
}

function doOpen(kind) {
  const res = kind === 'free' ? openBox(1, 'free') : kind === 'ad' ? openBox(1, 'ad') : kind === 'g10' ? openBox(10, 'gems') : openBox(1, 'gems');
  if (!res) { sound.invalid(); gemsModal('Not enough gems for this box'); return; }
  refreshTop();
  revealBoxes(res);
}

function revealBoxes(results) {
  const best = Math.max(...results.map((r) => RARITY_ORDER.indexOf(r.item.rarity)));
  const m = modal(`
    <div class="opening" style="--rc:${RARITIES[RARITY_ORDER[best]].color}">
      <div class="box-art big shake"><div class="box-lid"></div><div class="box-body">?</div></div>
      <p>Tap to open!</p>
    </div>`, { cls: 'reveal', dismiss: false });
  const opening = m.querySelector('.opening');
  const go = () => {
    if (!opening.isConnected) return;
    opening.removeEventListener('click', go);
    sound.reveal(best);
    if (best >= 3) confettiRain(140);
    const modalEl = m.querySelector('.modal');
    modalEl.innerHTML = `
      <h2>${results.length > 1 ? 'Your haul!' : best >= 3 ? 'WOW!' : 'You got…'}</h2>
      <div class="reveal-grid ${results.length > 1 ? 'many' : ''}">
        ${results.map((r, i) => `<div class="reveal-card r-${r.item.rarity}" style="--rc:${RARITIES[r.item.rarity].color};animation-delay:${i * 0.12}s">
          ${r.isNew ? '<div class="new">NEW!</div>' : ''}
          ${preview(r.item, results.length > 1 ? 50 : 150)}
          <div class="card-name">${r.item.name}</div>
          ${rarityBadge(r.item.rarity)}
          ${r.dup ? `<div class="dup">+${fmt(r.coins)} 🪙</div>` : ''}
        </div>`).join('')}
      </div>
      <div class="row">
        ${results.length === 1 && results[0].isNew ? '<button class="big-btn small purple" data-use>Use it</button>' : ''}
        <button class="big-btn small green" data-close>Awesome!</button>
      </div>`;
    hydrate(modalEl);
    modalEl.querySelector('[data-use]')?.addEventListener('click', () => { const it = results[0].item; equip(it.type, it.id); m.close(); rerender(); toast('Equipped!'); });
    modalEl.querySelector('[data-close]').addEventListener('click', () => { m.close(); rerender(); });
  };
  opening.addEventListener('click', go);
  setTimeout(go, 1500);
}

// ---------- SHOP ----------
function renderShop() {
  const items = dailyShop();
  const el = $('screen-shop');
  el.innerHTML = `
    <div class="page">
      ${!S.purchases.starter ? `
      <button class="offer" data-act="starter">
        <div class="offer-tag">ONE-TIME OFFER</div>
        <div class="offer-body">
          <div class="offer-cat">${catSVG(ITEM_BY_KEY['cat:lucky'].look, 'happy')}</div>
          <div><h3>Starter Pack</h3><p>Lucky (Epic cat) · Candy Gloss blocks · 💎500 · 🪙5,000</p>
          <div class="offer-price">${localPrice(STARTER_PACK.sku, STARTER_PACK.price)}</div></div>
        </div>
      </button>` : ''}
      ${!S.purchases.noAds ? `
      <button class="offer slim" data-act="noads">
        <div class="offer-body"><div class="noads-ico">🚫📺</div><div><h3>No Ads</h3><p>Remove all forced ads forever + 💎${NO_ADS.gems}</p></div>
        <div class="offer-price">${localPrice(NO_ADS.sku, NO_ADS.price)}</div></div>
      </button>` : ''}
      <h2>Daily Deals <span class="timer" id="shop-timer">${fmtDuration(msToMidnight())}</span></h2>
      <div class="grid">
        ${items.map((it, i) => {
          const key = itemKey(it), own = owns(key);
          return `<button class="card ${i === 0 ? 'featured' : ''} ${own ? 'owned' : ''}" style="--rc:${RARITIES[it.rarity].color}" data-buy="${key}">
            ${i === 0 ? '<div class="ribbon">HOT</div>' : ''}
            ${preview(it, i === 0 ? 110 : 76)}
            <div class="card-name">${it.name}</div>
            <div class="card-type">${TYPE_NAMES[it.type]} · ${RARITIES[it.rarity].name}</div>
            <div class="price">${own ? 'Owned ✓' : priceTag(shopPrice(it))}</div>
          </button>`;
        }).join('')}
      </div>
      <h2>Gems ${isDemo() ? '<span class="demo-tag">DEMO · no charges</span>' : ''}</h2>
      <div class="grid three">
        ${GEM_PACKS.map((g, i) => `<button class="card gem-card" data-iap="${g.sku}">
          ${g.tag ? `<div class="ribbon">${g.tag}</div>` : ''}
          <div class="gem-ico">${['💎', '💎💎', '💰', '🏆', '👑'][i]}</div>
          <div class="card-name">${fmt(g.gems + (g.bonus || 0))}</div>
          <div class="card-type">${g.bonus ? `+${fmt(g.bonus)} bonus` : g.label}</div>
          <div class="price iap">${localPrice(g.sku, g.price)}</div></button>`).join('')}
      </div>
      <h2>Power-ups</h2>
      <div class="grid three">
        ${Object.entries(POWERUPS).map(([id, p]) => `<button class="card" data-power-buy="${id}">
          <div class="pw-icon">${p.icon}</div><div class="card-name">${p.name} ×3</div><div class="card-type">${p.desc}<br>You have ${S.power[id]}</div>
          <div class="price">🪙 ${fmt(p.coins * 3)}</div></button>`).join('')}
      </div>
      <p class="fine">Cosmetics never change your score. Box odds are listed on the box.</p>
    </div>`;
  hydrate(el);
  shopTimer = setInterval(() => { const t = $('shop-timer'); if (t) t.textContent = fmtDuration(msToMidnight()); }, 1000);
}

// ---------- IAP ----------
function demoConfirm(label, price) {
  return new Promise((resolve) => {
    const m = modal(`
      <h2>Confirm purchase</h2>
      <p>${label}</p>
      <p class="big-price">${price}</p>
      <p class="demo-note">DEMO: nothing is charged here. In the Play Store app this opens Google Play Billing.</p>
      <div class="row"><button class="big-btn small gray" data-no>Cancel</button><button class="big-btn small green" data-yes>Buy</button></div>`,
    { onClose: () => resolve(false) });
    m.querySelector('[data-yes]').addEventListener('click', () => { m.remove(); resolve(true); });
    m.querySelector('[data-no]').addEventListener('click', () => { m.remove(); resolve(false); });
  });
}

// Called by billing once per completed purchase (and on restore for No Ads).
export function grantSku(sku, restored = false) {
  const pack = GEM_PACKS.find((g) => g.sku === sku);
  if (pack) {
    const n = pack.gems + (pack.bonus || 0);
    grant({ gems: n });
    toast(`+${fmt(n)} 💎 Thank you!`);
  } else if (sku === STARTER_PACK.sku) {
    if (S.purchases.starter) return;
    S.purchases.starter = true;
    grant({ gems: STARTER_PACK.gems, coins: STARTER_PACK.coins, item: `cat:${STARTER_PACK.cat}` });
    grant({ item: `skin:${STARTER_PACK.skin}` });
    revealSingle(ITEM_BY_KEY['cat:lucky']);
  } else if (sku === NO_ADS.sku) {
    if (S.purchases.noAds) return;
    S.purchases.noAds = true;
    if (!restored) { grant({ gems: NO_ADS.gems }); toast('Ads removed forever. Thank you! 💖'); }
    save();
  }
  if (!restored) { recordPurchase(sku); sound.coin(); confettiRain(70); }
  refreshTop(); rerender();
}

async function buy(sku, label, price) {
  await purchase(sku, () => demoConfirm(label, price));
}

function gemsModal(reason = '') {
  const m = modal(`
    <h2>💎 Get Gems</h2>${reason ? `<p class="warn">${reason}</p>` : ''}
    ${isDemo() ? '<p class="demo-note">DEMO · no charges</p>' : ''}
    <div class="grid three">${GEM_PACKS.map((g) => `<button class="card gem-card" data-iap="${g.sku}">${g.tag ? `<div class="ribbon">${g.tag}</div>` : ''}
      <div class="card-name">💎 ${fmt(g.gems + (g.bonus || 0))}</div><div class="price iap">${localPrice(g.sku, g.price)}</div></button>`).join('')}</div>`);
  m.querySelectorAll('[data-iap]').forEach((b) => b.addEventListener('click', () => { m.close(); buyGems(b.dataset.iap); }));
}

function buyGems(sku) {
  const g = GEM_PACKS.find((x) => x.sku === sku);
  buy(sku, `${fmt(g.gems + (g.bonus || 0))} Gems`, localPrice(sku, g.price));
}

// ---------- PASS ----------
function renderPass() {
  const el = $('screen-pass');
  const tier = passTier();
  const info = seasonInfo();
  const inTier = S.pass.xp - tier * PASS_XP_PER_TIER;
  const claimable = passClaimable();
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
      <div class="muted light">Ends in ${fmtDuration(info.left)}</div>
      <div class="pass-progress"><b>Tier ${tier}/${PASS_TIERS}</b><div class="bar"><div style="width:${tier >= PASS_TIERS ? 100 : (inTier / PASS_XP_PER_TIER) * 100}%"></div></div><span>${tier >= PASS_TIERS ? 'MAX' : `${inTier}/${PASS_XP_PER_TIER}`}</span></div>
      ${claimable ? `<button class="big-btn small green" data-act="claim-all">Claim ${claimable} reward${claimable > 1 ? 's' : ''}</button>` : ''}
      ${S.pass.premium ? '<div class="prem-on">⭐ Premium active</div>' : `
        <button class="big-btn purple" data-act="buy-pass">Go Premium 💎${PASS_PRICE_GEMS}<small>2 exclusive cats · Mythic theme · 960+ 💎 back</small></button>`}
      <p class="muted light small">Play games and finish missions to earn XP.</p>
    </div>
    <div class="pass-cols"><span></span><b>FREE</b><b class="gold">PREMIUM</b></div>
    ${rows.join('')}
  </div>`;
  hydrate(el);
}

// ---------- settings ----------
function settingsModal() {
  const m = modal(`<h2>⚙️ Settings</h2>
    <label class="toggle"><span>🎵 Music</span><input type="checkbox" data-s="music" ${S.settings.music ? 'checked' : ''}></label>
    <label class="toggle"><span>🔊 Sounds</span><input type="checkbox" data-s="sound" ${S.settings.sound ? 'checked' : ''}></label>
    <label class="toggle"><span>📳 Vibration</span><input type="checkbox" data-s="haptics" ${S.settings.haptics ? 'checked' : ''}></label>
    ${isNative() ? `<label class="toggle"><span>🔔 Reminders</span><input type="checkbox" data-s="notif" ${S.settings.notif ? 'checked' : ''}></label>` : ''}
    <div class="stats">
      <div>Games<b>${fmt(S.stats.games)}</b></div><div>Lines<b>${fmt(S.stats.lines)}</b></div>
      <div>Best combo<b>x${S.stats.bestCombo}</b></div><div>Kittens saved<b>${fmt(S.stats.rescued || 0)}</b></div>
    </div>
    ${isNative() ? '<button class="big-btn small gray" data-restore>Restore purchases</button>' : ''}
    <div class="links"><a href="privacy.html" target="_blank" rel="noopener">Privacy Policy</a> · <a href="mailto:${SUPPORT_EMAIL}?subject=Blockitty%20feedback">Contact</a></div>
    <button class="link danger" data-reset>Reset progress</button>
    <p class="fine">Blockitty v${VERSION} · ${isDemo() ? 'Demo store' : 'Google Play'}<br>© 2026 Filippo Casali. All rights reserved.</p>`);
  m.querySelectorAll('[data-s]').forEach((c) => c.addEventListener('change', () => {
    S.settings[c.dataset.s] = c.checked; save();
    setAudio(S.settings);
    if (c.dataset.s === 'music' && c.checked) playMusic('menu');
    if (c.dataset.s === 'notif' && c.checked) { S.settings.notifAsked = false; askNotifications(); } else if (c.dataset.s === 'notif') scheduleReminders();
  }));
  m.querySelector('[data-restore]')?.addEventListener('click', async () => { await restorePurchases(); toast('Purchases restored'); });
  m.querySelector('[data-reset]').addEventListener('click', () => {
    if (confirm('Delete ALL progress? This cannot be undone.')) { resetAll(); game.clearSavedRun(); location.reload(); }
  });
}

function powerOffer(id) {
  const p = POWERUPS[id];
  const m = modal(`<h2>${p.icon} ${p.name}</h2><p>${p.desc}</p>
    <div class="row"><button class="big-btn small" data-c="1">×1 🪙${fmt(p.coins)}</button><button class="big-btn small green" data-c="3">×3 🪙${fmt(p.coins * 3)}</button></div>
    <button class="big-btn small purple" data-ad>▶ Watch ad for 1 free</button>`);
  m.querySelectorAll('[data-c]').forEach((b) => b.addEventListener('click', () => {
    if (buyPower(id, Number(b.dataset.c))) { sound.coin(); refreshTop(); game.refresh(); m.close(); toast(`+${b.dataset.c} ${p.icon}`); }
    else { sound.invalid(); toast('Not enough coins 🪙'); }
  }));
  m.querySelector('[data-ad]').addEventListener('click', async () => {
    m.close();
    if (await showRewarded()) { S.power[id] += 1; save(); game.refresh(); toast(`+1 ${p.icon}`); }
  });
}

// ---------- sharing / virality ----------
function askName() {
  return new Promise((resolve) => {
    if (S.name) { resolve(S.name); return; }
    const m = modal(`<h2>Your player name</h2><p class="muted">Friends will see it on your challenge.</p>
      <input class="name-input" maxlength="16" placeholder="e.g. CatQueen" autocomplete="nickname">
      <button class="big-btn small green" data-ok>Continue</button>`, { onClose: () => resolve(S.name || 'A friend') });
    const inp = m.querySelector('input');
    setTimeout(() => inp.focus(), 50);
    m.querySelector('[data-ok]').addEventListener('click', () => {
      S.name = inp.value.trim().replace(/[<>&"]/g, '').slice(0, 16) || 'A friend';
      save(); m.close();
    });
  });
}

async function shareRun(run) {
  const name = await askName();
  const url = challengeLink({ seed: run.seed, score: run.score, name });
  const canvas = await scoreCard({ score: run.score, best: S.best.classic, look: equipped('cat').look, headline: `${name} scored`, sub: 'Same pieces. Your turn!' });
  const saved = run.rescued ? ` and saved ${run.rescued} kitten${run.rescued > 1 ? 's' : ''}` : '';
  const res = await shareContent({ text: `I scored ${fmt(run.score)}${saved} in Blockitty 🐱 Same pieces, can you beat me?`, url, canvas });
  afterShare(res);
}

async function shareInvite() {
  const name = await askName();
  const seed = (Math.random() * 2 ** 32) >>> 0;
  const score = S.best.classic || 0;
  const url = challengeLink({ seed, score: Math.max(score, 500), name });
  const res = await shareContent({ text: `Play Blockitty with me! Cute cats + block puzzle 🐱🧱 Beat ${fmt(Math.max(score, 500))}:`, url });
  afterShare(res);
}

function afterShare(res) {
  if (res === 'cancelled') return;
  S.stats.shares += 1;
  // First share of the day pays out: rewards spreading the word.
  if (S.daily && !S.daily.shared) { S.daily.shared = true; grant({ gems: 10 }); toast('Thanks for sharing! +💎10'); }
  else toast(res === 'copied' ? 'Link copied!' : 'Shared!');
  save(); refreshTop();
}

export function incomingChallenge(ch) {
  const m = modal(`<div class="duel">
    <div class="stuck-cat">${catSVG(ITEM_BY_KEY['cat:socks'].look, 'wow')}</div>
    <h2>${ch.name} challenges you!</h2>
    <p>Same starting pieces. Beat <b>${fmt(ch.score)}</b> points.</p>
    <button class="big-btn green" data-go>▶ Accept</button></div>`);
  m.querySelector('[data-go]').addEventListener('click', () => {
    m.close();
    startGame({ mode: 'duel', seed: ch.seed, target: ch.score, rival: ch.name });
  });
}

// Google Play In-App Review: native sheet, no custom pre-prompt (Play guidelines
// forbid steering ratings). Google decides whether it actually appears.
function ratePrompt() {
  const R = plugin('InAppReview');
  if (S.rated || S.stats.games < 3 || !isNative() || !R) return false;
  S.rated = true; save();
  R.requestReview().catch(() => {});
  return true;
}

// ---------- GAME FLOW ----------
export function startGame(opts) {
  closeAllModals();
  show('game');
  game.start(opts);
}

export function gameHooks() {
  return {
    onPause() {
      const m = modal(`<h2>Paused</h2>
        <button class="big-btn green" data-close>▶ Resume</button>
        <button class="big-btn small gray" data-home>Save &amp; exit</button>
        <button class="link" data-restart>Restart</button>`);
      m.querySelector('[data-restart]').addEventListener('click', () => { m.close(); const run = game.end(); finishRun(run, false); startGame({ mode: run.mode === 'duel' ? 'classic' : run.mode }); });
      m.querySelector('[data-home]').addEventListener('click', () => { m.close(); show('home'); });
    },
    offerPower: powerOffer,
    onTargetHit(run) {
      if (run.mode === 'challenge' && S.daily && !S.daily.challengeDone) {
        S.daily.challengeDone = true;
        grant(CHALLENGE_REWARD);
        confettiRain(100); sound.perfect();
        toast(`Daily Challenge complete! ${rewardText(CHALLENGE_REWARD)}`);
        refreshTop();
      } else if (run.mode === 'duel') {
        confettiRain(100); sound.perfect();
        toast(`You beat ${run.rival}! 🏆`);
      }
    },
    onStuck({ canRevive, havePowers, score }) {
      const free = S.daily?.freeRevive;
      const m = modal(`<div class="stuck"><h2>Out of space! 😿</h2>
        <div class="stuck-cat">${catSVG(equipped('cat').look, 'shock')}</div>
        <p>Score <b>${fmt(score)}</b></p>
        ${canRevive ? `
          <button class="big-btn green" data-rev="${free ? 'free' : 'ad'}">${free ? '🐾 Revive FREE' : '▶ Watch ad to revive'}<small>Clears the middle + new pieces</small></button>
          ${!free ? `<button class="big-btn small purple" data-rev="gems">Revive 💎${REVIVE_GEMS}</button>` : ''}` : ''}
        ${havePowers ? '<button class="big-btn small" data-pw>Use a power-up</button>' : ''}
        <button class="link" data-end>No thanks</button></div>`, { dismiss: false });
      m.querySelectorAll('[data-rev]').forEach((b) => b.addEventListener('click', async () => {
        const how = b.dataset.rev;
        if (how === 'free') { S.daily.freeRevive = false; save(); }
        else if (how === 'gems') { if (!spendGems(REVIVE_GEMS)) { gemsModal('Not enough gems'); return; } }
        else if (!(await showRewarded())) { toast('Ad not available, try again'); return; }
        m.close(); refreshTop(); game.revive();
      }));
      m.querySelector('[data-pw]')?.addEventListener('click', () => m.close());
      m.querySelector('[data-end]').addEventListener('click', () => { m.close(); finishRun(game.end(), true); });
    },
  };
}

function countUp(el, to, ms = 900) {
  const t0 = performance.now();
  const step = (t) => {
    const k = Math.min(1, (t - t0) / ms);
    el.textContent = fmt(Math.round(to * (1 - (1 - k) ** 3)));
    if (k < 1) requestAnimationFrame(step);
  };
  requestAnimationFrame(step);
}

function finishRun(run, showResults) {
  if (!run) return;
  const res = finishGame({ mode: run.mode, score: run.score, lines: run.lines, pieces: run.pieces, bestCombo: run.bestCombo, powers: run.powers, multis: run.multis, perfects: run.perfects, rescued: run.rescued || 0 });
  refreshTop();
  if (!showResults) return;
  playMusic('menu');
  if (res.newBest) { confettiRain(120); sound.levelUp(); }
  const duel = run.mode === 'duel';
  const won = duel && run.score > run.target;
  const head = duel ? (won ? `🏆 You beat ${run.rival}!` : `${run.rival} wins this time`) : res.newBest ? '🏆 NEW BEST!' : run.score >= res.prevBest * 0.8 && res.prevBest > 0 ? 'So close!' : 'Nice game!';
  const mood = res.newBest || won ? 'love' : run.score > 500 ? 'happy' : 'sleepy';
  const m = modal(`<div class="results">
    <h2>${head}</h2>
    <div class="stuck-cat">${catSVG(equipped('cat').look, mood)}</div>
    <div class="final-score" id="final-score">0</div>
    ${!res.newBest && !duel && res.prevBest ? `<div class="muted">Best ${fmt(res.prevBest)} · ${fmt(Math.max(0, res.prevBest - run.score + 1))} to go</div>` : ''}
    ${duel ? `<div class="muted">${run.rival}: ${fmt(run.target)}</div>` : ''}
    <div class="earned"><span>+🪙 <b id="earned-coins">${fmt(res.coins)}</b></span><span>+⭐ ${res.xp} XP</span>${run.rescued ? `<span>🐱 ${run.rescued} saved</span>` : ''}${res.streakUp ? `<span>🔥 ${res.streak} day streak</span>` : ''}</div>
    ${res.ups.map((u) => `<div class="lvlup">LEVEL ${u.level}! ${rewardText(u.reward)}</div>`).join('')}
    <button class="big-btn small purple" data-double>▶ Double coins</button>
    <button class="big-btn play" data-again>▶ Play again</button>
    <div class="row"><button class="big-btn small gray" data-home>Home</button><button class="big-btn small" data-share>📤 Challenge</button></div>
    ${missionsClaimable() || passClaimable() ? '<div class="hint">🎁 You have rewards to claim!</div>' : ''}
  </div>`, { dismiss: false });
  countUp(m.querySelector('#final-score'), run.score);
  if (res.ups.length) sound.levelUp();
  m.querySelector('[data-double]').addEventListener('click', async (e) => {
    e.currentTarget.disabled = true;
    if (await showRewarded()) {
      grant({ coins: res.coins });
      m.querySelector('#earned-coins').textContent = fmt(res.coins * 2);
      sound.coin(); refreshTop(); toast(`+${fmt(res.coins)} 🪙`);
      m.querySelector('[data-double]').remove();
    } else e.currentTarget.disabled = false;
  });
  m.querySelector('[data-share]').addEventListener('click', () => shareRun(run));
  const leave = async (next) => {
    m.close();
    if (S.stats.games === 1) askNotifications();
    await maybeInterstitial();
    next();
  };
  m.querySelector('[data-again]').addEventListener('click', () => leave(() => startGame({ mode: run.mode === 'challenge' ? 'challenge' : 'classic' })));
  m.querySelector('[data-home]').addEventListener('click', () => leave(() => {
    show('home');
    if (S.stats.games === 1) toast('🎁 Rewards unlocked! Check them out.');
    else if (res.newBest) ratePrompt();
  }));
}

// ---------- global event delegation ----------
export function initUI() {
  document.addEventListener('click', (e) => {
    const t = e.target.closest('button, [data-act], [data-item], [data-buy]');
    if (!t || t.closest('#screen-game')) return;
    const d = t.dataset;
    if (d.nav) { sound.tap(); show(d.nav); return; }
    if (d.buy) { sound.tap(); owns(d.buy) ? itemModal(d.buy) : tryBuy(d.buy); return; }
    if (d.item) { sound.tap(); itemModal(d.item); return; }
    if (d.powerBuy) { if (buyPower(d.powerBuy, 3)) { sound.coin(); toast(`+3 ${POWERUPS[d.powerBuy].icon}`); refreshTop(); rerender(); } else { sound.invalid(); toast('Not enough coins 🪙'); } return; }
    if (d.iap) { if (!t.closest('.modal')) buyGems(d.iap); return; }
    if (d.open) { sound.tap(); doOpen(d.open); return; }
    if (d.tab) { sound.tap(); colTab = d.tab; renderCats(); return; }
    if (d.claimSet) { const r = claimSet(d.claimSet); if (r) { sound.perfect(); confettiRain(120); toast(`Set complete! ${rewardText(r)}`); refreshTop(); rerender(); } return; }
    if (d.pass) {
      const [tier, prem] = d.pass.split(':').map(Number);
      if (prem && !S.pass.premium) { sound.tap(); toast('Go Premium to unlock'); return; }
      const r = claimPass(tier, !!prem);
      if (r) { sound.coin(); if (r.item) revealSingle(ITEM_BY_KEY[r.item]); else toast(rewardText(r)); refreshTop(); rerender(); }
      return;
    }
    switch (d.act) {
      case 'play': sound.tap(); game.clearSavedRun(); startGame({ mode: 'classic' }); break;
      case 'continue': sound.tap(); startGame({ resume: true }); break;
      case 'challenge': sound.tap(); game.clearSavedRun(); startGame({ mode: 'challenge' }); break;
      case 'rewards': sound.tap(); rewardsModal(); break;
      case 'share-invite': sound.tap(); shareInvite(); break;
      case 'settings': sound.tap(); settingsModal(); break;
      case 'starter': sound.tap(); buy(STARTER_PACK.sku, 'Starter Pack: Lucky (Epic cat), Candy Gloss blocks, 💎500, 🪙5,000', localPrice(STARTER_PACK.sku, STARTER_PACK.price)); break;
      case 'noads': sound.tap(); buy(NO_ADS.sku, `No Ads forever + 💎${NO_ADS.gems}`, localPrice(NO_ADS.sku, NO_ADS.price)); break;
      case 'odds': sound.tap(); oddsModal(); break;
      case 'pet': sound.meow(); t.querySelector('.cat-svg').outerHTML = catSVG(equipped('cat').look, 'love', 'idle-bob'); setTimeout(() => { const s = t.querySelector('.cat-svg'); if (s) s.outerHTML = catSVG(equipped('cat').look, 'idle', 'idle-bob'); }, 1200); break;
      case 'claim-all': { const r = claimAllPass(); if (r.length) { sound.coin(); confettiRain(60); const it = r.find((x) => x.item); if (it) revealSingle(ITEM_BY_KEY[it.item]); else toast(`Claimed ${r.length} rewards!`); refreshTop(); rerender(); } break; }
      case 'buy-pass':
        if (buyPremiumPass()) { sound.perfect(); confettiRain(120); toast('Premium Paw Pass unlocked! ⭐'); refreshTop(); rerender(); }
        else gemsModal(`You need 💎${fmt(PASS_PRICE_GEMS - S.gems)} more`);
        break;
      default:
    }
  });
  $('cur-gems').addEventListener('click', () => { sound.tap(); gemsModal(); });
  $('btn-profile').addEventListener('click', () => {
    sound.tap();
    modal(`<h2>Level ${S.level}</h2><div class="bar"><div style="width:${(S.xp / xpForLevel(S.level)) * 100}%"></div></div>
      <p class="muted">${fmt(S.xp)}/${fmt(xpForLevel(S.level))} XP · every level gives 🪙 and 💎</p>
      <p>Collection <b>${S.owned.length}</b> · Streak <b>🔥 ${streakAlive()}</b></p>`);
  });
}

export { dayKey };
