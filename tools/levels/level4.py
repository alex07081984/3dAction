from levelkit import Level, xform, rot_x, rot_y, f, yaw_to
import math
import random

random.seed(4)
L = Level("Level4Mansion", {
    "level_index": "3",
    "title": '"Особняк"',
    "objective": '"Найдите хозяина особняка — Худого"',
})
for g in ("Geometry", "Lights", "Props", "Enemies", "Pickups"):
    L.group(g)

DOOR = 3.5
WARM = "Color(1, 0.8, 0.55, 1)"


def lamp_post(x, z, y=0.0):
    L.cylinder("Props", "Post", (x, y + 1.6, z), 0.08, 3.2, "black_metal")
    L.box("Props", "PostLamp", (x, y + 3.3, z), (0.35, 0.4, 0.35), "lamp", collide=False)
    L.node("Light", "OmniLight3D", "Lights", transform=xform((x, y + 3.0, z)), light_color=WARM,
           light_energy="1.6", omni_range="11")


def hedge(x0, x1, z0, z1, h=1.6):
    L.box_ext("Props", "Hedge", x0, x1, 0, h, z0, z1, "hedge")


# G — ворота поместья (улица, без потолка)
L.room("GGate", -14, 14, -14, 0, 0, 4, "grass", "stone", None, openings={"N": [(-4, 4)], "S": [(-3, 3)]})
for x in (-3.6, 3.6):
    L.box("Props", "GatePillar", (x, 2.5, -0.2), (1.0, 5, 1.0), "stone")
    L.box("Props", "GateTop", (x, 5.2, -0.2), (1.3, 0.4, 1.3), "stone", collide=False)
for i in range(13):
    L.box("Props", "GateBar", (-3 + i * 0.5, 1.8, 0.25), (0.06, 3.6, 0.06), "black_metal", collide=False)
L.box("Props", "GateBarTop", (0, 3.5, 0.25), (6.4, 0.12, 0.08), "black_metal", collide=False)
L.invisible_wall("Geometry", "GateBlock", (0, 2, 0.25), (6.2, 4, 0.3))
L.box("Props", "Booth", (9.5, 1.3, -4), (3, 2.6, 3), "plaster_white")
L.box("Props", "BoothRoof", (9.5, 2.7, -4), (3.4, 0.2, 3.4), "roof_tiles", collide=False)
L.box("Props", "BoothWindow", (7.97, 1.5, -4), (0.06, 0.8, 1.6), "dark_glass", collide=False)
L.box_ext("Props", "Path", -3, 3, 0, 0.02, -14, 0, "paving", collide=False, shadow=False)
lamp_post(-5, -7)
lamp_post(5, -11)
L.label("ПОМЕСТЬЕ «ЗОЛОТОЙ КЛЮЧ»", (0, 3.4, -0.7), yaw=180, size=56, color="Color(0.9, 0.75, 0.35, 1)")
L.enemy("gunner", (-8, 0, -11), look_at=(0, 0, 0))
L.enemy("gunner", (9.5, 0, -8), look_at=(0, 0, 0))
L.enemy("rusher", (-3, 0, -12), look_at=(0, 0, 0))
L.player((0, 0.05, -2), 0)

# D — подъездная аллея
L.room("DDriveway", -10, 10, -64, -14, 0, 4, "grass", "stone", None, sides={"S": False, "N": False})
L.box_ext("Props", "Path", -3, 3, 0, 0.02, -64, -14, "paving", collide=False, shadow=False)
for z in range(-18, -62, -8):
    hedge(-6.5, -5, z - 3, z)
    hedge(5, 6.5, z - 3, z)
L.box("Props", "Limo", (7.6, 0.7, -32), (2.2, 1.2, 6.5), "car_black")
L.box("Props", "LimoCabin", (7.6, 1.55, -32.5), (2.0, 0.6, 4.0), "dark_glass")
L.box("Props", "Limo", (-7.6, 0.7, -50), (2.2, 1.2, 6.5), "car_black")
L.box("Props", "LimoCabin", (-7.6, 1.55, -49.5), (2.0, 0.6, 4.0), "dark_glass")
for z in (-24, -40, -56):
    lamp_post(-4, z)
    lamp_post(4, z - 6)
