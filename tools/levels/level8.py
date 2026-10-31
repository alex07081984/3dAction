"""Уровень 8 «Тюрьма» (финал эпизода 2): проходная, двор с вышками, тюремный блок
с галереями и кабинет начальника тюрьмы — финального босса."""
from levelkit import Level, xform, rot_x, rot_y, f, yaw_to
import math
import random

random.seed(8)
L = Level("Level8Prison", {
    "level_index": "7",
    "title": '"Тюрьма"',
    "objective": '"Найдите начальника тюрьмы"',
})
for g in ("Geometry", "Lights", "Props", "Enemies", "Pickups"):
    L.group(g)

COLD = "Color(0.8, 0.88, 1, 1)"
WARM = "Color(1, 0.82, 0.55, 1)"


def mul(a, b):
    return [[sum(a[i][k] * b[k][j] for k in range(3)) for j in range(3)] for i in range(3)]


def tower(x, z):
    for dx in (-1.3, 1.3):
        for dz in (-1.3, 1.3):
            L.box("Props", "TowerLeg", (x + dx, 2.25, z + dz), (0.3, 4.5, 0.3), "concrete")
    L.box("Props", "TowerFloor", (x, 4.65, z), (3.2, 0.3, 3.2), "concrete")
    L.box("Props", "TowerRoof", (x, 7.4, z), (3.4, 0.2, 3.4), "black_metal", collide=False)
    L.box("Props", "Searchlight", (x, 6.9, z), (0.5, 0.4, 0.5), "lamp_cold", collide=False)
    L.node("Light", "OmniLight3D", "Lights", transform=xform((x, 6.6, z)), light_color=COLD, light_energy="2.0",
           omni_range="16")
    L.enemy("guard", (x, 4.8, z), look_at=(0, 0, -16))


# Проходная
L.room("TGate", -10, 10, -16, 0, 0, 5, "asphalt", "concrete", None, openings={"N": [(-4, 4)]})
L.box("Props", "Booth", (6.5, 1.5, -8), (3, 3, 3), "white_paint")
L.box_ext("Props", "BoothWindow", 4.95, 5.05, 1.4, 2.4, -9, -7, "lamp", collide=False, shadow=False)
L.box("Props", "GateArm", (-0.5, 1.0, -12), (7, 0.15, 0.15), "hazard", collide=False)
L.label("ТЮРЬМА № 13", (0, 6.2, -15.4), size=110, color="Color(0.85, 0.9, 1, 1)")
for x in (-7, 7):
    L.cylinder("Props", "Post", (x, 2.5, -2), 0.1, 5, "black_metal")
    L.box("Props", "PostLamp", (x, 5.1, -2), (0.5, 0.25, 0.4), "lamp_cold", collide=False)
    L.node("Light", "OmniLight3D", "Lights", transform=xform((x, 4.8, -2)), light_color=COLD, light_energy="1.6",
           omni_range="12")
L.enemy("guard", (-6, 0, -12), look_at=(0, 0, 0))
L.enemy("guard", (4, 0, -12.5), look_at=(0, 0, 0))

# Прогулочный двор с вышками
L.room("TYard", -30, 30, -76, -16, 0, 7, "gravel", "concrete", None,
       openings={"S": [(-4, 4)], "N": [(-3, 3, 4)]})
for x in (-25.5, 25.5):
    for z in (-20, -72):
        tower(x, z)
for x0, x1, z0, z1 in ((-18, -17.9, -54, -38), (-26, -10, -46.05, -45.95)):
    L.box_ext("Props", "CourtLine", x0, x1, 0, 0.02, z0, z1, "white_paint", collide=False, shadow=False)
L.box("Props", "HoopPole", (-18, 2, -46), (0.2, 4, 0.2), "black_metal")
L.box("Props", "HoopBoard", (-18, 3.6, -46.3), (1.8, 1.2, 0.08), "white_paint", collide=False)
for x in (-14, 14):
    for z in (-30, -60):
        L.box("Props", "Bench", (x, 0.25, z), (2.5, 0.5, 0.6), "wood")
for x in (-7, 7):
    for z in (-36, -58):
        L.box("Props", "Barrier", (x, 0.5, z), (3, 1, 0.6), "concrete")
