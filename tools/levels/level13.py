"""Уровень 13 «Аляска» (финал эпизода 3): северный городок у замёрзшего залива.
Деревянные дома под снегом, православная церковь с луковичными куполами, фактория и салун,
лесопилка, консервный завод у причала, аэродром с самолётами. Над городом — северное сияние.
Сначала город нужно освободить (три района), потом он становится базой: входы на прииск
и в заброшенный городок, бревенчатый дом у озера, самолёты в первый город и Сан-Франциско."""
from levelkit import Level, xform, rot_x, rot_y, rot_z, f, yaw_to
import math
import random

random.seed(13)
L = Level("Level13Alaska", {
    "level_index": "13",
    "title": '"Аляска"',
    "objective": '"Освободите город: зачистите три района"',
})
for g in ("Geometry", "Lights", "Props", "Enemies", "Pickups", "Properties", "Entrances"):
    L.group(g)

GROUND = -0.02
STREETS = (-36, 0, 36)
HALF = 5
WARM = "Color(1, 0.8, 0.55, 1)"
SIGN = "Color(1, 0.85, 0.45, 1)"


def mul(a, b):
    return [[sum(a[i][k] * b[k][j] for k in range(3)) for j in range(3)] for i in range(3)]


def gable_roof(x0, x1, z0, z1, h, rise, mat="snow", parent="Geometry"):
    half = (z1 - z0) / 2
    theta = math.atan2(rise, half)
    length = math.hypot(half, rise) + 0.6
    cz = (z0 + z1) / 2
    for sign in (-1, 1):
        rows = rot_x(-theta if sign < 0 else theta)
        L.box(parent, "Roof", ((x0 + x1) / 2, h + rise / 2 + 0.1, cz + sign * half / 2), (x1 - x0 + 0.8, 0.25, length),
              mat, rows=rows)


def building(x0, x1, z0, z1, h, mat):
    L.box_ext("Geometry", "Building", x0, x1, 0, h, z0, z1, mat)
    L.box_ext("Geometry", "RoofSlab", x0 - 0.3, x1 + 0.3, h, h + 0.4, z0 - 0.3, z1 + 0.3, "snow")


def log_house(x0, x1, z0, z1, h=4.5, lit=True):
    """Бревенчатый дом: стены, двускатная крыша под снегом, светящееся окно на улицу."""
    L.box_ext("Geometry", "LogHouse", x0, x1, 0, h, z0, z1, "wood")
    gable_roof(x0, x1, z0, z1, h, 1.8)
    for y in (0.9, 2.1, 3.3):
        L.box_ext("Props", "LogBand", x0 - 0.05, x1 + 0.05, y, y + 0.12, z0 - 0.05, z1 + 0.05, "tree_trunk",
                  collide=False, shadow=False)
    if lit:
        cx = (x0 + x1) / 2
        L.box_ext("Props", "Window", cx - 1, cx + 1, 1.3, 2.5, z1, z1 + 0.05, "lamp", collide=False, shadow=False)


def pine(x, z, h=None, y=0.0):
    h = h or random.uniform(7, 12)
    L.cylinder("Props", "PineTrunk", (x, y + h * 0.25, z), 0.3, h * 0.5, "tree_trunk", collide=False, sides=6)
    for i, s in enumerate((3.2, 2.4, 1.5)):
        L.box("Props", "PineCrown", (x, y + h * (0.35 + 0.22 * i), z), (s, h * 0.24, s), "tree_leaves",
              collide=False)
        L.box("Props", "PineSnow", (x, y + h * (0.35 + 0.22 * i) + h * 0.12, z), (s * 0.8, 0.2, s * 0.8), "snow",
              collide=False, shadow=False)


def totem(x, z):
    colors = ("car_red", "tree_trunk", "plaster_blue", "car_black", "plaster_yellow")
    for i in range(5):
        L.box("Props", "Totem", (x, 0.6 + i * 1.2, z), (1.0, 1.2, 1.0), colors[i % len(colors)])
    L.box("Props", "TotemWings", (x, 5.9, z), (3.2, 0.3, 0.6), "car_red", collide=False)


def label(text, pos, yaw=0.0, size=56, color=SIGN):
    L.label(text, pos, yaw=yaw, size=size, color=color)


