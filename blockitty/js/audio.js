// All audio is synthesized at runtime with WebAudio: original music and sound
// effects, no sample files, no licensing issues, works offline.

import { plugin } from './config.js';

let ctx = null;
let master, musicBus, sfxBus, reverb, reverbSend;
let sfxOn = true;
let musicOn = true;
let hapticsOn = true;

export function setAudio({ sound, music, haptics }) {
  sfxOn = sound;
  musicOn = music;
  hapticsOn = haptics;
  if (musicBus) musicBus.gain.setTargetAtTime(musicOn ? 0.55 : 0, ctx.currentTime, 0.2);
  if (!musicOn) stopMusic();
  else if (wanted && !playing) playMusic(wanted);
}

function impulse(a, seconds = 1.8) {
  const len = a.sampleRate * seconds;
  const buf = a.createBuffer(2, len, a.sampleRate);
  for (let ch = 0; ch < 2; ch++) {
    const d = buf.getChannelData(ch);
    for (let i = 0; i < len; i++) d[i] = (Math.random() * 2 - 1) * (1 - i / len) ** 2.6;
  }
  return buf;
}

function ac() {
  if (!ctx) {
    const AC = window.AudioContext || window.webkitAudioContext;
    if (!AC) return null;
    ctx = new AC({ latencyHint: 'interactive' });
    const comp = ctx.createDynamicsCompressor();
    comp.threshold.value = -14; comp.ratio.value = 4; comp.attack.value = 0.005; comp.release.value = 0.2;
    master = ctx.createGain(); master.gain.value = 0.9;
    master.connect(comp).connect(ctx.destination);
    reverb = ctx.createConvolver(); reverb.buffer = impulse(ctx);
    reverbSend = ctx.createGain(); reverbSend.gain.value = 0.22;
    reverbSend.connect(reverb).connect(master);
    musicBus = ctx.createGain(); musicBus.gain.value = musicOn ? 0.55 : 0;
    musicBus.connect(master); musicBus.connect(reverbSend);
    sfxBus = ctx.createGain(); sfxBus.gain.value = 1;
    sfxBus.connect(master); sfxBus.connect(reverbSend);
  }
  if (ctx.state === 'suspended') ctx.resume();
  return ctx;
}

export function suspendAudio() { if (ctx && ctx.state === 'running') ctx.suspend(); }
export function resumeAudio() { if (ctx && ctx.state === 'suspended') ctx.resume(); }

const mtof = (m) => 440 * 2 ** ((m - 69) / 12);

// ---------- instruments ----------
function voice(bus, t, freq, dur, { type = 'triangle', vol = 0.15, attack = 0.008, release = 0.12, slide = 0, vibrato = 0, detune = 0, filter = 0 } = {}) {
  const o = ctx.createOscillator();
  const g = ctx.createGain();
  o.type = type;
  o.frequency.setValueAtTime(freq, t);
  if (detune) o.detune.value = detune;
  if (slide) o.frequency.exponentialRampToValueAtTime(Math.max(30, freq + slide), t + dur);
  let out = g;
  if (filter) {
    const f = ctx.createBiquadFilter(); f.type = 'lowpass'; f.frequency.value = filter; f.Q.value = 0.7;
    o.connect(f).connect(g);
  } else o.connect(g);
  if (vibrato) {
    const l = ctx.createOscillator(); const lg = ctx.createGain();
    l.frequency.value = 5.5; lg.gain.value = vibrato;
    l.connect(lg).connect(o.frequency); l.start(t + 0.08); l.stop(t + dur + release);
  }
  g.gain.setValueAtTime(0.0001, t);
  g.gain.exponentialRampToValueAtTime(vol, t + attack);
  g.gain.setValueAtTime(vol, t + Math.max(attack, dur - 0.02));
  g.gain.exponentialRampToValueAtTime(0.0001, t + dur + release);
  out.connect(bus);
  o.start(t);
  o.stop(t + dur + release + 0.02);
}

