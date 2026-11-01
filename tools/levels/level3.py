from levelkit import Level, xform, rot_x, rot_y, f, yaw_to
import math
import random

random.seed(3)
L = Level("Level3Skyscraper", {
    "level_index": "2",
    "title": '"Небоскрёб"',
    "objective": '"Поднимитесь на крышу к вертолёту"',
})
for g in ("Geometry", "Lights", "Props", "Enemies", "Pickups"):
    L.group(g)

WIN = {"E": (1.0, 5.0), "W": (1.0, 5.0)}

# L1 — скай-лобби (y = 0)
# P0 — подземный паркинг (y = -4), отсюда начинается уровень.
L.room("P0Parking", -14, 14, 0, 32, -4, 8, "concrete_dark", "concrete", "concrete",
       openings={"N": [(-3.5, 3.5, 4, 8)]})
L.ramp_z("Geometry/P0Parking", "Ramp", -3, 3, 14, -4, 2, 0, "concrete")
L.box_ext("Geometry/P0Parking", "Landing", -3, 3, -4, 0, 0, 2, "concrete")
for x in (-3.15, 3.15):
    L.ramp_z("Props", "RampWall", x - 0.15, x + 0.15, 14, -3, 2, 1, "hazard", t=0.6)
for x in (-6, 6):
    for z in (8, 16, 24):
        L.box("Props", "Pillar", (x, 0, z), (0.8, 8, 0.8), "concrete")
CARS = ["car_red", "car_blue", "car_white", "car_black"]
for i, z in enumerate((6, 10.5, 15, 19.5, 24, 28.5)):
    for side, x in ((0, -10.5), (1, 10.5)):
        if (i + side) % 3 == 2:
            continue
        mat = CARS[(i * 2 + side) % 4]
        L.box("Props", "Car", (x, -3.35, z), (4.4, 1.0, 2.0), mat)
        L.box("Props", "CarCabin", (x + (0.3 if side else -0.3), -2.55, z), (2.2, 0.65, 1.8), "dark_glass")
L.box("Props", "Lines", (0, -3.99, 16), (0.2, 0.02, 30), "road_line", collide=False, shadow=False)
for x, z in ((-8, 8), (8, 8), (-8, 24), (8, 24)):
    L.lamp((x, 3.9, z), 1.2, 11, mat="lamp_cold", color="Color(0.85, 0.92, 1, 1)", size=(0.3, 0.06, 2))
L.label("ПАРКИНГ  -1", (0, 1.5, 31.9), yaw=180, size=72, color="Color(0.95, 0.85, 0.3, 1)")
L.label("ЛОББИ", (0, 1.8, 0.6), size=56, color="Color(0.95, 0.85, 0.3, 1)")
L.enemy("gunner", (-8.5, -4, 6.5), look_at=(0, -4, 28))
L.enemy("gunner", (8.6, -4, 12.5), look_at=(0, -4, 28))
L.enemy("rusher", (-4, -4, 18), look_at=(0, -4, 28))
L.enemy("rusher", (4.5, -4, 21), look_at=(0, -4, 28))
L.enemy("gunner", (2, 0, 1), look_at=(0, -4, 28))
L.pickup("ammo", (-12.5, -4, 30.5))
L.player((0, -3.95, 28.5), 0)

# L1 — скай-лобби (y = 0)
L.room("L1Lobby", -10, 10, -20, 0, 0, 6, "floor_tiles", "office_wall", "ceiling",
       openings={"N": [(-3.5, 3.5, 4)], "S": [(-3.5, 3.5, 4)]}, windows=WIN)
L.box("Props", "Reception", (0, 0.55, -10), (6, 1.1, 1.2), "desk")
L.box("Props", "ReceptionTop", (0, 1.13, -10), (6.2, 0.06, 1.4), "wood", collide=False)
for x in (-6, 6):
    L.box("Props", "Column", (x, 3, -15), (1, 6, 1), "marble")
    L.box("Props", "Sofa", (x, 0.4, -5), (1, 0.8, 3), "train")
for x, z in ((-9, -1), (9, -1), (-9, -19), (9, -19)):
    L.box("Props", "Pot", (x, 0.35, z), (0.7, 0.7, 0.7), "pot")
    L.box("Props", "Plant", (x, 1.2, z), (0.9, 1.1, 0.9), "plant", collide=False)
for x in (-8, -5, 5, 8):
    L.box("Props", "ElevatorDoor", (x, 1.5, -0.05), (1.8, 3, 0.08), "metal", collide=False)
