"""Уровень 12 «Заброшенный городок» (эпизод 3, Аляска): городок золотой лихорадки под снегом.
Старт на хребте у хижины охотника — там лежит снайперская винтовка, с хребта видна главная улица.
Потом улица с салуном, банком и отелем, а за ней площадь с церковью, водонапорной башней
и копром шахты: там с вышки на вышку перебегает босс Снайпер."""
from levelkit import Level, xform, rot_x, rot_y, rot_z, f, yaw_to
import math
import random

random.seed(12)
L = Level("Level12GhostTown", {
    "level_index": "12",
    "title": '"Заброшенный городок"',
    "objective": '"Возьмите винтовку охотника и зачистите городок"',
})
for g in ("Geometry", "Lights", "Props", "Enemies", "Pickups"):
    L.group(g)

FIRE = "Color(1, 0.55, 0.25, 1)"
WARM = "Color(1, 0.75, 0.45, 1)"
SIGN = "Color(1, 0.85, 0.45, 1)"


def mul(a, b):
    return [[sum(a[i][k] * b[k][j] for k in range(3)) for j in range(3)] for i in range(3)]


def building(x0, x1, z0, z1, h, mat, sign, front, false_front=True, parapet=False):
    """Дом у улицы. front: 'E' — фасад смотрит на +X, 'W' — на −X."""
    L.box_ext("Props", "House", x0, x1, 0, h, z0, z1, mat)
    L.box_ext("Props", "Roof", x0 - 0.2, x1 + 0.2, h, h + 0.3, z0 - 0.2, z1 + 0.2, "snow")
    fx = x1 if front == "E" else x0
    out = 1 if front == "E" else -1
    zc = (z0 + z1) / 2
    if false_front:
        # Фальшфасад: высокая доска над крышей, как в городках золотой лихорадки.
        L.box_ext("Props", "FalseFront", fx - 0.15, fx + 0.15, h, h + 2.2, z0, z1, mat)
        L.box_ext("Props", "FalseFrontSnow", fx - 0.25, fx + 0.25, h + 2.2, h + 2.4, z0, z1, "snow", collide=False,
                  shadow=False)
    if parapet:
        for a, b, c, d in ((x0, x1, z0, z0 + 0.3), (x0, x1, z1 - 0.3, z1), (x0, x0 + 0.3, z0, z1),
                           (x1 - 0.3, x1, z0, z1)):
            L.box_ext("Props", "Parapet", a, b, h + 0.3, h + 0.9, c, d, mat)
    # Дверь, окна (тёмные: в городке давно никто не живёт), доски крест-накрест.
    L.box_ext("Props", "Door", fx + out * 0.02, fx + out * 0.08, 0, 2.3, zc - 0.7, zc + 0.7, "black_metal",
              collide=False, shadow=False)
    for dz in (-0.3, 0.3):
        wz = zc + dz * (z1 - z0)
        L.box_ext("Props", "Window", fx + out * 0.02, fx + out * 0.08, 1.2, 2.4, wz - 0.7, wz + 0.7, "dark_glass",
                  collide=False, shadow=False)
        L.box("Props", "Board", (fx + out * 0.1, 1.8, wz), (0.06, 0.18, 1.7), "plank", collide=False,
              rows=rot_x(0.6), shadow=False)
    # Деревянный тротуар и навес над ним.
    L.box_ext("Props", "Boardwalk", min(fx, fx + out * 2), max(fx, fx + out * 2), 0, 0.12, z0, z1, "plank",
              collide=False, shadow=False)
    L.label(sign, (fx + out * 0.2, h + 1.1 if false_front else h - 0.8, zc), yaw=90 if front == "E" else -90,
            size=64, color=SIGN)


def fire_barrel(x, z, y=0.0):
    L.cylinder("Props", "FireBarrel", (x, y + 0.5, z), 0.35, 1.0, "rust", sides=10)
    L.box("Props", "Embers", (x, y + 1.02, z), (0.5, 0.05, 0.5), "lamp_red", collide=False, shadow=False)
    L.node("Light", "OmniLight3D", "Lights", transform=xform((x, y + 1.6, z)), light_color=FIRE, light_energy="2.2",
           omni_range="13")