let noiseBuf = null;
function noise(bus, t, dur, { vol = 0.1, hp = 6000, bp = 0 } = {}) {
  if (!noiseBuf) {
    noiseBuf = ctx.createBuffer(1, ctx.sampleRate * 0.5, ctx.sampleRate);
    const d = noiseBuf.getChannelData(0);
    for (let i = 0; i < d.length; i++) d[i] = Math.random() * 2 - 1;
  }
  const s = ctx.createBufferSource(); s.buffer = noiseBuf;
  const f = ctx.createBiquadFilter();
  f.type = bp ? 'bandpass' : 'highpass'; f.frequency.value = bp || hp;
  const g = ctx.createGain();
  g.gain.setValueAtTime(vol, t); g.gain.exponentialRampToValueAtTime(0.0001, t + dur);
  s.connect(f).connect(g).connect(bus);
  s.start(t); s.stop(t + dur + 0.02);
}

function kick(bus, t, vol = 0.55) {
  const o = ctx.createOscillator(); const g = ctx.createGain();
  o.frequency.setValueAtTime(150, t); o.frequency.exponentialRampToValueAtTime(42, t + 0.12);
  g.gain.setValueAtTime(vol, t); g.gain.exponentialRampToValueAtTime(0.0001, t + 0.28);
  o.connect(g).connect(bus); o.start(t); o.stop(t + 0.3);
}

// ---------- music ----------
// Original compositions (Blockitty OST). Notes: [step, midi, lengthInSteps].
const TRACKS = {
  menu: {
    bpm: 84,
    chords: [[60, 64, 67, 71], [57, 60, 64, 67], [62, 65, 69, 72], [55, 59, 62, 65]], // Cmaj7 Am7 Dm7 G7
    bass: [36, 33, 38, 31],
    melody: [
      [[0, 76, 4], [4, 79, 4], [8, 83, 6]],
      [[0, 81, 4], [4, 76, 4], [8, 72, 6]],
      [[0, 77, 4], [4, 81, 2], [6, 84, 2], [8, 81, 6]],
      [[0, 79, 4], [4, 77, 2], [6, 74, 2], [8, 71, 6], [14, 74, 2]],
    ],
    style: 'lofi',
  },
  game: {
    bpm: 116,
    chords: [[53, 57, 60], [55, 59, 62], [52, 55, 59], [57, 60, 64]], // F G Em Am
    bass: [41, 43, 40, 45],
    melody: [
      [[0, 69, 2], [2, 72, 2], [4, 77, 3], [7, 76, 1], [8, 72, 2], [10, 69, 2], [12, 72, 4]],
      [[0, 71, 2], [2, 74, 2], [4, 79, 3], [7, 77, 1], [8, 74, 2], [10, 71, 2], [12, 74, 2], [14, 76, 2]],
      [[0, 79, 3], [3, 76, 1], [4, 71, 2], [6, 76, 2], [8, 79, 2], [10, 81, 2], [12, 79, 2], [14, 76, 2]],
      [[0, 72, 2], [2, 76, 2], [4, 81, 4], [8, 79, 2], [10, 76, 2], [12, 72, 2], [14, 71, 2]],
      [[0, 69, 2], [2, 72, 2], [4, 77, 3], [7, 76, 1], [8, 72, 2], [10, 69, 2], [12, 72, 4]],
      [[0, 71, 2], [2, 74, 2], [4, 79, 3], [7, 77, 1], [8, 74, 2], [10, 71, 2], [12, 74, 2], [14, 76, 2]],
      [[0, 76, 4], [4, 74, 2], [6, 76, 2], [8, 79, 4], [12, 83, 4]],
      [[0, 81, 6], [8, 76, 2], [10, 72, 2], [12, 69, 4]],
    ],
    style: 'pop',
  },
};

let wanted = null;
let playing = null;
let step = 0;
let nextTime = 0;
let timer = null;
let intensity = 0; // 0..3, raised by combos during play

export function setIntensity(n) { intensity = Math.max(0, Math.min(3, n)); }

