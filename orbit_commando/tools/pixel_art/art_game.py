"""Generated game art: the 8 non-pack enemies, hostage, items, vehicles,
bosses, FX, HUD and touch-control graphics.

Every maker returns (frames, anims, origin) where frames is a list of
Canvas objects of equal size. All art faces right.
"""
import math

import numpy as np

from paint import INK, MINI, Canvas, mini_text, ramp
from palette import color

C = color
MOSS, SPACE, EMBER, GOLD = ramp("moss"), ramp("space"), ramp("ember"), ramp("gold")
AQUA, CLAY, NEON, GREY = ramp("aqua"), ramp("clay"), ramp("neon"), ramp("ink")


def anim(frames, fps=8, loop=True):
    return {"frames": list(frames), "fps": fps, "loop": loop}


def sub(r, lo, hi):
    return r[lo:hi + 1]


# ================================================================ enemies ===

def clerk():
    """Glorbo bureaucrat: big green head, round specs, tie, giant stamp."""
    W, H = 36, 46
    frames = []

    def draw(leg, arm_up, angry, throw=False):
        cv = Canvas(W, H)
        # legs
        for lx, off in ((13, leg), (19, -leg)):
            cv.rect(lx, 34 + min(0, off), lx + 4, 45, sub(GREY, 1, 4), bevel=0)
            cv.rect(lx - 1 + max(0, off), 43, lx + 5 + max(0, off), 46, sub(GREY, 0, 2), bevel=0)
        # suit body
        cv.rect(10, 22, 26, 36, sub(GREY, 2, 5))
        cv.poly([(16, 22), (20, 22), (19, 33), (17, 33)], [C("ember", 4)])  # tie
        cv.px(17, 23, C("ember", 6))
        # clipboard arm (back)
        cv.rect(6, 25, 11, 34, sub(CLAY, 4, 7))
        # head
        cv.ellipse(18, 12, 11, 11, sub(MOSS, 2, 7))
        # specs + eyes
        for ex in (14, 22):
            cv.disc(ex, 12, 3, C("ink", 0))
            cv.disc(ex, 12, 2, C("aqua", 7))
            cv.px(ex + (1 if angry else 0), 12, C("ink", 0))
        cv.line(17, 12, 19, 12, C("ink", 0))
        if angry:
            cv.line(11, 7, 16, 9, C("ink", 0))
            cv.line(25, 7, 20, 9, C("ink", 0))
        cv.line(16, 18, 20, 18 if not angry else 19, C("ink", 1))
        # stamp arm
        if arm_up:
            cv.line(24, 26, 30, 14, C("ink", 3), 3)
            cv.rect(26, 6, 35, 12, sub(EMBER, 2, 5))
            cv.rect(29, 2, 32, 7, sub(CLAY, 3, 6))
        elif throw:
            cv.line(24, 26, 33, 22, C("ink", 3), 3)
            cv.rect(31, 18, 36, 26, sub(GREY, 5, 7), bevel=0)
        else:
            cv.line(24, 26, 28, 33, C("ink", 3), 3)
            cv.rect(25, 32, 33, 37, sub(EMBER, 2, 5))
            cv.rect(28, 28, 31, 33, sub(CLAY, 3, 6))
        cv.outline()
        return cv

    for leg in (0, 2, 0, -2):
        frames.append(draw(leg, False, False))
    frames.append(draw(0, True, True))
    frames.append(draw(0, False, True, throw=True))
    return frames, {"run": anim(range(4), 8), "attack": anim([5], 6), "tell": anim([4], 4),
                    "idle": anim([0], 1)}, (18, 45)


def drone():
    W, H = 34, 26
    frames = []
    for i in range(4):
        cv = Canvas(W, H)
        blade = [14, 6, 14, 6][i]
        cv.rect(17 - blade, 3, 17 + blade, 5, sub(GREY, 4, 7), bevel=0)
        cv.rect(16, 4, 18, 9, sub(GREY, 2, 4), bevel=0)
        cv.ellipse(17, 15, 12, 7, sub(AQUA, 1, 6))
        cv.rect(6, 15, 28, 18, sub(GREY, 1, 4), bevel=0)
        cv.disc(24, 14, 3, C("ember", 4 if i % 2 else 6))
        cv.rect(14, 21, 20, 25, sub(GOLD, 2, 5))  # bomb bay
        cv.outline()
        frames.append(cv)
    return frames, {"run": anim(range(4), 16), "idle": anim(range(4), 16),
                    "attack": anim([0, 2], 16), "tell": anim([1, 3], 20)}, (17, 13)


def turret():
    W, H = 34, 26
    frames = []
    for i in range(4):
        cv = Canvas(W, H)
        legs = [(0, 2), (2, 0), (0, 2), (2, 0)][i]
        for k, lx in enumerate((6, 11, 22, 27)):
            o = legs[k % 2]
            cv.line(lx, 17, lx - 3 + o, 25, C("ink", 2), 2)
        cv.rect(4, 13, 30, 19, sub(GREY, 2, 5))
        cv.ellipse(16, 12, 10, 8, sub(EMBER, 1, 5))
        hot = i == 3
        cv.rect(22, 8, 33, 12, sub(GREY, 3, 6), bevel=0)
        cv.rect(31, 7, 34, 13, [C("gold", 6)] if hot else sub(GREY, 4, 6), bevel=0)
        cv.disc(14, 10, 2, C("aqua", 6))
        cv.outline()
        frames.append(cv)
    return frames, {"run": anim([0, 1], 6), "idle": anim([0], 1), "attack": anim([3], 8),
                    "tell": anim([2, 3], 10)}, (16, 25)


