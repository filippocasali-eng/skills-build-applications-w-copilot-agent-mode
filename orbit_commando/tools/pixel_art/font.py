"""Original 5x7 pixel font "ORBIT-5".

Cell: 10 rows high. Rows 0-1 hold accents, rows 2-8 the glyph body
(cap height 7), row 9 a descender. Each glyph is a list of 7 strings
(body rows), optionally with accent rows. 'X' = ink, '.' = empty.
Glyph width is the length of its rows; 1 px of spacing is added at render.
"""

CELL_H = 10
BODY_TOP = 2

G = {}


def glyph(ch, *rows):
    rows = list(rows)
    assert len(rows) == 7, ch
    w = len(rows[0])
    assert all(len(r) == w for r in rows), ch
    G[ch] = rows


glyph("A", ".XXX.", "X...X", "X...X", "XXXXX", "X...X", "X...X", "X...X")
glyph("B", "XXXX.", "X...X", "X...X", "XXXX.", "X...X", "X...X", "XXXX.")
glyph("C", ".XXXX", "X....", "X....", "X....", "X....", "X....", ".XXXX")
glyph("D", "XXXX.", "X...X", "X...X", "X...X", "X...X", "X...X", "XXXX.")
glyph("E", "XXXXX", "X....", "X....", "XXXX.", "X....", "X....", "XXXXX")
glyph("F", "XXXXX", "X....", "X....", "XXXX.", "X....", "X....", "X....")
glyph("G", ".XXXX", "X....", "X....", "X..XX", "X...X", "X...X", ".XXXX")
glyph("H", "X...X", "X...X", "X...X", "XXXXX", "X...X", "X...X", "X...X")
glyph("I", "XXX", ".X.", ".X.", ".X.", ".X.", ".X.", "XXX")
glyph("J", "....X", "....X", "....X", "....X", "X...X", "X...X", ".XXX.")
glyph("K", "X...X", "X..X.", "X.X..", "XX...", "X.X..", "X..X.", "X...X")
glyph("L", "X....", "X....", "X....", "X....", "X....", "X....", "XXXXX")
glyph("M", "X...X", "XX.XX", "X.X.X", "X.X.X", "X...X", "X...X", "X...X")
glyph("N", "X...X", "XX..X", "X.X.X", "X..XX", "X...X", "X...X", "X...X")
glyph("O", ".XXX.", "X...X", "X...X", "X...X", "X...X", "X...X", ".XXX.")
glyph("P", "XXXX.", "X...X", "X...X", "XXXX.", "X....", "X....", "X....")
glyph("Q", ".XXX.", "X...X", "X...X", "X...X", "X.X.X", "X..X.", ".XX.X")
glyph("R", "XXXX.", "X...X", "X...X", "XXXX.", "X.X..", "X..X.", "X...X")
glyph("S", ".XXXX", "X....", "X....", ".XXX.", "....X", "....X", "XXXX.")
glyph("T", "XXXXX", "..X..", "..X..", "..X..", "..X..", "..X..", "..X..")
glyph("U", "X...X", "X...X", "X...X", "X...X", "X...X", "X...X", ".XXX.")
glyph("V", "X...X", "X...X", "X...X", "X...X", "X...X", ".X.X.", "..X..")
glyph("W", "X...X", "X...X", "X...X", "X.X.X", "X.X.X", "XX.XX", "X...X")
glyph("X", "X...X", "X...X", ".X.X.", "..X..", ".X.X.", "X...X", "X...X")
glyph("Y", "X...X", "X...X", ".X.X.", "..X..", "..X..", "..X..", "..X..")
glyph("Z", "XXXXX", "....X", "...X.", "..X..", ".X...", "X....", "XXXXX")

glyph("0", ".XXX.", "X...X", "X..XX", "X.X.X", "XX..X", "X...X", ".XXX.")
glyph("1", "..X..", ".XX..", "..X..", "..X..", "..X..", "..X..", ".XXX.")
glyph("2", ".XXX.", "X...X", "....X", "...X.", "..X..", ".X...", "XXXXX")
glyph("3", "XXXX.", "....X", "....X", ".XXX.", "....X", "....X", "XXXX.")
glyph("4", "...X.", "..XX.", ".X.X.", "X..X.", "XXXXX", "...X.", "...X.")
glyph("5", "XXXXX", "X....", "XXXX.", "....X", "....X", "X...X", ".XXX.")
glyph("6", ".XXX.", "X....", "X....", "XXXX.", "X...X", "X...X", ".XXX.")
glyph("7", "XXXXX", "....X", "...X.", "..X..", "..X..", "..X..", "..X..")
glyph("8", ".XXX.", "X...X", "X...X", ".XXX.", "X...X", "X...X", ".XXX.")
glyph("9", ".XXX.", "X...X", "X...X", ".XXXX", "....X", "....X", ".XXX.")

