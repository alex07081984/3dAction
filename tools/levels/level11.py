"""Уровень 11 «Золотой прииск» (эпизод 3, Аляска): заснеженная долина старателей
с промывочными лотками и бараками, штольня с вагонетками и рудная пещера с лифтом наверх."""
from levelkit import Level, xform, rot_x, rot_y, f, yaw_to
import math
import random

random.seed(11)
L = Level("Level11GoldMine", {
    "level_index": "10",
    "title": '"Золотой прииск"',
    "objective": '"Пробейтесь через прииск к лифту наверх"',
})
for g in ("Geometry", "Lights", "Props", "Enemies", "Pickups"):
    L.group(g)

WARM = "Color(1, 0.75, 0.45, 1)"


def mul(a, b):
    return [[sum(a[i][k] * b[k][j] for k in range(3)) for j in range(3)] for i in range(3)]


def cabin(x, z, w=6, d=5, h=3.5):
    L.box("Props", "Cabin", (x, h / 2, z), (w, h, d), "plank")
    L.box("Props", "CabinRoof", (x, h + 0.2, z), (w + 0.6, 0.4, d + 0.6), "snow")
    L.box_ext("Props", "CabinWindow", x - 0.8, x + 0.8, 1.2, 2.2, z + d / 2, z + d / 2 + 0.05, "lamp", collide=False,
              shadow=False)


def lantern_post(x, z, y=0.0):
    L.cylinder("Props", "Post", (x, y + 1.8, z), 0.1, 3.6, "wood")
    L.box("Props", "Lantern", (x, y + 3.7, z), (0.35, 0.45, 0.35), "lamp", collide=False)
    L.node("Light", "OmniLight3D", "Lights", transform=xform((x, y + 3.4, z)), light_color=WARM, light_energy="1.6",
           omni_range="12")


def pine(x, z, h=None):
    h = h or random.uniform(6, 11)
    L.cylinder("Props", "PineTrunk", (x, h * 0.25, z), 0.3, h * 0.5, "tree_trunk", collide=False, sides=6)
    for i, s in enumerate((3.2, 2.4, 1.5)):
        L.box("Props", "PineCrown", (x, h * (0.35 + 0.22 * i), z), (s, h * 0.24, s), "tree_leaves", collide=False)
        L.box("Props", "PineSnow", (x, h * (0.35 + 0.22 * i) + h * 0.12, z), (s * 0.8, 0.2, s * 0.8), "snow",
              collide=False, shadow=False)


# Долина старателей
L.room("MValley", -30, 30, -90, 0, 0, 12, "snow", "rock", None, openings={"N": [(-3, 3, 4)]})
for x in (-4, 4):
    L.box("Props", "ArchPost", (x, 2.2, -6), (0.4, 4.4, 0.4), "wood")
L.box_ext("Props", "ArchBeam", -4.6, 4.6, 4.2, 4.7, -6.2, -5.8, "wood", collide=False)
L.label("ПРИИСК «ЗОЛОТАЯ ЖИЛА»", (0, 5.3, -5.7), size=64, color="Color(1, 0.85, 0.35, 1)")
for x, z in ((-20, -20), (20, -30), (-22, -62), (22, -70)):
    cabin(x, z)
L.box_ext("Props", "Sluice", -12, -8, 0.8, 1.3, -62, -30, "wood")
for z in range(-60, -29, 6):
    for x in (-11.6, -8.4):
        L.box("Props", "Stilt", (x, 0.4, z), (0.25, 0.8, 0.25), "wood")
L.box_ext("Props", "Creek", 8, 11, 0, 0.03, -88, -2, "glass", collide=False, shadow=False)
for x0, x1 in ((-1.4, -1.3), (1.3, 1.4)):
    L.box_ext("Props", "Rail", x0, x1, 0, 0.04, -90, -70, "rail", collide=False, shadow=False)
for z in (-76, -84):
    L.box("Props", "OreCart", (4.2, 0.6, z), (1.2, 1.0, 1.8), "rust")
for x, z in ((-6, -14), (6, -44), (-6, -74), (6, -86)):
    lantern_post(x, z)
