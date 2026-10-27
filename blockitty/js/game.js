// Game screen controller: board rendering, drag & drop, power-ups, scoring, juice.

import {
  SIZE, SHAPES, emptyBoard, canPlace, linesCompletedBy, placePiece, scoreMove, dealTray,
  anyMoveLeft, hammer, bomb, reviveClear, mulberry32, hashString, challengeBoard, fillRatio,
} from './core.js';
import { drawCell } from './skins.js';
import { catSVG } from './cats.js';
import { sound, buzz, setIntensity, playMusic } from './audio.js';
import { burst, floatText } from './fx.js';
import { S, save, equipped, dayKey } from './state.js';
import { CHALLENGE_TARGET } from './data.js';

const FRENZY_AT = 5; // kittens to rescue to trigger Catnip Frenzy
const FRENZY_MOVES = 3; // placements with x3 points

const RUN_KEY = 'blockitty-run-v2';
const $ = (id) => document.getElementById(id);

let hooks = {};
let G = null; // current run
let cell = 40;
let dpr = 1;
let drag = null;
let ghost = null; // {shape, r, c, color, lines}
let target = null; // 'hammer' | 'bomb'
let clearing = []; // {r,c,color,t}
let flashes = []; // {rows, cols, t}
let animating = false;
let moodTimer = null;
let shownScore = 0;
let scoreAnim = null;

export function initGame(h) {
  hooks = h;
  window.addEventListener('resize', () => { if (G) layout(); });
  window.addEventListener('pointermove', onMove, { passive: false });
  window.addEventListener('pointerup', onUp);
  window.addEventListener('pointercancel', onUp);
  $('board').addEventListener('pointerdown', onBoardTap);
  document.querySelectorAll('.slot').forEach((el, i) => el.addEventListener('pointerdown', (e) => onPick(e, i)));
  document.querySelectorAll('[data-power]').forEach((b) => b.addEventListener('click', () => usePower(b.dataset.power)));
  $('btn-pause').addEventListener('click', () => { sound.tap(); hooks.onPause(); });
}

export function hasSavedRun() {
  try { return !!localStorage.getItem(RUN_KEY); } catch { return false; }
}

function persist() {
  if (!G) return;
  try {
    const { rng, ...rest } = G;
    localStorage.setItem(RUN_KEY, JSON.stringify({ ...rest, tray: G.tray.map((t) => (t ? { id: t.shape.id, color: t.color, catCell: t.catCell } : null)) }));
  } catch { /* ignore */ }
}

export function clearSavedRun() {
  try { localStorage.removeItem(RUN_KEY); } catch { /* ignore */ }
}

// opts: { mode: 'classic'|'challenge'|'duel', resume, seed, target, rival }
export function start(opts = {}) {
  let restored = null;
  if (opts.resume) {
    try { restored = JSON.parse(localStorage.getItem(RUN_KEY)); } catch { restored = null; }
  }
  if (restored) {
    G = { meter: 0, frenzy: 0, rescued: 0, ...restored, tray: restored.tray.map((t) => (t ? { shape: SHAPES.find((s) => s.id === t.id), color: t.color, catCell: t.catCell } : null)) };
    G.rng = mulberry32((G.seed + G.pieces * 7919) >>> 0);
  } else {
    const mode = opts.mode || 'classic';
    const seed = opts.seed != null ? opts.seed >>> 0
      : mode === 'challenge' ? hashString(`challenge-${dayKey()}`)
        : (Math.random() * 2 ** 32) >>> 0;
    const rng = mulberry32(seed);
    G = {
      mode,
      seed,
      target: mode === 'challenge' ? CHALLENGE_TARGET : opts.target || 0,
      rival: opts.rival || '',
      board: mode === 'challenge' ? challengeBoard(rng) : emptyBoard(),
      score: 0,
      comboState: { combo: 0, miss: 0 },
      bestCombo: 0,
      lines: 0, pieces: 0, powers: 0, multis: 0, perfects: 0,
      rescued: 0, meter: 0, frenzy: 0,
      revived: false,
      targetHit: false,
      bestAnnounced: false,
      tray: [],
      rng,
    };
    G.tray = dealTray(G.board, G.rng, 0);
  }
  target = null;
  clearing = [];
  flashes = [];
  ghost = null;
  shownScore = G.score;
  layout();
  updateHud(true);
  setMood('idle');
  if (G.mode === 'challenge') say(`Daily goal: ${G.target.toLocaleString('en-US')}!`);
  else if (G.mode === 'duel') say(`Beat ${G.rival}: ${G.target.toLocaleString('en-US')}!`);
  else say(['Let’s play!', 'Ready? Meow!', 'Go go go! 🐾'][Math.floor(Math.random() * 3)]);
  $('tutorial').hidden = S.tutorialDone;
  setIntensity(0);
  playMusic('game');
  persist();
  dealAnim();
  if (!anyMoveLeft(G.board, G.tray)) setTimeout(stuck, 400);
}

