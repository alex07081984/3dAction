"""Генератор сцен интерфейса (HUD, настройки, главное меню) в формате .tscn."""
import os

# Корень проекта: две папки вверх от этого файла (tools/levels/).
ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))

PRESETS = {
    "full": dict(anchors_preset=15, anchor_right=1.0, anchor_bottom=1.0, grow_horizontal=2, grow_vertical=2),
    "top_left": dict(),
    "top_right": dict(anchors_preset=1, anchor_left=1.0, anchor_right=1.0, grow_horizontal=0),
    "bottom_right": dict(anchors_preset=3, anchor_left=1.0, anchor_top=1.0, anchor_right=1.0, anchor_bottom=1.0,
                         grow_horizontal=0, grow_vertical=0),
    "bottom_left": dict(anchors_preset=2, anchor_top=1.0, anchor_bottom=1.0, grow_vertical=0),
    "center_top": dict(anchors_preset=5, anchor_left=0.5, anchor_right=0.5, grow_horizontal=2),
    "center": dict(anchors_preset=8, anchor_left=0.5, anchor_top=0.5, anchor_right=0.5, anchor_bottom=0.5,
                   grow_horizontal=2, grow_vertical=2),
    "center_bottom": dict(anchors_preset=7, anchor_left=0.5, anchor_top=1.0, anchor_right=0.5, anchor_bottom=1.0,
                          grow_horizontal=2, grow_vertical=0),
    "left_wide": dict(anchors_preset=9, anchor_bottom=1.0, grow_vertical=2),
}


def fmt(v):
    if isinstance(v, bool):
        return "true" if v else "false"
    if isinstance(v, float):
        return repr(v)
    if isinstance(v, int):
        return str(v)
    if isinstance(v, str) and (v.startswith(("Color(", "Vector2(", "Vector3(", "ExtResource(", "SubResource(",
                                             "Transform3D(", "&\"", "PackedStringArray(")) or v.startswith("__raw__")):
        return v.replace("__raw__", "")
    if isinstance(v, str):
        return '"' + v.replace('"', '\\"') + '"'
    raise TypeError(v)


class Scene:
    def __init__(self):
        self.ext = []
        self.sub = []
        self.nodes = []

    def ext_res(self, kind, path):
        rid = f"{len(self.ext) + 1}_{os.path.basename(path).split('.')[0]}"
        self.ext.append((kind, path, rid))
        return f'ExtResource("{rid}")'

    def sub_res(self, kind, rid, **props):
        self.sub.append((kind, rid, props))
        return f'SubResource("{rid}")'

    def node(self, name, kind=None, parent=None, instance=None, layout=None, offsets=None, unique=False, **props):
        head = f'[node name="{name}"'
        if kind:
            head += f' type="{kind}"'
        if parent is not None:
            head += f' parent="{parent}"'
        if instance:
            head += f" instance={instance}"
        head += "]"
        lines = [head]
        if unique:
            lines.append("unique_name_in_owner = true")
        ordered = {}
        for key in ("visible", "process_mode"):
            if key in props:
                ordered[key] = props.pop(key)
        if "custom_minimum_size" in props:
            ordered["custom_minimum_size"] = props.pop("custom_minimum_size")
        if layout:
            if layout == "container":
                ordered["layout_mode"] = 2
            else:
                ordered["layout_mode"] = 3 if parent is None or layout == "full" else 1
                ordered.update(PRESETS[layout])
        if offsets:
            for key, value in zip(("offset_left", "offset_top", "offset_right", "offset_bottom"), offsets):
                ordered[key] = float(value)
        ordered.update(props)
        for key, value in ordered.items():
            lines.append(f"{key} = {fmt(value)}")
        self.nodes.append("\n".join(lines))

    def write(self, path):
        out = ["[gd_scene format=3]", ""]
        for kind, p, rid in self.ext:
            out.append(f'[ext_resource type="{kind}" path="{p}" id="{rid}"]')
        if self.ext:
            out.append("")
        for kind, rid, props in self.sub:
            out.append(f'[sub_resource type="{kind}" id="{rid}"]')
            for key, value in props.items():
                out.append(f"{key} = {fmt(value)}")
            out.append("")
        out.append("\n\n".join(self.nodes))
        out.append("")
        with open(os.path.join(ROOT, path), "w") as f:
            f.write("\n".join(out))
        print("wrote", path)


