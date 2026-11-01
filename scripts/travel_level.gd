class_name TravelLevel
extends Level
## Дорога между городами (поезд и погоня по шоссе). Сам поезд или машина стоит на месте, а мир несётся мимо:
## земля и шпалы прокручиваются, деревья, столбы, кактусы и дома проезжают назад.
## Пейзаж зависит от маршрута (Нью-Йорк ⇄ Сан-Франциско: окраины, прерии, пустыня, горы;
## Сан-Франциско ⇄ Аляска: побережье, тайга, снег; Аляска ⇄ Нью-Йорк: снег, тайга, озёра, окраины).
## В горах и тайге бывают тоннели: кто стоит на крыше вагона, того сбивает.
## Цель — пробиться через вагоны к паровозу; в конце — город назначения.

const AHEAD := -320.0  ## Где появляются предметы пейзажа (впереди поезда).
const BEHIND := 140.0  ## Где исчезают (позади).
const ROW := 9.0  ## Шаг рядов пейзажа.
const ROOF_Y := 4.4  ## Высота крыш вагонов (кто выше — того сбивает тоннелем).
const BIOME_TIME := 40.0  ## Сколько секунд длится каждый участок пути.

const ROUTES := {
	"1-2": ["city", "prairie", "desert", "mountains"],
	"2-3": ["coast", "forest", "snow"],
	"1-3": ["city", "lakes", "forest", "snow"],
}
const BIOMES := {
	"city": {"ground": "asphalt", "tint": Color(0.55, 0.55, 0.58), "props": [["building", 0.55, 14, 60], ["pole", 0.25, 5, 5]]},
	"prairie": {"ground": "grass", "tint": Color(0.75, 0.8, 0.55), "props": [["tree", 0.3, 10, 90], ["house", 0.07, 18, 70], ["pole", 0.25, 5, 5]]},
	"desert": {"ground": "gravel", "tint": Color(0.95, 0.8, 0.55), "props": [["cactus", 0.35, 8, 80], ["rock", 0.25, 10, 110], ["pole", 0.25, 5, 5]]},
	"mountains": {"ground": "gravel", "tint": Color(0.6, 0.6, 0.62), "tunnels": true, "props": [["rock", 0.45, 9, 90], ["pine", 0.35, 10, 80], ["pole", 0.25, 5, 5]]},
	"coast": {"ground": "grass", "tint": Color(0.6, 0.72, 0.5), "water": true, "props": [["rock", 0.3, 8, 60], ["pine", 0.3, 9, 70]]},
	"forest": {"ground": "grass", "tint": Color(0.35, 0.5, 0.3), "tunnels": true, "props": [["pine", 0.8, 8, 90], ["pole", 0.25, 5, 5]]},
	"lakes": {"ground": "grass", "tint": Color(0.45, 0.6, 0.4), "water": true, "props": [["pine", 0.55, 9, 90], ["house", 0.05, 15, 50]]},
	"snow": {"ground": "snow", "tint": Color(0.92, 0.94, 1.0), "tunnels": true, "snow": true, "props": [["snow_pine", 0.75, 8, 90], ["rock", 0.15, 10, 80], ["pole", 0.25, 5, 5]]},
}
const BIOME_NAMES := {
	"city": "Окраины", "prairie": "Прерии", "desert": "Пустыня", "mountains": "Скалистые горы",
	"coast": "Тихоокеанское побережье", "forest": "Тайга", "lakes": "Великие озёра", "snow": "Снега Аляски",
}

## Скорость, ширина полотна (половина), сдвиг пейзажа от дороги, текстура полотна — у поезда и
## машины свои (наследники меняют их до super._ready()).
var speed := 24.0
var road_half := 4.0
var side_offset := 0.0
var track_texture := "res://textures/wood.png"
var track_tint := Color(0.35, 0.3, 0.26)
var sound_name := "train"
var front_z := -132.0  ## Передний край поезда: отсюда тоннель начинает накрывать состав.
var tunnel_warning := ["ТОННЕЛЬ!", "Спуститесь с крыши в вагон!"]
var title_prefix := "Поезд"