export function isRunning() { return !!G; }

function layout() {
  dpr = Math.min(window.devicePixelRatio || 1, 3);
  const screen = $('screen-game');
  const top = screen.querySelector('.game-top').offsetHeight + screen.querySelector('.buddy-row').offsetHeight + ($('goal').hidden ? 0 : 30);
  const reserved = top + 220;
  const avail = Math.min(window.innerWidth - 28, window.innerHeight - reserved, 520);
  cell = Math.max(28, Math.floor(avail / SIZE));
  const px = cell * SIZE;
  const c = $('board');
  c.width = px * dpr;
  c.height = px * dpr;
  c.style.width = `${px}px`;
  c.style.height = `${px}px`;
  draw();
  drawTray();
}

function skin() { return equipped('skin'); }
function theme() { return equipped('theme'); }

function draw() {
  const c = $('board');
  const ctx = c.getContext('2d');
  ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
  const px = cell * SIZE;
  const th = theme();
  const sk = skin();
  ctx.clearRect(0, 0, px, px);
  ctx.fillStyle = th.board;
  ctx.fillRect(0, 0, px, px);
  const willClear = new Set();
  if (ghost && ghost.lines) {
    ghost.lines.rows.forEach((r) => { for (let i = 0; i < SIZE; i++) willClear.add(r * SIZE + i); });
    ghost.lines.cols.forEach((col) => { for (let i = 0; i < SIZE; i++) willClear.add(i * SIZE + col); });
  }
  for (let r = 0; r < SIZE; r++) {
    for (let col = 0; col < SIZE; col++) {
      const x = col * cell, y = r * cell;
      ctx.fillStyle = th.cell;
      ctx.beginPath();
      if (ctx.roundRect) ctx.roundRect(x + 2, y + 2, cell - 4, cell - 4, cell * 0.16); else ctx.rect(x + 2, y + 2, cell - 4, cell - 4);
      ctx.fill();
      const v = G.board[r][col];
      if (v) drawCell(ctx, x, y, cell, willClear.has(r * SIZE + col) ? ghost.color | (v & 16) : v, sk);
    }
  }
  if (ghost) {
    ghost.shape.cells.forEach(([dr, dc], k) => drawCell(ctx, (ghost.c + dc) * cell, (ghost.r + dr) * cell, cell, k === ghost.catCell ? ghost.color | 16 : ghost.color, sk, 0.45));
    if (willClear.size) {
      ctx.save();
      ctx.globalCompositeOperation = 'lighter';
      ctx.fillStyle = 'rgba(255,255,255,.16)';
      for (const k of willClear) ctx.fillRect((k % SIZE) * cell, Math.floor(k / SIZE) * cell, cell, cell);
      ctx.restore();
    }
  }
  const now = performance.now();
  clearing = clearing.filter((p) => now - p.t < 340);
  for (const p of clearing) {
    const k = Math.max(0, 1 - (now - p.t) / 340);
    const s = cell * (0.2 + 0.8 * k);
    drawCell(ctx, p.c * cell + (cell - s) / 2, p.r * cell + (cell - s) / 2, s, p.color, sk, k);
  }
  flashes = flashes.filter((f) => now - f.t < 260);
  for (const f of flashes) {
    const a = 0.75 * (1 - (now - f.t) / 260);
    ctx.fillStyle = `rgba(255,255,255,${a})`;
    f.rows.forEach((r) => ctx.fillRect(0, r * cell, px, cell));
    f.cols.forEach((col) => ctx.fillRect(col * cell, 0, cell, px));
  }
  if (target) {
    ctx.strokeStyle = target === 'bomb' ? '#ff5a36' : '#ffd400';
    ctx.lineWidth = 4;
    ctx.setLineDash([10, 8]);
    ctx.strokeRect(2, 2, px - 4, px - 4);
    ctx.setLineDash([]);
  }
  if ((clearing.length || flashes.length) && !animating) {
    animating = true;
    requestAnimationFrame(() => { animating = false; draw(); });
  }
}