# --- Земля, улицы, ограда -------------------------------------------------------------------
TILES = (-63, -21, 21, 63)
for i in range(3):
    for j in range(3):
        L.begin_section(f"Ground{i}{j}")
        L.box_ext("Geometry", "Snow", TILES[i], TILES[i + 1], GROUND - 0.5, GROUND, TILES[j], TILES[j + 1], "snow")
L.begin_section("Roads")
for c in STREETS:
    L.box_ext("Props", "Road", c - HALF, c + HALF, GROUND, 0.0, -62, 62, "gravel", collide=False, shadow=False)
    L.box_ext("Props", "Road", -62, 62, GROUND, 0.0, c - HALF, c + HALF, "gravel", collide=False, shadow=False)
L.begin_section("Walls")
for x0, x1, z0, z1 in ((-63, 63, -63, -62), (-63, 63, 62, 63), (-63, -62, -62, 62), (62, 63, -62, 62)):
    L.box_ext("Geometry", "Palisade", x0, x1, GROUND, 1.6, z0, z1, "wood")
    L.invisible_wall("Geometry", "Guard", ((x0 + x1) / 2, 3, (z0 + z1) / 2), (x1 - x0, 6, z1 - z0))

# --- Север: церковь, фактория и салун, радиостанция, лесопилка --------------------------------
L.begin_section("Church")
L.box_ext("Geometry", "Church", -56, -46, 0, 7, -58, -46, "white_paint")
gable_roof(-56, -46, -58, -46, 7, 2.4, mat="plaster_blue")
L.box_ext("Geometry", "ChurchTower", -53, -49, 0, 11, -46, -42, "white_paint")
for r, y0, hh in ((1.0, 11, 0.5), (1.5, 11.5, 0.8), (1.7, 12.3, 0.6), (1.3, 12.9, 0.6), (0.7, 13.5, 0.6),
                  (0.25, 14.1, 0.8)):
    L.cylinder("Props", "Dome", (-51, y0 + hh / 2, -44), r, hh, "plaster_blue", collide=False, sides=12)
L.box("Props", "Cross", (-51, 15.4, -44), (0.12, 1.4, 0.12), "gold", collide=False)
L.box("Props", "CrossBar", (-51, 15.6, -44), (0.7, 0.1, 0.1), "gold", collide=False)
for x in (-54, -48):
    L.cylinder("Props", "SmallDome", (x, 9.6, -55), 0.9, 1.0, "plaster_blue", collide=False, sides=10)
L.box_ext("Props", "ChurchDoor", -52, -50, 0, 2.6, -41.98, -41.92, "wood", collide=False, shadow=False)
L.box_ext("Props", "ChurchWindow", -46.02, -45.96, 2, 4.5, -54, -50, "lamp", collide=False, shadow=False)
label("ЦЕРКОВЬ ВОЗНЕСЕНИЯ", (-51, 5.6, -41.9), size=40)

L.begin_section("TradingPost")
building(-30, -18, -58, -44, 6, "wood")
L.box_ext("Props", "Porch", -30, -18, 0, 0.12, -44, -42, "plank", collide=False, shadow=False)
L.box_ext("Props", "PorchRoof", -30.3, -17.7, 3.0, 3.2, -44.3, -41.7, "plank", collide=False)
label("ФАКТОРИЯ · МЕХА И ЗОЛОТО", (-24, 4.6, -43.6), size=44)
building(-16, -6, -58, -44, 7, "plank")
L.box_ext("Props", "SaloonDoor", -12, -10, 0, 2.4, -43.98, -43.92, "lamp", collide=False, shadow=False)
label("САЛУН «ПОЛЯРНЫЙ МЕДВЕДЬ»", (-11, 5.6, -43.6), size=40)
L.node("Light", "OmniLight3D", "Lights", transform=xform((-11, 3, -42)), light_color=WARM, light_energy="1.6",
       omni_range="10")

L.begin_section("Radio")
building(8, 20, -56, -46, 5, "concrete")
label("РАДИО «КЛОНДАЙК»", (14, 3.8, -45.6), size=44)
L.box_ext("Geometry", "Mast", 25.6, 26.4, 0, 30, -51.4, -50.6, "black_metal")
for y in (10, 20, 29.5):
    L.box("Props", "MastLight", (26, y, -51), (0.5, 0.4, 0.5), "lamp_red", collide=False, shadow=False)

