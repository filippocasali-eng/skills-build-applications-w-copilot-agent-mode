"""Level validator for ORBIT COMMANDO '94 (Tiled .tmj files).

    python3 tools/level_validation/validate.py [assets/levels/*.tmj]

Checks, per level:
  - a player start, and an exit (or a boss for boss stages);
  - at least 2 checkpoints, at least 1 hostage, cassettes 0, 1 and 2;
  - every entity inside the map and not buried in solid terrain;
  - ground enemies standing on something (terrain, platform, planetoid);
  - the exit (or boss arena) is REACHABLE from the start, using a graph of
    standable points connected by what the moveset allows (jump ~88 px up,
    ~130 px across, planet-to-planet hops, zero-g flight, gravity flips,
    vehicles for long gaps).
Exit code 1 if any level fails.
"""
import glob
import json
import math
import os
import sys
from collections import deque

JUMP_UP = 85
JUMP_ACROSS = 130
PLANET_HOP = 155
FLYING = {"rocket", "drone", "jelly", "swarm"}


def props(o):
    out = {}
    for p in o.get("properties", []) or []:
        out[p["name"]] = p["value"]
    return out


def load(path):
    with open(path) as f:
        m = json.load(f)
    lv = dict(path=path, props=props(m), solids=[], platforms=[], planets=[], zones=[],
              entities=[], exit=None,
              width=m["width"] * m["tilewidth"], height=m["height"] * m["tileheight"])
    for layer in m["layers"]:
        name = layer["name"]
        for o in layer.get("objects", []):
            x, y = o["x"], o["y"]
            if name == "terrain" and "polygon" in o:
                lv["solids"].append([(x + p["x"], y + p["y"]) for p in o["polygon"]])
            elif name == "platforms" and "polyline" in o:
                lv["platforms"].append([(x + p["x"], y + p["y"]) for p in o["polyline"]])
            elif name == "planets":
                r = min(o["width"], o["height"]) / 2
                pr = props(o)
                lv["planets"].append(dict(cx=x + r, cy=y + r, r=r,
                                          influence=pr.get("influence", r * 2.2)))
            elif name == "gravity":
                pr = props(o)
                lv["zones"].append(dict(kind=pr.get("kind", o.get("type")), x0=x, y0=y,
                                        x1=x + o["width"], y1=y + o["height"],
                                        gy=pr.get("gy", 1)))
            elif name == "entities":
                t = o.get("type") or o.get("class")
                if t == "exit":
                    lv["exit"] = (x, y, x + o["width"], y + o["height"])
                else:
                    lv["entities"].append(dict(type=t, x=x, y=y, props=props(o)))
    return lv


def point_in_poly(x, y, poly):
    inside = False
    n = len(poly)
    for i in range(n):
        x1, y1 = poly[i]
        x2, y2 = poly[(i + 1) % n]
        if (y1 > y) != (y2 > y):
            xi = x1 + (y - y1) * (x2 - x1) / (y2 - y1)
            if x < xi:
                inside = not inside
    return inside


def buried(lv, x, y):
    if any(point_in_poly(x, y, p) for p in lv["solids"]):
        return True
    return any(math.hypot(x - p["cx"], y - p["cy"]) < p["r"] - 2 for p in lv["planets"])


def in_zone(lv, x, y, kind, gy=None):
    for z in lv["zones"]:
        if z["kind"] == kind and z["x0"] <= x <= z["x1"] and z["y0"] <= y <= z["y1"]:
            if gy is None or z.get("gy") == gy:
                return True
    return False


