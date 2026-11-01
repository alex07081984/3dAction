"""Уровень 10 «Сан-Франциско» (финал эпизода 2): город у залива по мотивам «Грязного Гарри».
Чайнатаун с воротами, пирамида-небоскрёб, викторианские домики, крутая улица на холм
с канатным трамваем, набережная с паромом на Алькатрас. Сначала город нужно освободить
(три района), потом он становится базой: входы на уровни эпизода, квартира, аэропорт."""
from levelkit import Level, xform, rot_x, rot_y, f, yaw_to
import math
import random

random.seed(10)
L = Level("Level10SanFrancisco", {
    "level_index": "10",
    "title": '"Сан-Франциско"',
    "objective": '"Освободите город: зачистите три района"',
})
for g in ("Geometry", "Lights", "Props", "Enemies", "Pickups", "Properties", "Entrances"):
    L.group(g)

GROUND = -0.02
STREETS = (-36, 0, 36)
HALF = 5
COLS = [(-60, -41), (-31, -5), (5, 31), (41, 60)]
WARM = "Color(1, 0.85, 0.65, 1)"
VICTORIAN = ["plaster_pink", "plaster_blue", "plaster_yellow", "plaster_green", "plaster_white"]
HILL = 14


def mul(a, b):
    return [[sum(a[i][k] * b[k][j] for k in range(3)) for j in range(3)] for i in range(3)]


def gable_roof(x0, x1, z0, z1, h, rise, mat="roof_tiles"):
    half = (z1 - z0) / 2
    theta = math.atan2(rise, half)
    length = math.hypot(half, rise) + 0.6
    cz = (z0 + z1) / 2
    for sign in (-1, 1):
        rows = rot_x(-theta if sign < 0 else theta)
        L.box("Geometry", "Roof", ((x0 + x1) / 2, h + rise / 2 + 0.1, cz + sign * half / 2), (x1 - x0 + 0.8, 0.25, length),
              mat, rows=rows)


def building(x0, x1, z0, z1, h, mat, y=0.0):
    L.box_ext("Geometry", "Building", x0, x1, y, y + h, z0, z1, mat)
    L.box_ext("Geometry", "RoofSlab", x0 - 0.3, x1 + 0.3, y + h, y + h + 0.4, z0 - 0.3, z1 + 0.3, "concrete_dark")


def victorian(x0, x1, z0, z1, h, mat, front):
    """Викторианский дом: узкий, высокий, с эркером на улицу и двускатной крышей."""
    L.box_ext("Geometry", "House", x0, x1, 0, h, z0, z1, mat)
    gable_roof(x0, x1, z0, z1, h, 2.5)
    zc = (z0 + z1) / 2
    bx0, bx1 = (x1, x1 + 0.8) if front > 0 else (x0 - 0.8, x0)
    L.box_ext("Geometry", "Bay", bx0, bx1, 1.4, h - 1.2, zc - 1.2, zc + 1.2, mat)
    wx = bx1 if front > 0 else bx0
    L.box_ext("Props", "BayWindow", wx - 0.03, wx + 0.03, 2.0, h - 1.8, zc - 0.9, zc + 0.9, "lamp", collide=False,
              shadow=False)
    L.box_ext("Props", "Porch", bx0 - 0.4 * front, bx1, 0, 0.3, z0 + 0.4, z0 + 1.8, "wood")


def tree(x, z, h=None):
    h = h or random.uniform(4, 6.5)
    L.cylinder("Props", "Trunk", (x, h / 2, z), 0.25, h, "tree_trunk", sides=6)
    L.box("Props", "Crown", (x, h, z), (2.8, 2.6, 2.8), "tree_leaves", collide=False)


def car(x, z, along_x, mat):
    size = (4.4, 1.0, 2.0) if along_x else (2.0, 1.0, 4.4)
    cabin = (2.2, 0.65, 1.8) if along_x else (1.8, 0.65, 2.2)
    L.box("Props", "Car", (x, 0.6, z), size, mat)
    L.box("Props", "CarCabin", (x, 1.42, z), cabin, "dark_glass")