function pieceCanvas(piece, size, alpha = 1) {
  const c = document.createElement('canvas');
  const w = piece.shape.cols * size, h = piece.shape.rows * size;
  c.width = w * dpr; c.height = h * dpr;
  c.style.width = `${w}px`; c.style.height = `${h}px`;
  const ctx = c.getContext('2d');
  ctx.scale(dpr, dpr);
  piece.shape.cells.forEach(([r, col], k) => drawCell(ctx, col * size, r * size, size, k === piece.catCell ? piece.color | 16 : piece.color, skin(), alpha));
  return c;
}

function drawTray() {
  const slots = document.querySelectorAll('.slot');
  const slotW = Math.min(window.innerWidth - 24, 520) / 3 - 10;
  slots.forEach((el, i) => {
    el.innerHTML = '';
    const p = G.tray[i];
    if (!p) return;
    const fits = anyMoveLeft(G.board, [p]);
    const size = Math.floor(Math.min(cell * 0.62, slotW / p.shape.cols, 112 / p.shape.rows));
    const cv = pieceCanvas(p, size, fits ? 1 : 0.3);
    if (drag && drag.idx === i) cv.style.visibility = 'hidden';
    el.appendChild(cv);
  });
}

function dealAnim() {
  document.querySelectorAll('.slot canvas').forEach((cv, i) => {
    cv.classList.remove('deal');
    void cv.offsetWidth;
    cv.style.animationDelay = `${i * 60}ms`;
    cv.classList.add('deal');
  });
  sound.whoosh();
}

function animateScore() {
  cancelAnimationFrame(scoreAnim);
  const step = () => {
    const diff = G ? G.score - shownScore : 0;
    if (!G || diff <= 0) { if (G) $('score').textContent = G.score.toLocaleString('en-US'); return; }
    shownScore += Math.max(1, Math.ceil(diff * 0.18));
    $('score').textContent = shownScore.toLocaleString('en-US');
    scoreAnim = requestAnimationFrame(step);
  };
  step();
  const el = $('score');
  el.classList.remove('bump'); void el.offsetWidth; el.classList.add('bump');
}

