"""Builds assets/fonts/Orbit5.ttf from the ORBIT-5 pixel glyphs (font.py),
so Flutter UI text uses exactly the same original pixel font as the game.

Each pixel becomes a square contour (100 font units). Lower-case letters map
to the capital glyphs (the font is caps-only by design).
"""
import os

from fontTools.fontBuilder import FontBuilder
from fontTools.pens.ttGlyphPen import TTGlyphPen

import font

PX = 100  # font units per pixel
BASE_ROW = 9  # rows 0..8 sit above the baseline, row 9 is the descender


def _glyph(cell):
    pen = TTGlyphPen(None)
    for y, row in enumerate(cell):
        for x, v in enumerate(row):
            if v != "X":
                continue
            x0, x1 = x * PX, (x + 1) * PX
            y1 = (BASE_ROW - y) * PX
            y0 = y1 - PX
            pen.moveTo((x0, y0))
            pen.lineTo((x0, y1))
            pen.lineTo((x1, y1))
            pen.lineTo((x1, y0))
            pen.closePath()
    return pen.glyph()


def build(out_path):
    chars = font.charset()
    names = {".notdef": None}
    glyphs, metrics, cmap = {}, {}, {}
    empty = TTGlyphPen(None).glyph()
    glyphs[".notdef"] = empty
    metrics[".notdef"] = (600, 0)
    for i, ch in enumerate(chars):
        gname = f"g{i:03d}"
        cell = font.cell(ch)
        glyphs[gname] = _glyph(cell)
        w = len(cell[0])
        metrics[gname] = ((w + 1) * PX, 0)
        cmap[ord(ch)] = gname
        low = ch.lower()
        if low != ch and len(low) == 1:
            cmap[ord(low)] = gname
    fb = FontBuilder(unitsPerEm=1000, isTTF=True)
    order = list(glyphs.keys())
    fb.setupGlyphOrder(order)
    fb.setupCharacterMap(cmap)
    fb.setupGlyf(glyphs)
    fb.setupHorizontalMetrics(metrics)
    fb.setupHorizontalHeader(ascent=900, descent=-100)
    fb.setupNameTable({"familyName": "Orbit5", "styleName": "Regular"})
    fb.setupOS2(sTypoAscender=900, sTypoDescender=-100, usWinAscent=900, usWinDescent=100)
    fb.setupPost()
    fb.save(out_path)
    return len(chars)


if __name__ == "__main__":
    here = os.path.dirname(os.path.abspath(__file__))
    out = os.path.join(here, "..", "..", "assets", "fonts", "Orbit5.ttf")
    print(build(out), "glyphs")
