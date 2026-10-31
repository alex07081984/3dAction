from levelkit import Level, xform, rot_x, rot_y, f
import math

L = Level("Level1Underground", {
    "level_index": "0",
    "title": '"Подземка"',
    "objective": '"Выберитесь из коллектора"',
})
for g in ("Geometry", "Lights", "Props", "Enemies", "Pickups"):
    L.group(g)

T = 0.5
DOOR = 3.5

# R1 — шахта входа
L.room("R1Shaft", -5, 5, -8, 0, 0, 5, "concrete_dark", "concrete", "concrete_dark",
       openings={"N": [(-2.5, 2.5, DOOR)]})
L.lamp((0, 4.9, -4), 1.6, 10)
L.box("Props", "Ladder", (0, 2.5, -0.15), (1.2, 5, 0.1), "metal", collide=False)
for y in range(1, 5):
    L.box("Props", "Rung", (0, y, -0.3), (1.0, 0.06, 0.06), "metal", collide=False)
L.box("Props", "Crate", (-3.8, 0.5, -1.5), (1.2, 1, 1.2), "crate")
L.box("Props", "Crate", (3.8, 0.5, -6.5), (1.2, 1, 1.2), "crate")
L.label("КОЛЛЕКТОР 7", (0, 4.25, -7.9), size=64, color="Color(0.9, 0.85, 0.6, 1)")
L.player((0, 0.05, -3), 0)

# C1 — кирпичный коридор
L.room("C1Tunnel", -2, 2, -28, -8, 0, DOOR, "concrete_dark", "brick", "concrete", sides={"N": False, "S": False})
L.cylinder("Props", "Pipe", (-1.65, 2.9, -18), 0.18, 20, "pipe", collide=False, rows=rot_x(math.pi / 2))
L.cylinder("Props", "Pipe", (1.7, 3.1, -18), 0.12, 20, "pipe_blue", collide=False, rows=rot_x(math.pi / 2))
L.box("Props", "Crate", (-1.2, 0.5, -17), (1.2, 1, 1.2), "crate")
L.lamp((0, 3.4, -12), 1.2, 8)
L.lamp((0, 3.4, -23), 1.2, 8)
L.enemy("gunner", (1.0, 0, -25.5), look_at=(0, 0, -8))

# R2 — насосная
L.room("R2Pumps", -9, 9, -44, -28, 0, 6, "concrete_dark", "concrete", "concrete_dark",
       openings={"S": [(-2.5, 2.5, DOOR)], "E": [(-40.5, -35.5, DOOR)]})
L.cylinder("Props", "Pump", (-5, 1.5, -37), 1.3, 3, "pipe_blue", sides=16)
L.cylinder("Props", "Pump", (4.5, 1.5, -33), 1.3, 3, "pipe_blue", sides=16)
L.cylinder("Props", "PumpPipe", (-5, 4.6, -37), 0.35, 3.2, "pipe", collide=False)
L.cylinder("Props", "PumpPipe", (4.5, 4.6, -33), 0.35, 3.2, "pipe", collide=False)
L.box("Props", "Ledge", (0, 1.25, -43.25), (18, 2.5, 1.5), "metal")
L.box("Props", "Rail", (0, 3.0, -42.55), (18, 0.08, 0.08), "rail", collide=False)
for x in (-6.8, 6.8):
    L.box("Props", "Crate", (x, 0.6, -30), (1.4, 1.2, 1.4), "crate")
L.box("Props", "Crate", (1.5, 0.5, -39), (1.2, 1, 1.2), "crate")
L.box("Props", "Crate", (-1.5, 0.5, -31.5), (1.0, 1, 1.0), "crate")
L.lamp((-4, 5.9, -36), 1.5, 11)
L.lamp((4, 5.9, -36), 1.5, 11)
L.pickup("weapon", (-2.5, 0, -40.5), weapon="shotgun")
L.pickup("health", (7.5, 0, -40))
L.enemy("gunner", (-6.5, 0, -40.5), look_at=(0, 0, -28))
L.enemy("gunner", (6.5, 0, -36), look_at=(0, 0, -28))
L.enemy("rusher", (0, 0, -41), look_at=(0, 0, -28))
L.enemy("gunner", (3, 2.5, -43.3), look_at=(0, 0, -28))
L.label("НАСОСНАЯ", (0, 4.6, -43.9), yaw=0, size=56, color="Color(0.9, 0.85, 0.6, 1)")

