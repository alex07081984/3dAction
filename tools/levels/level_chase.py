"""Уровень «Шоссе» (дорога между городами): погоня. Машина героя стоит на месте,
а дорога, разметка и пейзаж несутся мимо (scripts/chase_level.gd + travel_level.gd).
Здесь — кабриолет героя с водителем, полотно с отбойниками и вертолёт банды для финала."""
from levelkit import Level, xform, rot_x, rot_y, rot_z, f, yaw_to
import math

L = Level("LevelChase", {
    "level_index": "-1",
    "title": '"Шоссе"',
    "objective": '"Оторвитесь от погони банды"',
})
for g in ("Geometry", "Lights", "Props", "Enemies", "Pickups"):
    L.group(g)

ROAD = 9.0

# Полотно: невидимая твёрдая «земля» (на неё падают гранаты, ракеты, обломки),
# сплошные линии по краям и отбойники (они одинаковые по всей длине — движение не нужно).
L.invisible_wall("Geometry", "RoadBody", (0, -0.5, -100), (80, 1, 700))
L.section = "Road"
for x in (-ROAD + 0.35, ROAD - 0.35):
    L.box_ext("Props", "EdgeLine", x - 0.1, x + 0.1, 0.0, 0.03, -360, 160, "white_paint", collide=False, shadow=False)
for x in (-ROAD - 0.3, ROAD + 0.3):
    L.box_ext("Props", "Guardrail", x - 0.08, x + 0.08, 0.55, 0.85, -360, 160, "metal", collide=False, shadow=False)

# Кабриолет героя: напарник за рулём, герой стоит на заднем сиденье.
car = L.node("PlayerCar", "Node3D", ".")
L.combiner("PlayerCar/Body", False)
B = "PlayerCar/Body"
for name, center, size, mat in (
        ("Floor", (0, 0.55, 0), (2.0, 0.5, 4.6), "car_red"),
        ("SideL", (-0.95, 1.0, 0), (0.12, 0.5, 4.6), "car_red"),
        ("SideR", (0.95, 1.0, 0), (0.12, 0.5, 4.6), "car_red"),
        ("Hood", (0, 0.95, -1.65), (2.0, 0.35, 1.3), "car_red"),
        ("Trunk", (0, 0.95, 1.85), (2.0, 0.35, 0.9), "car_red"),
        ("Windshield", (0, 1.45, -0.95), (1.8, 0.55, 0.06), "dark_glass"),
        ("FrontSeat", (0, 0.95, -0.2), (1.7, 0.45, 0.6), "sofa"),
        ("FrontBack", (0, 1.25, 0.15), (1.7, 0.6, 0.15), "sofa"),
        ("RearSeat", (0, 0.95, 1.0), (1.7, 0.45, 0.7), "sofa"),
        ("WheelsF", (0, 0.38, -1.4), (2.08, 0.76, 0.76), "black_metal"),
        ("WheelsR", (0, 0.38, 1.45), (2.08, 0.76, 0.76), "black_metal"),
        ("Bumper", (0, 0.5, -2.35), (2.0, 0.25, 0.15), "metal"),
        ("Grille", (0, 0.75, -2.32), (1.2, 0.3, 0.05), "metal")):
    L.box(B, name, center, size, mat, collide=False)
for x in (-0.7, 0.7):
    L.box("PlayerCar", "Headlight", (x, 0.85, -2.33), (0.35, 0.2, 0.05), "lamp", collide=False, shadow=False)
    L.box("PlayerCar", "Taillight", (x, 0.95, 2.31), (0.35, 0.18, 0.05), "lamp_red", collide=False, shadow=False)
L.node("Beam", "SpotLight3D", "PlayerCar", transform=xform((0, 1.0, -2.4), rot_x(-0.12)),
       light_color="Color(1, 0.95, 0.8, 1)", light_energy="4.0", spot_range="45.0", spot_angle="28.0")
L.node("Driver", "Node3D", "PlayerCar", transform=xform((-0.45, 0.35, -0.2)),
       script=L.ext_res("Script", "res://scripts/blocky_character.gd"), outfit='"suit"', hat='"fedora"',
       weapon='""', jacket_color="Color(0.25, 0.25, 0.27, 1)", hat_color="Color(0.15, 0.15, 0.16, 1)")
L.node("Seat", "Marker3D", "PlayerCar", transform=xform((0.45, 1.17, 1.0)))

# Вертолёт банды — финал погони (вылетает после трёх волн).
L.node("ChaseHeli", "CharacterBody3D", ".", transform=xform((40, 60, 200)),
       script=L.ext_res("Script", "res://scripts/attack_helicopter.gd"), boss_name='"Вертолёт банды"',
       phases="2", phase_health="700.0", reward="600", orbit_radius="26.0")

# Далёкие горы по горизонту.
L.section = "Far"
for i in range(14):
    side = -1 if i % 2 == 0 else 1
    z = -900 + i * 120
    h = 60 + (i * 37) % 80
    L.box("Props", "FarHill", (side * (440 + (i * 53) % 120), h / 2 - 20, z), (180, h, 200), "rock",
          collide=False, shadow=False, rows=rot_y((i * 17) % 40 - 20))

L.player((0.45, 1.17, 1.0), 0)
L.waypoint((0.45, 1.17, 1.0))

MOON_YAW, MOON_PITCH = 200, -34
moon_dir = (math.sin(math.radians(MOON_YAW)) * math.cos(math.radians(MOON_PITCH)), -math.sin(math.radians(MOON_PITCH)),
            math.cos(math.radians(MOON_YAW)) * math.cos(math.radians(MOON_PITCH)))
env = [
    ("ShaderMaterial", "SkyMat_C", {
        "shader": L.ext_res("Shader", "res://materials/night_sky.gdshader"),
        "shader_parameter/moon_direction": f"Vector3({f(moon_dir[0])}, {f(moon_dir[1])}, {f(moon_dir[2])})",
        "shader_parameter/horizon_color": "Color(0.15, 0.15, 0.19, 1)",
    }),
    ("Sky", "Sky_C", {"sky_material": 'SubResource("SkyMat_C")'}),
    ("Environment", "Env_C", {
        "background_mode": "2", "sky": 'SubResource("Sky_C")',
        "ambient_light_source": "2", "ambient_light_color": "Color(0.4, 0.43, 0.55, 1)",
        "ambient_light_energy": "0.85", "tonemap_mode": "2",
        "fog_enabled": "true", "fog_light_color": "Color(0.14, 0.15, 0.19, 1)", "fog_density": "0.006",
        "fog_sky_affect": "0.3",
    }),
]
L.node("WorldEnvironment", "WorldEnvironment", ".", environment='SubResource("Env_C")')
mx = [[sum(a * b for a, b in zip(r, c)) for c in zip(*rot_x(math.radians(MOON_PITCH)))] for r in rot_y(MOON_YAW)]
L.node("Moonlight", "DirectionalLight3D", ".", transform=xform((0, 60, 0), mx),
       light_color="Color(0.65, 0.72, 1, 1)", light_energy="0.5", shadow_enabled="true",
       directional_shadow_max_distance="60.0", directional_shadow_mode="1")
L.write("scenes/levels/level_chase.tscn", env, ["pistol", "shotgun", "magnum", "rifle"],
        script_path="res://scripts/chase_level.gd")