L.lamp((-5, 5.9, -6), 1.4, 11, mat="lamp_cold", color="Color(0.95, 0.97, 1, 1)", size=(1.5, 0.06, 1.5))
L.lamp((5, 5.9, -6), 1.4, 11, mat="lamp_cold", color="Color(0.95, 0.97, 1, 1)", size=(1.5, 0.06, 1.5))
L.lamp((0, 5.9, -16), 1.4, 11, mat="lamp_cold", color="Color(0.95, 0.97, 1, 1)", size=(1.5, 0.06, 1.5))
L.label("ВЕРТИКАЛЬ ПЛАЗА", (0, 4.6, -19.9), size=64, color="Color(0.85, 0.75, 0.45, 1)")
L.label("50", (-9.9, 4.2, -10), yaw=90, size=120, color="Color(0.85, 0.75, 0.45, 1)")
L.pickup("health", (8, 0, -17))
L.enemy("gunner", (-2.5, 0, -12), look_at=(0, 0, 0))
L.enemy("gunner", (2.5, 0, -12.5), look_at=(0, 0, 0))
L.enemy("rusher", (-7, 0, -17), look_at=(0, 0, 0))

# S1 — лестница A (с 0 на 5)
L.room("S1Stairs", -3, 3, -36, -20, 0, 10.5, "concrete", "concrete", "concrete",
       openings={"S": [(-3.5, 3.5, 0, 6.4)], "N": [(-3.5, 3.5, 5, 8.5)]})
L.ramp_z("Geometry/S1Stairs", "Ramp", -3, 3, -21, 0, -33, 5, "concrete")
L.box_ext("Geometry/S1Stairs", "Landing", -3, 3, 0, 5, -36, -33, "concrete")
L.lamp((0, 10.4, -27), 1.3, 11)
L.label("ЭТАЖ 51", (2.9, 7, -34.5), yaw=-90, size=56)
L.enemy("rusher", (0, 5, -34.5), look_at=(0, 0, -20))

# O1 — офисы (y = 5)
L.room("O1Offices", -14, 14, -66, -36, 5, 4, "carpet", "office_wall", "ceiling",
       openings={"S": [(-3.5, 3.5, 3.5)], "N": [(9.5, 14.5, 3.5)]}, windows={"E": (0.9, 3.3), "W": (0.9, 3.3)})
for z in (-42, -50, -58):
    for x in (-9, 0, 9):
        if (x, z) == (0, -42):
            continue
        L.box("Props", "Desk", (x, 5.375, z), (2.6, 0.75, 1.2), "desk")
        L.box("Props", "Partition", (x, 5.65, z - 0.72), (2.8, 1.3, 0.1), "train")
        L.box("Props", "Monitor", (x - 0.6, 6.0, z - 0.3), (0.6, 0.4, 0.06), "monitor", collide=False)
        L.box("Props", "Monitor", (x + 0.6, 6.0, z - 0.3), (0.6, 0.4, 0.06), "monitor", collide=False)
L.box("Props", "Copier", (-12.8, 5.6, -64.5), (1.4, 1.2, 1), "white_paint")
for x, z in ((-13, -37), (13, -65)):
    L.box("Props", "Pot", (x, 5.35, z), (0.7, 0.7, 0.7), "pot")
    L.box("Props", "Plant", (x, 6.2, z), (0.9, 1.1, 0.9), "plant", collide=False)
for x, z in ((-7, -45), (7, -45), (-7, -59), (7, -59)):
    L.lamp((x, 8.9, z), 1.3, 10, mat="lamp_cold", color="Color(0.95, 0.97, 1, 1)", size=(1.5, 0.06, 1.5))
L.pickup("ammo", (-12, 5, -38))
L.pickup("health", (12.5, 5, -40))
L.enemy("gunner", (-9, 5, -62), look_at=(0, 5, -36))
L.enemy("gunner", (9, 5, -54.5), look_at=(0, 5, -36))
L.enemy("gunner", (0.5, 5, -63.5), look_at=(0, 5, -36))
L.enemy("heavy", (12, 5, -62.5), look_at=(0, 5, -36))
L.enemy("rusher", (-5, 5, -46), look_at=(0, 5, -36))
L.wave_zone("ZoneOffice", (0, 7, -51), (22, 4, 12),
            spawns=[(-13, 5.1, -44), (-13, 5.1, -58), (12.5, 5.1, -64.5), (13, 5.1, -48)],
            barriers=[((0, 6.75, -35.85), (7.4, 3.5, 0.3)), ((12, 6.75, -66.15), (5.4, 3.5, 0.3))],
            title="Охрана подняла тревогу!", waves=2, first=4, extra=2, rusher=0.4)