def wagon(x, z, yaw=0.0):
    r = rot_y(yaw)
    def at(lx, ly, lz):
        return (x + r[0][0] * lx + r[0][2] * lz, ly, z + r[2][0] * lx + r[2][2] * lz)
    L.box("Props", "Wagon", at(0, 0.9, 0), (1.8, 0.5, 3.6), "wood", rows=r)
    L.box("Props", "WagonSide", at(0.85, 1.35, 0), (0.1, 0.5, 3.6), "plank", rows=r)
    L.box("Props", "WagonSide", at(-0.85, 1.35, 0), (0.1, 0.5, 3.6), "plank", rows=r)
    L.box("Props", "WagonSnow", at(0, 1.2, 0), (1.6, 0.15, 3.4), "snow", collide=False, rows=r, shadow=False)
    for lx, lz in ((1.0, 1.2), (-1.0, 1.2), (1.0, -1.2), (-1.0, -1.2)):
        L.cylinder("Props", "Wheel", at(lx, 0.6, lz), 0.6, 0.1, "wood", collide=False,
                   rows=mul(r, rot_z(math.pi / 2)), sides=10)


def drift(x, z, w, d, h=0.6):
    L.box("Props", "Drift", (x, h / 2, z), (w, h, d), "snow", rows=rot_y(random.uniform(-20, 20)))


def pine(x, z, h=None, y=0.0):
    h = h or random.uniform(7, 12)
    L.cylinder("Props", "PineTrunk", (x, y + h * 0.25, z), 0.3, h * 0.5, "tree_trunk", collide=False, sides=6)
    for i, s in enumerate((3.2, 2.4, 1.5)):
        L.box("Props", "PineCrown", (x, y + h * (0.35 + 0.22 * i), z), (s, h * 0.24, s), "tree_leaves",
              collide=False)
        L.box("Props", "PineSnow", (x, y + h * (0.35 + 0.22 * i) + h * 0.12, z), (s * 0.8, 0.2, s * 0.8), "snow",
              collide=False, shadow=False)


# --- Городок: хребет со стартом и главная улица -------------------------------------
L.room("GTown", -24, 24, -128, 0, 0, 16, "snow", "rock", None, openings={"E": [(-110, -100, 6)]})
RIDGE = 5.0
L.box_ext("Geometry", "Ridge", -24, 24, 0, RIDGE, -20, 0, "snow")
L.ramp_z("Geometry", "Trail", -3, 3, -20, RIDGE, -36, 0, "snow")
for x0, x1 in ((-24, -3.4), (3.4, 24)):
    L.box_ext("Props", "FenceRail", x0, x1, RIDGE + 0.85, RIDGE + 1.0, -19.95, -19.8, "wood")
    for x in range(int(x0) + 1, int(x1), 3):
        L.box("Props", "FencePost", (x, RIDGE + 0.5, -19.85), (0.15, 1.0, 0.15), "wood")
# Хижина охотника и навес с винтовкой.
L.box_ext("Props", "Shack", -16, -9, RIDGE, RIDGE + 3.2, -12, -3, "plank")
L.box_ext("Props", "ShackRoof", -16.4, -8.6, RIDGE + 3.2, RIDGE + 3.6, -12.4, -2.6, "snow")
L.box_ext("Props", "ShackWindow", -8.98, -8.95, RIDGE + 1.2, RIDGE + 2.2, -9, -7, "lamp", collide=False, shadow=False)
L.node("Light", "OmniLight3D", "Lights", transform=xform((-7.5, RIDGE + 2.0, -8)), light_color=WARM,
       light_energy="1.4", omni_range="9")
L.box_ext("Props", "RackTable", -4.5, -1.5, RIDGE, RIDGE + 0.9, -9, -8, "wood")
L.label("ВИНТОВКА ОХОТНИКА", (-3, RIDGE + 2.0, -8.4), size=48, color="Color(1, 0.9, 0.5, 1)")
L.pickup("weapon", (-3, RIDGE + 0.9, -8.5), weapon="sniper")
L.pickup("ammo", (-1.5, RIDGE, -6))
L.pickup("health", (12, RIDGE, -6))
for x, z in ((-20, -4), (20, -6), (17, -14), (-21, -15)):
    pine(x, z, y=RIDGE)