def panel_style(scene, rid="StyleBox_panel", color="Color(0.08, 0.1, 0.14, 0.94)"):
    return scene.sub_res("StyleBoxFlat", rid, content_margin_left=40.0, content_margin_top=32.0,
                         content_margin_right=40.0, content_margin_bottom=32.0, bg_color=color,
                         corner_radius_top_left=18, corner_radius_top_right=18,
                         corner_radius_bottom_right=18, corner_radius_bottom_left=18)


def dialog(scene, name, parent, title, buttons, style, dim="Color(0, 0, 0, 0.6)", extra=None, title_unique=False,
           visible=False):
    """Затемнение + центрированная панель с заголовком и кнопками."""
    scene.node(name, "Control", parent, layout="full", unique=True, visible=visible)
    path = name if parent == "." else f"{parent}/{name}"
    scene.node("Dim", "ColorRect", path, layout="full", color=dim)
    scene.node("Center", "CenterContainer", path, layout="full")
    scene.node("Panel", "PanelContainer", f"{path}/Center", layout="container",
               theme_override_styles__panel=style)
    vbox = f"{path}/Center/Panel/VBox"
    scene.node("VBox", "VBoxContainer", f"{path}/Center/Panel", layout="container",
               theme_override_constants__separation=16)
    scene.node("Title", "Label", vbox, layout="container", unique=title_unique,
               theme_override_font_sizes__font_size=44, text=title, horizontal_alignment=1)
    for item in extra or []:
        item(vbox)
    for button_name, text in buttons:
        scene.node(button_name, "Button", vbox, layout="container", unique=True,
                   custom_minimum_size="Vector2(400, 76)", text=text)


def fix_props(path):
    """theme_override_x__y -> theme_override_x/y (в Python нельзя писать «/» в имени аргумента)."""
    full = os.path.join(ROOT, path)
    text = open(full).read()
    import re
    text = re.sub(r"^(theme_override_\w+?)__(\w+) =", r"\1/\2 =", text, flags=re.M)
    open(full, "w").write(text)


# --- Панель настроек ---------------------------------------------------------------
def settings_panel():
    s = Scene()
    script = s.ext_res("Script", "res://scripts/ui/settings_panel.gd")
    style = panel_style(s)
    s.node("SettingsPanel", "Control", None, layout="full", script=script)
    s.node("Dim", "ColorRect", ".", layout="full", color="Color(0, 0, 0, 0.6)")
    s.node("Center", "CenterContainer", ".", layout="full")
    s.node("Panel", "PanelContainer", "Center", layout="container", theme_override_styles__panel=style)
    s.node("VBox", "VBoxContainer", "Center/Panel", layout="container", theme_override_constants__separation=12)
    v = "Center/Panel/VBox"
    s.node("Title", "Label", v, layout="container", theme_override_font_sizes__font_size=40,
           text="Настройки", horizontal_alignment=1)
    for row, label, slider, value_label, lo, hi, step in (
            ("SensitivityRow", "Чувствительность", "Sensitivity", "SensitivityValue", 0.3, 2.5, 0.05),
            ("VolumeRow", "Громкость", "Volume", "VolumeValue", 0.0, 1.0, 0.05)):
        s.node(row, "HBoxContainer", v, layout="container", theme_override_constants__separation=16)
        s.node("Label", "Label", f"{v}/{row}", layout="container", custom_minimum_size="Vector2(260, 0)", text=label)
        s.node(slider, "HSlider", f"{v}/{row}", layout="container", unique=True,
               custom_minimum_size="Vector2(320, 56)", size_flags_vertical=4, min_value=lo, max_value=hi,
               step=step, value=1.0 if slider == "Sensitivity" else 0.8)
        s.node(value_label, "Label", f"{v}/{row}", layout="container", unique=True,
               custom_minimum_size="Vector2(80, 0)", text="1.0")
    for name, text in (("AimAssist", "Помощь в прицеливании"),
                       ("AutoFire", "Автоогонь (стреляет сам, когда прицел на враге)"),
                       ("Shadows", "Тени (выключите, если игра тормозит)"),
                       ("Noir", "Нуар-фильтр: ч/б кадр, красная кровь (выкл. — быстрее)"),
                       ("Music", "Музыка")):
        s.node(name, "CheckButton", v, layout="container", unique=True, custom_minimum_size="Vector2(0, 56)",
               text=text)
    s.node("DoneButton", "Button", v, layout="container", unique=True, custom_minimum_size="Vector2(0, 76)",
           text="Готово")
    s.write("ui/settings_panel.tscn")
    fix_props("ui/settings_panel.tscn")


