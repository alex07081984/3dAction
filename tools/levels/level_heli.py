"""Уровень «Вертолёт над заливом» (эпизод 2): герой у пулемёта в двери полицейского вертолёта.
Взлёт с крыши небоскрёба, зачистка пирса, Алькатраса и моста Золотые Ворота с воздуха,
потом бой с боевым вертолётом банды над заливом. Вертолёт летит сам по точкам Flight."""
from levelkit import Level, xform, rot_x, rot_y, rot_z, f, yaw_to
import math
import random

random.seed(99)
L = Level("LevelHeliBay", {
    "level_index": "9",
    "title": '"Вертолёт над заливом"',
    "objective": '"Прикройте полицию с воздуха и собейте боевой вертолёт банды"',
})
for g in ("Geometry", "Lights", "Props", "Enemies", "Pickups"):
    L.group(g)

WARM = "Color(1, 0.85, 0.6, 1)"
SIGN = "Color(1, 0.85, 0.4, 1)"
FACADES = ["facade_white", "facade_blue", "facade_yellow", "facade_pink", "skyline"]


def mul(a, b):
    return [[sum(a[i][k] * b[k][j] for k in range(3)) for j in range(3)] for i in range(3)]


def post(kind, pos, target, **props):
    """Враг на посту: видит далеко и не сходит с места (бьёт по вертолёту)."""
    L.enemy(kind, pos, look_at=target, sight_range="95", effective_range="70", stationary="true",
            view_angle_deg="230", **props)


def hover_zone(name, hover, spawns, title, first=4, extra=2, heavy=1):
    L.wave_zone(name, hover, (12, 12, 12), spawns=spawns, barriers=[], title=title, waves=2, first=first,
                extra=extra, rusher=0.0, heavy=heavy, enemy_sight_range="95", enemy_stationary="true")


# --- Город на берегу и крыша с вертолётной площадкой -------------------------------------
L.begin_section("City")
L.box_ext("Geometry", "Shore", -420, 320, -1.5, 1.0, 20, 34, "concrete")
L.box_ext("Geometry", "Helitower", -9, 9, -1, 38, 51, 69, "skyline")
L.box_ext("Props", "Helipad", -6, 6, 38, 38.05, 54, 66, "concrete_dark", collide=False, shadow=False)
L.label("H", (0, 38.1, 60), size=400, color="Color(1, 1, 1, 0.9)", pixel=0.01)
L.nodes[-1] = L.nodes[-1].replace(f'transform = {xform((0, 38.1, 60))}', f'transform = {xform((0, 38.1, 60), rot_x(-math.pi / 2))}')
for i in range(26):
    x = -320 + i * 24 + random.uniform(-6, 6)
    if -20 < x < 20:
        continue
    z0 = random.uniform(36, 60)
    h = random.uniform(18, 70)
    L.box_ext("Geometry", "Tower", x - 9, x + 9, -1, h, z0, z0 + random.uniform(14, 30), random.choice(FACADES))
L.box_ext("Props", "Pyramid", 60, 74, -1, 90, 70, 84, "skyline", collide=False)
L.box_ext("Props", "PyramidTop", 64, 70, 90, 120, 74, 80, "white_paint", collide=False)

# --- Пирс 39: склады, лодки, банда ------------------------------------------------------
L.begin_section("Pier")
L.box_ext("Geometry", "PierDeck", 38, 52, 0, 2, -122, 22, "plank")
for z in range(-118, 20, 12):
    for x in (38.5, 51.5):
        L.box("Props", "Piling", (x, -0.5, z), (0.6, 3, 0.6), "wood", collide=False)
L.box_ext("Geometry", "Warehouse", 40, 50, 2, 8, -85, -60, "rust")
L.box_ext("Geometry", "Shed", 40, 50, 2, 7, -110, -95, "plank")
L.label("ПИРС 39", (52.1, 6.2, -72), yaw=90, size=96, color=SIGN)
for x, z, yaw in ((61, -100, 8), (30, -122, -15)):
    L.box("Geometry", "Boat", (x, 0.4, z), (4.5, 1.6, 11), "white_paint", rows=rot_y(yaw))
    L.box("Props", "BoatCabin", (x, 1.9, z + 1.5), (3, 1.4, 3.5), "dark_glass", rows=rot_y(yaw))
for z in (-40, -70, -100, -118):
    L.lamp((45, 7.5 if z == -40 else 10, z), 2.4, 22, color=WARM, size=(0.5, 0.2, 0.5))