def roller():
    W, H = 24, 24
    frames = []
    for i in range(5):
        cv = Canvas(W, H)
        cv.ellipse(12, 12, 11, 11, sub(GOLD, 1, 7))
        a = i * math.pi / 4
        for k in range(3):
            aa = a + k * math.pi * 2 / 3
            cv.line(12 + math.cos(aa) * 4, 12 + math.sin(aa) * 4, 12 + math.cos(aa) * 10,
                    12 + math.sin(aa) * 10, C("ember", 3), 2)
        surprised = i == 4
        cv.rect(12, 7, 22, 12, sub(GREY, 0, 2), bevel=0)
        for ex in (15, 19):
            cv.disc(ex, 9.5, 2.2 if surprised else 1.6, C("ink", 7))
            cv.px(ex, 9, C("ink", 0))
        cv.outline()
        frames.append(cv)
    return frames, {"run": anim(range(4), 14), "idle": anim([0], 1), "tell": anim([4], 4),
                    "attack": anim(range(4), 18)}, (12, 23)


def sniper():
    W, H = 46, 50
    frames = []
    for i in range(3):
        cv = Canvas(W, H)
        cv.poly([(12, 22), (24, 22), (27, 49), (9, 49)], sub(SPACE, 1, 5))  # coat
        cv.rect(13, 44, 17, 50, sub(GREY, 0, 2), bevel=0)
        cv.rect(20, 44, 24, 50, sub(GREY, 0, 2), bevel=0)
        cv.ellipse(18, 13, 8, 10, sub(NEON, 2, 6))
        cv.rect(10, 4, 27, 7, sub(GREY, 1, 3), bevel=0)  # hat brim
        cv.rect(13, 0, 24, 5, sub(GREY, 1, 4))
        cv.disc(21, 13, 2, C("gold", 6) if i == 2 else C("ink", 0))
        # rifle
        y = 25 if i < 2 else 23
        cv.rect(14, y, 45, y + 3, sub(GREY, 2, 5), bevel=0)
        cv.rect(30, y - 3, 36, y, sub(GREY, 1, 3), bevel=0)  # scope
        cv.px(44, y + 1, C("ember", 6) if i == 2 else C("ink", 4))
        cv.outline()
        frames.append(cv)
    return frames, {"idle": anim([0, 1], 2), "run": anim([0, 1], 2), "tell": anim([2], 4),
                    "attack": anim([2], 4)}, (18, 49)


def minimech():
    W, H = 50, 52
    frames = []

    def draw(step, crouch=0, air=False):
        cv = Canvas(W, H)
        by = 8 + crouch
        for side, ph in ((-1, step), (1, -step)):
            hx = 25 + side * 9
            kx = hx + ph * 3
            ky = by + 28 + (0 if air else 4)
            fx = hx + ph * 5
            fy = H - 3 if not air else H - 8
            cv.line(hx, by + 24, kx, ky, C("ink", 2), 5)
            cv.line(kx, ky, fx, fy, C("ink", 3), 4)
            cv.rect(fx - 6, fy, fx + 6, fy + 3, sub(GREY, 1, 4), bevel=0)
        cv.rect(9, by + 8, 41, by + 28, sub(GOLD, 1, 6))
        for k in range(4):
            cv.poly([(11 + k * 8, by + 26), (15 + k * 8, by + 26), (11 + k * 8, by + 22)],
                    [C("ink", 1)])
        cv.ellipse(25, by + 8, 11, 9, sub(AQUA, 2, 7))
        cv.ellipse(25, by + 10, 5, 5, sub(MOSS, 3, 6))  # pilot
        cv.disc(27, by + 9, 1.5, C("ink", 0))
        cv.rect(38, by + 14, 49, by + 18, sub(GREY, 2, 5), bevel=0)
        cv.outline()
        return cv

    for s in (-1, 0, 1, 0):
        frames.append(draw(s))
    frames.append(draw(0, crouch=5))
    frames.append(draw(0, air=True))
    return frames, {"run": anim(range(4), 8), "idle": anim([1], 1), "tell": anim([4], 4),
                    "attack": anim([5], 4), "jump": anim([5], 1)}, (25, 51)


def jelly():
    W, H = 36, 40
    frames = []
    for i in range(5):
        cv = Canvas(W, H)
        pulse = i == 4
        sq = [0, 1, 2, 1][i % 4]
        for k in range(5):
            x0 = 8 + k * 5
            for y in range(18, 38 - sq):
                x = x0 + math.sin(y * 0.4 + i + k) * 2
                cv.px(round(x), y, C("aqua", 5) if pulse else C("neon", 3 + (y % 2)))
        cv.ellipse(18, 13 + sq, 15, 11 - sq, sub(AQUA, 3, 7) if pulse else sub(NEON, 2, 7))
        cv.rect(4, 18 + sq, 33, 21 + sq, sub(NEON, 1, 3), bevel=0)
        for ex in (13, 23):
            cv.disc(ex, 12 + sq, 2, C("ink", 7))
            cv.px(ex, 12 + sq, C("ink", 0))
        cv.outline()
        frames.append(cv)
    return frames, {"run": anim(range(4), 6), "idle": anim(range(4), 6), "tell": anim([4, 0], 10),
                    "attack": anim([4], 8)}, (18, 20)


