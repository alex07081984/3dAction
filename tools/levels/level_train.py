"""Уровень «Поезд» (дорога между городами): состав из шести вагонов и паровоза.
Поезд стоит на месте, а пейзаж несётся мимо (его строит scripts/train_level.gd по маршруту).
Старт — открытая площадка последнего вагона, цель — кабина паровоза.
Вагоны: смотровой, пассажирский (засада), товарный (люк на крышу), платформа с грузом,
бронированный почтовый (засада), тендер с углём, паровоз."""
from levelkit import Level, xform, rot_x, rot_y, rot_z, f, yaw_to
import math
import random

random.seed(77)
L = Level("LevelTrain", {
    "level_index": "-1",
    "title": '"Поезд"',
    "objective": '"Пробейтесь через вагоны к паровозу"',
})
for g in ("Geometry", "Lights", "Props", "Enemies", "Pickups"):
    L.group(g)

FLOOR = 1.2
H = 2.8  # высота вагона внутри: крыша на FLOOR + H + 0.4 = 4.4
W = 1.6  # полуширина вагона
WARM = "Color(1, 0.82, 0.55, 1)"
DOOR = [(-0.7, 0.7, 2.3)]


def bogies(z0, z1):
    for z in (z0 - 3.0, z1 + 3.0):
        L.box_ext("Props", "Bogie", -1.3, 1.3, 0.1, FLOOR - 0.5, z - 1.6, z + 1.6, "black_metal", collide=False)
        for x in (-1.0, 1.0):
            for dz in (-1.0, 1.0):
                L.cylinder("Props", "Wheel", (x, 0.45, z + dz), 0.45, 0.25, "metal", collide=False,
                           rows=rot_z(math.pi / 2), sides=10)


def coupler(z_rear):
    """Сцепка между вагонами: площадка во всю ширину (упасть между вагонами нельзя)."""
    L.box_ext("Geometry", "Coupler", -W, W, FLOOR - 0.5, FLOOR, z_rear - 1.0, z_rear, "metal")


def car_lamp(z):
    L.lamp((0, FLOOR + H - 0.05, z), 1.3, 8, color=WARM, size=(0.6, 0.06, 0.3))


# --- Вагон 1: открытая площадка и смотровой салон ------------------------------------------------
L.begin_section("Platform")
L.box_ext("Geometry", "PlatformFloor", -W, W, FLOOR - 0.5, FLOOR, -4, 0.5, "plank")
for x0, x1, z0, z1 in ((-W, W, 0.4, 0.5), (-W, -W + 0.1, -4, 0.5), (W - 0.1, W, -4, 0.5)):
    L.box_ext("Geometry", "Railing", x0, x1, FLOOR, FLOOR + 1.1, z0, z1, "black_metal")
L.room("W1", -W, W, -18, -4, FLOOR, H, "parquet", "wood", "concrete_dark", t=0.15,
       openings={"N": DOOR, "S": DOOR}, windows={"W": (0.9, 2.0), "E": (0.9, 2.0)})
for z in (-7, -12):
    L.box("Props", "Sofa", (-1.15, FLOOR + 0.4, z), (0.7, 0.8, 2.2), "sofa")
L.box("Props", "Bar", (1.2, FLOOR + 0.55, -15), (0.6, 1.1, 2.4), "wood")
car_lamp(-11)
bogies(0, -18)
coupler(-18)

# --- Вагон 2: пассажирский ----------------------------------------------------------------------
L.room("W2", -W, W, -39, -19, FLOOR, H, "carpet", "car_red", "concrete_dark", t=0.15,
       openings={"N": DOOR, "S": DOOR}, windows={"W": (0.9, 2.0), "E": (0.9, 2.0)})
for z in range(-21, -38, -3):
    for x in (-1.05, 1.05):
        L.box("Props", "Seat", (x, FLOOR + 0.45, z), (0.75, 0.9, 0.8), "sofa")
        L.box("Props", "SeatBack", (x, FLOOR + 1.0, z - 0.42), (0.75, 1.1, 0.12), "sofa")
car_lamp(-24)
car_lamp(-34)
bogies(-19, -39)
coupler(-39)

