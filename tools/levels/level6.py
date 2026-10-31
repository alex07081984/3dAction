"""Уровень 6 «Порт» (эпизод 2): ночной контейнерный терминал, склад, причал и сухогруз."""
from levelkit import Level, xform, rot_x, rot_y, f, yaw_to
import math
import random

random.seed(6)
L = Level("Level6Port", {
    "level_index": "5",
    "title": '"Порт"',
    "objective": '"Прорвитесь на сухогруз"',
})
for g in ("Geometry", "Lights", "Props", "Enemies", "Pickups"):
    L.group(g)

WARM = "Color(1, 0.78, 0.5, 1)"
CONTAINERS = ["car_red", "car_blue", "awning_green", "rust", "car_white"]


def mul(a, b):
    return [[sum(a[i][k] * b[k][j] for k in range(3)) for j in range(3)] for i in range(3)]


def container(x, z, y=0.0, along_z=True, mat=None):
    size = (2.5, 2.6, 6.0) if along_z else (6.0, 2.6, 2.5)
    L.box("Props", "Container", (x, y + 1.3, z), size, mat or random.choice(CONTAINERS))


def lamp_post(x, z, y=0.0, height=6.0):
    L.cylinder("Props", "Post", (x, y + height / 2, z), 0.1, height, "black_metal")
    L.box("Props", "PostLamp", (x, y + height + 0.1, z), (0.6, 0.25, 0.4), "lamp", collide=False)
    L.node("Light", "OmniLight3D", "Lights", transform=xform((x, y + height - 0.3, z)), light_color=WARM,
           light_energy="1.8", omni_range="14")


# A — контейнерный двор (улица, забор по краям)
L.room("PYard", -30, 30, -80, 0, 0, 3, "asphalt", "metal", None, openings={"N": [(-3, 3)]})
for x in (-3.3, 3.3):
    L.box_ext("Props", "LaneLine", x - 0.1, x + 0.1, 0, 0.02, -78, -2, "hazard", collide=False, shadow=False)
for z, stacked in ((-10, False), (-20, True), (-34, False), (-46, True), (-60, False), (-70, True)):
    container(-10, z)
    if stacked:
        container(-10, z, 2.6)
for z, stacked in ((-12, True), (-24, False), (-36, True), (-48, False), (-62, True), (-72, False)):
    container(10, z)
    if stacked:
        container(10, z, 2.6)
for x in (-22, 22):
    for z, stacked in ((-14, False), (-28, True), (-42, False), (-54, True), (-66, False)):
        container(x, z)
        if stacked:
            container(x, z, 2.6)
# Портальный кран над двором.
for x in (-26.5, 26.5):
    L.box("Props", "CraneLeg", (x, 11, -40), (1.2, 22, 1.2), "hazard")
L.box_ext("Props", "CraneBeam", -27.5, 27.5, 21, 22.5, -40.8, -39.2, "hazard", collide=False)
L.box("Props", "CraneCabin", (8, 19.5, -40), (3, 2.5, 3), "car_white", collide=False)
L.box("Props", "CraneHook", (8, 15, -40), (0.6, 0.8, 0.6), "black_metal", collide=False)
L.box("Props", "CraneLight", (0, 22.9, -40), (0.4, 0.3, 0.4), "lamp_red", collide=False)
for z in (-12, -36, -60):
    for x in (-5, 5):
        lamp_post(x, z)
L.box_ext("Props", "WarehouseFacade", -16, 16, 3, 8, -80.6, -80.1, "rust")
L.label("СКЛАД 7", (0, 5.6, -79.4), size=96, color="Color(1, 0.85, 0.4, 1)")
L.pickup("weapon", (2, 0, -9), weapon="rifle")
L.pickup("health", (-27, 0, -6))
L.pickup("ammo", (27, 0, -34))
L.pickup("grenade", (-5.5, 0, -40))
L.enemy("gunner", (-10, 2.6, -34), look_at=(0, 0, -10))
L.enemy("gunner", (10, 2.6, -24), look_at=(0, 0, 0))
L.enemy("gunner", (-22, 5.2, -28), look_at=(0, 0, -10))
L.enemy("gunner", (22, 5.2, -54), look_at=(0, 0, -30))
L.enemy("gunner", (-6, 0, -28), look_at=(0, 0, -6))
L.enemy("rusher", (6, 0, -52), look_at=(0, 0, -30))
L.enemy("gunner", (-6.5, 0, -66), look_at=(0, 0, -40))
L.enemy("heavy", (0, 0, -76), look_at=(0, 0, -40))
L.wave_zone("ZoneYard", (0, 2, -55), (56, 4, 44),
            spawns=[(-27, 0.1, -77), (27, 0.1, -77), (-27, 0.1, -36), (27, 0.1, -36)],
            barriers=[((0, 2.25, -79.85), (6.4, 4.5, 0.3))],
            title="Засада в доках!", waves=2, first=5, extra=2, rusher=0.3, heavy=1)

