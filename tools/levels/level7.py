"""Уровень 7 «Казино» (эпизод 2): улица с неоновой вывеской, лобби, игорный зал,
хранилище и VIP-зал на втором этаже, где ждёт босс Крупье."""
from levelkit import Level, xform, rot_x, rot_y, rot_z, f, yaw_to
import math
import random

random.seed(7)
L = Level("Level7Casino", {
    "level_index": "6",
    "title": '"Казино"',
    "objective": '"Доберитесь до Крупье в VIP-зале"',
})
for g in ("Geometry", "Lights", "Props", "Enemies", "Pickups"):
    L.group(g)

WARM = "Color(1, 0.8, 0.55, 1)"
RED = "Color(1, 0.25, 0.2, 1)"
DOOR = 3.5


def table(x, z, felt="awning_green", y=0.0):
    L.box("Props", "Table", (x, y + 0.4, z), (3.0, 0.8, 1.8), "wood")
    L.box("Props", "Felt", (x, y + 0.82, z), (2.8, 0.05, 1.6), felt, collide=False, shadow=False)


# Улица перед казино
L.room("CStreet", -20, 20, -14, 0, 0, 4, "asphalt", "brick", None, openings={"N": [(-3, 3, DOOR)]})
L.box_ext("Props", "Facade", -12, 12, 6, 11, -14.6, -14.0, "brick")
L.label("ФОРТУНА", (0, 8.2, -13.3), size=180, color=RED)
L.label("КАЗИНО", (0, 10.1, -13.3), size=72, color="Color(1, 0.85, 0.4, 1)")
for x, mat in ((-12, "car_black"), (13, "car_red")):
    L.box("Props", "Car", (x, 0.75, -6), (4.4, 1.5, 2.0), mat)
for x in (-6, 6):
    L.cylinder("Props", "Post", (x, 2.5, -2), 0.1, 5, "black_metal")
    L.box("Props", "PostLamp", (x, 5.1, -2), (0.5, 0.25, 0.4), "lamp", collide=False)
    L.node("Light", "OmniLight3D", "Lights", transform=xform((x, 4.8, -2)), light_color=WARM, light_energy="1.6",
           omni_range="12")
L.node("Neon", "OmniLight3D", "Lights", transform=xform((0, 8, -12)), light_color=RED, light_energy="2.5",
       omni_range="14")
L.enemy("gunner", (-8, 0, -11), look_at=(0, 0, 0))
L.enemy("gunner", (8, 0, -11), look_at=(0, 0, 0))
L.enemy("rusher", (-15, 0, -9), look_at=(0, 0, 0))

# Лобби
L.room("CLobby", -12, 12, -34, -14, 0, 6, "marble", "wallpaper", "ceiling",
       openings={"S": [(-3, 3, DOOR)], "N": [(-4, 4, 4)]})
L.box("Props", "Reception", (8, 0.55, -22), (6, 1.1, 1.2), "marble")
for x in (-6, 6):
    for z in (-18, -30):
        L.box("Props", "Column", (x, 3, z), (0.9, 6, 0.9), "gold")
L.box("Props", "Chandelier", (0, 5.5, -24), (2.0, 0.6, 2.0), "gold", collide=False)
L.node("Light", "OmniLight3D", "Lights", transform=xform((0, 5, -24)), light_color=WARM, light_energy="1.5",
       omni_range="16")
L.pickup("health", (-10.5, 0, -16))
L.enemy("gunner", (8, 0, -23.5), look_at=(0, 0, -14))
L.enemy("gunner", (-9, 0, -31), look_at=(0, 0, -14))
L.enemy("rusher", (-4, 0, -27), look_at=(0, 0, -14))

# Игорный зал
L.room("CHall", -24, 24, -84, -34, 0, 8, "red_carpet", "wallpaper", "ceiling",
       openings={"S": [(-4, 4, 4)], "N": [(-3, 3, DOOR)]})
for x in (-8, 8, -16, 16):
    for z in (-42, -76):
        table(x, z)
for x in (-8, 8):
    L.cylinder("Props", "Roulette", (x, 0.45, -59), 1.3, 0.9, "wood", sides=16)
    L.cylinder("Props", "Wheel", (x, 0.93, -59), 0.8, 0.06, "gold", collide=False, sides=16)