function scheduleStep(tr, t) {
  const spb = 60 / tr.bpm / 4; // seconds per 16th
  const bar = Math.floor(step / 16);
  const s = step % 16;
  const ci = bar % tr.chords.length;
  const chord = tr.chords[ci];
  const mel = tr.melody[bar % tr.melody.length];
  if (tr.style === 'lofi') {
    if (s === 0) chord.forEach((m, i) => voice(musicBus, t + i * 0.012, mtof(m), spb * 15, { type: 'sine', vol: 0.05, attack: 0.08, release: 0.6, vibrato: 1.5 }));
    if (s === 0 || s === 10) voice(musicBus, t, mtof(tr.bass[ci]), spb * 5, { type: 'triangle', vol: 0.16, release: 0.2, filter: 600 });
    if (s === 0 || s === 8) kick(musicBus, t, 0.32);
    if (s === 4 || s === 12) noise(musicBus, t, 0.18, { vol: 0.07, bp: 1800 });
    if (s % 2 === 0) noise(musicBus, t + (s % 4 === 2 ? spb * 0.18 : 0), 0.04, { vol: 0.025 });
    for (const [st, m, len] of mel) if (st === s) voice(musicBus, t, mtof(m), spb * len, { type: 'sine', vol: 0.07, release: 0.5, vibrato: 2 });
    return;
  }
  // pop / game track
  if (s % 4 === 0) kick(musicBus, t, 0.45);
  if (s === 4 || s === 12) { noise(musicBus, t, 0.16, { vol: 0.12, bp: 2200 }); voice(musicBus, t, 190, 0.05, { type: 'triangle', vol: 0.06 }); }
  if (s % 2 === 1 || intensity >= 2) noise(musicBus, t, 0.035, { vol: s % 2 ? 0.035 : 0.02 });
  if (s % 2 === 0) {
    const m = tr.bass[ci] + (s % 4 === 2 ? 12 : 0);
    voice(musicBus, t, mtof(m), spb * 1.6, { type: 'square', vol: 0.05, release: 0.05, filter: 900 });
  }
  if (s === 0 || s === 6 || s === 8 || s === 14) chord.forEach((m) => voice(musicBus, t, mtof(m + 12), spb * 1.4, { type: 'triangle', vol: 0.022, release: 0.08 }));
  for (const [st, m, len] of mel) if (st === s) {
    voice(musicBus, t, mtof(m), spb * len * 0.92, { type: 'square', vol: 0.045, release: 0.07, vibrato: 3, filter: 3200 });
    voice(musicBus, t, mtof(m), spb * len * 0.92, { type: 'triangle', vol: 0.05, release: 0.1, detune: 7 });
  }
  if (intensity >= 1 && s % 2 === 0) {
    const arp = chord[(s / 2) % chord.length] + 24;
    voice(musicBus, t, mtof(arp), spb * 0.8, { type: 'sine', vol: 0.03 + intensity * 0.008, release: 0.05 });
  }
}

function tick() {
  const tr = TRACKS[playing];
  if (!tr) return;
  while (nextTime < ctx.currentTime + 0.15) {
    scheduleStep(tr, nextTime);
    nextTime += 60 / tr.bpm / 4;
    step = (step + 1) % (16 * tr.melody.length * 2);
  }
}

export function playMusic(name) {
  wanted = name;
  if (!musicOn) return;
  const a = ac();
  if (!a || playing === name) return;
  stopMusic(true);
  playing = name;
  step = 0;
  nextTime = a.currentTime + 0.08;
  timer = setInterval(tick, 30);
}

export function stopMusic(keepWanted = false) {
  if (!keepWanted) wanted = null;
  clearInterval(timer);
  timer = null;
  playing = null;
}

// ---------- haptics ----------
export function buzz(kind = 'light') {
  if (!hapticsOn) return;
  const H = plugin('Haptics');
  if (H) {
    if (kind === 'success') H.notification({ type: 'SUCCESS' }).catch(() => {});
    else H.impact({ style: kind === 'heavy' ? 'HEAVY' : kind === 'medium' ? 'MEDIUM' : 'LIGHT' }).catch(() => {});
  } else if (navigator.vibrate) {
    navigator.vibrate(kind === 'heavy' ? 45 : kind === 'medium' ? 22 : kind === 'success' ? [20, 40, 30] : 8);
  }
}

// ---------- sound effects ----------
const SCALE = [72, 74, 76, 79, 81, 84, 86, 88, 91, 93, 96];
function sfx(fn) { return (...a) => { if (!sfxOn) return; if (!ac()) return; fn(ctx.currentTime, ...a); }; }