def lantern(x, y, z):
    L.box("Props", "Lantern", (x, y, z), (0.4, 0.5, 0.4), "lamp_red", collide=False, shadow=False)


def guards(x0, x1, z0, z1, y, gap=None):
    for x in (x0 - 0.6, x1 + 0.6):
        L.invisible_wall("Geometry", "Guard", (x, y + 2.5, (z0 + z1) / 2), (0.6, 5, z1 - z0 + 1.2))
    for z, side in ((z0 - 0.6, "N"), (z1 + 0.6, "S")):
        pieces = [(x0 - 0.6, gap[0]), (gap[1], x1 + 0.6)] if gap and side == "S" else [(x0 - 0.6, x1 + 0.6)]
        for a, b in pieces:
            L.invisible_wall("Geometry", "Guard", ((a + b) / 2, y + 2.5, z), (b - a, 5, 0.6))


# --- Земля, разметка, ограда ---------------------------------------------------------------
TILES = (-63, -21, 21, 63)
marks = []
for c in STREETS:
    for a, b in ((-60, -HALF - 1), (HALF + 1, 60)):
        for start in range(int(a), int(b) - 2, 6):
            marks.append(("Dash", c - 0.1, c + 0.1, start, start + 3))
            marks.append(("Dash", start, start + 3, c - 0.1, c + 0.1))
for i in range(3):
    for j in range(3):
        L.begin_section(f"Ground{i}{j}")
        L.box_ext("Geometry", "Asphalt", TILES[i], TILES[i + 1], GROUND - 0.5, GROUND, TILES[j], TILES[j + 1],
                  "asphalt_wet")
        for name, x0, x1, z0, z1 in marks:
            cx, cz = (x0 + x1) / 2, (z0 + z1) / 2
            if TILES[i] <= cx < TILES[i + 1] and TILES[j] <= cz < TILES[j + 1]:
                L.box_ext("Props", name, x0, x1, GROUND, 0.01, z0, z1, "road_line", collide=False, shadow=False)
L.begin_section("Walls")
for x0, x1, z0, z1 in ((-63, -5, -63, -62), (5, 63, -63, -62), (-63, 63, 62, 63), (-63, -62, -62, 62), (62, 63, -62, 62)):
    L.box_ext("Geometry", "TownWall", x0, x1, GROUND, 1.2, z0, z1, "stone")
    L.invisible_wall("Geometry", "Guard", ((x0 + x1) / 2, 3, (z0 + z1) / 2), (x1 - x0, 6, z1 - z0))

# --- Чайнатаун (северо-запад) ---------------------------------------------------------------
L.begin_section("Chinatown")
L.box_ext("Geometry", "Pagoda", -55, -45, 0, 5, -56, -46, "car_red")
for i, (pad, y0) in enumerate(((1.5, 5), (0, 9), (-1.5, 12))):
    L.box_ext("Geometry", "PagodaRoof", -55 - pad, -45 + pad, y0, y0 + 0.4, -56 - pad, -46 + pad, "black_metal")
    if i < 2:
        inset = 1.5 * (i + 1)
        L.box_ext("Geometry", "PagodaTier", -55 + inset, -45 - inset, y0 + 0.4, y0 + 3.6 + i * -0.6, -56 + inset,
                  -46 - inset, "car_red")
L.box_ext("Props", "Spire", -50.3, -49.7, 12.4, 15, -51.3, -50.7, "gold", collide=False)
for k in range(4):
    x0 = -30 + k * 6
    L.box_ext("Geometry", "Shop", x0, x0 + 5.5, 0, random.choice((6, 7, 8)), -58, -46,
              random.choice(("car_red", "plaster_yellow", "plaster_green")))
    L.box_ext("Props", "Awning", x0 + 0.3, x0 + 5.2, 2.8, 3.0, -46, -44.6, "awning_red", collide=False)