# --- Вагон 3: товарный, с люком на крышу ---------------------------------------------------------
L.room("W3", -W, W, -58, -40, FLOOR, H, "plank", "rust", None, t=0.15, openings={"N": DOOR, "S": DOOR})
L.box_ext("Geometry/W3", "Roof", -W - 0.15, W + 0.15, FLOOR + H, FLOOR + H + 0.4, -58.15, -55.5, "rust")
L.box_ext("Geometry/W3", "Roof", -W - 0.15, W + 0.15, FLOOR + H, FLOOR + H + 0.4, -53.0, -39.85, "rust")
L.box_ext("Geometry/W3", "Roof", -0.3, W + 0.15, FLOOR + H, FLOOR + H + 0.4, -55.5, -53.0, "rust")
# Ступени из ящиков к люку (из люка можно выбраться на крышу).
L.box_ext("Props", "CrateStep", -1.55, -0.6, FLOOR, FLOOR + 1.0, -52.4, -50.6, "crate")
L.box_ext("Props", "CrateStep", -1.55, -0.6, FLOOR, FLOOR + 2.0, -55.4, -53.2, "crate")
for x, z in ((1.05, -43), (1.05, -47.5), (-1.05, -44.5)):
    L.box("Props", "Crate", (x, FLOOR + 0.5, z), (0.9, 1.0, 1.2), "crate", rows=rot_y(random.uniform(-10, 10)))
car_lamp(-46)
bogies(-40, -58)
coupler(-58)

# --- Вагон 4: платформа с грузом -------------------------------------------------------------------
L.begin_section("Flatcar")
L.box_ext("Geometry", "FlatFloor", -W, W, FLOOR - 0.5, FLOOR, -77, -59, "plank")
for x0, x1 in ((-W, -W + 0.12), (W - 0.12, W)):
    L.box_ext("Geometry", "FlatRail", x0, x1, FLOOR, FLOOR + 0.6, -77, -59, "black_metal")
for x, z, h in ((1.05, -62, 1.3), (-1.05, -66, 1.6), (1.05, -71, 1.0), (-1.05, -74.5, 1.3)):
    L.box("Props", "Cargo", (x, FLOOR + h / 2, z), (0.9, h, 1.6), "crate")
L.box("Props", "Tarp", (-1.05, FLOOR + 1.7, -66), (1.0, 0.12, 1.7), "awning_green", collide=False)
bogies(-59, -77)
coupler(-77)

# --- Вагон 5: бронированный почтовый -----------------------------------------------------------------
L.room("W5", -W, W, -98, -78, FLOOR, H, "metal", "metal", "black_metal", t=0.15, openings={"N": DOOR, "S": DOOR})
for x, z in ((1.05, -81), (-1.05, -84), (1.05, -90), (-1.05, -94)):
    L.box("Props", "MailSacks", (x, FLOOR + 0.4, z), (0.9, 0.8, 1.6), "blanket")
L.box("Props", "Safe", (1.1, FLOOR + 0.6, -96.5), (0.8, 1.2, 0.8), "metal")
L.label("ПОЧТА США", (-W - 0.2, FLOOR + 1.6, -88), yaw=-90, size=56, color="Color(0.85, 0.9, 1, 1)")
car_lamp(-83)
car_lamp(-93)
bogies(-78, -98)
coupler(-98)

# --- Тендер с углём ------------------------------------------------------------------------------------
L.begin_section("Tender")
L.box_ext("Geometry", "TenderFloor", -W, W, FLOOR - 0.5, FLOOR, -109, -99, "black_metal")
for x0, x1 in ((-W, -W + 0.15), (W - 0.15, W)):
    L.box_ext("Geometry", "TenderWall", x0, x1, FLOOR, FLOOR + 1.6, -109, -99, "black_metal")
for x in (-1.0, 1.0):
    L.box_ext("Props", "Coal", x - 0.45, x + 0.45, FLOOR, FLOOR + 1.3, -108.5, -99.5, "concrete_dark")
bogies(-99, -109)
coupler(-109)

# --- Паровоз: кабина и котёл ---------------------------------------------------------------------------
L.room("Cab", -W, W, -116, -110, FLOOR, H, "metal", "black_metal", "black_metal", t=0.15,
       openings={"S": [(-0.9, 0.9, 2.4)]}, windows={"W": (1.0, 2.0), "E": (1.0, 2.0)})
L.box("Props", "Firebox", (0, FLOOR + 0.7, -115.4), (1.2, 1.4, 0.6), "black_metal")
L.box("Props", "Fire", (0, FLOOR + 0.5, -115.08), (0.6, 0.4, 0.05), "lamp_red", collide=False, shadow=False)
L.node("Light", "OmniLight3D", "Lights", transform=xform((0, FLOOR + 1.0, -114.5)),
       light_color="Color(1, 0.5, 0.2, 1)", light_energy="1.8", omni_range="6")