L.box("Props", "Weights", (14, 0.4, -46), (2, 0.8, 1), "metal")
L.label("БЛОК А", (0, 5.6, -75.4), size=96, color="Color(0.85, 0.9, 1, 1)")
L.pickup("health", (-28, 0, -18))
L.pickup("ammo", (28, 0, -46))
L.pickup("grenade", (-28, 0, -74))
L.enemy("inmate", (-12, 0, -40), look_at=(0, 0, -16))
L.enemy("inmate", (12, 0, -52), look_at=(0, 0, -16))
L.enemy("inmate", (-16, 0, -62), look_at=(0, 0, -16))
L.enemy("guard", (8, 0, -30), look_at=(0, 0, -16))
L.enemy("guard", (-8, 0, -70), look_at=(0, 0, -16))
L.wave_zone("ZoneYard", (0, 2, -46), (56, 4, 56),
            spawns=[(-22, 0.1, -24), (22, 0.1, -24), (-22, 0.1, -68), (22, 0.1, -68)],
            barriers=[((0, 2.5, -16.15), (8.4, 5, 0.3)), ((0, 2, -75.85), (6.4, 4, 0.3))],
            title="Бунт во дворе!", waves=2, first=6, extra=2, rusher=0.5, heavy=1)

# Тюремный блок: камеры в два яруса, галереи, столы в середине
L.room("TCells", -14, 14, -136, -76, 0, 9, "concrete", "concrete_dark", "concrete",
       openings={"S": [(-3, 3, 4)], "N": [(-3, 3, 4)]})
CELL = 4.6
for side in (-1, 1):
    inner, outer = side * 10, side * 14
    lo, hi = min(inner, outer), max(inner, outer)
    L.box_ext("Props", "CellFloor", lo, hi, 4.2, 4.5, -134, -134 + 12 * CELL, "concrete")
    L.invisible_wall("Geometry", "CellBars", (inner, 4.5, -134 + 6 * CELL), (0.2, 9, 12 * CELL))
    for i in range(13):
        z = -134 + i * CELL
        L.box_ext("Props", "CellWall", lo, hi, 0, 8.7, z - 0.1, z + 0.1, "concrete")
        if i == 12:
            break
        for k in range(1, 5):
            rz = z + k * CELL / 5
            for y0, y1 in ((0, 4.2), (4.5, 8.5)):
                L.box_ext("Props", "Bar", inner - 0.04, inner + 0.04, y0, y1, rz - 0.04, rz + 0.04, "rail",
                          collide=False, shadow=False)
    # Галерея второго яруса вдоль камер
    walk_lo, walk_hi = (7, 10) if side > 0 else (-10, -7)
    rail_x = side * 7
    L.box_ext("Props", "Gallery", walk_lo, walk_hi, 4.2, 4.5, -134, -78, "metal")
    L.box_ext("Props", "Railing", rail_x - 0.05, rail_x + 0.05, 4.5, 5.5, -134, -78, "rail")
    for z in (-86, -98, -110, -122):
        L.box("Props", "Pillar", (side * 7.2, 2.1, z), (0.4, 4.2, 0.4), "metal")
for x in (-5, 5):
    for z in (-90, -104, -118):
        L.box("Props", "MessTable", (x, 0.4, z), (2, 0.8, 4), "metal")
for z in (-86, -106, -126):
    L.lamp((0, 8.9, z), 1.5, 14, mat="lamp_cold", color=COLD)
L.pickup("health", (-9, 0, -82))
L.pickup("ammo", (9, 0, -130))
L.pickup("grenade", (-9, 0, -130))
L.enemy("inmate", (-5, 0, -97), look_at=(0, 0, -76))
L.enemy("inmate", (5, 0, -111), look_at=(0, 0, -76))
L.enemy("guard", (-6, 0, -128), look_at=(0, 0, -76))
L.enemy("heavy", (0, 0, -132), look_at=(0, 0, -76))
L.enemy("guard", (8.5, 4.5, -95), look_at=(0, 0, -80))
L.enemy("guard", (-8.5, 4.5, -95), look_at=(0, 0, -80))
L.enemy("guard", (8.5, 4.5, -120), look_at=(0, 0, -90))
L.enemy("guard", (-8.5, 4.5, -120), look_at=(0, 0, -90))
L.wave_zone("ZoneCells", (0, 2, -106), (19, 4, 58),
            spawns=[(-8, 0.1, -79), (8, 0.1, -79), (-8, 0.1, -133), (8, 0.1, -133)],
            barriers=[((0, 2, -76.15), (6.4, 4, 0.3)), ((0, 2, -135.85), (6.4, 4, 0.3))],
            title="Камеры открыты!", waves=2, first=6, extra=2, rusher=0.5, heavy=1)

# Коридор администрации
L.room("TCorr", -3, 3, -160, -136, 0, 4, "floor_tiles", "office_wall", "ceiling",
       openings={"S": [(-3.5, 3.5, 4)], "N": [(-3.5, 3.5, 3.5)]})