post("gunner", (45, 8, -72), (14, 20, -98))
post("gunner", (51, 2, -78), (14, 20, -98))
post("gunner", (39.5, 2, -100), (14, 20, -98))
post("gunner", (45, 7, -102), (14, 20, -98))
post("gunner", (61, 1.2, -97), (14, 20, -98))
hover_zone("ZonePier", (14, 20, -98), [(44, 2.1, -90), (51, 2.1, -65), (39, 2.1, -118), (61, 1.3, -103)],
           "Банда на пирсе!")

# --- Алькатрас ---------------------------------------------------------------------------
L.begin_section("Alcatraz")
L.box_ext("Geometry", "Island", -150, -70, -3, 4, -310, -230, "rock")
L.box_ext("Geometry", "Prison", -130, -95, 4, 14, -290, -262, "concrete")
L.box_ext("Props", "PrisonWindows", -94.95, -94.9, 7, 12, -288, -264, "dark_glass", collide=False, shadow=False)
for x0, z0 in ((-75, -236), (-75, -306)):
    L.box_ext("Geometry", "GuardTower", x0, x0 + 4, 4, 11.6, z0, z0 + 4, "concrete")
    L.box_ext("Geometry", "TowerDeck", x0 - 0.5, x0 + 4.5, 11.6, 12, z0 - 0.5, z0 + 4.5, "concrete_dark")
L.cylinder("Props", "Lighthouse", (-140, 14, -240), 1.6, 20, "white_paint", collide=False, sides=12)
L.box("Props", "LighthouseLamp", (-140, 24.6, -240), (1.6, 1.2, 1.6), "lamp", collide=False, shadow=False)
L.label("АЛЬКАТРАС", (-94.6, 13, -276), yaw=90, size=120, color="Color(0.85, 0.9, 1, 1)")
L.lamp((-80, 7, -270), 2.6, 24, color=WARM, size=(0.5, 0.2, 0.5))
L.lamp((-73, 15, -234), 2.0, 16, color=WARM, size=(0.4, 0.2, 0.4))
L.lamp((-100, 17, -275), 2.2, 20, color=WARM, size=(0.4, 0.2, 0.4))
post("gunner", (-80, 4, -250), (-58, 26, -250))
post("gunner", (-73, 12, -234), (-58, 26, -250))
post("gunner", (-73, 12, -304), (-58, 26, -250))
post("gunner", (-100, 14, -270), (-58, 26, -250))
post("heavy", (-88, 4, -298), (-58, 26, -250))
post("gunner", (-110, 14, -282), (-58, 26, -250))
hover_zone("ZoneAlcatraz", (-58, 26, -250), [(-82, 4.1, -262), (-82, 4.1, -280), (-98, 14.1, -265), (-78, 4.1, -295)],
           "Бунт на Алькатрасе!")

# --- Мост Золотые Ворота --------------------------------------------------------------------
L.begin_section("Bridge")
DECK = 22
L.box_ext("Geometry", "Deck", -268, -252, DECK - 2, DECK, -720, -380, "asphalt")
for x0, x1 in ((-268.4, -268), (-252, -251.6)):
    L.box_ext("Geometry", "Railing", x0, x1, DECK, DECK + 1.2, -720, -380, "bridge_red")
for z in (-470, -620):
    for x0 in (-269, -255):
        L.box_ext("Geometry", "BridgeTower", x0, x0 + 4, -2, 82, z - 2, z + 2, "bridge_red")
    for y in (DECK + 18, 60, 80):
        L.box_ext("Props", "TowerBeam", -269, -251, y, y + 2, z - 1.5, z + 1.5, "bridge_red", collide=False)
for x in (-267, -253):
    for z0, z1, y0, y1 in ((-380, -470, DECK + 4, 80), (-470, -545, 80, DECK + 4), (-545, -620, DECK + 4, 80)):
        length = math.hypot(z1 - z0, y1 - y0)
        angle = math.atan2(y1 - y0, abs(z1 - z0))
        L.box("Props", "Cable", (x, (y0 + y1) / 2, (z0 + z1) / 2), (0.5, 0.5, length), "bridge_red", collide=False,
              rows=rot_x(angle if z1 < z0 else -angle), shadow=False)
for z in (-410, -440, -480, -510, -560):
    L.lamp((-260, DECK + 6, z), 2.4, 20, color=WARM, size=(0.5, 0.2, 0.5))