# C2 — коридор на восток
L.room("C2Tunnel", 9, 27, -40, -36, 0, DOOR, "concrete_dark", "brick", "concrete", sides={"W": False, "E": False})
L.box("Props", "Water", (18, 0.015, -38), (18, 0.03, 1.2), "water", collide=False, shadow=False)
L.cylinder("Props", "Pipe", (18, 3.0, -36.4), 0.15, 18, "pipe", collide=False,
           rows=[[0, -1, 0], [1, 0, 0], [0, 0, 1]])
L.lamp((14, 3.4, -38), 1.1, 8)
L.lamp((22, 3.4, -38), 1.1, 8)
L.enemy("rusher", (23.5, 0, -37.2), look_at=(9, 0, -38))
L.enemy("gunner", (26, 0, -39.2), look_at=(9, 0, -38))

# R3 — развилка
L.room("R3Junction", 27, 37, -46, -30, 0, 4.5, "concrete_dark", "concrete", "concrete_dark",
       openings={"W": [(-40.5, -35.5, DOOR)], "N": [(29.5, 34.5, DOOR)]})
L.box("Props", "Crate", (34.5, 0.6, -36.5), (1.4, 1.2, 1.4), "crate")
L.box("Props", "Crate", (29.5, 0.5, -43.5), (1.2, 1, 1.2), "crate")
for p in ((35.5, -31.5), (35.6, -32.6), (28.5, -31)):
    L.cylinder("Props", "Barrel", (p[0], 0.55, p[1]), 0.4, 1.1, "lamp_red" if p[0] > 35.5 else "pipe_blue")
L.lamp((32, 4.4, -38), 1.4, 10)
L.pickup("ammo", (35.5, 0, -44))
L.enemy("gunner", (35, 0, -42.5), look_at=(27, 0, -38))
L.label("СЕКТОР Б", (36.9, 2.6, -38), yaw=-90, size=48, color="Color(0.9, 0.85, 0.6, 1)")

# C3 — коридор на север
L.room("C3Tunnel", 30, 34, -66, -46, 0, DOOR, "concrete_dark", "brick", "concrete", sides={"N": False, "S": False})
L.box("Props", "Crate", (30.9, 0.5, -52), (1.2, 1, 1.2), "crate")
L.box("Props", "Crate", (32.9, 0.45, -59), (1.0, 0.9, 1.0), "crate")
L.lamp((32, 3.4, -51), 1.1, 8)
L.lamp((32, 3.4, -61), 1.1, 8)
L.enemy("gunner", (31, 0, -63), look_at=(32, 0, -46))
L.enemy("gunner", (33.2, 0, -57.5), look_at=(32, 0, -46))

# R4 — отстойник (волны 1)
L.room("R4Settler", 22, 42, -88, -66, 0, 7, "concrete_dark", "concrete", "concrete_dark",
       openings={"S": [(29.5, 34.5, DOOR)], "N": [(29.5, 34.5, DOOR)]})
for x, z in ((26, -70), (38, -70), (26, -84), (38, -84)):
    L.box("Props", "Pillar", (x, 3.5, z), (1.2, 7, 1.2), "concrete")
L.box("Props", "Water", (32, 0.015, -77), (8, 0.03, 8), "water", collide=False, shadow=False)
L.box("Props", "Block", (28, 0.55, -79), (3, 1.1, 0.6), "concrete")
L.box("Props", "Block", (36, 0.55, -75), (3, 1.1, 0.6), "concrete")
L.box("Props", "Crate", (29, 0.6, -73.5), (1.2, 1.2, 1.2), "crate")
L.box("Props", "Crate", (35, 0.6, -81), (1.2, 1.2, 1.2), "crate")
for x, z in ((22.3, -86), (41.7, -86), (22.3, -68), (41.7, -68)):
    L.box("Props", "Grate", (x, 1.2, z), (0.2, 2.4, 2.2), "metal", collide=False)
L.lamp((27, 6.9, -73), 1.6, 12)
L.lamp((37, 6.9, -73), 1.6, 12)
L.lamp((32, 6.9, -83), 1.6, 12)
L.pickup("ammo", (24.5, 0, -77))
L.pickup("health", (39.5, 0, -77))
L.wave_zone("ZoneSettler", (32, 2, -77), (16, 4, 16),
            spawns=[(23.5, 0.1, -86.5), (40.5, 0.1, -86.5), (23.5, 0.1, -67.5), (40.5, 0.1, -67.5)],
            barriers=[((32, 1.75, -65.85), (5.2, 3.5, 0.3)), ((32, 1.75, -88.15), (5.2, 3.5, 0.3))],
            title="Засада в отстойнике!", waves=2, first=4, extra=2, rusher=0.35)