def swarm():
    W, H = 14, 12
    frames = []
    for i in range(2):
        cv = Canvas(W, H)
        cv.ellipse(7, 7, 5, 3, sub(GREY, 2, 6))
        cv.px(11, 6, C("ember", 6))
        wy = 2 if i == 0 else 4
        cv.line(4, 5, 2, wy, C("aqua", 6))
        cv.line(8, 5, 10, wy, C("aqua", 6))
        cv.line(4, 9, 3, 11, C("ink", 2))
        cv.line(8, 9, 9, 11, C("ink", 2))
        cv.outline()
        frames.append(cv)
    return frames, {"run": anim([0, 1], 20), "idle": anim([0, 1], 20), "attack": anim([0, 1], 24),
                    "tell": anim([0], 1)}, (7, 6)


# ================================================================ hostage ===

def hostage():
    W, H = 30, 38
    frames = []

    def body(cv, leg=0, arm=None, tied=False, wiggle=0):
        ox = wiggle
        for lx, o in ((11, leg), (17, -leg)):
            cv.rect(lx + ox + max(0, o), 28, lx + 4 + ox + max(0, o), 38, sub(GREY, 4, 7), bevel=0)
        cv.rect(9 + ox, 16, 22 + ox, 30, sub(GREY, 4, 7))
        cv.ellipse(15.5 + ox, 9, 8, 8, sub(GREY, 4, 7))
        cv.ellipse(17.5 + ox, 9, 5, 4, sub(EMBER, 3, 6))
        cv.px(19 + ox, 7, C("ink", 7))
        if tied:
            for y in (18, 23, 27):
                cv.line(8 + ox, y, 23 + ox, y + 1, C("clay", 5), 2)
        elif arm == "wave":
            cv.line(21 + ox, 18, 27 + ox, 8 + leg, C("ink", 6), 3)
        else:
            cv.line(21 + ox, 18, 24 + ox, 26 + leg, C("ink", 5), 3)
        cv.outline()

    for w in (0, 1):
        cv = Canvas(W, H)
        body(cv, tied=True, wiggle=w)
        frames.append(cv)
    for a in (0, -3):
        cv = Canvas(W, H)
        body(cv, leg=a, arm="wave")
        frames.append(cv)
    for leg in (-3, 0, 3, 0):
        cv = Canvas(W, H)
        body(cv, leg=leg)
        frames.append(cv)
    return frames, {"tied": anim([0, 1], 3), "wave": anim([2, 3], 6),
                    "run": anim([4, 5, 6, 7], 12), "idle": anim([0], 1)}, (15, 37)


# ================================================================== items ===

def items():
    """One atlas: weapon crates, grenade, 1UP, medkit, shield, cassette,
    checkpoint beacon (off/on), exit sign (2 frames)."""
    W, H = 24, 24
    frames, anims = [], {}

    def crate(letter, ramp_name):
        cv = Canvas(W, H)
        cv.rect(3, 4, 21, 21, sub(ramp(ramp_name), 2, 6), bevel=2)
        cv.rect(6, 6, 18, 19, [C("ink", 0)], bevel=0)
        g = MINI[letter]
        for gy, row in enumerate(g):
            for gx, v in enumerate(row):
                if v == "X":
                    cv.rect(9 + gx * 2, 7 + gy * 2, 11 + gx * 2, 9 + gy * 2,
                            [C("ink", 7)], bevel=0)
        cv.outline()
        return cv

    for i, (letter, rn) in enumerate([("S", "ember"), ("L", "aqua"), ("P", "neon"),
                                      ("H", "moss"), ("F", "gold"), ("R", "space")]):
        anims[letter] = anim([len(frames)], 1)
        frames.append(crate(letter, rn))
    cv = Canvas(W, H)
    cv.ellipse(12, 14, 6, 7, sub(MOSS, 1, 6))
    cv.rect(10, 4, 14, 8, sub(GREY, 3, 6), bevel=0)
    cv.line(14, 5, 18, 3, C("gold", 6), 1)
    cv.outline()
    anims["grenade"] = anim([len(frames)], 1)
    frames.append(cv)
    cv = Canvas(W, H)
    cv.ellipse(12, 12, 10, 10, sub(GOLD, 2, 7))
    cv.ellipse(12, 12, 7, 7, sub(EMBER, 2, 5))
    mini_text(cv, "1U", 7, 10, C("gold", 7))
    cv.outline()
    anims["life"] = anim([len(frames)], 1)
    frames.append(cv)
    cv = Canvas(W, H)
    cv.rect(4, 6, 20, 20, sub(GREY, 5, 7), bevel=2)
    cv.rect(10, 8, 14, 18, [C("ember", 4)], bevel=0)
    cv.rect(7, 11, 17, 15, [C("ember", 4)], bevel=0)
    cv.outline()
    anims["medkit"] = anim([len(frames)], 1)
    frames.append(cv)
    cv = Canvas(W, H)
    cv.ellipse(12, 12, 9, 9, sub(AQUA, 2, 7))
    cv.ellipse(10, 9, 3, 2, [C("aqua", 7)], flat=True)
    cv.outline()
    anims["shield"] = anim([len(frames)], 1)
    frames.append(cv)
    # cassette
    cv = Canvas(W, H)
    cv.rect(2, 6, 22, 19, sub(GREY, 1, 3), bevel=1)
    cv.rect(4, 7, 20, 11, sub(NEON, 4, 6), bevel=0)
    for rx in (8, 16):
        cv.disc(rx, 14, 2.5, C("ink", 6))
        cv.disc(rx, 14, 1, C("ink", 0))
    cv.rect(6, 17, 18, 19, sub(GREY, 3, 4), bevel=0)
    cv.outline()
    anims["cassette"] = anim([len(frames)], 1)
    frames.append(cv)
    return frames, anims, (12, 23)


