"""Tiny raster helpers used by the sprite definitions.

A Layer is a w*h grid of RGBA tuples (or None for transparent). All drawing is
integer and deterministic, so re-running the build always produces byte-identical
PNGs.
"""
import math

BAYER4 = [
    [0, 8, 2, 10],
    [12, 4, 14, 6],
    [3, 11, 1, 9],
    [15, 7, 13, 5],
]


class Layer:
    def __init__(self, w, h):
        self.w, self.h = w, h
        self.px = [[None] * w for _ in range(h)]

    def get(self, x, y):
        if 0 <= x < self.w and 0 <= y < self.h:
            return self.px[y][x]
        return None

    def set(self, x, y, c):
        if 0 <= x < self.w and 0 <= y < self.h:
            self.px[y][x] = c

    def blit_matrix(self, rows, keys, ox=0, oy=0):
        """Draw a character matrix. `keys` maps chars to colours; '.' is empty."""
        for y, row in enumerate(rows):
            for x, ch in enumerate(row):
                if ch == "." or ch == " ":
                    continue
                self.set(ox + x, oy + y, keys[ch])

    def blit(self, other, ox=0, oy=0):
        for y in range(other.h):
            for x in range(other.w):
                c = other.px[y][x]
                if c is not None:
                    self.set(ox + x, oy + y, c)

    def capsule(self, x0, y0, x1, y1, r, c):
        """Fill a thick segment (capsule) with colour c."""
        minx, maxx = int(math.floor(min(x0, x1) - r)), int(math.ceil(max(x0, x1) + r))
        miny, maxy = int(math.floor(min(y0, y1) - r)), int(math.ceil(max(y0, y1) + r))
        dx, dy = x1 - x0, y1 - y0
        ll = dx * dx + dy * dy or 1e-9
        for y in range(miny, maxy + 1):
            for x in range(minx, maxx + 1):
                px, py = x + 0.5, y + 0.5
                t = max(0.0, min(1.0, ((px - x0) * dx + (py - y0) * dy) / ll))
                qx, qy = x0 + t * dx, y0 + t * dy
                if (px - qx) ** 2 + (py - qy) ** 2 <= r * r:
                    self.set(x, y, c)

    def outline(self, c, diagonal=False):
        """Add a 1px outline around every opaque pixel."""
        add = []
        n = [(1, 0), (-1, 0), (0, 1), (0, -1)]
        if diagonal:
            n += [(1, 1), (-1, -1), (1, -1), (-1, 1)]
        for y in range(self.h):
            for x in range(self.w):
                if self.px[y][x] is not None:
                    continue
                if any(self.get(x + dx, y + dy) is not None for dx, dy in n):
                    add.append((x, y))
        for x, y in add:
            self.px[y][x] = c

    def flipped(self):
        out = Layer(self.w, self.h)
        for y in range(self.h):
            out.px[y] = list(reversed(self.px[y]))
        return out


def dither_pick(shades, value, x, y):
    """Pick from an ordered list of shades using 4x4 Bayer dithering.

    value in [0, 1]: 0 = first shade, 1 = last shade.
    """
    value = max(0.0, min(1.0, value)) * (len(shades) - 1)
    lo = int(math.floor(value))
    frac = value - lo
    if lo >= len(shades) - 1:
        return shades[-1]
    threshold = (BAYER4[y % 4][x % 4] + 0.5) / 16.0
    return shades[lo + 1] if frac > threshold else shades[lo]