var _route: Array = []
var _biome := ""
var _biome_index := -1
var _biome_left := 0.0
var _props: Array = []  # {"type", "pos": Vector3, "yaw", "scale"}
var _multimeshes := {}  # тип -> MultiMeshInstance3D
var _row_acc := 0.0
var _ground_left: StandardMaterial3D
var _ground_right: StandardMaterial3D
var _track: StandardMaterial3D
var _water: MeshInstance3D
var _tunnel: Node3D
var _tunnel_cooldown := 20.0
var _tunnel_warned := false
var _tunnel_front_prev := -INF
var _tunnel_hits := {}
var _dust: CPUParticles3D
var _sound: AudioStreamPlayer
var _environment: Environment
var _base_ambient := 0.7


func _ready() -> void:
	var key := Game.route_key(Game.travel_from, Game.travel_to)
	_route = (ROUTES.get(key, ROUTES["1-2"]) as Array).duplicate()
	if Game.travel_from > Game.travel_to:
		_route.reverse()
	title = "%s: %s → %s" % [title_prefix, Game.city_name(Game.travel_from), Game.city_name(Game.travel_to)]
	super._ready()
	var world := get_node_or_null("WorldEnvironment") as WorldEnvironment
	if world:
		_environment = world.environment
		_base_ambient = _environment.ambient_light_energy
	_build_ground()
	_build_prop_meshes()
	_build_tunnel()
	_build_dust()
	_set_biome(0)
	# Заполняем пейзаж от горизонта до хвоста поезда.
	var z := BEHIND
	while z > AHEAD:
		_spawn_row(z)
		z -= ROW
	_update_multimeshes()
	_start_sound()


## Текущий участок пути: city, prairie, desert, mountains, coast, forest, lakes, snow.
func get_biome() -> String:
	return _biome


func get_route() -> Array:
	return _route


func get_prop_count() -> int:
	return _props.size()


## Первый предмет пейзажа (для тестов: проверить, что он едет назад).
func get_prop_position(index: int) -> Vector3:
	return _props[index].pos if index < _props.size() else Vector3.ZERO


func is_tunnel_active() -> bool:
	return _tunnel.visible


## Запустить тоннель прямо сейчас (тесты): он появится у паровоза.
func spawn_tunnel(distance := 40.0) -> void:
	_tunnel.position.z = front_z - distance - 30.0
	_tunnel.visible = true
	_tunnel_warned = false
	_tunnel_front_prev = -INF
	_tunnel_hits.clear()


func _physics_process(delta: float) -> void:
	var step := speed * delta
	_biome_left -= delta
	if _biome_left <= 0.0:
		_set_biome(_biome_index + 1)
	for prop in _props:
		prop.pos.z += step
	_props = _props.filter(func(prop: Dictionary) -> bool: return prop.pos.z < BEHIND)
	_row_acc += step
	while _row_acc >= ROW:
		_row_acc -= ROW
		_spawn_row(AHEAD - _row_acc)
	_update_multimeshes()
	# Земля и шпалы прокручиваются.
	for material in [_ground_left, _ground_right, _track]:
		material.uv1_offset.z -= step * material.uv1_scale.z
	_tunnel_logic(delta, step)


# --- Пейзаж ---------------------------------------------------------------------------

func _set_biome(index: int) -> void:
	_biome_index = mini(index, _route.size() - 1)
	_biome = String(_route[_biome_index])
	_biome_left = BIOME_TIME if index < _route.size() - 1 else INF
	var data: Dictionary = BIOMES[_biome]
	var texture := load("res://textures/%s.png" % ("plaster" if data.ground == "snow" else data.ground)) as Texture2D
	for material in [_ground_left, _ground_right]:
		material.albedo_texture = texture
		material.albedo_color = data.tint
	_water.visible = data.get("water", false)
	_dust.color = Color(0.95, 0.97, 1.0, 0.8) if data.get("snow", false) else Color(0.75, 0.68, 0.55, 0.35)
	_dust.emitting = data.get("snow", false) or _biome == "desert"
	if index > 0:
		hud.show_message(BIOME_NAMES.get(_biome, _biome), "До цели: %s" % Game.city_name(Game.travel_to))


