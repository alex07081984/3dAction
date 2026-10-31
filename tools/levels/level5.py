"""Уровень 5 «Город»: открытая карта 120x120 м, 6 улиц (3 вдоль X и 3 вдоль Z), 16 кварталов.
Первый заход — освобождение города (3 места с волнами), потом — база с входами на уровни
и недвижимостью (хибара, квартира, особняк)."""
from levelkit import Level, xform, rot_x, rot_y, f, yaw_to
import math
import random

random.seed(5)
L = Level("Level5Town", {
    "level_index": "4",
    "title": '"Город"',
    "objective": '"Освободите город: зачистите три района"',
})
# Ночь: город освещают фонари, окна домов и витрины.
for g in ("Geometry", "Lights", "Props", "Enemies", "Pickups", "Properties", "Entrances"):
    L.group(g)

GROUND = -0.02
STREETS = (-36, 0, 36)
HALF = 5  # полуширина улицы
COLS = [(-60, -41), (-31, -5), (5, 31), (41, 60)]
ROWS = [(-60, -41), (-31, -5), (5, 31), (41, 60)]
CARS = ["car_red", "car_blue", "car_white", "car_black"]
LIGHT = "Color(1, 0.9, 0.75, 1)"


def gable_roof(x0, x1, z0, z1, h, rise, mat="roof_tiles", parent="Geometry"):
    """Двускатная крыша, конёк вдоль X."""
    half = (z1 - z0) / 2
    theta = math.atan2(rise, half)
    length = math.hypot(half, rise) + 0.6
    cz = (z0 + z1) / 2
    for sign in (-1, 1):
        zc = cz + sign * half / 2
        rows = rot_x(-theta if sign < 0 else theta)
        L.box(parent, "Roof", ((x0 + x1) / 2, h + rise / 2 + 0.1, zc), (x1 - x0 + 0.8, 0.25, length), mat, rows=rows)
    # Фронтоны: ступенчато закрываем треугольники по торцам.
    for x in (x0 + 0.1, x1 - 0.1):
        for i in range(4):
            t = (i + 0.5) / 4
            L.box(parent, "Gable", (x, h + rise * t * 0.9, cz), (0.2, rise / 4, (1 - t) * (z1 - z0)), "plank",
                  collide=False)


def solid_building(x0, x1, z0, z1, h, mat, roof="flat"):
    L.box_ext("Geometry", "Building", x0, x1, 0, h, z0, z1, mat)
    if roof == "flat":
        L.box_ext("Geometry", "RoofSlab", x0 - 0.3, x1 + 0.3, h, h + 0.4, z0 - 0.3, z1 + 0.3, "concrete_dark")
    else:
        gable_roof(x0, x1, z0, z1, h, 2.5)


def sidewalk(block, inner=None):
    """Тротуар вокруг здания (декор поверх асфальта)."""
    x0, x1, z0, z1 = block
    if inner is None:
        L.box_ext("Props", "Sidewalk", x0, x1, GROUND, 0.01, z0, z1, "paving", collide=False, shadow=False)
        return
    bx0, bx1, bz0, bz1 = inner
    for a in ((x0, x1, z0, bz0), (x0, x1, bz1, z1), (x0, bx0, bz0, bz1), (bx1, x1, bz0, bz1)):
        if a[1] - a[0] > 0.05 and a[3] - a[2] > 0.05:
            L.box_ext("Props", "Sidewalk", a[0], a[1], GROUND, 0.01, a[2], a[3], "paving", collide=False, shadow=False)


def tree(x, z, h=None):
    h = h or random.uniform(4, 6.5)
    L.cylinder("Props", "Trunk", (x, h / 2, z), 0.25, h, "tree_trunk", sides=6)
    L.box("Props", "Crown", (x, h, z), (2.8, 2.6, 2.8), "tree_leaves", collide=False)


def car(x, z, along_x, mat):
    size = (4.4, 1.0, 2.0) if along_x else (2.0, 1.0, 4.4)
    cabin = (2.2, 0.65, 1.8) if along_x else (1.8, 0.65, 2.2)
    L.box("Props", "Car", (x, 0.6, z), size, mat)
    L.box("Props", "CarCabin", (x, 1.42, z), cabin, "dark_glass")


def bench(x, z, along_x=True):
    L.box("Props", "Bench", (x, 0.25, z), (2.0, 0.5, 0.6) if along_x else (0.6, 0.5, 2.0), "wood")


def lamp_post(x, z):
    L.cylinder("Props", "Post", (x, 2, z), 0.08, 4, "black_metal")
    L.box("Props", "PostLamp", (x, 4.1, z), (0.4, 0.3, 0.4), "lamp", collide=False)


def interior_light(x, y, z, rng=10.0, energy=1.3):
    L.node("Light", "OmniLight3D", "Lights", transform=xform((x, y, z)), light_color=LIGHT,
           light_energy=f(energy), omni_range=f(rng))


