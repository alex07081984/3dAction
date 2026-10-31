"""Мини-конструктор уровней: комнаты, коридоры, рампы, свет, враги, волны -> .tscn"""
import math
import os

# Корень проекта: две папки вверх от этого файла (tools/levels/).
ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))


def f(v):
    s = f"{v:.4f}".rstrip("0").rstrip(".")
    return "0" if s in ("-0", "") else s


def rot_y(deg):
    a = math.radians(deg)
    c, s = math.cos(a), math.sin(a)
    return [[c, 0, s], [0, 1, 0], [-s, 0, c]]


def rot_x(rad):
    c, s = math.cos(rad), math.sin(rad)
    return [[1, 0, 0], [0, c, -s], [0, s, c]]


def rot_z(rad):
    c, s = math.cos(rad), math.sin(rad)
    return [[c, -s, 0], [s, c, 0], [0, 0, 1]]


IDENT = [[1, 0, 0], [0, 1, 0], [0, 0, 1]]


def xform(pos, rows=IDENT):
    vals = [rows[i][j] for i in range(3) for j in range(3)] + list(pos)
    return "Transform3D(" + ", ".join(f(v) for v in vals) + ")"


def yaw_to(src, dst):
    """Угол поворота (в градусах) узла в src, чтобы он смотрел (-Z) на dst."""
    dx, dz = dst[0] - src[0], dst[-1] - src[-1]
    return math.degrees(math.atan2(-dx, -dz))