L.enemy("gunner", (-8, 0, -38), look_at=(0, 0, -14))
L.enemy("gunner", (8, 0, -44), look_at=(0, 0, -14))
L.enemy("gunner", (-8.5, 0, -58), look_at=(0, 0, -14))
L.enemy("rusher", (2, 0, -46), look_at=(0, 0, -14))
L.pickup("ammo", (-8.5, 0, -22))

# C — двор с фонтаном (волны 1)
L.room("CCourtyard", -26, 26, -102, -64, 0, 4, "paving", "stone", None,
       openings={"S": [(-10.5, 10.5)], "N": [(-16.5, 16.5)]})
L.cylinder("Props", "Basin", (0, 0.4, -83), 4, 0.8, "stone", sides=24)
L.cylinder("Props", "FountainWater", (0, 0.78, -83), 3.6, 0.06, "pool_water", collide=False, sides=24)
L.cylinder("Props", "FountainColumn", (0, 1.8, -83), 0.5, 2.4, "marble")
L.cylinder("Props", "FountainBowl", (0, 3.0, -83), 1.4, 0.3, "marble", collide=False)
for x, z in ((-18, -72), (18, -72), (-18, -95), (18, -95)):
    L.box("Props", "Plinth", (x, 0.6, z), (1.4, 1.2, 1.4), "stone")
    L.box("Props", "Statue", (x, 2.2, z), (0.7, 2.0, 0.7), "gold")
for x0, x1, z0, z1 in ((-24, -14, -82, -80), (14, 24, -82, -80), (-10, -6, -96, -94), (6, 10, -96, -94)):
    hedge(x0, x1, z0, z1, 1.3)
for x, z in ((-10, -70), (10, -70), (-21, -88), (21, -88)):
    L.box("Props", "Bench", (x, 0.25, z), (2.0, 0.5, 0.6), "wood")
for x in (-6, -2.2, 2.2, 6):
    L.cylinder("Props", "PorticoColumn", (x, 3, -100.4), 0.4, 6, "marble")
L.box_ext("Props", "PorticoRoof", -7.5, 7.5, 6, 6.6, -102, -99, "stone", collide=False)
for x, z in ((-13, -68), (13, -68), (-13, -98), (13, -98), (-23, -84), (23, -84)):
    lamp_post(x, z)
L.pickup("health", (-24, 0, -66))
L.pickup("ammo", (24, 0, -100))
L.enemy("gunner", (-20, 0, -90), look_at=(0, 0, -64))
L.enemy("gunner", (20, 0, -93), look_at=(0, 0, -64))
L.enemy("gunner", (-12, 0, -98), look_at=(0, 0, -64))
L.enemy("gunner", (12, 0, -99), look_at=(0, 0, -64))
L.enemy("heavy", (0, 0, -99.5), look_at=(0, 0, -64))
L.wave_zone("ZoneCourtyard", (0, 2, -83), (44, 4, 30),
            spawns=[(-24, 0.1, -66), (24, 0.1, -66), (-24, 0.1, -100), (24, 0.1, -100)],
            barriers=[((0, 2, -63.85), (21.4, 4, 0.3)), ((0, 1.75, -102.15), (6.4, 3.5, 0.3))],
            title="Охрана особняка!", waves=2, first=5, extra=2, rusher=0.35, heavy=1)

# H — главный зал (два этажа в высоту, галерея с лестницами)
L.room("HHall", -16, 16, -134, -102, 0, 10, "floor_tiles", "wallpaper", "ceiling",
       openings={"S": [(-3, 3, DOOR)], "N": [(-3, 3, DOOR)]}, wall_mats={"S": "stone"})
L.box_ext("Geometry/HHall", "Gallery", -16, 16, 4.6, 5, -134, -127, "parquet")
for x0, x1 in ((-16, -12), (12, 16)):
    L.ramp_z("Geometry/HHall", "GrandStairs", x0, x1, -106, 0, -127, 5, "marble")
L.box_ext("Props", "Railing", -12, 12, 5, 6.0, -127.1, -126.9, "gold")
L.box_ext("Props", "Carpet", -2, 2, 0, 0.02, -134, -102, "red_carpet", collide=False, shadow=False)
for x in (-8, 8):
    for z in (-110, -120):
        L.box("Props", "Column", (x, 2.3, z), (0.9, 4.6, 0.9), "marble")
