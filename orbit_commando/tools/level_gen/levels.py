"""The 15 campaign levels of ORBIT COMMANDO '94, written with dsl.py.

Run `python3 tools/level_gen/build_levels.py` to regenerate the .tmj files.
World 1: Asteroid Belt "Quiet"   (classic gravity, first planetoids)
World 2: Orbital Station Pizza-Station (gravity flips, zero-g, rocket bike)
World 3: Planet Glorbo Prime      (planetoid clusters, shuttle, mech)
"""
from dsl import HOVER, Level

# --------------------------------------------------------------- sections ---


def fight(L, length, enemies, *, slope=0):
    """Flat stretch with enemies spread along it. enemies: [(kind, dx)]."""
    x0 = L.x
    L.ground(length, rise=slope)
    for kind, dx in enemies:
        L.ent("enemy", x0 + dx, L.gy + slope * (1 - dx / length) if slope else L.gy, kind=kind)


def steps(L, ups, width=140):
    for u in ups:
        L.ground(width)
        L.step(u)


def hop_chain(L, radii, *, style=0, gap=110, enemies=(), hostage=None, cassette=None,
              pickup=None, ground_below=True, lead=180):
    """Chain of planetoids above the ground. The first is jump-reachable."""
    planets = []
    x = lead
    prev_r = None
    for r in radii:
        if prev_r is not None:
            x += prev_r + gap + r
        p = L.planet(x, r + HOVER, r, style=style)
        planets.append(p)
        prev_r = r
    span = x + radii[-1] + 200
    if ground_below:
        L.ground(span)
    else:
        L.ground(lead - 40)
        L.gap(span - (lead - 40) * 2)
        L.ground(lead - 40)
    for i, (kind, angle) in enumerate(enemies):
        p = planets[i % len(planets)]
        L.on_planet(p, angle, "enemy", kind=kind)
    if hostage is not None:
        i, a, reward = hostage
        L.on_planet(planets[i], a, "hostage", reward=reward)
    if cassette is not None:
        i, a, idx = cassette
        L.on_planet(planets[i], a, "cassette", index=idx)
    if pickup is not None:
        i, a, item = pickup
        L.on_planet(planets[i], a, "pickup", item=item)
    return planets


def corridor(L, length, clearance=230, flip=None, enemies=(), ceiling_enemies=()):
    """Station corridor. flip=(dx0, dx1) makes gravity point up there."""
    x0 = L.x
    L.ceiling(length, clearance)
    L.ground(length)
    if flip:
        a, b = flip
        L.zone("uniform", x0 + a, L.gy - clearance - 10, x0 + b, L.gy + 10, gx=0.0, gy=-1.0)
    for kind, dx in enemies:
        L.ent("enemy", x0 + dx, L.gy, kind=kind)
    for kind, dx in ceiling_enemies:
        # Enemies standing upside-down on the ceiling (inside a flip zone).
        L.ent("enemy", x0 + dx, L.gy - clearance, kind=kind)


def zero_g(L, length, height=420, blocks=(), enemies=()):
    """Zero-gravity hall with floor and ceiling; jetpack time."""
    x0 = L.x
    L.ceiling(length, height)
    L.ground(length)
    L.zone("zero", x0 + 40, L.gy - height, x0 + length - 40, L.gy)
    for dx, h, w in blocks:
        L.block(dx - length, h, w, thick=w if w < 80 else 40)
    for kind, dx, h in enemies:
        L.ent("enemy", x0 + dx, L.gy - h, kind=kind)


# ----------------------------------------------------------------- world 1 --