# S2 — лестница B (с 5 на 10)
L.room("S2Stairs", 10, 14, -82, -66, 5, 10.5, "concrete", "concrete", "concrete",
       openings={"S": [(9.5, 14.5, 0, 4.4)], "N": [(9.5, 14.5, 5, 8.5)]})
L.ramp_z("Geometry/S2Stairs", "Ramp", 10, 14, -67, 5, -79, 10, "concrete")
L.box_ext("Geometry/S2Stairs", "Landing", 10, 14, 5, 10, -82, -79, "concrete")
L.lamp((12, 15.4, -73), 1.3, 11)
L.label("ЭТАЖ 52", (13.9, 12, -80.5), yaw=-90, size=56)

# SR — серверная (y = 10)
L.room("SRServers", -8, 16, -100, -82, 10, 4.5, "metal", "concrete", "concrete_dark",
       openings={"S": [(9.5, 14.5, 3.5)], "N": [(-7.5, -2.5, 3.5)]})
for x in (0, 4, 8):
    L.box("Props", "Rack", (x, 11.1, -91), (1.0, 2.2, 10), "server")
    for side in (-0.51, 0.51):
        L.box("Props", "Leds", (x + side, 11.6, -91), (0.02, 0.06, 9), "led", collide=False, shadow=False)
L.box("Props", "Rack", (-4, 11.1, -86), (3, 2.2, 1.0), "server")
L.box("Props", "Rack", (12, 11.1, -96), (3, 2.2, 1.0), "server")
for x in (-4, 6, 13):
    L.lamp((x, 14.4, -91), 1.2, 10, mat="lamp_cold", color="Color(0.6, 0.85, 1, 1)", size=(0.3, 0.06, 3))
L.pickup("health", (14.5, 10, -98.5))
L.pickup("ammo", (-7, 10, -83.5))
L.enemy("gunner", (-6, 10, -92), look_at=(12, 10, -82))
L.enemy("gunner", (2, 10, -98.5), look_at=(12, 10, -82))
L.enemy("rusher", (6, 10, -84), look_at=(12, 10, -82))
L.enemy("gunner", (13, 10, -97), look_at=(12, 10, -82))
L.enemy("rusher", (-2, 10, -88), look_at=(12, 10, -82))

# S3 — лестница C (с 10 на 15)
L.room("S3Stairs", -7, -3, -116, -100, 10, 10.5, "concrete", "concrete", "concrete",
       openings={"S": [(-7.5, -2.5, 0, 4.9)], "N": [(-7.5, -2.5, 5, 8.5)]})
L.ramp_z("Geometry/S3Stairs", "Ramp", -7, -3, -101, 10, -113, 15, "concrete")
L.box_ext("Geometry/S3Stairs", "Landing", -7, -3, 10, 15, -116, -113, "concrete")
L.lamp((-5, 20.4, -107), 1.3, 11)
L.label("ЭТАЖ 53", (-3.1, 17, -114.5), yaw=-90, size=56)

# F4 — ресторан (y = 15)
L.room("F4Restaurant", -16, 12, -146, -116, 15, 4.5, "parquet", "office_wall", "ceiling",
       openings={"S": [(-7.5, -2.5, 3.5)], "N": [(5.5, 10.5, 3.5)]}, windows={"E": (0.9, 3.6), "W": (0.9, 3.6)})
for x in (-11, -5, 1, 7):
    for z in (-122, -130, -138):
        if (x, z) in ((-5, -122), (7, -138)):
            continue
        L.box("Props", "Table", (x, 15.37, z), (1.4, 0.74, 1.4), "desk")
        L.box("Props", "Cloth", (x, 15.75, z), (1.5, 0.02, 1.5), "bed_sheet", collide=False)
        for dx in (-1.0, 1.0):
            L.box("Props", "Chair", (x + dx, 15.25, z), (0.5, 0.5, 0.5), "sofa")
L.box("Props", "Bar", (-14.8, 15.55, -131), (1.2, 1.1, 14), "wood")
L.box("Props", "BarTop", (-14.6, 16.12, -131), (1.5, 0.06, 14.2), "marble", collide=False)
L.box("Props", "Shelf", (-15.9, 17, -131), (0.2, 2.4, 12), "wood", collide=False)
L.box("Props", "Kitchen", (10.6, 15.5, -126), (2.4, 1.0, 8), "metal")
L.box("Props", "Hood", (10.9, 18.2, -126), (1.8, 0.6, 7), "metal", collide=False)
for x, z in ((-8, -124), (4, -124), (-8, -138), (4, -138)):
    L.lamp((x, 19.4, z), 1.3, 10, color="Color(1, 0.85, 0.6, 1)", size=(1.0, 0.06, 1.0))
