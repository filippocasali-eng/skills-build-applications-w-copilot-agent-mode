"""Generates every sound of ORBIT COMMANDO '94 (all original).

    python3 tools/audio/build_audio.py     # needs numpy + ffmpeg (libvorbis)

Writes assets/audio/:
  sfx_<name>.wav      33 sound effects (22 kHz mono 16-bit)
  music_<name>.ogg    6 looping chiptune tracks
  jingle_<name>.ogg   6 short jingles
"""
import os
import random
import subprocess
import sys
import tempfile
import wave

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

from synth import (SR, Song, adsr, bitcrush, mix, noise, normalize, note_freq,  # noqa: E402
                   pulse, saw, slide, to_int16, triangle)

OUT = os.path.abspath(os.path.join(HERE, "..", "..", "assets", "audio"))


def n_(sec):
    return int(sec * SR)


# ===================================================================== SFX ===

def sfx_shot():
    n = n_(0.09)
    return pulse(slide(1400, 300, n, 0.6), n, 0.25) * adsr(n, 0.001, 0.02, 0.4, 0.05) * 0.6


def sfx_laser():
    n = n_(0.12)
    f = 900 + 120 * np.sin(np.arange(n) / SR * 2 * np.pi * 60)
    return pulse(f, n, 0.125) * adsr(n, 0.001, 0.03, 0.6, 0.05) * 0.4


def sfx_plasma():
    n = n_(0.2)
    return mix(pulse(slide(300, 900, n, 0.5), n, 0.5) * 0.4, triangle(slide(150, 450, n), n) * 0.5) * adsr(n, 0.002, 0.05, 0.5, 0.1)


def sfx_flame():
    n = n_(0.14)
    return noise(n, 3) * adsr(n, 0.01, 0.04, 0.5, 0.06) * 0.45


def sfx_enemy_shot():
    n = n_(0.1)
    return pulse(slide(700, 200, n, 0.7), n, 0.5) * adsr(n, 0.001, 0.02, 0.4, 0.06) * 0.45


def sfx_hit():
    n = n_(0.05)
    return mix(noise(n, 2) * 0.5, pulse(slide(500, 200, n), n, 0.25) * 0.4) * adsr(n, 0.001, 0.01, 0.3, 0.03)


def sfx_tink():
    n = n_(0.08)
    return pulse(np.full(n, 2400.0), n, 0.125) * adsr(n, 0.001, 0.01, 0.2, 0.06) * 0.35


def _boom(sec, period):
    n = n_(sec)
    body = noise(n, period) * adsr(n, 0.001, 0.08, 0.5, sec * 0.7)
    thump = triangle(slide(120, 30, n, 0.5), n) * adsr(n, 0.001, 0.05, 0.6, sec * 0.5)
    return mix(body * 0.7, thump * 0.9)


def sfx_explosion():
    return _boom(0.45, 6)


def sfx_big_explosion():
    return mix(_boom(0.9, 9), np.pad(_boom(0.5, 5) * 0.6, (n_(0.15), 0)))


def sfx_jump():
    n = n_(0.12)
    return pulse(slide(300, 700, n, 0.6), n, 0.5) * adsr(n, 0.002, 0.03, 0.5, 0.05) * 0.4


def sfx_land():
    n = n_(0.1)
    return mix(noise(n, 8) * 0.5, triangle(slide(100, 50, n), n) * 0.6) * adsr(n, 0.001, 0.03, 0.3, 0.05)


def sfx_dash():
    n = n_(0.18)
    return noise(n, 2) * np.linspace(1, 0, n) * adsr(n, 0.02, 0.05, 0.6, 0.08) * 0.5


def sfx_knife():
    n = n_(0.1)
    return mix(noise(n, 1) * 0.4, pulse(slide(2000, 800, n), n, 0.125) * 0.3) * adsr(n, 0.001, 0.02, 0.3, 0.05)


def sfx_grenade():
    n = n_(0.12)
    return pulse(slide(500, 900, n), n, 0.25) * adsr(n, 0.002, 0.02, 0.4, 0.06) * 0.35