post("gunner", (-260, DECK, -430), (-232, 34, -440))
post("gunner", (-255, DECK, -452), (-232, 34, -440))
post("gunner", (-265, DECK, -462), (-232, 34, -440))
post("gunner", (-258, DECK, -485), (-232, 34, -440))
post("heavy", (-261, DECK, -505), (-232, 34, -440))
hover_zone("ZoneBridge", (-232, 34, -440), [(-262, DECK + 0.1, -415), (-255, DECK + 0.1, -445),
                                            (-264, DECK + 0.1, -478), (-258, DECK + 0.1, -495)],
           "Засада на мосту!")

# --- Взрывоопасное: цистерны и бочки на пирсе, бочки на острове, машины на мосту ------------------
L.explosives([(41, 2, -45), (49, 2, -50)], pattern="F")
L.explosives([(39, 2, -92), (51, 2, -93), (47, 2, -116), (-84, 4, -258), (-86, 4, -290)], pattern="BBC")
L.cars([(-262, DECK, -420, 0), (-256, DECK, -440, 180), (-263, DECK, -458, 8), (-256, DECK, -490, 175),
        (-262, DECK, -515, -6)])

# --- Полицейский вертолёт героя -----------------------------------------------------------------
START = (0, 38.6, 60)
heli = L.node("Helicopter", "Node3D", ".", transform=xform(START))
L.combiner("Helicopter/Body", False)
B = "Helicopter/Body"
# Хвостовая балка — на уровне крыши: из двери её не видно, камера справа от героя её не задевает.
for name, center, size, mat in (
        ("Floor", (0, -0.07, 0.15), (2.4, 0.15, 3.6), "concrete_dark"),
        ("Roof", (0, 2.75, 0.15), (2.4, 0.15, 3.8), "black_metal"),
        ("WallL", (-1.2, 1.35, 0.15), (0.1, 2.8, 3.6), "concrete_dark"),
        ("StripeL", (-1.26, 1.0, 0.15), (0.04, 0.35, 3.6), "plaster_blue"),
        ("PillarFront", (1.15, 1.35, -1.55), (0.12, 2.8, 0.12), "black_metal"),
        ("Cockpit", (0, 0.95, -2.3), (2.2, 1.7, 1.4), "dark_glass"),
        ("Nose", (0, 0.4, -3.15), (1.6, 0.8, 0.4), "white_paint"),
        ("Boom", (0, 2.65, 5.0), (0.5, 0.4, 6.0), "black_metal"),
        ("BoomStripe", (0, 2.5, 5.0), (0.52, 0.08, 6.0), "plaster_blue"),
        ("Fin", (0, 3.3, 7.8), (0.12, 1.3, 1.0), "plaster_blue"),
        ("SkidL", (-1.0, -0.6, 0.2), (0.12, 0.12, 4.0), "black_metal"),
        ("SkidR", (1.0, -0.6, 0.2), (0.12, 0.12, 4.0), "black_metal"),
        ("StrutL", (-1.0, -0.3, 0.2), (0.1, 0.6, 0.1), "black_metal"),
        ("StrutR", (1.0, -0.3, 0.2), (0.1, 0.6, 0.1), "black_metal"),
        ("Hub", (0, 3.0, 0.2), (0.4, 0.3, 0.4), "black_metal")):
    L.box(B, name, center, size, mat, collide=False)
L.node("PoliceText", "Label3D", "Helicopter", transform=xform((-1.3, 1.45, 0.15), rot_y(-90)), pixel_size="0.008",
       modulate="Color(0.2, 0.3, 0.9, 1)", text='"ПОЛИЦИЯ"', font_size="64", outline_size="0")
L.node("Rotor", "Node3D", "Helicopter", transform=xform((0, 3.2, 0.2)))
L.combiner("Helicopter/Rotor/Blades", False)
for angle in (0, 90):
    L.box("Helicopter/Rotor/Blades", "Blade", (0, 0, 0), (11, 0.05, 0.35), "black_metal", collide=False,
          rows=rot_y(angle))
L.node("CabinLight", "OmniLight3D", "Helicopter", transform=xform((-0.2, 2.3, 0.4)), light_color=WARM,
       light_energy="1.6", omni_range="5")