L.lamp((3, RIDGE + 3, -3), 1.2, 10, color=WARM, size=(0.3, 0.3, 0.3))

# Дома по сторонам улицы: запад (фасад на +X) и восток (фасад на −X).
building(-22, -8, -56, -40, 7, "plank", "САЛУН", "E")
building(-22, -8, -72, -60, 5.5, "wood", "ЛАВКА", "E")
building(-22, -8, -88, -76, 6.5, "brick", "БАНК", "E", false_front=False, parapet=True)
building(-22, -8, -104, -92, 5, "plank", "ШЕРИФ", "E")
building(-22, -8, -124, -108, 5, "wood", "КОНЮШНЯ", "E")
building(8, 22, -58, -40, 8, "wood", "ОТЕЛЬ «АВРОРА»", "W")
building(8, 22, -72, -62, 5, "plank", "ЦИРЮЛЬНЯ", "W")
building(8, 22, -96, -76, 6, "brick", "ПРОБИРНАЯ КОНТОРА", "W", false_front=False, parapet=True)
building(8, 22, -126, -114, 6, "wood", "СКЛАД", "W", false_front=False, parapet=True)
# Балкон отеля.
L.box_ext("Props", "Balcony", 6.2, 8, 3.8, 4.1, -56, -42, "plank")
L.box_ext("Props", "BalconyRail", 6.2, 6.35, 4.1, 5.0, -56, -42, "wood")
for z in (-56, -49, -42):
    L.box("Props", "BalconyPost", (6.4, 1.9, z), (0.2, 3.8, 0.2), "wood")
# Церковь в конце улицы не нужна: там скала. Табличка-указатель в переулок.
L.box("Props", "SignPost", (7, 1.2, -103), (0.15, 2.4, 0.15), "wood")
L.box("Props", "SignBoard", (7.6, 2.2, -103), (1.4, 0.4, 0.08), "plank", collide=False)
L.label("К ШАХТЕ →", (7.6, 2.2, -102.94), size=32, color=SIGN)

# Укрытия на улице.
wagon(-3.5, -62, 8)
wagon(3.8, -96, -12)
for x, z in ((-5, -46), (4.5, -76), (-4.5, -88), (2, -112)):
    L.box("Props", "Trough", (x, 0.4, z), (0.9, 0.8, 2.4), "wood")
for x, z, w, d in ((3, -52, 3, 2), (-2, -74, 2.5, 3), (0, -84, 3.5, 2), (-3, -118, 3, 2.5), (5, -120, 2, 2)):
    drift(x, z, w, d)
for x, z in ((-6.5, -66), (6.6, -80), (-6.6, -97)):
    L.box("Props", "HitchRail", (x, 0.9, z), (0.15, 0.15, 3), "wood")
fire_barrel(-5.5, -57)
fire_barrel(5.5, -88)
fire_barrel(-5, -114)

# Враги на улице: бандиты и снайперы на балконе и крышах.
L.enemy("bandit", (-4, 0, -50), look_at=(0, 0, -20))
L.enemy("bandit", (5, 0, -66), look_at=(0, 0, -20))
L.enemy("marksman", (7.0, 4.1, -48), look_at=(0, RIDGE, -10))
L.enemy("bandit", (-6.8, 0, -82), look_at=(0, 0, -40))
L.enemy("marksman", (-12, 6.8, -82), look_at=(0, RIDGE, -10))
L.enemy("trapper", (3, 0, -92), look_at=(0, 0, -40))
L.enemy("bandit", (-3, 0, -102), look_at=(0, 0, -40))
L.enemy("heavy", (0, 0, -120), look_at=(0, 0, -60))
L.enemy("marksman", (14, 6.3, -116), look_at=(0, 0, -60))
L.enemy("bandit", (15, 0, -106), look_at=(0, 0, -105))
L.pickup("ammo", (-7, 0, -70))
L.pickup("health", (7, 0, -60))
L.pickup("grenade", (-7, 0, -106))
L.pickup("ammo", (20, 0, -100))
L.pickup("health", (20, 0, -110))

