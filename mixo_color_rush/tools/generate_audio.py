#!/usr/bin/env python3
"""Generates every sound effect and music loop of MIXO: Color Rush.

All audio is synthesised from scratch (no third-party samples), so the
project owns it entirely. Output: 22.05 kHz mono 16-bit WAV files in
assets/generated/audio/. Deterministic: same script -> same bytes.

Usage: python3 tools/generate_audio.py
"""
import os
import wave

import numpy as np

SR = 22050
OUT = os.path.join(os.path.dirname(__file__), '..', 'assets', 'generated', 'audio')
rng = np.random.default_rng(42)


def t(sec):
    return np.arange(int(SR * sec)) / SR


def env(n, a=0.005, d=0.1, s=0.0, r=0.05, sustain_level=0.0):
    """ADSR envelope of n samples (times in seconds)."""
    a_n, d_n, r_n = int(a * SR), int(d * SR), int(r * SR)
    s_n = max(0, n - a_n - d_n - r_n)
    parts = [
        np.linspace(0, 1, a_n, endpoint=False),
        np.linspace(1, sustain_level, d_n, endpoint=False),
        np.full(s_n, sustain_level),
        np.linspace(sustain_level, 0, r_n),
    ]
    e = np.concatenate(parts)
    if len(e) < n:
        e = np.pad(e, (0, n - len(e)))
    return e[:n]


def osc(freq, sec, kind='sine', duty=0.5):
    tt = t(sec)
    f = np.broadcast_to(freq, tt.shape) if np.ndim(freq) else np.full(tt.shape, freq)
    phase = 2 * np.pi * np.cumsum(f) / SR
    if kind == 'sine':
        return np.sin(phase)
    if kind == 'square':
        return np.where((phase / (2 * np.pi)) % 1 < duty, 1.0, -1.0)
    if kind == 'tri':
        return 2 * np.abs(2 * ((phase / (2 * np.pi)) % 1) - 1) - 1
    if kind == 'saw':
        return 2 * ((phase / (2 * np.pi)) % 1) - 1
    raise ValueError(kind)


def noise(sec):
    return rng.uniform(-1, 1, int(SR * sec))


def note(midi):
    return 440.0 * 2 ** ((midi - 69) / 12)


def write(name, x, gain=0.8):
    x = np.asarray(x, dtype=np.float64)
    peak = np.max(np.abs(x)) or 1.0
    x = np.clip(x / peak * gain, -1, 1)
    data = (x * 32767).astype('<i2').tobytes()
    path = os.path.join(OUT, name + '.wav')
    with wave.open(path, 'wb') as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data)
    print(f'{name}.wav  {len(x) / SR:.2f}s')


# ---------------------------------------------------------------- SFX
def sfx_gate_ok():
    sec = 0.16
    f = np.linspace(660, 1320, int(SR * sec))
    x = osc(f, sec, 'square', 0.25) * env(len(f), 0.002, 0.14)
    return x * 0.6 + osc(f * 2, sec) * env(len(f), 0.002, 0.08) * 0.3


def sfx_gate_fail():
    sec = 0.32
    f = np.linspace(330, 180, int(SR * sec))
    x = osc(f, sec, 'tri') * env(len(f), 0.01, 0.3)
    return x  # soft "bonk", not scary


def sfx_drop():
    sec = 0.18
    f = 300 + 700 * np.exp(-t(sec) * 25)
    return osc(f, sec) * env(len(f), 0.002, 0.17)


def sfx_lane():
    sec = 0.12
    n = noise(sec)
    # simple band-ish filter: moving average
    k = np.ones(12) / 12
    x = np.convolve(n, k, mode='same')
    return x * env(len(x), 0.02, 0.1) * 0.6


def sfx_jump():
    sec = 0.2
    f = np.linspace(300, 900, int(SR * sec))
    return osc(f, sec, 'square', 0.5) * env(len(f), 0.003, 0.19) * 0.5


def sfx_combo():
    out = []
    for m in (72, 76, 79, 84):
        sec = 0.07
        x = osc(note(m), sec, 'square', 0.25) * env(int(SR * sec), 0.002, 0.06)
        out.append(x)
    return np.concatenate(out)


def sfx_near_miss():
    sec = 0.35
    x = np.zeros(int(SR * sec))
    for i, m in enumerate((88, 91, 96)):
        start = int(i * 0.05 * SR)
        s = osc(note(m), sec - i * 0.05) * env(int(SR * (sec - i * 0.05)), 0.002, 0.25)
        x[start:start + len(s)] += s
    return x