export const sound = {
  tap: sfx((t) => voice(sfxBus, t, 880, 0.03, { type: 'sine', vol: 0.08, release: 0.04 })),
  pick: sfx((t) => voice(sfxBus, t, 520, 0.05, { type: 'triangle', vol: 0.09, slide: 260, release: 0.04 })),
  place: sfx((t) => {
    voice(sfxBus, t, 180, 0.05, { type: 'sine', vol: 0.32, slide: -90, release: 0.06 });
    noise(sfxBus, t, 0.05, { vol: 0.08, bp: 900 });
    buzz('light');
  }),
  invalid: sfx((t) => voice(sfxBus, t, 200, 0.1, { type: 'triangle', vol: 0.08, slide: -80 })),
  clear: sfx((t, lines, combo) => {
    const base = Math.min(combo, 5);
    const n = Math.min(lines + 2, 6);
    for (let i = 0; i < n; i++) {
      const m = SCALE[Math.min(base + i, SCALE.length - 1)];
      voice(sfxBus, t + i * 0.045, mtof(m), 0.14, { type: 'triangle', vol: 0.13, release: 0.25 });
      voice(sfxBus, t + i * 0.045, mtof(m + 12), 0.1, { type: 'sine', vol: 0.05, release: 0.2 });
    }
    noise(sfxBus, t, 0.25, { vol: 0.05 + lines * 0.02, hp: 3000 });
    buzz(lines >= 2 ? 'heavy' : 'medium');
  }),
  meow: sfx((t) => {
    const o = ctx.createOscillator(); const f = ctx.createBiquadFilter(); const g = ctx.createGain();
    o.type = 'sawtooth';
    o.frequency.setValueAtTime(520, t); o.frequency.linearRampToValueAtTime(820, t + 0.12); o.frequency.exponentialRampToValueAtTime(430, t + 0.42);
    f.type = 'bandpass'; f.Q.value = 6;
    f.frequency.setValueAtTime(900, t); f.frequency.linearRampToValueAtTime(2200, t + 0.12); f.frequency.exponentialRampToValueAtTime(700, t + 0.42);
    g.gain.setValueAtTime(0.0001, t); g.gain.exponentialRampToValueAtTime(0.25, t + 0.04); g.gain.exponentialRampToValueAtTime(0.0001, t + 0.45);
    o.connect(f).connect(g).connect(sfxBus); o.start(t); o.stop(t + 0.5);
  }),
  perfect: sfx((t) => {
    [0, 2, 4, 5, 7, 9, 10].forEach((k, i) => voice(sfxBus, t + i * 0.06, mtof(SCALE[k]), 0.2, { type: 'square', vol: 0.05, release: 0.3, filter: 4000 }));
    buzz('success');
  }),
  coin: sfx((t) => { voice(sfxBus, t, 1318, 0.06, { type: 'square', vol: 0.05, filter: 5000 }); voice(sfxBus, t + 0.06, 1760, 0.14, { type: 'square', vol: 0.05, filter: 5000 }); }),
  boom: sfx((t) => { kick(sfxBus, t, 0.8); noise(sfxBus, t, 0.5, { vol: 0.2, bp: 400 }); buzz('heavy'); }),
  gameOver: sfx((t) => [67, 64, 60, 55].forEach((m, i) => voice(sfxBus, t + i * 0.16, mtof(m), 0.22, { type: 'triangle', vol: 0.1, release: 0.3 }))),
  reveal: sfx((t, tier) => {
    const n = 3 + tier * 2;
    for (let i = 0; i < n; i++) voice(sfxBus, t + i * 0.055, mtof(SCALE[i % SCALE.length] + (i >= SCALE.length ? 12 : 0)), 0.16, { type: 'triangle', vol: 0.1, release: 0.3 });
    if (tier >= 3) { buzz('success'); noise(sfxBus, t + n * 0.055, 0.8, { vol: 0.08, hp: 5000 }); }
  }),
  tick: sfx((t) => voice(sfxBus, t, 1500, 0.015, { type: 'square', vol: 0.025 })),
  levelUp: sfx((t) => [0, 2, 4, 7].forEach((k, i) => voice(sfxBus, t + i * 0.09, mtof(SCALE[k]), 0.22, { type: 'triangle', vol: 0.11, release: 0.3 }))),
  whoosh: sfx((t) => noise(sfxBus, t, 0.25, { vol: 0.06, bp: 1200 })),
};

// Browsers only allow audio after a user gesture: unlock on the first touch.
export function unlockOnGesture() {
  const go = () => { ac(); if (wanted && !playing) playMusic(wanted); };
  window.addEventListener('pointerdown', go, { once: false, passive: true });
}