def sign(text, pos, yaw=0.0, size=72, color="Color(1, 1, 1, 1)"):
    L.label(text, pos, yaw=yaw, size=size, color=color)


# --- Земля, улицы, разметка ------------------------------------------------------------
# Асфальт разбит на 3x3 участка: ночью на каждый падает свет лишь нескольких фонарей
# (в рендере Compatibility на один объект действует не больше 8 источников света).
TILES = (-63, -21, 21, 63)


def tile_of(x, z):
    return f"Ground{sum(x >= t for t in TILES[1:3])}{sum(z >= t for t in TILES[1:3])}"


marks = []
for c in STREETS:
    for a, b in ((-60, -HALF - 1), (HALF + 1, 60)):
        for start in range(int(a), int(b) - 2, 6):
            marks.append(("Dash", c - 0.1, c + 0.1, start, start + 3))
            marks.append(("Dash", start, start + 3, c - 0.1, c + 0.1))
for cx in STREETS:
    for cz in STREETS:
        for i in range(5):
            o = -4 + i * 2
            marks.append(("Zebra", cx + o - 0.4, cx + o + 0.4, cz + HALF + 0.2, cz + HALF + 1.6))
for i in range(3):
    for j in range(3):
        L.begin_section(f"Ground{i}{j}")
        L.box_ext("Geometry", "Asphalt", TILES[i], TILES[i + 1], GROUND - 0.5, GROUND, TILES[j], TILES[j + 1], "asphalt")
        for name, x0, x1, z0, z1 in marks:
            if tile_of((x0 + x1) / 2, (z0 + z1) / 2) == f"Ground{i}{j}":
                L.box_ext("Props", name, x0, x1, GROUND, 0.01, z0, z1, "road_line", collide=False, shadow=False)
L.begin_section("Ground")
# Граница города: каменный парапет и невидимые стены.
for x0, x1, z0, z1 in ((-63, 63, -63, -62), (-63, 63, 62, 63), (-63, -62, -62, 62), (62, 63, -62, 62)):
    L.box_ext("Geometry", "TownWall", x0, x1, GROUND, 1.2, z0, z1, "stone")
    L.invisible_wall("Geometry", "Guard", ((x0 + x1) / 2, 3, (z0 + z1) / 2), (x1 - x0, 6, z1 - z0))

# --- Кварталы ------------------------------------------------------------------------
def block(c, r):
    return COLS[c][0], COLS[c][1], ROWS[r][0], ROWS[r][1]


# (0,0) — парк и ворота к особняку (вход на уровень 4).
L.begin_section("ParkNW")
b = block(0, 0)
L.box_ext("Props", "Grass", b[0], b[1], GROUND, 0.01, b[2], b[3], "grass", collide=False, shadow=False)
for x, z in ((-56, -56), (-46, -55), (-57, -45), (-44, -46), (-51, -44)):
    tree(x, z)
L.box("Props", "Plinth", (-51, 0.6, -51), (1.4, 1.2, 1.4), "stone")
L.box("Props", "Statue", (-51, 2.2, -51), (0.7, 2.0, 0.7), "gold")
for x in (-54.6, -45.4):
    L.box("Props", "GatePillar", (x, 2.2, -62.2), (1.0, 4.4, 1.0), "stone")
for i in range(17):
    L.box("Props", "GateBar", (-54 + i * 0.5, 1.6, -62.3), (0.06, 3.2, 0.06), "black_metal", collide=False)
sign("ПОМЕСТЬЕ «ЗОЛОТОЙ КЛЮЧ»", (-50, 4.6, -62.0), size=48, color="Color(0.95, 0.8, 0.4, 1)")
L.interactable("level_entrance", "MansionGate", "Entrances", (-50, 1.5, -60), (6, 3, 3), level_index="3")

# (1,0) — мэрия (можно зайти).
b = block(1, 0)
sidewalk(b, (-28, -8, -58, -44))
L.room("TownHall", -28, -8, -58, -44, 0, 7, "floor_tiles", "plaster_yellow", "ceiling",
       openings={"S": [(-19.5, -16.5, 3)]}, windows={"W": (1.2, 5.5), "E": (1.2, 5.5)})
L.box_ext("Geometry", "TownHallRoof", -28.5, -7.5, 7.4, 8.2, -58.5, -43.5, "roof_tiles")
for x in (-21, -15):
    L.cylinder("Props", "Column", (x, 3.5, -43), 0.35, 7, "marble")
L.box_ext("Props", "Portico", -23, -13, 7, 7.5, -44, -42, "plaster_yellow", collide=False)
L.box("Props", "Desk", (-18, 0.45, -54), (5, 0.9, 1.2), "wood")
for x in (-25, -11):
    L.box("Props", "Bench", (x, 0.25, -50), (0.6, 0.5, 4), "wood")