# --- HUD ---------------------------------------------------------------------------
def hud():
    s = Scene()
    script = s.ext_res("Script", "res://scripts/hud.gd")
    joystick = s.ext_res("Script", "res://scripts/touch/touch_joystick.gd")
    button = s.ext_res("Script", "res://scripts/touch/touch_button.gd")
    crosshair = s.ext_res("Script", "res://scripts/ui/crosshair.gd")
    settings = s.ext_res("PackedScene", "res://ui/settings_panel.tscn")
    hp_bg = s.sub_res("StyleBoxFlat", "StyleBox_hp_bg", bg_color="Color(0, 0, 0, 0.5)",
                      corner_radius_top_left=8, corner_radius_top_right=8,
                      corner_radius_bottom_right=8, corner_radius_bottom_left=8)
    hp_fill = s.sub_res("StyleBoxFlat", "StyleBox_hp_fill", bg_color="Color(0.86, 0.2, 0.24, 1)",
                        corner_radius_top_left=8, corner_radius_top_right=8,
                        corner_radius_bottom_right=8, corner_radius_bottom_left=8)
    reload_fill = s.sub_res("StyleBoxFlat", "StyleBox_reload", bg_color="Color(1, 0.85, 0.3, 1)",
                            corner_radius_top_left=4, corner_radius_top_right=4,
                            corner_radius_bottom_right=4, corner_radius_bottom_left=4)
    noir_shader = s.ext_res("Shader", "res://ui/noir.gdshader")
    noir = s.sub_res("ShaderMaterial", "ShaderMaterial_noir", shader=noir_shader)
    boss_fill = s.sub_res("StyleBoxFlat", "StyleBox_boss", bg_color="Color(0.7, 0.08, 0.06, 1)",
                          corner_radius_top_left=6, corner_radius_top_right=6,
                          corner_radius_bottom_right=6, corner_radius_bottom_left=6)
    style = panel_style(s)

    s.node("HUD", "CanvasLayer", None, process_mode=3, script=script)
    # Нуар-фильтр рисуется первым: он берёт только 3D-картинку, интерфейс поверх остаётся цветным.
    s.node("NoirFilter", "ColorRect", ".", layout="full", unique=True, mouse_filter=2, material=noir)
    s.node("DamageFlash", "ColorRect", ".", layout="full", unique=True, mouse_filter=2,
           color="Color(0.8, 0, 0, 0)")
    s.node("Crosshair", "Control", ".", layout="full", unique=True, mouse_filter=2, script=crosshair)

    s.node("TouchControls", "Control", ".", layout="full", unique=True, process_mode=1, mouse_filter=2)
    s.node("Joystick", "Control", "TouchControls", layout="top_left", mouse_filter=2, script=joystick,
           anchor_top=0.3, anchor_right=0.42, anchor_bottom=1.0, grow_horizontal=2, grow_vertical=2)
    buttons = [
        ("FireButton", "fire", "Огонь", 30, (-255, -255, -85, -85), True, "Color(1, 0.35, 0.3, 0.28)"),
        ("JumpButton", "jump", "Прыжок", 18, (-400, -145, -300, -45), False, None),
        ("DodgeButton", "dodge", "Рывок", 18, (-415, -285, -315, -185), False, None),
        ("ReloadButton", "reload", "Заряд", 18, (-335, -385, -245, -295), False, None),
        ("SwitchButton", "switch_weapon", "Пист", 22, (-195, -405, -85, -295), False, "Color(0.4, 0.8, 1, 0.25)"),
        ("InteractButton", "interact", "Войти", 24, (-600, -230, -460, -90), False, "Color(0.3, 1, 0.45, 0.35)"),
        ("GrenadeButton", "grenade", "Гран 2", 18, (-455, -400, -355, -300), False, "Color(0.5, 1, 0.4, 0.28)"),
    ]
    for name, action, text, size, offsets, drag, color in buttons:
        props = dict(mouse_filter=2, script=button, action=f'&"{action}"', text=text, font_size=size)
        if drag:
            props["pass_drag"] = True
        if color:
            props["color"] = color
        if name == "InteractButton":
            props["visible"] = False
        s.node(name, "Control", "TouchControls", layout="bottom_right", offsets=offsets,
               unique=(name in ("SwitchButton", "InteractButton", "GrenadeButton")), **props)
    s.node("InteractPrompt", "Label", "TouchControls", layout="bottom_right", offsets=(-900, -290, -160, -240),
           unique=True, visible=False, theme_override_font_sizes__font_size=24, horizontal_alignment=1,
           theme_override_colors__font_color="Color(0.75, 1, 0.8, 1)", autowrap_mode=3)

    s.node("TopBar", "Control", ".", layout="full", mouse_filter=2)
    s.node("HealthBar", "ProgressBar", "TopBar", layout="top_left", offsets=(24, 20, 324, 56), unique=True,
           mouse_filter=2, theme_override_styles__background=hp_bg, theme_override_styles__fill=hp_fill,
           step=1.0, value=100.0, show_percentage=False)
    s.node("HealthLabel", "Label", "TopBar/HealthBar", layout="full", unique=True,
           theme_override_font_sizes__font_size=22, text="100", horizontal_alignment=1, vertical_alignment=1)
    s.node("ObjectiveLabel", "Label", "TopBar", layout="center_top", offsets=(-270, 14, 270, 50), unique=True,
           theme_override_font_sizes__font_size=22, horizontal_alignment=1, autowrap_mode=3,
           clip_text=True)
    s.node("KillsLabel", "Label", "TopBar", layout="center_top", offsets=(-270, 50, 270, 80), unique=True,
           theme_override_font_sizes__font_size=20, text="Убито: 0", horizontal_alignment=1)
    s.node("BossBar", "VBoxContainer", "TopBar", layout="center_top", offsets=(-300, 84, 300, 140), unique=True,
           visible=False, mouse_filter=2, theme_override_constants__separation=2)
    s.node("BossName", "Label", "TopBar/BossBar", layout="container", unique=True,
           theme_override_font_sizes__font_size=22, theme_override_colors__font_color="Color(1, 0.8, 0.45, 1)",
           text="Босс", horizontal_alignment=1)
    s.node("BossHealth", "ProgressBar", "TopBar/BossBar", layout="container", unique=True,
           custom_minimum_size="Vector2(600, 18)", mouse_filter=2, theme_override_styles__background=hp_bg,
           theme_override_styles__fill=boss_fill, value=100.0, show_percentage=False)
    s.node("PauseButton", "Button", "TopBar", layout="top_right", offsets=(-104, 16, -24, 96), unique=True,
           focus_mode=0, theme_override_font_sizes__font_size=32, text="II")
    s.node("MoneyLabel", "Label", "TopBar", layout="top_right", offsets=(-370, 22, -120, 60), unique=True,
           theme_override_font_sizes__font_size=30, theme_override_colors__font_color="Color(1, 0.85, 0.3, 1)",
           text="$ 0", horizontal_alignment=2)
    s.node("MoneyPopup", "Label", "TopBar", layout="top_right", offsets=(-370, 60, -120, 92), unique=True,
           theme_override_font_sizes__font_size=24, theme_override_colors__font_color="Color(0.6, 1, 0.5, 1)",
           horizontal_alignment=2)
    s.node("WeaponLabel", "Label", "TopBar", layout="bottom_right", offsets=(-440, -522, -60, -490), unique=True,
           theme_override_font_sizes__font_size=20, text="Пистолет", horizontal_alignment=2)
    s.node("AmmoLabel", "Label", "TopBar", layout="bottom_right", offsets=(-440, -492, -60, -430), unique=True,
           theme_override_font_sizes__font_size=42, text="12 / ∞", horizontal_alignment=2)

    s.node("ReloadBar", "ProgressBar", ".", layout="center", offsets=(-70, 36, 70, 46), unique=True,
           mouse_filter=2, theme_override_styles__background=hp_bg, theme_override_styles__fill=reload_fill,
           show_percentage=False)
    s.node("Message", "Label", ".", layout="center", offsets=(-500, -205, 500, -125), unique=True,
           theme_override_constants__outline_size=12, theme_override_font_sizes__font_size=60,
           horizontal_alignment=1, vertical_alignment=1)
    s.node("Subtitle", "Label", ".", layout="center", offsets=(-500, -125, 500, -81), unique=True,
           theme_override_font_sizes__font_size=28, horizontal_alignment=1, vertical_alignment=1)
    s.node("Toast", "Label", ".", layout="center_bottom", offsets=(-300, -76, 300, -36), unique=True,
           theme_override_font_sizes__font_size=26, horizontal_alignment=1,
           theme_override_colors__font_color="Color(1, 0.9, 0.5, 1)")

    dialog(s, "PauseMenu", ".", "Пауза",
           [("ResumeButton", "Продолжить"), ("SettingsButton", "Настройки"),
            ("RestartButton", "Начать уровень заново"), ("TownButton", "Вернуться в город"),
            ("MenuButton", "В главное меню")], style)
    s.node("SettingsPanel", None, ".", instance=settings, unique=True, visible=False)
    dialog(s, "GameOver", ".", "Вы погибли",
           [("GameOverRestartButton", "Заново"), ("GameOverTownButton", "В город"),
            ("GameOverMenuButton", "В главное меню")], style,
           dim="Color(0.3, 0, 0, 0.6)")

    def entrance_info(vbox):
        s.node("EntranceInfo", "Label", vbox, layout="container", unique=True,
               custom_minimum_size="Vector2(460, 0)", theme_override_font_sizes__font_size=26,
               horizontal_alignment=1, autowrap_mode=3)

    dialog(s, "EntrancePanel", ".", "Задание", [("EntranceStartButton", "Начать"), ("EntranceCancelButton", "Отмена")],
           style, extra=[entrance_info])

    def property_body(vbox):
        s.node("PropertyInfo", "Label", vbox, layout="container", unique=True,
               custom_minimum_size="Vector2(620, 0)", theme_override_font_sizes__font_size=24,
               horizontal_alignment=1, autowrap_mode=3)
        s.node("PropertyBuyButton", "Button", vbox, layout="container", unique=True,
               custom_minimum_size="Vector2(400, 76)", text="Купить")
        s.node("UpgradeList", "VBoxContainer", vbox, layout="container", unique=True,
               theme_override_constants__separation=10)

    dialog(s, "PropertyPanel", ".", "Недвижимость", [("PropertyCloseButton", "Закрыть")], style,
           extra=[property_body])

    def stats(vbox):
        s.node("CompleteStats", "Label", vbox, layout="container", unique=True,
               theme_override_font_sizes__font_size=30, text="Время: 0:00", horizontal_alignment=1)
        s.node("RecordLabel", "Label", vbox, layout="container", unique=True,
               theme_override_colors__font_color="Color(1, 0.85, 0.3, 1)",
               theme_override_font_sizes__font_size=30, text="Новый рекорд!", horizontal_alignment=1)

    dialog(s, "LevelComplete", ".", "Уровень пройден!",
           [("NextButton", "Следующий уровень"), ("CompleteMenuButton", "В главное меню")], style,
           dim="Color(0, 0.15, 0.05, 0.6)", extra=[stats], title_unique=False)
    s.write("ui/hud.tscn")
    text = open(os.path.join(ROOT, "ui/hud.tscn")).read()
    for panel, unique_title in (("EntrancePanel", "EntranceTitle"), ("PropertyPanel", "PropertyTitle")):
        text = text.replace(f'[node name="Title" type="Label" parent="{panel}/Center/Panel/VBox"]',
                            f'[node name="{unique_title}" type="Label" parent="{panel}/Center/Panel/VBox"]\n'
                            'unique_name_in_owner = true')
    # Заголовок экрана победы должен быть доступен как %CompleteTitle.
    text = text.replace('[node name="Title" type="Label" parent="LevelComplete/Center/Panel/VBox"]',
                        '[node name="CompleteTitle" type="Label" parent="LevelComplete/Center/Panel/VBox"]\n'
                        'unique_name_in_owner = true')
    open(os.path.join(ROOT, "ui/hud.tscn"), "w").write(text)
    fix_props("ui/hud.tscn")