def w1_l1():
    L = Level("w1_l1", "Cintura Tranquilla", 1, 1, "asteroids", music="world1",
              par=180, target=18000)
    L.ground(40)
    L.start(80)
    L.here("hint", 160, icon="move")
    L.ground(420)
    L.here("hint", -140, icon="jump")
    L.step(50)
    L.ground(200)
    L.here("hint", 60, icon="fire")
    fight(L, 520, [("grunt", 300), ("grunt", 460)])
    L.here("pickup", -120, item="S")
    L.gap(70)
    L.here("hint", -30, icon="jump")
    L.ground(300)
    L.plat(60, 70, 140)
    L.here("cassette", 130, h=110, index=0)
    L.checkpoint(-150)
    fight(L, 600, [("grunt", 200), ("clerk", 380), ("grunt", 540)])
    L.here("hostage", -80, reward="grenade")
    L.here("hint", -260, icon="grenade")
    steps(L, [40, -40], 180)
    L.here("hint", 0, icon="aim_up")
    fight(L, 420, [("drone", 200), ("drone", 360)])
    L.checkpoint(-200)
    # First planetoid: optional detour with a cassette on top.
    hop_chain(L, [70], style=0, enemies=[("turret", 140)],
              cassette=(0, 0, 1), lead=220)
    fight(L, 500, [("grunt", 120), ("roller", 300), ("grunt", 460)])
    L.here("hostage", -60, reward="H")
    L.gap(80)
    fight(L, 400, [("clerk", 200), ("grunt", 350)])
    L.checkpoint(-300)
    L.plat(80, 60, 120)
    L.plat(260, 120, 120)
    L.here("cassette", 320, h=160, index=2)
    fight(L, 520, [("grunt", 180), ("clerk", 300), ("grunt", 480)])
    L.finish()
    return L


def w1_l2():
    L = Level("w1_l2", "Campo di Sassi", 1, 2, "asteroids", music="world1",
              par=220, target=24000)
    L.ground(40)
    L.start(80)
    fight(L, 500, [("grunt", 300), ("drone", 420)])
    steps(L, [50, 50], 160)
    fight(L, 400, [("clerk", 200), ("grunt", 360)])
    L.here("pickup", 0, item="R")
    L.gap(80)
    L.ground(160)
    L.checkpoint(60)
    hop_chain(L, [80, 60, 90], style=0, gap=120,
              enemies=[("turret", 60), ("grunt", 0), ("turret", 300)],
              hostage=(1, 180, "S"), cassette=(2, 90, 0))
    fight(L, 450, [("roller", 200), ("roller", 300), ("grunt", 420)])
    steps(L, [-60], 120)
    fight(L, 500, [("cyclops", 380), ("drone", 200)])
    L.checkpoint(-420)
    L.plat(60, 70, 160)
    L.plat(300, 70, 160)
    L.here("cassette", 380, h=110, index=1)
    fight(L, 520, [("grunt", 160), ("clerk", 320), ("grunt", 480)])
    L.gap(80)
    fight(L, 400, [("bulwark", 300)])
    L.here("hostage", -40, reward="grenade")
    L.checkpoint(-300)
    hop_chain(L, [70, 70], style=1, gap=110, enemies=[("sniper", 180), ("grunt", 0)],
              cassette=(1, 270, 2))
    fight(L, 480, [("grunt", 200), ("drone", 320), ("grunt", 440)])
    L.here("hostage", -100, reward="P")
    L.finish()
    return L


def w1_l3():
    L = Level("w1_l3", "Il Mech a Molla", 1, 3, "asteroids", music="world1",
              par=240, target=30000)
    L.ground(40)
    L.start(80)
    L.here("hint", 220, icon="dash")
    fight(L, 520, [("grunt", 360), ("roller", 460)])
    L.here("vehicle", -120, kind="mech")
    fight(L, 700, [("grunt", 200), ("grunt", 300), ("minimech", 520), ("clerk", 640)])
    steps(L, [60, 60], 200)
    fight(L, 500, [("cyclops", 300), ("drone", 420)])
    L.checkpoint(-460)
    L.here("hostage", -60, reward="F")
    hop_chain(L, [100, 80], style=0, gap=120,
              enemies=[("turret", 90), ("turret", 270), ("grunt", 0)],
              cassette=(0, 180, 0), pickup=(1, 0, "L"))
    fight(L, 500, [("bulwark", 260), ("grunt", 420)])
    L.gap(80)
    fight(L, 420, [("minimech", 300)])
    L.checkpoint(-380)
    L.plat(80, 60, 120)
    L.plat(240, 120, 120)
    L.plat(400, 60, 120)
    L.here("cassette", 300, h=160, index=1)
    fight(L, 560, [("clerk", 200), ("drone", 350), ("grunt", 500)])
    L.here("hostage", -80, reward="grenade")
    steps(L, [-60], 200)
    fight(L, 520, [("cyclops", 320), ("roller", 440)])
    L.here("cassette", -40, h=0, index=2)
    L.finish()
    return L