L.wave_zone("ZoneGate", (0, 2, -44), (16, 4, 12),
            spawns=[(-12, RIDGE + 0.1, -15), (12, RIDGE + 0.1, -15), (-5, 0.1, -70), (5, 0.1, -70)],
            barriers=[], title="Банда спускается с хребта!", waves=2, first=4, extra=2, rusher=0.35,
            gunner_kind="bandit", rusher_kind="trapper")
L.wave_zone("ZoneStreet", (0, 2, -100), (40, 4, 24),
            spawns=[(-4, 0.1, -126), (4, 0.1, -126), (-12, 0.1, -106), (18, 0.1, -110)],
            barriers=[((23.7, 3, -105), (0.3, 6, 10.4))],
            title="Засада у конюшни!", waves=2, first=5, extra=2, rusher=0.3, heavy=1,
            gunner_kind="bandit", rusher_kind="trapper")

# --- Площадь у шахты: вышки Снайпера ---------------------------------------------
L.room("GSquare", 24, 96, -150, -60, 0, 18, "snow", "rock", None, openings={"W": [(-110, -100, 6)]})
# Церковь с колокольней.
L.box_ext("Props", "Church", 78, 92, 0, 7, -84, -64, "white_paint")
L.box_ext("Props", "ChurchRoof", 77.6, 92.4, 7, 7.4, -84.4, -63.6, "snow")
L.box_ext("Props", "ChurchWindow", 77.95, 78, 2, 4.5, -70, -68, "lamp", collide=False, shadow=False)
L.box_ext("Props", "ChurchWindow", 77.95, 78, 2, 4.5, -80, -78, "lamp", collide=False, shadow=False)
TOWER = 11.0
L.box_ext("Props", "BellTower", 72, 78, 0, TOWER, -77, -71, "white_paint")
L.box_ext("Props", "BelfryBack", 77.7, 78, TOWER, TOWER + 3.5, -77, -71, "wood")
for a, b, c, d in ((72, 78, -77, -76.7), (72, 78, -71.3, -71), (72, 72.3, -77, -71), (77.7, 78, -77, -71)):
    L.box_ext("Props", "BelfryWall", a, b, TOWER, TOWER + 1.0, c, d, "wood")
for x, z in ((72.2, -76.8), (77.8, -76.8), (72.2, -71.2), (77.8, -71.2)):
    L.box("Props", "BelfryPost", (x, TOWER + 1.75, z), (0.3, 3.5, 0.3), "wood")
L.box_ext("Props", "BelfryRoof", 71.5, 78.5, TOWER + 3.5, TOWER + 4.0, -77.5, -70.5, "wood")
L.box_ext("Props", "Spire", 74.4, 75.6, TOWER + 4.0, TOWER + 7.0, -74.6, -73.4, "wood", collide=False)
L.cylinder("Props", "Bell", (76.3, TOWER + 2.6, -74), 0.55, 0.9, "rust", collide=False)
L.label("ЦЕРКОВЬ СВ. НИКОЛАЯ", (71.9, 6.5, -74), yaw=-90, size=40, color=SIGN)
# Водонапорная башня.
WATER = 9.0
for x, z in ((37, -137), (43, -137), (37, -143), (43, -143)):
    L.box("Props", "TowerLeg", (x, WATER / 2, z), (0.45, WATER, 0.45), "wood")
L.box("Props", "Brace", (40, WATER / 2, -137), (6, 0.25, 0.2), "wood", rows=rot_z(0.9))
L.box("Props", "Brace", (40, WATER / 2, -143), (6, 0.25, 0.2), "wood", rows=rot_z(-0.9))
L.box_ext("Props", "TowerDeck", 35.5, 44.5, WATER - 0.3, WATER, -145.5, -134.5, "plank")
L.box_ext("Props", "DeckRail", 35.5, 44.5, WATER, WATER + 0.9, -134.6, -134.45, "wood")
L.cylinder("Props", "Tank", (40, WATER + 2.6, -140), 3.2, 5.2, "wood", sides=14)
L.cylinder("Props", "TankRoof", (40, WATER + 5.5, -140), 3.5, 0.6, "snow", collide=False, sides=14)
L.ramp_z("Props", "TowerLadder", 39.6, 40.4, -128, 0, -134.5, WATER - 0.3, "wood", t=0.15)
# Копёр шахты: башня с колесом над стволом, внизу — надшахтное здание.
HEAD = 13.0
for x, z in ((80, -134), (88, -134), (80, -142), (88, -142)):
    L.box("Props", "HeadframeLeg", (x, HEAD / 2, z), (0.5, HEAD, 0.5), "wood")