# B — склад
DOOR = 4.5
L.room("PWarehouse", -16, 16, -124, -80, 0, 8, "concrete", "rust", "metal",
       openings={"S": [(-3, 3, DOOR)], "N": [(-3, 3, DOOR)]})
for x in (-12, -6, 6, 12):
    for z0, z1 in ((-112, -100), (-96, -86)):
        L.box_ext("Props", "Rack", x - 0.6, x + 0.6, 0, 4.5, z0, z1, "metal")
        for y in (1.6, 3.1):
            L.box_ext("Props", "Boxes", x - 0.55, x + 0.55, y, y + 0.9, z0 + 0.5, z1 - 0.5, "crate", collide=False,
                      shadow=False)
for x, z in ((-9, -90), (9, -108), (-9, -116)):
    L.box("Props", "Crate", (x, 0.6, z), (1.2, 1.2, 1.2), "crate")
for x, z in ((0, -88), (0, -104), (0, -118), (-9, -96), (9, -112)):
    L.lamp((x, 7.9, z), 1.4, 12, color=WARM)
L.pickup("health", (-14.5, 0, -83))
L.pickup("ammo", (14.5, 0, -122))
L.pickup("grenade", (-14.5, 0, -122))
L.enemy("gunner", (-9, 0, -100), look_at=(0, 0, -80))
L.enemy("gunner", (9, 0, -94), look_at=(0, 0, -80))
L.enemy("rusher", (-14, 0, -118), look_at=(0, 0, -80))
L.enemy("gunner", (14, 0, -112), look_at=(0, 0, -80))
L.enemy("heavy", (0, 0, -121), look_at=(0, 0, -80))
L.wave_zone("ZoneWarehouse", (0, 2, -102), (30, 4, 40),
            spawns=[(-14, 0.1, -122), (14, 0.1, -122), (-14, 0.1, -82), (14, 0.1, -82)],
            barriers=[((0, 2.25, -80.15), (6.4, 4.5, 0.3)), ((0, 2.25, -123.85), (6.4, 4.5, 0.3))],
            title="Засада на складе!", waves=2, first=5, extra=2, rusher=0.35, heavy=1)

# C — причал над водой
L.room("PPier", -6, 6, -170, -124, 0, 1.1, "plank", "wood", None,
       openings={"S": [(-3, 3)], "N": [(-1.6, 1.6)]})
for x in (-6.6, 6.6):
    L.invisible_wall("Geometry", "Guard", (x, 2.5, -147), (0.6, 5, 46))
for z in range(-164, -127, 8):
    for x in (-5.2, 5.2):
        L.cylinder("Props", "Bollard", (x, 0.3, z), 0.25, 0.6, "black_metal")
for z in (-134, -158):
    lamp_post(5.4, z, height=5)
L.box("Props", "Tugboat", (12, -0.3, -150), (5, 2.2, 12), "car_red", collide=False)
L.box("Props", "TugCabin", (12, 1.6, -152), (3, 1.8, 4), "white_paint", collide=False)
L.enemy("gunner", (4, 0, -150), look_at=(0, 0, -124))
L.enemy("gunner", (-4, 0, -162), look_at=(0, 0, -124))
L.enemy("rusher", (-2, 0, -140), look_at=(0, 0, -124))

# D — сухогруз (палуба на высоте 3 м), трап с причала
DECK = 3
L.room("PShip", -9, 9, -232, -176, DECK, 1.2, "plank", "black_metal", None, openings={"S": [(-1.6, 1.6)]})
L.ramp_z("Geometry/PShip", "Gangway", -1.5, 1.5, -169.5, 0, -176, DECK, "metal")
for x in (-1.9, 1.9):
    L.invisible_wall("Geometry", "Guard", (x, 2.5, -173), (0.3, 5, 7))
for x in (-9.7, 9.7):
    L.invisible_wall("Geometry", "Guard", (x, DECK + 2.5, -204), (0.6, 5, 57))
L.invisible_wall("Geometry", "Guard", (0, DECK + 2.5, -232.7), (20, 5, 0.6))
for x0, x1 in ((-9.7, -1.6), (1.6, 9.7)):
    L.invisible_wall("Geometry", "Guard", ((x0 + x1) / 2, DECK + 2.5, -175.6), (x1 - x0, 5, 0.6))
L.box_ext("Props", "Hull", -10, 10, -2.0, DECK - 0.5, -236, -176, "black_metal")
L.box_ext("Props", "HullStripe", -10.05, 10.05, 1.6, 2.1, -236, -176, "car_red", collide=False, shadow=False)
L.box_ext("Props", "Bridge", -6, 6, DECK, DECK + 6, -232, -220, "white_paint")
L.box_ext("Props", "BridgeWindows", -5.5, 5.5, DECK + 4, DECK + 5, -220.1, -219.95, "lamp", collide=False, shadow=False)
for x, z, stacked in ((-5.5, -186, True), (5.5, -194, False), (-5.5, -204, False), (5.5, -210, True)):
    container(x, z, DECK)
    if stacked:
        container(x, z, DECK + 2.6)
