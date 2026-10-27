"use client";

/**
 * Original sound effects synthesised with the Web Audio API (no audio files,
 * no licensing concerns). The AudioContext is created lazily on the first
 * call, which always follows a user gesture, so browser autoplay rules hold.
 */
export type Sfx = "select" | "correct" | "wrong" | "tick" | "victory" | "start";

let ctx: AudioContext | null = null;

function audio(): AudioContext | null {
  if (typeof window === "undefined") return null;
  const Ctor = window.AudioContext ?? (window as unknown as { webkitAudioContext?: typeof AudioContext }).webkitAudioContext;
  if (!Ctor) return null;
  ctx ??= new Ctor();
  if (ctx.state === "suspended") void ctx.resume();
  return ctx;
}

function tone(ac: AudioContext, freq: number, start: number, dur: number, type: OscillatorType = "sine", gain = 0.12) {
  const osc = ac.createOscillator();
  const g = ac.createGain();
  osc.type = type;
  osc.frequency.setValueAtTime(freq, ac.currentTime + start);
  g.gain.setValueAtTime(0.0001, ac.currentTime + start);
  g.gain.exponentialRampToValueAtTime(gain, ac.currentTime + start + 0.01);
  g.gain.exponentialRampToValueAtTime(0.0001, ac.currentTime + start + dur);
  osc.connect(g).connect(ac.destination);
  osc.start(ac.currentTime + start);
  osc.stop(ac.currentTime + start + dur + 0.02);
}

const PATTERNS: Record<Sfx, (ac: AudioContext) => void> = {
  select: (ac) => tone(ac, 660, 0, 0.06, "triangle", 0.06),
  correct: (ac) => {
    tone(ac, 660, 0, 0.12, "triangle");
    tone(ac, 990, 0.08, 0.2, "triangle");
  },
  wrong: (ac) => {
    tone(ac, 220, 0, 0.18, "sawtooth", 0.06);
    tone(ac, 165, 0.12, 0.25, "sawtooth", 0.05);
  },
  tick: (ac) => tone(ac, 1200, 0, 0.04, "square", 0.03),
  start: (ac) => tone(ac, 880, 0, 0.12, "triangle", 0.08),
  victory: (ac) => [523, 659, 784, 1047].forEach((f, i) => tone(ac, f, i * 0.11, 0.25, "triangle", 0.1)),
};

export function playSfx(name: Sfx, enabled: boolean): void {
  if (!enabled) return;
  try {
    const ac = audio();
    if (ac) PATTERNS[name](ac);
  } catch {
    // Audio is optional; never let it break gameplay.
  }
}
