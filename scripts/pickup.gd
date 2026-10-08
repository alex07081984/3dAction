class_name Pickup
extends Area3D
## Подбираемый предмет: аптечка, патроны или оружие.
## Моделька и зона подбора строятся кодом — достаточно поставить узел на уровень.

enum Kind { HEALTH, AMMO, WEAPON }

@export var kind := Kind.HEALTH
@export var heal_amount := 35
@export var weapon: WeaponData  ## Только для Kind.WEAPON.

var _visual: Node3D
var _time := 0.0
var _check := 0.0


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	monitorable = false
	_time = randf() * TAU
	if not has_node("Shape"):
		var shape := CollisionShape3D.new()
		shape.name = "Shape"
		var sphere := SphereShape3D.new()
		sphere.radius = 0.9
		shape.shape = sphere
		shape.position.y = 0.6
		add_child(shape)
	_visual = _build_visual()
	# Предмет крутится в _process, поэтому интерполяция физики ему не нужна.
	_visual.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	add_child(_visual)
	body_entered.connect(_try_pick)


func _process(delta: float) -> void:
	_time += delta
	_visual.rotation.y += delta * 1.8
	_visual.position.y = 0.55 + sin(_time * 2.5) * 0.1


func _physics_process(delta: float) -> void:
	# Если игрок стоит на предмете с полным здоровьем, подберём его, когда понадобится.
	_check -= delta
	if _check <= 0.0:
		_check = 0.3
		for body in get_overlapping_bodies():
			_try_pick(body)


func _try_pick(body: Node) -> void:
	var player := body as Player
	if player == null or not player.is_alive() or is_queued_for_deletion():
		return
	var used := false
	match kind:
		Kind.HEALTH:
			used = player.heal(heal_amount)
		Kind.AMMO:
			used = player.add_ammo()
		Kind.WEAPON:
			used = player.give_weapon(weapon)
	if used:
		Audio.play("weapon_pickup" if kind == Kind.WEAPON else "pickup")
		queue_free()


func _build_visual() -> Node3D:
	var root := Node3D.new()
	root.name = "Visual"
	match kind:
		Kind.HEALTH:
			BlockyCharacter.add_box(root, Vector3(0.5, 0.34, 0.34), Vector3.ZERO, Color(0.95, 0.95, 0.95))
			var red := Color(0.85, 0.08, 0.08)
			BlockyCharacter.add_box(root, Vector3(0.28, 0.08, 0.36), Vector3(0, 0, 0), red)
			BlockyCharacter.add_box(root, Vector3(0.08, 0.28, 0.36), Vector3(0, 0, 0), red)
			BlockyCharacter.add_box(root, Vector3(0.28, 0.36, 0.08), Vector3(0, 0, 0), red)
		Kind.AMMO:
			BlockyCharacter.add_box(root, Vector3(0.5, 0.3, 0.32), Vector3.ZERO, Color(0.28, 0.33, 0.2))
			BlockyCharacter.add_box(root, Vector3(0.52, 0.06, 0.34), Vector3(0, 0.05, 0), Color(0.9, 0.75, 0.2))
			for i in 4:
				BlockyCharacter.add_box(root, Vector3(0.05, 0.14, 0.05), Vector3(-0.15 + i * 0.1, 0.22, 0), Color(0.85, 0.65, 0.25))
		Kind.WEAPON:
			if weapon:
				var gun := BlockyCharacter.build_weapon_model(weapon.model)
				gun.scale = Vector3.ONE * 1.8
				root.add_child(gun)
				var label := Label3D.new()
				label.text = weapon.display_name
				label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
				label.font_size = 48
				label.outline_size = 10
				label.pixel_size = 0.006
				label.position = Vector3(0, 0.6, 0)
				label.no_depth_test = true
				root.add_child(label)
	# Светящийся круг под предметом, чтобы его было видно в темноте.
	var glow := MeshInstance3D.new()
	var disk := CylinderMesh.new()
	disk.top_radius = 0.45
	disk.bottom_radius = 0.45
	disk.height = 0.02
	disk.radial_segments = 16
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var colors := {Kind.HEALTH: Color(1, 0.3, 0.3, 0.5), Kind.AMMO: Color(1, 0.85, 0.3, 0.5), Kind.WEAPON: Color(0.4, 0.9, 1, 0.6)}
	material.albedo_color = colors[kind]
	disk.material = material
	glow.mesh = disk
	glow.position.y = -0.5
	glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(glow)
	return root