def beacon():
    W, H = 18, 48
    frames = []
    for on in (False, True, True):
        cv = Canvas(W, H)
        cv.rect(7, 10, 11, 46, sub(GREY, 2, 5), bevel=0)
        cv.rect(3, 44, 15, 48, sub(GREY, 1, 4))
        lit = sub(AQUA, 3, 7) if on else sub(GREY, 1, 3)
        cv.ellipse(9, 7, 6, 6, lit)
        if on and len(frames) == 2:
            cv.ellipse(9, 7, 3, 3, [C("aqua", 7)], flat=True)
        # flag
        cv.poly([(11, 14), (17, 17), (11, 20)], [C("ember", 5) if on else C("ink", 3)])
        cv.outline()
        frames.append(cv)
    return frames, {"off": anim([0], 1), "on": anim([1, 2], 3)}, (9, 47)


def exit_sign():
    W, H = 56, 64
    frames = []
    for blink in (0, 1):
        cv = Canvas(W, H)
        cv.rect(25, 30, 31, 64, sub(GREY, 2, 5), bevel=0)
        cv.rect(4, 4, 52, 30, sub(MOSS, 1, 4), bevel=2)
        cv.rect(7, 7, 49, 27, [C("moss", 1)], bevel=0)
        col = C("moss", 7) if blink == 0 else C("gold", 7)
        for i, ch in enumerate("EXIT"):
            g = MINI[ch]
            for gy, row in enumerate(g):
                for gx, v in enumerate(row):
                    if v == "X":
                        cv.rect(10 + i * 10 + gx * 2, 10 + gy * 3, 12 + i * 10 + gx * 2,
                                13 + gy * 3, [col], bevel=0)
        cv.poly([(44, 34), (54, 40), (44, 46)], [col])
        cv.outline()
        frames.append(cv)
    return frames, {"idle": anim([0, 1], 3)}, (28, 63)


# =============================================================== vehicles ===

def mech():
    W, H = 80, 100
    frames = []

    def draw(step, squash=0, air=False):
        cv = Canvas(W, H)
        top = 14 + squash
        for side, ph in ((-1, step), (1, -step)):
            hx = 40 + side * 16
            fy = H - 4 - (6 if air else 0)
            # spring leg
            for k in range(6):
                y = top + 46 + k * (fy - top - 46) / 6
                cv.line(hx - 6 + ph * k * 0.6, y, hx + 6 + ph * k * 0.6, y + 3,
                        C("gold", 5 if k % 2 else 3), 2)
            cv.rect(hx - 11 + ph * 4, fy, hx + 11 + ph * 4, fy + 4, sub(GREY, 1, 4), bevel=0)
        cv.rect(12, top + 22, 68, top + 50, sub(GOLD, 1, 6), bevel=2)
        for k in range(7):
            x = 14 + k * 8
            cv.poly([(x, top + 48), (x + 4, top + 48), (x, top + 44)], [C("ink", 1)])
        cv.ellipse(40, top + 16, 20, 16, sub(AQUA, 2, 7))  # canopy
        cv.ellipse(34, top + 10, 5, 3, [C("aqua", 7)], flat=True)
        cv.rect(62, top + 28, 79, top + 36, sub(GREY, 2, 5), bevel=1)  # cannon
        cv.rect(4, top + 26, 14, top + 44, sub(SPACE, 2, 5), bevel=1)  # backpack
        cv.outline()
        return cv

    for s in (-1, 0, 1, 0):
        frames.append(draw(s))
    frames.append(draw(0, squash=8))
    frames.append(draw(0, air=True))
    return frames, {"run": anim(range(4), 7), "idle": anim([1], 1), "squash": anim([4], 1),
                    "jump": anim([5], 1)}, (40, 99)


def bike():
    W, H = 80, 44
    frames = []
    for f in range(2):
        cv = Canvas(W, H)
        for wx in (16, 62):
            cv.ellipse(wx, 34, 9, 9, sub(GREY, 0, 3))
            cv.disc(wx, 34, 3, C("ink", 5))
        cv.poly([(10, 24), (60, 18), (74, 26), (70, 32), (14, 32)], sub(EMBER, 2, 6))
        cv.rect(30, 14, 46, 20, sub(GREY, 1, 3))  # seat
        cv.poly([(64, 18), (72, 8), (75, 9), (69, 20)], sub(GREY, 3, 6))
        cv.rect(0, 22, 12, 30, sub(GREY, 2, 5), bevel=1)  # rocket
        flame = [(0, 23), (-1, 26), (0, 29)]
        for i, (x, y) in enumerate(flame):
            cv.rect(0, y, 3 + f * 2, y + 2, [C("gold", 6 - i % 2)], bevel=0)
        cv.outline()
        frames.append(cv)
    return frames, {"run": anim([0, 1], 16), "idle": anim([0], 1)}, (40, 43)


