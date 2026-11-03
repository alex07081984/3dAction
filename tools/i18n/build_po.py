#!/usr/bin/env python3
"""Собирает locale/{en,de,fr,ru}.po из tools/i18n/strings.tsv.

Таблица: первая строка — заголовок, дальше «русский ключ<TAB>en<TAB>de<TAB>fr».
Перевод строки внутри ячейки пишется как \\n. Пустая ячейка — строка не переведена
(Godot покажет английский вариант). ru.po — ключи как есть: без него русский язык
тоже показывал бы английский (запасной язык Godot — en).

Проверки: у перевода должны совпадать подстановки (%d, %s, %.1f, %%) — иначе игра
упадёт при форматировании; каждый ключ таблицы должен встречаться в проекте
(см. extract.py).

  python3 tools/i18n/build_po.py
"""
import os
import re
import sys

sys.path.insert(0, os.path.dirname(__file__))
import extract  # noqa: E402

ROOT = extract.ROOT
LANGS = ("en", "de", "fr")
SPEC = re.compile(r"%(?:\.\d+)?[dsf%]")
# Французская типографика: перед ! ? : ; и внутри «» — неразрывный пробел (чтобы не переносилось).
NBSP = " "


def french(text):
    text = re.sub(r" ([!?:;»])", NBSP + r"\1", text)
    return text.replace("« ", "«" + NBSP)


def po_escape(text):
    """Ячейка таблицы уже экранирована (\\n, \\t, \\\\); в .po экранируем ещё кавычки."""
    return text.replace('"', '\\"')


def write_po(lang, pairs):
    path = os.path.join(ROOT, "locale", lang + ".po")
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8", newline="\n") as out:
        out.write('# 3D Action — %s. Файл собран tools/i18n/build_po.py из tools/i18n/strings.tsv, правьте таблицу.\n' % lang)
        out.write('msgid ""\nmsgstr ""\n"Content-Type: text/plain; charset=UTF-8\\n"\n"Language: %s\\n"\n\n' % lang)
        for key, value in pairs:
            out.write('msgid "%s"\nmsgstr "%s"\n\n' % (po_escape(key), po_escape(value)))
    return path


def main():
    table = extract.load_table()
    keys = extract.collect()
    errors = []
    for key, row in table.items():
        for lang in LANGS:
            value = row[lang]
            if value and SPEC.findall(value) != SPEC.findall(key):
                errors.append("%s: подстановки не совпадают: %r → %r" % (lang, key, value))
    unused = [k for k in table if k not in set(keys)]
    for k in unused:
        errors.append("ключа нет в проекте: %r" % k)
    if errors:
        print("\n".join(errors))
        return 1
    order = [k for k in keys if k in table]
    for lang in LANGS:
        pairs = []
        for key in order:
            value = table[key][lang]
            if value:
                pairs.append((key, french(value) if lang == "fr" else value))
        print(write_po(lang, pairs), len(pairs))
    print(write_po("ru", [(k, k) for k in order]), len(order))
    missing = [k for k in keys if k not in table]
    if missing:
        print("без перевода (%d): запустите extract.py" % len(missing))
    return 0


if __name__ == "__main__":
    sys.exit(main())
