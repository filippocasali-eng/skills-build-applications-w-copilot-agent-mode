"""Numpy pixel-art painting helpers on top of the master palette.

Everything is integer-exact and deterministic. Shading uses ordered (Bayer)
dithering between the shades of a palette ramp, lit from the top-left.
"""
import math

import numpy as np

from palette import RAMPS, color

_BAYER = (np.array([[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]],
                   dtype=np.float64) + 0.5) / 16.0
INK = color("ink", 0)
LIGHT = (-0.55, -0.65, 0.52)


def ramp(name, lo=0, hi=7):
    return [color(name, i) for i in range(lo, hi + 1)]


class Canvas:
    def __init__(self, w, h):
        self.w, self.h = w, h
        self.a = np.zeros((h, w, 4), dtype=np.uint8)

    # ----------------------------------------------------------- basics --
    def px(self, x, y, c):
        if 0 <= x < self.w and 0 <= y < self.h:
            self.a[int(y), int(x)] = c

    def _grid(self):
        yy, xx = np.mgrid[0:self.h, 0:self.w]
        return xx + 0.5, yy + 0.5

    def _shade(self, mask, value, shades):
        """Write dithered shades where mask is true. value in [0,1]."""
        n = len(shades)
        v = np.clip(value, 0, 1) * (n - 1)
        lo = np.floor(v)
        frac = v - lo
        bayer = np.tile(_BAYER, (self.h // 4 + 1, self.w // 4 + 1))[:self.h, :self.w]
        idx = np.clip(lo + (frac > bayer), 0, n - 1).astype(int)
        pal = np.array(shades, dtype=np.uint8)
        self.a[mask] = pal[idx[mask]]

    # ----------------------------------------------------------- shapes --
    def ellipse(self, cx, cy, rx, ry, shades, light=LIGHT, flat=False, amb=0.18):
        xx, yy = self._grid()
        dx, dy = (xx - cx) / rx, (yy - cy) / ry
        d2 = dx * dx + dy * dy
        mask = d2 <= 1.0
        if flat:
            val = np.full(d2.shape, 0.6)
        else:
            dz = np.sqrt(np.clip(1 - d2, 0, 1))
            lx, ly, lz = light
            val = amb + (1 - amb) * np.clip(dx * lx + dy * ly + dz * lz, 0, 1)
        self._shade(mask, val, shades)
        return mask

    def rect(self, x0, y0, x1, y1, shades, bevel=1, base=0.55):
        """Box with a lit top-left bevel and a dark bottom-right bevel."""
        xx, yy = self._grid()
        mask = (xx >= x0) & (xx < x1) & (yy >= y0) & (yy < y1)
        val = np.full(xx.shape, base)
        if bevel:
            val = np.where((xx < x0 + bevel) | (yy < y0 + bevel), base + 0.3, val)
            val = np.where((xx >= x1 - bevel) | (yy >= y1 - bevel), base - 0.35, val)
        # gentle vertical gradient
        val = val + (0.12 - 0.24 * (yy - y0) / max(1, y1 - y0))
        self._shade(mask, val, shades)
        return mask

    def poly(self, pts, shades, base=0.55, grad=0.25):
        xx, yy = self._grid()
        inside = np.zeros(xx.shape, dtype=bool)
        n = len(pts)
        for i in range(n):
            x1, y1 = pts[i]
            x2, y2 = pts[(i + 1) % n]
            cond = (y1 > yy) != (y2 > yy)
            with np.errstate(divide="ignore", invalid="ignore"):
                xi = x1 + (yy - y1) * (x2 - x1) / (y2 - y1)
            inside ^= cond & (xx < xi)
        ys = [p[1] for p in pts]
        y0, y1 = min(ys), max(ys)
        val = base + grad * (0.5 - (yy - y0) / max(1, y1 - y0))
        self._shade(inside, val, shades if isinstance(shades, list) else [shades])
        return inside

    def line(self, x0, y0, x1, y1, c, width=1):
        steps = int(max(abs(x1 - x0), abs(y1 - y0)) * 2) + 1
        r = width / 2.0
        for i in range(steps + 1):
            t = i / steps
            x, y = x0 + (x1 - x0) * t, y0 + (y1 - y0) * t
            if width <= 1:
                self.px(round(x - 0.5), round(y - 0.5), c)
            else:
                for oy in range(int(-r), int(r) + 1):
                    for ox in range(int(-r), int(r) + 1):
                        if ox * ox + oy * oy <= r * r:
                            self.px(round(x - 0.5 + ox), round(y - 0.5 + oy), c)

    def disc(self, cx, cy, r, c):
        xx, yy = self._grid()
        self.a[(xx - cx) ** 2 + (yy - cy) ** 2 <= r * r] = c

    def matrix(self, rows, keys, ox=0, oy=0):
        for y, row in enumerate(rows):
            for x, ch in enumerate(row):
                if ch not in (".", " "):
                    self.px(ox + x, oy + y, keys[ch])

    def outline(self, c=INK, diagonal=False):
        solid = self.a[:, :, 3] > 0
        g = solid.copy()
        g[1:] |= solid[:-1]
        g[:-1] |= solid[1:]
        g[:, 1:] |= solid[:, :-1]
        g[:, :-1] |= solid[:, 1:]
        if diagonal:
            g[1:, 1:] |= solid[:-1, :-1]
            g[:-1, :-1] |= solid[1:, 1:]
            g[1:, :-1] |= solid[:-1, 1:]
            g[:-1, 1:] |= solid[1:, :-1]
        self.a[g & ~solid] = c
        return self

    def blit(self, other, ox, oy):
        h, w = other.a.shape[:2]
        for y in range(h):
            ty = oy + y
            if not 0 <= ty < self.h:
                continue
            for x in range(w):
                tx = ox + x
                if 0 <= tx < self.w and other.a[y, x, 3]:
                    self.a[ty, tx] = other.a[y, x]

    def flipped(self):
        c = Canvas(self.w, self.h)
        c.a = self.a[:, ::-1].copy()
        return c

    def copy(self):
        c = Canvas(self.w, self.h)
        c.a = self.a.copy()
        return c


# Tiny 3x5 font for labels painted into sprites (crate letters, signs).
MINI = {
    "S": ["XXX", "X..", "XXX", "..X", "XXX"], "L": ["X..", "X..", "X..", "X..", "XXX"],
    "P": ["XXX", "X.X", "XXX", "X..", "X.."], "H": ["X.X", "X.X", "XXX", "X.X", "X.X"],
    "F": ["XXX", "X..", "XX.", "X..", "X.."], "R": ["XX.", "X.X", "XX.", "X.X", "X.X"],
    "G": ["XXX", "X..", "X.X", "X.X", "XXX"], "1": [".X.", "XX.", ".X.", ".X.", "XXX"],
    "U": ["X.X", "X.X", "X.X", "X.X", "XXX"], "E": ["XXX", "X..", "XX.", "X..", "XXX"],
    "X": ["X.X", "X.X", ".X.", "X.X", "X.X"], "I": ["XXX", ".X.", ".X.", ".X.", "XXX"],
    "T": ["XXX", ".X.", ".X.", ".X.", ".X."], "+": ["...", ".X.", "XXX", ".X.", "..."],
    "O": ["XXX", "X.X", "X.X", "X.X", "XXX"], "K": ["X.X", "X.X", "XX.", "X.X", "X.X"],
}


def mini_text(cv, text, x, y, c):
    for ch in text:
        g = MINI.get(ch)
        if g:
            for gy, row in enumerate(g):
                for gx, v in enumerate(row):
                    if v == "X":
                        cv.px(x + gx, y + gy, c)
        x += 4


def all_ramp_names():
    return list(RAMPS.keys())


def rot(px, py, cx, cy, a):
    c, s = math.cos(a), math.sin(a)
    return cx + (px - cx) * c - (py - cy) * s, cy + (px - cx) * s + (py - cy) * c