L.pickup("health", (-27, 0, -4))
L.pickup("ammo", (27, 0, -46))
L.pickup("grenade", (-6, 0, -50))
L.enemy("bandit", (-17, 0, -24), look_at=(0, 0, 0))
L.enemy("bandit", (17, 0, -36), look_at=(0, 0, 0))
L.enemy("bandit", (-6.5, 0, -64), look_at=(0, 0, -20))
L.enemy("trapper", (5, 0, -56), look_at=(0, 0, -20))
L.enemy("trapper", (-15, 0, -80), look_at=(0, 0, -40))
L.enemy("bandit", (14, 0, -82), look_at=(0, 0, -40))
L.enemy("marksman", (22, 3.9, -70), look_at=(0, 0, -20))
L.enemy("marksman", (-20, 3.9, -20), look_at=(0, 0, 0))
L.wave_zone("ZoneValley", (0, 2, -60), (56, 4, 56),
            spawns=[(-27, 0.1, -87), (27, 0.1, -87), (-27, 0.1, -36), (27, 0.1, -40)],
            barriers=[((0, 2, -89.85), (6.4, 4, 0.3))],
            title="Захватчики участков!", waves=2, first=5, extra=2, rusher=0.35, heavy=1,
            gunner_kind="bandit", rusher_kind="trapper")

# Штольня
L.room("MAdit", -3, 3, -130, -90, 0, 4, "gravel", "rock", "rock",
       openings={"S": [(-3.5, 3.5, 4)], "N": [(-3.5, 3.5, 4)]})
for z in range(-94, -129, -6):
    for x in (-2.75, 2.75):
        L.box("Props", "Timber", (x, 2, z), (0.3, 4, 0.3), "wood")
    L.box_ext("Props", "TimberBeam", -3, 3, 3.6, 3.95, z - 0.15, z + 0.15, "wood", collide=False)
for x0, x1 in ((-1.4, -1.3), (1.3, 1.4)):
    L.box_ext("Props", "Rail", x0, x1, 0, 0.04, -130, -90, "rail", collide=False, shadow=False)
L.box("Props", "OreCart", (1.6, 0.6, -104), (1.2, 1.0, 1.8), "rust")
for z in (-97, -113, -125):
    L.lamp((0, 3.9, z), 1.3, 9, color=WARM, size=(0.3, 0.1, 0.3))
L.enemy("bandit", (1.6, 0, -107), look_at=(0, 0, -90))
L.enemy("trapper", (-1.5, 0, -122), look_at=(0, 0, -90))

# Рудная пещера с лифтом наверх
L.room("MCavern", -22, 22, -185, -130, 0, 12, "gravel", "rock", "rock", openings={"S": [(-3, 3, 4)]})
L.box_ext("Props", "Scaffold", -22, -14, 4.6, 5, -178, -142, "wood")
for z in range(-176, -141, 8):
    L.box("Props", "ScaffoldLeg", (-14.4, 2.3, z), (0.3, 4.6, 0.3), "wood")
L.box_ext("Props", "ScaffoldRail", -14.5, -14.3, 5, 6, -178, -142, "wood")
for x, y, z, w, h in ((-21.9, 6, -150, 0.2, 2.4), (21.9, 4, -140, 0.2, 1.6), (21.9, 7, -170, 0.2, 3),
                      (-21.9, 3, -172, 0.2, 1.4), (10, 11.9, -160, 4, 0.2)):
    L.box("Props", "GoldVein", (x, y, z), (w, h, 3.0) if w < 1 else (w, h, 2.0), "gold", collide=False, shadow=False)
for x, z in ((12, -146), (-6, -170), (14, -172)):
    L.box("Props", "OrePile", (x, 0.6, z), (3, 1.2, 3), "gravel")
L.box_ext("Props", "Conveyor", 6, 8, 1.0, 1.4, -168, -140, "black_metal")
L.box_ext("Props", "LiftCage", -3, 3, 0, 0.2, -185, -180, "metal", collide=False)
for x in (-3, 3):
    L.box_ext("Props", "LiftFrame", x - 0.15, x + 0.15, 0, 12, -185, -184.7, "metal")