# C4 — коридор
L.room("C4Tunnel", 30, 34, -104, -88, 0, DOOR, "concrete_dark", "brick", "concrete", sides={"N": False, "S": False})
L.lamp((32, 3.4, -96), 1.1, 8)
L.enemy("rusher", (31, 0, -100), look_at=(32, 0, -88))
L.enemy("rusher", (33, 0, -101.5), look_at=(32, 0, -88))

# R5 — шлюз (волны 2)
L.room("R5Sluice", 24, 40, -124, -104, 0, 6, "concrete_dark", "concrete", "concrete_dark",
       openings={"S": [(29.5, 34.5, DOOR)], "N": [(29.5, 34.5, DOOR)]})
for x, z in ((27.5, -109), (36.5, -110), (28, -119), (36, -118.5)):
    L.box("Props", "Crate", (x, 0.75, z), (1.6, 1.5, 1.6), "crate")
L.box("Props", "Block", (32, 0.55, -114), (4, 1.1, 0.6), "concrete")
L.box("Props", "Gate", (32, 4.8, -123.8), (6, 2.4, 0.3), "hazard", collide=False)
L.lamp((28, 5.9, -114), 1.5, 11)
L.lamp((36, 5.9, -114), 1.5, 11)
L.pickup("health", (25, 0, -105))
L.pickup("ammo", (39, 0, -105))
L.wave_zone("ZoneSluice", (32, 2, -114), (12, 4, 14),
            spawns=[(25.5, 0.1, -122.5), (38.5, 0.1, -122.5), (25.5, 0.1, -105.5), (38.5, 0.1, -105.5)],
            barriers=[((32, 1.75, -103.85), (5.2, 3.5, 0.3)), ((32, 1.75, -124.15), (5.2, 3.5, 0.3))],
            title="Шлюз заблокирован!", waves=2, first=5, extra=2, rusher=0.3, heavy=1)

# C5 — коридор к большому коллектору
L.room("C5Tunnel", 30, 34, -140, -124, 0, DOOR, "concrete_dark", "brick", "concrete", sides={"S": False, "N": False})
L.lamp((32, 3.4, -130), 1.1, 8)
L.enemy("gunner", (31, 0, -135), look_at=(32, 0, -124))

# R6 — большой коллектор: канал с водой посередине и мостки по бокам (пол канала на -1).
L.room("R6Channel", 26, 38, -176, -140, -1, 8, "concrete_dark", "brick", "concrete_dark",
       openings={"S": [(29.5, 34.5, 1, 1 + DOOR)], "N": [(25.5, 30.5, 1, 1 + DOOR)]})
g = "Geometry/R6Channel"
L.box_ext(g, "WalkLeft", 26, 30, -1, 0, -176, -140, "concrete")
L.box_ext(g, "WalkRight", 34, 38, -1, 0, -176, -140, "concrete")
L.box_ext(g, "Landing", 30, 34, -1, 0, -144, -140, "concrete")
for z in (-151, -165):
    L.box_ext(g, "Bridge", 30, 34, -0.3, 0, z - 1, z + 1, "metal")
L.box_ext("Props", "Water", 30, 34, -0.95, -0.9, -176, -144, "water", collide=False, shadow=False)
for x in (30.05, 33.95):
    L.box_ext("Props", "Rail", x - 0.05, x + 0.05, 0.9, 1.0, -176, -144, "rail", collide=False)
L.cylinder("Props", "Pipe", (26.4, 5.5, -158), 0.3, 36, "pipe", collide=False, rows=rot_x(math.pi / 2))
L.cylinder("Props", "Pipe", (37.6, 6.0, -158), 0.25, 36, "pipe_blue", collide=False, rows=rot_x(math.pi / 2))
L.box("Props", "Crate", (36.5, 0.5, -155), (1.2, 1, 1.2), "crate")
L.box("Props", "Crate", (27.4, 0.5, -163), (1.0, 1, 1.0), "crate")
L.lamp((32, 6.9, -150), 1.4, 12)
L.lamp((32, 6.9, -166), 1.4, 12)
L.label("ГЛАВНЫЙ КОЛЛЕКТОР", (32, 4.5, -175.9), size=56, color="Color(0.9, 0.85, 0.6, 1)")
L.pickup("health", (37, 0, -146))
L.pickup("ammo", (27, 0, -150))
L.enemy("gunner", (27.2, 0, -170), look_at=(32, 0, -140))
L.enemy("gunner", (36.8, 0, -161), look_at=(32, 0, -140))
L.enemy("rusher", (28.2, 0, -158), look_at=(32, 0, -140))
L.enemy("gunner", (36.5, 0, -173), look_at=(32, 0, -140))
L.enemy("heavy", (32, -1, -172), look_at=(32, 0, -140))