def _arp(notes, step=0.05, duty=0.5, vol=0.4):
    parts = []
    for name in notes:
        n = n_(step)
        parts.append(pulse(np.full(n, note_freq(name)), n, duty) * adsr(n, 0.001, 0.01, 0.8, 0.01) * vol)
    return np.concatenate(parts)


def sfx_pickup():
    return _arp(["C5", "E5", "G5", "C6"], 0.04)


def sfx_weapon():
    return _arp(["G4", "C5", "E5", "G5", "C6", "E6"], 0.045, 0.25)


def sfx_hostage():
    return _arp(["E5", "G5", "E5", "C6"], 0.07, 0.5)


def sfx_cassette():
    return _arp(["A5", "C#6", "E6", "A6", "E6", "A6"], 0.05, 0.125)


def sfx_checkpoint():
    return _arp(["C5", "G5", "C6"], 0.09, 0.25)


def sfx_one_up():
    return _arp(["E5", "G5", "E6", "C6", "D6", "G6"], 0.07, 0.5)


def sfx_hurt():
    n = n_(0.2)
    return pulse(slide(600, 150, n), n, 0.5) * adsr(n, 0.001, 0.03, 0.5, 0.1) * 0.45


def sfx_death():
    n = n_(0.6)
    f = slide(800, 80, n, 0.8) * (1 + 0.05 * np.sin(np.arange(n) / SR * 2 * np.pi * 18))
    return mix(pulse(f, n, 0.5) * 0.45 * adsr(n, 0.001, 0.1, 0.6, 0.3), _boom(0.4, 6) * 0.5)


def sfx_tell():
    # Two quick warning beeps: the >= 300 ms attack tell, audible.
    n = n_(0.06)
    b = pulse(np.full(n, 1500.0), n, 0.5) * adsr(n, 0.001, 0.01, 0.6, 0.02) * 0.3
    return np.concatenate([b, np.zeros(n_(0.04)), b])


def sfx_vehicle():
    n = n_(0.35)
    return mix(saw(slide(80, 160, n), n) * 0.4, noise(n, 6) * 0.2) * adsr(n, 0.01, 0.1, 0.6, 0.15)


def sfx_eject():
    n = n_(0.4)
    return mix(pulse(slide(200, 1600, n, 0.5), n, 0.5) * 0.35, _boom(0.35, 6) * 0.5)


def sfx_boss_warn():
    parts = []
    for _ in range(3):
        n = n_(0.18)
        parts.append(pulse(np.full(n, 330.0), n, 0.5) * adsr(n, 0.005, 0.02, 0.8, 0.03) * 0.4)
        parts.append(np.zeros(n_(0.08)))
    return np.concatenate(parts)


def sfx_select():
    n = n_(0.04)
    return pulse(np.full(n, 1200.0), n, 0.25) * adsr(n, 0.001, 0.01, 0.5, 0.02) * 0.3


def sfx_confirm():
    return _arp(["C6", "G6"], 0.05, 0.25, 0.35)


def sfx_tick():
    n = n_(0.025)
    return pulse(np.full(n, 1800.0), n, 0.125) * adsr(n, 0.001, 0.005, 0.4, 0.01) * 0.3


def sfx_stamp():
    n = n_(0.3)
    return mix(noise(n, 10) * adsr(n, 0.001, 0.04, 0.3, 0.15) * 0.7, triangle(slide(90, 40, n), n) * adsr(n, 0.001, 0.08, 0.4, 0.15))


def sfx_coin():
    return _arp(["B5", "E6"], 0.06, 0.5, 0.4)


def _voice(formants, f0s, n, crush=4):
    """Crude formant voice: a buzzy source through moving resonances,
    then bit-crushed for that 8-bit sample sound."""
    src = saw(f0s, n)
    t = np.arange(n) / SR
    out = np.zeros(n)
    for f, amp in formants:
        out += np.sin(2 * np.pi * np.cumsum(f) / SR) * amp
    voiced = src * 0.5 + out * src * 0.8
    return bitcrush(normalize(voiced) * adsr(n, 0.01, 0.05, 0.8, 0.1), bits=crush, hold=2) * (0.6 + 0.4 * np.sin(t * 30))


