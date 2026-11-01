"""Уровень «Радарная станция» (эпизод 3, Аляска): военная база в горах, захваченная бандой.
КПП у подъёма, двор с казармами и грузовиками, площадка с куполами радаров и антенной,
автопарк с ангаром — там из ангара выезжает босс Танк. Победа над ним завершает уровень."""
from levelkit import Level, xform, rot_x, rot_y, rot_z, f, yaw_to
import math
import random

random.seed(14)
L = Level("LevelRadar", {
    "level_index": "13",
    "title": '"Радарная станция"',
    "objective": '"Прорвитесь на базу и уничтожьте танк банды"',
})
for g in ("Geometry", "Lights", "Props", "Enemies", "Pickups"):
    L.group(g)

WARM = "Color(1, 0.85, 0.6, 1)"
COLD = "Color(0.8, 0.9, 1, 1)"
SIGN = "Color(1, 0.85, 0.45, 1)"
GATE = [(-6, 6, 8)]


def mul(a, b):
    return [[sum(a[i][k] * b[k][j] for k in range(3)) for j in range(3)] for i in range(3)]


def pine(x, z, h=None):
    h = h or random.uniform(7, 11)
    L.cylinder("Props", "PineTrunk", (x, h * 0.25, z), 0.3, h * 0.5, "tree_trunk", collide=False, sides=6)
    for i, s in enumerate((3.2, 2.4, 1.5)):
        L.box("Props", "PineCrown", (x, h * (0.35 + 0.22 * i), z), (s, h * 0.24, s), "tree_leaves", collide=False)
        L.box("Props", "PineSnow", (x, h * (0.35 + 0.22 * i) + h * 0.12, z), (s * 0.8, 0.2, s * 0.8), "snow",
              collide=False, shadow=False)


def floodlight(x, z, h=8.0, yaw=0.0):
    L.cylinder("Props", "LightPole", (x, h / 2, z), 0.15, h, "metal", sides=8)
    L.box("Props", "Flood", (x, h + 0.2, z), (1.0, 0.5, 0.4), "lamp_cold", collide=False, rows=rot_y(yaw))
    L.node("Light", "OmniLight3D", "Lights", transform=xform((x, h - 0.5, z)), light_color=COLD,
           light_energy="2.2", omni_range="22")


def sandbags(x, z, w=3.0, yaw=0.0):
    L.box("Props", "Sandbags", (x, 0.5, z), (w, 1.0, 0.9), "gravel", rows=rot_y(yaw))


def block(x, z, yaw=0.0):
    L.box("Props", "ConcreteBlock", (x, 0.6, z), (2.4, 1.2, 1.0), "concrete", rows=rot_y(yaw))


def building(x0, x1, z0, z1, h, mat, lit=True):
    L.box_ext("Geometry", "Building", x0, x1, 0, h, z0, z1, mat)
    L.box_ext("Geometry", "RoofSlab", x0 - 0.2, x1 + 0.2, h, h + 0.3, z0 - 0.2, z1 + 0.2, "snow")
    if lit:
        cx = (x0 + x1) / 2
        L.box_ext("Props", "Windows", cx - 3, cx + 3, 1.4, 2.4, z1, z1 + 0.05, "lamp", collide=False, shadow=False)


# --- КПП у подъёма -------------------------------------------------------------------------------
L.room("RGate", -20, 20, -50, 0, 0, 10, "snow", "rock", None, openings={"N": GATE})
L.box_ext("Props", "Road", -4, 4, 0, 0.02, -50, 0, "gravel", collide=False, shadow=False)
L.box_ext("Geometry", "Booth", 5, 8, 0, 3, -14, -11, "concrete")
L.box_ext("Geometry", "BoothRoof", 4.7, 8.3, 3, 3.3, -14.3, -10.7, "snow")
L.box_ext("Props", "BoothWindow", 4.97, 5.0, 1.2, 2.2, -13.5, -11.5, "lamp", collide=False, shadow=False)
L.box("Props", "BarrierArm", (-1.2, 1.0, -13.5), (5.0, 0.15, 0.15), "hazard", collide=False, rows=rot_z(0.5))
L.box("Props", "BarrierPost", (4.2, 0.6, -13.5), (0.3, 1.2, 0.3), "black_metal")
L.label("РАДАРНАЯ СТАНЦИЯ «СЕВЕРНЫЙ ЩИТ»", (6.5, 4.2, -10.6), size=40, color=SIGN)
L.label("ПОСТОРОННИМ ВХОД ЗАПРЕЩЁН", (0, 7.5, -49.4), size=56, color="Color(1, 0.3, 0.25, 1)")
for x, z in ((-16, -6), (16, -4), (-15, -44), (15, -46)):
    pine(x, z)
