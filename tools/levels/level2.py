from levelkit import Level, xform, rot_x, rot_y, f
import math

L = Level("Level2Metro", {
    "level_index": "1",
    "title": '"Метро"',
    "objective": '"Пройдите по тоннелю к станции «Конечная»"',
})
for g in ("Geometry", "Lights", "Props", "Enemies", "Pickups"):
    L.group(g)

T = 0.5
TRACK = -1.3  # уровень путей


def platform_hall(name, z0, z1, south_open, north_open):
    """Станционный зал: пути внизу, островная платформа x[-4, 4] на уровне 0."""
    L.room(name, -11, 11, z0, z1, TRACK, 7.3, "gravel", "tiles_wall", "concrete",
           openings={"S": south_open, "N": north_open})
    g = f"Geometry/{name}"
    L.box_ext(g, "Platform", -4, 4, TRACK, 0, z0, z1, "floor_tiles")
    for x in (-3.85, 3.85):
        L.box_ext("Props", "Edge", x - 0.15, x + 0.15, 0, 0.02, z0, z1, "hazard", collide=False, shadow=False)
    for x in (-8.5, -6.5, 6.5, 8.5):
        L.box_ext("Props", "Rail", x - 0.06, x + 0.06, TRACK, TRACK + 0.15, z0, z1, "rail", collide=False,
                  shadow=False)
    zc = z0 + 6
    while zc < z1 - 3:
        for x in (-2.6, 2.6):
            L.box("Props", "Column", (x, 3, zc), (0.9, 6, 0.9), "marble")
        zc += 8


# V1 — вестибюль (y = 6)
L.room("V1Vestibule", -8, 8, -14, 0, 6, 4.5, "floor_tiles", "tiles_wall", "ceiling",
       openings={"N": [(-3.5, 3.5)]})
for x in (-6.5, -4.5, -2.5, 2.5, 4.5, 6.5):
    L.box("Props", "Turnstile", (x, 6.5, -9), (0.35, 1.0, 1.4), "metal")
L.box("Props", "Booth", (-6.2, 7.25, -3), (2.6, 2.5, 3), "train")
L.box("Props", "BoothWindow", (-4.85, 7.6, -3), (0.06, 0.8, 2.2), "dark_glass", collide=False)
L.box("Props", "Bench", (6.6, 6.25, -3), (1.0, 0.5, 3), "wood")
L.lamp((0, 10.4, -4), 1.5, 10)
L.lamp((0, 10.4, -11), 1.5, 10)
L.box("Props", "SignPlate", (0, 9.3, -13.85), (1.6, 1.6, 0.1), "white_paint", collide=False)
L.label("М", (0, 9.3, -13.78), size=150, color="Color(0.95, 0.15, 0.15, 1)")
L.label("ВХОД В МЕТРО", (0, 8.5, -0.1), yaw=180, size=48)
L.pickup("weapon", (5.5, 6, -5.5), weapon="deagle")
L.enemy("gunner", (-4.2, 6, -12), look_at=(0, 6, -2))
L.enemy("gunner", (4.6, 6, -12.5), look_at=(0, 6, -2))
L.player((0, 6.05, -2), 0)

# E1 — эскалатор вниз до платформы
L.room("E1Escalator", -3, 3, -28, -14, 0, 10.5, "floor_tiles", "tiles_wall", "ceiling",
       openings={"S": [(-3.5, 3.5, 6, 10.5)], "N": [(-3.5, 3.5, 4)]})
L.ramp_z("Geometry/E1Escalator", "Ramp", -3, 3, -14, 6, -26, 0, "metal")
for x in (-2.75, 2.75):
    L.ramp_z("Props", "Handrail", x - 0.12, x + 0.12, -14, 7.0, -26, 1.0, "rubber", t=0.15)
L.lamp((0, 10.4, -18), 1.4, 10)
L.lamp((0, 8.0, -25), 1.2, 9)
L.enemy("rusher", (0, 0, -27), look_at=(0, 0, -14))

# P1 — станция «Подземная»
platform_hall("P1Station", -72, -28, south_open=[(-3.5, 3.5, 1.3, 5.3)], north_open=[(-11.5, -3.5, 0, 5)])
# Поезд на правом пути — укрытие и преграда.
L.box("Geometry", "Train", (7, 0.7, -50), (4.8, 3.4, 32), "train")
L.box("Props", "TrainStripe", (4.57, 0.2, -50), (0.06, 0.25, 32), "train_stripe", collide=False)
for zc in range(-64, -35, 4):
    L.box("Props", "TrainWindow", (4.56, 1.3, zc), (0.06, 0.9, 2.2), "dark_glass", collide=False)