L.label("РЕСТОРАН «ОБЛАКА»", (-2, 18.2, -145.9), size=64, color="Color(0.85, 0.75, 0.45, 1)")
L.pickup("health", (-13, 15, -119))
L.pickup("ammo", (10.5, 15, -143))
L.enemy("gunner", (-13.5, 15, -136), look_at=(-5, 15, -116))
L.enemy("gunner", (4, 15, -134), look_at=(-5, 15, -116))
L.enemy("gunner", (9, 15, -142), look_at=(-5, 15, -116))
L.enemy("rusher", (-2, 15, -127), look_at=(-5, 15, -116))
L.enemy("rusher", (2, 15, -140), look_at=(-5, 15, -116))

# S4 — лестница D (с 15 на 20)
L.room("S4Stairs", 6, 10, -162, -146, 15, 10.5, "concrete", "concrete", "concrete",
       openings={"S": [(5.5, 10.5, 0, 4.9)], "N": [(5.5, 10.5, 5, 8.5)]})
L.ramp_z("Geometry/S4Stairs", "Ramp", 6, 10, -147, 15, -159, 20, "concrete")
L.box_ext("Geometry/S4Stairs", "Landing", 6, 10, 15, 20, -162, -159, "concrete")
L.lamp((8, 25.4, -153), 1.3, 11)
L.label("ПЕНТХАУС", (9.9, 22, -160.5), yaw=-90, size=56)
L.enemy("gunner", (9, 20, -161), look_at=(8, 15, -146))

# F5 — пентхаус босса (y = 20, волны)
L.room("F5Penthouse", -14, 14, -192, -162, 20, 5, "parquet", "wallpaper", "ceiling",
       openings={"S": [(5.5, 10.5, 3.5)], "N": [(-12.5, -7.5, 3.5)]}, windows={"E": (0.6, 4.4), "W": (0.6, 4.4)})
L.box("Props", "Carpet", (0, 20.02, -177), (12, 0.02, 10), "red_carpet", collide=False, shadow=False)
L.box("Props", "SofaL", (-4.5, 20.45, -177), (1.0, 0.9, 5), "sofa")
L.box("Props", "SofaR", (4.5, 20.45, -177), (1.0, 0.9, 5), "sofa")
L.box("Props", "CoffeeTable", (0, 20.3, -177), (2.4, 0.6, 1.4), "dark_glass")
L.box("Props", "Piano", (-10, 20.6, -186), (2.2, 1.2, 1.6), "black_metal")
L.box("Props", "AquariumGlass", (10, 21.2, -185), (1.2, 2.4, 5), "glass")
L.box("Props", "AquariumWater", (10, 21.0, -185), (1.0, 1.9, 4.8), "pool_water", collide=False)
L.box("Props", "Statue", (0, 21.2, -189.5), (0.8, 2.4, 0.8), "gold")
L.box("Props", "Bar", (-12.5, 20.55, -168), (2.4, 1.1, 1.0), "wood")
for x, z in ((-8, -168), (8, -172), (-8, -184), (6, -186)):
    L.lamp((x, 24.9, z), 1.3, 11, mat="gold", color="Color(1, 0.85, 0.6, 1)", size=(0.8, 0.1, 0.8))
L.label("ПЕНТХАУС", (0, 23.6, -191.9), size=72, color="Color(0.95, 0.8, 0.4, 1)")
L.pickup("health", (12.5, 20, -164))
L.pickup("ammo", (-12.5, 20, -190))
L.enemy("gunner", (-10, 20, -180), look_at=(8, 20, -162))
L.enemy("gunner", (6, 20, -189), look_at=(8, 20, -162))
L.enemy("heavy", (-10.5, 20, -190), look_at=(8, 20, -162))
L.enemy("rusher", (0, 20, -182), look_at=(8, 20, -162))
L.wave_zone("ZonePenthouse", (0, 22, -177), (24, 4, 24),
            spawns=[(-13, 20.1, -165), (13, 20.1, -190), (-13, 20.1, -190), (0, 20.1, -191)],
            barriers=[((8, 21.75, -161.85), (5.4, 3.5, 0.3)), ((-10, 21.75, -192.15), (5.4, 3.5, 0.3))],
            title="Охрана босса!", waves=2, first=5, extra=2, rusher=0.35, heavy=1)

