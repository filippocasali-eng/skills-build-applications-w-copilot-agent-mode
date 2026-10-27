// Game screen controller: board rendering, drag & drop, power-ups, scoring.

import {
  SIZE, SHAPES, emptyBoard, canPlace, linesCompletedBy, placePiece, scoreMove, dealTray,
  anyMoveLeft, hammer, bomb, reviveClear, mulberry32, hashString, challengeBoard,
} from './core.js';
import { drawCell } from './skins.js';
import { catSVG } from './cats.js';
import { sfx, buzz } from './audio.js';
import { burst, floatText } from './fx.js';
import { S, save, equipped, dayKey } from './state.js';
import { CHALLENGE_TARGET } from './data.js';

const RUN_KEY = 'blockitty-run-v1';
const $ = (id) => document.getElementById(id);

let hooks = {};
let G = null; // current run
let cell = 40;
let dpr = 1;
let drag = null;
let ghost = null; // {shape, r, c, color, lines}
let target = null; // 'hammer' | 'bomb'
let clearing = []; // {r,c,color,t}
let animating = false;
let moodTimer = null;

export function initGame(h) {
  hooks = h;
  window.addEventListener('resize', () => { if (G) layout(); });
  window.addEventListener('pointermove', onMove, { passive: false });
  window.addEventListener('pointerup', onUp);
  window.addEventListener('pointercancel', onUp);
  $('board').addEventListener('pointerdown', onBoardTap);
  document.querySelectorAll('.slot').forEach((el, i) => el.addEventListener('pointerdown', (e) => onPick(e, i)));
  document.querySelectorAll('[data-power]').forEach((b) => b.addEventListener('click', () => usePower(b.dataset.power)));
  $('btn-pause').addEventListener('click', () => { sfx.tap(); hooks.onPause(); });
}

function newRng(mode) {
  if (mode === 'challenge') return mulberry32(hashString(`challenge-${dayKey()}`));
  return mulberry32((Math.random() * 2 ** 32) >>> 0);
}

export function hasSavedRun() {
  try { return !!localStorage.getItem(RUN_KEY); } catch { return false; }
}

function persist() {
  if (!G) return;
  try {
    localStorage.setItem(RUN_KEY, JSON.stringify({
      ...G, rng: undefined, rngSeed: undefined,
      tray: G.tray.map((t) => (t ? { id: t.shape.id, color: t.color } : null)),
    }));
  } catch { /* ignore */ }
}

export function clearSavedRun() {
  try { localStorage.removeItem(RUN_KEY); } catch { /* ignore */ }
}

export function start(mode, resume = false) {
  mode = mode || 'classic';
  let restored = null;
  if (resume) {
    try { restored = JSON.parse(localStorage.getItem(RUN_KEY)); } catch { restored = null; }
  }
  if (restored) {
    G = { ...restored, tray: restored.tray.map((t) => (t ? { shape: SHAPES.find((s) => s.id === t.id), color: t.color } : null)) };
    G.rng = newRng('classic');
  } else {
    const rng = newRng(mode);
    G = {
      mode,
      board: mode === 'challenge' ? challengeBoard(rng) : emptyBoard(),
      score: 0,
      comboState: { combo: 0, miss: 0 },
      bestCombo: 0,
      lines: 0, pieces: 0, powers: 0, multis: 0, perfects: 0,
      revived: false,
      challengeHit: false,
      tray: [],
      rng,
    };
    G.tray = dealTray(G.board, G.rng);
  }
  target = null;
  clearing = [];
  ghost = null;
  layout();
  updateHud();
  setMood('idle');
  say(G.mode === 'challenge' ? `Daily goal: ${CHALLENGE_TARGET.toLocaleString()}!` : 'Let’s play!');
  $('tutorial').hidden = S.tutorialDone;
  persist();
  if (!anyMoveLeft(G.board, G.tray)) setTimeout(stuck, 400);
}

export function isRunning() { return !!G; }