L.box("Props", "Flag", (-18, 4.2, -57.7), (2.4, 1.4, 0.05), "car_red", collide=False)
sign("МЭРИЯ", (-18, 6.2, -42.9), yaw=0, size=80, color="Color(0.3, 0.25, 0.15, 1)")
interior_light(-18, 6.5, -51, 14, 1.6)

# (2,0) — небоскрёб (вход на уровень 3).
L.begin_section("Tower")
b = block(2, 0)
sidewalk(b, (9, 27, -58, -44))
solid_building(9, 27, -58, -44, 42, "skyline")
L.box_ext("Props", "TowerDoor", 15.5, 20.5, 0, 3.2, -43.95, -43.85, "dark_glass", collide=False)
L.box_ext("Props", "Canopy", 14, 22, 3.4, 3.6, -44, -41.5, "metal", collide=False)
sign("ВЕРТИКАЛЬ ПЛАЗА", (18, 4.6, -43.8), size=64, color="Color(0.95, 0.85, 0.5, 1)")
L.interactable("level_entrance", "TowerDoor", "Entrances", (18, 1.5, -42), (5, 3, 3), level_index="2")

# (3,0) — особняк-недвижимость.
L.begin_section("VillaYard")
b = block(3, 0)
L.box_ext("Props", "Lawn", b[0], b[1], GROUND, 0.01, b[2], b[3], "grass", collide=False, shadow=False)
for x0, x1, z0, z1 in ((41, 60, -60, -59.4), (59.4, 60, -60, -41), (41, 41.6, -60, -41)):
    L.box_ext("Geometry", "Hedge", x0, x1, 0, 1.4, z0, z1, "hedge")
L.box_ext("Geometry", "Hedge", 41, 47.5, 0, 1.4, -41.6, -41, "hedge")
L.box_ext("Geometry", "Hedge", 52.5, 60, 0, 1.4, -41.6, -41, "hedge")
L.room("Villa", 43, 55, -58, -49, 0, 4, "parquet", "plaster_white", "ceiling",
       openings={"S": [(47.5, 50.5, 2.8)]}, windows={"N": (1.0, 3.2), "E": (1.0, 3.2)})
gable_roof(43, 55, -58, -49, 4.4, 2.5)
L.box_ext("Props", "Path", 48, 50, GROUND, 0.02, -49, -41, "paving", collide=False, shadow=False)

# (0,1) — жилой дом.
L.begin_section("BlockW1")
b = block(0, 1)
sidewalk(b, (-58, -43, -29, -7))
solid_building(-58, -43, -29, -7, 12, "facade_pink")

# (1,1) — квартира-недвижимость: первый этаж жилого дома.
b = block(1, 1)
sidewalk(b, (-28, -8, -28, -8))
L.room("Apartment", -28, -8, -28, -8, 0, 3.5, "parquet", "plaster_blue", "ceiling",
       openings={"E": [(-19.5, -16.5, 2.6)]}, windows={"N": (1.0, 2.8), "S": (1.0, 2.8)})
L.box_ext("Geometry", "UpperFloors", -28.5, -7.5, 3.9, 11, -28.5, -7.5, "facade_blue")
L.box_ext("Geometry", "AptRoof", -28.8, -7.2, 11, 11.4, -28.8, -7.2, "concrete_dark")
L.box_ext("Props", "AptPartition", -18.2, -17.8, 0, 3.5, -28, -21.5, "plaster_blue", collide=True)

# (2,1) — магазин.
b = block(2, 1)
sidewalk(b, (8, 28, -28, -8))
L.room("Shop", 8, 28, -28, -8, 0, 4.5, "floor_tiles", "plaster_green", "ceiling",
       openings={"W": [(-19.5, -16.5, 2.8)]}, windows={"W": (0.8, 3.6)})
L.box_ext("Geometry", "ShopRoof", 7.7, 28.3, 4.5, 6, -28.3, -7.7, "facade_yellow")
for z in (-24, -20, -12):
    L.box("Props", "Shelf", (19, 1.0, z), (12, 2.0, 0.8), "white_paint")
    L.box("Props", "Goods", (19, 1.6, z), (11.6, 0.4, 0.9), "car_red", collide=False)
L.box("Props", "Counter", (10.5, 0.5, -11), (1.2, 1.0, 4), "wood")
L.box("Props", "Fridge", (27.2, 1.0, -18), (1.2, 2.0, 6), "lamp_cold")
L.box_ext("Props", "Awning", 7.0, 8.0, 3.2, 3.4, -27, -9, "awning_green", collide=False)
sign("ПРОДУКТЫ", (7.6, 5.2, -18), yaw=-90, size=80, color="Color(0.15, 0.4, 0.2, 1)")
interior_light(18, 4.2, -18, 14, 1.5)

# (3,1) — полиция.
b = block(3, 1)
sidewalk(b, (44, 57, -28, -8))
L.room("Police", 44, 57, -28, -8, 0, 4.5, "floor_tiles", "plaster_blue", "ceiling",
       openings={"W": [(-19.5, -16.5, 2.8)]}, windows={"W": (1.0, 3.4)})