def shuttle():
    W, H = 84, 44
    frames = []
    for f in range(2):
        cv = Canvas(W, H)
        cv.poly([(8, 14), (60, 10), (82, 22), (60, 34), (8, 30)], sub(GREY, 3, 7))
        cv.poly([(30, 4), (48, 10), (40, 12)], sub(EMBER, 3, 6))
        cv.poly([(30, 40), (48, 34), (40, 32)], sub(EMBER, 3, 6))
        cv.ellipse(56, 19, 12, 6, sub(AQUA, 2, 7))
        cv.rect(4, 15, 10, 29, sub(GREY, 1, 3), bevel=0)
        for y in (18, 25):
            cv.rect(0, y, 4 + f * 2, y + 2, [C("gold", 6)], bevel=0)
        cv.outline()
        frames.append(cv)
    return frames, {"idle": anim([0, 1], 14), "run": anim([0, 1], 14)}, (42, 22)


# ================================================================== bosses ===

def stamper_body():
    W, H = 150, 120
    frames = []
    for blink in (0, 1):
        cv = Canvas(W, H)
        cv.rect(10, 10, 140, 104, sub(CLAY, 2, 6), bevel=3)
        cv.rect(20, 4, 130, 14, sub(CLAY, 1, 4), bevel=2)  # roof
        for row in range(3):
            for col in range(4):
                x, y = 22 + col * 28, 20 + row * 26
                cv.rect(x, y, x + 20, y + 18, sub(AQUA, 1, 4), bevel=1)
                for k in range(3):
                    cv.line(x + 1, y + 4 + k * 5, x + 19, y + 4 + k * 5, C("ink", 3))
        # angry eyes in the middle windows
        for ex in (61, 89):
            cv.rect(ex - 9, 46, ex + 9, 62, [C("ink", 7)], bevel=0)
            if blink:
                cv.rect(ex - 9, 53, ex + 9, 56, [C("ink", 1)], bevel=0)
            else:
                cv.disc(ex, 55, 4, C("ember", 4))
                cv.disc(ex, 55, 2, C("ink", 0))
            cv.line(ex - 10, 42 + (0 if ex < 75 else 6), ex + 10, 42 + (6 if ex < 75 else 0),
                    C("ink", 0), 3)
        # thrusters
        for tx in (26, 124):
            cv.rect(tx - 10, 100, tx + 10, 112, sub(GREY, 1, 4), bevel=1)
            cv.rect(tx - 6, 112, tx + 6, 118, [C("gold", 6 - blink)], bevel=0)
        cv.outline()
        frames.append(cv)
    return frames, {"idle": anim([0, 0, 0, 1], 3)}, (75, 60)


def stamper_parts():
    """drawer closed/open, stamp normal/exposed."""
    W, H = 48, 48
    frames = []
    for open_ in (False, True):
        cv = Canvas(W, H)
        d = 14 if open_ else 0
        cv.rect(8 - d, 12, 40 - d, 36, sub(CLAY, 2, 5), bevel=2)
        cv.rect(18 - d, 21, 30 - d, 25, sub(GOLD, 4, 6), bevel=0)
        if open_:
            for k in range(3):
                cv.rect(28 - d + k * 3, 6 + k * 2, 38 - d + k * 3, 14 + k * 2,
                        sub(GREY, 5, 7), bevel=0)
        cv.outline()
        frames.append(cv)
    for hot in (False, True):
        cv = Canvas(W, H)
        cv.rect(19, 0, 29, 18, sub(CLAY, 3, 6), bevel=1)
        cv.rect(6, 18, 42, 30, sub(GREY, 1, 4), bevel=2)
        face = sub(EMBER, 4, 7) if hot else sub(EMBER, 2, 4)
        cv.rect(4, 30, 44, 42, face, bevel=1)
        mini_text(cv, "OK", 18, 33, C("gold", 7) if hot else C("ember", 6))
        cv.outline()
        frames.append(cv)
    return frames, {"drawer": anim([0], 1), "drawer_open": anim([1], 1),
                    "stamp": anim([2], 1), "stamp_hot": anim([2, 3], 8)}, (24, 24)


def washer_body():
    W, H = 160, 180
    frames = []
    for shake in (0, 1):
        cv = Canvas(W, H)
        o = shake
        cv.rect(8 + o, 20, 152 + o, 170, sub(GREY, 4, 7), bevel=3)
        cv.rect(8 + o, 20, 152 + o, 50, sub(AQUA, 3, 6), bevel=2)  # top panel
        for k, kx in enumerate((30, 50, 120)):
            cv.ellipse(kx + o, 35, 6, 6, sub(GREY, 1, 4))
            cv.line(kx + o, 35, kx + o + 4 * math.cos(k + shake), 35 - 4 * math.sin(k + 1),
                    C("ink", 0))
        cv.rect(66 + o, 30, 104 + o, 42, [C("ink", 1)], bevel=0)
        for fx in (24, 136):
            cv.rect(fx - 10 + o, 168, fx + 10 + o, 180, sub(GREY, 1, 3), bevel=1)
        cv.ellipse(80 + o, 110, 52, 52, sub(GREY, 2, 5))  # door frame
        cv.outline()
        frames.append(cv)
    return frames, {"idle": anim([0], 1), "shake": anim([0, 1], 20)}, (80, 100)


