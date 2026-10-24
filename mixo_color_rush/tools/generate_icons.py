#!/usr/bin/env python3
"""Draws the MIXO launcher icon (legacy + adaptive foreground) and the
web icons with Pillow. Everything is generated: no third-party artwork.

Usage: python3 tools/generate_icons.py
"""
import os

from PIL import Image, ImageDraw

ROOT = os.path.join(os.path.dirname(__file__), '..')
RES = os.path.join(ROOT, 'android', 'app', 'src', 'main', 'res')
SS = 4  # supersampling


def mixo(size, background=True, scale=1.0):
    s = size * SS
    img = Image.new('RGBA', (s, s), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    if background:
        for y in range(s):
            t = y / s
            c = (int(18 + (106 - 18) * t), int(10 + (43 - 10) * t), int(51 + (176 - 51) * t), 255)
            d.line([(0, y), (s, y)], fill=c)
    cx, cy = s / 2, s / 2 + s * 0.04 * scale
    w, h = s * 0.62 * scale, s * 0.56 * scale
    # Body: red jelly blob.
    d.rounded_rectangle([cx - w / 2, cy - h / 2, cx + w / 2, cy + h / 2], radius=w * 0.42, fill=(255, 59, 71, 255),
                        outline=(40, 10, 40, 160), width=int(s * 0.012 * scale))
    d.ellipse([cx - w * 0.33, cy - h * 0.38, cx - w * 0.1, cy - h * 0.25], fill=(255, 255, 255, 110))
    # Eyes.
    for side in (-1, 1):
        ex, ey, er = cx + side * w * 0.19, cy - h * 0.06, w * 0.12
        d.ellipse([ex - er, ey - er, ex + er, ey + er], fill='white')
        pr = er * 0.55
        d.ellipse([ex - pr, ey - pr + er * 0.1, ex + pr, ey + pr + er * 0.1], fill=(27, 16, 53, 255))
        hr = er * 0.2
        d.ellipse([ex - er * 0.3 - hr, ey - er * 0.35 - hr, ex - er * 0.3 + hr, ey - er * 0.35 + hr], fill='white')
    # Smile.
    d.arc([cx - w * 0.14, cy + h * 0.02, cx + w * 0.14, cy + h * 0.24], 20, 160, fill=(27, 16, 53, 255),
          width=int(s * 0.018 * scale))
    # Colour drops around (yellow triangle, blue square).
    d.polygon([(s * 0.8, s * 0.16), (s * 0.88, s * 0.3), (s * 0.72, s * 0.3)], fill=(255, 210, 31, 255))
    d.rectangle([s * 0.12, s * 0.7, s * 0.24, s * 0.82], fill=(47, 123, 255, 255))
    return img.resize((size, size), Image.LANCZOS)


def main():
    legacy = {'mdpi': 48, 'hdpi': 72, 'xhdpi': 96, 'xxhdpi': 144, 'xxxhdpi': 192}
    for name, px in legacy.items():
        out = os.path.join(RES, f'mipmap-{name}')
        os.makedirs(out, exist_ok=True)
        mixo(px).save(os.path.join(out, 'ic_launcher.png'))
        # Adaptive foreground: 108dp canvas, art inside the 66dp safe zone.
        fg = mixo(int(px * 108 / 48), background=False, scale=0.62)
        fg.save(os.path.join(out, 'ic_launcher_foreground.png'))
    v26 = os.path.join(RES, 'mipmap-anydpi-v26')
    os.makedirs(v26, exist_ok=True)
    with open(os.path.join(v26, 'ic_launcher.xml'), 'w') as f:
        f.write('<?xml version="1.0" encoding="utf-8"?>\n'
                '<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">\n'
                '    <background android:drawable="@color/ic_launcher_background"/>\n'
                '    <foreground android:drawable="@mipmap/ic_launcher_foreground"/>\n'
                '</adaptive-icon>\n')
    with open(os.path.join(RES, 'values', 'ic_launcher_background.xml'), 'w') as f:
        f.write('<?xml version="1.0" encoding="utf-8"?>\n<resources>\n'
                '    <color name="ic_launcher_background">#3B1C7A</color>\n</resources>\n')
    web = os.path.join(ROOT, 'web')
    if os.path.isdir(web):
        mixo(32).save(os.path.join(web, 'favicon.png'))
        for px in (192, 512):
            mixo(px).save(os.path.join(web, 'icons', f'Icon-{px}.png'))
            mixo(px, scale=0.8).save(os.path.join(web, 'icons', f'Icon-maskable-{px}.png'))
    # Play Store hi-res icon (512x512) for the listing.
    store = os.path.join(ROOT, 'store')
    os.makedirs(store, exist_ok=True)
    mixo(512).save(os.path.join(store, 'icon_512.png'))
    print('icons written')


if __name__ == '__main__':
    main()
