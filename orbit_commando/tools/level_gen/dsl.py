"""A tiny level-building language that writes Tiled JSON maps (.tmj).

Levels are authored as Python code (see levels.py) and saved in the Tiled
format, so they can be opened, inspected and hand-edited in the Tiled editor
(https://www.mapeditor.org). The game reads the same files.

Coordinates are world pixels, y grows downwards. The "cursor" walks from
left to right; terrain pieces extend the current ground strip so joints
between pieces never create seams (ghost collisions).

Movement limits the layouts must respect (balance.json defaults):
  jump apex ~88 px, jump length ~110 px running, step-ups <= 70 px,
  gaps <= 90 px, planetoid surfaces <= 140 px apart.

Planetoid gravity reaches `influence` = radius + 80 px by default: a jump
(88 px) can always escape it. A planetoid hovering `radius + 130` px above
the ground can be reached with a jump but doesn't pull people walking below.
"""
HOVER = 130  # see above
import json
import math

TILE = 16


class Planet:
    def __init__(self, cx, cy, r, influence, style, strength=1.0):
        self.cx, self.cy, self.r = cx, cy, r
        self.influence, self.style, self.strength = influence, style, strength

    def surface(self, angle_deg, lift=0.0):
        """Point on the surface. 0 deg = top, 90 = right, 180 = bottom."""
        a = math.radians(angle_deg)
        return (self.cx + math.sin(a) * (self.r + lift), self.cy - math.cos(a) * (self.r + lift))