L.cylinder("Props", "Boiler", (0, 2.9, -124), 1.35, 16, "black_metal", rows=rot_x(math.pi / 2), sides=16)
L.box_ext("Props", "BoilerBand", -1.4, 1.4, 1.5, 4.3, -121.2, -120.8, "car_red", collide=False)
L.cylinder("Props", "Smokestack", (0, 5.0, -129), 0.45, 2.0, "black_metal", collide=False, sides=10)
L.box("Props", "Headlamp", (0, 3.6, -132.1), (0.6, 0.6, 0.3), "lamp", collide=False, shadow=False)
L.box_ext("Props", "Cowcatcher", -1.4, 1.4, 0.2, 1.0, -133.5, -132, "car_red", collide=False)
for z in (-113, -118, -122, -126, -130):
    for x in (-1.1, 1.1):
        L.cylinder("Props", "DriveWheel", (x, 0.8, z), 0.8, 0.2, "car_red", collide=False, rows=rot_z(math.pi / 2),
                   sides=12)
# Дым из трубы.
L.node("Smoke", "CPUParticles3D", ".", transform=xform((0, 6.2, -129)), amount="40", lifetime="2.5",
       direction="Vector3(0, 1, 1)", spread="12.0", initial_velocity_min="4.0", initial_velocity_max="7.0",
       gravity="Vector3(0, 1.5, 18)", scale_amount_min="2.0", scale_amount_max="4.0",
       mesh=L.sub_res("SphereMesh", {"radius": "0.3", "height": "0.6", "radial_segments": "6", "rings": "3",
                                     "material": L.sub_res("StandardMaterial3D", {
                                         "shading_mode": "0", "transparency": "1",
                                         "albedo_color": "Color(0.25, 0.25, 0.27, 0.55)"}, "SmokeMat")}, "SmokeMesh"))

# Невидимые стены по бокам (с крыши и из вагонов не выпасть) и позади.
for x in (-W - 0.35, W + 0.35):
    L.invisible_wall("Geometry", "Guard", (x, 5, -66), (0.3, 10, 136))
L.invisible_wall("Geometry", "Guard", (0, 5, 0.8), (2 * W + 1, 10, 0.3))
L.invisible_wall("Geometry", "Guard", (0, 5, -117.3), (2 * W + 1, 10, 0.3))

# --- Враги -------------------------------------------------------------------------------------------
for kind, pos, target in (
        ("gunner", (0.6, FLOOR, -14), (0, FLOOR, 0)),
        ("gunner", (-1.0, FLOOR, -27), (0, FLOOR, -19)),
        ("rusher", (0, FLOOR, -33), (0, FLOOR, -19)),
        ("gunner", (1.0, FLOOR, -37), (0, FLOOR, -19)),
        ("heavy", (-0.9, FLOOR, -50), (0, FLOOR, -40)),
        ("gunner", (0, FLOOR + H + 0.4, -49), (0, 4.4, -20)),
        ("gunner", (1.0, FLOOR, -69), (0, FLOOR, -59)),
        ("gunner", (-1.0, FLOOR, -72), (0, FLOOR, -59)),
        ("gunner", (0, FLOOR + H + 0.4, -86), (0, 4.4, -60)),
        ("gunner", (0.4, FLOOR + H + 0.4, -94), (0, 4.4, -60)),
        ("gunner", (0.8, FLOOR, -92), (0, FLOOR, -78)),
        ("rusher", (0, FLOOR, -104), (0, FLOOR, -98)),
        ("heavy", (0, FLOOR, -114), (0, FLOOR, -110))):
    L.enemy(kind, pos, look_at=target)

L.wave_zone("ZoneCoach", (0, FLOOR + 1.4, -29), (3.2, 2.8, 16),
            spawns=[(-0.6, FLOOR + 0.1, -37.5), (0.6, FLOOR + 0.1, -37.5), (0, FLOOR + 0.1, -36), (0, FLOOR + 0.1, -20.5)],
            barriers=[((0, FLOOR + 1.15, -18.95), (1.4, 2.3, 0.25)), ((0, FLOOR + 1.15, -39.05), (1.4, 2.3, 0.25))],
            title="Банда в вагоне!", waves=2, first=4, extra=2, rusher=0.35)