function layout() {
  dpr = Math.min(window.devicePixelRatio || 1, 2);
  const screen = $('screen-game');
  const top = screen.querySelector('.game-top').offsetHeight + screen.querySelector('.buddy-row').offsetHeight;
  const reserved = top + 230; // tray + powers + paddings
  const avail = Math.min(window.innerWidth - 24, window.innerHeight - reserved, 520);
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
      ctx.roundRect ? ctx.roundRect(x + 2, y + 2, cell - 4, cell - 4, cell * 0.14) : ctx.rect(x + 2, y + 2, cell - 4, cell - 4);
      ctx.fill();
      const v = G.board[r][col];
      if (v) drawCell(ctx, x, y, cell, willClear.has(r * SIZE + col) ? ghost.color : v, sk);
    }
  }
  if (ghost) {
    for (const [dr, dc] of ghost.shape.cells) drawCell(ctx, (ghost.c + dc) * cell, (ghost.r + dr) * cell, cell, ghost.color, sk, 0.5);
    if (willClear.size) {
      ctx.save();
      ctx.globalCompositeOperation = 'lighter';
      ctx.fillStyle = 'rgba(255,255,255,.18)';
      for (const k of willClear) ctx.fillRect((k % SIZE) * cell, Math.floor(k / SIZE) * cell, cell, cell);
      ctx.restore();
    }
  }
  const now = performance.now();
  clearing = clearing.filter((p) => now - p.t < 320);
  for (const p of clearing) {
    const k = 1 - (now - p.t) / 320;
    const s = cell * k;
    drawCell(ctx, p.c * cell + (cell - s) / 2, p.r * cell + (cell - s) / 2, s, p.color, sk, k);
  }
  if (target) {
    ctx.strokeStyle = target === 'bomb' ? '#ff5a36' : '#ffd400';
    ctx.lineWidth = 4;
    ctx.setLineDash([10, 8]);
    ctx.strokeRect(2, 2, px - 4, px - 4);
    ctx.setLineDash([]);
  }
  if (clearing.length && !animating) {
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
  for (const [r, col] of piece.shape.cells) drawCell(ctx, col * size, r * size, size, piece.color, skin(), alpha);
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
    const size = Math.floor(Math.min(cell * 0.62, slotW / p.shape.cols, 110 / p.shape.rows));
    const cv = pieceCanvas(p, size, fits ? 1 : 0.35);
    if (drag && drag.idx === i) cv.style.visibility = 'hidden';
    el.appendChild(cv);
  });
}

function updateHud() {
  $('score').textContent = G.score.toLocaleString();
  $('best').textContent = Math.max(S.best[G.mode] || 0, G.score).toLocaleString();
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
  if (G.mode === 'challenge') {
    goal.hidden = false;
    const pct = Math.min(100, (G.score / CHALLENGE_TARGET) * 100);
    goal.querySelector('.fill').style.width = `${pct}%`;
    goal.querySelector('.txt').textContent = G.challengeHit ? 'Goal complete! 🎉' : `Goal ${G.score.toLocaleString()} / ${CHALLENGE_TARGET.toLocaleString()}`;
  } else goal.hidden = true;
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
  drag = { idx: i, piece, el, w, h, lift: touch ? cell * 1.3 + h / 2 : 0 };
  sfx.pick();
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
      ghost = { shape: drag.piece.shape, color: drag.piece.color, r, c, lines: linesCompletedBy(G.board, drag.piece.shape, r, c) };
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
    sfx.invalid();
    drawTray();
  }
}

function cellCenter(r, c) {
  const rect = $('board').getBoundingClientRect();
  return { x: rect.left + c * cell + cell / 2, y: rect.top + r * cell + cell / 2 };
}

const PRAISE = ['', '', 'Great!', 'Amazing!', 'Purrfect!', 'Un-fur-gettable!', 'Legendary!'];