def w1_l4():
    L = Level("w1_l4", "Lato Oscuro del Sasso", 1, 4, "asteroids", music="world1",
              par=260, target=34000)
    L.ground(40)
    L.start(80)
    fight(L, 480, [("grunt", 280), ("drone", 400)])
    hop_chain(L, [110], style=1, enemies=[("sniper", 180), ("turret", 60)],
              hostage=(0, 300, "H"))
    L.checkpoint(-150)
    fight(L, 520, [("bulwark", 320), ("clerk", 460)])
    L.gap(80)
    steps(L, [55, 55], 150)
    fight(L, 450, [("cyclops", 330)])
    L.here("pickup", -400, item="P")
    L.checkpoint(-200)
    hop_chain(L, [70, 90, 70], style=0, gap=130,
              enemies=[("grunt", 0), ("sniper", 180), ("turret", 90)],
              cassette=(1, 0, 0), ground_below=False)
    fight(L, 500, [("minimech", 300), ("grunt", 450)])
    L.here("hostage", -80, reward="S")
    L.checkpoint(-300)
    fight(L, 520, [("roller", 200), ("roller", 260), ("drone", 400)])
    L.plat(60, 70, 140)
    L.here("cassette", 120, h=110, index=1)
    L.gap(80)
    hop_chain(L, [120], style=1, enemies=[("sniper", 180), ("bulwark", 0)],
              cassette=(0, 140, 2))
    fight(L, 520, [("cyclops", 250), ("grunt", 400), ("clerk", 480)])
    L.here("hostage", -60, reward="grenade")
    L.finish()
    return L


def boss_level(id, name, world, theme, kind, music, *, approach=None, style=0):
    L = Level(id, name, world, 5, theme, music=music, par=200, target=80000, boss=True,
              height=1100, base=850)
    L.ground(40)
    L.start(80)
    if approach:
        approach(L)
    L.checkpoint(60)
    L.ground(200)
    # No left wall: the arena keeps the player in while the boss is alive.
    arena_w, arena_h = 640, 340
    L.ground(arena_w)
    L.ent("boss", L.x - arena_w / 2, L.gy, kind=kind, arenaW=float(arena_w),
          arenaH=float(arena_h))
    L.step(400)
    L.ground(60)
    return L


def w1_boss():
    def approach(L):
        fight(L, 500, [("grunt", 260), ("clerk", 420)])
        L.here("pickup", -60, item="H")
    return boss_level("w1_l5", "Timbratore Supremo", 1, "asteroids", "stamper", "boss",
                      approach=approach)


# ----------------------------------------------------------------- world 2 --


def w2_l1():
    L = Level("w2_l1", "Corridoio Margherita", 2, 1, "station", music="world2",
              par=240, target=30000)
    L.ground(40)
    L.start(80)
    corridor(L, 600, enemies=[("grunt", 300), ("turret", 520)])
    corridor(L, 700, flip=(150, 550), enemies=[("grunt", 640)],
             ceiling_enemies=[("turret", 300), ("grunt", 420)])
    L.here("hint", -680, icon="gravity")
    L.checkpoint(-60)
    corridor(L, 500, enemies=[("bulwark", 380)])
    L.here("pickup", -420, item="L")
    L.gap(80)
    corridor(L, 600, enemies=[("clerk", 200), ("drone", 400), ("grunt", 540)])
    L.here("hostage", -300, reward="grenade")
    L.checkpoint(-100)
    corridor(L, 800, flip=(100, 700), ceiling_enemies=[("turret", 250), ("turret", 500)],
             enemies=[("cyclops", 760)])
    L.here("cassette", -400, h=200, index=0)
    corridor(L, 500, enemies=[("minimech", 360)])
    steps(L, [60], 160)
    corridor(L, 600, enemies=[("grunt", 200), ("grunt", 300), ("clerk", 500)])
    L.here("hostage", -80, reward="R")
    L.checkpoint(-500)
    corridor(L, 600, flip=(200, 500), ceiling_enemies=[("grunt", 350)],
             enemies=[("bulwark", 560)])
    L.here("cassette", -300, h=200, index=1)
    fight(L, 400, [("drone", 200), ("drone", 300)])
    L.here("cassette", -60, h=0, index=2)
    L.finish()
    return L