L.box("Props", "TrainFront", (7, 1.2, -65.98), (3.6, 1.0, 0.06), "lamp_cold", collide=False)
for zc in (-60, -50, -40):
    L.lamp((0, 6.9, zc), 1.6, 12, mat="lamp_cold", color="Color(0.85, 0.92, 1, 1)", size=(0.4, 0.08, 4))
L.lamp((-7.5, 4.5, -66), 0.9, 8)
L.label("ПОДЗЕМНАЯ", (-10.9, 3.5, -50), yaw=90, size=96, color="Color(0.15, 0.2, 0.35, 1)")
L.label("ПОДЗЕМНАЯ", (10.9, 4.5, -50), yaw=-90, size=96, color="Color(0.15, 0.2, 0.35, 1)")
L.pickup("health", (-3, 0, -35))
L.pickup("ammo", (3, 0, -69))
L.enemy("gunner", (-2.6, 0, -45), look_at=(0, 0, -28))
L.enemy("gunner", (2.6, 0, -53), look_at=(0, 0, -28))
L.enemy("gunner", (0.5, 0, -64), look_at=(0, 0, -28))
L.enemy("gunner", (7, 2.4, -42), look_at=(0, 0, -28))
L.enemy("rusher", (-7.5, TRACK, -60), look_at=(-7.5, TRACK, -28))
L.wave_zone("ZonePlatform", (0, 1, -54), (22, 5, 16),
            spawns=[(-7.5, TRACK + 0.1, -70), (-7.5, TRACK + 0.1, -30), (7.5, TRACK + 0.1, -69.5),
                    (7.5, TRACK + 0.1, -30)],
            barriers=[((0, 2, -27.85), (7.4, 4, 0.3)), ((-7.5, 1.2, -72.15), (8.4, 5, 0.3))],
            title="Засада на платформе!", waves=2, first=5, extra=2, rusher=0.3)

# T1 — тоннель по левому пути
L.room("T1Tunnel", -11, -4, -112, -72, TRACK, 5, "gravel", "concrete", "concrete_dark",
       sides={"N": False, "S": False})
for x in (-8.5, -6.5):
    L.box_ext("Props", "Rail", x - 0.06, x + 0.06, TRACK, TRACK + 0.15, -112, -72, "rail", collide=False,
              shadow=False)
L.box("Props", "Cables", (-10.85, 2.4, -92), (0.12, 0.3, 40), "rubber", collide=False)
L.box("Props", "Trolley", (-6.5, TRACK + 0.6, -88), (2.2, 1.2, 3), "metal")
L.box("Props", "Niche", (-11.2, TRACK + 1.2, -84), (0.6, 2.4, 2), "concrete_dark", collide=False)
L.lamp((-7.5, TRACK + 4.9, -80), 1.0, 8, mat="lamp_red", color="Color(1, 0.35, 0.3, 1)", size=(0.3, 0.1, 0.3))
L.lamp((-7.5, TRACK + 4.9, -92), 1.1, 9)
L.lamp((-7.5, TRACK + 4.9, -104), 1.0, 8, mat="lamp_green", color="Color(0.4, 1, 0.5, 1)", size=(0.3, 0.1, 0.3))
L.pickup("health", (-10.2, TRACK, -84))
L.enemy("gunner", (-9.5, TRACK, -100), look_at=(-7.5, TRACK, -72))
L.enemy("gunner", (-5.5, TRACK, -106), look_at=(-7.5, TRACK, -72))
L.enemy("rusher", (-7.5, TRACK, -94), look_at=(-7.5, TRACK, -72))

# P2 — станция «Конечная». Дальше путь идёт по правому пути в депо.
platform_hall("P2Station", -152, -112, south_open=[(-11.5, -3.5, 0, 5)], north_open=[(3.5, 11.5, 0, 5)])
# Служебный пандус с путей на платформу.
L.ramp_x("Geometry", "ServiceRamp", -119, -116, -9.5, TRACK, -4, 0, "metal")
L.box("Props", "RampSign", (-4.3, 1.4, -117.5), (0.1, 0.5, 1.2), "hazard", collide=False)
for zc in (-140, -128, -118):
    L.lamp((0, 6.9, zc), 1.6, 12, mat="lamp_cold", color="Color(0.85, 0.92, 1, 1)", size=(0.4, 0.08, 4))