func _spawn_row(z: float) -> void:
	var data: Dictionary = BIOMES[_biome]
	for entry in data.props:
		var kind: String = entry[0]
		if kind == "pole":
			# Телеграфные столбы вдоль пути через равные промежутки.
			if int(roundf(z / ROW)) % 4 == 0:
				_props.append({"type": "pole", "pos": Vector3(road_half + 1.5, 0, z), "yaw": 0.0, "scale": 1.0})
			continue
		for side in [-1.0, 1.0]:
			if data.get("water", false) and side < 0.0:
				continue
			if randf() < float(entry[1]):
				var x: float = side * (side_offset + randf_range(float(entry[2]), float(entry[3])))
				_props.append({"type": kind, "pos": Vector3(x, 0, z + randf_range(-ROW * 0.4, ROW * 0.4)),
						"yaw": randf() * TAU, "scale": randf_range(0.8, 1.4)})


func _update_multimeshes() -> void:
	var counts := {}
	for kind in _multimeshes:
		counts[kind] = 0
	for prop in _props:
		var instance := _multimeshes.get(prop.type) as MultiMeshInstance3D
		if instance == null:
			continue
		var index: int = counts[prop.type]
		if index >= instance.multimesh.instance_count:
			continue
		var basis := Basis(Vector3.UP, prop.yaw).scaled(Vector3.ONE * prop.scale)
		if prop.type == "building":
			basis = Basis(Vector3.UP, 0.0).scaled(Vector3(prop.scale, prop.scale * 1.8, prop.scale))
		instance.multimesh.set_instance_transform(index, Transform3D(basis, prop.pos))
		counts[prop.type] = index + 1
	for kind in _multimeshes:
		(_multimeshes[kind] as MultiMeshInstance3D).multimesh.visible_instance_count = counts[kind]


func _build_ground() -> void:
	_ground_left = _scroll_material(null, 0.25)
	_ground_right = _scroll_material(null, 0.25)
	_track = _scroll_material(load(track_texture), 0.5)
	_track.albedo_color = track_tint
	for side in [-1.0, 1.0]:
		var ground := MeshInstance3D.new()
		var plane := BoxMesh.new()
		plane.size = Vector3(500, 0.2, 700)
		ground.mesh = plane
		ground.material_override = _ground_left if side < 0.0 else _ground_right
		ground.position = Vector3(side * (road_half + 250.0), -0.3, -100)
		ground.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(ground)
	var bed := MeshInstance3D.new()
	var bed_mesh := BoxMesh.new()
	bed_mesh.size = Vector3(road_half * 2.0, 0.3, 700)
	bed.mesh = bed_mesh
	bed.material_override = _track
	bed.position = Vector3(0, -0.25, -100)
	bed.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(bed)
	_water = MeshInstance3D.new()
	var water_mesh := BoxMesh.new()
	water_mesh.size = Vector3(500, 0.2, 700)
	_water.mesh = water_mesh
	_water.material_override = load("res://materials/water.tres")
	_water.position = Vector3(-(road_half + 252.0), -0.1, -100)
	_water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_water)