# --- Главное меню ------------------------------------------------------------------
def main_menu():
    s = Scene()
    script = s.ext_res("Script", "res://scripts/ui/main_menu.gd")
    model = s.ext_res("Script", "res://scripts/blocky_character.gd")
    settings = s.ext_res("PackedScene", "res://ui/settings_panel.tscn")
    metal = s.ext_res("Material", "res://materials/metal.tres")
    env = s.sub_res("Environment", "Env_menu", background_mode=1, background_color="Color(0.04, 0.05, 0.08, 1)",
                    ambient_light_source=2, ambient_light_color="Color(0.35, 0.38, 0.45, 1)",
                    ambient_light_energy=0.6, tonemap_mode=2)
    s.node("MainMenu", "Node3D", None, script=script)
    s.node("WorldEnvironment", "WorldEnvironment", ".", environment=env)
    s.node("Camera3D", "Camera3D", ".", current=True, fov=50.0,
           transform="Transform3D(0.95937, -0.03554, 0.27992, 0.00000, 0.99203, 0.12596, -0.28217, -0.12085, 0.95172, 1.6, 1.5, 3.4)")
    s.node("KeyLight", "DirectionalLight3D", ".", light_energy=0.9, shadow_enabled=True,
           transform="Transform3D(0.819152, -0.469846, 0.32899, 0, 0.573576, 0.819152, -0.573576, -0.67101, 0.469846, 0, 4, 0)")
    s.node("RimRed", "OmniLight3D", ".", transform="Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0.2, 2.2, -2.0)",
           light_color="Color(1, 0.25, 0.2, 1)", light_energy=3.0, omni_range=6.0)
    s.node("RimBlue", "OmniLight3D", ".", transform="Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 3.9, 1.6, -1.6)",
           light_color="Color(0.3, 0.6, 1, 1)", light_energy=2.5, omni_range=6.0)
    s.node("Pedestal", "CSGCylinder3D", ".", transform="Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 1.9, -0.15, -0.6)",
           radius=1.1, height=0.3, sides=24, material=metal)
    s.node("Hero", "Node3D", ".", transform="Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 1.9, 0, -0.6)")
    s.node("Model", "Node3D", "Hero", script=model, leg_length=0.86, torso_length=0.88, outfit="coat", hat="fedora", beard="stubble",
           skin_color="Color(0.9, 0.72, 0.58, 1)", shirt_color="Color(0.82, 0.82, 0.8, 1)",
           jacket_color="Color(0.36, 0.31, 0.24, 1)", pants_color="Color(0.13, 0.13, 0.15, 1)",
           hair_color="Color(0.1, 0.07, 0.05, 1)", hat_color="Color(0.17, 0.15, 0.14, 1)",
           shoe_color="Color(0.12, 0.08, 0.06, 1)", weapon="shotgun")

    s.node("UI", "CanvasLayer", ".")
    s.node("Title", "Label", "UI", layout="top_left", offsets=(60, 50, 760, 150),
           theme_override_constants__outline_size=14, theme_override_font_sizes__font_size=84,
           theme_override_colors__font_color="Color(1, 0.86, 0.35, 1)", text="3D ACTION")
    s.node("Subtitle", "Label", "UI", layout="top_left", offsets=(64, 150, 900, 190),
           theme_override_font_sizes__font_size=26, text="Эпизод 1: Подземка · Метро · Небоскрёб · Особняк · Город")
    s.node("MoneyLabel", "Label", "UI", layout="top_right", offsets=(-420, 40, -60, 84), unique=True,
           theme_override_font_sizes__font_size=34, theme_override_colors__font_color="Color(1, 0.85, 0.3, 1)",
           text="$ 0", horizontal_alignment=2)
    s.node("MainButtons", "VBoxContainer", "UI", layout="top_left", offsets=(60, 240, 520, 640), unique=True,
           theme_override_constants__separation=14)
    for name, text in (("PlayButton", "Играть"), ("LevelsButton", "Уровни"), ("SettingsButton", "Настройки"),
                       ("QuitButton", "Выход")):
        s.node(name, "Button", "UI/MainButtons", layout="container", unique=True,
               custom_minimum_size="Vector2(440, 80)", theme_override_font_sizes__font_size=30, text=text)
    s.node("LevelsPanel", "VBoxContainer", "UI", layout="top_left", offsets=(60, 200, 820, 700), unique=True,
           visible=False, theme_override_constants__separation=14)
    s.node("Header", "Label", "UI/LevelsPanel", layout="container", theme_override_font_sizes__font_size=40,
           text="Уровни")
    s.node("LevelList", "VBoxContainer", "UI/LevelsPanel", layout="container", unique=True,
           theme_override_constants__separation=8)
    s.node("BackButton", "Button", "UI/LevelsPanel", layout="container", unique=True,
           custom_minimum_size="Vector2(300, 72)", text="Назад")
    s.node("SettingsPanel", None, "UI", instance=settings, unique=True, visible=False)
    s.write("scenes/main_menu.tscn")
    fix_props("scenes/main_menu.tscn")


settings_panel()
hud()
main_menu()