# S5 — выход на крышу (с 20 на 25)
L.room("S5Stairs", -12, -8, -208, -192, 20, 10.5, "concrete", "concrete", "concrete",
       openings={"S": [(-12.5, -7.5, 0, 5.4)], "N": [(-12.5, -7.5, 5, 10.5)]})
L.ramp_z("Geometry/S5Stairs", "Ramp", -12, -8, -193, 20, -205, 25, "concrete")
L.box_ext("Geometry/S5Stairs", "Landing", -12, -8, 20, 25, -208, -205, "concrete")
L.lamp((-10, 30.4, -199), 1.3, 11)
L.label("КРЫША", (-8.1, 27, -206.5), yaw=-90, size=56)

# Крыша (y = 25), без потолка.
ROOF = 25
L.room("Roof", -22, 22, -252, -208, ROOF, 1.1, "gravel", "concrete", None,
       openings={"S": [(-12.5, -7.5)]})
L.box_ext("Props", "Shell", -22.5, 22.5, -150, ROOF - 0.5, -252.5, -207.5, "skyline", collide=False)
for x0, x1, z0, z1 in ((-22.5, -22, -252.5, -207.5), (22, 22.5, -252.5, -207.5), (-22.5, 22.5, -252.5, -252)):
    L.invisible_wall("Geometry", "Guard", ((x0 + x1) / 2, ROOF + 2.5, (z0 + z1) / 2), (x1 - x0, 4, z1 - z0))
for x0, x1 in ((-22.5, -12.5), (-7.5, 22.5)):
    L.invisible_wall("Geometry", "Guard", ((x0 + x1) / 2, ROOF + 2.5, -207.75), (x1 - x0, 4, 0.5))
for x, z, w, d in ((-1, -217, 3, 2), (10, -220, 3, 2.2), (-14, -237, 3.2, 2), (14, -242, 2.6, 3)):
    L.box("Props", "Hvac", (x, ROOF + 1, z), (w, 2, d), "metal")
    L.box("Props", "Fan", (x, ROOF + 2.02, z), (w * 0.6, 0.04, d * 0.6), "rubber", collide=False)
L.cylinder("Props", "Tank", (16, ROOF + 2, -214), 2, 4, "white_paint", sides=16)
L.box("Props", "Antenna", (-18, ROOF + 4, -248), (0.3, 8, 0.3), "metal")
L.box("Props", "AntennaLight", (-18, ROOF + 8.1, -248), (0.4, 0.3, 0.4), "lamp_red", collide=False)
L.box("Props", "Helipad", (0, ROOF + 0.02, -240), (12, 0.04, 12), "rubber", collide=False, shadow=False)
for cx, cz, w, d in ((0, -234.2, 10, 0.4), (0, -245.8, 10, 0.4), (-5.8, -240, 0.4, 12), (5.8, -240, 0.4, 12)):
    L.box("Props", "PadRing", (cx, ROOF + 0.05, cz), (w, 0.02, d), "hazard", collide=False, shadow=False)
for cx, cz, w, d in ((-1.5, -240, 0.6, 5), (1.5, -240, 0.6, 5), (0, -240, 2.4, 0.6)):
    L.box("Props", "PadH", (cx, ROOF + 0.06, cz), (w, 0.02, d), "white_paint", collide=False, shadow=False)
L.lamp((-10, ROOF + 1.6, -209.5), 1.2, 8, mat="lamp", size=(0.5, 0.1, 0.2))
L.pickup("health", (-20, ROOF, -210))
L.pickup("ammo", (20, ROOF, -210))
L.pickup("ammo", (0, ROOF, -224))
L.enemy("gunner", (-10, ROOF, -224), look_at=(-10, ROOF, -208))
L.enemy("gunner", (10, ROOF, -232), look_at=(-10, ROOF, -208))
L.enemy("gunner", (3, ROOF, -247), look_at=(-10, ROOF, -208))
# Босс Толстяк ждёт на вертолётной площадке; на каждой фазе с краёв крыши лезет подмога.
L.boss("fat_boss", "FatBoss", (0, ROOF, -246), (-10, ROOF, -208),
       henchman_points='NodePath("../../BossSpawns")')