for x in (-16, 16):
    table(x, -59, felt="red_carpet")
for side in (-1, 1):
    L.box_ext("Props", "Slots", side * 22.2 - 0.5, side * 22.2 + 0.5, 0, 1.9, -80, -38, "monitor")
    L.box_ext("Props", "SlotLights", side * 22.2 - 0.5, side * 22.2 + 0.5, 1.9, 2.05, -80, -38, "lamp_red",
              collide=False, shadow=False)
for x in (-5, 5):
    for z in (-46, -70):
        L.box("Props", "Column", (x, 4, z), (0.9, 8, 0.9), "gold")
for x in (-12, 12):
    for z in (-46, -70):
        L.box("Props", "Chandelier", (x, 7.5, z), (2.2, 0.7, 2.2), "gold", collide=False)
        L.node("Light", "OmniLight3D", "Lights", transform=xform((x, 7, z)), light_color=WARM, light_energy="2.0",
               omni_range="16")
L.lamp((0, 7.9, -58), 1.6, 14, color=WARM, mat="gold", size=(1.2, 0.2, 1.2))
L.pickup("health", (-20, 0, -38))
L.pickup("ammo", (20, 0, -81))
L.pickup("grenade", (-20, 0, -81))
L.enemy("gunner", (8, 0, -44.5), look_at=(0, 0, -34))
L.enemy("gunner", (-8, 0, -78.5), look_at=(0, 0, -34))
L.enemy("rusher", (12, 0, -66), look_at=(0, 0, -34))
L.enemy("rusher", (-12, 0, -50), look_at=(0, 0, -34))
L.enemy("gunner", (-19.5, 0, -64), look_at=(0, 0, -50))
L.enemy("gunner", (19.5, 0, -52), look_at=(0, 0, -40))
L.enemy("heavy", (0, 0, -81), look_at=(0, 0, -34))
L.wave_zone("ZoneHall", (0, 2, -60), (44, 4, 44),
            spawns=[(-20, 0.1, -36), (20, 0.1, -36), (-20, 0.1, -82), (20, 0.1, -82)],
            barriers=[((0, 2, -34.15), (8.4, 4, 0.3)), ((0, 1.75, -83.85), (6.4, 3.5, 0.3))],
            title="Перестрелка в зале!", waves=2, first=6, extra=2, rusher=0.35, heavy=1)

# Хранилище и счётная комната
L.room("CVault", -10, 10, -110, -84, 0, 4.5, "concrete", "metal", "ceiling",
       openings={"S": [(-3, 3, DOOR)], "N": [(-3, 3, DOOR)]})
L.cylinder("Props", "VaultDoor", (-9.7, 2, -97), 1.6, 0.4, "metal", collide=False, rows=rot_z(math.pi / 2), sides=20)
L.box_ext("Props", "Deposit", 9.2, 10, 0, 3, -108, -86, "gold")
for z in (-92, -102):
    L.box("Props", "CountTable", (5.5, 0.45, z), (3, 0.9, 1.6), "wood")
    L.box("Props", "Money", (5.5, 1.0, z), (2.6, 0.2, 1.2), "awning_green", collide=False, shadow=False)
for z in (-90, -104):
    L.lamp((0, 4.4, z), 1.4, 10, mat="lamp_cold", color="Color(0.95, 0.97, 1, 1)")
L.pickup("health", (-8.5, 0, -100))
L.pickup("ammo", (8, 0, -108))
L.enemy("gunner", (5.5, 0, -94.5), look_at=(0, 0, -84))
L.enemy("gunner", (-6, 0, -104), look_at=(0, 0, -84))
L.enemy("rusher", (-7, 0, -90), look_at=(0, 0, -84))
L.enemy("heavy", (0, 0, -108), look_at=(0, 0, -84))
L.wave_zone("ZoneVault", (0, 2, -97), (18, 4, 24),
            spawns=[(-8.5, 0.1, -86), (8, 0.1, -86), (-8.5, 0.1, -108), (8, 0.1, -108)],
            barriers=[((0, 1.75, -84.15), (6.4, 3.5, 0.3)), ((0, 1.75, -109.85), (6.4, 3.5, 0.3))],
            title="Хранилище!", waves=2, first=4, extra=2, rusher=0.3, heavy=1)

