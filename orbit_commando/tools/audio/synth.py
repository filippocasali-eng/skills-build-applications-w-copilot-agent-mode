"""Chiptune synthesis for ORBIT COMMANDO '94.

A tiny 16-bit-console-style sound chip in numpy:
  - 2 pulse channels (duty 12.5 / 25 / 50 %), 1 triangle, 1 noise (LFSR)
  - ADSR envelopes, pitch slides, vibrato, arpeggios
  - a pattern "tracker" (rows of notes per channel) for music

Everything is deterministic: same code, same samples.
"""
import numpy as np

SR = 22050

NOTE_NAMES = {"C": 0, "C#": 1, "D": 2, "D#": 3, "E": 4, "F": 5, "F#": 6, "G": 7, "G#": 8, "A": 9, "A#": 10, "B": 11}


def note_freq(name):
    """'A4' -> 440 Hz. Supports sharps: 'C#5'."""
    pitch, octave = name[:-1], int(name[-1])
    semis = NOTE_NAMES[pitch] + (octave - 4) * 12 - 9
    return 440.0 * 2 ** (semis / 12)


def _phase(freq, n):
    """Phase accumulator for a (possibly time-varying) frequency array."""
    f = np.broadcast_to(np.asarray(freq, dtype=np.float64), (n,))
    return np.cumsum(f) / SR


def pulse(freq, n, duty=0.5):
    ph = _phase(freq, n) % 1.0
    return np.where(ph < duty, 1.0, -1.0)


def triangle(freq, n):
    ph = _phase(freq, n) % 1.0
    # 4-bit stepped triangle, like the hardware.
    tri = 1 - 4 * np.abs(ph - 0.5)
    return np.round(tri * 7.5) / 7.5


def saw(freq, n):
    ph = _phase(freq, n) % 1.0
    return 2 * ph - 1


_noise_cache = {}


def noise(n, period=1, short=False):
    """15-bit LFSR noise; `period` holds each sample (lower = brighter)."""
    key = (n, period, short)
    if key in _noise_cache:
        return _noise_cache[key].copy()
    reg = 1
    steps = n // max(1, period) + 2
    out = np.empty(steps)
    tap = 6 if short else 1
    for i in range(steps):
        bit = (reg ^ (reg >> tap)) & 1
        reg = (reg >> 1) | (bit << 14)
        out[i] = 1.0 if reg & 1 else -1.0
    res = np.repeat(out, max(1, period))[:n]
    _noise_cache[key] = res
    return res.copy()


def adsr(n, a=0.005, d=0.05, s=0.6, r=0.05):
    a_n, d_n, r_n = int(a * SR), int(d * SR), int(r * SR)
    s_n = max(0, n - a_n - d_n - r_n)
    env = np.concatenate([
        np.linspace(0, 1, max(1, a_n), endpoint=False),
        np.linspace(1, s, max(1, d_n), endpoint=False),
        np.full(s_n, s),
        np.linspace(s, 0, max(1, r_n)),
    ])
    if len(env) < n:
        env = np.pad(env, (0, n - len(env)))
    return env[:n]


def slide(f0, f1, n, curve=1.0):
    t = np.linspace(0, 1, n) ** curve
    return f0 * (f1 / f0) ** t


def vibrato(freq, n, depth=0.01, rate=6.0, delay=0.1):
    t = np.arange(n) / SR
    amt = np.clip((t - delay) / 0.1, 0, 1) * depth
    return freq * (1 + amt * np.sin(2 * np.pi * rate * t))


def bitcrush(x, bits=5, hold=3):
    levels = 2 ** bits / 2
    y = np.round(x * levels) / levels
    if hold > 1:
        y = np.repeat(y[::hold], hold)[: len(x)]
    return y


def mix(*tracks):
    n = max(len(t) for t in tracks)
    out = np.zeros(n)
    for t in tracks:
        out[: len(t)] += t
    return out


def normalize(x, peak=0.85):
    m = np.max(np.abs(x)) or 1.0
    return x / m * peak


def to_int16(x):
    return (np.clip(x, -1, 1) * 32000).astype(np.int16)


# --------------------------------------------------------------- tracker --

class Song:
    """Rows-based tracker. Each channel is a list of row strings:
    'C4' note, '.' sustain, '-' rest/cut, 'C4~' slide target (pulse only).
    Drums on the noise channel: 'K' kick, 'S' snare, 'H' hat, 'O' open hat.
    """

    def __init__(self, bpm=140, rows_per_beat=4):
        self.bpm = bpm
        self.rpb = rows_per_beat
        self.channels = {}

    @property
    def row_len(self):
        return int(SR * 60 / self.bpm / self.rpb)

    def add(self, name, rows, kind="pulse", duty=0.5, vol=0.25, env=(0.004, 0.08, 0.55, 0.04), vib=0.0, arp=None):
        self.channels[name] = dict(rows=rows, kind=kind, duty=duty, vol=vol, env=env, vib=vib, arp=arp)

    def render(self, loops=1):
        out = []
        for ch in self.channels.values():
            out.append(self._render_channel(ch))
        song = mix(*out)
        return np.tile(song, loops)

    def _render_channel(self, ch):
        rows = ch["rows"]
        rl = self.row_len
        total = len(rows) * rl
        buf = np.zeros(total)
        i = 0
        while i < len(rows):
            tok = rows[i]
            if tok in (".", "-", ""):
                i += 1
                continue
            # note length: this row + following sustains
            j = i + 1
            while j < len(rows) and rows[j] == ".":
                j += 1
            n = (j - i) * rl
            start = i * rl
            if ch["kind"] == "noise":
                seg = self._drum(tok, rl * 2)
                end = min(total, start + len(seg))
                buf[start:end] += seg[: end - start] * ch["vol"]
                i = j
                continue
            f = note_freq(tok)
            if ch["arp"]:
                # Arpeggio: cycle through chord offsets every 1/50 s.
                steps = np.arange(n) // int(SR / 50)
                offs = np.array(ch["arp"])[steps % len(ch["arp"])]
                freq = f * 2 ** (offs / 12)
            else:
                freq = np.full(n, f)
            if ch["vib"]:
                freq = vibrato(freq, n, depth=ch["vib"])
            if ch["kind"] == "triangle":
                wave = triangle(freq, n)
            elif ch["kind"] == "saw":
                wave = saw(freq, n)
            else:
                wave = pulse(freq, n, ch["duty"])
            a, d, s, r = ch["env"]
            buf[start:start + n] += wave * adsr(n, a, d, s, r) * ch["vol"]
            i = j
        return buf

    @staticmethod
    def _drum(tok, n):
        if tok == "K":
            m = int(0.12 * SR)
            f = slide(160, 45, m, 0.5)
            return triangle(f, m) * adsr(m, 0.001, 0.02, 0.7, 0.08) * 1.6
        if tok == "S":
            m = int(0.14 * SR)
            return (noise(m, 1) * 0.8 + pulse(slide(220, 140, m), m) * 0.3) * adsr(m, 0.001, 0.03, 0.35, 0.09)
        if tok == "H":
            m = int(0.04 * SR)
            return noise(m, 1, short=True) * adsr(m, 0.001, 0.01, 0.3, 0.02) * 0.5
        if tok == "O":
            m = int(0.16 * SR)
            return noise(m, 1, short=True) * adsr(m, 0.001, 0.02, 0.4, 0.12) * 0.45
        return np.zeros(n)