for x in range(-58, -43, 4):
    lantern(x + 0.5, 3.6, -41.6)
for z in range(-58, -43, 4):
    lantern(-41.6, 3.6, z + 0.5)
for x in range(-30, -6, 4):
    lantern(x + 0.5, 3.6, -44.4)
for x in (-40.3, -31.7):
    L.box("Geometry", "GatePillar", (x, 3.5, -50), (0.9, 7, 0.9), "car_red")
L.box_ext("Props", "GateBeam", -41.5, -30.5, 6.6, 7.4, -50.6, -49.4, "car_red", collide=False)
L.box_ext("Props", "GateRoof", -42, -30, 7.4, 8.0, -51.2, -48.8, "black_metal", collide=False)
L.label("ЧАЙНАТАУН", (-36, 5.9, -48.7), size=56, color="Color(1, 0.8, 0.3, 1)")

# --- Пирамида-небоскрёб и полиция ------------------------------------------------------------
L.begin_section("Pyramid")
for i in range(8):
    s = 14 - 1.6 * i
    L.box_ext("Geometry", "Pyramid", 18 - s / 2, 18 + s / 2, i * 8, (i + 1) * 8, -50.5 - s / 2, -50.5 + s / 2, "skyline",
              shadow=i < 2)
L.box_ext("Props", "PyramidSpire", 17.7, 18.3, 64, 78, -50.8, -50.2, "white_paint", collide=False)
L.begin_section("Police")
building(43, 58, -58, -46, 9, "facade_blue")
L.label("ПОЛИЦИЯ", (50.5, 6.5, -45.4), size=64, color="Color(0.6, 0.8, 1, 1)")
L.box_ext("Props", "Steps", 48, 53, 0, 0.3, -46, -45, "stone")
car(46, -43.2, True, "car_black")
car(55, -43.2, True, "car_white")
L.node("Light", "OmniLight3D", "Lights", transform=xform((50.5, 4, -44)), light_color="Color(0.7, 0.85, 1, 1)",
       light_energy="1.6", omni_range="10")

# --- Викторианские домики и квартира игрока ---------------------------------------------------
L.begin_section("Ladies")
for i, (z0, z1) in enumerate(((-30, -24.5), (-24, -18.5), (-10.5, -6))):
    victorian(-58, -46, z0, z1, 9, VICTORIAN[i], +1)
L.room("SFFlat", -57, -46, -17, -11, 0, 4, "parquet", "wallpaper", "ceiling", openings={"E": [(-15, -13, 2.6)]})
L.box_ext("Geometry", "FlatUpper", -57.5, -45.5, 4.4, 9, -17.5, -10.5, "plaster_blue")
gable_roof(-57.5, -45.5, -17.5, -10.5, 9, 2.5)
L.node("Light", "OmniLight3D", "Lights", transform=xform((-51.5, 3.4, -14)), light_color=WARM, light_energy="1.3",
       omni_range="8")
L.begin_section("Ladies2")
for i, (z0, z1) in enumerate(((-30, -24.5), (-24, -18.5), (-18, -12.5), (-12, -6.5))):
    victorian(42, 54, z0, z1, 9, VICTORIAN[(i + 2) % len(VICTORIAN)], -1)

script = L.ext_res("Script", "res://scripts/property.gd")
root = L.node("flat", "Node3D", "Properties", script=script, property_id='"flat"')
L.box(root, "Door", (-45.75, 1.3, -14), (0.3, 2.6, 2.0), "plank", collide=True)
L.node("ForSale", "Label3D", root, transform=xform((-45.3, 3.1, -14), rot_y(90)), pixel_size="0.01",
       modulate="Color(1, 0.9, 0.3, 1)", outline_size="12", font_size="56", text='"ПРОДАЁТСЯ"')
