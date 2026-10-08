class_name WeaponData
extends Resource
## Параметры оружия. Файлы лежат в res://weapons/*.tres — их удобно править в Инспекторе.

@export var id := "pistol"
@export var display_name := "Пистолет"
@export var short_name := "Пист"  ## Подпись на кнопке смены оружия.
@export var model := "pistol"  ## Какую модельку держит персонаж: pistol, deagle, shotgun.
@export var sound := "pistol"  ## Звук выстрела из res://audio/.

@export_group("Стрельба")
@export var damage := 20.0  ## Урон одной пули (у дробовика — одной дробины).
@export var pellets := 1  ## Сколько пуль за выстрел.
@export var spread_deg := 0.8  ## Разброс в градусах.
@export var fire_interval := 0.25  ## Пауза между выстрелами, сек.
@export var max_range := 70.0
@export var headshot_multiplier := 3.0
@export var impulse := 4.0  ## Насколько сильно отбрасывает тела.
## Если один выстрел наносит врагу столько урона и убивает его — тело разлетается на куски.
@export var gib_damage := 1000.0
## Если в руку попало столько урона за выстрел — её отрывает (ноге нужно в 1,3 раза больше).
## 0 — оружие конечности не отрывает.
@export var sever_damage := 0.0

@export_group("Патроны")
@export var magazine := 12
@export var reload_time := 1.2
@export var infinite_ammo := false
@export var start_reserve := 24
@export var max_reserve := 60
@export var ammo_per_pickup := 12

@export_group("Отдача")
@export var recoil_deg := 1.2  ## Подброс камеры при выстреле.
@export var shake := 0.12  ## Тряска камеры.
@export var crosshair_kick := 8.0  ## Насколько расходится прицел.