L.box_ext("Geometry", "PoliceRoof", 43.7, 57.3, 4.5, 5.3, -28.3, -7.7, "concrete_dark")
L.box("Props", "Desk", (48, 0.45, -13), (3, 0.9, 1.4), "wood")
L.box("Props", "Desk", (48, 0.45, -23), (3, 0.9, 1.4), "wood")
for z in (-26.5, -23.5):
    L.box_ext("Props", "CellBars", 52, 56.9, 0, 3, z - 0.05, z + 0.05, "black_metal", collide=False)
for x in range(52, 57):
    L.box("Props", "Locker", (x + 0.4, 1, -8.6), (0.9, 2, 0.6), "metal")
L.box("Props", "PoliceCar", (38.5, 0.6, -22), (2.0, 1.0, 4.4), "car_white")
L.box("Props", "PoliceCabin", (38.5, 1.42, -22), (1.8, 0.65, 2.2), "dark_glass")
L.box("Props", "Siren", (38.5, 1.82, -22), (1.2, 0.15, 0.3), "car_blue", collide=False)
sign("ПОЛИЦИЯ", (43.6, 4.0, -18), yaw=-90, size=80, color="Color(0.15, 0.25, 0.6, 1)")
interior_light(50, 4.2, -18, 12, 1.5)

# (0,2) — хибара-недвижимость и свалка.
L.begin_section("Junkyard")
b = block(0, 2)
L.box_ext("Props", "Dirt", b[0], b[1], GROUND, 0.01, b[2], b[3], "gravel", collide=False, shadow=False)
for z0, z1 in ((5, 5.4), (30.6, 31)):
    L.box_ext("Geometry", "Fence", -60, -41, 0, 1.6, z0, z1, "plank")
L.box_ext("Geometry", "Fence", -60, -59.6, 0, 1.6, 5, 31, "plank")
L.box("Props", "JunkCar", (-56, 0.5, 27), (4.4, 0.9, 2.0), "rust")
L.box("Props", "Tires", (-46, 0.4, 27.5), (1.6, 0.8, 1.6), "rubber")
L.box("Props", "Scrap", (-46, 0.6, 8.5), (2.5, 1.2, 2.0), "rust")
L.room("Shack", -56, -50, 12, 18, 0, 2.8, "plank", "plank", "plank", openings={"E": [(14, 16, 2.2)]})
gable_roof(-56, -50, 12, 18, 2.8, 1.6, mat="rust")

# (1,2) — бар.
b = block(1, 2)
sidewalk(b, (-28, -10, 8, 24))
L.room("Bar", -28, -10, 8, 24, 0, 4.2, "parquet", "plaster_pink", "ceiling",
       openings={"E": [(14.5, 17.5, 2.8)]}, windows={"E": (1.0, 3.0)})
L.box_ext("Geometry", "BarRoof", -28.3, -9.7, 4.2, 5.0, 7.7, 24.3, "concrete_dark")
L.box("Props", "BarCounter", (-25.5, 0.55, 16), (1.2, 1.1, 10), "wood")
L.box("Props", "BarShelf", (-27.6, 1.8, 16), (0.4, 2.0, 9), "wood", collide=False)
L.box("Props", "PoolTable", (-16, 0.45, 20.5), (3.2, 0.9, 1.8), "awning_green")
for x, z in ((-19, 11), (-14, 11), (-19, 15)):
    L.box("Props", "Table", (x, 0.4, z), (1.2, 0.8, 1.2), "wood")
L.box_ext("Props", "Awning", -10, -9, 3.0, 3.2, 9, 23, "awning_red", collide=False)
sign("БАР «ГИЛЬЗА»", (-9.6, 4.3, 16), yaw=90, size=72, color="Color(0.75, 0.15, 0.1, 1)")
interior_light(-19, 3.9, 16, 12, 1.4)
L.begin_section("BarYard")
solid_building(-28, -12, 26, 30, 5, "facade_white")

# (2,2) — павильон метро (вход на уровень 2) и сквер.
L.begin_section("MetroSquare")
b = block(2, 2)
L.box_ext("Props", "Grass", 17, 31, GROUND, 0.01, 5, 31, "grass", collide=False, shadow=False)
L.box_ext("Props", "Plaza", 5, 17, GROUND, 0.01, 5, 31, "paving", collide=False, shadow=False)
L.box_ext("Props", "Plaza", 17, 31, GROUND, 0.01, 5, 7, "paving", collide=False, shadow=False)
for x, z in ((21, 12), (27, 16), (22, 24), (28, 28)):
    tree(x, z)
bench(24, 9)
bench(19, 20, along_x=False)
L.room("MetroPavilion", 8, 16, 9, 17, 0, 4, "floor_tiles", "tiles_wall", "ceiling",
       openings={"N": [(10.5, 13.5, 3)]}, windows={"W": (0.8, 3.4), "E": (0.8, 3.4)})