L.markers("BossSpawns", [(f"Spawn{i}", (x, ROOF + 0.1, z), yaw_to((x, z), (0, -230)))
                         for i, (x, z) in enumerate(((-19, -249), (19, -249), (-19, -212), (19, -218),
                                                     (0, -250.5), (20, -232)))])
L.explosives([(1.2, ROOF, -217), (13.5, ROOF, -211.5), (-14, ROOF, -235.3), (14, ROOF, -244.3)], pattern="BCBB")
L.exit((0, ROOF + 1.5, -240), (6, 3, 6), (0, ROOF + 4.5, -240), "ЭВАКУАЦИЯ", required_zone="Enemies/FatBoss")

# Город вокруг: небоскрёбы с окнами (кольцо вокруг вытянутого здания).
for i in range(28):
    angle = i / 28 * math.tau + random.uniform(-0.06, 0.06)
    extra = random.uniform(0, 60)
    cx, cz = math.sin(angle) * (70 + extra), -110 + math.cos(angle) * (175 + extra)
    w, d = random.uniform(14, 30), random.uniform(14, 30)
    top = random.uniform(-10, 80)
    L.box_ext("Props", "Tower", cx - w / 2, cx + w / 2, -150, top, cz - d / 2, cz + d / 2, "skyline",
              collide=False, shadow=False)

L.waypoint((0, -4, 28.5), (0, -4, 15), (0, 0, 1.5), (0, 0, -2), (4, 0, -6), (4, 0, -16), (0, 0, -19),
           (0, 0, -21.5), (0, 5, -33.5), (0, 5, -35), (0, 5, -38), (4.5, 5, -46), (4.5, 5, -62), (12, 5, -65),
           (12, 5, -67.5), (12, 10, -79.5), (12, 10, -83), (13.5, 10, -86), (13.5, 10, -94), (14.5, 10, -98.5),
           (-5, 10, -98.5), (-5, 10, -101.5), (-5, 15, -113.5), (-5, 15, -117), (-2, 15, -126), (-2, 15, -142),
           (8, 15, -144), (8, 15, -147.5), (8, 20, -159.5), (8, 20, -163), (7.2, 20, -181), (2, 20, -186),
           (-7, 20, -187.5), (-10, 20, -190), (-10, 20, -193.5), (-10, 25, -205.5), (-10, 25, -209), (0, ROOF, -224), (0, ROOF, -240))

env = [
    ("ProceduralSkyMaterial", "SkyMat_3", {
        "sky_top_color": "Color(0.015, 0.02, 0.05, 1)", "sky_horizon_color": "Color(0.2, 0.13, 0.18, 1)",
        "ground_bottom_color": "Color(0.02, 0.02, 0.03, 1)", "ground_horizon_color": "Color(0.14, 0.1, 0.14, 1)",
    }),
    ("Sky", "Sky_3", {"sky_material": 'SubResource("SkyMat_3")'}),
    ("Environment", "Env_3", {
        "background_mode": "2", "sky": 'SubResource("Sky_3")',
        "ambient_light_source": "2", "ambient_light_color": "Color(0.32, 0.34, 0.46, 1)",
        "ambient_light_energy": "0.6", "tonemap_mode": "2",
        "fog_enabled": "true", "fog_light_color": "Color(0.1, 0.08, 0.12, 1)", "fog_density": "0.0035",
        "fog_sky_affect": "0.15",
    }),
]
L.node("WorldEnvironment", "WorldEnvironment", ".", environment='SubResource("Env_3")')
L.node("Sun", "DirectionalLight3D", ".",
       transform=xform((0, 40, 0), [[-0.5, -0.4924, 0.7124], [0, 0.8226, 0.5686], [-0.866, 0.2843, -0.4113]]),
       light_color="Color(0.62, 0.7, 1, 1)", light_energy="0.45", shadow_enabled="true",
       directional_shadow_max_distance="60.0", directional_shadow_mode="1")
# Взрывоопасные бочки и баллоны (места подобраны у стен рядом с постами врагов).
L.explosives([(-6.86, -4, 7.56), (6.34, -4, 22.84), (3.06, 0, -0.06), (2.4, 5, -33.51), (-9, 5, -59.4), (13.5, 5, -62.5), (-7.5, 10, -92), (7.41, 10, -82.59), (-12.73, 15, -137.85), (2.57, 15, -138.61), (10.84, 20, -162.84), (-10.5, 20, -187.4)])

L.pickup("weapon", (-4, ROOF, -214), weapon="rpg")
L.write("scenes/levels/level_3_skyscraper.tscn", env, ["pistol", "shotgun", "deagle"])