floodlight(-8, -30)
L.enemy("bandit", (-8, 0, -24), look_at=(0, 0, 0))
L.enemy("bandit", (9, 0, -30), look_at=(0, 0, 0))
L.enemy("marksman", (6.5, 3.3, -12.5), look_at=(0, 0, 0))
L.enemy("trapper", (-5, 0, -42), look_at=(0, 0, 0))
L.pickup("ammo", (-15, 0, -5))
L.pickup("health", (15, 0, -40))

# --- Двор с казармами ------------------------------------------------------------------------------
L.room("RYard", -40, 40, -130, -50, 0, 10, "snow", "rock", None, openings={"S": GATE, "N": GATE})
building(-36, -20, -118, -104, 4.5, "plaster_green")
building(-36, -20, -96, -82, 4.5, "plaster_green")
building(20, 36, -110, -90, 4.5, "plaster_green")
L.label("КАЗАРМА", (-28, 3.6, -81.9), size=56, color=SIGN)
L.box("Props", "Flagpole", (5, 5, -88), (0.15, 10, 0.15), "metal")
L.box("Props", "Flag", (5.9, 9.2, -88), (1.6, 1.0, 0.05), "car_red", collide=False)
for x, z, w, yaw in ((-8, -66, 3, 0), (8, -72, 3, 0), (-12, -100, 3, 90), (12, -116, 3, 90), (-6, -108, 4, 0)):
    sandbags(x, z, w, yaw)
floodlight(-14, -60)
floodlight(14, -122)
L.enemy("bandit", (-12, 0, -70), look_at=(0, 0, -50))
L.enemy("bandit", (14, 0, -80), look_at=(0, 0, -50))
L.enemy("heavy", (0, 0, -118), look_at=(0, 0, -50))
L.enemy("trapper", (-18, 0, -100), look_at=(0, 0, -50))
L.enemy("marksman", (-28, 4.5, -111), look_at=(0, 0, -60))
L.pickup("health", (36, 0, -55))
L.pickup("ammo", (-36, 0, -126))
L.pickup("grenade", (30, 0, -120))
L.wave_zone("ZoneYard", (0, 2, -92), (60, 4, 64),
            spawns=[(-18, 0.1, -111), (-18, 0.1, -89), (18, 0.1, -100), (0, 0.1, -126)],
            barriers=[((0, 2, -130.15), (12.4, 4, 0.3))],
            title="Тревога в казармах!", waves=2, first=5, extra=2, rusher=0.3, heavy=1,
            gunner_kind="bandit", rusher_kind="trapper")

# --- Купола радаров и антенна ---------------------------------------------------------------------
L.room("RRadar", -40, 40, -200, -130, 0, 12, "snow", "rock", None, openings={"S": GATE, "N": GATE})
for cx, cz, r in ((-24, -168, 8.0), (25, -178, 6.5)):
    L.cylinder("Geometry", "Radome", (cx, 3, cz), r, 6, "white_paint", sides=20)
    for k, (rr, hh, yy) in enumerate(((0.88, 2.0, 7.0), (0.68, 1.6, 8.8), (0.42, 1.2, 10.2), (0.18, 0.8, 11.2))):
        L.cylinder("Props", "RadomeCap", (cx, yy, cz), r * rr, hh, "white_paint", sides=20)