# C6 — коридор к бомбоубежищу
L.room("C6Tunnel", 26, 30, -196, -176, 0, DOOR, "concrete_dark", "brick", "concrete", sides={"N": False, "S": False})
L.lamp((28, 3.4, -186), 1.1, 8)
L.enemy("gunner", (29, 0, -193), look_at=(28, 0, -176))

# R7 — бомбоубежище (волны 3)
L.room("R7Bunker", 18, 38, -222, -196, 0, 4, "concrete_dark", "concrete", "concrete",
       openings={"S": [(25.5, 30.5, DOOR)], "W": [(-212.5, -207.5, DOOR)]})
for z in (-200, -205, -210, -215):
    L.box("Props", "Bunk", (36.6, 0.45, z), (2.2, 0.9, 1.0), "metal")
    L.box("Props", "BunkTop", (36.6, 1.6, z), (2.2, 0.1, 1.0), "metal", collide=False)
    L.box("Props", "Blanket", (36.6, 0.95, z), (2.0, 0.12, 0.9), "blanket", collide=False)
for x in range(20, 36, 2):
    L.box("Props", "Locker", (x, 1.0, -221.5), (0.9, 2.0, 0.6), "metal")
L.box("Props", "Table", (31.5, 0.4, -214), (2.4, 0.8, 1.2), "wood")
L.box("Props", "Crate", (21, 0.6, -201), (1.2, 1.2, 1.2), "crate")
L.box("Props", "Crate", (23.5, 0.6, -216), (1.2, 1.2, 1.2), "crate")
L.box("Props", "BlastDoor", (25, 1.75, -196.2), (0.3, 3.5, 3.6), "hazard", collide=False)
L.lamp((24, 3.9, -204), 1.3, 10)
L.lamp((32, 3.9, -214), 1.3, 10)
L.label("БОМБОУБЕЖИЩЕ", (28, 3.4, -221.1), size=56, color="Color(0.9, 0.85, 0.6, 1)")
L.pickup("health", (35, 0, -219))
L.pickup("ammo", (19.5, 0, -205))
L.wave_zone("ZoneBunker", (28, 2, -209), (18, 4, 22),
            spawns=[(19.5, 0.1, -220.5), (36.5, 0.1, -220), (36, 0.1, -197.5), (19.5, 0.1, -197.5)],
            barriers=[((28, 1.75, -195.85), (5.2, 3.5, 0.3)), ((17.85, 1.75, -210), (0.3, 3.5, 5.2))],
            title="Бомбоубежище!", waves=2, first=5, extra=2, rusher=0.35, heavy=1)

# C7 — коридор на запад
L.room("C7Tunnel", 0, 18, -212, -208, 0, DOOR, "concrete_dark", "brick", "concrete", sides={"W": False, "E": False})
L.lamp((9, 3.4, -210), 1.1, 8)
L.enemy("gunner", (2, 0, -209), look_at=(18, 0, -210))
L.enemy("rusher", (6, 0, -211), look_at=(18, 0, -210))

# R8 — котельная
L.room("R8Boilers", -20, 0, -228, -196, 0, 6, "concrete_dark", "brick", "concrete_dark",
       openings={"E": [(-212.5, -207.5, DOOR)], "N": [(-16.5, -7.5, 4)]})
for z in (-201, -211):
    L.cylinder("Props", "Boiler", (-17, 2, z), 1.6, 4, "rust", sides=16)
    L.cylinder("Props", "Chimney", (-17, 5, z), 0.4, 2, "pipe", collide=False)