L.node("Seat", "Marker3D", "Helicopter", transform=xform((1.0, 0.0, 0.2)))
# Невидимые стенки кабины на отдельном слое 6: в них упирается только «пружина» камеры,
# чтобы она не вылезала за борт и не закрывала обзор. Пули и враги их не замечают.
shell = L.node("CameraShell", "StaticBody3D", "Helicopter", collision_layer="32", collision_mask="0")
for name, center, size in (
        ("Back", (-1.2, 1.4, 0.15), (0.3, 3.2, 4.6)),
        ("Top", (0, 2.7, 0.15), (2.8, 0.3, 4.6)),
        ("Bottom", (0, -0.25, 0.15), (2.8, 0.3, 4.6)),
        ("Front", (0, 1.4, -1.85), (2.8, 3.2, 0.3)),
        ("Rear", (0, 1.4, 2.25), (2.8, 3.2, 0.3))):
    box = L.sub_res("BoxShape3D", {"size": f"Vector3({size[0]}, {size[1]}, {size[2]})"}, "Box")
    L.node(name, "CollisionShape3D", shell, transform=xform(center), shape=box)

# --- Маршрут полёта ----------------------------------------------------------------------------
flight = L.group("Flight")
for i, (pos, meta) in enumerate((
        (START, {"metadata__speed": "4.0"}),
        ((0, 44, 40), {"metadata__speed": "10.0"}),
        ((6, 30, -10), {}),
        ((12, 22, -70), {}),
        ((14, 20, -98), {"metadata__zone": 'NodePath("ZonePier")'}),
        ((-10, 26, -160), {}),
        ((-40, 28, -210), {}),
        ((-58, 26, -250), {"metadata__zone": 'NodePath("ZoneAlcatraz")'}),
        ((-120, 30, -330), {}),
        ((-190, 34, -390), {}),
        ((-232, 34, -440), {"metadata__zone": 'NodePath("ZoneBridge")'}),
        ((-200, 40, -520), {"metadata__boss": "true"}))):
    L.node(f"P{i:02d}", "Marker3D", flight, transform=xform(pos), **meta)

L.node("AttackHelicopter", "CharacterBody3D", ".", transform=xform((-150, 55, -620)),
       script=L.ext_res("Script", "res://scripts/attack_helicopter.gd"))

# --- Залив, луна ---------------------------------------------------------------------------------
L.section = "Outdoor"
L.box_ext("Props", "Water", -700, 500, -2, -0.6, -1000, 20, "water", collide=False, shadow=False)
L.box_ext("Props", "MarinHills", -900, 300, -2, 60, -1100, -900, "grass", collide=False, shadow=False)
L.box_ext("Props", "WestHills", -900, -650, -2, 45, -900, 40, "grass", collide=False, shadow=False)
L.cylinder("Props", "Moon", (-300, 160, -700), 12, 1, "lamp_cold", collide=False, rows=rot_x(math.pi / 2), sides=24)

L.player((START[0] + 1.0, START[1], START[2] + 0.2), 90)
L.waypoint(START)

MOON_YAW, MOON_PITCH = 210, -30
moon_dir = (math.sin(math.radians(MOON_YAW)) * math.cos(math.radians(MOON_PITCH)), -math.sin(math.radians(MOON_PITCH)),
            math.cos(math.radians(MOON_YAW)) * math.cos(math.radians(MOON_PITCH)))
env = [
    ("ShaderMaterial", "SkyMat_H", {
        "shader": L.ext_res("Shader", "res://materials/night_sky.gdshader"),
        "shader_parameter/moon_direction": f"Vector3({f(moon_dir[0])}, {f(moon_dir[1])}, {f(moon_dir[2])})",
        "shader_parameter/horizon_color": "Color(0.13, 0.13, 0.17, 1)",
    }),
    ("Sky", "Sky_H", {"sky_material": 'SubResource("SkyMat_H")'}),
    ("Environment", "Env_H", {
        "background_mode": "2", "sky": 'SubResource("Sky_H")',
        "ambient_light_source": "2", "ambient_light_color": "Color(0.36, 0.4, 0.52, 1)",
        "ambient_light_energy": "0.85", "tonemap_mode": "2",
        "fog_enabled": "true", "fog_light_color": "Color(0.12, 0.13, 0.17, 1)", "fog_density": "0.006",
        "fog_sky_affect": "0.3",
    }),
]
L.node("WorldEnvironment", "WorldEnvironment", ".", environment='SubResource("Env_H")')
L.node("Moonlight", "DirectionalLight3D", ".", transform=xform((0, 60, 0), mul(rot_y(MOON_YAW), rot_x(math.radians(MOON_PITCH)))),
       light_color="Color(0.6, 0.7, 1, 1)", light_energy="0.45", shadow_enabled="true",
       directional_shadow_max_distance="80.0", directional_shadow_mode="1")
L.write("scenes/levels/level_heli_bay.tscn", env, ["minigun", "heli_rockets"], script_path="res://scripts/heli_level.gd")