L.lamp((0, 3.9, -148), 1.3, 10, mat="lamp_cold", color=COLD)
L.label("НАЧАЛЬНИК", (0, 3.7, -159.4), size=56, color="Color(0.95, 0.8, 0.4, 1)")
L.enemy("guard", (1.5, 0, -150), look_at=(0, 0, -136))

# Кабинет начальника — арена финального босса
L.room("TWarden", -18, 18, -196, -160, 0, 7, "parquet", "wood", "ceiling", openings={"S": [(-3, 3, 3.5)]})
L.box("Props", "Desk", (0, 0.45, -188), (5, 0.9, 2), "wood")
for x in (-7, 7):
    for z in (-170, -182):
        L.box("Props", "Column", (x, 3.5, z), (1.2, 7, 1.2), "marble")
for x in (-18, 17.2):
    L.box_ext("Props", "Bookcase", x, x + 0.8, 0, 3.5, -190, -166, "wood")
L.box_ext("Props", "Portrait", -2, 2, 2.5, 5.5, -195.95, -195.85, "gold", collide=False)
for x in (-4, 4):
    L.box_ext("Props", "Flag", x - 0.8, x + 0.8, 2, 5.5, -195.9, -195.8, "car_red", collide=False, shadow=False)
for x, z in ((-9, -168), (9, -168), (-9, -190), (9, -190)):
    L.lamp((x, 6.9, z), 1.4, 12, mat="gold", color=WARM, size=(0.8, 0.15, 0.8))
L.pickup("health", (-16, 0, -194.5))
L.pickup("health", (16, 0, -194.5))
L.pickup("grenade", (16, 0, -162))
L.enemy("guard", (-12, 0, -176), look_at=(0, 0, -160))
L.enemy("guard", (12, 0, -186), look_at=(0, 0, -160))
L.boss("warden", "Warden", (0, 0, -191.5), (0, 0, -160), henchman_points='NodePath("../../BossSpawns")')
L.markers("BossSpawns", [(f"Spawn{i}", p, 0) for i, p in enumerate((
    (-16, 0, -162), (16, 0, -162.5), (-16, 0, -194), (16, 0, -193), (0, 0, -150)))])

L.section = "Outdoor"
L.box_ext("Props", "Ground", -200, 200, -2, -0.6, -300, 100, "gravel", collide=False, shadow=False)
L.cylinder("Props", "Moon", (-90, 100, -320), 8, 1, "lamp_cold", collide=False, rows=rot_x(math.pi / 2), sides=24)

L.player((0, 0, -3), 0)
L.waypoint((0, 0, -3), (0, 0, -15), (0, 0, -17), (0, 0, -75), (0, 0, -77), (0, 0, -135), (0, 0, -137),
           (0, 0, -159), (0, 0, -161), (0, 0, -180))

env = [
    ("ProceduralSkyMaterial", "SkyMat_8", {
        "sky_top_color": "Color(0.015, 0.02, 0.04, 1)", "sky_horizon_color": "Color(0.1, 0.11, 0.15, 1)",
        "ground_bottom_color": "Color(0.01, 0.01, 0.02, 1)", "ground_horizon_color": "Color(0.08, 0.09, 0.12, 1)",
    }),
    ("Sky", "Sky_8", {"sky_material": 'SubResource("SkyMat_8")'}),
    ("Environment", "Env_8", {
        "background_mode": "2", "sky": 'SubResource("Sky_8")',
        "ambient_light_source": "2", "ambient_light_color": "Color(0.34, 0.38, 0.48, 1)",
        "ambient_light_energy": "0.58", "tonemap_mode": "2",
        "fog_enabled": "true", "fog_light_color": "Color(0.05, 0.06, 0.09, 1)", "fog_density": "0.012",
        "fog_sky_affect": "0.3",
    }),
]
L.node("WorldEnvironment", "WorldEnvironment", ".", environment='SubResource("Env_8")')
L.node("Moonlight", "DirectionalLight3D", ".", transform=xform((0, 40, 0), mul(rot_y(200), rot_x(math.radians(-42)))),
       light_color="Color(0.6, 0.7, 1, 1)", light_energy="0.35", shadow_enabled="true",
       directional_shadow_max_distance="50.0", directional_shadow_mode="1")
L.explosives([(-8.5, 0, -14), (8.6, 0, -14), (-28, 0, -44), (28, 0, -30), (10, 0, -73), (-8.5, 0, -112),
              (8.5, 0, -96), (-16.5, 0, -178), (16.4, 0, -172)], pattern="BBC")
L.write("scenes/levels/level_8_prison.tscn", env, ["pistol", "shotgun", "deagle", "rifle"])