def washer_drum():
    W, H = 90, 90
    frames = []
    for i in range(6):
        cv = Canvas(W, H)
        cv.ellipse(45, 45, 42, 42, sub(AQUA, 1, 4) if i < 4 else sub(NEON, 2, 5), flat=False)
        a0 = i * math.pi / 6
        for k in range(5):
            a = a0 + k * math.pi * 2 / 5
            cv.disc(45 + math.cos(a) * 24, 45 + math.sin(a) * 24, 7, C("ink", 7))
            cv.disc(45 + math.cos(a + 0.4) * 12, 45 + math.sin(a + 0.4) * 12, 4, C("aqua", 6))
        if i >= 4:  # open door: dark drum mouth
            cv.ellipse(45, 45, 30, 30, [C("ink", 0), C("space", 1)], flat=True)
        cv.ellipse(30, 26, 10, 5, [C("aqua", 7)], flat=True)
        frames.append(cv)
    return frames, {"spin": anim(range(4), 12), "open": anim([4, 5], 6)}, (45, 45)


def washer_panel():
    W, H = 44, 22
    frames = []
    for on in (0, 1):
        cv = Canvas(W, H)
        cv.rect(0, 0, 44, 22, sub(GREY, 1, 3), bevel=1)
        for k in range(4):
            cv.disc(8 + k * 9, 11, 3, C("ember", 6) if (k + on) % 2 else C("moss", 6))
        cv.outline()
        frames.append(cv)
    return frames, {"blink": anim([0, 1], 4)}, (22, 11)


def emperor_throne():
    W, H = 200, 220
    frames = []
    for step in (0, 1):
        cv = Canvas(W, H)
        for lx in (50, 150):
            o = 4 if (lx < 100) == bool(step) else 0
            cv.rect(lx - 12, 170 - o, lx + 12, 214 - o, sub(GREY, 1, 4), bevel=2)
            cv.rect(lx - 20, 206 - o, lx + 20, 220 - o, sub(GREY, 0, 3), bevel=1)
        cv.rect(20, 40, 180, 180, sub(NEON, 1, 5), bevel=3)
        cv.rect(30, 20, 170, 44, sub(GOLD, 2, 6), bevel=2)  # crown-ish top
        for k in range(5):
            cv.poly([(34 + k * 30, 20), (46 + k * 30, 20), (40 + k * 30, 6)], sub(GOLD, 3, 7))
        cv.rect(120, 60, 176, 172, sub(NEON, 0, 3), bevel=2)  # side panel
        cv.outline()
        frames.append(cv)
    return frames, {"idle": anim([0], 1), "walk": anim([0, 1], 4)}, (100, 120)


def emperor_parts():
    """drawer closed/open/broken, core eye open/shut, saucer x2."""
    W, H = 72, 48
    frames = []
    for state in ("closed", "open", "broken"):
        cv = Canvas(W, H)
        if state == "broken":
            cv.rect(16, 10, 60, 38, [C("ink", 1), C("ink", 2)], bevel=0)
            cv.line(18, 12, 58, 36, C("ember", 3), 2)
        else:
            d = 16 if state == "open" else 0
            cv.rect(16 - d, 10, 60 - d, 38, sub(GOLD, 2, 6), bevel=2)
            cv.rect(30 - d, 21, 46 - d, 27, sub(GREY, 4, 6), bevel=0)
            if state == "open":
                cv.ellipse(52 - d + 12, 24, 8, 10, sub(EMBER, 2, 6))
        cv.outline()
        frames.append(cv)
    for shut in (False, True):
        cv = Canvas(W, H)
        cv.ellipse(36, 24, 26, 20, sub(GREY, 4, 7))
        if shut:
            cv.rect(10, 22, 62, 27, [C("neon", 2)], bevel=0)
        else:
            cv.ellipse(38, 24, 14, 14, sub(EMBER, 2, 6))
            cv.disc(40, 22, 5, C("ink", 0))
            cv.disc(37, 19, 2, C("ink", 7))
        cv.outline()
        frames.append(cv)
    for f in range(2):
        cv = Canvas(W, H)
        cv.ellipse(36, 30, 34, 10, sub(GREY, 3, 7))
        cv.ellipse(36, 20, 16, 14, sub(AQUA, 3, 7))
        cv.ellipse(36, 22, 8, 9, sub(MOSS, 2, 6))  # the emperor
        cv.disc(39, 20, 2.5, C("gold", 7))  # monocle
        cv.disc(39, 20, 1, C("ink", 0))
        for k in range(3):
            cv.poly([(29 + k * 5, 13), (33 + k * 5, 13), (31 + k * 5, 8)], [C("gold", 6)])
        for k in range(5):
            cv.disc(12 + k * 12, 32, 2, C("gold", 7) if (k + f) % 2 else C("ember", 5))
        cv.outline()
        frames.append(cv)
    return frames, {"drawer": anim([0], 1), "drawer_open": anim([1], 1),
                    "drawer_broken": anim([2], 1), "core": anim([3, 3, 3, 4], 4),
                    "saucer": anim([5, 6], 8)}, (36, 24)


# ===================================================================== FX ===

def explosion():
    S = 64
    frames = []
    rng = np.random.default_rng(64)
    blobs = [(rng.uniform(-10, 10), rng.uniform(-10, 10), rng.uniform(8, 16)) for _ in range(7)]
    for f in range(8):
        cv = Canvas(S, S)
        t = f / 7
        grow = 0.4 + t * 1.1
        for bx, by, br in blobs:
            r = br * grow
            cx, cy = 32 + bx * grow, 32 + by * grow - t * 8
            if t < 0.45:
                shades = [C("ember", 4), C("ember", 5), C("gold", 5), C("gold", 6), C("gold", 7)]
            elif t < 0.75:
                shades = [C("ember", 2), C("ember", 3), C("ember", 4), C("gold", 5)]
            else:
                shades = [C("ink", 1), C("ink", 2), C("ink", 3), C("ink", 4)]
            cv.ellipse(cx, cy, r, r, shades)
        if t > 0.8:  # dissolve
            mask = rng.random((S, S)) < (t - 0.8) * 3
            cv.a[mask] = 0
        frames.append(cv)
    return frames, {"boom": anim(range(8), 18, loop=False)}, (32, 32)


