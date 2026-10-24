"""Generated sprite definitions. Characters come from the imported pack
(see import_characters.py). Each `make_*` returns (frames, frame_w, frame_h, anims, origin).

frames: list of Layer. anims: {name: {"frames": [...], "fps": n, "loop": bool}}.
origin: anchor point (feet for characters, centre for round objects).
"""
import math

from palette import color
from raster import Layer, dither_pick

K = color("ink", 0)

# -------------------------------------------------------------- planetoid ---

def make_planetoid(radius=30, seed=7):
    size = radius * 2 + 4
    layer = Layer(size, size)
    cx = cy = size / 2.0
    shades = [color("clay", i) for i in (1, 2, 3, 4, 5, 6)]
    crater_shades = [color("clay", i) for i in (0, 1, 2, 3, 4)]
    # deterministic LCG for crater placement
    state = seed

    def rnd():
        nonlocal state
        state = (state * 1103515245 + 12345) & 0x7FFFFFFF
        return state / 0x7FFFFFFF

    craters = [(cx + (rnd() - 0.5) * radius * 1.3, cy + (rnd() - 0.5) * radius * 1.3, 2 + rnd() * 5) for _ in range(7)]
    lx, ly, lz = -0.55, -0.6, 0.58  # light from top-left
    for y in range(size):
        for x in range(size):
            dx, dy = (x + 0.5 - cx) / radius, (y + 0.5 - cy) / radius
            d2 = dx * dx + dy * dy
            if d2 > 1.0:
                continue
            dz = math.sqrt(1.0 - d2)
            lum = max(0.0, dx * lx + dy * ly + dz * lz)
            pal = shades
            for (ccx, ccy, cr) in craters:
                if (x - ccx) ** 2 + (y - ccy) ** 2 < cr * cr:
                    pal = crater_shades
                    # inner rim lit on the opposite side
                    lum = 0.6 - 0.5 * ((x - ccx) * lx + (y - ccy) * ly) / cr
                    break
            layer.set(x, y, dither_pick(pal, lum, x, y))
    layer.outline(K)
    return [layer], size, size, {"idle": {"frames": [0], "fps": 1, "loop": True}}, (size // 2, size // 2)


SPRITES = {
    "planetoid_small": lambda: make_planetoid(radius=30, seed=7),
    "planetoid_medium": lambda: make_planetoid(radius=60, seed=94),
}
