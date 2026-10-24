"""Sprite definitions. Each `make_*` returns (frames, frame_w, frame_h, anims, origin).

frames: list of Layer. anims: {name: {"frames": [...], "fps": n, "loop": bool}}.
origin: anchor point (feet for characters, centre for round objects).
"""
import math

from palette import color
from raster import Layer, dither_pick

K = color("ink", 0)

# ---------------------------------------------------------------- player ---
# Rex "Torpedo" Calloway: orange magnetic suit, white bubble helmet, cyan visor,
# twin-cell backpack. Facing right. Upper body is a hand-drawn matrix; legs are
# procedural capsules so the 8-frame run cycle stays consistent.

REX_KEYS = {
    "K": K,
    "H": color("ink", 6),  # helmet
    "h": color("ink", 5),  # helmet shade
    "W": color("ink", 7),  # highlight
    "V": color("aqua", 5),  # visor
    "v": color("aqua", 3),  # visor shade
    "S": color("ember", 5),  # suit
    "s": color("ember", 3),  # suit shade
    "P": color("space", 4),  # backpack
    "p": color("space", 2),
    "G": color("ink", 5),  # gun
    "g": color("ink", 3),
    "Y": color("gold", 5),  # belt
    "L": color("gold", 7),  # gun light
}

REX_UPPER = [
    "..........KKKKKK",
    "........KKHHHHHHKK",
    ".......KHHWWHHHHHHK",
    "......KHHWHHHHHHHHHK",
    "......KHWHHHHKKKKKKKK",
    "......KHHHHHKVVVVVVVVK",
    "......KHHHHKVWWVVVVVVK",
    "......KhHHHKVWVVVVVvvK",
    "......KhHHHKVVVVVvvvvK",
    "......KhhHHHKKKKKKKKK",
    ".......KhhhhhhhhhhhK",
    ".....KKKKKKKKKKKKKKK",
    "....KPPKSSSSSSSSSSSK",
    "....KPPKSWSSSSSSSKKKKKKKKKK",
    "....KPPKSWSSSSSKKGGGGGGGGGLK",
    "....KPpKSSSSSSKsKgggggKKKKKK",
    "....KPpKsSSSSKssKKKKKK",
    ".....KKKsssSSKKKK",
    "......KYYYYYYYK",
    "......KsSSSSSSK",
]

HIP_BACK = (9.5, 20.0)
HIP_FRONT = (12.5, 20.0)
THIGH, SHIN = 5.0, 5.5


def _leg(layer, hip, thigh_deg, knee_deg, suit, boot):
    hx, hy = hip
    a = math.radians(thigh_deg)
    kx, ky = hx + math.sin(a) * THIGH, hy + math.cos(a) * THIGH
    b = math.radians(thigh_deg - knee_deg)
    fx, fy = kx + math.sin(b) * SHIN, ky + math.cos(b) * SHIN
    layer.capsule(hx, hy, kx, ky, 1.6, suit)
    layer.capsule(kx, ky, fx, fy, 1.5, suit)
    # boot: short horizontal capsule pointing forward
    layer.capsule(fx - 0.5, fy - 0.5, fx + 2.0, fy - 0.5, 1.4, boot)


def _rex_frame(back, front, bob=0):
    legs = Layer(32, 32)
    _leg(legs, HIP_BACK, back[0], back[1], color("ember", 3), color("ink", 2))
    _leg(legs, HIP_FRONT, front[0], front[1], color("ember", 5), color("ink", 3))
    legs.outline(K)
    frame = Layer(32, 32)
    frame.blit(legs, 0, bob)
    upper = Layer(32, 32)
    upper.blit_matrix(REX_UPPER, REX_KEYS)
    frame.blit(upper, 0, bob)
    return frame


def make_player():
    frames = []
    anims = {}
    # idle: 2 frames breathing
    idle = [_rex_frame((-6, 0), (6, 0)), _rex_frame((-6, 0), (6, 0), bob=1)]
    anims["idle"] = {"frames": [0, 1], "fps": 3, "loop": True}
    frames += idle
    # run: 8 frames. Thigh swings +-32 deg, knee bends on the back-swing.
    start = len(frames)
    for i in range(8):
        ph = i / 8.0 * 2 * math.pi
        t_f = 32 * math.sin(ph)
        t_b = -32 * math.sin(ph)
        k_f = 8 + 32 * max(0.0, -math.sin(ph + 0.6))
        k_b = 8 + 32 * max(0.0, math.sin(ph + 0.6))
        bob = 0 if i % 4 in (0, 1) else 1
        frames.append(_rex_frame((t_b, k_b), (t_f, k_f), bob=bob - 1))
    anims["run"] = {"frames": list(range(start, start + 8)), "fps": 14, "loop": True}
    return frames, 32, 32, anims, (14, 31)


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
    "player_rex": make_player,
    "planetoid_small": make_planetoid,
}