L.begin_section("Sawmill")
building(43, 58, -58, -48, 6, "plank")
label("ЛЕСОПИЛКА", (50.5, 4.4, -47.6), size=64)
for i, z in enumerate((-46.5, -45.2, -43.9)):
    for k in range(3 - i % 2):
        L.cylinder("Props", "Log", (46 + k * 4.2, 0.45 + (i % 2) * 0.4, z), 0.45, 3.8, "tree_trunk",
                   rows=rot_z(math.pi / 2), sides=8)
L.box_ext("Props", "SawBlade", 41.9, 42.1, 1.2, 3.6, -54, -52, "metal", collide=False)

# --- Середина: дома, площадь с ёлкой и тотемами, отель, ангар -----------------------------------
L.begin_section("WestHouses")
log_house(-58, -46, -29, -20)
log_house(-58, -46, -16, -7)
L.begin_section("Square")
L.box_ext("Props", "Plaza", -31, -5, GROUND, 0.01, -31, -5, "paving", collide=False, shadow=False)
pine(-18, -18, 13)
for i, (x, y, z) in enumerate(((-19.2, 4.2, -16.8), (-16.6, 6.1, -19.4), (-19.4, 8.2, -19.2), (-17, 3.4, -19.8),
                              (-16.9, 9.6, -17.1), (-19.6, 6.4, -17.0))):
    L.box("Props", "Garland", (x, y, z), (0.3, 0.3, 0.3), ("lamp_red", "lamp_green", "lamp")[i % 3], collide=False,
          shadow=False)
L.box("Props", "Star", (-18, 13.3, -18), (0.6, 0.6, 0.2), "gold", collide=False, shadow=False)
L.node("Light", "OmniLight3D", "Lights", transform=xform((-18, 5, -18)), light_color=WARM, light_energy="1.6",
       omni_range="14")
totem(-27, -27)
totem(-9, -9)
for x, z in ((-25, -10), (-11, -26)):
    L.box("Props", "Bench", (x, 0.25, z), (2.0, 0.5, 0.6), "wood")
L.begin_section("Hotel")
building(8, 29, -29, -7, 10, "brick")
label("ОТЕЛЬ «СЕВЕРНОЕ СИЯНИЕ»", (7.4, 7.2, -18), yaw=-90, size=56)
L.node("Light", "OmniLight3D", "Lights", transform=xform((5.5, 4, -18)), light_color=WARM, light_energy="1.5",
       omni_range="10")
L.begin_section("Hangar")
building(43, 58, -29, -8, 7, "metal")
L.box_ext("Props", "HangarDoor", 42.94, 43.0, 0, 5.5, -26, -11, "black_metal", collide=False, shadow=False)
label("АЭРОДРОМ", (42.4, 6.2, -18.5), yaw=-90, size=72)

# --- Юг от главной улицы: дома, школа, магазин, топливо --------------------------------------
L.begin_section("SouthHouses")
log_house(-58, -46, 7, 17)
log_house(-58, -46, 20, 29)
L.begin_section("School")
building(-29, -7, 9, 20, 6, "plaster_yellow")
label("ШКОЛА", (-18, 4.6, 8.6), yaw=180, size=56)
L.box("Props", "Flagpole", (-18, 4, 24), (0.15, 8, 0.15), "metal")
L.box("Props", "Flag", (-17.2, 7.4, 24), (1.4, 0.9, 0.05), "plaster_blue", collide=False)
L.begin_section("Store")
building(7, 18, 7, 29, 5, "wood")
label("ВСЁ ДЛЯ СТАРАТЕЛЯ", (6.4, 3.8, 18), yaw=-90, size=40)
building(20, 29, 7, 29, 4.5, "white_paint")
L.box_ext("Props", "DinerStripe", 19.95, 20.05, 3.0, 3.4, 7, 29, "lamp_red", collide=False, shadow=False)
label("ЗАКУСОЧНАЯ «ЛОСЬ»", (24.5, 3.6, 29.6), size=44)
L.begin_section("Fuel")
for x, z in ((47, 12), (55, 12), (51, 24)):
    L.cylinder("Props", "FuelTank", (x, 3, z), 3.0, 6, "white_paint", sides=14)
label("ТОПЛИВО", (47, 4.0, 8.9), yaw=180, size=56)

# --- Набережная: рыбный рынок, консервный завод, причал, дом игрока ------------------------------
L.begin_section("Market")
for x0 in (-29, -16):
    L.box_ext("Geometry", "FishShed", x0, x0 + 9, 0, 4, 43, 52, "plank")
    gable_roof(x0, x0 + 9, 43, 52, 4, 1.4)
