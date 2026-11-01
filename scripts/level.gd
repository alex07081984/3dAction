class_name Level
extends Node3D
## Корень уровня: связывает игрока, HUD и места с волнами, считает время,
## убийства и хедшоты, показывает итог и открывает следующий уровень.
## Аркада: серия убийств без урона (комбо) умножает деньги, за эффектные убийства —
## крупные надписи, убийства копят ярость, за уровень дают 1–3 звезды.

const COMBO_WINDOW := 4.0  ## Сколько секунд ждёт серия следующего убийства.
const MULTI_WINDOW := 0.9  ## Убийства чаще этого — двойное, тройное…

@export var level_index := 0
@export var title := "Подземка"
@export var objective := "Найдите выход"
@export var start_weapons: Array[WeaponData] = []

var kills := 0
var headshots := 0
var time := 0.0
var combo := 0
var max_combo := 0
var shots_fired := 0
var shots_hit := 0

var _combo_timer := 0.0
var _multi := 0
var _multi_timer := 0.0
var _shot_hit := false

var _finished := false
var _last_health := 1 << 30

@onready var player: Player = $Player
@onready var hud: Hud = $HUD


func _ready() -> void:
	add_to_group("level")
	Game.current_level = level_index
	Engine.time_scale = 1.0
	for weapon in start_weapons:
		player.give_weapon(weapon, false)
	if not player.weapons.is_empty():
		player.switch_weapon_to(player.weapons[0])
	hud.bind_player(player)
	hud.restart_requested.connect(Game.restart_level)
	hud.menu_requested.connect(Game.go_to_menu)
	hud.town_requested.connect(Game.go_to_town)
	hud.next_requested.connect(_on_next_requested)
	hud.set_town_available(Game.latest_city() >= 0 and not Game.is_city(level_index))
	player.died.connect(_on_player_died)
	player.hit_confirmed.connect(func(_head: bool, _killed: bool) -> void: _shot_hit = true)
	player.shot_fired.connect(_on_shot_fired)
	player.health_changed.connect(_on_player_health)

	for zone in find_children("*", "WaveZone"):
		zone.started.connect(_on_zone_started)
		zone.wave_started.connect(_on_wave_started)
		zone.cleared.connect(_on_zone_cleared)

	var shadows: bool = Game.settings.get("shadows", true)
	for light in find_children("*", "DirectionalLight3D"):
		(light as DirectionalLight3D).shadow_enabled = shadows

	Audio.play_music("music_explore")
	var tier: int = Game.current_tier
	hud.show_message(title, objective if tier == 0 else "Сложность %d · награда ×%.1f" % [tier + 1, Game.reward_multiplier()])
	hud.set_objective(objective)


func _process(delta: float) -> void:
	if not _finished and player.is_alive():
		time += delta
	_multi_timer -= delta
	if combo > 0:
		_combo_timer -= delta
		if _combo_timer <= 0.0:
			_set_combo(0)


## Множитель денег за серию: 3 убийства подряд — ×2, 6 — ×3 и так до ×5.
func combo_multiplier() -> int:
	return clampi(1 + combo / 3, 1, 5)


func register_kill(headshot: bool) -> void:
	kills += 1
	if headshot:
		headshots += 1
	_multi = _multi + 1 if _multi_timer > 0.0 else 1
	_multi_timer = MULTI_WINDOW
	_set_combo(combo + 1)
	hud.set_kills(kills)
	hud.show_money_popup(Game.reward_kill(headshot, combo_multiplier()))
	player.add_rage(10.0 + (6.0 if headshot else 0.0) + (5.0 if _multi > 1 else 0.0))
	# Крупная надпись: мультикилл важнее хедшота, а круглая серия — повод похвастаться.
	if _multi >= 2:
		hud.show_banner(["", "", "ДВОЙНОЕ!", "ТРОЙНОЕ!"][_multi] if _multi <= 3 else "МЯСОРУБКА!", Color(1, 0.55, 0.15))
	elif headshot:
		hud.show_banner("ХЕДШОТ!", Color(1, 0.2, 0.15))
	elif combo >= 5 and combo % 5 == 0:
		hud.show_banner("СЕРИЯ ×%d!" % combo_multiplier(), Color(1, 0.85, 0.3))


