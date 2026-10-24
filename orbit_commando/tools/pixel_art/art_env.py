"""Environment art: terrain textures, per-world backdrops and planetoids
in four styles (rock, ice, glorbo, metal).
"""
import math

import numpy as np

from paint import Canvas
from palette import color
from sprites import _dither, _fbm, _outline, _ramp, _sphere

C = color


def _arr_canvas(arr):
    cv = Canvas(arr.shape[1], arr.shape[0])
    cv.a = arr
    return cv


# ---------------------------------------------------------------- textures --

def texture(theme):
    """64x64 seamless fill texture for solid terrain."""
    S = 64
    rgba = np.zeros((S, S, 4), dtype=np.uint8)
    if theme == "asteroids":
        n = _fbm(S, S, 32, 11, octaves=4, wrap_x=True)
        # make it tile vertically too by mirroring the noise
        n = (n + n[::-1]) / 2
        r = _ramp("clay", (1, 2, 2, 3, 4))
        rgba[:] = r[_dither(n * 1.2 - 0.1, 5)]
        rng = np.random.default_rng(3)
        for _ in range(14):
            x, y = rng.integers(0, S, 2)
            rr = rng.integers(2, 5)
            yy, xx = np.mgrid[0:S, 0:S]
            m = ((xx - x) % S) ** 2 + ((yy - y) % S) ** 2 < rr * rr
            rgba[m] = C("clay", 1)
            rgba[np.roll(np.roll(m, -1, 0), -1, 1) & ~m] = C("clay", 5)
    elif theme == "station":
        base = _ramp("ink", (1, 2, 3))
        rgba[:] = base[1]
        for y0 in (0, 32):
            for x0 in (0, 32):
                rgba[y0:y0 + 31, x0:x0 + 31] = base[1]
                rgba[y0, x0:x0 + 31] = C("ink", 4)
                rgba[y0:y0 + 31, x0] = C("ink", 4)
                rgba[y0 + 30, x0:x0 + 31] = C("ink", 0)
                rgba[y0:y0 + 31, x0 + 30] = C("ink", 0)
                for rx, ry in ((3, 3), (27, 3), (3, 27), (27, 27)):
                    rgba[y0 + ry, x0 + rx] = C("ink", 5)
        # hazard stripes band at the top half of the tile
        for y in range(12, 20):
            for x in range(S):
                rgba[y, x] = C("gold", 5) if ((x + y) // 4) % 2 == 0 else C("ink", 0)
    else:  # glorbo: organic
        n = _fbm(S, S, 32, 21, octaves=3, wrap_x=True)
        n = (n + n[::-1]) / 2
        r = _ramp("neon", (0, 1, 1, 2, 3))
        rgba[:] = r[_dither(n * 1.3 - 0.15, 5)]
        yy, xx = np.mgrid[0:S, 0:S]
        for cx, cy, cr in ((14, 18, 6), (44, 40, 8), (52, 10, 4), (24, 52, 5)):
            d = np.sqrt(((xx - cx + 32) % S - 32) ** 2 + ((yy - cy + 32) % S - 32) ** 2)
            rgba[d < cr] = C("moss", 3)
            rgba[(d < cr) & (d > cr - 1.5)] = C("moss", 5)
    return rgba


def textures():
    frames = [_arr_canvas(texture(t)) for t in ("asteroids", "station", "glorbo")]
    return frames, {
        "asteroids": {"frames": [0], "fps": 1, "loop": True},
        "station": {"frames": [1], "fps": 1, "loop": True},
        "glorbo": {"frames": [2], "fps": 1, "loop": True},
    }, (0, 0)


# -------------------------------------------------------------- backdrops --

def bg_station():
    w, h = 640, 360
    rgba = np.zeros((h, w, 4), dtype=np.uint8)
    rgba[:] = C("ink", 1)
    # big wall panels
    for x0 in range(0, w, 160):
        rgba[:, x0:x0 + 2] = C("ink", 0)
        rgba[:, x0 + 2:x0 + 3] = C("ink", 2)
    for y0 in (60, 300):
        rgba[y0:y0 + 3, :] = C("ink", 0)
    # round windows to space with stars
    rng = np.random.default_rng(7)
    yy, xx = np.mgrid[0:h, 0:w]
    for i, cx in enumerate(range(80, w, 160)):
        cy = 170 + (i % 2) * 20
        d = np.sqrt((xx - cx) ** 2 + (yy - cy) ** 2)
        rgba[(d < 44) & (d >= 40)] = C("ink", 3)
        win = d < 40
        rgba[win] = C("space", 0)
        stars = win & (rng.random((h, w)) < 0.01)
        rgba[stars] = C("ink", 6)
        glare = win & (np.abs((xx - cx) + (yy - cy) + 20) < 2)
        rgba[glare] = C("space", 2)
    # pipes
    for y, c in ((30, 3), (330, 2)):
        rgba[y:y + 8, :] = C("ink", c)
        rgba[y:y + 1, :] = C("ink", c + 2)
        for x in range(20, w, 80):
            rgba[y - 2:y + 10, x:x + 6] = C("ink", c + 1)
    return rgba


def bg_glorbo():
    w, h = 640, 360
    yy = (np.arange(h)[:, None] + 0.5) / h
    sky = np.broadcast_to(1 - yy, (h, w))
    clouds = _fbm(h, w, 160, 33, octaves=4, wrap_x=True)
    val = np.clip(sky * 0.75 + (clouds - 0.5) * 0.35, 0, 1)
    pal = np.array([C("space", 0), C("neon", 0), C("neon", 1), C("moss", 1), C("moss", 2)],
                   dtype=np.uint8)
    rgba = pal[_dither(val, 5)].copy()
    # three suns-moons
    yy2, xx = np.mgrid[0:h, 0:w]
    for cx, cy, r, rn in ((120, 70, 26, "gold"), (520, 50, 14, "aqua")):
        d = np.sqrt((xx - cx) ** 2 + (yy2 - cy) ** 2)
        rgba[d < r] = C(rn, 6)
        rgba[(d < r) & (d > r - 3)] = C(rn, 4)
    # tower silhouettes (tileable)
    rng = np.random.default_rng(12)
    x = 0
    while x < w:
        tw = int(rng.integers(18, 40))
        th = int(rng.integers(60, 170))
        x1 = min(w, x + tw)
        rgba[h - th:h, x:x1] = C("neon", 0)
        rgba[h - th - 10:h - th, x + tw // 3:min(w, x + 2 * tw // 3)] = C("neon", 0)
        for wy in range(h - th + 10, h - 10, 14):
            if rng.random() < 0.6:
                rgba[wy:wy + 4, x + 4:min(w, x + 7)] = C("gold", 5)
        x = x1 + int(rng.integers(6, 30))
    return rgba


def backdrops():
    from sprites import make_nebula
    neb = make_nebula()[0][0]
    neb_arr = np.zeros((neb.h, neb.w, 4), dtype=np.uint8)
    for y in range(neb.h):
        for x in range(neb.w):
            c = neb.px[y][x]
            if c is not None:
                neb_arr[y, x] = c
    return neb_arr, bg_station(), bg_glorbo()


# -------------------------------------------------------------- planetoids --

STYLE_RAMPS = {
    0: ("clay", (0, 1, 2, 3, 4, 5, 6, 7), "ink", (0, 1, 1, 2, 2, 3, 3, 4), "aqua"),
    1: ("aqua", (0, 1, 2, 3, 4, 5, 6, 7), "ink", (2, 3, 4, 5, 5, 6, 6, 7), "space"),
    2: ("neon", (0, 1, 2, 3, 4, 5, 6, 7), "moss", (0, 1, 2, 3, 4, 5, 5, 6), "gold"),
    3: ("ink", (0, 1, 2, 3, 4, 5, 6, 6), "space", (1, 2, 2, 3, 3, 4, 4, 5), "ember"),
}


def planet(radius, style, seed=None):
    seed = seed if seed is not None else radius * 7 + style
    pad = 2
    size = radius * 2 + pad * 2
    dx, dy, d2, inside, lam = _sphere(size, radius)
    rn, ri, mn, mi, rim = STYLE_RAMPS[style]
    rock, mat = _ramp(rn, ri), _ramp(mn, mi)
    cell = max(8, radius // 2)
    terrain = _fbm(size, size, cell, seed)
    detail = _fbm(size, size, max(4, cell // 4), seed + 1, octaves=2)
    lum = 0.12 + 0.78 * lam + (terrain - 0.5) * 0.35 + (detail - 0.5) * 0.18
    rng = np.random.default_rng(seed + 2)
    yy, xx = np.mgrid[0:size, 0:size]
    rimm = np.zeros_like(inside)
    if style != 3:
        for _ in range(max(3, radius // 12)):
            ang = rng.random() * 2 * np.pi
            dist = np.sqrt(rng.random()) * radius * 0.78
            ccx = size / 2 + np.cos(ang) * dist
            ccy = size / 2 + np.sin(ang) * dist
            cr = radius * (0.06 + rng.random() * 0.12)
            ex, ey = (xx + 0.5 - ccx) / cr, (yy + 0.5 - ccy) / cr
            e2 = ex * ex + ey * ey
            bowl = e2 < 1.0
            lum = np.where(bowl, 0.25 + 0.35 * (ex * 0.55 + ey * 0.6) + 0.2 * lam, lum)
            rimm |= (e2 >= 1.0) & (e2 < 1.45) & ((ex * -0.55 + ey * -0.6) > 0.15)
    else:
        # metal station-planetoid: panel seams and lights
        ang = np.arctan2(dy, dx)
        seams = (np.abs(np.sin(ang * 6)) < 0.06) | (np.abs(np.sqrt(d2) - 0.6) < 0.02)
        lum = np.where(seams, lum - 0.3, lum)
    lum = np.where(rimm, lum + 0.22, lum)
    material = terrain + (detail - 0.5) * 0.3 > 0.62
    idx = _dither(lum, 8)
    rgba = np.zeros((size, size, 4), dtype=np.uint8)
    rgba[inside & ~material] = rock[idx[inside & ~material]]
    rgba[inside & material] = mat[idx[inside & material]]
    edge = inside & (d2 > 0.86) & ((dx * -0.55 + dy * -0.6) < -0.35)
    rl = _ramp(rim, (3, 4, 5))
    rli = _dither(np.clip((d2 - 0.86) / 0.14, 0, 1), 3)
    rgba[edge] = rl[rli[edge]]
    if style == 3:
        for k in range(8):
            a = k * math.pi / 4 + 0.2
            px = int(size / 2 + math.cos(a) * radius * 0.82)
            py = int(size / 2 + math.sin(a) * radius * 0.82)
            rgba[py - 1:py + 2, px - 1:px + 2] = C("ember", 6)
    return _outline(rgba)