L.node("Spawn", "Marker3D", root, transform=xform((-51, 0.05, -14), rot_y(-90)))
fur = L.node("Furniture", "Node3D", root)
L.interactable("property_door", "FlatDoor", "Entrances", (-44.3, 1.5, -14), (2.4, 3, 3), property_id='"flat"')
for group, items in (("Base", [("Bed", (-55.5, 0.3, -16), (2.0, 0.6, 1.4), "bed_sheet"),
                               ("Rug", (-51, 0.02, -14), (4, 0.04, 3), "red_carpet"),
                               ("Armchair", (-48.2, 0.5, -12), (1.0, 1.0, 1.0), "sofa")]),
                     ("espresso", [("Counter", (-48, 0.5, -16.3), (2.0, 1.0, 0.6), "wood"),
                                   ("Machine", (-48, 1.2, -16.3), (0.4, 0.4, 0.3), "metal")]),
                     ("magnum_safe", [("Safe", (-56.3, 0.6, -12), (0.8, 1.2, 0.8), "metal"),
                                      ("SafeDial", (-55.88, 0.8, -12), (0.04, 0.25, 0.25), "gold")]),
                     ("punching_bag", [("Bag", (-52.5, 1.6, -12), (0.5, 1.2, 0.5), "car_red"),
                                       ("Chain", (-52.5, 2.9, -12), (0.05, 1.4, 0.05), "metal")])):
    g = L.node(group, "Node3D", fur)
    for name, center, size, mat in items:
        L.box(g, name, center, size, mat, collide=False)

# --- Парк, казино, кварталы ------------------------------------------------------------------
L.begin_section("Park")
L.box_ext("Props", "Grass", -31, -5, GROUND, 0.01, -31, -5, "grass", collide=False, shadow=False)
for x, z in ((-26, -26), (-12, -27), (-27, -12), (-11, -11), (-19, -19), (-23, -8), (-8, -20)):
    tree(x, z)
for x, z in ((-18, -28.5), (-18, -7.5)):
    L.box("Props", "Bench", (x, 0.25, z), (2.0, 0.5, 0.6), "wood")
L.begin_section("Casino")
building(8, 30, -29, -7, 10, "brick")
L.label("ФОРТУНА", (7.4, 7, -18), yaw=-90, size=120, color="Color(1, 0.25, 0.2, 1)")
L.label("КАЗИНО", (7.4, 8.8, -18), yaw=-90, size=56, color="Color(1, 0.85, 0.4, 1)")
L.node("Neon", "OmniLight3D", "Lights", transform=xform((5, 6, -18)), light_color="Color(1, 0.3, 0.25, 1)",
       light_energy="2.0", omni_range="12")
L.begin_section("Diner")
building(-58, -46, 10, 22, 4.5, "white_paint")
L.box_ext("Props", "DinerStripe", -46.05, -45.95, 3.0, 3.4, 10, 22, "lamp_red", collide=False, shadow=False)
L.label("ЗАКУСОЧНАЯ", (-45.4, 3.9, 16), yaw=90, size=56, color="Color(1, 0.4, 0.35, 1)")
L.begin_section("Offices")
building(-29, -18, 7, 29, 16, "facade_white")
building(-16, -7, 7, 29, 22, "facade_blue")
building(7, 18, 7, 29, 12, "facade_yellow")
building(20, 29, 7, 29, 18, "facade_pink")
L.begin_section("Warehouse")
building(43, 58, 7, 29, 8, "rust")
L.label("ПОРТ", (42.6, 5.5, 18), yaw=-90, size=96, color="Color(1, 0.85, 0.4, 1)")

# --- Набережная ----------------------------------------------------------------------------
L.begin_section("Wharf")
L.box_ext("Props", "Deck", -60, -41, GROUND, 0.02, 41, 60, "plank", collide=False, shadow=False)
for x, mat in ((-27, "awning_red"), (-19, "awning_green"), (-11, "awning_red")):
    L.box("Props", "Kiosk", (x, 1.25, 50), (3, 2.5, 2), "white_paint")
    L.box_ext("Props", "KioskAwning", x - 1.7, x + 1.7, 2.5, 2.7, 48.4, 51.6, mat, collide=False)