class Level:
    def __init__(self, id, name, world, index, theme, *, gravity="uniform",
                 music="", par=240, target=20000, boss=False, height=1200, base=900):
        self.id, self.name, self.world, self.index = id, name, world, index
        self.theme, self.gravity, self.music = theme, gravity, music
        self.par, self.target, self.boss = par, target, boss
        self.height, self.base = height, base
        self.solids, self.platforms, self.planets = [], [], []
        self.zones, self.entities = [], []
        self.exit = None
        self.x = 0.0
        self.gy = float(base)
        self._strip = []  # top points of the current ground strip

    # ------------------------------------------------------------ terrain --
    def _flush(self):
        if len(self._strip) >= 2:
            top = self._strip
            poly = list(top) + [(top[-1][0], self.height), (top[0][0], self.height)]
            self.solids.append(poly)
        self._strip = []

    def _add_top(self, x, y):
        if self._strip and self._strip[-1] == (x, y):
            return
        self._strip.append((x, y))

    def ground(self, length, rise=0):
        """Flat (or sloped when rise != 0) ground from the cursor."""
        self._add_top(self.x, self.gy)
        self.x += length
        self.gy -= rise
        self._add_top(self.x, self.gy)
        return self

    def step(self, up):
        """A vertical step: positive = up (keep <= 70 to be jumpable)."""
        self._add_top(self.x, self.gy)
        self.gy -= up
        self._add_top(self.x, self.gy)
        return self

    def gap(self, length):
        """A pit (falling in is deadly). Keep <= 90 px."""
        self._flush()
        self.x += length
        return self

    def solid(self, pts):
        self.solids.append([(float(x), float(y)) for x, y in pts])

    def block(self, dx, h, w, thick=24):
        """Solid floating block, top `h` px above the ground at the cursor."""
        x0, y0 = self.x + dx, self.gy - h
        self.solid([(x0, y0), (x0 + w, y0), (x0 + w, y0 + thick), (x0, y0 + thick)])
        return (x0, y0)

    def ceiling(self, length, clearance, thick=160):
        """Solid ceiling above the ground (station corridors)."""
        y1 = self.gy - clearance
        self.solid([(self.x, y1 - thick), (self.x + length, y1 - thick),
                    (self.x + length, y1), (self.x, y1)])

    def plat(self, dx, h, w):
        """One-way platform, `h` px above the ground at the cursor."""
        y = self.gy - h
        self.platforms.append([(self.x + dx, y), (self.x + dx + w, y)])
        return (self.x + dx, y)

    def planet(self, dx, above, r, style=0, influence=None):
        """Planetoid whose centre is `dx` ahead and `above` px over ground."""
        p = Planet(self.x + dx, self.gy - above, r, influence or r + 80, style)
        self.planets.append(p)
        return p

    def planet_at(self, cx, cy, r, style=0, influence=None):
        p = Planet(cx, cy, r, influence or r + 80, style)
        self.planets.append(p)
        return p

    def zone(self, kind, x0, y0, x1, y1, gx=0.0, gy=1.0):
        self.zones.append(dict(kind=kind, x0=x0, y0=y0, x1=x1, y1=y1, gx=gx, gy=gy))

    # ----------------------------------------------------------- entities --
    def ent(self, type, x, y, **props):
        self.entities.append(dict(type=type, x=float(x), y=float(y), props=props))

    def here(self, type, dx=0, h=0, **props):
        """Entity standing on the ground (or `h` px above) at cursor+dx."""
        self.ent(type, self.x + dx, self.gy - h, **props)

    def enemy(self, kind, dx=0, h=0, **props):
        self.here("enemy", dx, h, kind=kind, **props)

    def on_planet(self, planet, angle, type, lift=0, **props):
        x, y = planet.surface(angle, lift)
        self.ent(type, x, y, **props)

    def start(self, dx=60):
        self.here("player", dx)

    def checkpoint(self, dx=0):
        self.here("checkpoint", dx)

    def finish(self, dx=-60):
        x = self.x + dx
        self.exit = (x - 40, self.gy - 140, x + 40, self.gy)
        self.ground(240)
        self.step(260)  # back wall
        self.ground(40)
        self._flush()

    def close(self):
        self._flush()
        self.width = max(
            [self.x + 200]
            + [p.cx + p.r + 200 for p in self.planets]
            + [e["x"] + 200 for e in self.entities]
        )

    # -------------------------------------------------------------- output --
    def to_tiled(self):
        self.close()
        oid = [0]

        def nid():
            oid[0] += 1
            return oid[0]

        def obj(**kw):
            base = dict(id=nid(), name="", type="", rotation=0, visible=True,
                        x=0, y=0, width=0, height=0)
            base.update(kw)
            return base

        def props(d):
            out = []
            for k, v in d.items():
                t = "bool" if isinstance(v, bool) else "int" if isinstance(v, int) else \
                    "float" if isinstance(v, float) else "string"
                out.append(dict(name=k, type=t, value=v))
            return out

        def poly_obj(pts, key):
            x0, y0 = pts[0]
            return obj(x=round(x0, 2), y=round(y0, 2),
                       **{key: [dict(x=round(x - x0, 2), y=round(y - y0, 2)) for x, y in pts]})

        layers = []

        def layer(name, objects):
            layers.append(dict(id=len(layers) + 1, name=name, type="objectgroup",
                               draworder="topdown", opacity=1, visible=True, x=0, y=0,
                               objects=objects))

        layer("terrain", [poly_obj(p, "polygon") for p in self.solids])
        layer("platforms", [poly_obj(p, "polyline") for p in self.platforms])
        layer("planets", [obj(x=p.cx - p.r, y=p.cy - p.r, width=2 * p.r, height=2 * p.r,
                              ellipse=True,
                              properties=props(dict(influence=float(p.influence),
                                                    style=int(p.style),
                                                    strength=float(p.strength))))
                          for p in self.planets])
        layer("gravity", [obj(x=z["x0"], y=z["y0"], width=z["x1"] - z["x0"],
                              height=z["y1"] - z["y0"], type=z["kind"],
                              properties=props(dict(kind=z["kind"], gx=float(z["gx"]),
                                                    gy=float(z["gy"]))))
                          for z in self.zones])
        ents = [obj(x=round(e["x"], 2), y=round(e["y"], 2), point=True, type=e["type"],
                    properties=props(e["props"])) for e in self.entities]
        if self.exit:
            x0, y0, x1, y1 = self.exit
            ents.append(obj(x=x0, y=y0, width=x1 - x0, height=y1 - y0, type="exit"))
        layer("entities", ents)

        return dict(
            type="map", version="1.10", tiledversion="1.11.0",
            orientation="orthogonal", renderorder="right-down", infinite=False,
            width=int(math.ceil(self.width / TILE)), height=int(math.ceil(self.height / TILE)),
            tilewidth=TILE, tileheight=TILE, nextlayerid=len(layers) + 1,
            nextobjectid=oid[0] + 1, tilesets=[], layers=layers,
            properties=props(dict(id=self.id, name=self.name, world=self.world,
                                  index=self.index, theme=self.theme,
                                  gravity=self.gravity, music=self.music,
                                  parTime=self.par, targetScore=self.target,
                                  boss=self.boss)),
        )

    def save(self, path):
        with open(path, "w") as f:
            json.dump(self.to_tiled(), f, separators=(",", ":"))
            f.write("\n")
