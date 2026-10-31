"""Уровень 9 «Мост Золотые Ворота» (эпизод 2): пробка из брошенных машин на полотне моста,
потом подъём по платформам вдоль несущего троса к вершине опоры, где ждёт босс Маньяк."""
from levelkit import Level, xform, rot_x, rot_y, f, yaw_to
import math
import random

random.seed(9)
L = Level("Level9Bridge", {
    "level_index": "8",
    "title": '"Мост Золотые Ворота"',
    "objective": '"Поднимитесь на опору моста к Маньяку"',
})
for g in ("Geometry", "Lights", "Props", "Enemies", "Pickups"):
    L.group(g)

WARM = "Color(1, 0.8, 0.55, 1)"
CARS = ["car_red", "car_blue", "car_white", "car_black"]
RED = "bridge_red"


def mul(a, b):
    return [[sum(a[i][k] * b[k][j] for k in range(3)) for j in range(3)] for i in range(3)]


def car(x, z, mat=None):
    L.box("Props", "Car", (x, 0.6, z), (2.0, 1.0, 4.4), mat or random.choice(CARS))
    L.box("Props", "CarCabin", (x, 1.42, z + 0.2), (1.8, 0.65, 2.2), "dark_glass")


def guards(x0, x1, z0, z1, y, gap=None):
    """Невидимые стены вокруг площадки на высоте y (с проёмами для пандусов по оси x = 0)."""
    for x in (x0 - 0.6, x1 + 0.6):
        L.invisible_wall("Geometry", "Guard", (x, y + 2.5, (z0 + z1) / 2), (0.6, 5, z1 - z0 + 1.2))
    for z, open_side in ((z0 - 0.6, gap in ("N", "NS")), (z1 + 0.6, gap in ("S", "NS"))):
        pieces = [(x0 - 0.6, -3.2), (3.2, x1 + 0.6)] if open_side else [(x0 - 0.6, x1 + 0.6)]
        for a, b in pieces:
            L.invisible_wall("Geometry", "Guard", ((a + b) / 2, y + 2.5, z), (b - a, 5, 0.6))


def ramp(section, z_start, y_start, z_end, y_end):
    L.ramp_z(f"Geometry/{section}", "Ramp", -3, 3, z_start, y_start, z_end, y_end, "metal")
    for x in (-3.4, 3.4):
        L.invisible_wall("Geometry", "Guard", (x, (y_start + y_end) / 2 + 1.5, (z_start + z_end) / 2),
                         (0.3, y_end - y_start + 5, abs(z_end - z_start)))


def lamp_post(x, z, y=0.0):
    L.cylinder("Props", "Post", (x, y + 2.5, z), 0.1, 5, RED)
    L.box("Props", "PostLamp", (x, y + 5.1, z), (0.5, 0.25, 0.4), "lamp", collide=False)
    L.node("Light", "OmniLight3D", "Lights", transform=xform((x, y + 4.8, z)), light_color=WARM,
           light_energy="1.7", omni_range="13")


# Полотно моста: три участка, чтобы на каждый падало немного источников света.
for name, z0, z1, sides in (("GDeck1", -100, 0, {"N": False}), ("GDeck2", -200, -100, {"S": False, "N": False}),
                            ("GDeck3", -290, -200, {"S": False})):
    L.room(name, -12, 12, z0, z1, 0, 1.3, "asphalt", RED, None, sides=sides)
for x in (-12.6, 12.6):
    L.invisible_wall("Geometry", "Guard", (x, 3, -145), (0.6, 6, 290))
L.invisible_wall("Geometry", "Guard", (0, 3, 0.6), (26, 6, 0.6))
for x in (-9, -4.6, 4.6, 9):
    L.box("Props", "TollBooth", (x, 1.5, -8), (1.8, 3, 3), "white_paint")
L.box_ext("Props", "TollRoof", -11, 11, 3.2, 3.6, -10, -6, RED, collide=False)
L.label("МОСТ ЗОЛОТЫЕ ВОРОТА", (0, 4.6, -10.1), size=72, color="Color(1, 0.85, 0.4, 1)")
for x, z in ((6.5, -24), (-9.5, -31), (9.5, -46), (-6.5, -52), (6.5, -70), (-9.5, -84), (9.5, -96), (6.5, -112),
             (-6.5, -118), (9.5, -134), (-9.5, -142), (6.5, -150), (-6.5, -160)):
    car(x, z)