label("РЫБНЫЙ РЫНОК", (-18, 3.4, 42.4), yaw=180, size=48)
L.begin_section("Cannery")
building(7, 29, 43, 58, 7, "rust")
label("КОНСЕРВНЫЙ ЗАВОД", (18, 5.6, 42.4), yaw=180, size=64)
L.cylinder("Props", "Chimney", (26, 10, 55), 0.8, 8, "brick", sides=10)
L.begin_section("Dock")
building(43, 58, 43, 56, 6, "plank")
label("ПРИЧАЛ", (50.5, 4.4, 42.4), yaw=180, size=64)

L.room("AKCabin", -57, -45, 43, 53, 0, 3.6, "plank", "wood", "wood", openings={"N": [(-52, -50, 2.6)]})
gable_roof(-57.5, -44.5, 42.5, 53.5, 3.6, 1.6)
L.box_ext("Props", "CabinChimney", -47, -46, 3.6, 7, 50, 51, "stone")
L.node("Light", "OmniLight3D", "Lights", transform=xform((-51, 3.0, 48)), light_color=WARM, light_energy="1.3",
       omni_range="8")
script = L.ext_res("Script", "res://scripts/property.gd")
root = L.node("cabin", "Node3D", "Properties", script=script, property_id='"cabin"')
L.box(root, "Door", (-51, 1.3, 42.75), (2.0, 2.6, 0.3), "plank", collide=True)
L.node("ForSale", "Label3D", root, transform=xform((-51, 3.1, 42.3), rot_y(180)), pixel_size="0.01",
       modulate="Color(1, 0.9, 0.3, 1)", outline_size="12", font_size="56", text='"ПРОДАЁТСЯ"')
L.node("Spawn", "Marker3D", root, transform=xform((-51, 0.05, 48), rot_y(0)))
fur = L.node("Furniture", "Node3D", root)
L.interactable("property_door", "CabinDoor", "Entrances", (-51, 1.5, 41.4), (3, 3, 2.4), property_id='"cabin"')
for group, items in (("Base", [("Bed", (-55.5, 0.3, 51), (1.4, 0.6, 2.0), "blanket"),
                               ("Table", (-48, 0.45, 51), (1.4, 0.9, 1.0), "wood"),
                               ("Rug", (-51, 0.02, 48), (3, 0.04, 2.4), "red_carpet")]),
                     ("stove", [("Stove", (-46.2, 0.6, 50.5), (1.0, 1.2, 1.0), "black_metal"),
                                ("BearSkin", (-51, 0.05, 48), (2.4, 0.06, 1.6), "tree_trunk")]),
                     ("workbench", [("Bench", (-56.2, 0.5, 45), (1.0, 1.0, 2.4), "wood"),
                                    ("Vise", (-56.2, 1.1, 45.6), (0.3, 0.2, 0.3), "metal"),
                                    ("Scope", (-56.2, 1.07, 44.6), (0.12, 0.12, 0.6), "black_metal")]),
                     ("gold_pan", [("Pan", (-48, 0.95, 51), (0.7, 0.06, 0.7), "metal"),
                                   ("Nugget", (-48, 1.0, 51), (0.15, 0.1, 0.12), "gold")])):
    g = L.node(group, "Node3D", fur)
    for name, center, size, mat in items:
        L.box(g, name, center, size, mat, collide=False)
label("ДОМ У ОЗЕРА", (-51, 4.6, 42.2), yaw=180, size=48)

# --- Освобождение: три района -------------------------------------------------------------------
L.wave_zone("ZoneSawmill", (36, 2, -36), (20, 4, 20),
            spawns=[(36, 0.1, -56), (56, 0.1, -36), (16, 0.1, -36), (36, 0.1, -16)], barriers=[],
            title="Лесопилка!", waves=2, first=5, extra=2, rusher=0.35, heavy=1,
            gunner_kind="bandit", rusher_kind="trapper")
L.wave_zone("ZoneSquare", (-18, 2, -18), (26, 4, 26),
            spawns=[(-36, 0.1, -18), (0, 0.1, -18), (-18, 0.1, -36), (-18, 0.1, 0)], barriers=[],
            title="Площадь с ёлкой!", waves=2, first=5, extra=2, rusher=0.3, heavy=1,
            gunner_kind="bandit", rusher_kind="trapper")