glyph(" ", "...", "...", "...", "...", "...", "...", "...")
glyph("!", "X", "X", "X", "X", "X", ".", "X")
glyph(".", ".", ".", ".", ".", ".", ".", "X")
glyph(",", "..", "..", "..", "..", "..", ".X", "X.")
glyph(":", ".", ".", "X", ".", ".", "X", ".")
glyph(";", "..", "..", ".X", "..", "..", ".X", "X.")
glyph("'", "X", "X", ".", ".", ".", ".", ".")
glyph('"', "X.X", "X.X", "...", "...", "...", "...", "...")
glyph("-", "....", "....", "....", "XXXX", "....", "....", "....")
glyph("+", ".....", "..X..", "..X..", "XXXXX", "..X..", "..X..", ".....")
glyph("/", "....X", "....X", "...X.", "..X..", ".X...", "X....", "X....")
glyph("?", ".XXX.", "X...X", "....X", "...X.", "..X..", ".....", "..X..")
glyph("(", ".X", "X.", "X.", "X.", "X.", "X.", ".X")
glyph(")", "X.", ".X", ".X", ".X", ".X", ".X", "X.")
glyph("%", "XX..X", "XX..X", "...X.", "..X..", ".X...", "X..XX", "X..XX")
glyph("*", ".....", "X.X.X", ".XXX.", "XXXXX", ".XXX.", "X.X.X", ".....")
glyph("×", ".....", "X...X", ".X.X.", "..X..", ".X.X.", "X...X", ".....")
glyph("#", ".X.X.", "XXXXX", ".X.X.", ".X.X.", ".X.X.", "XXXXX", ".X.X.")
glyph("=", "....", "....", "XXXX", "....", "XXXX", "....", "....")
glyph("<", "...X", "..X.", ".X..", "X...", ".X..", "..X.", "...X")
glyph(">", "X...", ".X..", "..X.", "...X", "..X.", ".X..", "X...")
glyph("_", ".....", ".....", ".....", ".....", ".....", ".....", "XXXXX")
glyph("&", ".XX..", "X..X.", "X.X..", ".X...", "X.X.X", "X..X.", ".XX.X")
glyph("€", "..XXX", ".X...", "XXXX.", ".X...", "XXXX.", ".X...", "..XXX")
glyph("♥", ".....", ".X.X.", "XXXXX", "XXXXX", ".XXX.", "..X..", ".....")
glyph("•", "...", "...", ".X.", "XXX", ".X.", "...", "...")
# Extra letters and punctuation for FR / DE / ES / PT / TR.
glyph("Œ", ".XXXXX", "X..X..", "X..X..", "X..XXX", "X..X..", "X..X..", ".XXXXX")
glyph("ß", ".XX..", "X..X.", "X..X.", "X.X..", "X..X.", "X..X.", "X.XX.")
glyph("¿", "..X..", ".....", "..X..", ".X...", "X....", "X...X", ".XXX.")
glyph("¡", "X", ".", "X", "X", "X", "X", "X")
glyph("«", ".....", ".....", "..X.X", ".X.X.", "X.X..", ".X.X.", "..X.X")
glyph("»", ".....", ".....", "X.X..", ".X.X.", "..X.X", ".X.X.", "X.X..")
glyph('"', "X.X", "X.X", "...", "...", "...", "...", "...")

# Accented capitals (IT first; ready for ES/DE/FR/PT).
ACCENTS = {
    "grave": [".X...", "..X.."],
    "acute": ["...X.", "..X.."],
    "umlaut": [".....", ".X.X."],
    "tilde": [".XX.X", "X..X."],
    "circ": ["..X..", ".X.X."],
    "breve": [".X.X.", "..X.."],
    "dot": [".....", "..X.."],
}

# Marks drawn in the descender row, under the glyph (cedilla).
BELOW = {"cedilla": "..X.."}
ACCENTED = {
    "À": ("A", "grave"), "Á": ("A", "acute"), "Â": ("A", "circ"), "Ä": ("A", "umlaut"), "Ã": ("A", "tilde"),
    "È": ("E", "grave"), "É": ("E", "acute"), "Ê": ("E", "circ"),
    "Ì": ("I", "grave"), "Í": ("I", "acute"),
    "Ò": ("O", "grave"), "Ó": ("O", "acute"), "Ô": ("O", "circ"), "Ö": ("O", "umlaut"), "Õ": ("O", "tilde"),
    "Ù": ("U", "grave"), "Ú": ("U", "acute"), "Ü": ("U", "umlaut"),
    "Ñ": ("N", "tilde"),
    "Ë": ("E", "umlaut"), "Ï": ("I", "umlaut"), "Î": ("I", "circ"),
    "Û": ("U", "circ"), "Ÿ": ("Y", "umlaut"),
    "Ğ": ("G", "breve"), "İ": ("I", "dot"),
    "Ç": ("C", "cedilla"), "Ş": ("S", "cedilla"),
}


def cell(ch):
    """Return the full 10-row cell for a glyph."""
    if ch in ACCENTED:
        base, acc = ACCENTED[ch]
        body = G[base]
        w = len(body[0])
        if acc in BELOW:
            mark = BELOW[acc]
            under = mark[:w].center(w, ".") if len(mark) > w else mark.center(w, ".")
            return ["." * w] * BODY_TOP + body + [under]
        accent = [r[:w].center(w, ".") if len(r) > w else r.center(w, ".") for r in ACCENTS[acc]]
        if w == 3:  # narrow I
            accent = [r[1:4] for r in ACCENTS[acc]]
        return accent + body + ["." * w]
    body = G[ch]
    w = len(body[0])
    return ["." * w] * BODY_TOP + body + ["." * w]


def charset():
    return list(G.keys()) + list(ACCENTED.keys())