for y in (4, 8.5):
    L.box_ext("Props", "HeadframeBeam", 80, 88, y, y + 0.3, -134.2, -133.8, "wood", collide=False)
    L.box_ext("Props", "HeadframeBeam", 80, 88, y, y + 0.3, -142.2, -141.8, "wood", collide=False)
L.box_ext("Props", "HeadframeDeck", 79.5, 88.5, HEAD - 0.3, HEAD, -142.5, -133.5, "plank")
L.box_ext("Props", "HeadframeRail", 79.5, 88.5, HEAD, HEAD + 0.9, -133.6, -133.45, "wood")
L.cylinder("Props", "Sheave", (84, HEAD + 2.4, -138), 2.0, 0.25, "rust", collide=False, rows=rot_x(math.pi / 2),
           sides=16)
L.box_ext("Props", "ShaftHouse", 80, 92, 0, 5, -150, -144, "plank")
L.label("ШАХТА «ЗОЛОТАЯ ЖИЛА»", (86, 5.8, -143.9), size=48, color=SIGN)
L.ramp_z("Props", "HeadframeLadder", 83.6, 84.4, -124, 0, -133.5, HEAD - 0.3, "wood", t=0.15)
# Контора прииска с плоской крышей.
OFFICE = 6.0
L.box_ext("Props", "Office", 50, 62, 0, OFFICE, -72, -62, "brick")
L.box_ext("Props", "OfficeRoof", 49.8, 62.2, OFFICE, OFFICE + 0.3, -72.2, -61.8, "snow")
for a, b, c, d in ((50, 62, -72.2, -71.9), (50, 50.3, -72, -62), (61.7, 62, -72, -62)):
    L.box_ext("Props", "OfficeParapet", a, b, OFFICE + 0.3, OFFICE + 0.9, c, d, "brick")
L.label("КОНТОРА ПРИИСКА", (56, 4.6, -72.06), yaw=180, size=48, color=SIGN)
L.box_ext("Props", "OfficeDoor", 55.2, 56.8, 0, 2.3, -72.08, -72.02, "black_metal", collide=False, shadow=False)

# Укрытия на площади.
wagon(36, -84, 75)
wagon(64, -112, -20)
wagon(48, -128, 40)
for x0, z in ((52, -100), (70, -96), (34, -118)):
    L.box("Props", "Woodpile", (x0, 0.6, z), (3.2, 1.2, 1.2), "wood", rows=rot_y(random.uniform(-30, 30)))
for x, z in ((44, -96), (60, -88), (76, -120), (30, -100), (56, -138), (70, -132)):
    L.box("Props", "Crate", (x, 0.55, z), (1.1, 1.1, 1.1), "crate", rows=rot_y(random.uniform(0, 90)))
for x0, x1 in ((83.6, 83.7), (84.3, 84.4)):
    L.box_ext("Props", "Rail", x0, x1, 0, 0.04, -133, -96, "rail", collide=False, shadow=False)
L.box("Props", "OreCart", (84, 0.6, -110), (1.2, 1.0, 1.8), "rust")
L.box("Props", "OreCart", (84, 0.6, -101), (1.2, 1.0, 1.8), "rust")
for x, z, w, d in ((40, -108, 4, 2.5), (68, -104, 3, 3), (58, -120, 4, 2), (30, -136, 3, 3), (90, -92, 3, 4)):
    drift(x, z, w, d, 0.9)
fire_barrel(46, -104)
fire_barrel(66, -126)
fire_barrel(32, -76)
L.lamp((84, 4.5, -143.6), 1.4, 10, color=WARM, size=(0.3, 0.3, 0.3))
L.pickup("health", (28, 0, -64))
L.pickup("ammo", (28, 0, -146))
L.pickup("health", (93, 0, -110))
L.pickup("ammo", (60, 0, -97))
L.pickup("grenade", (46, 0, -130))