L.wave_zone("ZoneHarbor", (18, 2, 36), (30, 4, 10),
            spawns=[(0, 0.1, 52), (36, 0.1, 52), (36, 0.1, 20), (0, 0.1, 20)], barriers=[],
            title="Консервный завод!", waves=2, first=5, extra=2, rusher=0.3, heavy=1,
            gunner_kind="bandit", rusher_kind="trapper")
for kind, pos in (("bandit", (30, 0, -38)), ("bandit", (38, 0, -28)), ("trapper", (46, 0, -34)),
                  ("heavy", (36, 0, -50)), ("marksman", (50, 6.4, -50)),
                  ("bandit", (-14, 0, -10)), ("bandit", (-26, 0, -22)), ("trapper", (-8, 0, -26)),
                  ("bandit", (0, 0, -20)), ("heavy", (-18, 0, -28)),
                  ("bandit", (10, 0, 36)), ("bandit", (26, 0, 37)), ("trapper", (36, 0, 28)),
                  ("heavy", (18, 0, 38)), ("marksman", (18, 7.4, 45)),
                  ("bandit", (-36, 0, 2)), ("bandit", (36, 0, 10)), ("bandit", (-36, 0, 28)),
                  ("trapper", (0, 0, 14)), ("bandit", (-2, 0, -48)), ("marksman", (14, 10.4, -10))):
    L.enemy(kind, pos, look_at=(0, pos[1], 0))
for kind, pos in (("health", (-36, 0, -30)), ("ammo", (-30, 0, -36)), ("health", (30, 0, 40)),
                  ("grenade", (-36, 0, 30)), ("health", (40, 0, -40)), ("ammo", (0, 0, 30)),
                  ("ammo", (36, 0, -6))):
    L.pickup(kind, pos)

# --- База: входы на уровни эпизода, аэродром --------------------------------------------------
L.interactable("level_entrance", "MineRoad", "Entrances", (-58.5, 1.5, 0), (3, 3, 6), level_index="11")
label("ДОРОГА НА ПРИИСК", (-60.4, 3.6, 0), yaw=90, size=56)
L.interactable("level_entrance", "GhostTrail", "Entrances", (0, 1.5, -58.5), (6, 3, 3), level_index="12")
for x in (-3.5, 3.5):
    L.box("Props", "TrailPost", (x, 2.2, -61), (0.4, 4.4, 0.4), "wood")
L.box_ext("Props", "TrailBeam", -4, 4, 4.1, 4.6, -61.2, -60.8, "wood", collide=False)
label("ТРОПА В ЗАБРОШЕННЫЙ ГОРОДОК", (0, 5.2, -60.7), size=44)
L.interactable("travel_point", "AirfieldTown", "Entrances", (58.5, 1.5, 0), (3, 3, 6), episode="1")
label("САМОЛЁТ → ГОРОД", (60.4, 3.6, 0), yaw=-90, size=56)
L.interactable("travel_point", "AirfieldSF", "Entrances", (58.5, 1.5, 36), (3, 3, 6), episode="2")
label("САМОЛЁТ → САН-ФРАНЦИСКО", (60.4, 3.6, 36), yaw=-90, size=48)

# --- Фонари, снег, прохожие, машины ----------------------------------------------------------
lamps = L.group("StreetLamps")
L.nodes[-1] = L.nodes[-1] + '\nscript = ' + L.ext_res("Script", "res://scripts/street_lamps.gd")
n = 0
for c in STREETS:
    for i, t in enumerate(range(-56, 57, 14)):
        if any(abs(t - s) < 6 for s in STREETS):
            continue
        side = 1 if i % 2 == 0 else -1
        for pos, target in (((c + side * 5.6, GROUND, t), (c, t)), ((t, GROUND, c - side * 5.6), (t, c))):
            L.node(f"Lamp{n:02d}", "Marker3D", lamps, transform=xform(pos, rot_y(yaw_to(pos, target))))
            n += 1
L.node("Snow", "Node3D", ".", script=L.ext_res("Script", "res://scripts/town/rain.gd"), snow="true")
for name in ("Civilians", "Traffic"):
    L.node(name, "Node3D", ".", script=L.ext_res("Script", f"res://scripts/town/{name.lower()}.gd"))

