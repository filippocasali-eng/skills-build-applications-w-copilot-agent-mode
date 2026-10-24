"""Convert the concept-resolution character pack into game-ready pixel sprites.

Source: art_source/characters/<name>.png. Each sheet is 4 columns x 2 rows:
frames 0-3 = run/patrol, frames 4-7 = attack/fire (see PACK_README.md).

Pipeline per character:
  1. split the sheet into frames by connected components (not a blind grid
     crop: guns and muzzle flashes cross the cell borders),
  2. find a stable anchor (feet baseline, hip centre),
  3. downscale every frame with one scale factor, sampling the source so the
     anchor lands on a whole pixel (no jitter between frames),
  4. hard alpha, quantize to the sprite's own 15-colour palette (one SNES-style
     sub-palette per character) and add a 1px dark outline,
  5. emit an atlas PNG + JSON in the same format as the generated sprites.

All output faces right; enemies (drawn facing left) are mirrored.
"""
import json
import os

import numpy as np
from PIL import Image
from scipy import ndimage

ALPHA_SOLID = 96  # source alpha considered part of the drawing
ALPHA_OUT = 128  # alpha threshold after downscaling
COLORS = 32  # per-sprite palette size (+ outline)
OUTLINE = (14, 11, 20, 255)

# name: (role, source facing, target body height in game pixels)
CHARACTERS = {
    "roxy": ("hero", "right", 68),
    "brutus": ("hero", "right", 72),
    "nyx": ("hero", "right", 68),
    "doc": ("hero", "right", 64),
    "grunt": ("enemy", "left", 64),
    "rocket": ("enemy", "left", 70),
    "cyclops": ("enemy", "left", 76),
    "bulwark": ("enemy", "left", 78),
}

ANIMS = {
    # Source pack: run 120 ms/frame, attack 140 ms/frame.
    "run": {"frames": [0, 1, 2, 3], "fps": 8.33, "loop": True},
    "attack": {"frames": [4, 5, 6, 7], "fps": 7.14, "loop": True},
    # Derived until dedicated frames exist (see ART_PIPELINE.md).
    "idle": {"frames": [4], "fps": 1, "loop": True},
    "jump": {"frames": [1], "fps": 1, "loop": False},
}


