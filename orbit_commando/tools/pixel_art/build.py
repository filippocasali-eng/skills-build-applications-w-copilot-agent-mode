"""Build every generated asset.

    python3 tools/pixel_art/build.py            # from the project root

Outputs (all committed, all byte-reproducible):
  assets/sprites/<name>.png + <name>.json   sprite atlases (generated + imported characters)
  assets/fonts/orbit5.png + orbit5.json      bitmap font
  assets/palette.json
  lib/engine/render/palette.g.dart

See ART_PIPELINE.md for the atlas format and how to replace placeholders.
"""
import json
import os
import sys

from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
sys.path.insert(0, HERE)

import font  # noqa: E402
import palette  # noqa: E402
from sprites import SPRITES  # noqa: E402
import import_characters  # noqa: E402
import ttf  # noqa: E402
import numpy as np  # noqa: E402
from art_env import backdrops, planet, textures  # noqa: E402
from art_game import GAME_ART  # noqa: E402

PALETTE_SET = {c + (255,) for c in palette.all_colors()}
COLS = 8


def _check_palette(name, layer):
    for row in layer.px:
        for c in row:
            if c is not None and c not in PALETTE_SET:
                raise SystemExit(f"{name}: colour {c} is not in the master palette")


def _save_png(img, path):
    # Strip metadata so output is byte-identical across runs.
    img.save(path, format="PNG", optimize=True)


