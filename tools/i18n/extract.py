#!/usr/bin/env python3
"""Сбор строк для перевода.

Исходный язык игры — русский: русские строки служат ключами (msgid), переводы на
английский, немецкий и французский лежат в tools/i18n/strings.tsv, а build_po.py
собирает из них locale/*.po.

  python3 tools/i18n/extract.py          — список ключей, которых нет в strings.tsv
  python3 tools/i18n/extract.py --keys   — все ключи по порядку (для новой таблицы)

Откуда берутся ключи:
  * .gd — все строки в кавычках с русскими буквами (кроме комментариев,
    @export_group и названий языков в Game.LANGUAGES);
  * .tscn/.tres — свойства text, title, objective, boss_name, display_name,
    short_name, prompt, button_text и имена укрытий боссов (BossNests, BossHidePoints).
"""
import os
import re
import sys

ROOT = os.path.normpath(os.path.join(os.path.dirname(__file__), "..", ".."))
CYR = re.compile(r"[А-Яа-яЁё]")
PROPS = ("text", "title", "objective", "boss_name", "display_name", "short_name", "prompt", "button_text")
SPOT_PARENTS = ("BossNests", "BossHidePoints")
SKIP_KEYS = {"Русский"}  # названия языков пишутся на самом языке


def escape(text):
    """Канонический вид ключа в таблице: перевод строки — \\n, табуляция — \\t."""
    return text.replace("\\", "\\\\").replace("\n", "\\n").replace("\t", "\\t")


def unescape_gd(literal):
    out, i = [], 0
    while i < len(literal):
        c = literal[i]
        if c == "\\" and i + 1 < len(literal):
            n = literal[i + 1]
            out.append({"n": "\n", "t": "\t", '"': '"', "\\": "\\", "'": "'"}.get(n, "\\" + n))
            i += 2
        else:
            out.append(c)
            i += 1
    return "".join(out)


def gd_strings(path):
    """Строки в двойных кавычках вне комментариев."""
    found = []
    for line in open(path, encoding="utf-8"):
        stripped = line.strip()
        if stripped.startswith("#") or stripped.startswith("@export_group"):
            continue
        i, n = 0, len(line)
        while i < n:
            c = line[i]
            if c == "#":
                break
            if c == '"':
                if line.startswith('"""', i):
                    break  # многострочные строки (шейдеры) не переводим
                j, buf = i + 1, []
                while j < n and line[j] != '"':
                    if line[j] == "\\" and j + 1 < n:
                        buf.append(line[j:j + 2])
                        j += 2
                        continue
                    buf.append(line[j])
                    j += 1
                text = unescape_gd("".join(buf))
                if CYR.search(text):
                    found.append(text)
                i = j + 1
                continue
            i += 1
    return found


def unescape_tscn(literal):
    return literal.replace('\\"', '"').replace("\\n", "\n").replace("\\\\", "\\")


def scene_strings(path):
    text = open(path, encoding="utf-8").read()
    found = []
    for m in re.finditer(r'^(\w+) = "((?:[^"\\]|\\.)*)"', text, re.M | re.S):
        if m.group(1) in PROPS:
            value = unescape_tscn(m.group(2))
            if CYR.search(value):
                found.append(value)
    for m in re.finditer(r'\[node name="([^"]+)" type="[^"]+" parent="(?:[^"]*/)?(%s)"' % "|".join(SPOT_PARENTS), text):
        if CYR.search(m.group(1)):
            found.append(m.group(1))
    return found


def collect():
    keys = []
    seen = set()
    for folder in ("scripts", "scenes", "ui", "weapons"):
        for base, _dirs, files in sorted(os.walk(os.path.join(ROOT, folder))):
            for name in sorted(files):
                path = os.path.join(base, name)
                if name.endswith(".gd"):
                    strings = gd_strings(path)
                elif name.endswith((".tscn", ".tres")):
                    strings = scene_strings(path)
                else:
                    continue
                for s in strings:
                    key = escape(s)
                    if key not in seen and s not in SKIP_KEYS:
                        seen.add(key)
                        keys.append(key)
    return keys


def load_table(path=os.path.join(ROOT, "tools", "i18n", "strings.tsv")):
    rows = {}
    if not os.path.exists(path):
        return rows
    for number, line in enumerate(open(path, encoding="utf-8"), 1):
        line = line.rstrip("\n")
        if not line or line.startswith("#") or number == 1:
            continue
        cells = line.split("\t")
        cells += [""] * (4 - len(cells))
        rows[cells[0]] = {"en": cells[1], "de": cells[2], "fr": cells[3]}
    return rows


def main():
    keys = collect()
    if "--keys" in sys.argv:
        print("\n".join(keys))
        return 0
    table = load_table()
    missing = [k for k in keys if k not in table]
    unused = [k for k in table if k not in set(keys)]
    for k in missing:
        print("нет перевода:", k)
    for k in unused:
        print("лишняя строка в таблице:", k)
    print("ключей: %d, в таблице: %d, без перевода: %d" % (len(keys), len(table), len(missing)))
    return 1 if missing else 0


if __name__ == "__main__":
    sys.exit(main())