## Звёзды за уровень: одна за прохождение, ещё по одной за меткость (40%)
## и за хедшоты (каждое четвёртое убийство).
func earned_stars() -> int:
	var result := 1
	if shots_fired > 0 and float(shots_hit) / shots_fired >= 0.4:
		result += 1
	if kills > 0 and float(headshots) / kills >= 0.25:
		result += 1
	return result


func accuracy() -> float:
	return float(shots_hit) / shots_fired if shots_fired > 0 else 0.0


func _set_combo(value: int) -> void:
	combo = value
	max_combo = maxi(max_combo, combo)
	_combo_timer = COMBO_WINDOW
	hud.update_combo(combo, combo_multiplier())


func _on_shot_fired(weapon: WeaponData) -> void:
	# Ракеты взрываются позже — в меткость их не считаем.
	if weapon.projectile != "":
		_shot_hit = false
		return
	shots_fired += 1
	if _shot_hit:
		shots_hit += 1
	_shot_hit = false


## Любое ранение обрывает серию.
func _on_player_health(current: int, _maximum: int) -> void:
	if current < _last_health and combo > 0:
		_set_combo(0)
	_last_health = current


func complete() -> void:
	if _finished or not player.is_alive():
		return
	_finished = true
	player.end_rage()
	var stars := earned_stars()
	var result := Game.complete_level(level_index, time, kills, headshots, stars)
	Audio.stop_music()
	Audio.play("level_complete")
	var next_text := ""
	if _continues_episode():
		next_text = "Следующий уровень"
	elif Game.latest_city() >= 0:
		next_text = "В город"
	var heading := "%s пройден!" % title
	if Game.is_episode_finale(level_index):
		heading = "Эпизод %d пройден!" % Game.episode_of(level_index)
	hud.show_level_complete(heading, time, kills, headshots, result.reward, result.record, next_text)
	hud.show_stars(stars, accuracy(), max_combo)


func _on_next_requested() -> void:
	if _continues_episode():
		Game.start_level(level_index + 1)
	else:
		Game.go_to_town(Game.city_of(level_index))


## Уровень ведёт к следующему уровню того же эпизода (а не обратно в город).
func _continues_episode() -> bool:
	if Game.is_episode_finale(level_index) or not Game.has_next_level(level_index):
		return false
	return not Game.is_liberated(Game.city_of(level_index))


func _on_player_died() -> void:
	Audio.stop_music()
	Game.save_data()
	get_tree().create_timer(1.5, false).timeout.connect(hud.show_game_over)


## Босс побеждён: либо уровень пройден сразу, либо открывается выход.
## Босс заметил игрока — играет музыка боя.
func on_boss_fight(_boss: Boss) -> void:
	Audio.play_music("music_combat")


func on_boss_defeated(boss: Boss) -> void:
	Audio.play_music("music_explore")
	Game.slow_motion(1.4, 0.2)
	if boss.completes_level:
		get_tree().create_timer(3.0, false).timeout.connect(complete)
	else:
		hud.set_objective(objective)


func _on_zone_started(zone: WaveZone) -> void:
	Audio.play_music("music_combat")
	hud.show_message(zone.title, "Продержитесь!")


func _on_wave_started(_zone: WaveZone, wave: int, total: int) -> void:
	hud.set_objective("Волна %d из %d" % [wave, total])


func _on_zone_cleared(_zone: WaveZone) -> void:
	Audio.play_music("music_explore")
	Game.slow_motion(0.9, 0.25)
	hud.show_message("Чисто!", "Проход открыт")
	hud.set_objective(objective)