def sfx_game_over():
    out = []
    for m in (72, 67, 64, 60):
        sec = 0.16
        out.append(osc(note(m), sec, 'tri') * env(int(SR * sec), 0.005, 0.15))
    return np.concatenate(out)


def sfx_record():
    out = []
    for m, sec in ((72, 0.1), (76, 0.1), (79, 0.1), (84, 0.35)):
        out.append(osc(note(m), sec, 'square', 0.3) * env(int(SR * sec), 0.003, sec * 0.9, r=0.02))
    return np.concatenate(out)


def sfx_click():
    sec = 0.05
    return osc(1000, sec, 'sine') * env(int(SR * sec), 0.001, 0.045)


def sfx_unlock():
    out = []
    for m in (79, 84, 88, 91):
        sec = 0.09
        out.append(osc(note(m), sec) * env(int(SR * sec), 0.002, 0.085))
    return np.concatenate(out)


# ---------------------------------------------------------------- Music
BPM = 120
BEAT = 60 / BPM
BARS = 4
LOOP = BARS * 4 * BEAT  # 8 s
N = int(SR * LOOP)

# C major pentatonic progression: C - A min - F - G
CHORDS = [(48, 52, 55), (45, 48, 52), (41, 45, 48), (43, 47, 50)]


def place(buf, sig, at):
    i = int(at * SR)
    j = min(len(buf), i + len(sig))
    buf[i:j] += sig[: j - i]


def kick():
    sec = 0.18
    f = 50 + 120 * np.exp(-t(sec) * 30)
    return osc(f, sec) * env(int(SR * sec), 0.001, 0.17)


def hat():
    sec = 0.04
    return np.diff(noise(sec), prepend=0) * env(int(SR * sec), 0.001, 0.035) * 0.35


def layer_base():
    buf = np.zeros(N)
    for bar in range(BARS):
        root = CHORDS[bar][0] - 12
        for beat in range(4):
            at = (bar * 4 + beat) * BEAT
            place(buf, kick() * 0.9, at)
            place(buf, hat(), at + BEAT / 2)
            sec = BEAT * 0.45
            b = osc(note(root + (7 if beat % 2 else 0)), sec, 'tri') * env(int(SR * sec), 0.005, sec * 0.9)
            place(buf, b * 0.5, at)
    return buf


def layer_arp():
    buf = np.zeros(N)
    for bar in range(BARS):
        chord = CHORDS[bar]
        for step in range(8):
            m = chord[step % 3] + 12 + (12 if step >= 6 else 0)
            sec = BEAT / 2 * 0.8
            s = osc(note(m), sec, 'square', 0.25) * env(int(SR * sec), 0.002, sec * 0.8)
            place(buf, s * 0.18, (bar * 4) * BEAT + step * BEAT / 2)
    return buf


MELODY = [
    (72, 1), (76, 0.5), (79, 0.5), (76, 1), (72, 1),
    (69, 1), (72, 0.5), (76, 0.5), (74, 2),
    (77, 1), (76, 0.5), (74, 0.5), (72, 1), (69, 1),
    (71, 1), (74, 1), (79, 2),
]


def layer_lead():
    buf = np.zeros(N)
    at = 0.0
    for m, beats in MELODY:
        sec = beats * BEAT * 0.9
        vib = note(m) * (1 + 0.004 * np.sin(2 * np.pi * 6 * t(sec)))
        s = osc(vib, sec, 'square', 0.5) * env(int(SR * sec), 0.01, 0.1, r=0.05, sustain_level=0.6)
        place(buf, s * 0.16, at)
        at += beats * BEAT
    return buf


def main():
    os.makedirs(OUT, exist_ok=True)
    write('gate_ok', sfx_gate_ok())
    write('gate_fail', sfx_gate_fail(), 0.6)
    write('drop', sfx_drop())
    write('lane', sfx_lane(), 0.4)
    write('jump', sfx_jump(), 0.6)
    write('combo', sfx_combo(), 0.7)
    write('near_miss', sfx_near_miss(), 0.7)
    write('game_over', sfx_game_over(), 0.7)
    write('record', sfx_record(), 0.7)
    write('click', sfx_click(), 0.5)
    write('unlock', sfx_unlock(), 0.7)

    base, arp, lead = layer_base(), layer_arp(), layer_lead()
    write('music_1', base, 0.55)
    write('music_2', base + arp, 0.6)
    write('music_3', base + arp + lead, 0.65)


if __name__ == '__main__':
    main()