def build_sprite(name, maker):
    frames, fw, fh, anims, origin = maker()
    cols = min(COLS, len(frames))
    rows = (len(frames) + cols - 1) // cols
    img = Image.new("RGBA", (cols * fw, rows * fh), (0, 0, 0, 0))
    meta_frames = []
    for i, layer in enumerate(frames):
        _check_palette(name, layer)
        fx, fy = (i % cols) * fw, (i // cols) * fh
        for y in range(layer.h):
            for x in range(layer.w):
                c = layer.px[y][x]
                if c is not None:
                    img.putpixel((fx + x, fy + y), c)
        meta_frames.append({"x": fx, "y": fy, "w": fw, "h": fh})
    _save_png(img, os.path.join(ROOT, "assets", "sprites", f"{name}.png"))
    meta = {
        "version": 1,
        "image": f"{name}.png",
        "origin": {"x": origin[0], "y": origin[1]},
        "frames": meta_frames,
        "animations": anims,
    }
    with open(os.path.join(ROOT, "assets", "sprites", f"{name}.json"), "w") as f:
        json.dump(meta, f, indent=1, sort_keys=True)
        f.write("\n")
    return len(frames)


PALETTE_ARR = np.array(sorted(PALETTE_SET), dtype=np.uint8)


def _check_array(name, arr):
    opaque = arr[arr[:, :, 3] > 0]
    if len(opaque) == 0:
        return
    cols = {tuple(int(v) for v in c) for c in np.unique(opaque.reshape(-1, 4), axis=0)}
    bad = cols - PALETTE_SET
    if bad:
        raise SystemExit(f"{name}: colours {sorted(bad)[:4]} are not in the master palette")


def save_canvas_atlas(name, frames, anims, origin, out_dir="sprites", cols=None):
    """Writes frames (Canvas objects of equal size) as an atlas + JSON."""
    fh, fw = frames[0].a.shape[:2]
    cols = cols or min(8, len(frames))
    rows = (len(frames) + cols - 1) // cols
    sheet = np.zeros((rows * fh, cols * fw, 4), dtype=np.uint8)
    meta_frames = []
    for i, cv in enumerate(frames):
        assert cv.a.shape[:2] == (fh, fw), f"{name}: frame {i} size mismatch"
        _check_array(f"{name}[{i}]", cv.a)
        x, y = (i % cols) * fw, (i // cols) * fh
        sheet[y:y + fh, x:x + fw] = cv.a
        meta_frames.append({"x": x, "y": y, "w": fw, "h": fh})
    d = os.path.join(ROOT, "assets", out_dir)
    os.makedirs(d, exist_ok=True)
    _save_png(Image.fromarray(sheet), os.path.join(d, f"{name}.png"))
    meta = {"version": 1, "image": f"{name}.png",
            "origin": {"x": origin[0], "y": origin[1]},
            "frames": meta_frames, "animations": anims}
    with open(os.path.join(d, f"{name}.json"), "w") as f:
        json.dump(meta, f, indent=1, sort_keys=True)
        f.write("\n")
    return len(frames)


def save_image(path, arr, check=True):
    if check:
        _check_array(path, arr)
    full = os.path.join(ROOT, "assets", path)
    os.makedirs(os.path.dirname(full), exist_ok=True)
    _save_png(Image.fromarray(arr), full)


def build_env():
    from paint import Canvas  # noqa: F401
    frames, anims, origin = textures()
    save_canvas_atlas("textures", frames, anims, origin, out_dir="tiles", cols=3)
    neb, station, glorbo = backdrops()
    save_image("sprites/bg_asteroids.png", neb)
    save_image("sprites/bg_station.png", station)
    save_image("sprites/bg_glorbo.png", glorbo)
    used = os.path.join(ROOT, "tools", "level_gen", "planets_used.json")
    sizes = json.load(open(used)) if os.path.exists(used) else []
    sizes = sorted({tuple(s) for s in sizes} | {(110, 0), (40, 0)})
    for r, style in sizes:
        save_image(f"planets/planet_s{style}_r{r}.png", planet(r, style))
    return len(sizes)


def build_font():
    chars = font.charset()
    cells = [font.cell(ch) for ch in chars]
    per_row = 16
    max_w = max(len(c[0]) for c in cells)
    cw, ch_h = max_w + 1, font.CELL_H
    rows = (len(chars) + per_row - 1) // per_row
    img = Image.new("RGBA", (per_row * cw, rows * ch_h), (0, 0, 0, 0))
    glyphs = {}
    for i, (char, cell) in enumerate(zip(chars, cells)):
        gx, gy = (i % per_row) * cw, (i // per_row) * ch_h
        for y, row in enumerate(cell):
            for x, v in enumerate(row):
                if v == "X":
                    img.putpixel((gx + x, gy + y), (255, 255, 255, 255))
        glyphs[char] = {"x": gx, "y": gy, "w": len(cell[0])}
    _save_png(img, os.path.join(ROOT, "assets", "fonts", "orbit5.png"))
    meta = {
        "version": 1,
        "image": "orbit5.png",
        "lineHeight": ch_h,
        "baseline": font.BODY_TOP + 7,
        "spacing": 1,
        "glyphs": glyphs,
    }
    with open(os.path.join(ROOT, "assets", "fonts", "orbit5.json"), "w", encoding="utf-8") as f:
        json.dump(meta, f, indent=1, sort_keys=True, ensure_ascii=False)
        f.write("\n")
    return len(chars)


def build_palette():
    with open(os.path.join(ROOT, "assets", "palette.json"), "w") as f:
        json.dump(palette.RAMPS, f, indent=1)
        f.write("\n")
    lines = [
        "// GENERATED by tools/pixel_art/build.py. Do not edit by hand.",
        "// ignore_for_file: constant_identifier_names",
        "",
        "import 'dart:ui';",
        "",
        "/// The 64-colour master palette (8 ramps x 8 shades, dark -> light).",
        "abstract final class Pal {",
    ]
    for name, ramp in palette.RAMPS.items():
        for i, h in enumerate(ramp):
            lines.append(f"  static const Color {name}{i} = Color(0xFF{h.upper()});")
    lines.append("")
    lines.append("  static const List<Color> all = [")
    for name, ramp in palette.RAMPS.items():
        lines.append("    " + ", ".join(f"{name}{i}" for i in range(len(ramp))) + ",")
    lines.append("  ];")
    lines.append("}")
    with open(os.path.join(ROOT, "lib", "engine", "render", "palette.g.dart"), "w") as f:
        f.write("\n".join(lines) + "\n")


def main():
    for d in ("assets/sprites", "assets/fonts", "lib/engine/render"):
        os.makedirs(os.path.join(ROOT, d), exist_ok=True)
    build_palette()
    n = build_font()
    print(f"font orbit5: {n} glyphs")
    ttf.build(os.path.join(ROOT, "assets", "fonts", "Orbit5.ttf"))
    for name, maker in SPRITES.items():
        print(f"sprite {name}: {build_sprite(name, maker)} frames")
    for name, (w, h, c) in import_characters.build_all(ROOT).items():
        print(f"character {name}: {w}x{h} frames, {c} colours")
    for name, maker in GAME_ART.items():
        frames, anims, origin = maker()
        print(f"art {name}: {save_canvas_atlas(name, frames, anims, origin)} frames")
    print(f"environment: textures, 3 backdrops, {build_env()} planetoids")


if __name__ == "__main__":
    main()