for z in (-108, -114, -120):
    L.box("Props", "Portrait", (-15.9, 3.2, z), (0.08, 1.6, 1.2), "gold", collide=False)
L.box("Props", "Chandelier", (0, 8.6, -118), (2.2, 0.8, 2.2), "gold", collide=False)
L.node("Light", "OmniLight3D", "Lights", transform=xform((0, 7.8, -118)), light_color=WARM,
       light_energy="2.4", omni_range="20")
L.lamp((-10, 9.9, -108), 1.0, 9, color=WARM)
L.lamp((10, 9.9, -108), 1.0, 9, color=WARM)
L.enemy("gunner", (-8, 5, -131), look_at=(0, 0, -102))
L.enemy("gunner", (8, 5, -131), look_at=(0, 0, -102))
L.enemy("rusher", (-10, 0, -112), look_at=(0, 0, -102))
L.enemy("rusher", (10, 0, -118), look_at=(0, 0, -102))
L.enemy("heavy", (0, 0, -130), look_at=(0, 0, -102))
L.pickup("health", (14, 0, -104))

# DN — столовая
L.room("DNDining", -12, 12, -158, -134, 0, 5, "parquet", "wallpaper", "ceiling",
       openings={"S": [(-3, 3, DOOR)], "N": [(-3, 3, DOOR)]})
L.box("Props", "Table", (0, 0.4, -146), (14, 0.8, 2.2), "wood")
L.box("Props", "TableCloth", (0, 0.81, -146), (14.2, 0.02, 2.4), "bed_sheet", collide=False)
for x in range(-6, 7, 2):
    for z in (-144.4, -147.6):
        L.box("Props", "Chair", (x, 0.5, z), (0.6, 1.0, 0.6), "sofa")
L.box("Props", "Cabinet", (-11.4, 1.1, -146), (1.0, 2.2, 6), "wood")
L.box("Props", "Fireplace", (11.4, 1.2, -146), (1.2, 2.4, 3), "stone")
L.box("Props", "FireGlow", (10.78, 0.7, -146), (0.05, 0.8, 1.8), "lamp_red", collide=False)
for x in (-4, 4):
    L.lamp((x, 4.9, -146), 1.4, 11, mat="gold", color=WARM, size=(1.0, 0.3, 1.0))
L.label("СТОЛОВАЯ", (0, 4.3, -157.9), size=56, color="Color(0.95, 0.8, 0.4, 1)")
L.enemy("gunner", (-10, 0, -155.5), look_at=(0, 0, -134))
L.enemy("gunner", (10, 0, -156), look_at=(0, 0, -134))
L.enemy("gunner", (0, 0, -151), look_at=(0, 0, -134))
L.enemy("rusher", (-8, 0, -140), look_at=(0, 0, -134))

# K — кухня
L.room("KKitchen", -10, 10, -176, -158, 0, 4.5, "floor_tiles", "tiles_wall", "ceiling",
       openings={"S": [(-3, 3, DOOR)], "N": [(-3.5, 3.5, DOOR)]})
L.box("Props", "Island", (0, 0.45, -167), (4, 0.9, 2), "metal")
for z in range(-174, -159, 3):
    L.box("Props", "Counter", (-9.4, 0.45, z), (1.2, 0.9, 2.8), "white_paint")
L.box("Props", "Stove", (9.4, 0.5, -164), (1.2, 1.0, 4), "metal")
L.box("Props", "Hood", (9.5, 3.4, -164), (1.0, 0.6, 3.5), "metal", collide=False)
L.box("Props", "Fridge", (9.3, 1.0, -172), (1.2, 2.0, 1.2), "white_paint")
L.lamp((-4, 4.4, -167), 1.3, 10, mat="lamp_cold", color="Color(0.95, 0.97, 1, 1)")
L.lamp((5, 4.4, -167), 1.3, 10, mat="lamp_cold", color="Color(0.95, 0.97, 1, 1)")
L.pickup("ammo", (8.5, 0, -160))
L.enemy("gunner", (-8, 0, -174.5), look_at=(0, 0, -158))
L.enemy("rusher", (7, 0, -175), look_at=(0, 0, -158))