def small_fx():
    """hit spark (4), muzzle flash (3), smoke puff (4), debris (3), shell (2)."""
    S = 24
    frames, anims = [], {}
    start = len(frames)
    for f in range(4):
        cv = Canvas(S, S)
        r = 2 + f * 2
        for k in range(6):
            a = k * math.pi / 3 + f * 0.3
            cv.line(12, 12, 12 + math.cos(a) * r, 12 + math.sin(a) * r,
                    C("gold", 7 - f), 1)
        if f < 2:
            cv.disc(12, 12, 3 - f, C("ink", 7))
        frames.append(cv)
    anims["spark"] = anim(range(start, start + 4), 24, False)
    start = len(frames)
    for f in range(3):
        cv = Canvas(S, S)
        cv.ellipse(12, 12, 8 - f * 2, 5 - f, [C("gold", 5), C("gold", 6), C("gold", 7)], flat=True)
        cv.ellipse(15, 12, 5 - f, 3, [C("ink", 7)], flat=True)
        frames.append(cv)
    anims["muzzle"] = anim(range(start, start + 3), 30, False)
    start = len(frames)
    for f in range(4):
        cv = Canvas(S, S)
        r = 4 + f * 2
        cv.ellipse(12, 12, r, r, sub(GREY, 2 + (f > 1), 5))
        if f == 3:
            cv.a[::2, ::2] = 0
        frames.append(cv)
    anims["smoke"] = anim(range(start, start + 4), 10, False)
    start = len(frames)
    for f in range(3):
        cv = Canvas(S, S)
        pts = [(9, 9), (15, 10), (14, 15), (9, 14)]
        a = f * 1.2
        pts = [(12 + (x - 12) * math.cos(a) - (y - 12) * math.sin(a),
                12 + (x - 12) * math.sin(a) + (y - 12) * math.cos(a)) for x, y in pts]
        cv.poly(pts, sub(GREY, 2, 5))
        cv.outline()
        frames.append(cv)
    anims["debris"] = anim(range(start, start + 3), 12)
    start = len(frames)
    for f in range(2):
        cv = Canvas(S, S)
        if f == 0:
            cv.rect(11, 10, 13, 14, [C("gold", 6)], bevel=0)
        else:
            cv.rect(10, 11, 14, 13, [C("gold", 5)], bevel=0)
        frames.append(cv)
    anims["shell"] = anim(range(start, start + 2), 12)
    return frames, anims, (12, 12)


# ================================================================= HUD / UI ===

def seg_digits():
    """7-segment digits 0-9 plus blank, for the arcade score."""
    W, H = 11, 17
    segs = {  # a b c d e f g
        "0": "abcdef", "1": "bc", "2": "abged", "3": "abgcd", "4": "fgbc",
        "5": "afgcd", "6": "afgedc", "7": "abc", "8": "abcdefg", "9": "abcdfg", " ": "",
    }
    frames, anims = [], {}
    on, off = C("gold", 6), C("ember", 1)
    for ch, s in segs.items():
        cv = Canvas(W, H)
        for seg in "abcdefg":
            c = on if seg in s else off
            if seg == "a":
                cv.rect(2, 0, 9, 2, [c], bevel=0)
            if seg == "g":
                cv.rect(2, 7, 9, 9, [c], bevel=0)
            if seg == "d":
                cv.rect(2, 14, 9, 16, [c], bevel=0)
            if seg == "f":
                cv.rect(0, 2, 2, 7, [c], bevel=0)
            if seg == "b":
                cv.rect(9, 2, 11, 7, [c], bevel=0)
            if seg == "e":
                cv.rect(0, 9, 2, 14, [c], bevel=0)
            if seg == "c":
                cv.rect(9, 9, 11, 14, [c], bevel=0)
        anims["d" + (ch if ch != " " else "_")] = anim([len(frames)], 1)
        frames.append(cv)
    return frames, anims, (0, 0)