L.label("КРАБЫ", (-19, 3.4, 48.9), size=56, color="Color(1, 0.4, 0.3, 1)")
building(8, 28, 44, 56, 6, "wood")
L.label("ПИРС 39", (18, 4.6, 43.4), yaw=180, size=72, color="Color(1, 0.85, 0.4, 1)")
building(44, 57, 44, 57, 6, "plank")
L.label("ПАРОМ НА АЛЬКАТРАС", (-50, 3.6, 59.6), yaw=180, size=56, color="Color(0.85, 0.9, 1, 1)")
L.label("К МОСТУ ЗОЛОТЫЕ ВОРОТА", (-60.4, 3.6, 0), yaw=90, size=56, color="Color(1, 0.5, 0.35, 1)")
L.label("АЭРОПОРТ", (60.4, 3.6, 0), yaw=-90, size=64, color="Color(1, 0.85, 0.3, 1)")
L.label("АЭРОПОРТ → АЛЯСКА", (60.4, 3.6, 36), yaw=-90, size=56, color="Color(0.6, 0.9, 1, 1)")

# --- Холм: крутая улица, канатный трамвай, башня на вершине ---------------------------------
L.room("SFHill", -16, 16, -112, -95, HILL, 1.1, "paving", "stone", None, openings={"S": [(-5, 5)]})
L.ramp_z("Geometry/SFHill", "HillStreet", -5, 5, -62, 0, -95, HILL, "asphalt")
guards(-16, 16, -112, -95, HILL, gap=(-5, 5))
L.cylinder("Props", "Tower", (0, HILL + 12, -106), 2.5, 24, "white_paint", sides=16)
L.box("Props", "TowerTop", (0, HILL + 24.4, -106), (3.2, 0.8, 3.2), "lamp", collide=False)
L.node("Light", "OmniLight3D", "Lights", transform=xform((0, HILL + 4, -99)), light_color=WARM, light_energy="1.8",
       omni_range="16")
L.label("ТЕЛЕГРАФНЫЙ ХОЛМ", (0, HILL + 5.5, -103.4), size=56, color="Color(0.85, 0.9, 1, 1)")
L.section = "HillHouses"
for k in range(5):
    z0 = -62 - k * 6.6
    base = HILL * (k + 0.5) / 5
    for x0, x1 in ((-20, -5.5), (5.5, 20)):
        L.box_ext("Props", "HillHouse", x0, x1, -3, base + 7, z0 - 6.5, z0, random.choice(VICTORIAN))
        L.box_ext("Props", "HillRoof", x0 - 0.2, x1 + 0.2, base + 7, base + 7.3, z0 - 6.7, z0 + 0.2, "roof_tiles",
                  collide=False)
for x in (-3.3, -1.7):
    L.box_ext("Props", "Rail", x - 0.05, x + 0.05, 0, 0.04, -62, -40, "rail", collide=False, shadow=False)
cable = L.node("CableCar", "AnimatableBody3D", ".", script=L.ext_res("Script", "res://scripts/town/cable_car.gd"))
for i, p in enumerate(((-2.5, 0, -40), (-2.5, 0, -62), (-2.5, HILL, -95), (-2.5, HILL, -100))):
    L.node(f"Stop{i}", "Marker3D", cable, transform=xform(p))

# --- Освобождение: три района ------------------------------------------------------------------
L.wave_zone("ZoneChinatown", (-36, 2, -36), (20, 4, 20),
            spawns=[(-36, 0.1, -56), (-56, 0.1, -36), (-16, 0.1, -36), (-36, 0.1, -16)], barriers=[],
            title="Чайнатаун!", waves=2, first=5, extra=2, rusher=0.35, heavy=1)
L.wave_zone("ZoneWharf", (-36, 2, 36), (20, 4, 20),
            spawns=[(-56, 0.1, 36), (-16, 0.1, 36), (-36, 0.1, 16), (-36, 0.1, 56)], barriers=[],
            title="Набережная!", waves=2, first=5, extra=2, rusher=0.3, heavy=1)