def split_frames(rgba):
    """Return 8 RGBA arrays (sheet-sized, other frames cleared) + their bboxes."""
    h, w = rgba.shape[:2]
    fw, fh = w / 4, h / 2
    solid = rgba[:, :, 3] >= ALPHA_SOLID
    labels, n = ndimage.label(solid, structure=np.ones((3, 3), dtype=bool))
    centroids = ndimage.center_of_mass(solid, labels, range(1, n + 1))
    owner = np.zeros(n + 1, dtype=np.int16) - 1
    for i, (cy, cx) in enumerate(centroids, start=1):
        owner[i] = min(int(cy // fh), 1) * 4 + min(int(cx // fw), 3)
    frame_of_pixel = owner[labels]
    frames = []
    for f in range(8):
        m = frame_of_pixel == f
        ys, xs = np.nonzero(m)
        out = np.zeros_like(rgba)
        out[m] = rgba[m]
        frames.append((out, (xs.min(), ys.min(), xs.max() + 1, ys.max() + 1)))
    return frames


def anchor_of(frame, bbox):
    """Feet baseline (bottom of the drawing) and hip centre (x)."""
    x0, y0, x1, y1 = bbox
    solid = frame[:, :, 3] >= ALPHA_SOLID
    h = y1 - y0
    # Hips/legs band: 55%-85% of the height. Excludes guns and muzzle flashes,
    # which sit higher, and splayed feet, which sit lower.
    band = solid[y0 + int(h * 0.55): y0 + int(h * 0.85), x0:x1]
    cols = np.nonzero(band)[1]
    cx = x0 + float(np.median(cols)) if len(cols) else (x0 + x1) / 2
    return cx, float(y1)


def quantize(img, colors):
    """Quantize opaque pixels to `colors` colours; alpha stays binary."""
    rgb = Image.new("RGB", img.size, (0, 0, 0))
    rgb.paste(img, mask=img.getchannel("A"))
    pal = rgb.quantize(colors=colors + 1, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE)
    return pal


def outline(arr):
    solid = arr[:, :, 3] > 0
    grown = ndimage.binary_dilation(solid, structure=np.array([[0, 1, 0], [1, 1, 1], [0, 1, 0]], dtype=bool))
    edge = grown & ~solid
    arr[edge] = OUTLINE
    return arr


def convert(name, src_path, out_dir):
    role, facing, target_h = CHARACTERS[name]
    sheet = np.array(Image.open(src_path).convert("RGBA"))
    frames = split_frames(sheet)
    anchors = [anchor_of(f, bb) for f, bb in frames]

    # One scale per character from the median run-frame height.
    run_h = sorted(bb[3] - bb[1] for _, bb in frames[:4])
    scale = target_h / ((run_h[1] + run_h[2]) / 2)

    # Common frame box around the anchor (in target pixels), +1px for outline.
    left = max((ax - bb[0]) * scale for (ax, _), (_, bb) in zip(anchors, frames))
    right = max((bb[2] - ax) * scale for (ax, _), (_, bb) in zip(anchors, frames))
    up = max((ay - bb[1]) * scale for (_, ay), (_, bb) in zip(anchors, frames))
    ox, oy = int(np.ceil(left)) + 1, int(np.ceil(up)) + 1
    fw = ox + int(np.ceil(right)) + 1
    fh = oy + 1  # feet sit on the last row

    # Shared palette: quantize all frames together so colours don't flicker.
    small = []
    for (frame, _), (ax, ay) in zip(frames, anchors):
        # Pad so the sampling box may extend past the sheet edges.
        pad = int(max(fw, fh) / scale) + 2
        padded = np.pad(frame, ((pad, pad), (pad, pad), (0, 0)))
        src = Image.fromarray(padded).convert("RGBa")  # premultiplied for resize
        ax, ay = ax + pad, ay + pad
        box = (ax - ox / scale, ay - oy / scale, ax + (fw - ox) / scale, ay + (fh - oy) / scale)
        img = src.resize((fw, fh), Image.Resampling.BOX, box=box).convert("RGBA")
        arr = np.array(img)
        arr[:, :, 3] = np.where(arr[:, :, 3] >= ALPHA_OUT, 255, 0)
        small.append(arr)

    strip = np.concatenate(small, axis=1)
    strip_img = Image.fromarray(strip)
    q = quantize(strip_img, COLORS - 1).convert("RGBA")
    qa = np.array(q)
    qa[:, :, 3] = strip[:, :, 3]
    qa[qa[:, :, 3] == 0] = 0

    out_frames = []
    for i in range(8):
        arr = qa[:, i * fw:(i + 1) * fw].copy()
        if facing == "left":
            arr = arr[:, ::-1]
        out_frames.append(outline(arr))

    # Anchor x after mirroring.
    ax_out = ox if facing == "right" else fw - 1 - ox

    cols = 4
    sheet_out = np.zeros((fh * 2, fw * cols, 4), dtype=np.uint8)
    meta_frames = []
    for i, arr in enumerate(out_frames):
        x, y = (i % cols) * fw, (i // cols) * fh
        sheet_out[y:y + fh, x:x + fw] = arr
        meta_frames.append({"x": x, "y": y, "w": fw, "h": fh})
    Image.fromarray(sheet_out).save(os.path.join(out_dir, f"{name}.png"), optimize=True)
    meta = {
        "version": 1,
        "image": f"{name}.png",
        "origin": {"x": ax_out, "y": fh - 1},
        "frames": meta_frames,
        "animations": ANIMS,
        "source": f"art_source/characters/{name}.png",
        "role": role,
    }
    with open(os.path.join(out_dir, f"{name}.json"), "w") as f:
        json.dump(meta, f, indent=1, sort_keys=True)
        f.write("\n")
    colours = {tuple(p) for a in out_frames for p in a.reshape(-1, 4) if p[3]}
    return fw, fh, len(colours)


def build_all(root):
    src_dir = os.path.join(root, "art_source", "characters")
    out_dir = os.path.join(root, "assets", "sprites")
    report = {}
    for name in CHARACTERS:
        report[name] = convert(name, os.path.join(src_dir, f"{name}.png"), out_dir)
    return report


if __name__ == "__main__":
    here = os.path.dirname(os.path.abspath(__file__))
    for name, (w, h, c) in build_all(os.path.abspath(os.path.join(here, "..", ".."))).items():
        print(f"{name}: {w}x{h}, {c} colours")