L.label("ОБЪЕКТ «ЩИТ-1»", (-24, 4.5, -159.9), size=56, color=SIGN)
L.box_ext("Geometry", "AntennaTower", 6.5, 9.5, 0, 12, -191.5, -188.5, "metal")
L.box_ext("Geometry", "AntennaDeck", 5, 11, 12, 12.4, -193, -187, "black_metal")
L.box("Props", "Dish", (8, 16, -190), (7, 5, 0.4), "white_paint", collide=False, rows=mul(rot_y(25), rot_x(-0.5)))
L.box("Props", "DishFeed", (8, 16.6, -188.6), (0.3, 0.3, 2.4), "metal", collide=False, rows=rot_x(-0.5))
building(-14, -4, -150, -140, 5, "concrete")
L.label("ПУЛЬТ УПРАВЛЕНИЯ", (-9, 4.2, -139.9), size=40, color=SIGN)
for x, z in ((-6, -175), (14, -150), (-30, -190)):
    block(x, z, random.uniform(-30, 30))
floodlight(-36, -136)
floodlight(36, -196)
L.enemy("bandit", (-14, 0, -170), look_at=(0, 0, -130))
L.enemy("bandit", (16, 0, -160), look_at=(0, 0, -130))
L.enemy("marksman", (8, 12.4, -190), look_at=(0, 0, -130))
L.enemy("marksman", (-9, 5.3, -145), look_at=(0, 0, -130))
L.enemy("heavy", (0, 0, -194), look_at=(0, 0, -130))
L.pickup("health", (-36, 0, -134))
L.pickup("ammo", (36, 0, -134))
L.wave_zone("ZoneRadar", (0, 2, -168), (60, 4, 50),
            spawns=[(-36, 0.1, -140), (36, 0.1, -140), (-36, 0.1, -196), (36, 0.1, -196)],
            barriers=[((0, 2, -200.15), (12.4, 4, 0.3))],
            title="Засада у радаров!", waves=2, first=5, extra=2, rusher=0.3, heavy=1,
            gunner_kind="bandit", rusher_kind="trapper")

# --- Автопарк и ангар: арена танка ---------------------------------------------------------------------
L.room("RMotor", -50, 50, -300, -200, 0, 14, "concrete", "rock", None, openings={"S": GATE})
L.box_ext("Geometry", "HangarWall", -24.5, -24, 0, 12, -300, -284, "metal")
L.box_ext("Geometry", "HangarWall", 24, 24.5, 0, 12, -300, -284, "metal")
L.box_ext("Geometry", "HangarRoof", -25, 25, 12, 12.6, -300, -283.5, "metal")
L.box_ext("Props", "HangarDoorL", -24, -14, 0, 11, -283.6, -283.3, "rust")
L.box_ext("Props", "HangarDoorR", 14, 24, 0, 11, -283.6, -283.3, "rust")
L.label("АНГАР №3", (0, 13.4, -283.2), size=96, color=SIGN)
for x, z, w, h, d in ((-38, -215, 2.6, 2.6, 6), (-38, -222, 2.6, 5.2, 6), (38, -275, 2.6, 2.6, 6), (-40, -275, 6, 2.6, 2.6)):
    L.box("Props", "Container", (x, h / 2, z), (w, h, d), "rust")
for x, z, yaw in ((-14, -228, 10), (14, -232, -15), (-22, -250, 80), (22, -255, 90), (-8, -262, 0), (10, -270, 5),
                  (-30, -240, 0), (32, -242, 0)):
    block(x, z, yaw)
for x, z in ((-20, -208), (20, -208)):
    sandbags(x, z, 4.0)
floodlight(-45, -205)
floodlight(45, -205)
floodlight(-45, -280)
floodlight(45, -280)
L.node("HangarLight", "OmniLight3D", "Lights", transform=xform((0, 10, -292)), light_color=WARM,
       light_energy="2.5", omni_range="22")