L.box_ext("Props", "EscalatorPit", 10.5, 13.5, 0, 0.05, 12, 16.5, "metal", collide=False)
L.box("Props", "MetroSign", (12, 5.2, 9), (1.4, 1.4, 0.2), "white_paint", collide=False)
sign("М", (12, 5.2, 8.85), size=150, color="Color(0.95, 0.15, 0.15, 1)")
interior_light(12, 3.8, 13, 9, 1.2)
L.interactable("level_entrance", "MetroEntrance", "Entrances", (12, 1.5, 14), (3, 3, 4), level_index="1")

# (3,2) — жилой дом.
L.begin_section("BlockE2")
b = block(3, 2)
sidewalk(b, (44, 57, 8, 28))
solid_building(44, 57, 8, 28, 9, "facade_white")

# (0,3) — парк.
L.begin_section("ParkSW")
b = block(0, 3)
L.box_ext("Props", "Grass", b[0], b[1], GROUND, 0.01, b[2], b[3], "grass", collide=False, shadow=False)
for x, z in ((-57, 44), (-48, 46), (-55, 55), (-44, 57), (-50, 52)):
    tree(x, z)
L.box("Props", "Slide", (-46, 1.0, 51), (1.0, 2.0, 3.0), "car_red")
L.box("Props", "Sandbox", (-55, 0.15, 49), (3, 0.3, 3), "plank")
bench(-50, 43)

# (1,3) — коллектор (вход на уровень 1).
b = block(1, 3)
sidewalk(b, (-26, -14, 44, 54))
L.room("Collector", -26, -14, 44, 54, 0, 4, "concrete_dark", "brick", "concrete",
       openings={"E": [(47.5, 50.5, 2.8)]})
L.cylinder("Props", "Hatch", (-20, 0.02, 49), 0.8, 0.04, "metal", collide=False, sides=16)
L.box("Props", "HatchRim", (-20, 0.05, 49), (2.0, 0.05, 2.0), "hazard", collide=False)
L.box("Props", "Pipes", (-25.6, 2.5, 49), (0.5, 0.5, 9), "pipe", collide=False)
sign("КОЛЛЕКТОР 7", (-13.6, 3.3, 49), yaw=90, size=64, color="Color(0.9, 0.85, 0.6, 1)")
interior_light(-20, 3.8, 49, 9, 1.2)
L.interactable("level_entrance", "SewerHatch", "Entrances", (-20, 1.5, 49), (3, 3, 3), level_index="0")
L.begin_section("CollectorYard")
solid_building(-30, -27, 42, 58, 6, "facade_yellow")

# (2,3) — ряд лавок.
L.begin_section("ShopsS")
b = block(2, 3)
sidewalk(b, (9, 28, 44, 57))
solid_building(9, 28, 44, 57, 6, "facade_yellow")
for z0 in (45, 50.5):
    L.box_ext("Props", "Awning", 8.0, 9.0, 2.8, 3.0, z0, z0 + 4.5, ["awning_red", "awning_green"][int(z0) % 2],
              collide=False)
# Остановка — здесь игрок начинает.
L.box_ext("Props", "BusShelterRoof", 5.5, 7.5, 2.5, 2.6, 52, 58, "metal", collide=False)
L.box_ext("Props", "BusShelterBack", 7.4, 7.5, 0, 2.5, 52, 58, "glass", collide=False)
sign("ОСТАНОВКА", (6.5, 2.9, 55), yaw=-90, size=40)

# (3,3) — жилой дом.
L.begin_section("BlockE3")
b = block(3, 3)
sidewalk(b, (44, 57, 44, 57))
solid_building(44, 57, 44, 57, 8, "facade_blue", roof="gable")

# --- Улицы: машины, деревья, фонари ------------------------------------------------------
L.begin_section("StreetProps")
parked = [(3.6, 30, False), (-3.6, 18, False), (3.6, -22, False), (-3.6, -14, False), (16, -3.6, True),
          (-16, 3.6, True), (24, 3.6, True), (-26, -3.6, True), (46, 3.6, True), (33, 18, False), (39, -26, False),
          (-33, 20, False), (-39, -20, False), (-14, -32.4, True), (14, -39.6, True), (20, 39.6, True),
          (-20, 32.4, True), (52, -32.4, True)]
for i, (x, z, along_x) in enumerate(parked):
    car(x, z, along_x, CARS[i % 4])
for x, z in ((-6.5, 33), (6.5, -33), (-33, 6.5), (33, -6.5), (-39, 39), (39, 39), (-39, -39), (39, -39)):
    tree(x, z)

