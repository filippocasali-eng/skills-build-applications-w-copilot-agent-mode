"""Writes every campaign level to assets/levels/<id>.tmj and an index.

    python3 tools/level_gen/build_levels.py
"""
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
sys.path.insert(0, HERE)

from levels import LEVELS  # noqa: E402


def main():
    out = os.path.join(ROOT, "assets", "levels")
    os.makedirs(out, exist_ok=True)
    index = []
    planets = set()
    for make in LEVELS:
        L = make()
        L.save(os.path.join(out, f"{L.id}.tmj"))
        for p in L.planets:
            planets.add((int(round(p.r)), p.style))
        index.append(dict(id=L.id, name=L.name, world=L.world, index=L.index,
                          boss=L.boss, file=f"levels/{L.id}.tmj"))
        print(f"{L.id}: {L.name} ({int(L.width)} px, {len(L.entities)} entities)")
    with open(os.path.join(out, "campaign.json"), "w") as f:
        json.dump(dict(version=1, levels=index), f, indent=1, ensure_ascii=False)
        f.write("\n")
    # Planetoid sizes used by the levels, for the sprite generator.
    with open(os.path.join(HERE, "planets_used.json"), "w") as f:
        json.dump(sorted(planets), f)
        f.write("\n")


if __name__ == "__main__":
    main()