class Level:
    def __init__(self, root_name, script_props):
        self.root_name = root_name
        self.ext = {}
        self.sub = []
        self.nodes = []
        self.names = {}
        self.script_props = script_props
        self.route = []
        # Текущая секция: геометрия и мелочи комнаты сливаются в объединители CSG,
        # чтобы на экране было меньше отдельных объектов (меньше вызовов отрисовки).
        self.section = None
        self.combiners = set()

    # --- ресурсы ---
    def ext_res(self, kind, path):
        if path not in self.ext:
            rid = f"{len(self.ext) + 1}_{path.split('/')[-1].split('.')[0]}"
            self.ext[path] = (kind, rid)
        return f'ExtResource("{self.ext[path][1]}")'

    def mat(self, name):
        return self.ext_res("Material", f"res://materials/{name}.tres")

    def sub_res(self, kind, props, prefix=None):
        rid = f"{prefix or kind}_{len(self.sub) + 1}"
        self.sub.append((kind, rid, props))
        return f'SubResource("{rid}")'

    def unique(self, parent, name):
        key = (parent, name)
        n = self.names.get(key, 0) + 1
        self.names[key] = n
        return name if n == 1 else f"{name}{n}"

    def node(self, name, node_type, parent=".", instance=None, node_paths=None, **props):
        name = self.unique(parent, name)
        head = f'[node name="{name}"'
        if node_type:
            head += f' type="{node_type}"'
        head += f' parent="{parent}"'
        if instance:
            head += f" instance={instance}"
        if node_paths:
            head += " node_paths=PackedStringArray(" + ", ".join(f'"{p}"' for p in node_paths) + ")"
        head += "]"
        lines = [head] + [f"{k.replace('__', '/')} = {v}" for k, v in props.items()]
        self.nodes.append("\n".join(lines))
        return name if parent == "." else f"{parent}/{name}"

    def group(self, name, parent="."):
        return self.node(name, "Node3D", parent)

    # --- геометрия ---
    def combiner(self, path, collide):
        """Создаёт (один раз) CSGCombiner3D по пути вида 'Props/R1Solid'."""
        if path not in self.combiners:
            parent, name = path.rsplit("/", 1)
            props = {"use_collision": "true"} if collide else {}
            self.node(name, "CSGCombiner3D", parent, **props)
            self.combiners.add(path)
        return path

    def _resolve(self, parent, collide):
        """Мелкие объекты секции попадают в общий объединитель: твёрдые или декоративные."""
        if self.section is None:
            return parent, False
        if parent in ("Props", "Lights"):
            kind = "Solid" if collide else "Decor"
            return self.combiner(f"Props/{self.section}{kind}", collide), True
        if parent == "Geometry":
            return f"Geometry/{self.section}", True
        if parent in self.combiners:
            return parent, True
        return parent, False

    def box(self, parent, name, center, size, mat, collide=True, rows=IDENT, shadow=True):
        parent, merged = self._resolve(parent, collide)
        props = {"transform": xform(center, rows)}
        if collide and not merged:
            props["use_collision"] = "true"
        if not shadow and not merged:
            props["cast_shadow"] = "0"
        props["size"] = f"Vector3({f(size[0])}, {f(size[1])}, {f(size[2])})"
        props["material"] = self.mat(mat)
        return self.node(name, "CSGBox3D", parent, **props)

    def box_ext(self, parent, name, x0, x1, y0, y1, z0, z1, mat, collide=True, shadow=True):
        return self.box(parent, name, ((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2),
                        (abs(x1 - x0), abs(y1 - y0), abs(z1 - z0)), mat, collide, shadow=shadow)

    def cylinder(self, parent, name, center, radius, height, mat, collide=True, rows=IDENT, sides=12):
        parent, merged = self._resolve(parent, collide)
        props = {"transform": xform(center, rows)}
        if collide and not merged:
            props["use_collision"] = "true"
        props.update(radius=f(radius), height=f(height), sides=str(sides), material=self.mat(mat))
        return self.node(name, "CSGCylinder3D", parent, **props)

    def invisible_wall(self, parent, name, center, size):
        shape = self.sub_res("BoxShape3D", {"size": f"Vector3({f(size[0])}, {f(size[1])}, {f(size[2])})"}, "Box")
        body = self.node(name, "StaticBody3D", parent, transform=xform(center))
        self.node("Shape", "CollisionShape3D", body, shape=shape)

    def room(self, name, x0, x1, z0, z1, y, h, floor, wall, ceil=None, openings=None, sides=None, t=0.5,
             windows=None, wall_mats=None, floor_collide=True):
        """Комната: пол, потолок и стены снаружи границ. openings: {сторона: [(a, b, низ, верх)]},
        стороны N (z0), S (z1), W (x0), E (x1). Проём (a, b) без высоты — во всю высоту."""
        g = self.node(name, "CSGCombiner3D", "Geometry", use_collision="true")
        self.combiners.add(g)
        self.section = name
        openings = openings or {}
        sides = sides or {}
        windows = windows or {}
        wall_mats = wall_mats or {}
        self.box_ext(g, "Floor", x0, x1, y - 0.5, y, z0, z1, floor, floor_collide)
        if ceil:
            self.box_ext(g, "Ceiling", x0 - t, x1 + t, y + h, y + h + 0.4, z0 - t, z1 + t, ceil, shadow=True)
        for side in "NSWE":
            if not sides.get(side, True):
                continue
            m = wall_mats.get(side, wall)
            if side in "NS":
                # Углы закрываем, только если соседняя стена есть (у открытого торца коридора — нет).
                lo = x0 - t if sides.get("W", True) else x0
                hi = x1 + t if sides.get("E", True) else x1
                zz = (z0 - t, z0) if side == "N" else (z1, z1 + t)
            else:
                lo, hi = z0, z1
                xx = (x0 - t, x0) if side == "W" else (x1, x1 + t)
            holes = []
            for o in openings.get(side, []):
                a, b = o[0], o[1]
                bottom, top = (0, h) if len(o) == 2 else ((0, o[2]) if len(o) == 3 else (o[2], o[3]))
                holes.append((a, b, bottom, top))
            holes.sort()
            pieces = []  # (a, b, bottom, top)
            cursor = lo
            for a, b, bottom, top in holes:
                if a > cursor:
                    pieces.append((cursor, a, -0.5, h))
                if bottom > 0:
                    pieces.append((a, b, -0.5, bottom))
                if top < h:
                    pieces.append((a, b, top, h))
                cursor = max(cursor, b)
            if cursor < hi:
                pieces.append((cursor, hi, -0.5, h))
            for a, b, bottom, top in pieces:
                if b - a < 0.01 or top - bottom < 0.01:
                    continue
                bands = [(bottom, top, m)]
                if side in windows and bottom <= windows[side][0] and top >= windows[side][1]:
                    wb, wt = windows[side]
                    bands = [(bottom, wb, m), (wb, wt, "glass"), (wt, top, m)]
                for bb, tt, mm in bands:
                    if tt - bb < 0.01:
                        continue
                    if side in "NS":
                        self.box_ext(g, f"Wall{side}", a, b, y + bb, y + tt, zz[0], zz[1], mm)
                    else:
                        self.box_ext(g, f"Wall{side}", xx[0], xx[1], y + bb, y + tt, a, b, mm)
        return g

    def ramp_z(self, parent, name, x0, x1, z_start, y_start, z_end, y_end, mat, t=0.4):
        run = abs(z_end - z_start)
        rise = y_end - y_start
        length = math.hypot(run, rise)
        phi = math.atan2(rise, run)
        if z_end > z_start:
            phi = -phi
        rows = rot_x(phi)
        normal = (0, math.cos(phi), math.sin(phi))
        cx, cy, cz = (x0 + x1) / 2, (y_start + y_end) / 2, (z_start + z_end) / 2
        center = (cx - normal[0] * t / 2, cy - normal[1] * t / 2, cz - normal[2] * t / 2)
        return self.box(parent, name, center, (x1 - x0, t, length + 0.04), mat, rows=rows)

    def ramp_x(self, parent, name, z0, z1, x_start, y_start, x_end, y_end, mat, t=0.4):
        run = abs(x_end - x_start)
        rise = y_end - y_start
        length = math.hypot(run, rise)
        phi = math.atan2(rise, run)
        if x_end < x_start:
            phi = -phi
        rows = rot_z(phi)
        normal = (-math.sin(phi), math.cos(phi), 0)
        cx, cy, cz = (x_start + x_end) / 2, (y_start + y_end) / 2, (z0 + z1) / 2
        center = (cx - normal[0] * t / 2, cy - normal[1] * t / 2, cz - normal[2] * t / 2)
        return self.box(parent, name, center, (length + 0.04, t, z1 - z0), mat, rows=rows)

    # --- свет ---
    def lamp(self, pos, energy=1.4, rng=9.0, color="Color(1, 0.9, 0.75, 1)", mat="lamp", size=(1.2, 0.08, 0.3),
             fixture=True):
        if fixture:
            self.box("Lights", "Lamp", (pos[0], pos[1] + 0.05, pos[2]), size, mat, collide=False, shadow=False)
        self.node("Light", "OmniLight3D", "Lights", transform=xform((pos[0], pos[1] - 0.3, pos[2])),
                  light_color=color, light_energy=f(energy), omni_range=f(rng))

    # --- игровые объекты ---
    def enemy(self, kind, pos, look_at=None, yaw=0.0, **props):
        if look_at is not None:
            yaw = yaw_to(pos, look_at)
        scene = self.ext_res("PackedScene", f"res://scenes/enemies/{kind}.tscn")
        self.node(kind.capitalize(), None, "Enemies", instance=scene,
                  transform=xform(pos, rot_y(yaw)), **props)

    def pickup(self, kind, pos, weapon=None, heal=None):
        script = self.ext_res("Script", "res://scripts/pickup.gd")
        kinds = {"health": 0, "ammo": 1, "weapon": 2, "grenade": 3}
        props = {"transform": xform(pos), "script": script, "kind": str(kinds[kind])}
        if heal:
            props["heal_amount"] = str(heal)
        if weapon:
            props["weapon"] = self.ext_res("Resource", f"res://weapons/{weapon}.tres")
        self.node(kind.capitalize() if not weapon else weapon.capitalize(), "Area3D", "Pickups", **props)

    def explosives(self, spots, pattern="BBC"):
        """Бочки (B), газовые баллоны (C) и ящики динамита (T) по очереди по шаблону."""
        if not getattr(self, "_explosives_group", False):
            self.group("Explosives")
            self._explosives_group = True
        kinds = {"B": ("explosive_barrel", "Barrel"), "C": ("gas_cylinder", "Cylinder"), "T": ("tnt_crate", "Tnt")}
        for i, pos in enumerate(spots):
            path, name = kinds[pattern[i % len(pattern)]]
            scene = self.ext_res("PackedScene", f"res://scenes/props/{path}.tscn")
            self.node(name, None, "Explosives", instance=scene, transform=xform(pos, rot_y(i * 37.0)))

    def markers(self, group, points):
        """Группа маркеров: [(имя, (x, y, z), поворот)] — места пряток, точки появления."""
        g = self.group(group)
        for name, pos, yaw in points:
            self.node(name, "Marker3D", g, transform=xform(pos, rot_y(yaw)))
        return g

    def boss(self, kind, name, pos, look_at, **props):
        scene = self.ext_res("PackedScene", f"res://scenes/enemies/{kind}.tscn")
        self.node(name, None, "Enemies", instance=scene, transform=xform(pos, rot_y(yaw_to(pos, look_at))), **props)

    def wave_zone(self, name, center, size, spawns, barriers, title="Засада!", waves=2, first=4, extra=2,
                  rusher=0.3, heavy=0, gunner_kind="gunner", rusher_kind="rusher", heavy_kind="heavy"):
        script = self.ext_res("Script", "res://scripts/wave_zone.gd")
        shape = self.sub_res("BoxShape3D", {"size": f"Vector3({f(size[0])}, {f(size[1])}, {f(size[2])})"}, "Box")
        z = self.node(name, "Area3D", ".", transform=xform(center), script=script, title=f'"{title}"',
                      waves=str(waves), enemies_in_first_wave=str(first), extra_per_wave=str(extra),
                      rusher_share=f(rusher), heavy_in_last_wave=str(heavy),
                      gunner_scene=self.ext_res("PackedScene", f"res://scenes/enemies/{gunner_kind}.tscn"),
                      rusher_scene=self.ext_res("PackedScene", f"res://scenes/enemies/{rusher_kind}.tscn"),
                      heavy_scene=self.ext_res("PackedScene", f"res://scenes/enemies/{heavy_kind}.tscn"))
        self.node("CollisionShape3D", "CollisionShape3D", z, shape=shape)
        sp = self.node("Spawns", "Node3D", z)
        for p in spawns:
            local = (p[0] - center[0], p[1] - center[1], p[2] - center[2])
            yaw = yaw_to(p, center)
            self.node("Spawn", "Marker3D", sp, transform=xform(local, rot_y(yaw)))
        br = self.node("Barriers", "Node3D", z)
        for c, s in barriers:
            local = (c[0] - center[0], c[1] - center[1], c[2] - center[2])
            self.box(br, "Barrier", local, s, "barrier", collide=True)
        return name

    def exit(self, center, size, sign_pos, text="ВЫХОД", required_zone=None, sign_yaw=0.0):
        script = self.ext_res("Script", "res://scripts/level_exit.gd")
        shape = self.sub_res("BoxShape3D", {"size": f"Vector3({f(size[0])}, {f(size[1])}, {f(size[2])})"}, "Box")
        props = {"transform": xform(center), "script": script}
        paths = None
        if required_zone:
            props["required_zone"] = f'NodePath("../{required_zone}")'
            paths = ["required_zone"]
        e = self.node("Exit", "Area3D", ".", node_paths=paths, **props)
        self.node("CollisionShape3D", "CollisionShape3D", e, shape=shape)
        local = (sign_pos[0] - center[0], sign_pos[1] - center[1], sign_pos[2] - center[2])
        self.node("Sign", "Label3D", e, transform=xform(local, rot_y(sign_yaw)), pixel_size="0.012",
                  modulate="Color(0.4, 1, 0.5, 1)", outline_modulate="Color(0, 0.15, 0, 1)", text=f'"{text}"',
                  font_size="96", outline_size="16")
        self.node("Glow", "OmniLight3D", e, transform=xform((local[0], local[1] - 0.5, local[2] + 1.0)),
                  light_color="Color(0.3, 1, 0.45, 1)", light_energy="2.0", omni_range="7.0")
        marker_mat = self.mat("sign_green")
        self.node("Marker", "CSGCylinder3D", e, transform=xform((0, -size[1] / 2 + 0.03, 0)),
                  radius=f(min(size[0], size[2]) * 0.45), height="0.04", sides="24", material=marker_mat)

    def label(self, text, pos, yaw=0.0, size=72, color="Color(1, 1, 1, 1)", pixel=0.01):
        self.node("Label", "Label3D", "Props", transform=xform(pos, rot_y(yaw)), pixel_size=f(pixel),
                  modulate=color, text=f'"{text}"', font_size=str(size), outline_size="12")

    def player(self, pos, yaw=0.0):
        self.node("Player", None, ".", instance=self.ext_res("PackedScene", "res://scenes/player.tscn"),
                  transform=xform(pos, rot_y(yaw)))

    def waypoint(self, *points):
        self.route.extend(points)

    # --- запись ---
    def begin_section(self, name):
        """Секция без комнаты (квартал города): своя объединённая геометрия и мелочи."""
        self.combiner(f"Geometry/{name}", True)
        self.section = name

    def interactable(self, script_name, name, parent, center, size, **props):
        script = self.ext_res("Script", f"res://scripts/{script_name}.gd")
        shape = self.sub_res("BoxShape3D", {"size": f"Vector3({f(size[0])}, {f(size[1])}, {f(size[2])})"}, "Box")
        node = self.node(name, "Area3D", parent, transform=xform(center), script=script, **props)
        self.node("CollisionShape3D", "CollisionShape3D", node, shape=shape)
        return node

    def write(self, path, environment, start_weapons, extra_root_nodes=None, script_path="res://scripts/level.gd"):
        script = self.ext_res("Script", script_path)
        weapon_script = self.ext_res("Script", "res://scripts/weapon_data.gd")
        weapons = ", ".join(self.ext_res("Resource", f"res://weapons/{w}.tres") for w in start_weapons)
        hud = self.ext_res("PackedScene", "res://ui/hud.tscn")
        route = self.group("Route")
        for i, p in enumerate(self.route):
            self.node(f"P{i:02d}", "Marker3D", route, transform=xform(p))
        self.node("HUD", None, ".", instance=hud)

        out = ["[gd_scene format=3]", ""]
        for p, (kind, rid) in self.ext.items():
            out.append(f'[ext_resource type="{kind}" path="{p}" id="{rid}"]')
        out.append("")
        for kind, rid, props in self.sub + environment:
            out.append(f'[sub_resource type="{kind}" id="{rid}"]')
            for k, v in props.items():
                out.append(f"{k} = {v}")
            out.append("")
        root = [f'[node name="{self.root_name}" type="Node3D"]', f"script = {script}"]
        for k, v in self.script_props.items():
            root.append(f"{k} = {v}")
        root.append(f"start_weapons = Array[{weapon_script}]([{weapons}])")
        out.append("\n".join(root))
        out.append("")
        out.append("\n\n".join(self.nodes))
        out.append("")
        with open(f"{ROOT}/{path}", "w") as fh:
            fh.write("\n".join(out))
        print("wrote", path, "nodes:", len(self.nodes))