L.wave_zone("ZoneMail", (0, FLOOR + 1.4, -88), (3.2, 2.8, 16),
            spawns=[(-0.6, FLOOR + 0.1, -96.5), (0.6, FLOOR + 0.1, -97), (0, FLOOR + 0.1, -95), (0, FLOOR + 0.1, -79.5)],
            barriers=[((0, FLOOR + 1.15, -77.95), (1.4, 2.3, 0.25)), ((0, FLOOR + 1.15, -98.05), (1.4, 2.3, 0.25))],
            title="Налёт на почтовый вагон!", waves=2, first=5, extra=2, rusher=0.3, heavy=1)
L.exit((0, FLOOR + 1.5, -113.2), (2.6, 3, 2.6), (0, FLOOR + 2.4, -111.2), "ПАРОВОЗ", required_zone="ZoneMail")

for kind, pos in (("health", (-1.0, FLOOR, -2)), ("ammo", (1.0, FLOOR, -2)), ("ammo", (0.9, FLOOR, -30)),
                  ("health", (0.6, FLOOR, -56)), ("grenade", (-0.9, FLOOR, -61)), ("health", (0.9, FLOOR, -80.5)),
                  ("ammo", (-0.9, FLOOR, -101))):
    L.pickup(kind, pos)
L.pickup("weapon", (0, FLOOR, -63), weapon="rpg")
L.explosives([(-1.2, FLOOR, -6.5), (1.2, FLOOR, -41.5), (-1.2, FLOOR, -57), (-1.2, FLOOR, -69.5),
              (1.2, FLOOR, -75.5), (-1.2, FLOOR, -79.5), (1.2, FLOOR, -85.5), (1.2, FLOOR, -105.5)], pattern="BBCTB")

# Рельсы (сами шпалы и земля прокручиваются скриптом).
L.section = "Rails"
for x in (-0.75, 0.75):
    L.box_ext("Props", "Rail", x - 0.06, x + 0.06, -0.1, 0.05, -360, 160, "rail", collide=False, shadow=False)
# Далёкие горы по горизонту (неподвижны — так далеко, что почти не сдвигаются).
for i in range(14):
    side = -1 if i % 2 == 0 else 1
    z = -900 + i * 120
    h = random.uniform(60, 140)
    L.box("Props", "FarHill", (side * random.uniform(420, 560), h / 2 - 20, z), (180, h, 200), "rock",
          collide=False, shadow=False, rows=rot_y(random.uniform(-20, 20)))

L.player((0, FLOOR, -1.5), 0)
L.waypoint((0.13, FLOOR, -1.5), (0.13, FLOOR, -113))

MOON_YAW, MOON_PITCH = 200, -34
moon_dir = (math.sin(math.radians(MOON_YAW)) * math.cos(math.radians(MOON_PITCH)), -math.sin(math.radians(MOON_PITCH)),
            math.cos(math.radians(MOON_YAW)) * math.cos(math.radians(MOON_PITCH)))
env = [
    ("ShaderMaterial", "SkyMat_T", {
        "shader": L.ext_res("Shader", "res://materials/night_sky.gdshader"),
        "shader_parameter/moon_direction": f"Vector3({f(moon_dir[0])}, {f(moon_dir[1])}, {f(moon_dir[2])})",
        "shader_parameter/horizon_color": "Color(0.15, 0.15, 0.19, 1)",
    }),
    ("Sky", "Sky_T", {"sky_material": 'SubResource("SkyMat_T")'}),
    ("Environment", "Env_T", {
        "background_mode": "2", "sky": 'SubResource("Sky_T")',
        "ambient_light_source": "2", "ambient_light_color": "Color(0.4, 0.43, 0.55, 1)",
        "ambient_light_energy": "0.8", "tonemap_mode": "2",
        "fog_enabled": "true", "fog_light_color": "Color(0.14, 0.15, 0.19, 1)", "fog_density": "0.007",
        "fog_sky_affect": "0.3",
    }),
]
L.node("WorldEnvironment", "WorldEnvironment", ".", environment='SubResource("Env_T")')
L.node("Moonlight", "DirectionalLight3D", ".", transform=xform((0, 60, 0), [[sum(a * b for a, b in zip(r, c)) for c in zip(*rot_x(math.radians(MOON_PITCH)))] for r in rot_y(MOON_YAW)]),
       light_color="Color(0.65, 0.72, 1, 1)", light_energy="0.5", shadow_enabled="true",
       directional_shadow_max_distance="60.0", directional_shadow_mode="1")
L.write("scenes/levels/level_train.tscn", env, ["pistol", "shotgun", "magnum", "rifle"],
        script_path="res://scripts/train_level.gd")