def icons():
    """Button / hint icons, 24x24: jump fire grenade dash pause aim_up move
    jetpack gravity bike shuttle heart ammo."""
    S = 24
    frames, anims = [], {}

    def icon(name, draw):
        cv = Canvas(S, S)
        draw(cv)
        anims[name] = anim([len(frames)], 1)
        frames.append(cv)

    w = C("ink", 7)

    def arrow(cv, x, y, dx, dy, c=w):
        cv.line(x, y, x + dx * 8, y + dy * 8, c, 3)
        px, py = -dy, dx
        tip = (x + dx * 10, y + dy * 10)
        cv.poly([(tip[0] + dx * 2, tip[1] + dy * 2), (tip[0] + px * 5, tip[1] + py * 5),
                 (tip[0] - px * 5, tip[1] - py * 5)], [c])

    icon("jump", lambda cv: arrow(cv, 12, 19, 0, -1))
    icon("aim_up", lambda cv: (arrow(cv, 12, 20, 0, -1, C("gold", 6)),
                               cv.disc(12, 5, 2, w)))

    def fire(cv):
        cv.rect(4, 9, 16, 15, sub(GREY, 4, 7), bevel=0)
        cv.rect(16, 10, 21, 14, [C("gold", 6)], bevel=0)
        cv.rect(6, 15, 9, 20, sub(GREY, 3, 5), bevel=0)
    icon("fire", fire)

    def gren(cv):
        cv.ellipse(12, 14, 6, 7, sub(MOSS, 3, 7))
        cv.rect(10, 4, 14, 8, [w], bevel=0)
    icon("grenade", gren)

    def dash(cv):
        for k in range(3):
            cv.line(3 + k * 2, 8 + k * 4, 12 + k * 2, 8 + k * 4, C("aqua", 6 - k), 2)
        arrow(cv, 12, 12, 1, 0)
    icon("dash", dash)

    def pause(cv):
        cv.rect(6, 5, 10, 19, [w], bevel=0)
        cv.rect(14, 5, 18, 19, [w], bevel=0)
    icon("pause", pause)

    def move(cv):
        arrow(cv, 10, 12, -1, 0)
        arrow(cv, 14, 12, 1, 0)
    icon("move", move)

    def jet(cv):
        cv.rect(8, 4, 16, 16, sub(GREY, 3, 6), bevel=1)
        cv.rect(9, 16, 15, 22, [C("gold", 6)], bevel=0)
    icon("jetpack", jet)

    def grav(cv):
        arrow(cv, 8, 18, 0, -1, C("aqua", 6))
        arrow(cv, 16, 6, 0, 1, C("neon", 6))
    icon("gravity", grav)

    def bk(cv):
        cv.ellipse(6, 16, 4, 4, sub(GREY, 3, 6))
        cv.ellipse(18, 16, 4, 4, sub(GREY, 3, 6))
        cv.poly([(4, 12), (18, 9), (21, 13), (6, 14)], [C("ember", 5)])
    icon("bike", bk)

    def sh(cv):
        cv.poly([(2, 9), (16, 7), (22, 12), (16, 17), (2, 15)], sub(GREY, 4, 7))
        cv.ellipse(15, 12, 4, 2, [C("aqua", 6)], flat=True)
    icon("shuttle", sh)

    def heart(cv):
        cv.disc(8, 9, 4, C("ember", 5))
        cv.disc(16, 9, 4, C("ember", 5))
        cv.poly([(4, 10), (20, 10), (12, 20)], [C("ember", 5)])
        cv.disc(7, 8, 1, C("ember", 7))
    icon("heart", heart)

    def ammo(cv):
        for k in range(3):
            cv.rect(5 + k * 5, 8, 8 + k * 5, 19, [C("gold", 5)], bevel=0)
            cv.rect(5 + k * 5, 5, 8 + k * 5, 8, [C("ember", 5)], bevel=0)
    icon("ammo", ammo)

    def coin(cv):
        cv.ellipse(12, 12, 9, 9, sub(GOLD, 3, 7))
        cv.rect(11, 7, 13, 17, [C("gold", 2)], bevel=0)
    icon("credit", coin)

    for cv in frames:
        cv.outline()
    return frames, anims, (12, 12)


def touch_pad():
    """Joystick base (0) and knob (1), 72x72; button disc (2,3 pressed)."""
    S = 72
    frames = []
    cv = Canvas(S, S)
    yy, xx = np.mgrid[0:S, 0:S]
    d = np.sqrt((xx + 0.5 - 36) ** 2 + (yy + 0.5 - 36) ** 2)
    ring = (d <= 34) & (d >= 30)
    cv.a[ring] = C("ink", 6)
    inner = (d < 30) & ((xx + yy) % 2 == 0)
    cv.a[inner] = C("space", 2)
    for a in range(4):
        ang = a * math.pi / 2
        x, y = 36 + math.cos(ang) * 24, 36 + math.sin(ang) * 24
        cv.disc(x, y, 2, C("ink", 6))
    frames.append(cv)
    cv = Canvas(S, S)
    cv.ellipse(36, 36, 16, 16, sub(GREY, 3, 7))
    frames.append(cv)
    for pressed in (False, True):
        cv = Canvas(S, S)
        cv.ellipse(36, 36, 30, 30, sub(GREY, 1, 4) if pressed else sub(GREY, 2, 6))
        cv.ellipse(36, 36, 25, 25, [C("space", 2), C("space", 3)] if pressed
                   else [C("space", 3), C("space", 4)], flat=True)
        frames.append(cv)
    for cv in frames:
        cv.outline()
    return frames, {"base": anim([0], 1), "knob": anim([1], 1), "button": anim([2], 1),
                    "button_down": anim([3], 1)}, (36, 36)


GAME_ART = {
    "clerk": clerk, "drone": drone, "turret": turret, "roller": roller,
    "sniper": sniper, "minimech": minimech, "jelly": jelly, "swarm": swarm,
    "hostage": hostage, "items": items, "beacon": beacon, "exit_sign": exit_sign,
    "mech": mech, "bike": bike, "shuttle": shuttle,
    "stamper_body": stamper_body, "stamper_parts": stamper_parts,
    "washer_body": washer_body, "washer_drum": washer_drum, "washer_panel": washer_panel,
    "emperor_throne": emperor_throne, "emperor_parts": emperor_parts,
    "explosion": explosion, "fx": small_fx, "seg_digits": seg_digits, "icons": icons,
    "touch": touch_pad,
}