# Уличные фонари: по одному каждые 14 м, через сторону, у края тротуара; кронштейн — над дорогой.
lamps = L.group("StreetLamps")
L.nodes[-1] = L.nodes[-1] + '\nscript = ' + L.ext_res("Script", "res://scripts/street_lamps.gd")
SKIP_LAMPS = {(56, -42), (-42, 6), (42, -56), (-56, 30)}  # там заборы дворов
n = 0
for c in STREETS:
    for i, t in enumerate(range(-56, 57, 14)):
        if any(abs(t - s) < 6 for s in STREETS):
            continue
        side = 1 if i % 2 == 0 else -1
        for pos, target in (((c + side * 5.6, GROUND, t), (c, t)), ((t, GROUND, c - side * 5.6), (t, c))):
            if (round(pos[0]), round(pos[2])) in SKIP_LAMPS:
                continue
            L.node(f"Lamp{n:02d}", "Marker3D", lamps, transform=xform(pos, rot_y(yaw_to(pos, target))))
            n += 1

# --- Недвижимость --------------------------------------------------------------------------
L.section = None


def property_node(pid, door_center, door_size, label_pos, label_yaw, spawn, spawn_yaw, entry_center, entry_size):
    script = L.ext_res("Script", "res://scripts/property.gd")
    root = L.node(pid, "Node3D", "Properties", script=script, property_id=f'"{pid}"')
    L.box(root, "Door", door_center, door_size, "plank", collide=True)
    L.node("ForSale", "Label3D", root, transform=xform(label_pos, rot_y(label_yaw)), pixel_size="0.01",
           modulate="Color(1, 0.9, 0.3, 1)", outline_size="12", font_size="56", text='"ПРОДАЁТСЯ"')
    L.node("Spawn", "Marker3D", root, transform=xform(spawn, rot_y(spawn_yaw)))
    furniture = L.node("Furniture", "Node3D", root)
    L.interactable("property_door", f"{pid.capitalize()}Door", "Entrances", entry_center, entry_size,
                   property_id=f'"{pid}"')
    return furniture


def group(furniture, name):
    return L.node(name, "Node3D", furniture)


def item(parent, name, center, size, mat):
    L.box(parent, name, center, size, mat, collide=False)


# Хибара: дверь на восточной стене (x = -50), вход с улицы x = -36.
fur = property_node("shack", (-49.75, 1.1, 15), (0.3, 2.2, 2.0), (-49.3, 2.6, 15), 90, (-53, 0.05, 15), -90,
                    (-48.3, 1.5, 15), (2.4, 3, 3))
base = group(fur, "Base")
item(base, "Mattress", (-55, 0.12, 13.2), (1.8, 0.24, 1.2), "bed_sheet")
item(base, "Crate", (-51, 0.35, 12.6), (0.8, 0.7, 0.8), "crate")
bed = group(fur, "bed")
item(bed, "BedFrame", (-55, 0.3, 16.6), (2.0, 0.6, 1.4), "wood")
item(bed, "Blanket", (-55, 0.64, 16.6), (1.9, 0.1, 1.3), "blanket")
stash = group(fur, "stash")
for i in range(3):
    item(stash, "AmmoBox", (-52.5 + i * 0.7, 0.25, 17.4), (0.6, 0.5, 0.4), "awning_green")
lamp = group(fur, "lamp")
item(lamp, "Generator", (-51, 0.4, 17.3), (0.9, 0.8, 0.6), "car_red")
item(lamp, "Bulb", (-53, 2.6, 15), (0.3, 0.3, 0.3), "lamp")
L.node("Light", "OmniLight3D", lamp, transform=xform((-53, 2.4, 15)), light_color=LIGHT, light_energy="1.2",
       omni_range="6")

# Квартира: дверь на восточной стене (x = -8), вход с центральной улицы.
fur = property_node("apartment", (-7.75, 1.3, -18), (0.3, 2.6, 3.0), (-7.3, 3.1, -18), 90, (-11, 0.05, -18), -90,
                    (-5.8, 1.5, -18), (2.6, 3, 3.6))
base = group(fur, "Base")
item(base, "Bed", (-25.5, 0.3, -25.5), (2.0, 0.6, 2.4), "bed_sheet")
item(base, "Rug", (-14, 0.02, -18), (5, 0.02, 4), "red_carpet")
item(base, "Table", (-13, 0.4, -12), (1.6, 0.8, 1.0), "wood")
gym = group(fur, "gym")
item(gym, "Bench", (-24, 0.35, -12), (0.6, 0.7, 2.0), "rubber")
item(gym, "Barbell", (-24, 1.1, -12), (2.2, 0.08, 0.08), "black_metal")
item(gym, "Weights", (-26.6, 0.6, -12), (0.6, 1.2, 1.6), "metal")
guns = group(fur, "gun_cabinet")
item(guns, "Cabinet", (-27.6, 1.1, -19), (0.6, 2.2, 3.0), "wood")
for i in range(3):
    item(guns, "Gun", (-27.25, 1.4, -20 + i), (0.08, 1.2, 0.15), "black_metal")
tv = group(fur, "tv")
item(tv, "TV", (-17.9, 1.5, -10), (0.1, 1.0, 1.8), "monitor")
item(tv, "Sofa", (-12, 0.4, -10), (1.0, 0.8, 3.0), "sofa")

