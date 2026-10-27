// Tiny WebAudio synth: no audio files needed, works offline.

let ctx = null;
let enabled = true;
let hapticsOn = true;

export function setAudio(sound, haptics) {
  enabled = sound;
  hapticsOn = haptics;
}

function ac() {
  if (!ctx) {
    const AC = window.AudioContext || window.webkitAudioContext;
    if (!AC) return null;
    ctx = new AC();
  }
  if (ctx.state === 'suspended') ctx.resume();
  return ctx;
}

function tone(freq, dur, { type = 'sine', vol = 0.15, delay = 0, slide = 0 } = {}) {
  if (!enabled) return;
  const a = ac();
  if (!a) return;
  const t = a.currentTime + delay;
  const o = a.createOscillator();
  const g = a.createGain();
  o.type = type;
  o.frequency.setValueAtTime(freq, t);
  if (slide) o.frequency.exponentialRampToValueAtTime(Math.max(40, freq + slide), t + dur);
  g.gain.setValueAtTime(0.0001, t);
  g.gain.exponentialRampToValueAtTime(vol, t + 0.01);
  g.gain.exponentialRampToValueAtTime(0.0001, t + dur);
  o.connect(g).connect(a.destination);
  o.start(t);
  o.stop(t + dur + 0.02);
}

export function buzz(pattern) {
  if (hapticsOn && navigator.vibrate) navigator.vibrate(pattern);
}

const SCALE = [523.25, 587.33, 659.25, 783.99, 880, 1046.5, 1174.66, 1318.5, 1568];

export const sfx = {
  tap: () => tone(660, 0.05, { type: 'triangle', vol: 0.08 }),
  pick: () => tone(440, 0.06, { type: 'triangle', vol: 0.08, slide: 200 }),
  place: () => { tone(220, 0.08, { type: 'square', vol: 0.06 }); buzz(8); },
  invalid: () => tone(160, 0.12, { type: 'sawtooth', vol: 0.05, slide: -60 }),
  clear: (lines, combo) => {
    const start = Math.min(combo, 4);
    for (let i = 0; i < Math.min(lines + 2, 6); i++) tone(SCALE[Math.min(start + i, SCALE.length - 1)], 0.16, { type: 'triangle', vol: 0.12, delay: i * 0.055 });
    buzz(lines > 1 ? [20, 30, 30] : 18);
  },
  meow: () => {
    tone(700, 0.28, { type: 'sawtooth', vol: 0.05, slide: 350 });
    tone(1050, 0.22, { type: 'sine', vol: 0.06, delay: 0.08, slide: -500 });
  },
  perfect: () => { [0, 2, 4, 5, 7, 8].forEach((k, i) => tone(SCALE[k], 0.22, { type: 'square', vol: 0.06, delay: i * 0.07 })); buzz([30, 40, 30, 40, 60]); },
  coin: () => { tone(988, 0.07, { type: 'square', vol: 0.06 }); tone(1319, 0.14, { type: 'square', vol: 0.06, delay: 0.07 }); },
  boom: () => { tone(120, 0.4, { type: 'sawtooth', vol: 0.12, slide: -80 }); buzz(60); },
  gameOver: () => [392, 330, 262, 196].forEach((f, i) => tone(f, 0.25, { type: 'triangle', vol: 0.1, delay: i * 0.15 })),
  reveal: (tier) => {
    const n = 3 + tier * 2;
    for (let i = 0; i < n; i++) tone(SCALE[i % SCALE.length] * (i >= SCALE.length ? 2 : 1), 0.18, { type: 'triangle', vol: 0.1, delay: i * 0.06 });
    if (tier >= 3) buzz([40, 40, 80, 40, 120]);
  },
  spinTick: () => tone(1200, 0.02, { type: 'square', vol: 0.03 }),
  levelUp: () => [0, 2, 4, 7].forEach((k, i) => tone(SCALE[k] * 1.0, 0.2, { type: 'triangle', vol: 0.1, delay: i * 0.09 })),
};