L.box("Props", "Furnace", (-4, 1, -200), (3, 2, 2), "rust")
L.box("Props", "FurnaceGlow", (-4, 0.7, -198.98), (1.6, 0.6, 0.05), "lamp_red", collide=False)
L.box("Props", "CoalPile", (-3, 0.4, -222), (3, 0.8, 3), "concrete_dark")
L.box("Props", "Crate", (-8, 0.6, -205), (1.2, 1.2, 1.2), "crate")
L.box("Props", "Crate", (-13, 0.6, -220), (1.2, 1.2, 1.2), "crate")
L.lamp((-15, 5.9, -205), 1.3, 11, color="Color(1, 0.75, 0.5, 1)")
L.lamp((-5, 5.9, -209), 1.3, 11, color="Color(1, 0.75, 0.5, 1)")
L.lamp((-10, 5.9, -222), 1.3, 11, color="Color(1, 0.75, 0.5, 1)")
L.label("КОТЕЛЬНАЯ", (-0.1, 4.4, -203), yaw=-90, size=56, color="Color(0.9, 0.85, 0.6, 1)")
L.pickup("health", (-2, 0, -226))
L.pickup("ammo", (-19, 0, -198))
L.enemy("gunner", (-18.5, 0, -224), look_at=(0, 0, -210))
L.enemy("gunner", (-2, 0, -217), look_at=(0, 0, -210))
L.enemy("gunner", (-10, 0, -198), look_at=(0, 0, -210))
L.enemy("rusher", (-12, 0, -215), look_at=(0, 0, -210))
L.enemy("rusher", (-6, 0, -205), look_at=(0, 0, -210))
L.enemy("heavy", (-12, 0, -226.5), look_at=(0, 0, -210))

# R9 — шахта выхода: подъём к люку
L.room("R9Exit", -16, -8, -248, -228, 0, 8.5, "concrete_dark", "concrete", "concrete",
       openings={"S": [(-16.5, -7.5, 0, 4)]})
L.ramp_z("Geometry/R9Exit", "Ramp", -16, -8, -229, 0, -241, 4, "metal")
L.box_ext("Geometry/R9Exit", "Landing", -16, -8, 0, 4, -248, -241, "concrete")
L.box("Props", "Ladder", (-12, 6.25, -247.85), (1.2, 4.5, 0.1), "metal", collide=False)
L.lamp((-12, 8.4, -236), 1.2, 10)
L.enemy("gunner", (-9, 4, -246), look_at=(-12, 0, -228))
L.exit((-12, 5.5, -245), (6, 3, 4), (-12, 6.8, -247.8), "ВЫХОД")

L.waypoint((0, 0, -3), (0, 0, -9), (0, 0, -27), (0, 0, -29), (0, 0, -38), (8, 0, -38), (26, 0, -38),
           (30, 0, -38), (32, 0, -40), (32, 0, -46), (32, 0, -65), (32, 0, -67), (32, 0, -87), (32, 0, -89),
           (32, 0, -103), (32, 0, -105), (29.2, 0, -111), (29.2, 0, -117), (32, 0, -123), (32, 0, -125),
           (32, 0, -139), (32, 0, -142), (28, 0, -143), (28.6, 0, -156), (28.6, 0, -175), (28, 0, -177),
           (28, 0, -195), (28, 0, -197), (24, 0, -205), (19, 0, -210), (17, 0, -210), (1, 0, -210),
           (-1, 0, -210), (-11, 0, -214), (-12, 0, -227), (-12, 0, -230), (-12, 4, -241.5), (-12, 4, -245))

env = [
    ("Environment", "Env_1", {
        "background_mode": "1", "background_color": "Color(0.01, 0.012, 0.015, 1)",
        "ambient_light_source": "2", "ambient_light_color": "Color(0.36, 0.39, 0.47, 1)",
        "ambient_light_energy": "0.52", "tonemap_mode": "2",
        "fog_enabled": "true", "fog_light_color": "Color(0.03, 0.035, 0.045, 1)", "fog_density": "0.022",
    }),
]
L.node("WorldEnvironment", "WorldEnvironment", ".", environment='SubResource("Env_1")')
# Взрывоопасные бочки и баллоны (места подобраны у стен рядом с постами врагов).
L.explosives([(-6.5, 0, -42), (8.5, 0, -36), (27.84, 0, -41.04), (26.43, 0, -168.15), (26.79, 0, -156.59), (31.01, -1, -174.4), (-19.56, 0, -225.06), (-10, 0, -196.5), (-8.43, 4, -244.61)])

L.write("scenes/levels/level_1_underground.tscn", env, ["pistol"])