# Особняк: дверь на южной стене (z = -49), сад с бассейном справа.
fur = property_node("mansion", (49, 1.4, -48.75), (3.0, 2.8, 0.3), (49, 3.4, -48.3), 0, (49, 0.05, -52), 180,
                    (49, 1.5, -46.8), (3.6, 3, 2.6))
base = group(fur, "Base")
item(base, "Rug", (49, 0.02, -54), (7, 0.02, 5), "red_carpet")
item(base, "Sofa", (46, 0.45, -54), (1.0, 0.9, 4.0), "sofa")
item(base, "Chandelier", (49, 3.6, -53.5), (1.4, 0.5, 1.4), "gold")
target = group(fur, "range")
for x in (45, 47.5, 50):
    item(target, "Target", (x, 1.4, -57.8), (1.0, 1.4, 0.1), "awning_red")
item(target, "ShootingBench", (47.5, 0.5, -55.5), (5, 1.0, 0.5), "wood")
armory = group(fur, "armory")
item(armory, "Wardrobe", (54.5, 1.2, -55), (0.8, 2.4, 3.0), "wood")
for i in range(3):
    item(armory, "Vest", (54.0, 1.4, -56 + i), (0.15, 0.8, 0.6), "car_black")
pool = group(fur, "pool")
item(pool, "PoolRim", (57.5, 0.12, -53.5), (3.6, 0.24, 7.0), "stone")
item(pool, "PoolWater", (57.5, 0.2, -53.5), (3.0, 0.1, 6.4), "pool_water")
item(pool, "Lounger", (56, 0.25, -45.5), (0.8, 0.5, 2.0), "white_paint")

# Точка появления в режиме базы.
L.node("HubStart", "Marker3D", ".", transform=xform((0, 0.05, 54), rot_y(0)))

# --- Враги (только в бою; в режиме базы удаляются) ------------------------------------------
E = [
    ("gunner", (3.6, 0, 27), (0, 0, 56)), ("gunner", (-3.6, 0, 15), (0, 0, 56)), ("rusher", (2, 0, 36), (0, 0, 56)),
    ("gunner", (-3, 0, -12), (0, 0, 10)), ("gunner", (3, 0, -24), (0, 0, 10)),
    ("gunner", (16, 0, -6), (0, 0, 0)), ("gunner", (24, 0, 6), (0, 0, 0)), ("gunner", (-16, 0, 6), (0, 0, 0)),
    ("gunner", (-26, 0, -6), (0, 0, 0)), ("rusher", (46, 0, 1), (36, 0, 0)), ("gunner", (54, 0, -2), (36, 0, 0)),
    ("rusher", (36, 0, 18), (36, 0, 0)), ("gunner", (33, 0, -18), (36, 0, 0)), ("gunner", (39, 0, -28), (36, 0, 0)),
    ("gunner", (-36, 0, 22), (-36, 0, 0)), ("gunner", (-33, 0, -22), (-36, 0, 0)),
    ("gunner", (-14, 0, -35), (0, 0, -36)), ("gunner", (14, 0, -37), (0, 0, -36)), ("heavy", (30, 0, -36), (0, 0, -36)),
    ("gunner", (-20, 0, 38), (0, 0, 36)), ("gunner", (20, 0, 36), (0, 0, 36)),
    ("gunner", (-14, 0, -50), (-18, 0, -42)), ("gunner", (-22, 0, -54), (-18, 0, -42)),
    ("gunner", (12, 0, -22), (5, 0, -18)), ("rusher", (24, 0, -14), (5, 0, -18)),
    ("gunner", (50, 0, -12), (41, 0, -18)), ("heavy", (52, 0, -20), (41, 0, -18)),
    ("gunner", (-22, 0, 12), (-5, 0, 16)), ("rusher", (-14, 0, 20), (-5, 0, 16)),
    ("gunner", (-23, 0, 46), (-5, 0, 49)),
]
for kind, pos, target in E:
    L.enemy(kind, pos, look_at=target)
for kind, pos in (("health", (-3, 0, 40)), ("ammo", (3, 0, 8)), ("health", (40, 0, 6)), ("ammo", (34, 0, -30)),
                  ("health", (-6, 0, -40)), ("ammo", (-40, 0, 2)), ("health", (20, 0, -20)), ("ammo", (-24, 0, 20))):
    L.pickup(kind, pos)

L.wave_zone("ZoneSquare", (0, 2, 0), (20, 4, 20),
            spawns=[(0, 0.1, -22), (0, 0.1, 22), (-22, 0.1, 0), (22, 0.1, 0)], barriers=[],
            title="Центральная площадь!", waves=2, first=5, extra=2, rusher=0.35)