L.cylinder("Props", "Mast", (7.6, DECK + 4.5, -200), 0.3, 9, "hazard")
for x, z in ((-7.8, -188), (7.8, -216)):
    lamp_post(x, z, DECK, 4.5)
L.lamp((0, DECK + 6.2, -219), 1.5, 12, color=WARM)
L.pickup("health", (-8, DECK, -178))
L.pickup("ammo", (8, DECK, -200))
L.pickup("grenade", (-8, DECK, -214))
L.enemy("gunner", (-5.5, DECK + 5.2, -186), look_at=(0, 0, -170))
L.enemy("gunner", (5.5, DECK + 5.2, -210), look_at=(0, DECK, -180))
L.enemy("gunner", (3, DECK + 6, -224), look_at=(0, DECK, -180))
L.enemy("heavy", (0, DECK, -214), look_at=(0, DECK, -180))
L.enemy("rusher", (-3.5, DECK, -198), look_at=(0, DECK, -180))
L.wave_zone("ZoneShip", (0, DECK + 2, -204), (18, 4, 54),
            spawns=[(-8, DECK + 0.1, -230), (8, DECK + 0.1, -230), (-8, DECK + 0.1, -179), (8, DECK + 0.1, -179)],
            barriers=[((0, DECK + 1.5, -176.15), (3.4, 3, 0.3))],
            title="Абордаж!", waves=2, first=6, extra=2, rusher=0.25, heavy=2)
L.exit((0, DECK + 1.5, -217), (5, 3, 3), (0, DECK + 4.2, -219.6), "ШЛЮПКА", required_zone="ZoneShip")

# Вокруг: вода, огни города на том берегу, луна.
L.section = "Outdoor"
L.box_ext("Props", "Water", -300, 300, -2.5, -1.0, -500, 80, "water", collide=False, shadow=False)
for i in range(14):
    x = -160 + i * 24 + random.uniform(-6, 6)
    w, d = random.uniform(12, 22), random.uniform(12, 22)
    L.box_ext("Props", "Skyline", x - w / 2, x + w / 2, -2, random.uniform(15, 70), -420 - d, -420, "skyline",
              collide=False, shadow=False)
L.cylinder("Props", "Moon", (110, 110, -380), 8, 1, "lamp_cold", collide=False, rows=rot_x(math.pi / 2), sides=24)

L.player((0, 0, -3), 0)
L.waypoint((0, 0, -3), (0, 0, -78), (0, 0, -82), (0, 0, -122), (0, 0, -126), (0, 0, -169.5), (0, DECK, -176.8),
           (0, DECK, -200), (0, DECK, -216))

env = [
    ("ProceduralSkyMaterial", "SkyMat_6", {
        "sky_top_color": "Color(0.015, 0.02, 0.045, 1)", "sky_horizon_color": "Color(0.12, 0.12, 0.17, 1)",
        "ground_bottom_color": "Color(0.01, 0.01, 0.02, 1)", "ground_horizon_color": "Color(0.1, 0.1, 0.14, 1)",
    }),
    ("Sky", "Sky_6", {"sky_material": 'SubResource("SkyMat_6")'}),
    ("Environment", "Env_6", {
        "background_mode": "2", "sky": 'SubResource("Sky_6")',
        "ambient_light_source": "2", "ambient_light_color": "Color(0.32, 0.36, 0.48, 1)",
        "ambient_light_energy": "0.58", "tonemap_mode": "2",
        "fog_enabled": "true", "fog_light_color": "Color(0.06, 0.07, 0.1, 1)", "fog_density": "0.012",
        "fog_sky_affect": "0.3",
    }),
]
L.node("WorldEnvironment", "WorldEnvironment", ".", environment='SubResource("Env_6")')
L.node("Moonlight", "DirectionalLight3D", ".", transform=xform((0, 40, 0), mul(rot_y(150), rot_x(math.radians(-40)))),
       light_color="Color(0.6, 0.7, 1, 1)", light_energy="0.35", shadow_enabled="true",
       directional_shadow_max_distance="50.0", directional_shadow_mode="1")
L.explosives([(-6.2, 0, -12), (6.2, 0, -24), (-17, 0, -31), (-6.2, 0, -50), (6.2, 0, -64), (17, 0, -58),
              (-8.5, 0, -88), (8.5, 0, -118), (-4.4, 0, -136), (-7.6, DECK, -185), (7, DECK, -203), (-7, DECK, -215)],
             pattern="BBC")
L.write("scenes/levels/level_6_port.tscn", env, ["pistol", "shotgun", "deagle"])