# --- Вокруг: горы, лес, замёрзший залив, взлётная полоса ------------------------------------------
L.section = "Outskirts"
L.box_ext("Props", "Ice", -500, 500, -1.2, -0.9, 63, 500, "glass", collide=False, shadow=False)
L.box_ext("Props", "IceSnow", -500, 500, -0.9, -0.85, 90, 500, "snow", collide=False, shadow=False)
for x, z, yaw in ((-20, 80, 20), (25, 95, -35)):
    L.box("Props", "Boat", (x, -0.4, z), (3.0, 1.4, 9.0), "car_red", collide=False, rows=rot_y(yaw))
    L.box("Props", "BoatCabin", (x, 1.0, z), (2.2, 1.4, 3.0), "white_paint", collide=False, rows=rot_y(yaw))
L.box_ext("Props", "Runway", 64, 120, -0.6, -0.3, -10, 10, "asphalt", collide=False, shadow=False)
for z0, yaw in ((-4, 0), (30, 10)):
    L.box("Props", "Fuselage", (80, 1.6, z0), (9.0, 1.6, 1.6), "white_paint", collide=False, rows=rot_y(yaw))
    L.box("Props", "Wing", (79, 2.4, z0), (1.8, 0.15, 11.0), "car_red", collide=False, rows=rot_y(yaw))
    L.box("Props", "Tail", (84.2, 2.6, z0), (1.2, 1.6, 0.15), "car_red", collide=False, rows=rot_y(yaw))
for i in range(40):
    side = random.choice(("N", "W", "E"))
    if side == "N":
        x, z = random.uniform(-90, 90), random.uniform(-110, -68)
    elif side == "W":
        x, z = random.uniform(-110, -68), random.uniform(-90, 60)
    else:
        x, z = random.uniform(68, 110), random.uniform(-90, -20)
    pine(x, z, y=random.uniform(-0.5, 1.5))
for x, z, w, h in ((-180, -40, 120, 70), (190, -60, 140, 90), (0, -230, 400, 120), (-140, -200, 160, 100)):
    L.box("Props", "Mountain", (x, h / 2 - 8, z), (w, h, 140), "snow", collide=False, shadow=False)
L.cylinder("Props", "Moon", (-140, 130, -320), 9, 1, "lamp_cold", collide=False, rows=rot_x(math.pi / 2), sides=24)

L.node("HubStart", "Marker3D", ".", transform=xform((52, 0.05, 0), rot_y(90)))
L.player((0, 0.05, -56), 180)
L.waypoint((0, 0, -56), (0, 0, -36), (36, 0, -36), (36, 0, 0), (0, 0, 0), (0, 0, 36), (-36, 0, 36), (-36, 0, 0),
           (-56, 0, 0))

env = [
    ("ShaderMaterial", "SkyMat_13", {"shader": L.ext_res("Shader", "res://materials/aurora_sky.gdshader")}),
    ("Sky", "Sky_13", {"sky_material": 'SubResource("SkyMat_13")'}),
    ("Environment", "Env_13", {
        "background_mode": "2", "sky": 'SubResource("Sky_13")',
        "ambient_light_source": "2", "ambient_light_color": "Color(0.4, 0.45, 0.56, 1)",
        "ambient_light_energy": "0.62", "tonemap_mode": "2",
        "fog_enabled": "true", "fog_light_color": "Color(0.2, 0.22, 0.27, 1)", "fog_density": "0.011",
        "fog_sky_affect": "0.35",
    }),
]
L.node("WorldEnvironment", "WorldEnvironment", ".", environment='SubResource("Env_13")')
L.node("Moonlight", "DirectionalLight3D", ".", transform=xform((0, 40, 0), mul(rot_y(210), rot_x(math.radians(-36)))),
       light_color="Color(0.65, 0.75, 1, 1)", light_energy="0.38", shadow_enabled="true",
       directional_shadow_max_distance="50.0", directional_shadow_mode="1")
L.explosives([(-43.5, 0, -30), (-28.5, 0, -42.5), (43, 0, -43.5), (6.5, 0, -6.5), (-6.5, 0, 6.5), (42.5, 0, 6.5),
              (-43, 0, 40.5), (30, 0, 42.5), (-30, 0, -6.5)], pattern="TBT")
L.explosives([(46, 0, 20), (56, 0, 22)], pattern="F")
L.cars([(32.8, 0, -20, 0), (-39.2, 0, 20, 180), (3.8, 0, -25, 0), (-3.8, 0, 48, 180)])
L.pickup("weapon", (0, 0, -40), weapon="rpg")
L.write("scenes/levels/level_13_alaska.tscn", env, ["pistol", "shotgun", "magnum", "rifle", "sniper"],
        script_path="res://scripts/town.gd")