function updateHud(instant = false) {
  if (instant) { shownScore = G.score; $('score').textContent = G.score.toLocaleString('en-US'); } else animateScore();
  const best = Math.max(S.best[G.mode] || 0, G.score);
  $('best').textContent = best.toLocaleString('en-US');
  const combo = G.comboState.combo;
  const el = $('combo');
  el.textContent = combo > 1 ? `🔥 Combo x${combo}` : '';
  el.classList.toggle('show', combo > 1);
  for (const [k, v] of Object.entries(S.power)) {
    const b = document.querySelector(`[data-power="${k}"] .count`);
    if (b) b.textContent = v > 0 ? v : '+';
  }
  document.querySelectorAll('[data-power]').forEach((b) => b.classList.toggle('active', target === b.dataset.power));
  const goal = $('goal');
  if (G.target) {
    goal.hidden = false;
    const pct = Math.min(100, (G.score / G.target) * 100);
    goal.querySelector('.fill').style.width = `${pct}%`;
    const who = G.mode === 'duel' ? `${G.rival}'s score` : 'Goal';
    goal.querySelector('.txt').textContent = G.targetHit ? (G.mode === 'duel' ? `You beat ${G.rival}! 🎉` : 'Goal complete! 🎉') : `${who} ${G.score.toLocaleString('en-US')} / ${G.target.toLocaleString('en-US')}`;
  } else goal.hidden = true;
  $('screen-game').classList.toggle('danger', fillRatio(G.board) > 0.66);
  const m = $('meter');
  m.innerHTML = G.frenzy > 0
    ? `<b>CATNIP FRENZY ×3</b> <span>${G.frenzy} left</span>`
    : `${Array.from({ length: FRENZY_AT }, (_, i) => `<i class="${i < G.meter ? 'on' : ''}">🐾</i>`).join('')}`;
  m.classList.toggle('frenzy', G.frenzy > 0);
  document.querySelector('.board-wrap').classList.toggle('frenzy', G.frenzy > 0);
}

export function setMood(mood, ms = 1400) {
  const look = equipped('cat').look;
  const b = $('buddy');
  b.innerHTML = catSVG(look, mood);
  b.classList.remove('bounce');
  void b.offsetWidth;
  if (mood !== 'idle') b.classList.add('bounce');
  clearTimeout(moodTimer);
  if (mood !== 'idle') moodTimer = setTimeout(() => setMood('idle'), ms);
}

function say(text) {
  const s = $('speech');
  s.textContent = text;
  s.classList.remove('show');
  void s.offsetWidth;
  s.classList.add('show');
}

function shake(strength = 1) {
  const w = document.querySelector('.board-wrap');
  w.style.setProperty('--shake', `${3 + strength * 3}px`);
  w.classList.remove('shake'); void w.offsetWidth; w.classList.add('shake');
}

// ---------- drag & drop ----------
function onPick(e, i) {
  if (!G || !G.tray[i] || target) return;
  e.preventDefault();
  const piece = G.tray[i];
  const el = pieceCanvas(piece, cell);
  el.id = 'drag';
  document.body.appendChild(el);
  const w = piece.shape.cols * cell, h = piece.shape.rows * cell;
  const touch = e.pointerType !== 'mouse';
  drag = { idx: i, piece, el, w, h, lift: touch ? cell * 1.4 + h / 2 : 0 };
  sound.pick();
  positionDrag(e.clientX, e.clientY);
  drawTray();
}

function positionDrag(x, y) {
  const left = x - drag.w / 2;
  const top = y - drag.h / 2 - drag.lift;
  drag.el.style.transform = `translate(${left}px, ${top}px)`;
  const rect = $('board').getBoundingClientRect();
  const c = Math.round((left - rect.left) / cell);
  const r = Math.round((top - rect.top) / cell);
  if (canPlace(G.board, drag.piece.shape, r, c)) {
    if (!ghost || ghost.r !== r || ghost.c !== c) {
      ghost = { shape: drag.piece.shape, color: drag.piece.color, catCell: drag.piece.catCell, r, c, lines: linesCompletedBy(G.board, drag.piece.shape, r, c) };
      draw();
    }
  } else if (ghost) {
    ghost = null;
    draw();
  }
}

function onMove(e) {
  if (!drag) return;
  e.preventDefault();
  positionDrag(e.clientX, e.clientY);
}

function onUp() {
  if (!drag) return;
  const d = drag;
  drag = null;
  d.el.remove();
  if (ghost) {
    const g = ghost;
    ghost = null;
    commit(d.idx, g.r, g.c);
  } else {
    sound.invalid();
    drawTray();
  }
}

function cellCenter(r, c) {
  const rect = $('board').getBoundingClientRect();
  return { x: rect.left + c * cell + cell / 2, y: rect.top + r * cell + cell / 2 };
}

const PRAISE = ['', '', 'Great!', 'Amazing!', 'Purrfect!', 'Un-fur-gettable!', 'Legendary!'];
const CHEERS = ['Meow-velous!', 'Paw-some!', 'So good! 😻', 'Clawsome!', 'Yesss! 🐾'];