L.wave_zone("ZoneHill", (0, HILL + 2, -103), (32, 4, 17),
            spawns=[(-13, HILL + 0.1, -98), (13, HILL + 0.1, -98), (-13, HILL + 0.1, -110), (13, HILL + 0.1, -110)],
            barriers=[], title="Холм!", waves=2, first=5, extra=2, rusher=0.3, heavy=1)
for kind, pos in (("gunner", (-33, 0, -45)), ("gunner", (-39, 0, -28)), ("gunner", (-28, 0, -38)),
                  ("rusher", (-50, 0, -36)), ("rusher", (-36, 0, -55)),
                  ("gunner", (8, 0, 0)), ("gunner", (-12, 0, 2)), ("gunner", (20, 0, -36)), ("gunner", (0, 0, -48)),
                  ("heavy", (36, 0, -36)),
                  ("gunner", (-45, 0, 36)), ("gunner", (-28, 0, 38)), ("gunner", (-36, 0, 48)), ("rusher", (-20, 0, 34)),
                  ("heavy", (-36, 0, 25)),
                  ("gunner", (3, 6.0, -76)), ("gunner", (-3, HILL, -100)), ("gunner", (8, HILL, -104)),
                  ("gunner", (-9, HILL, -108)), ("rusher", (12, HILL, -99)),
                  ("gunner", (36, 0, 10)), ("gunner", (50, 0, 0)), ("gunner", (36, 0, -14))):
    L.enemy(kind, pos, look_at=(0, pos[1], 0) if pos[2] > -60 else (0, 0, -60))
for kind, pos in (("health", (-36, 0, -30)), ("ammo", (-30, 0, -36)), ("health", (-30, 0, 36)),
                  ("grenade", (-36, 0, 30)), ("health", (6, HILL, -97)), ("ammo", (-6, HILL, -97)),
                  ("ammo", (36, 0, 0))):
    L.pickup(kind, pos)

# --- База: входы на уровни эпизода, аэропорт ------------------------------------------------------
L.interactable("level_entrance", "PortGate", "Entrances", (39, 1.5, 18), (3, 3, 6), level_index="5")
L.interactable("level_entrance", "CasinoDoor", "Entrances", (6, 1.5, -18), (3, 3, 4), level_index="6")
L.interactable("level_entrance", "Ferry", "Entrances", (-50, 1.5, 58.5), (6, 3, 3), level_index="7")
L.interactable("level_entrance", "BridgeRoad", "Entrances", (-58.5, 1.5, 0), (3, 3, 6), level_index="8")
L.interactable("level_entrance", "Helipad", "Entrances", (50.5, 1.5, -43.6), (4, 3, 2.4), level_index="9")
L.label("ВЕРТОЛЁТ ПОЛИЦИИ", (50.5, 8.0, -45.4), size=48, color="Color(0.6, 0.8, 1, 1)")
L.interactable("travel_point", "Airport", "Entrances", (58.5, 1.5, 0), (3, 3, 6), episode="1")
L.interactable("travel_point", "AirportAlaska", "Entrances", (58.5, 1.5, 36), (3, 3, 6), episode="3")

# --- Фонари, дождь, прохожие, машины -----------------------------------------------------------
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
for name in ("Rain", "Civilians", "Traffic"):
    L.node(name, "Node3D", ".", script=L.ext_res("Script", f"res://scripts/town/{name.lower()}.gd"))