def w2_l2():
    L = Level("w2_l2", "Sala Antigravità", 2, 2, "station", music="world2",
              par=260, target=32000)
    L.ground(40)
    L.start(80)
    corridor(L, 500, enemies=[("grunt", 300), ("grunt", 420)])
    L.here("hint", 80, icon="jetpack")
    zero_g(L, 900, blocks=[(250, 150, 80), (520, 260, 60), (720, 120, 90)],
           enemies=[("jelly", 300, 200), ("jelly", 600, 280), ("swarm", 750, 200)])
    L.here("hostage", -300, h=0, reward="S")
    L.checkpoint(60)
    corridor(L, 500, enemies=[("bulwark", 360)])
    zero_g(L, 1000, blocks=[(200, 200, 60), (420, 100, 120), (650, 300, 60), (850, 180, 80)],
           enemies=[("jelly", 250, 260), ("drone", 500, 300), ("jelly", 700, 150),
                    ("swarm", 900, 250)])
    L.here("cassette", -600, h=340, index=0)
    L.checkpoint(60)
    corridor(L, 600, flip=(100, 500), ceiling_enemies=[("turret", 300)],
             enemies=[("cyclops", 540)])
    L.here("pickup", -60, item="F")  # outside the flip zone
    zero_g(L, 800, blocks=[(300, 220, 100), (600, 120, 60)],
           enemies=[("swarm", 350, 300), ("jelly", 600, 250), ("rocket", 700, 200)])
    L.here("cassette", -100, h=360, index=1)
    L.here("hostage", -500, h=0, reward="grenade")
    L.checkpoint(60)
    corridor(L, 600, enemies=[("grunt", 200), ("minimech", 400), ("clerk", 560)])
    L.here("cassette", -30, h=0, index=2)
    L.finish()
    return L


def w2_l3():
    L = Level("w2_l3", "Moto-Razzo Express", 2, 3, "station", music="world2",
              par=200, target=30000)
    L.ground(40)
    L.start(80)
    L.ground(200)
    L.here("vehicle", -60, kind="bike")
    L.here("hint", -120, icon="bike")
    # Long run with jumps and ramps: the bike's showcase.
    for i in range(6):
        fight(L, 520, [("grunt", 300), ("roller", 420)] if i % 2 == 0 else
              [("clerk", 260), ("drone", 400)])
        L.ground(140, rise=40)
        L.gap(110)
        L.step(-40)
    L.checkpoint(60)
    L.here("pickup", 200, item="S")
    L.here("hostage", 500, reward="grenade")
    for i in range(5):
        fight(L, 480, [("bulwark", 380)] if i == 2 else [("grunt", 240), ("grunt", 400)])
        L.gap(100)
    L.here("cassette", 0, h=140, index=0)
    L.ground(300)
    L.checkpoint(-60)
    for i in range(5):
        L.ground(200, rise=-30 if i % 2 else 30)
        fight(L, 380, [("cyclops", 300)] if i == 3 else [("drone", 200), ("roller", 330)])
        if i in (1, 3):
            L.gap(110)
    L.here("cassette", -200, h=150, index=1)
    L.here("hostage", -80, reward="H")
    fight(L, 600, [("grunt", 300), ("clerk", 450)])
    L.here("cassette", -100, h=0, index=2)
    L.finish()
    return L