# SS — чёрная лестница на второй этаж (с 0 на 5)
L.room("SSStairs", -3, 3, -192, -176, 0, 10.5, "concrete", "plaster_white", "ceiling",
       openings={"S": [(-3.5, 3.5, 0, 4.9)], "N": [(-3.5, 3.5, 5, 9)]})
L.ramp_z("Geometry/SSStairs", "Ramp", -3, 3, -177, 0, -189, 5, "wood")
L.box_ext("Geometry/SSStairs", "Landing", -3, 3, 0, 5, -192, -189, "parquet")
L.lamp((0, 10.4, -184), 1.2, 11, color=WARM)
L.enemy("gunner", (2, 5, -191), look_at=(0, 0, -176))

# CR — коридор второго этажа со спальнями по бокам
L.room("CRCorridor", -3, 3, -222, -192, 5, 4, "red_carpet", "wallpaper", "ceiling",
       openings={"S": [(-3.5, 3.5, 3.5)], "E": [(-202, -198, 3.2)], "W": [(-216, -212, 3.2)],
                 "N": [(-3, 3, DOOR)]})
for z in (-196, -206, -216):
    L.lamp((0, 8.9, z), 1.1, 8, mat="gold", color=WARM, size=(0.5, 0.1, 0.5))
for z in (-195, -210, -220):
    L.box("Props", "Portrait", (-2.95, 7, z), (0.06, 1.2, 0.9), "gold", collide=False)
L.enemy("gunner", (1.5, 5, -219), look_at=(0, 5, -192))

for name, x0, x1, z0, z1, side, door in (("B1Bedroom", 3, 15, -206, -194, "W", (-202, -198, 3.2)),
                                         ("B2Bedroom", -15, -3, -220, -208, "E", (-216, -212, 3.2))):
    L.room(name, x0, x1, z0, z1, 5, 4, "parquet", "wallpaper", "ceiling", openings={side: [door]})
    cx = (x0 + x1) / 2
    far = x1 - 1.4 if side == "W" else x0 + 1.4
    L.box("Props", "Bed", (far, 5.35, (z0 + z1) / 2), (2.2, 0.7, 2.6), "bed_sheet")
    L.box("Props", "Blanket", (far, 5.72, (z0 + z1) / 2 + 0.3), (2.2, 0.08, 1.8), "blanket", collide=False)
    L.box("Props", "Wardrobe", (cx, 6.1, z0 + 0.6), (2.4, 2.2, 0.9), "wood")
    L.box("Props", "Nightstand", (far, 5.3, z1 - 0.6), (0.6, 0.6, 0.6), "wood")
    L.lamp((cx, 8.9, (z0 + z1) / 2), 1.1, 9, color=WARM, size=(0.6, 0.1, 0.6))
L.enemy("gunner", (12, 5, -196), look_at=(3, 5, -200))
L.enemy("gunner", (8, 5, -204.5), look_at=(3, 5, -200))
L.enemy("heavy", (-12, 5, -214), look_at=(-3, 5, -214))
L.pickup("health", (13.5, 5, -204.5))
L.pickup("ammo", (-13.5, 5, -209))

# LB — библиотека (волны 2)
L.room("LBLibrary", -14, 14, -250, -222, 5, 6, "parquet", "wood", "ceiling",
       openings={"S": [(-3, 3, DOOR)], "N": [(-3, 3, DOOR)]})
for x in (-10.5, -6, 6, 10.5):
    for z0, z1 in ((-232, -226), (-246, -238)):
        L.box_ext("Props", "Bookshelf", x - 0.4, x + 0.4, 5, 8, z0, z1, "wood")
        for i, row in enumerate((5.6, 6.4, 7.2)):
            mat = ["car_red", "car_blue", "awning_green"][(i + int(x)) % 3]
            for sx in (-0.42, 0.42):
                L.box_ext("Props", "Books", x + sx - 0.03, x + sx + 0.03, row, row + 0.45, z0 + 0.2, z1 - 0.2, mat,
                          collide=False, shadow=False)