L.label("КОНЕЧНАЯ", (-10.9, 3.5, -132), yaw=90, size=96, color="Color(0.35, 0.12, 0.12, 1)")
L.label("КОНЕЧНАЯ", (10.9, 4.5, -132), yaw=-90, size=96, color="Color(0.35, 0.12, 0.12, 1)")
L.label("В ДЕПО", (7.5, 4.3, -151.9), size=64, color="Color(0.9, 0.85, 0.6, 1)")
L.pickup("ammo", (-3, 0, -121))
L.pickup("health", (3, 0, -147))
L.enemy("gunner", (2.6, 0, -126), look_at=(0, 0, -112))
L.enemy("gunner", (-2.6, 0, -139), look_at=(0, 0, -112))
L.enemy("heavy", (0, 0, -149), look_at=(0, 0, -112))
L.enemy("rusher", (7.5, TRACK, -125), look_at=(0, 0, -112))
L.wave_zone("ZoneTerminal", (0, 1, -134), (22, 5, 16),
            spawns=[(-7.5, TRACK + 0.1, -150), (7.5, TRACK + 0.1, -150), (7.5, TRACK + 0.1, -114),
                    (0, 0.1, -150.5)],
            barriers=[((-7.5, 1.2, -111.85), (8.4, 5, 0.3)), ((7.5, 1.2, -152.15), (8.4, 5, 0.3))],
            title="Они перекрыли станцию!", waves=2, first=5, extra=2, rusher=0.35, heavy=1)

# T2 — тоннель в депо
L.room("T2Tunnel", 4, 11, -200, -152, TRACK, 5, "gravel", "concrete", "concrete_dark", sides={"N": False, "S": False})
for x in (6.5, 8.5):
    L.box_ext("Props", "Rail", x - 0.06, x + 0.06, TRACK, TRACK + 0.15, -200, -152, "rail", collide=False, shadow=False)
L.box("Props", "Cables", (10.85, 2.4, -176), (0.12, 0.3, 48), "rubber", collide=False)
L.box("Props", "Trolley", (5.4, TRACK + 0.6, -172), (1.6, 1.2, 3), "metal")
L.box("Props", "Barrier", (9.6, TRACK + 0.5, -186), (1.8, 1.0, 0.4), "hazard")
L.lamp((7.5, TRACK + 4.9, -162), 1.0, 8, mat="lamp_red", color="Color(1, 0.35, 0.3, 1)", size=(0.3, 0.1, 0.3))
L.lamp((7.5, TRACK + 4.9, -176), 1.1, 9)
L.lamp((7.5, TRACK + 4.9, -190), 1.0, 8, mat="lamp_green", color="Color(0.4, 1, 0.5, 1)", size=(0.3, 0.1, 0.3))
L.enemy("gunner", (5.2, TRACK, -178), look_at=(7.5, TRACK, -152))
L.enemy("rusher", (8.5, TRACK, -184), look_at=(7.5, TRACK, -152))
L.enemy("gunner", (9.8, TRACK, -195), look_at=(7.5, TRACK, -152))

# D1 — электродепо: два поезда, между ними — проход (волны 3)
L.room("D1Depot", -14, 26, -252, -200, TRACK, 9, "gravel", "concrete", "concrete_dark",
       openings={"S": [(3.5, 11.5, 0, 5)], "N": [(3.5, 11.5, 0, 5)]})
for x0, x1 in ((-9, -4), (15, 20)):
    L.box_ext("Geometry/D1Depot", "Train", x0, x1, TRACK + 0.3, TRACK + 3.7, -246, -206, "train")
    side = x1 + 0.03 if x0 < 0 else x0 - 0.03
    L.box_ext("Props", "TrainStripe", side - 0.03, side + 0.03, TRACK + 0.9, TRACK + 1.15, -246, -206, "train_stripe",
              collide=False)
    for zc in range(-242, -208, 4):
        L.box("Props", "TrainWindow", (side, TRACK + 2.3, zc), (0.06, 0.9, 2.2), "dark_glass", collide=False)
    for x in (x0 + 1, x1 - 1):
        L.box_ext("Props", "Rail", x - 0.06, x + 0.06, TRACK, TRACK + 0.15, -252, -200, "rail", collide=False,
                  shadow=False)
for x in (6.5, 8.5):
    L.box_ext("Props", "Rail", x - 0.06, x + 0.06, TRACK, TRACK + 0.15, -252, -200, "rail", collide=False, shadow=False)
for z in (-212, -228, -244):
    L.box_ext("Props", "Gantry", -14, 26, TRACK + 7.3, TRACK + 7.7, z - 0.3, z + 0.3, "hazard", collide=False)
for x, z in ((1, -214), (13, -236), (0.5, -240), (12.5, -218)):
    L.box("Props", "Crate", (x, TRACK + 0.6, z), (1.4, 1.2, 1.4), "crate")
for x, z in ((-12, -230), (24, -212), (24, -244)):
    L.cylinder("Props", "Barrel", (x, TRACK + 0.55, z), 0.4, 1.1, "rust")
for x, z in ((-1, -212), (16, -224), (-1, -238), (16, -246)):
    L.lamp((x, TRACK + 8.9, z), 1.6, 14, mat="lamp_cold", color="Color(0.85, 0.92, 1, 1)", size=(0.4, 0.08, 4))