def w2_l4():
    L = Level("w2_l4", "Anelli della Pizza", 2, 4, "station", music="world2",
              par=280, target=36000)
    L.ground(40)
    L.start(80)
    corridor(L, 500, enemies=[("grunt", 260), ("turret", 440)])
    corridor(L, 900, flip=(100, 800), ceiling_enemies=[("turret", 300), ("grunt", 500),
                                                       ("turret", 700)])
    L.here("cassette", -450, h=200, index=0)
    L.checkpoint(-60)
    hop_chain(L, [90, 90], style=3, gap=120, enemies=[("turret", 0), ("turret", 180),
                                                       ("sniper", 90)],
              hostage=(1, 0, "L"))
    corridor(L, 600, flip=(150, 450), enemies=[("bulwark", 560)],
             ceiling_enemies=[("grunt", 300)])
    L.checkpoint(-100)
    zero_g(L, 700, blocks=[(300, 200, 80)], enemies=[("jelly", 300, 260),
                                                     ("swarm", 500, 200)])
    L.here("cassette", -350, h=330, index=1)
    corridor(L, 600, enemies=[("minimech", 300), ("cyclops", 520)])
    L.here("hostage", -200, reward="grenade")
    L.checkpoint(-500)
    hop_chain(L, [110, 80, 110], style=3, gap=120, enemies=[("grunt", 0), ("turret", 180),
                                                            ("sniper", 0)],
              cassette=(1, 180, 2), ground_below=False)
    corridor(L, 600, flip=(100, 400), ceiling_enemies=[("turret", 250)],
             enemies=[("clerk", 500)])
    L.here("hostage", -50, reward="P")
    L.finish()
    return L


def w2_boss():
    def approach(L):
        corridor(L, 500, enemies=[("grunt", 300), ("turret", 420)])
        L.here("pickup", -60, item="R")
    return boss_level("w2_l5", "La Grande Lavatrice Cosmica", 2, "station", "washer",
                      "boss", approach=approach)


# ----------------------------------------------------------------- world 3 --


def w3_l1():
    L = Level("w3_l1", "Arcipelago Glorbo", 3, 1, "glorbo", music="world3",
              par=280, target=40000)
    L.ground(40)
    L.start(80)
    fight(L, 450, [("clerk", 250), ("clerk", 380)])
    hop_chain(L, [90, 120, 80, 100], style=2, gap=125,
              enemies=[("grunt", 0), ("turret", 120), ("sniper", 180), ("grunt", 270),
                       ("turret", 0), ("roller", 90)],
              hostage=(1, 270, "H"), cassette=(2, 180, 0), pickup=(0, 90, "P"),
              ground_below=False)
    L.checkpoint(60)
    fight(L, 500, [("bulwark", 300), ("drone", 420)])
    hop_chain(L, [140], style=2, enemies=[("cyclops", 0), ("turret", 120), ("turret", 240)],
              cassette=(0, 180, 1))
    L.checkpoint(-100)
    fight(L, 520, [("minimech", 300), ("clerk", 460)])
    L.gap(80)
    hop_chain(L, [80, 80, 80], style=2, gap=110,
              enemies=[("roller", 0), ("roller", 0), ("sniper", 180)],
              hostage=(2, 90, "grenade"), cassette=(1, 0, 2), ground_below=False)
    fight(L, 500, [("grunt", 260), ("grunt", 400), ("clerk", 470)])
    L.here("hostage", -60, reward="S")
    L.finish()
    return L


def w3_l2():
    L = Level("w3_l2", "Navetta nel Vuoto", 3, 2, "glorbo", music="world3",
              par=220, target=40000, height=1200, base=950)
    L.ground(40)
    L.start(80)
    L.ground(260)
    L.here("vehicle", -60, kind="shuttle")
    L.here("hint", -120, icon="shuttle")
    # A long zero-g run with floating rocks: shoot'em up section.
    x0 = L.x
    length = 5200
    L.ceiling(length, 640, thick=200)
    L.ground(length)
    L.zone("zero", x0, L.gy - 640, x0 + length, L.gy)
    import random
    r = random.Random(1994)
    for i in range(18):
        cx = x0 + 400 + i * 270 + r.randint(-40, 40)
        cy = L.gy - r.randint(120, 520)
        s = r.randint(30, 60)
        L.solid([(cx - s, cy - s * 0.6), (cx, cy - s), (cx + s, cy - s * 0.5),
                 (cx + s * 0.8, cy + s * 0.6), (cx - s * 0.5, cy + s * 0.7)])
    kinds = ["drone", "swarm", "rocket", "jelly", "drone", "rocket"]
    for i in range(30):
        L.ent("enemy", x0 + 600 + i * 150, L.gy - r.randint(120, 500), kind=kinds[i % 6])
    L.ent("checkpoint", x0 + 1800, L.gy)
    L.ent("checkpoint", x0 + 3600, L.gy)
    for i, dx in enumerate([1200, 2700, 4400]):
        L.ent("cassette", x0 + dx, L.gy - 560, index=i)
    L.ent("hostage", x0 + 2000, L.gy, reward="H")
    L.ent("hostage", x0 + 4000, L.gy, reward="grenade")
    fight(L, 400, [("grunt", 300)])
    L.finish()
    return L