L.wave_zone("ZoneEast", (36, 2, 0), (18, 4, 18),
            spawns=[(36, 0.1, -24), (36, 0.1, 24), (56, 0.1, 0), (20, 0.1, 0)], barriers=[],
            title="Восточный перекрёсток!", waves=2, first=5, extra=2, rusher=0.3, heavy=1)
L.wave_zone("ZoneTownHall", (0, 2, -36), (18, 4, 18),
            spawns=[(-24, 0.1, -36), (24, 0.1, -36), (0, 0.1, -56), (0, 0.1, -20)], barriers=[],
            title="Площадь у мэрии!", waves=2, first=6, extra=2, rusher=0.3, heavy=1)

L.player((0, 0.05, 56), 0)

# --- Вокруг города: поля, деревья, дальние дома ---------------------------------------------
L.section = "Outskirts"
L.box_ext("Props", "Field", -300, 300, -2, GROUND - 0.6, -300, 300, "grass", collide=False, shadow=False)
for i in range(46):
    side = random.randrange(4)
    t = random.uniform(-70, 70)
    d = random.uniform(66, 90)
    x, z = [(t, -d), (t, d), (-d, t), (d, t)][side]
    h = random.uniform(5, 9)
    L.cylinder("Props", "Trunk", (x, h / 2 - 0.6, z), 0.35, h, "tree_trunk", collide=False, sides=6)
    L.box("Props", "Crown", (x, h, z), (4, 3.6, 4), "tree_leaves", collide=False)
for i in range(18):
    angle = i / 18 * math.tau
    dist = random.uniform(150, 220)
    cx, cz = math.sin(angle) * dist, math.cos(angle) * dist
    w, d = random.uniform(15, 30), random.uniform(15, 30)
    L.box_ext("Props", "FarBuilding", cx - w / 2, cx + w / 2, -2, random.uniform(15, 60), cz - d / 2, cz + d / 2,
              "skyline", collide=False, shadow=False)

L.waypoint((0, 0, 56), (0, 0, 40), (0, 0, 10), (0, 0, 0), (12, 0, 0), (36, 0, 0), (36, 0, -20), (36, 0, -36),
           (0, 0, -36), (-18, 0, -41), (-18, 0, -48), (-18, 0, -41), (-36, 0, -36), (-36, 0, 15),
           (-46, 0, 15), (-48.5, 0, 15))

# Луна светит с северо-запада; её диск на небе — в том же направлении.
MOON_YAW, MOON_PITCH = 150, -38
# Направление на луну — ось +Z источника света (свет летит по -Z).
moon_dir = (math.sin(math.radians(MOON_YAW)) * math.cos(math.radians(MOON_PITCH)),
            -math.sin(math.radians(MOON_PITCH)),
            math.cos(math.radians(MOON_YAW)) * math.cos(math.radians(MOON_PITCH)))
env = [
    ("ShaderMaterial", "SkyMat_5", {
        "shader": L.ext_res("Shader", "res://materials/night_sky.gdshader"),
        "shader_parameter/moon_direction": f"Vector3({f(moon_dir[0])}, {f(moon_dir[1])}, {f(moon_dir[2])})",
    }),
    ("Sky", "Sky_5", {"sky_material": 'SubResource("SkyMat_5")'}),
    ("Environment", "Env_5", {
        "background_mode": "2", "sky": 'SubResource("Sky_5")',
        "ambient_light_source": "2", "ambient_light_color": "Color(0.3, 0.36, 0.52, 1)",
        "ambient_light_energy": "0.6", "tonemap_mode": "2",
        "fog_enabled": "true", "fog_light_color": "Color(0.05, 0.06, 0.1, 1)", "fog_density": "0.011",
        "fog_sky_affect": "0.25",
    }),
]


def mul(a, b):
    return [[sum(a[i][k] * b[k][j] for k in range(3)) for j in range(3)] for i in range(3)]


L.node("WorldEnvironment", "WorldEnvironment", ".", environment='SubResource("Env_5")')
L.node("Moonlight", "DirectionalLight3D", ".",
       transform=xform((0, 40, 0), mul(rot_y(MOON_YAW), rot_x(math.radians(MOON_PITCH)))),
       light_color="Color(0.6, 0.7, 1, 1)", light_energy="0.32", shadow_enabled="true",
       directional_shadow_max_distance="50.0", directional_shadow_mode="1")
# Взрывоопасные бочки и баллоны (места подобраны у стен рядом с постами врагов).
L.explosives([(4.99, -0.02, 27.57), (-5.03, -0.02, -11.94), (17.06, -0.02, -7.06), (-17.06, -0.02, 7.06), (47.06, -0.02, 2.06), (40.42, -0.02, -27.17), (-15.06, -0.02, -33.94), (20, -0.02, 38), (-20.94, 0, -52.94), (22.94, 0, -12.94), (50.16, 0, -21.84), (-14.77, 0, 21.85)])

L.write("scenes/levels/level_5_town.tscn", env, ["pistol", "shotgun", "deagle"], script_path="res://scripts/town.gd")