function commit(idx, r, c) {
  const piece = G.tray[idx];
  const move = placePiece(G.board, piece.shape, r, c, piece.color);
  G.tray[idx] = null;
  G.pieces += 1;
  const { points, combo } = scoreMove(move, G.comboState);
  G.comboState = combo;
  G.score += points;
  G.bestCombo = Math.max(G.bestCombo, combo.combo);
  if (!S.tutorialDone) { S.tutorialDone = true; save(); $('tutorial').hidden = true; }

  if (move.lines) {
    G.lines += move.lines;
    if (move.lines >= 3) G.multis += 1;
    const now = performance.now();
    clearing.push(...move.cleared.map((x, k) => ({ ...x, t: now + k * 4 })));
    const fxId = equipped('fx').id;
    burst(move.cleared.map((x) => ({ ...cellCenter(x.r, x.c), color: x.color })), fxId, skin().palette);
    sfx.clear(move.lines, combo.combo);
    const mid = cellCenter(r + piece.shape.rows / 2 - 0.5, c + piece.shape.cols / 2 - 0.5);
    floatText(`+${points}`, mid.x, mid.y, 'pts');
    if (move.perfect) {
      G.perfects += 1;
      sfx.perfect();
      const b = $('board').getBoundingClientRect();
      floatText('PURRFECT CLEAR!', b.left + b.width / 2, b.top + b.height / 2, 'big');
      setMood('wow', 2200);
      say('PURRFECT!! 😻');
    } else if (move.lines >= 2 || combo.combo >= 3) {
      const b = $('board').getBoundingClientRect();
      const word = PRAISE[Math.min(move.lines + (combo.combo >= 3 ? 1 : 0), PRAISE.length - 1)] || 'Nice!';
      floatText(word, b.left + b.width / 2, b.top + b.height * 0.4, 'praise');
      setMood(combo.combo >= 3 ? 'love' : 'happy');
      if (Math.random() < 0.5) sfx.meow();
      say(combo.combo >= 3 ? `Combo x${combo.combo}! 🔥` : 'Meow-velous!');
    } else {
      setMood('happy', 900);
    }
  } else {
    sfx.place();
  }

  if (G.mode === 'challenge' && !G.challengeHit && G.score >= CHALLENGE_TARGET) {
    G.challengeHit = true;
    hooks.onChallengeHit();
  }

  if (G.tray.every((t) => !t)) G.tray = dealTray(G.board, G.rng);
  draw();
  drawTray();
  updateHud();
  persist();
  checkStuck();
}

function checkStuck() {
  if (anyMoveLeft(G.board, G.tray)) {
    const filled = G.board.flat().filter(Boolean).length;
    if (filled > 44 && Math.random() < 0.3) { setMood('shock'); say('Getting crowded… 😿'); }
    return;
  }
  setTimeout(stuck, 450);
}

function stuck() {
  if (!G) return;
  setMood('shock', 2500);
  sfx.invalid();
  buzz([40, 60, 40]);
  const havePowers = S.power.hammer + S.power.bomb + S.power.shuffle > 0;
  hooks.onStuck({ canRevive: !G.revived && G.mode !== 'challenge', havePowers });
}

export function revive() {
  G.revived = true;
  const cleared = reviveClear(G.board);
  burst(cleared.map((x) => ({ ...cellCenter(x.r, x.c), color: x.color })), 'stars', skin().palette);
  sfx.boom();
  G.tray = dealTray(G.board, G.rng);
  setMood('love');
  say('Second life! 9 left 😼');
  draw(); drawTray(); updateHud(); persist();
}

export function end() {
  const run = G;
  G = null;
  clearSavedRun();
  sfx.gameOver();
  return run;
}

// ---------- power-ups ----------
function usePower(id) {
  if (!G) return;
  sfx.tap();
  if (S.power[id] <= 0) { hooks.offerPower(id); return; }
  if (id === 'shuffle') {
    S.power.shuffle -= 1;
    G.powers += 1;
    save();
    G.tray = dealTray(G.board, G.rng);
    say('Fresh pieces! 🔄');
    drawTray(); updateHud(); persist();
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
  if (!out.length) { sfx.invalid(); return; }
  S.power[target] -= 1;
  G.powers += 1;
  save();
  const now = performance.now();
  clearing.push(...out.map((x) => ({ ...x, t: now })));
  burst(out.map((x) => ({ ...cellCenter(x.r, x.c), color: x.color })), target === 'bomb' ? 'stars' : equipped('fx').id, skin().palette);
  target === 'bomb' ? sfx.boom() : sfx.place();
  target = null;
  setMood('happy');
  draw(); drawTray(); updateHud(); persist();
  checkStuck();
}

export function refresh() {
  if (!G) return;
  layout();
  updateHud();
  setMood('idle');
}

export function current() { return G; }