L.markers("BossNests", [
    ("Колокольня", (74.5, TOWER, -74), yaw_to((74.5, 0, -74), (40, 0, -105))),
    ("Водонапорная башня", (40, WATER, -135.4), yaw_to((40, 0, -135.4), (55, 0, -95))),
    ("Копёр шахты", (84, HEAD, -134.4), yaw_to((84, 0, -134.4), (50, 0, -100))),
    ("Крыша конторы", (56, OFFICE + 0.3, -70.6), yaw_to((56, 0, -70.6), (45, 0, -110))),
])
L.markers("BossSpawns", [
    ("Spawn", (30, 0, -64), 180), ("Spawn", (93, 0, -100), 90), ("Spawn", (62, 0, -147), 0),
    ("Spawn", (27, 0, -146), 0), ("Spawn", (90, 0, -66), 135),
])
L.boss("sniper_boss", "Sniper", (74.5, TOWER, -74), (24, 0, -105),
       hide_points='NodePath("../../BossNests")', henchman_points='NodePath("../../BossSpawns")')

# --- Горы, лес, луна ---------------------------------------------------------------
L.section = "Outdoor"
for i in range(26):
    x = random.choice((random.uniform(-70, -30), random.uniform(100, 140)))
    pine(x, random.uniform(-160, 10), y=random.uniform(4, 10))
for x, z, w, h in ((-110, -60, 120, 70), (190, -100, 140, 80), (40, -240, 300, 100), (40, 90, 300, 50)):
    L.box("Props", "Mountain", (x, h / 2 - 8, z), (w, h, 120), "snow", collide=False, shadow=False)
L.cylinder("Props", "Moon", (-120, 120, -330), 9, 1, "lamp_cold", collide=False, rows=rot_x(math.pi / 2), sides=24)
L.node("Snow", "Node3D", ".", script=L.ext_res("Script", "res://scripts/town/rain.gd"), snow="true")

L.player((0, RIDGE, -3), 0)
L.waypoint((0, RIDGE, -3), (0, RIDGE, -20), (0, 0, -36), (0, 0, -104), (22, 0, -105), (30, 0, -105),
           (50, 0, -105))

env = [
    ("ShaderMaterial", "SkyMat_12", {"shader": L.ext_res("Shader", "res://materials/aurora_sky.gdshader")}),
    ("Sky", "Sky_12", {"sky_material": 'SubResource("SkyMat_12")'}),
    ("Environment", "Env_12", {
        "background_mode": "2", "sky": 'SubResource("Sky_12")',
        "ambient_light_source": "2", "ambient_light_color": "Color(0.42, 0.47, 0.58, 1)",
        "ambient_light_energy": "0.65", "tonemap_mode": "2",
        "fog_enabled": "true", "fog_light_color": "Color(0.26, 0.28, 0.33, 1)", "fog_density": "0.01",
        "fog_sky_affect": "0.4",
    }),
]
L.node("WorldEnvironment", "WorldEnvironment", ".", environment='SubResource("Env_12")')
L.node("Moonlight", "DirectionalLight3D", ".", transform=xform((0, 40, 0), mul(rot_y(200), rot_x(math.radians(-38)))),
       light_color="Color(0.65, 0.75, 1, 1)", light_energy="0.45", shadow_enabled="true",
       directional_shadow_max_distance="60.0", directional_shadow_mode="1")
L.explosives([(-6.5, 0, -52), (6.6, 0, -70), (-6.6, 0, -86), (6.5, 0, -100), (-5.5, 0, -122), (20, 0, -98),
              (44.5, 0, -94), (62, 0, -86), (74, 0, -118), (58, 0, -136), (32, 0, -120), (90, 0, -128)],
             pattern="TBT")
L.explosives([(28, 0, -90), (80, 0, -100)], pattern="F")
L.pickup("weapon", (30, 0, -108), weapon="rpg")
L.write("scenes/levels/level_12_ghost_town.tscn", env, ["pistol", "shotgun", "magnum", "rifle"])
