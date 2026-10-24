"""Generated sprite definitions (backgrounds, planetoids, props).

Characters come from the imported pack (see import_characters.py).
Each `make_*` returns (frames, frame_w, frame_h, anims, origin):
frames is a list of Layer, anims maps names to {"frames", "fps", "loop"},
origin is the anchor (centre for round objects, top-left for backdrops).

Everything is drawn with the master palette and 4x4 Bayer dithering, and is
deterministic (fixed seeds, no wall-clock or platform randomness).
"""
import numpy as np

from palette import color
from raster import BAYER4, Layer

K = color("ink", 0)
STATIC = {"idle": {"frames": [0], "fps": 1, "loop": True}}
_BAYER = (np.array(BAYER4, dtype=np.float64) + 0.5) / 16.0


# ----------------------------------------------------------------- helpers ---

def _ramp(name, indices):
    return np.array([color(name, i) for i in indices], dtype=np.uint8)


def _bayer(h, w):
    return np.tile(_BAYER, (h // 4 + 1, w // 4 + 1))[:h, :w]


def _dither(value, n):
    """Map value in [0,1] (2D array) to shade indices 0..n-1 with ordered dither."""
    v = np.clip(value, 0.0, 1.0) * (n - 1)
    lo = np.floor(v)
    frac = v - lo
    idx = lo + (frac > _bayer(*value.shape))
    return np.clip(idx, 0, n - 1).astype(np.int32)


def _value_noise(h, w, cell, rng, wrap_x=False):
    gw = w // cell + (0 if wrap_x else 2)
    gh = h // cell + 2
    grid = rng.random((gh, gw))
    ys = (np.arange(h) + 0.5) / cell
    xs = (np.arange(w) + 0.5) / cell
    y0 = np.floor(ys).astype(int)
    x0 = np.floor(xs).astype(int)
    ty = ys - y0
    tx = xs - x0
    ty = ty * ty * (3 - 2 * ty)
    tx = tx * tx * (3 - 2 * tx)
    x1 = (x0 + 1) % gw if wrap_x else x0 + 1
    x0 = x0 % gw if wrap_x else x0
    a = grid[y0][:, x0]
    b = grid[y0][:, x1]
    c = grid[y0 + 1][:, x0]
    d = grid[y0 + 1][:, x1]
    top = a + (b - a) * tx
    bot = c + (d - c) * tx
    return top + (bot - top) * ty[:, None]


def _fbm(h, w, cell, seed, octaves=4, wrap_x=False):
    rng = np.random.default_rng(seed)
    total = np.zeros((h, w))
    amp, norm = 1.0, 0.0
    for _ in range(octaves):
        total += amp * _value_noise(h, w, max(cell, 1), rng, wrap_x)
        norm += amp
        amp *= 0.5
        cell //= 2
    return total / norm


def _to_layer(rgba):
    h, w = rgba.shape[:2]
    layer = Layer(w, h)
    for y in range(h):
        row = layer.px[y]
        for x in range(w):
            p = rgba[y, x]
            if p[3]:
                row[x] = tuple(int(c) for c in p)
    return layer


def _outline(rgba):
    solid = rgba[:, :, 3] > 0
    grown = solid.copy()
    grown[1:] |= solid[:-1]
    grown[:-1] |= solid[1:]
    grown[:, 1:] |= solid[:, :-1]
    grown[:, :-1] |= solid[:, 1:]
    rgba[grown & ~solid] = K
    return rgba


def _sphere(size, radius, light=(-0.55, -0.6, 0.58)):
    c = size / 2.0
    yy, xx = np.mgrid[0:size, 0:size]
    dx = (xx + 0.5 - c) / radius
    dy = (yy + 0.5 - c) / radius
    d2 = dx * dx + dy * dy
    inside = d2 <= 1.0
    dz = np.sqrt(np.clip(1.0 - d2, 0, 1))
    lx, ly, lz = light
    lambert = np.clip(dx * lx + dy * ly + dz * lz, 0, 1)
    return dx, dy, d2, inside, lambert


# --------------------------------------------------------------- planetoid ---

def make_planetoid(radius=60, seed=94):
    """Rocky planetoid: terrain noise, two materials, craters with lit rims,
    and an aqua rim light on the shadow side (16-bit 'backlight' look)."""
    pad = 2
    size = radius * 2 + pad * 2
    dx, dy, d2, inside, lam = _sphere(size, radius)
    rock = _ramp("clay", range(8))
    basalt = _ramp("ink", (0, 1, 1, 2, 2, 3, 3, 4))

    cell = max(8, radius // 2)
    terrain = _fbm(size, size, cell, seed)
    detail = _fbm(size, size, max(4, cell // 4), seed + 1, octaves=2)
    lum = 0.12 + 0.78 * lam + (terrain - 0.5) * 0.35 + (detail - 0.5) * 0.18

    # Craters: bowl shading (dark toward the light, lit far wall) + rim.
    rng = np.random.default_rng(seed + 2)
    yy, xx = np.mgrid[0:size, 0:size]
    rim = np.zeros_like(lum, dtype=bool)
    n_craters = max(4, radius // 10)
    for _ in range(n_craters):
        ang = rng.random() * 2 * np.pi
        dist = np.sqrt(rng.random()) * radius * 0.8
        ccx = size / 2 + np.cos(ang) * dist
        ccy = size / 2 + np.sin(ang) * dist
        cr = radius * (0.05 + rng.random() * 0.12)
        ex, ey = (xx + 0.5 - ccx) / cr, (yy + 0.5 - ccy) / cr
        e2 = ex * ex + ey * ey
        bowl = e2 < 1.0
        # Light comes from top-left, so the bowl's lower-right wall is lit.
        lum = np.where(bowl, 0.25 + 0.35 * (ex * 0.55 + ey * 0.6) + 0.2 * lam, lum)
        rim |= (e2 >= 1.0) & (e2 < 1.45) & ((ex * -0.55 + ey * -0.6) > 0.15)

    lum = np.where(rim, lum + 0.22, lum)
    material = terrain + (detail - 0.5) * 0.3 > 0.62
    idx = _dither(lum, 8)
    rgba = np.zeros((size, size, 4), dtype=np.uint8)
    rgba[inside & ~material] = rock[idx[inside & ~material]]
    rgba[inside & material] = basalt[idx[inside & material]]

    # Rim light on the shadow side.
    edge = inside & (d2 > 0.86) & ((dx * -0.55 + dy * -0.6) < -0.35)
    rl = _ramp("aqua", (3, 4, 5))
    rli = _dither(np.clip((d2 - 0.86) / 0.14, 0, 1), 3)
    rgba[edge] = rl[rli[edge]]

    rgba = _outline(rgba)
    return [_to_layer(rgba)], size, size, STATIC, (size // 2, size // 2)


# ------------------------------------------------------------------ nebula ---

def make_nebula(w=640, h=360, seed=1994):
    """Full-screen backdrop, tileable horizontally for parallax scrolling."""
    gas = _fbm(h, w, 160, seed, octaves=5, wrap_x=True)
    tint = _fbm(h, w, 80, seed + 7, octaves=3, wrap_x=True)
    # Vertical band so the nebula reads as a 'river' across the sky.
    yy = (np.arange(h)[:, None] + 0.5) / h
    band = np.exp(-((yy - 0.42) ** 2) / 0.06)
    # Kept dark on purpose: the backdrop must never compete with sprites.
    density = np.clip((gas - 0.45) * 2.2 * (0.35 + 0.65 * band), 0, 1)

    space = _ramp("space", (0, 0, 1, 2, 3))
    neon = _ramp("neon", (0, 0, 0, 1, 2))
    idx = _dither(density, 5)
    rgba = np.where((tint > 0.58)[:, :, None], neon[idx], space[idx]).astype(np.uint8)
    return [_to_layer(rgba)], w, h, STATIC, (0, 0)


# ---------------------------------------------------------- ringed planet ---

def make_ringed_planet(radius=26, seed=5):
    """Distant gas giant with bands and a tilted ring (back half behind)."""
    w, h = radius * 5, radius * 3
    cxp, cyp = w / 2.0, h / 2.0
    yy, xx = np.mgrid[0:h, 0:w]
    dx = (xx + 0.5 - cxp) / radius
    dy = (yy + 0.5 - cyp) / radius
    d2 = dx * dx + dy * dy
    body = d2 <= 1.0
    dz = np.sqrt(np.clip(1 - d2, 0, 1))
    lam = np.clip(dx * -0.6 + dy * -0.45 + dz * 0.66, 0, 1)
    wobble = _fbm(h, w, 16, seed, octaves=3)
    bands = 0.5 + 0.5 * np.sin((dy * 1.0 + (wobble - 0.5) * 0.35) * 9.0)
    lum = 0.1 + 0.75 * lam + (bands - 0.5) * 0.3
    planet = _ramp("aqua", range(1, 8))
    pidx = _dither(lum, 7)

    # Ring: ellipse annulus, tilted.
    tilt = 0.32
    rx, ry = dx, (dy - dx * 0.18) / tilt
    rr = np.sqrt(rx * rx + ry * ry)
    ring = (rr > 1.35) & (rr < 2.2) & ~((rr > 1.7) & (rr < 1.78))  # with a gap
    ring_lum = np.clip(0.75 - (rr - 1.35) * 0.35 + (dx * -0.15), 0, 1)
    rcol = _ramp("gold", range(1, 7))
    ridx = _dither(ring_lum, 6)
    front = ry > 0  # lower half of the ellipse passes in front

    rgba = np.zeros((h, w, 4), dtype=np.uint8)
    back = ring & ~front & ~body
    rgba[back] = rcol[ridx[back]]
    rgba[body] = planet[pidx[body]]
    fr = ring & front
    rgba[fr] = rcol[ridx[fr]]
    rgba = _outline(rgba)
    return [_to_layer(rgba)], w, h, STATIC, (w // 2, h // 2)


SPRITES = {
    "planetoid_small": lambda: make_planetoid(radius=40, seed=7),
    "planetoid_large": lambda: make_planetoid(radius=110, seed=94),
    "nebula": make_nebula,
    "ringed_planet": make_ringed_planet,
}