L.box("Props", "SchoolBus", (-6, 1.6, -95), (2.6, 3.2, 11), "plaster_yellow")
L.box_ext("Props", "BusWindows", -7.35, -4.65, 2.2, 3.0, -100, -90, "dark_glass", collide=False, shadow=False)
L.box_ext("Props", "Blockade", -12, -3.4, 0, 1.2, -168, -167, "barrier")
L.box_ext("Props", "Blockade", 3.4, 12, 0, 1.2, -168, -167, "barrier")
for x, z in ((-11.3, -20), (11.3, -60), (-11.3, -100), (11.3, -140), (-11.3, -180)):
    lamp_post(x, z)

# Несущие тросы, подвески и опора.
SLOPE = math.atan2(36, 258)
for x in (-12.8, 12.8):
    L.box("Props", "MainCable", (x, 22, -149), (0.8, 0.8, 262), RED, collide=False, rows=rot_x(SLOPE), shadow=False)
    for z in range(-30, -271, -12):
        top = 4 + (-20 - z) / 258 * 36
        L.box_ext("Props", "Suspender", x - 0.06, x + 0.06, 1.3, top, z - 0.06, z + 0.06, RED, collide=False,
                  shadow=False)
for x in (-16, 16):
    L.box_ext("Props", "TowerLeg", x - 1.75, x + 1.75, -60, 46, -284, -270, RED)
for y0, y1 in ((20, 22), (36, 39), (44, 46)):
    L.box_ext("Props", "TowerBeam", -14.25, 14.25, y0, y1, -282, -272, RED)
L.box("Props", "AviationLight", (16, 46.4, -277), (0.6, 0.6, 0.6), "lamp_red", collide=False)

# Подъём: пандусы и площадки вдоль троса — всё выше к вершине опоры.
PLATFORMS = [("GP1", -196, -186, 8), ("GP2", -222, -212, 16), ("GP3", -248, -238, 24)]
L.room("GP1", -12, 12, -196, -186, 8, 1.1, "metal", RED, None, openings={"S": [(-3, 3)], "N": [(-3, 3)]})
ramp("GP1", -170, 0, -186, 8)
L.room("GP2", -12, 12, -222, -212, 16, 1.1, "metal", RED, None, openings={"S": [(-3, 3)], "N": [(-3, 3)]})
ramp("GP2", -196, 8, -212, 16)
L.room("GP3", -12, 12, -248, -238, 24, 1.1, "metal", RED, None, openings={"S": [(-3, 3)], "N": [(-3, 3)]})
ramp("GP3", -222, 16, -238, 24)
TOP = 32
L.room("GTop", -14, 14, -290, -264, TOP, 1.1, "metal", RED, None, openings={"S": [(-3, 3)]})
ramp("GTop", -248, 24, -264, TOP)
for name, z0, z1, y in PLATFORMS:
    guards(-12, 12, z0, z1, y, "NS")
    lamp_post(-11.3, (z0 + z1) / 2, y)
guards(-14, 14, -290, -264, TOP, "S")
for x, z in ((-6, -276), (6, -280), (0, -287)):
    L.box("Props", "CableAnchor", (x, TOP + 0.75, z), (1.6, 1.5, 1.6), RED)
L.lamp((0, TOP + 6, -277), 1.6, 16, color=WARM, mat="lamp_red", size=(0.6, 0.3, 0.6))

# Враги
for x, z in ((6.5, -27), (-9.5, -34), (-6.5, -55), (9.5, -73)):
    L.enemy("gunner", (x, 0, z), look_at=(0, 0, 0))
L.enemy("rusher", (2, 0, -60), look_at=(0, 0, 0))
L.enemy("gunner", (9.5, 0, -137), look_at=(0, 0, -100))
L.enemy("rusher", (-2, 0, -150), look_at=(0, 0, -100))
L.enemy("heavy", (0, 0, -164), look_at=(0, 0, -100))
L.enemy("gunner", (-9, 8, -191), look_at=(0, 0, -170))
L.enemy("gunner", (9, 8, -191), look_at=(0, 0, -170))
L.enemy("gunner", (9, 16, -217), look_at=(0, 8, -196))
L.enemy("rusher", (-8, 16, -219), look_at=(0, 8, -196))
L.enemy("gunner", (-9, 24, -243), look_at=(0, 16, -222))
L.enemy("gunner", (9, 24, -243), look_at=(0, 16, -222))
L.enemy("gunner", (-11, TOP, -268), look_at=(0, 24, -248))
L.enemy("gunner", (11, TOP, -268), look_at=(0, 24, -248))
L.boss("maniac", "Maniac", (0, TOP, -285), (0, TOP, -264), henchman_points='NodePath("../../BossSpawns")')
L.markers("BossSpawns", [(f"Spawn{i}", p, 0) for i, p in enumerate((
    (-12, TOP, -266), (12, TOP, -266), (-12, TOP, -288), (12, TOP, -288), (0, 24, -246)))])