function commit(idx, r, c) {
  const piece = G.tray[idx];
  const move = placePiece(G.board, piece.shape, r, c, piece.color, piece.catCell ?? -1);
  G.tray[idx] = null;
  G.pieces += 1;
  const scored = scoreMove(move, G.comboState);
  const combo = scored.combo;
  let points = scored.points;
  const inFrenzy = G.frenzy > 0;
  if (inFrenzy) { points *= 3; G.frenzy -= 1; }
  G.comboState = combo;
  G.score += points;
  if (move.cats) rescue(move.cats);
  else if (inFrenzy && !G.frenzy) endFrenzyFx();
  G.bestCombo = Math.max(G.bestCombo, combo.combo);
  setIntensity(G.frenzy > 0 || combo.combo >= 4 ? 3 : combo.combo >= 2 ? 2 : combo.combo >= 1 ? 1 : 0);
  if (!S.tutorialDone) { S.tutorialDone = true; save(); $('tutorial').hidden = true; }

  if (move.lines) {
    G.lines += move.lines;
    if (move.lines >= 3) G.multis += 1;
    const now = performance.now();
    clearing.push(...move.cleared.map((x) => ({ ...x, t: now + (x.r + x.c) * 6 })));
    flashes.push({ rows: move.rows, cols: move.cols, t: now });
    burst(move.cleared.map((x) => ({ ...cellCenter(x.r, x.c), color: x.color })), equipped('fx').id, skin().palette);
    sound.clear(move.lines, combo.combo);
    if (move.lines >= 2 || combo.combo >= 3) shake(Math.min(3, move.lines));
    const mid = cellCenter(r + piece.shape.rows / 2 - 0.5, c + piece.shape.cols / 2 - 0.5);
    floatText(`+${points}`, mid.x, mid.y, 'pts');
    const b = $('board').getBoundingClientRect();
    if (move.perfect) {
      G.perfects += 1;
      sound.perfect();
      floatText('PURRFECT CLEAR!', b.left + b.width / 2, b.top + b.height / 2, 'big');
      setMood('wow', 2200);
      say('PURRFECT!! 😻');
    } else if (move.lines >= 2 || combo.combo >= 3) {
      const word = PRAISE[Math.min(move.lines + (combo.combo >= 3 ? 1 : 0), PRAISE.length - 1)] || 'Nice!';
      floatText(word, b.left + b.width / 2, b.top + b.height * 0.4, 'praise');
      setMood(combo.combo >= 3 ? 'love' : 'happy');
      if (Math.random() < 0.5) sound.meow();
      say(combo.combo >= 3 ? `Combo x${combo.combo}! 🔥` : CHEERS[Math.floor(Math.random() * CHEERS.length)]);
    } else {
      setMood('happy', 900);
    }
  } else {
    sound.place();
  }

  const best = S.best[G.mode] || 0;
  if (!G.bestAnnounced && best > 0 && G.score > best) {
    G.bestAnnounced = true;
    const b = $('board').getBoundingClientRect();
    setTimeout(() => floatText('NEW BEST! 🏆', b.left + b.width / 2, b.top + b.height * 0.25, 'big'), 350);
    sound.levelUp();
  }

  if (G.target && !G.targetHit && G.score >= G.target) {
    G.targetHit = true;
    hooks.onTargetHit(G);
  }

  let dealt = false;
  if (G.tray.every((t) => !t)) { G.tray = dealTray(G.board, G.rng, G.score); dealt = true; kittenHint(); }
  draw();
  drawTray();
  if (dealt) dealAnim();
  updateHud();
  persist();
  checkStuck();
}