func _scroll_material(texture: Texture2D, scale: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_texture = texture
	material.uv1_triplanar = true
	material.uv1_scale = Vector3(scale, scale, scale)
	material.roughness = 0.95
	return material


## Меши пейзажа: коробки с цветом в вершинах, по одному MultiMesh на вид.
func _build_prop_meshes() -> void:
	var trunk := Color(0.3, 0.2, 0.12)
	var green := Color(0.16, 0.3, 0.16)
	var dark_green := Color(0.1, 0.22, 0.12)
	var white := Color(0.92, 0.94, 1.0)
	var stone := Color(0.42, 0.42, 0.44)
	var shapes := {
		"pole": [[Vector3(0.25, 8, 0.25), Vector3(0, 4, 0), trunk], [Vector3(2.2, 0.15, 0.15), Vector3(0, 7.4, 0), trunk]],
		"tree": [[Vector3(0.5, 3, 0.5), Vector3(0, 1.5, 0), trunk], [Vector3(3.6, 3.2, 3.6), Vector3(0, 4.4, 0), green]],
		"pine": [[Vector3(0.45, 3, 0.45), Vector3(0, 1.5, 0), trunk], [Vector3(3.4, 2.6, 3.4), Vector3(0, 3.6, 0), dark_green],
				[Vector3(2.4, 2.4, 2.4), Vector3(0, 5.6, 0), dark_green], [Vector3(1.3, 2.2, 1.3), Vector3(0, 7.4, 0), dark_green]],
		"snow_pine": [[Vector3(0.45, 3, 0.45), Vector3(0, 1.5, 0), trunk], [Vector3(3.4, 2.6, 3.4), Vector3(0, 3.6, 0), dark_green],
				[Vector3(3.0, 0.3, 3.0), Vector3(0, 5.0, 0), white], [Vector3(2.4, 2.4, 2.4), Vector3(0, 5.8, 0), dark_green],
				[Vector3(1.9, 0.3, 1.9), Vector3(0, 7.1, 0), white], [Vector3(1.3, 2.0, 1.3), Vector3(0, 7.9, 0), white]],
		"cactus": [[Vector3(0.6, 4.5, 0.6), Vector3(0, 2.25, 0), Color(0.25, 0.45, 0.22)],
				[Vector3(1.2, 0.5, 0.5), Vector3(0.6, 2.2, 0), Color(0.25, 0.45, 0.22)],
				[Vector3(0.5, 1.4, 0.5), Vector3(1.1, 2.9, 0), Color(0.25, 0.45, 0.22)]],
		"rock": [[Vector3(3.2, 2.2, 2.8), Vector3(0, 1.0, 0), stone], [Vector3(1.8, 1.4, 1.6), Vector3(1.2, 2.4, 0.4), stone.darkened(0.15)]],
		"house": [[Vector3(6, 4, 7), Vector3(0, 2, 0), Color(0.55, 0.42, 0.3)], [Vector3(6.8, 0.6, 7.8), Vector3(0, 4.3, 0), Color(0.3, 0.12, 0.1)],
				[Vector3(1.4, 1.2, 0.1), Vector3(0, 2.2, 3.52), Color(1.0, 0.85, 0.5)]],
		"dash": [[Vector3(0.2, 0.04, 3.0), Vector3(0, 0.03, 0), Color(0.95, 0.95, 0.9)]],
		"building": [[Vector3(12, 14, 12), Vector3(0, 7, 0), Color(0.3, 0.31, 0.34)],
				[Vector3(12.1, 0.6, 12.1), Vector3(0, 5, 0), Color(0.9, 0.82, 0.55)],
				[Vector3(12.1, 0.6, 12.1), Vector3(0, 9.5, 0), Color(0.9, 0.82, 0.55)]],
	}
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.roughness = 0.95
	for kind in shapes:
		var instance := MultiMeshInstance3D.new()
		var multimesh := MultiMesh.new()
		multimesh.transform_format = MultiMesh.TRANSFORM_3D
		multimesh.mesh = _box_mesh(shapes[kind], material)
		multimesh.instance_count = 200 if kind == "dash" else (140 if kind in ["pine", "snow_pine"] else 80)
		multimesh.visible_instance_count = 0
		instance.multimesh = multimesh
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		instance.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
		instance.name = "Props_" + kind
		add_child(instance)
		_multimeshes[kind] = instance


static func _box_mesh(boxes: Array, material: Material) -> ArrayMesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for box in boxes:
		var size: Vector3 = box[0]
		var center: Vector3 = box[1]
		var color: Color = box[2]
		var cube := BoxMesh.new()
		cube.size = size
		var arrays := cube.get_mesh_arrays()
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		for i in indices:
			tool.set_color(color)
			tool.set_normal(normals[i])
			tool.add_vertex(vertices[i] + center)
	tool.set_material(material)
	return tool.commit()


# --- Тоннели ------------------------------------------------------------------------------

func _build_tunnel() -> void:
	_tunnel = Node3D.new()
	_tunnel.name = "Tunnel"
	var rock := load("res://materials/rock.tres") as Material
	# Стены, свод (низ свода — на уровне голов стоящих на крыше) и скала вокруг входа.
	var wall := road_half + 2.5
	for part in [[Vector3(4, 9, 70), Vector3(-wall, 3.5, 0)], [Vector3(4, 9, 70), Vector3(wall, 3.5, 0)],
			[Vector3(wall * 2.0 + 4.0, 4, 70), Vector3(0, 7.7, 0)], [Vector3(wall * 2.0 + 30.0, 26, 3), Vector3(0, 20.6, -35)],
			[Vector3(12, 9, 3), Vector3(-wall - 8.0, 3.5, -35)], [Vector3(12, 9, 3), Vector3(wall + 8.0, 3.5, -35)]]:
		var mesh := MeshInstance3D.new()
		var cube := BoxMesh.new()
		cube.size = part[0]
		mesh.mesh = cube
		mesh.material_override = rock
		mesh.position = part[1]
		_tunnel.add_child(mesh)
	_tunnel.visible = false
	add_child(_tunnel)


func _tunnel_logic(delta: float, step: float) -> void:
	if not _tunnel.visible:
		_tunnel_cooldown -= delta
		if _tunnel_cooldown <= 0.0 and BIOMES[_biome].get("tunnels", false):
			_tunnel_cooldown = randf_range(28.0, 40.0)
			spawn_tunnel(speed * 4.0)
		return
	_tunnel.position.z += step
	var front := _tunnel.position.z + 35.0
	var back := _tunnel.position.z - 35.0
	if not _tunnel_warned and front > front_z - speed * 3.0:
		_tunnel_warned = true
		hud.show_message(tunnel_warning[0], tunnel_warning[1])
		Audio.play("train_horn" if sound_name == "train" else "horn", 2.0)
	# Внутри тоннеля темнеет.
	if _environment:
		var inside := back < 0.0 and front > front_z
		_environment.ambient_light_energy = move_toward(_environment.ambient_light_energy,
				_base_ambient * (0.35 if inside else 1.0), delta * 1.5)
	# Кто на крыше, когда над ним проходит свод тоннеля, — того сбивает.
	if _tunnel_front_prev > -INF:
		_hit_on_roof(player, _tunnel_front_prev, front)
		for node in get_tree().get_nodes_in_group("enemies"):
			_hit_on_roof(node as Node3D, _tunnel_front_prev, front)
	_tunnel_front_prev = front
	if back > BEHIND:
		_tunnel.visible = false


func _hit_on_roof(body: Node3D, from_z: float, to_z: float) -> void:
	if body == null or _tunnel_hits.has(body) or body.global_position.y < ROOF_Y - 0.3:
		return
	var z := body.global_position.z
	if z <= from_z or z > to_z:
		return
	_tunnel_hits[body] = true
	if body == player:
		if player.is_alive():
			player.take_damage(45, body.global_position + Vector3(0, 1.5, -2))
			player.knockback(Vector3(0, -2, 9))
			hud.show_message("Ударило тоннелем!", "В тоннелях держитесь внутри вагонов")
	elif body is Enemy and (body as Enemy).is_alive():
		(body as Enemy).apply_blast(500.0, body.global_position + Vector3(0, 1.5, -1.5), 12.0)


func _build_dust() -> void:
	_dust = CPUParticles3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.06, 0.06, 0.06)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.vertex_color_use_as_albedo = true
	mesh.material = material
	_dust.mesh = mesh
	_dust.amount = 300
	_dust.lifetime = 1.4
	_dust.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_dust.emission_box_extents = Vector3(18, 5, 20)
	_dust.direction = Vector3(0.1, -0.2, 1)
	_dust.spread = 8.0
	_dust.initial_velocity_min = speed * 0.8
	_dust.initial_velocity_max = speed * 1.1
	_dust.gravity = Vector3.ZERO
	_dust.local_coords = false
	_dust.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_dust.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	_dust.position = Vector3(0, 5, front_z * 0.45)
	_dust.emitting = false
	add_child(_dust)


func _start_sound() -> void:
	var stream := load("res://audio/%s.wav" % sound_name) as AudioStreamWAV
	if stream == null:
		return
	var loop := stream.duplicate() as AudioStreamWAV
	loop.loop_mode = AudioStreamWAV.LOOP_FORWARD
	loop.loop_end = int(loop.data.size() / 2)
	_sound = AudioStreamPlayer.new()
	_sound.stream = loop
	_sound.volume_db = -9.0
	add_child(_sound)
	_sound.play()


# --- Прибытие -------------------------------------------------------------------------------

## Доехали: маршрут открыт для самолёта, награда, дальше — город назначения.
func complete() -> void:
	if _finished or not player.is_alive():
		return
	_finished = true
	player.end_rage()
	var stars := earned_stars()
	var reward := Game.finish_travel(stars)
	Audio.stop_music()
	Audio.play("level_complete")
	hud.show_level_complete("Приехали: %s!" % Game.city_name(Game.travel_to), time, kills, headshots, reward, false,
			"Дальше")
	hud.show_stars(stars, accuracy(), max_combo)


func _on_next_requested() -> void:
	Game.travel(Game.travel_to)