L.label("ЭЛЕКТРОДЕПО", (7.5, TRACK + 6.3, -251.9), size=96, color="Color(0.9, 0.85, 0.6, 1)")
L.pickup("health", (-12, TRACK, -222))
L.pickup("ammo", (24, TRACK, -228))
L.pickup("ammo", (5, TRACK, -204))
L.enemy("gunner", (-6.5, TRACK + 3.7, -216), look_at=(7.5, 0, -200))
L.enemy("gunner", (17.5, TRACK + 3.7, -232), look_at=(7.5, 0, -200))
L.enemy("gunner", (0, TRACK, -246), look_at=(7.5, 0, -200))
L.enemy("gunner", (12.5, TRACK, -248), look_at=(7.5, 0, -200))
L.enemy("rusher", (-1, TRACK, -222), look_at=(7.5, 0, -200))
L.enemy("rusher", (13, TRACK, -208), look_at=(7.5, 0, -200))
L.enemy("heavy", (7.5, TRACK, -249), look_at=(7.5, 0, -200))
L.wave_zone("ZoneDepot", (7.5, 1, -226), (18, 6, 24),
            spawns=[(-12, TRACK + 0.1, -250), (24, TRACK + 0.1, -250), (-12, TRACK + 0.1, -202),
                    (24, TRACK + 0.1, -202), (-6.5, TRACK + 3.8, -240), (17.5, TRACK + 3.8, -212)],
            barriers=[((7.5, 1.2, -199.85), (8.4, 5, 0.3)), ((7.5, 1.2, -252.15), (8.4, 5, 0.3))],
            title="Засада в депо!", waves=2, first=6, extra=2, rusher=0.3, heavy=1)

# X2 — подъём в город
L.room("X2Exit", 4, 11, -272, -252, TRACK, 9, "floor_tiles", "tiles_wall", "ceiling", sides={"S": False})
L.ramp_z("Geometry/X2Exit", "Stairs", 4, 11, -253, TRACK, -265, 4.2, "concrete")
L.box_ext("Geometry/X2Exit", "Landing", 4, 11, TRACK, 4.2, -272, -265, "floor_tiles")
L.lamp((7.5, TRACK + 8.9, -260), 1.4, 11)
L.enemy("gunner", (10, 4.2, -270), look_at=(7.5, 0, -252))
L.exit((7.5, 5.7, -269), (6, 3, 4), (7.5, 6.6, -271.8), "ВЫХОД В ГОРОД")

L.waypoint((0, 6, -2), (0, 6, -13), (0, 6, -14.5), (0, 0, -26), (0, 0, -29), (0, 0, -66), (-1.5, 0, -70.5),
           (-4.3, 0, -70.5), (-6, TRACK, -71), (-7.5, TRACK, -73), (-7.5, TRACK, -85), (-8.8, TRACK, -88),
           (-8.8, TRACK, -92), (-7.5, TRACK, -96), (-7.5, TRACK, -111), (-8, TRACK, -117.5), (-9.3, TRACK, -117.5),
           (-4.5, 0, -117.5), (0, 0, -120), (0, 0, -148), (4.3, 0, -148), (6.5, TRACK, -149), (7.5, TRACK, -153),
           (7.5, TRACK, -199), (7.5, TRACK, -201), (7.5, TRACK, -251), (7.5, TRACK, -253.5), (7.5, 4.2, -265.5),
           (7.5, 4.2, -269))

env = [
    ("Environment", "Env_2", {
        "background_mode": "1", "background_color": "Color(0.01, 0.012, 0.015, 1)",
        "ambient_light_source": "2", "ambient_light_color": "Color(0.4, 0.42, 0.5, 1)",
        "ambient_light_energy": "0.52", "tonemap_mode": "2",
        "fog_enabled": "true", "fog_light_color": "Color(0.03, 0.035, 0.045, 1)", "fog_density": "0.016",
    }),
]
L.node("WorldEnvironment", "WorldEnvironment", ".", environment='SubResource("Env_2")')
# Взрывоопасные бочки и баллоны (места подобраны у стен рядом с постами врагов).
L.explosives([(-4.2, 6, -13.5), (-2.4, 0, -27.99), (3.99, 0, -52.43), (-10.1, -1.3, -60), (-4.44, -1.3, -104.94), (2.6, 0, -128.6), (-0.99, 0, -151.4), (4.43, -1.3, -176.15), (10.57, -1.3, -193.15), (-3.4, -1.3, -221.01), (10.57, 4.2, -268.61)])

L.write("scenes/levels/level_2_metro.tscn", env, ["pistol", "shotgun"])