def w3_l3():
    L = Level("w3_l3", "Fabbrica di Moduli", 3, 3, "glorbo", music="world3",
              par=280, target=44000)
    L.ground(40)
    L.start(80)
    L.ground(160)
    L.here("vehicle", -40, kind="mech")
    fight(L, 700, [("bulwark", 300), ("cyclops", 520), ("grunt", 650)])
    steps(L, [60, 60, -60], 180)
    fight(L, 600, [("minimech", 250), ("minimech", 450), ("clerk", 560)])
    L.checkpoint(-500)
    L.here("hostage", -300, reward="L")
    corridor(L, 700, flip=(150, 550), ceiling_enemies=[("turret", 300), ("turret", 450)],
             enemies=[("cyclops", 640)])
    L.here("cassette", -350, h=200, index=0)
    hop_chain(L, [100, 100], style=2, gap=120,
              enemies=[("cyclops", 0), ("sniper", 180), ("turret", 90)],
              cassette=(1, 270, 1))
    L.checkpoint(-100)
    fight(L, 600, [("bulwark", 200), ("bulwark", 400), ("drone", 520)])
    L.here("pickup", -300, item="F")
    L.gap(80)
    fight(L, 600, [("clerk", 200), ("clerk", 300), ("minimech", 500)])
    L.here("hostage", -100, reward="grenade")
    L.here("cassette", -500, h=0, index=2)
    L.finish()
    return L


def w3_l4():
    L = Level("w3_l4", "Ultimo Sportello", 3, 4, "glorbo", music="world3",
              par=300, target=48000)
    L.ground(40)
    L.start(80)
    fight(L, 500, [("grunt", 250), ("clerk", 350), ("grunt", 450)])
    hop_chain(L, [90, 110], style=2, gap=120,
              enemies=[("sniper", 180), ("turret", 0), ("roller", 90)],
              hostage=(0, 270, "S"))
    L.checkpoint(-100)
    corridor(L, 700, flip=(100, 600), ceiling_enemies=[("grunt", 300), ("turret", 500)],
             enemies=[("bulwark", 650)])
    zero_g(L, 800, blocks=[(300, 200, 80), (550, 120, 60)],
           enemies=[("jelly", 250, 250), ("swarm", 450, 300), ("jelly", 650, 150)])
    L.here("cassette", -400, h=340, index=0)
    L.checkpoint(60)
    fight(L, 600, [("cyclops", 300), ("minimech", 450), ("drone", 550)])
    L.here("pickup", -550, item="H")
    hop_chain(L, [80, 80, 80, 80], style=2, gap=115,
              enemies=[("turret", 0), ("sniper", 180), ("turret", 0), ("roller", 180)],
              cassette=(3, 0, 1), ground_below=False)
    L.checkpoint(60)
    fight(L, 700, [("bulwark", 250), ("clerk", 400), ("cyclops", 600)])
    L.here("hostage", -150, reward="grenade")
    L.here("cassette", -40, h=0, index=2)
    L.finish()
    return L


def w3_boss():
    def approach(L):
        fight(L, 500, [("clerk", 250), ("bulwark", 420)])
        L.here("pickup", -60, item="L")
    return boss_level("w3_l5", "Imperatore Glorbo", 3, "glorbo", "emperor", "boss",
                      approach=approach)


LEVELS = [
    w1_l1, w1_l2, w1_l3, w1_l4, w1_boss,
    w2_l1, w2_l2, w2_l3, w2_l4, w2_boss,
    w3_l1, w3_l2, w3_l3, w3_l4, w3_boss,
]