L.box("Props", "ReadingTable", (3, 5.4, -236), (2.4, 0.8, 1.4), "wood")
L.cylinder("Props", "Globe", (2.5, 5.8, -242), 0.45, 0.9, "awning_green", collide=False)
L.box("Props", "Fireplace", (13.4, 6.2, -236), (1.2, 2.4, 3), "stone")
L.box("Props", "FireGlow", (12.78, 5.7, -236), (0.05, 0.8, 1.8), "lamp_red", collide=False)
for x, z in ((-8, -229), (8, -229), (-8, -243), (8, -243)):
    L.lamp((x, 10.9, z), 1.3, 11, color=WARM, size=(0.6, 0.1, 0.6))
L.label("БИБЛИОТЕКА", (0, 9.4, -249.9), size=64, color="Color(0.95, 0.8, 0.4, 1)")
L.pickup("health", (-13, 5, -248.5))
L.pickup("ammo", (13, 5, -224))
L.enemy("gunner", (-11.5, 5, -246), look_at=(0, 5, -222))
L.enemy("gunner", (11.5, 5, -247), look_at=(0, 5, -222))
L.enemy("rusher", (-3, 5, -244), look_at=(0, 5, -222))
L.wave_zone("ZoneLibrary", (0, 7, -236), (26, 4, 24),
            spawns=[(-13, 5.1, -224), (13, 5.1, -230), (-13, 5.1, -240), (13, 5.1, -248.5)],
            barriers=[((0, 6.75, -221.85), (6.4, 3.5, 0.3)), ((0, 6.75, -250.15), (6.4, 3.5, 0.3))],
            title="Засада в библиотеке!", waves=2, first=5, extra=2, rusher=0.4, heavy=1)

# ST — кабинет босса (финальные волны, сейф)
L.room("STStudy", -10, 10, -268, -250, 5, 5, "parquet", "wallpaper", "ceiling",
       openings={"S": [(-3, 3, DOOR)]}, windows={"N": (1.0, 4.2)})
L.box_ext("Props", "Carpet", -5, 5, 5, 5.02, -266, -254, "red_carpet", collide=False, shadow=False)
L.box("Props", "Desk", (0, 5.45, -262), (4, 0.9, 1.6), "wood")
L.box("Props", "BossChair", (0, 5.7, -263.6), (1.0, 1.4, 0.9), "sofa")
L.box("Props", "Safe", (8, 5.8, -266.8), (1.4, 1.6, 1.0), "metal")
L.box("Props", "SafeDial", (8, 5.9, -266.28), (0.3, 0.3, 0.05), "gold", collide=False)
for x in (-9.4, 9.4):
    L.box("Props", "Bookcase", (x, 6.5, -256), (0.9, 3, 5), "wood")
L.box("Props", "Statue", (-7, 6.0, -266.5), (0.7, 2.0, 0.7), "gold")
L.lamp((-4, 9.9, -258), 1.4, 11, mat="gold", color=WARM, size=(0.8, 0.1, 0.8))
L.lamp((4, 9.9, -264), 1.4, 11, mat="gold", color=WARM, size=(0.8, 0.1, 0.8))
L.label("КАБИНЕТ", (0, 8.8, -250.6), yaw=180, size=56, color="Color(0.95, 0.8, 0.4, 1)")
# Босс Худой: после каждой фазы прячется в другой комнате особняка (имя маркера — подсказка).
L.boss("thin_boss", "ThinBoss", (0, 5, -265.5), (0, 5, -250),
       hide_points='NodePath("../../BossHidePoints")', henchman_points='NodePath("../../BossSpawns")')
L.enemy("gunner", (-8, 5, -264), look_at=(0, 5, -250))
L.enemy("gunner", (6, 5, -258), look_at=(0, 5, -250))
L.markers("BossHidePoints", [
    ("холл, под галереей", (-14, 0, -131), 160), ("галерея холла", (13, 5, -132), 200),
    ("столовая", (10.5, 0, -137), 120), ("кухня", (3.5, 0, -174.5), 0),
    ("спальня (восток)", (13.4, 5, -204.2), 60), ("спальня (запад)", (-13.5, 5, -217.8), -60),
    ("библиотека (запад)", (-12.5, 5, -229), 0), ("библиотека (восток)", (12.3, 5, -243), 0),
    ("кабинет", (-8, 5, -260.5), -30)])