# Лестница в VIP-зал (с 0 на 5)
L.room("CStairs", -3, 3, -126, -110, 0, 10.5, "marble", "wallpaper", "ceiling",
       openings={"S": [(-3.5, 3.5, 0, 4.9)], "N": [(-3.5, 3.5, 5, 9)]})
L.ramp_z("Geometry/CStairs", "Ramp", -3, 3, -111, 0, -123, 5, "red_carpet")
L.box_ext("Geometry/CStairs", "Landing", -3, 3, 0, 5, -126, -123, "marble")
L.lamp((0, 10.4, -118), 1.3, 11, color=WARM)

# VIP-зал — логово Крупье
VIP = 5
L.room("CVip", -16, 16, -160, -126, VIP, 6, "red_carpet", "wallpaper", "ceiling",
       openings={"S": [(-3, 3, 4)]}, windows={"N": (1.0, 5.0)})
table(0, -146, y=VIP)
for x in (-11, 11):
    for z in (-132, -152):
        L.box("Props", "Sofa", (x, VIP + 0.45, z), (4, 0.9, 1.4), "sofa")
L.box("Props", "Piano", (-12.5, VIP + 0.6, -142), (1.6, 1.2, 2.2), "car_black")
L.box_ext("Props", "Bar", 12, 13.2, VIP, VIP + 1.1, -146, -134, "wood")
for x in (-6, 6):
    for z in (-136, -154):
        L.box("Props", "Column", (x, VIP + 3, z), (0.8, 6, 0.8), "gold")
for x, z in ((-8, -138), (8, -150), (0, -132)):
    L.lamp((x, VIP + 5.9, z), 1.5, 12, mat="gold", color="Color(1, 0.6, 0.45, 1)", size=(0.9, 0.2, 0.9))
L.pickup("health", (-14.5, VIP, -128))
L.pickup("ammo", (14.5, VIP, -128))
L.pickup("grenade", (-14.5, VIP, -158))
L.enemy("gunner", (-10, VIP, -136), look_at=(0, VIP, -126))
L.enemy("gunner", (10, VIP, -140), look_at=(0, VIP, -126))
L.boss("croupier", "Croupier", (0, VIP, -155.5), (0, VIP, -126),
       henchman_points='NodePath("../../BossSpawns")')
L.markers("BossSpawns", [(f"Spawn{i}", p, 0) for i, p in enumerate((
    (-14, VIP, -129), (14, VIP, -129), (-14, VIP, -157), (14, VIP, -157), (0, VIP, -124.5)))])

# Ночной город за окнами VIP-зала
L.section = "Outdoor"
for i in range(12):
    x = -90 + i * 16 + random.uniform(-4, 4)
    w, d = random.uniform(10, 18), random.uniform(10, 18)
    L.box_ext("Props", "Skyline", x - w / 2, x + w / 2, -20, random.uniform(20, 60), -260 - d, -200, "skyline",
              collide=False, shadow=False)

L.player((0, 0, -3), 0)
L.waypoint((0, 0, -3), (0, 0, -13), (0, 0, -15), (0, 0, -33), (0, 0, -35), (0, 0, -83), (0, 0, -85),
           (0, 0, -109), (0, 0, -111), (0, VIP, -123), (0, VIP, -125), (0, VIP, -127), (0, VIP, -140))

env = [
    ("Environment", "Env_7", {
        "background_mode": "1", "background_color": "Color(0.01, 0.01, 0.02, 1)",
        "ambient_light_source": "2", "ambient_light_color": "Color(0.42, 0.36, 0.38, 1)",
        "ambient_light_energy": "0.55", "tonemap_mode": "2",
        "fog_enabled": "true", "fog_light_color": "Color(0.05, 0.03, 0.04, 1)", "fog_density": "0.012",
    }),
]
L.node("WorldEnvironment", "WorldEnvironment", ".", environment='SubResource("Env_7")')
L.explosives([(-15, 0, -4), (15, 0, -11.5), (-11, 0, -21), (-19.5, 0, -42), (19.5, 0, -70), (-14.5, 0, -66),
              (-8.5, 0, -95), (-14.5, VIP, -150)], pattern="BCB")
L.explosives([(14.4, VIP, -138), (14.4, VIP, -142)], pattern="C")
L.write("scenes/levels/level_7_casino.tscn", env, ["pistol", "shotgun", "deagle", "rifle"])