function rescue(n) {
  G.rescued += n;
  G.meter += n;
  sound.meow();
  const b = $('board').getBoundingClientRect();
  setTimeout(() => floatText(n > 1 ? `${n} kittens saved! 🐱` : 'Kitten saved! 🐱', b.left + b.width / 2, b.top + b.height * 0.62, 'praise'), 250);
  if (G.meter >= FRENZY_AT && G.frenzy === 0) {
    G.meter = 0;
    G.frenzy = FRENZY_MOVES;
    setTimeout(() => {
      floatText('CATNIP FRENZY! ×3', b.left + b.width / 2, b.top + b.height * 0.35, 'big');
      sound.perfect();
      setMood('wow', 2500);
      say('Catnip time!! 🌿😻');
    }, 500);
  } else {
    setMood('love');
  }
}

function endFrenzyFx() { say('Frenzy over. Save more kittens! 🐾'); }

function kittenHint() {
  if (S.stats.rescued || G.hinted || !G.tray.some((t) => t && t.catCell != null)) return;
  G.hinted = true;
  say('A kitten is trapped! Clear its line to save it 🐱');
}

function checkStuck() {
  if (anyMoveLeft(G.board, G.tray)) {
    if (fillRatio(G.board) > 0.7 && Math.random() < 0.25) { setMood('shock'); say('Getting crowded… 😿'); }
    return;
  }
  setTimeout(stuck, 450);
}

function stuck() {
  if (!G) return;
  setMood('shock', 2500);
  sound.invalid();
  buzz('heavy');
  setIntensity(0);
  const havePowers = S.power.hammer + S.power.bomb + S.power.shuffle > 0;
  hooks.onStuck({ canRevive: !G.revived, havePowers, score: G.score });
}

export function revive() {
  G.revived = true;
  const cleared = reviveClear(G.board);
  burst(cleared.map((x) => ({ ...cellCenter(x.r, x.c), color: x.color })), 'stars', skin().palette);
  sound.boom();
  G.tray = dealTray(G.board, G.rng, 0);
  setMood('love');
  say('Second life! 8 left 😼');
  draw(); drawTray(); dealAnim(); updateHud(); persist();
}

export function end() {
  const run = G;
  G = null;
  clearSavedRun();
  setIntensity(0);
  sound.gameOver();
  $('screen-game').classList.remove('danger');
  return run;
}

// ---------- power-ups ----------
function usePower(id) {
  if (!G) return;
  sound.tap();
  if (S.power[id] <= 0) { hooks.offerPower(id); return; }
  if (id === 'shuffle') {
    S.power.shuffle -= 1;
    G.powers += 1;
    save();
    G.tray = dealTray(G.board, G.rng, 0);
    say('Fresh pieces! 🔄');
    drawTray(); dealAnim(); updateHud(); persist();
    checkStuck();
    return;
  }
  target = target === id ? null : id;
  if (target) say(id === 'bomb' ? 'Tap where to drop the bomb 💣' : 'Tap a block to smash 🔨');
  draw();
  updateHud();
}

function onBoardTap(e) {
  if (!target || !G) return;
  const rect = $('board').getBoundingClientRect();
  const c = Math.floor((e.clientX - rect.left) / cell);
  const r = Math.floor((e.clientY - rect.top) / cell);
  const out = target === 'bomb' ? bomb(G.board, r, c) : hammer(G.board, r, c);
  if (!out.length) { sound.invalid(); return; }
  S.power[target] -= 1;
  G.powers += 1;
  save();
  const freed = out.filter((x) => x.color & 16).length;
  if (freed) rescue(freed);
  const now = performance.now();
  clearing.push(...out.map((x) => ({ ...x, t: now })));
  burst(out.map((x) => ({ ...cellCenter(x.r, x.c), color: x.color })), target === 'bomb' ? 'stars' : equipped('fx').id, skin().palette);
  if (target === 'bomb') { sound.boom(); shake(3); } else sound.place();
  target = null;
  setMood('happy');
  draw(); drawTray(); updateHud(); persist();
  checkStuck();
}

export function refresh() {
  if (!G) return;
  layout();
  updateHud(true);
  setMood('idle');
}

export function current() { return G; }

// Test hook: lets automated UI tests jump to the out-of-moves screen.
export function debugStuck() { stuck(); }