L.markers("BossSpawns", [(f"Spawn{i}", p, 0) for i, p in enumerate((
    (0, 0, -104), (-10, 0, -125), (-9, 0, -136), (9, 0, -156), (-6, 0, -160), (6, 0, -160),
    (0, 5, -190.5), (0, 5, -195), (0, 5, -220), (-12, 5, -224), (12, 5, -249), (-8.5, 5, -252),
    (8.5, 5, -252)))])

# Вокруг поместья: деревья, холмы и луна (отдельная секция, чтобы не сливать с кабинетом).
L.section = "Outdoor"
for i in range(40):
    side = random.choice((-1, 1))
    x = side * random.uniform(30, 60)
    z = random.uniform(-280, 10)
    h = random.uniform(6, 12)
    L.cylinder("Props", "Trunk", (x, h / 2 - 2, z), 0.4, h, "tree_trunk", collide=False, sides=6)
    L.box("Props", "Crown", (x, h - 1, z), (4, 4, 4), "tree_leaves", collide=False)
for x, z, w, h in ((-150, -120, 160, 30), (150, -150, 160, 36), (0, -400, 300, 45), (0, 120, 300, 30)):
    L.box("Props", "Hill", (x, h / 2 - 25, z), (w, h, 120), "grass", collide=False, shadow=False)
L.cylinder("Props", "Moon", (-120, 120, -380), 9, 1, "lamp_cold", collide=False, rows=rot_x(math.pi / 2), sides=24)
L.box_ext("Props", "Ground", -300, 300, -25, -1.5, -500, 200, "grass", collide=False, shadow=False)

L.waypoint((0, 0, -2), (0, 0, -14), (0, 0, -63), (0, 0, -66), (-6, 0, -76), (-6, 0, -90), (0, 0, -98),
           (0, 0, -103), (0, 0, -133), (0, 0, -135), (9, 0, -140), (9, 0, -152), (0, 0, -156), (0, 0, -159),
           (4, 0, -162), (4, 0, -172), (0, 0, -175), (0, 0, -177.5), (0, 5, -189.5), (0, 5, -193),
           (0, 5, -221), (0, 5, -223), (0, 5, -249), (0, 5, -251), (-4, 5, -256), (5, 5, -258),
           (6.5, 5, -265))

def mul(a, b):
    return [[sum(a[i][k] * b[k][j] for k in range(3)) for j in range(3)] for i in range(3)]


MOON = mul(rot_y(-35), rot_x(math.radians(-40)))
env = [
    ("ProceduralSkyMaterial", "SkyMat_4", {
        "sky_top_color": "Color(0.02, 0.03, 0.08, 1)", "sky_horizon_color": "Color(0.08, 0.1, 0.18, 1)",
        "ground_bottom_color": "Color(0.01, 0.01, 0.02, 1)", "ground_horizon_color": "Color(0.08, 0.1, 0.16, 1)",
    }),
    ("Sky", "Sky_4", {"sky_material": 'SubResource("SkyMat_4")'}),
    ("Environment", "Env_4", {
        "background_mode": "2", "sky": 'SubResource("Sky_4")',
        "ambient_light_source": "2", "ambient_light_color": "Color(0.3, 0.35, 0.5, 1)",
        "ambient_light_energy": "0.58", "tonemap_mode": "2",
        "fog_enabled": "true", "fog_light_color": "Color(0.04, 0.05, 0.08, 1)", "fog_density": "0.01",
        "fog_sky_affect": "0.3",
    }),
]
L.node("WorldEnvironment", "WorldEnvironment", ".", environment='SubResource("Env_4")')
L.node("Moonlight", "DirectionalLight3D", ".",
       transform=xform((0, 40, 0), MOON),
       light_color="Color(0.6, 0.7, 1, 1)", light_energy="0.45", shadow_enabled="true",
       directional_shadow_max_distance="50.0", directional_shadow_mode="1")
# Взрывоопасные бочки и баллоны (места подобраны у стен рядом с постами врагов).
L.explosives([(-8.99, 0, -13.4), (9.5, 0, -44), (19.23, 0, -94.85), (2, 0, -99.5), (7.6, 0, -118.99), (-10, 0, -157), (-6.94, 0, -175.56), (2.56, 5, -217.94), (-12.77, 5, -212.15), (11.5, 5, -245.5)])

L.write("scenes/levels/level_4_mansion.tscn", env, ["pistol", "shotgun", "deagle"])