# --- Залив вокруг: Алькатрас, мост Золотые Ворота, холмы ----------------------------------------
L.section = "Outskirts"
L.box_ext("Props", "Water", -500, 500, -2, -0.8, 63, 500, "water", collide=False, shadow=False)
L.box_ext("Props", "Water", 63, 500, -2, -0.8, -500, 63, "water", collide=False, shadow=False)
L.box_ext("Props", "Ferry", -56, -44, -1.5, 1.8, 66, 80, "car_white", collide=False)
L.box_ext("Props", "Alcatraz", -110, -10, -2, 6, 220, 300, "stone", collide=False, shadow=False)
L.box_ext("Props", "AlcatrazPrison", -80, -40, 6, 18, 245, 275, "concrete", collide=False, shadow=False)
L.cylinder("Props", "Lighthouse", (-20, 20, 240), 2, 28, "white_paint", collide=False, sides=10)
L.box_ext("Props", "BridgeDeck", -420, -380, 18, 21, -400, 400, "bridge_red", collide=False, shadow=False)
for z in (-120, 120):
    L.box_ext("Props", "BridgeTower", -404, -396, -10, 95, z - 4, z + 4, "bridge_red", collide=False, shadow=False)
for i in range(18):
    x = -150 + i * 18 + random.uniform(-5, 5)
    h = random.uniform(10, 40)
    L.box_ext("Props", "HillHomes", x - 7, x + 7, -2, h, -190 - random.uniform(0, 40), -120, random.choice(VICTORIAN),
              collide=False, shadow=False)

L.node("HubStart", "Marker3D", ".", transform=xform((50.5, 0.05, -40), rot_y(180)))
L.player((2.5, 0.05, 20), 0)
L.waypoint((2.5, 0, 20), (2.5, 0, 2.5), (-33.5, 0, 2.5), (-33.5, 0, 36), (-33.5, 0, 2.5), (-33.5, 0, -33.5),
           (2.5, 0, -33.5), (2.5, 0, -61), (2.5, HILL, -95.5), (2.5, HILL, -97))

MOON_YAW, MOON_PITCH = 210, -36
moon_dir = (math.sin(math.radians(MOON_YAW)) * math.cos(math.radians(MOON_PITCH)), -math.sin(math.radians(MOON_PITCH)),
            math.cos(math.radians(MOON_YAW)) * math.cos(math.radians(MOON_PITCH)))
env = [
    ("ShaderMaterial", "SkyMat_10", {
        "shader": L.ext_res("Shader", "res://materials/night_sky.gdshader"),
        "shader_parameter/moon_direction": f"Vector3({f(moon_dir[0])}, {f(moon_dir[1])}, {f(moon_dir[2])})",
        "shader_parameter/horizon_color": "Color(0.13, 0.13, 0.17, 1)",
    }),
    ("Sky", "Sky_10", {"sky_material": 'SubResource("SkyMat_10")'}),
    ("Environment", "Env_10", {
        "background_mode": "2", "sky": 'SubResource("Sky_10")',
        "ambient_light_source": "2", "ambient_light_color": "Color(0.32, 0.36, 0.48, 1)",
        "ambient_light_energy": "0.6", "tonemap_mode": "2",
        "fog_enabled": "true", "fog_light_color": "Color(0.11, 0.12, 0.16, 1)", "fog_density": "0.013",
        "fog_sky_affect": "0.35",
    }),
]
L.node("WorldEnvironment", "WorldEnvironment", ".", environment='SubResource("Env_10")')
L.node("Moonlight", "DirectionalLight3D", ".",
       transform=xform((0, 40, 0), mul(rot_y(MOON_YAW), rot_x(math.radians(MOON_PITCH)))),
       light_color="Color(0.6, 0.7, 1, 1)", light_energy="0.32", shadow_enabled="true",
       directional_shadow_max_distance="50.0", directional_shadow_mode="1")
L.explosives([(-43.5, 0, -30), (-28.5, 0, -43), (-45, 0, 43), (-28, 0, 43.5), (6.5, 0, -6.5), (-6.5, 0, 6.5),
              (14, HILL, -97.5), (-14, HILL, -110.5), (42.5, 0, 6.5)], pattern="BBC")
L.cars([(-3.8, 0, 22, 0), (39.2, 0, -20, 180), (-39.2, 0, -20, 0)])
L.pickup("weapon", (0, 0, 28), weapon="rpg")
L.write("scenes/levels/level_10_san_francisco.tscn", env, ["pistol", "shotgun", "magnum", "rifle"],
        script_path="res://scripts/town.gd")