L.label("ЛИФТ НАВЕРХ", (0, 5.0, -183.6), size=64, color="Color(0.4, 1, 0.5, 1)")
for x, z in ((-12, -138), (12, -138), (-10, -165), (10, -178)):
    L.lamp((x, 11.9, z), 1.5, 14, color=WARM, size=(0.4, 0.1, 0.4))
L.pickup("health", (20, 0, -133))
L.pickup("ammo", (-20, 0, -133))
L.pickup("health", (20, 0, -182))
L.enemy("bandit", (-8, 0, -150), look_at=(0, 0, -130))
L.enemy("bandit", (12, 0, -149), look_at=(0, 0, -130))
L.enemy("trapper", (-4, 0, -172), look_at=(0, 0, -130))
L.enemy("bandit", (-18, 5, -150), look_at=(0, 0, -130))
L.enemy("marksman", (-18, 5, -170), look_at=(0, 0, -130))
L.enemy("heavy", (0, 0, -178), look_at=(0, 0, -130))
L.wave_zone("ZoneCavern", (0, 2, -158), (40, 4, 50),
            spawns=[(-19, 0.1, -133), (19, 0.1, -133), (-19, 0.1, -182), (19, 0.1, -182)],
            barriers=[((0, 2, -130.15), (6.4, 4, 0.3))],
            title="Обвал! Засада в пещере!", waves=2, first=5, extra=2, rusher=0.35, heavy=1,
            gunner_kind="bandit", rusher_kind="trapper")
L.exit((0, 1.5, -181.5), (5, 3, 4), (0, 4.4, -183.5), "ЛИФТ", required_zone="ZoneCavern")

# Горы и лес вокруг
L.section = "Outdoor"
for i in range(30):
    side = random.choice((-1, 1))
    pine(side * random.uniform(34, 70), random.uniform(-100, 20))
for x, z, w, h in ((-120, -60, 120, 60), (120, -80, 120, 70), (0, -220, 260, 90), (0, 120, 260, 40)):
    L.box("Props", "Mountain", (x, h / 2 - 8, z), (w, h, 100), "snow", collide=False, shadow=False)
L.cylinder("Props", "Moon", (100, 110, -360), 8, 1, "lamp_cold", collide=False, rows=rot_x(math.pi / 2), sides=24)
L.node("Snow", "Node3D", ".", script=L.ext_res("Script", "res://scripts/town/rain.gd"), snow="true")

L.player((0, 0, -3), 0)
L.waypoint((0, 0, -3), (0, 0, -88), (0, 0, -92), (0, 0, -128), (0, 0, -132), (0, 0, -178))

env = [
    ("ShaderMaterial", "SkyMat_11", {"shader": L.ext_res("Shader", "res://materials/aurora_sky.gdshader")}),
    ("Sky", "Sky_11", {"sky_material": 'SubResource("SkyMat_11")'}),
    ("Environment", "Env_11", {
        "background_mode": "2", "sky": 'SubResource("Sky_11")',
        "ambient_light_source": "2", "ambient_light_color": "Color(0.4, 0.45, 0.56, 1)",
        "ambient_light_energy": "0.62", "tonemap_mode": "2",
        "fog_enabled": "true", "fog_light_color": "Color(0.26, 0.28, 0.33, 1)", "fog_density": "0.014",
        "fog_sky_affect": "0.4",
    }),
]
L.node("WorldEnvironment", "WorldEnvironment", ".", environment='SubResource("Env_11")')
L.node("Moonlight", "DirectionalLight3D", ".", transform=xform((0, 40, 0), mul(rot_y(150), rot_x(math.radians(-40)))),
       light_color="Color(0.65, 0.75, 1, 1)", light_energy="0.4", shadow_enabled="true",
       directional_shadow_max_distance="50.0", directional_shadow_mode="1")
L.explosives([(-14.5, 0, -24), (14.5, 0, -30), (-13.5, 0, -40), (13, 0, -66), (-4.2, 0, -100), (16, 0, -146),
              (-9, 0, -170), (17.5, 0, -172), (-16, 0, -138)], pattern="TTB")
L.write("scenes/levels/level_11_gold_mine.tscn", env, ["pistol", "shotgun", "magnum", "rifle"])