L.wave_zone("ZoneDeck", (0, 2, -100), (24, 4, 50),
            spawns=[(-10.5, 0.1, -77), (10.5, 0.1, -77), (-10.5, 0.1, -123), (10.5, 0.1, -123)],
            barriers=[((0, 2, -74), (24.6, 4, 0.3)), ((0, 2, -126), (24.6, 4, 0.3))],
            title="Пробка на мосту!", waves=2, first=5, extra=2, rusher=0.3, heavy=1)
L.wave_zone("ZoneTower", (0, 18, -217), (24, 4, 10),
            spawns=[(-11, 16.1, -213), (11, 16.1, -213), (-11, 16.1, -221), (11, 16.1, -221)],
            barriers=[((0, 17.5, -211.85), (6.4, 3, 0.3)), ((0, 17.5, -222.15), (6.4, 3, 0.3))],
            title="Засада на опоре!", waves=2, first=4, extra=2, rusher=0.4, heavy=0)
for kind, pos in (("health", (-10.5, 0, -40)), ("ammo", (10.5, 0, -88)), ("grenade", (-10.5, 0, -128)),
                  ("health", (10.5, 0, -164)), ("ammo", (11, 8, -194)), ("health", (-11, 16, -214)),
                  ("grenade", (11, 24, -246)), ("health", (-13, TOP, -289)), ("health", (13, TOP, -289))):
    L.pickup(kind, pos)

# Залив, туман, город на берегу, луна.
L.section = "Outdoor"
L.box_ext("Props", "Water", -500, 500, -64, -62, -700, 300, "water", collide=False, shadow=False)
for i in range(16):
    x = -260 + i * 34 + random.uniform(-8, 8)
    w, d = random.uniform(14, 26), random.uniform(14, 26)
    L.box_ext("Props", "Skyline", x - w / 2, x + w / 2, -64, random.uniform(-30, 30), 120, 120 + d, "skyline",
              collide=False, shadow=False)
L.cylinder("Props", "Moon", (-120, 120, -420), 9, 1, "lamp_cold", collide=False, rows=rot_x(math.pi / 2), sides=24)

L.player((0, 0, -3), 0)
L.waypoint((0, 0, -3), (0, 0, -169), (0, 8, -186.5), (0, 8, -195.5), (0, 16, -212.5), (0, 16, -221.5),
           (0, 24, -238.5), (0, 24, -247.5), (0, TOP, -264.5), (0, TOP, -272))

env = [
    ("ProceduralSkyMaterial", "SkyMat_9", {
        "sky_top_color": "Color(0.02, 0.025, 0.05, 1)", "sky_horizon_color": "Color(0.16, 0.17, 0.21, 1)",
        "ground_bottom_color": "Color(0.02, 0.02, 0.03, 1)", "ground_horizon_color": "Color(0.14, 0.15, 0.19, 1)",
    }),
    ("Sky", "Sky_9", {"sky_material": 'SubResource("SkyMat_9")'}),
    ("Environment", "Env_9", {
        "background_mode": "2", "sky": 'SubResource("Sky_9")',
        "ambient_light_source": "2", "ambient_light_color": "Color(0.34, 0.37, 0.48, 1)",
        "ambient_light_energy": "0.62", "tonemap_mode": "2",
        "fog_enabled": "true", "fog_light_color": "Color(0.13, 0.14, 0.18, 1)", "fog_density": "0.018",
        "fog_sky_affect": "0.6",
    }),
]
L.node("WorldEnvironment", "WorldEnvironment", ".", environment='SubResource("Env_9")')
L.node("Moonlight", "DirectionalLight3D", ".", transform=xform((0, 60, 0), mul(rot_y(160), rot_x(math.radians(-38)))),
       light_color="Color(0.6, 0.7, 1, 1)", light_energy="0.35", shadow_enabled="true",
       directional_shadow_max_distance="50.0", directional_shadow_mode="1")
L.explosives([(4.6, 0, -35), (-4.6, 0, -85), (4.6, 0, -130), (-4.6, 0, -150), (-10, 8, -193), (10, 24, -240),
              (-12.5, TOP, -276), (12.5, TOP, -280)], pattern="BBC")
L.write("scenes/levels/level_9_bridge.tscn", env, ["pistol", "shotgun", "magnum", "rifle"])