L.pickup("weapon", (-8, 0, -205), weapon="rpg")
L.pickup("weapon", (8, 0, -205), weapon="rpg")
L.pickup("weapon", (44, 0, -294), weapon="rpg")
L.pickup("ammo", (-44, 0, -294))
L.pickup("health", (-44, 0, -206))
L.pickup("health", (44, 0, -250))
L.pickup("grenade", (-44, 0, -250))
L.enemy("bandit", (-20, 0, -280), look_at=(0, 0, -200))
L.enemy("bandit", (20, 0, -280), look_at=(0, 0, -200))
L.markers("TankPath", [
    ("P1", (0, 0, -272), 0), ("P2", (-30, 0, -262), 0), ("P3", (-32, 0, -228), 0), ("P4", (0, 0, -218), 0),
    ("P5", (30, 0, -228), 0), ("P6", (30, 0, -262), 0), ("P7", (0, 0, -245), 0)])
L.markers("TankSpawns", [("S1", (-46, 0, -212), 90), ("S2", (46, 0, -212), -90), ("S3", (-46, 0, -290), 90),
                         ("S4", (46, 0, -290), -90)])
L.node("Tank", "CharacterBody3D", "Enemies", transform=xform((0, 0.1, -277), rot_y(180)),
       script=L.ext_res("Script", "res://scripts/tank_boss.gd"),
       path_points='NodePath("../../TankPath")', henchman_points='NodePath("../../TankSpawns")',
       henchman_scene=L.ext_res("PackedScene", "res://scenes/enemies/bandit.tscn"),
       heavy_scene=L.ext_res("PackedScene", "res://scenes/enemies/heavy.tscn"))

# --- Взрывоопасное --------------------------------------------------------------------------------------
L.explosives([(-30, 0, -60), (30, 0, -60), (-35, 0, -230), (35, 0, -255), (-20, 0, -268)], pattern="F")
L.cars([(12, 0, -70, 90), (-12, 0, -78, 80)])
L.explosives([(-6, 0, -45), (16, 0, -120), (-16, 0, -180), (18, 0, -196), (-40, 0, -260), (40, 0, -230)],
             pattern="TBT")

# --- Горы, лес, сияние ------------------------------------------------------------------------------------
L.section = "Outdoor"
for i in range(26):
    pine(random.choice((-1, 1)) * random.uniform(56, 90), random.uniform(-320, 20))
for x, z, w, h in ((-130, -150, 120, 70), (130, -150, 120, 80), (0, -380, 300, 110), (0, 90, 300, 50)):
    L.box("Props", "Mountain", (x, h / 2 - 8, z), (w, h, 140), "snow", collide=False, shadow=False)
L.cylinder("Props", "Moon", (90, 120, -420), 9, 1, "lamp_cold", collide=False, rows=rot_x(math.pi / 2), sides=24)
L.node("Snow", "Node3D", ".", script=L.ext_res("Script", "res://scripts/town/rain.gd"), snow="true")

L.player((0, 0, -3), 0)
L.waypoint((0, 0, -3), (0, 0, -128), (0, 0, -132), (0, 0, -198), (0, 0, -202), (0, 0, -240))

env = [
    ("ShaderMaterial", "SkyMat_R", {"shader": L.ext_res("Shader", "res://materials/aurora_sky.gdshader")}),
    ("Sky", "Sky_R", {"sky_material": 'SubResource("SkyMat_R")'}),
    ("Environment", "Env_R", {
        "background_mode": "2", "sky": 'SubResource("Sky_R")',
        "ambient_light_source": "2", "ambient_light_color": "Color(0.42, 0.47, 0.58, 1)",
        "ambient_light_energy": "0.65", "tonemap_mode": "2",
        "fog_enabled": "true", "fog_light_color": "Color(0.24, 0.26, 0.31, 1)", "fog_density": "0.005",
        "fog_sky_affect": "0.4",
    }),
]
L.node("WorldEnvironment", "WorldEnvironment", ".", environment='SubResource("Env_R")')
L.node("Moonlight", "DirectionalLight3D", ".", transform=xform((0, 40, 0), mul(rot_y(160), rot_x(math.radians(-38)))),
       light_color="Color(0.65, 0.75, 1, 1)", light_energy="0.45", shadow_enabled="true",
       directional_shadow_max_distance="60.0", directional_shadow_mode="1")
L.write("scenes/levels/level_radar.tscn", env, ["pistol", "shotgun", "magnum", "rifle", "sniper"])