def sfx_scream():
    # Comic little yelp of a defeated grunt.
    n = n_(0.28)
    f0 = slide(520, 260, n, 0.7)
    return _voice([(slide(900, 600, n), 0.6), (slide(2400, 1700, n), 0.3)], f0, n) * 0.5


def sfx_yeah():
    # "Yeah!" bark: 'ye' -> 'ah' formant glide, bit-crushed.
    n = n_(0.45)
    f0 = slide(190, 150, n, 0.6)
    f1 = np.concatenate([slide(300, 750, n // 2), np.full(n - n // 2, 750.0)])
    f2 = np.concatenate([slide(2200, 1200, n // 2), np.full(n - n // 2, 1200.0)])
    return _voice([(f1, 0.7), (f2, 0.35)], f0, n, crush=3) * 0.6


SFX = {
    "shot": sfx_shot, "laser": sfx_laser, "plasma": sfx_plasma, "flame": sfx_flame,
    "enemyShot": sfx_enemy_shot, "hit": sfx_hit, "tink": sfx_tink, "explosion": sfx_explosion,
    "bigExplosion": sfx_big_explosion, "jump": sfx_jump, "land": sfx_land, "dash": sfx_dash,
    "knife": sfx_knife, "grenade": sfx_grenade, "pickup": sfx_pickup, "weapon": sfx_weapon,
    "hostage": sfx_hostage, "cassette": sfx_cassette, "checkpoint": sfx_checkpoint,
    "oneUp": sfx_one_up, "hurt": sfx_hurt, "death": sfx_death, "tell": sfx_tell,
    "vehicle": sfx_vehicle, "eject": sfx_eject, "bossWarn": sfx_boss_warn, "select": sfx_select,
    "confirm": sfx_confirm, "tick": sfx_tick, "stamp": sfx_stamp, "coin": sfx_coin,
    "scream": sfx_scream, "yeah": sfx_yeah,
}

# =================================================================== MUSIC ===

SCALES = {
    "minor": [0, 2, 3, 5, 7, 8, 10],
    "major": [0, 2, 4, 5, 7, 9, 11],
    "dorian": [0, 2, 3, 5, 7, 9, 10],
    "phrygian": [0, 1, 3, 5, 7, 8, 10],
}
CHORD = {"": [0, 4, 7], "m": [0, 3, 7], "7": [0, 4, 7, 10], "m7": [0, 3, 7, 10], "dim": [0, 3, 6], "sus": [0, 5, 7]}
NAMES = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]


def midi_to_name(m):
    return f"{NAMES[m % 12]}{m // 12 - 1}"


def parse_chord(c):
    root = c[:2] if len(c) > 1 and c[1] == "#" else c[:1]
    return NAMES.index(root), CHORD[c[len(root):]]


def bass_rows(chords, octave=2, pattern="R.R.R.RRR.R.R5.R"):
    rows = []
    for c in chords:
        r, ch = parse_chord(c)
        base = (octave + 1) * 12 + r
        for p in pattern:
            if p == "R":
                rows.append(midi_to_name(base))
            elif p == "5":
                rows.append(midi_to_name(base + 7))
            elif p == "8":
                rows.append(midi_to_name(base + 12))
            else:
                rows.append(".")
    return rows


def arp_rows(chords, octave=4, pattern="1.3.5.3.1.3.5.8."):
    rows = []
    for c in chords:
        r, ch = parse_chord(c)
        base = (octave + 1) * 12 + r
        tones = {"1": ch[0], "3": ch[1], "5": ch[2], "8": 12, "7": ch[3] if len(ch) > 3 else 10}
        for p in pattern:
            rows.append(midi_to_name(base + tones[p]) if p in tones else ".")
    return rows


def melody_rows(chords, key, scale, seed, octave=5, rhythms=None):
    """Phrase-structured melody (A A' B A''): bar motifs reuse the same
    rhythm, chord tones on strong beats, scale steps in between."""
    rng = random.Random(seed)
    rhythms = rhythms or ["x.x.x...x.x.xxx.", "x...x.x.x...x...", "x.xxx.x.x.x.x...", "xx.x..x.x.x.x..."]
    scale_notes = [(octave + 1) * 12 + NAMES.index(key) + s + 12 * o for o in (-1, 0, 1) for s in SCALES[scale]]
    motifs = {}
    rows = []
    prev = scale_notes[7]
    for bar, c in enumerate(chords):
        phrase_pos = bar % 8
        section = "A" if phrase_pos < 4 else "B"
        motif_key = (section, phrase_pos % 2)
        rhythm = rhythms[(phrase_pos // 2) % len(rhythms)] if section == "B" else rhythms[phrase_pos % 2]
        r, ch = parse_chord(c)
        chord_pcs = {(r + x) % 12 for x in ch}
        bar_rows = []
        if motif_key in motifs and rng.random() < 0.7:
            # Repeat the motif shape transposed onto this chord.
            shape = motifs[motif_key]
            root_note = min((n for n in scale_notes if n % 12 == r and n >= scale_notes[5]), default=prev)
            for step in shape:
                if step is None:
                    bar_rows.append(".")
                else:
                    target = root_note + step
                    nearest = min(scale_notes, key=lambda n: abs(n - target))
                    bar_rows.append(midi_to_name(nearest))
                    prev = nearest
        else:
            shape = []
            root_note = min((n for n in scale_notes if n % 12 == r and n >= scale_notes[5]), default=prev)
            for i, sym in enumerate(rhythm):
                if sym != "x":
                    bar_rows.append(".")
                    shape.append(None)
                    continue
                strong = i % 4 == 0
                cands = [n for n in scale_notes if abs(n - prev) <= (7 if strong else 3)]
                if strong:
                    cands = [n for n in cands if n % 12 in chord_pcs] or cands
                nxt = rng.choice(cands) if cands else prev
                bar_rows.append(midi_to_name(nxt))
                shape.append(nxt - root_note)
                prev = nxt
            motifs.setdefault(motif_key, shape)
        rows.extend(bar_rows)
    return rows


def drum_rows(bars, pattern="K.H.S.H.K.KHS.HO"):
    return list(pattern) * bars


def track(bpm, chords, key, scale, seed, lead_duty=0.25, drums="K.H.S.H.K.KHS.HO", bass_pattern="R.R.R.RRR.R.R5.R", arp_pattern="1.3.5.3.1.3.5.8.", lead_vib=0.012):
    s = Song(bpm=bpm)
    s.add("lead", melody_rows(chords, key, scale, seed), "pulse", duty=lead_duty, vol=0.22, vib=lead_vib, env=(0.004, 0.06, 0.6, 0.05))
    s.add("arp", arp_rows(chords, 4, arp_pattern), "pulse", duty=0.125, vol=0.09, env=(0.002, 0.04, 0.4, 0.02))
    s.add("bass", bass_rows(chords, 2, bass_pattern), "triangle", vol=0.42, env=(0.002, 0.05, 0.8, 0.03))
    s.add("drums", drum_rows(len(chords), drums), "noise", vol=0.3)
    return s.render(loops=1)


MUSIC = {
    # Heroic A minor with a lifted B section.
    "title": lambda: track(132, ["Am", "F", "C", "G", "Am", "F", "G", "E", "F", "G", "Em", "Am", "Dm", "F", "G", "G"], "A", "minor", 94),
    # Upbeat C major shuffle for the asteroid belt.
    "world1": lambda: track(150, ["C", "Am", "F", "G", "C", "Em", "F", "G", "Am", "F", "C", "G", "F", "G", "C", "C"], "C", "major", 11, lead_duty=0.5, drums="K.HHS.H.K.HKS.HH"),
    # Funky D dorian for the pizza station.
    "world2": lambda: track(118, ["Dm7", "G", "Dm7", "G", "Am", "Dm7", "C", "G", "Dm7", "G", "F", "C", "Am", "G", "Dm7", "Dm7"], "D", "dorian", 27, drums="K..HS.HKK.HHS.HO", bass_pattern="R..R..8.R.R..58."),
    # Dark E phrygian march on Glorbo Prime.
    "world3": lambda: track(108, ["Em", "F", "Em", "D", "Em", "F", "G", "F", "Am", "G", "F", "Em", "Am", "F", "D", "Em"], "E", "phrygian", 33, lead_duty=0.125, drums="K.H.S.HKK.H.S.SS"),
    # Fast, tense boss theme.
    "boss": lambda: track(168, ["Am", "Am", "G#dim", "Am", "F", "G", "E", "E", "Am", "C", "D", "F", "E", "E", "Am", "E"], "A", "minor", 57, lead_duty=0.5, drums="KHSHKHSHKHSHKSSS", bass_pattern="R8R8R8R8R8R8R858"),
    # Victory loop.
    "victory": lambda: track(140, ["C", "F", "G", "C", "Am", "F", "G", "C"], "C", "major", 3, lead_duty=0.5, drums="K.H.S.H.K.H.S.HO"),
}

# ================================================================= JINGLES ===


def _jingle(notes, step, duty=0.5, bass=None):
    lead = _arp(notes, step, duty, 0.35)
    if bass:
        b = np.concatenate([triangle(np.full(n_(step * k), note_freq(nm)), n_(step * k)) * adsr(n_(step * k), 0.002, 0.05, 0.8, 0.05) * 0.4 for nm, k in bass])
        return mix(lead, b)
    return lead


JINGLES = {
    "studio": lambda: _jingle(["C5", "E5", "G5", "C6", "B5", "C6"], 0.11, 0.25, [("C3", 4), ("G2", 2)]),
    "oneUp": lambda: _jingle(["C5", "E5", "G5", "E5", "G5", "C6"], 0.07),
    "continueQ": lambda: _jingle(["E5", "E5", "D5", "C5", "D5", "B4"], 0.13, 0.5, [("A2", 4), ("E2", 2)]),
    "gameOver": lambda: _jingle(["G4", "F#4", "F4", "E4", "D#4", "D4"], 0.16, 0.5, [("C3", 3), ("G2", 3)]),
    "rankS": lambda: _jingle(["C5", "G5", "C6", "E6", "G6", "C7"], 0.08, 0.125, [("C3", 3), ("C3", 3)]),
    "stageClear": lambda: _jingle(["G4", "C5", "E5", "G5", "E5", "G5", "C6"], 0.1, 0.5, [("C3", 4), ("G2", 3)]),
}

# ================================================================== OUTPUT ===


def write_wav(path, x):
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(to_int16(x).tobytes())


def write_ogg(path, x):
    with tempfile.TemporaryDirectory() as d:
        tmp = os.path.join(d, "a.wav")
        write_wav(tmp, x)
        subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", tmp, "-c:a", "libvorbis", "-q:a", "3",
                        "-map_metadata", "-1", "-fflags", "+bitexact", "-flags:a", "+bitexact", path], check=True)


def main():
    os.makedirs(OUT, exist_ok=True)
    for name, f in SFX.items():
        write_wav(os.path.join(OUT, f"sfx_{name}.wav"), normalize(f(), 0.8))
    for name, f in MUSIC.items():
        write_ogg(os.path.join(OUT, f"music_{name}.ogg"), normalize(f(), 0.75))
    for name, f in JINGLES.items():
        write_ogg(os.path.join(OUT, f"jingle_{name}.ogg"), normalize(f(), 0.8))
    print(f"{len(SFX)} sfx, {len(MUSIC)} tracks, {len(JINGLES)} jingles -> {OUT}")


if __name__ == "__main__":
    main()
