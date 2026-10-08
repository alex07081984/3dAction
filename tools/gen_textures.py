"""Генератор бесшовных текстур для уровней.

Запуск с ПК:  python3 tools/gen_textures.py
Результат: textures/*.png (128x128 или 256x256, бесшовные).
"""
import os
import struct
import zlib

import numpy as np

OUT = os.path.join(os.path.dirname(__file__), "..", "textures")
rng = np.random.default_rng(11)


def save_png(name, img):
    img = np.clip(img, 0, 255).astype(np.uint8)
    h, w, _ = img.shape
    raw = b"".join(b"\x00" + img[y].tobytes() for y in range(h))

    def chunk(tag, data):
        return struct.pack(">I", len(data)) + tag + data + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)

    png = b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 2, 0, 0, 0))
    png += chunk(b"IDAT", zlib.compress(raw, 9)) + chunk(b"IEND", b"")
    os.makedirs(OUT, exist_ok=True)
    with open(os.path.join(OUT, name + ".png"), "wb") as f:
        f.write(png)
    print(name, img.shape)


def value_noise(size, cells):
    """Бесшовный value noise: случайная сетка cells x cells, билинейная интерполяция с заворотом."""
    grid = rng.random((cells, cells))
    coords = np.arange(size) * cells / size
    i0 = np.floor(coords).astype(int)
    f = coords - i0
    f = f * f * (3 - 2 * f)
    i1 = (i0 + 1) % cells
    i0 %= cells
    a = grid[np.ix_(i0, i0)]
    b = grid[np.ix_(i0, i1)]
    c = grid[np.ix_(i1, i0)]
    d = grid[np.ix_(i1, i1)]
    fy = f[:, None]
    fx = f[None, :]
    return (a * (1 - fx) + b * fx) * (1 - fy) + (c * (1 - fx) + d * fx) * fy


def fbm(size, base=4, octaves=4):
    total = np.zeros((size, size))
    amp, norm = 1.0, 0.0
    for o in range(octaves):
        total += value_noise(size, base * 2 ** o) * amp
        norm += amp
        amp *= 0.5
    return total / norm


def colorize(gray, c0, c1):
    c0 = np.array(c0, float)
    c1 = np.array(c1, float)
    return c0 + (c1 - c0) * gray[..., None]


def concrete(name, dark, light, size=128):
    n = fbm(size, 4, 5)
    speck = (rng.random((size, size)) > 0.97) * -0.15
    img = colorize(np.clip(n + speck, 0, 1), dark, light)
    save_png(name, img)


def grid_lines(size, count, width):
    y, x = np.mgrid[0:size, 0:size]
    step = size // count
    return ((x % step) < width) | ((y % step) < width)


def tiles(name, base, grout, count, size=128, var=0.06):
    n = fbm(size, 8, 3)
    img = colorize(n * var * 4, base, np.array(base) * (1 - var))
    y, x = np.mgrid[0:size, 0:size]
    step = size // count
    # Каждая плитка слегка своего оттенка.
    tile_id = (y // step) * count + (x // step)
    shade = rng.uniform(0.94, 1.04, count * count)[tile_id]
    img *= shade[..., None]
    img[grid_lines(size, count, 2)] = grout
    save_png(name, img)


def bricks(name, size=128):
    n = fbm(size, 8, 4)
    img = colorize(n, (95, 45, 35), (150, 75, 55))
    y, x = np.mgrid[0:size, 0:size]
    rows = 8
    h = size // rows
    row = y // h
    offset = (row % 2) * (size // 8)
    mortar = ((y % h) < 2) | (((x + offset) % (size // 4)) < 2)
    brick_id = row * 16 + ((x + offset) // (size // 4))
    shade = rng.uniform(0.8, 1.1, rows * 16 + 16)[brick_id]
    img *= shade[..., None]
    img[mortar] = (70, 68, 64)
    save_png(name, img)


def metal(name, size=128):
    n = fbm(size, 4, 4)
    img = colorize(n, (70, 74, 80), (110, 115, 122))
    y, x = np.mgrid[0:size, 0:size]
    # Рифление «ёлочкой».
    a = ((x + y) % 32 < 3) & ((x // 16 + y // 16) % 2 == 0)
    b = ((x - y) % 32 < 3) & ((x // 16 + y // 16) % 2 == 1)
    img[a | b] += 35
    save_png(name, img)


def hazard(name, size=128):
    y, x = np.mgrid[0:size, 0:size]
    stripe = ((x + y) // (size // 4)) % 2 == 0
    img = np.where(stripe[..., None], np.array([235, 185, 30]), np.array([30, 30, 30])).astype(float)
    img *= (0.85 + 0.15 * fbm(size, 8, 3))[..., None]
    save_png(name, img)


def wood(name, size=128):
    y, x = np.mgrid[0:size, 0:size]
    grain = np.sin((x / size) * 2 * np.pi * 10 + fbm(size, 4, 3) * 6) * 0.5 + 0.5
    img = colorize(grain * 0.6 + fbm(size, 8, 3) * 0.4, (120, 80, 40), (175, 125, 70))
    img[(y % (size // 4)) < 2] = (70, 45, 25)
    save_png(name, img)


def carpet(name, size=128):
    n = fbm(size, 16, 3) * 0.5 + rng.random((size, size)) * 0.5
    save_png(name, colorize(n, (55, 62, 78), (80, 90, 110)))


def windows(name, size=128):
    """Фасад с окнами: часть окон светится — для небоскрёбов на горизонте."""
    img = np.zeros((size, size, 3)) + (25, 28, 36)
    cols, rows = 8, 8
    cw, ch = size // cols, size // rows
    for r in range(rows):
        for c in range(cols):
            lit = rng.random() < 0.35
            color = (255, 210, 130) if lit else (45, 55, 75)
            img[r * ch + 3: r * ch + ch - 3, c * cw + 3: c * cw + cw - 3] = color
    save_png(name, img)


def main():
    concrete("concrete", (95, 95, 92), (150, 150, 145))
    concrete("concrete_dark", (55, 57, 58), (95, 97, 98))
    concrete("gravel", (60, 60, 62), (100, 98, 95))
    bricks("brick")
    tiles("tiles_wall", (225, 222, 210), (150, 150, 145), 8)
    tiles("floor_tiles", (120, 118, 115), (70, 70, 70), 2, var=0.12)
    metal("metal")
    hazard("hazard")
    wood("wood")
    carpet("carpet")
    windows("windows")
    tiles("office_wall", (200, 200, 195), (185, 185, 180), 1, var=0.05)


if __name__ == "__main__":
    main()
