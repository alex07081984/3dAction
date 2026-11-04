extends SceneTree
## Растрирует иконку из SVG в PNG для значков Android (см. tools/gen_icon.py).
##   godot --headless --path . -s res://tools/render_icon.gd


func _initialize() -> void:
	for job in [["res://icon.svg", "res://icons/icon_192.png", 192],
			["res://icons/icon_foreground.svg", "res://icons/icon_foreground.png", 432],
			["res://icons/icon_background.svg", "res://icons/icon_background.png", 432]]:
		var source := FileAccess.get_file_as_string(job[0])
		var image := Image.new()
		var size: int = job[2]
		# Исходник рисуется в 512 пикселей — масштаб подгоняет под нужный размер.
		var header := source.substr(0, source.find("viewBox"))
		var native := float(header.get_slice('width="', 1).get_slice('"', 0))
		image.load_svg_from_string(source, size / native)
		image.save_png(ProjectSettings.globalize_path(job[1]))
		print(job[1], " ", image.get_size())
	quit()