def nodes(lv):
    """Standable points: (x, y, kind, ref)."""
    out = []

    def sample(a, b, kind):
        (x1, y1), (x2, y2) = a, b
        L = math.hypot(x2 - x1, y2 - y1)
        n = max(1, int(L // 24))
        for i in range(n + 1):
            t = i / n
            out.append((x1 + (x2 - x1) * t, y1 + (y2 - y1) * t, kind, None))

    for poly in lv["solids"]:
        area = sum(poly[i][0] * poly[(i + 1) % len(poly)][1] -
                   poly[(i + 1) % len(poly)][0] * poly[i][1] for i in range(len(poly)))
        pts = poly if area >= 0 else list(reversed(poly))
        for i in range(len(pts)):
            a, b = pts[i], pts[(i + 1) % len(pts)]
            dx, dy = b[0] - a[0], b[1] - a[1]
            L = math.hypot(dx, dy) or 1
            nx, ny = dy / L, -dx / L  # free side
            mx, my = (a[0] + b[0]) / 2, (a[1] + b[1]) / 2
            if ny < -0.6:
                sample(a, b, "ground")
            elif ny > 0.6 and (in_zone(lv, mx, my + 20, "uniform", -1.0)):
                sample(a, b, "ceiling")
    for line in lv["platforms"]:
        for i in range(len(line) - 1):
            sample(line[i], line[i + 1], "ground")
    for pi, p in enumerate(lv["planets"]):
        for k in range(0, 360, 15):
            a = math.radians(k)
            out.append((p["cx"] + math.sin(a) * p["r"], p["cy"] - math.cos(a) * p["r"],
                        "planet", pi))
    return out


def reachable(lv, start, goal_test, vehicles):
    ns = nodes(lv)
    if not ns:
        return False
    across = 230 if vehicles else JUMP_ACROSS
    # Bucket by x for speed.
    buckets = {}
    for i, n in enumerate(ns):
        buckets.setdefault(int(n[0] // 256), []).append(i)

    def near(i):
        x = ns[i][0]
        for b in range(int(x // 256) - 2, int(x // 256) + 3):
            for j in buckets.get(b, []):
                yield j

    def can(a, b):
        ax, ay, ak, ar = a
        bx, by, bk, br = b
        d = math.hypot(bx - ax, by - ay)
        if d > 500:
            return False
        if in_zone(lv, ax, ay - 30, "zero") or in_zone(lv, bx, by - 30, "zero"):
            return d <= 450  # jetpack / shuttle
        if ak == "planet" and bk == "planet":
            return ar == br and d <= 60 or d <= PLANET_HOP
        if ak == "planet" or bk == "planet":
            # Ground -> planet: jump into its field. Planet -> ground: fall.
            if ak == "planet":
                return by > ay - 20 and abs(bx - ax) <= 260
            return d <= 175
        if ak == "ceiling" or bk == "ceiling":
            # Gravity flip zone: fall up / down between floor and ceiling.
            return abs(bx - ax) <= 60
        dx = abs(bx - ax)
        rise = ay - by
        if rise > JUMP_UP:
            return False
        drop = max(0.0, -rise)
        return dx <= across + drop * 0.6

    sx, sy = start
    first = min(range(len(ns)), key=lambda i: math.hypot(ns[i][0] - sx, ns[i][1] - sy))
    seen = {first}
    q = deque([first])
    while q:
        i = q.popleft()
        if goal_test(ns[i][0], ns[i][1]):
            return True
        for j in near(i):
            if j not in seen and can(ns[i], ns[j]):
                seen.add(j)
                q.append(j)
    return False


def validate(path):
    lv = load(path)
    errs = []
    ents = lv["entities"]
    p = lv["props"]
    boss = p.get("boss", False)
    start = [e for e in ents if e["type"] == "player"]
    if not start:
        errs.append("no player start")
    if boss:
        if not [e for e in ents if e["type"] == "boss"]:
            errs.append("boss stage without a boss")
    else:
        if not lv["exit"]:
            errs.append("no exit")
        if len([e for e in ents if e["type"] == "checkpoint"]) < 2:
            errs.append("fewer than 2 checkpoints")
        if not [e for e in ents if e["type"] == "hostage"]:
            errs.append("no hostages")
        idx = sorted(e["props"].get("index") for e in ents if e["type"] == "cassette")
        if idx != [0, 1, 2]:
            errs.append(f"cassettes must be 0,1,2 (got {idx})")

    for e in ents:
        x, y = e["x"], e["y"]
        if not (-50 <= x <= lv["width"] + 50 and -400 <= y <= lv["height"] + 50):
            errs.append(f"{e['type']} at {x:.0f},{y:.0f} outside the map")
        # Probe a few pixels along the local "up" (planet normal, flipped
        # gravity on ceilings, otherwise screen up).
        ox, oy = 0.0, -6.0
        for pl in lv["planets"]:
            d = math.hypot(x - pl["cx"], y - pl["cy"])
            if abs(d - pl["r"]) < 4 and d > 0:
                ox, oy = (x - pl["cx"]) / d * 6, (y - pl["cy"]) / d * 6
                break
        else:
            if in_zone(lv, x, y + 6, "uniform", -1.0):
                ox, oy = 0.0, 6.0
        if buried(lv, x + ox, y + oy):
            errs.append(f"{e['type']} at {x:.0f},{y:.0f} is inside terrain")
        if e["type"] == "enemy" and e["props"].get("kind") not in FLYING:
            standing = any(abs(y - n[1]) < 30 and abs(x - n[0]) < 30 for n in nodes(lv))
            if not standing:
                errs.append(f"enemy {e['props'].get('kind')} at {x:.0f},{y:.0f} floats")

    if start:
        s = (start[0]["x"], start[0]["y"])
        vehicles = any(e["type"] == "vehicle" for e in ents)
        if boss:
            b = [e for e in ents if e["type"] == "boss"][0]
            w = b["props"].get("arenaW", 600)

            def goal(x, y):
                return abs(x - b["x"]) < w / 2 and abs(y - b["y"]) < 40
        elif lv["exit"]:
            x0, y0, x1, y1 = lv["exit"]

            def goal(x, y):
                return x0 - 10 <= x <= x1 + 10 and y0 - 10 <= y <= y1 + 10
        else:
            goal = None
        if goal and not reachable(lv, s, goal, vehicles):
            errs.append("exit not reachable from the start")
    return lv, errs


def main(paths):
    paths = paths or sorted(glob.glob(os.path.join(
        os.path.dirname(__file__), "..", "..", "assets", "levels", "*.tmj")))
    failed = 0
    for path in paths:
        lv, errs = validate(path)
        name = os.path.basename(path)
        if errs:
            failed += 1
            print(f"FAIL {name}")
            for e in errs:
                print(f"     - {e}")
        else:
            n = len(lv["entities"])
            print(f"ok   {name} ({n} entities, {len(lv['planets'])} planetoids)")
    print(f"{len(paths) - failed}/{len(paths)} levels valid")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
