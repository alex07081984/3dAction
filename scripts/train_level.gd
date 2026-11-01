class_name TrainLevel
extends TravelLevel
## Поездка на поезде: пробиться через вагоны к паровозу. Пейзаж, тоннели и прибытие —
## в TravelLevel. Кто стоит на крыше вагона, когда поезд въезжает в тоннель, — того сбивает.


func _ready() -> void:
	objective = "Пробейтесь через вагоны к паровозу"
	super._ready()
