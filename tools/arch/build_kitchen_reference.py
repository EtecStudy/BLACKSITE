#!/usr/bin/env python3
"""Gera a cena de reconstrução 3D da imagem de referência (cozinha).

Reconstrução fiel à imagem fornecida pelo usuário: cozinha degradada com
porta acorrentada, armários, geladeira, fogão, ilha e iluminação mista
quente/fria. Geometria e texturas PBR procedurais, somente biblioteca
padrão do Python; nenhum asset externo.

Uso:
    python3 tools/arch/build_kitchen_reference.py

Saídas:
    maps/reference/textures/*.png
    maps/reference/materials/*.tres
    maps/reference/kitchen_reference.tscn
"""

from __future__ import annotations

import math
import random
import struct
import zlib
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
REF = ROOT / "maps" / "reference"
TEX_DIR = REF / "textures"
MAT_DIR = REF / "materials"
SCENE_PATH = REF / "kitchen_reference.tscn"

# ---------------------------------------------------------------------------
# PNG procedural (somente biblioteca padrão)
# ---------------------------------------------------------------------------


def _chunk(kind: bytes, data: bytes) -> bytes:
    return struct.pack(">I", len(data)) + kind + data + struct.pack(">I", zlib.crc32(kind + data) & 0xFFFFFFFF)


def write_png(path: Path, rows: list[bytearray]) -> None:
    height = len(rows)
    width = len(rows[0]) // 3
    raw = b"".join(b"\x00" + bytes(row) for row in rows)
    data = b"\x89PNG\r\n\x1a\n"
    data += _chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 2, 0, 0, 0))
    data += _chunk(b"IDAT", zlib.compress(raw, level=7))
    data += _chunk(b"IEND", b"")
    path.write_bytes(data)


def write_png_rgba(path: Path, rows: list[bytearray]) -> None:
    height = len(rows)
    width = len(rows[0]) // 4
    raw = b"".join(b"\x00" + bytes(row) for row in rows)
    data = b"\x89PNG\r\n\x1a\n"
    data += _chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0))
    data += _chunk(b"IDAT", zlib.compress(raw, level=7))
    data += _chunk(b"IEND", b"")
    path.write_bytes(data)


def noise_grid(size: int, cells: int, seed: int) -> list[list[float]]:
    rnd = random.Random(seed)
    grid = [[rnd.random() for _ in range(cells + 1)] for _ in range(cells + 1)]
    for i in range(cells + 1):
        grid[i][cells] = grid[i][0]
        grid[cells][i] = grid[0][i]
    out: list[list[float]] = []
    scale = cells / float(size)
    for y in range(size):
        fy = y * scale
        y0 = int(fy) % cells
        y1 = (y0 + 1) % cells
        ty = fy - int(fy)
        row: list[float] = []
        grow0 = grid[y0]
        grow1 = grid[y1]
        for x in range(size):
            fx = x * scale
            x0 = int(fx) % cells
            x1 = (x0 + 1) % cells
            tx = fx - int(fx)
            top = grow0[x0] * (1.0 - tx) + grow0[x1] * tx
            bottom = grow1[x0] * (1.0 - tx) + grow1[x1] * tx
            row.append(top * (1.0 - ty) + bottom * ty)
        out.append(row)
    return out


def combined_noise(size: int, seed: int) -> list[list[float]]:
    layers = [
        (noise_grid(size, 6, seed + 11), 0.46),
        (noise_grid(size, 14, seed + 29), 0.30),
        (noise_grid(size, 34, seed + 47), 0.16),
        (noise_grid(size, 72, seed + 71), 0.08),
    ]
    result: list[list[float]] = []
    for y in range(size):
        row: list[float] = []
        for x in range(size):
            value = 0.0
            for grid, weight in layers:
                value += grid[y][x] * weight
            row.append(value)
        result.append(row)
    return result


def clamp_byte(value: float) -> int:
    return max(0, min(255, int(round(value))))


def save_maps(name: str, albedo: list[bytearray], height: list[list[float]],
              roughness: list[bytearray], strength: float = 2.0) -> None:
    size = len(height)
    normal: list[bytearray] = []
    ao: list[bytearray] = []
    for y in range(size):
        nrow = bytearray()
        arow = bytearray()
        ym = max(0, y - 1)
        yp = min(size - 1, y + 1)
        for x in range(size):
            xm = max(0, x - 1)
            xp = min(size - 1, x + 1)
            dx = (height[y][xp] - height[y][xm]) * strength
            dy = (height[yp][x] - height[ym][x]) * strength
            inv = 1.0 / math.sqrt(dx * dx + dy * dy + 1.0)
            nrow += bytes((clamp_byte((-dx * inv * 0.5 + 0.5) * 255),
                           clamp_byte((dy * inv * 0.5 + 0.5) * 255),
                           clamp_byte((inv * 0.5 + 0.5) * 255)))
            shade = clamp_byte((0.72 + height[y][x] * 0.5) * 255)
            arow += bytes((shade, shade, shade))
        normal.append(nrow)
        ao.append(arow)
    write_png(TEX_DIR / f"{name}_albedo.png", albedo)
    write_png(TEX_DIR / f"{name}_normal.png", normal)
    write_png(TEX_DIR / f"{name}_roughness.png", roughness)
    write_png(TEX_DIR / f"{name}_ao.png", ao)


def base_rows(size: int, rgb: tuple[float, float, float]) -> list[bytearray]:
    rows: list[bytearray] = []
    for _ in range(size):
        row = bytearray()
        for _ in range(size):
            row += bytes((clamp_byte(rgb[0] * 255), clamp_byte(rgb[1] * 255), clamp_byte(rgb[2] * 255)))
        rows.append(row)
    return rows


def set_px(rows: list[bytearray], x: int, y: int, rgb: tuple[int, int, int]) -> None:
    if 0 <= y < len(rows) and 0 <= x < len(rows[0]) // 3:
        i = x * 3
        rows[y][i:i + 3] = bytes(rgb)


def blend_px(rows: list[bytearray], x: int, y: int, rgb: tuple[float, float, float], alpha: float) -> None:
    if 0 <= y < len(rows) and 0 <= x < len(rows[0]) // 3:
        i = x * 3
        for c in range(3):
            rows[y][i + c] = clamp_byte(rows[y][i + c] * (1.0 - alpha) + rgb[c] * 255 * alpha)


def blotch(rows: list[bytearray], height: list[list[float]], cx: float, cy: float,
           radius: float, rgb: tuple[float, float, float], alpha: float,
           rnd: random.Random, depth: float = 0.0) -> None:
    size = len(rows)
    r = int(radius)
    for _ in range(26):
        ox = cx + rnd.uniform(-radius, radius) * 0.7
        oy = cy + rnd.uniform(-radius, radius) * 0.7
        orad = radius * rnd.uniform(0.25, 0.62)
        x0, x1 = max(0, int(ox - orad)), min(size, int(ox + orad))
        y0, y1 = max(0, int(oy - orad)), min(size, int(oy + orad))
        for y in range(y0, y1):
            for x in range(x0, x1):
                d = math.hypot(x - ox, y - oy) / max(1.0, orad)
                if d < 1.0:
                    a = alpha * (1.0 - d) * rnd.uniform(0.6, 1.0)
                    blend_px(rows, x, y, rgb, min(0.92, a))
                    height[y][x] = max(-0.6, height[y][x] - depth * (1.0 - d))


def streak(rows: list[bytearray], x: int, y0: int, length: int, width: int,
           rgb: tuple[float, float, float], alpha: float, rnd: random.Random) -> None:
    size = len(rows)
    for t in range(length):
        y = y0 + t
        if y >= size:
            break
        fade = 1.0 - t / max(1, length)
        for dx in range(-width, width + 1):
            a = alpha * fade * (1.0 - abs(dx) / (width + 1.0)) * rnd.uniform(0.7, 1.0)
            blend_px(rows, x + dx, y, rgb, min(0.8, a))


def speckle(rows: list[bytearray], height: list[list[float]], rnd: random.Random,
            count: int, rgb: tuple[float, float, float], alpha: float, max_r: float = 2.2) -> None:
    size = len(rows)
    for _ in range(count):
        x = rnd.randrange(size)
        y = rnd.randrange(size)
        r = rnd.uniform(0.6, max_r)
        x0, x1 = max(0, int(x - r)), min(size, int(x + r) + 1)
        y0, y1 = max(0, int(y - r)), min(size, int(y + r) + 1)
        for yy in range(y0, y1):
            for xx in range(x0, x1):
                if math.hypot(xx - x, yy - y) <= r:
                    blend_px(rows, xx, yy, rgb, alpha * rnd.uniform(0.5, 1.0))
                    height[yy][xx] += rnd.uniform(-0.03, 0.03)


def rough_from(height: list[list[float]], base: float, vary: float, seed: int) -> list[bytearray]:
    size = len(height)
    n = combined_noise(size, seed)
    rows: list[bytearray] = []
    for y in range(size):
        row = bytearray()
        for x in range(size):
            v = clamp_byte((base + (n[y][x] - 0.5) * vary + height[y][x] * 0.08) * 255)
            row += bytes((v, v, v))
        rows.append(row)
    return rows


def tint_noise(size: int, base: tuple[float, float, float], amp: float, seed: int):
    """Retorna (albedo, height) com marmoramento procedural."""
    n = combined_noise(size, seed)
    rows = base_rows(size, base)
    for y in range(size):
        for x in range(size):
            v = (n[y][x] - 0.5) * amp
            i = x * 3
            rows[y][i] = clamp_byte(rows[y][i] + v * 255)
            rows[y][i + 1] = clamp_byte(rows[y][i + 1] + v * 255)
            rows[y][i + 2] = clamp_byte(rows[y][i + 2] + v * 235)
    return rows, n


# ---------------------------------------------------------------------------
# Texturas da cozinha de referência
# ---------------------------------------------------------------------------


def tex_wall(size: int, seed: int, heavy: bool) -> None:
    rnd = random.Random(seed)
    rows, height = tint_noise(size, (0.60, 0.585, 0.52), 0.10, seed)
    # Manchas de umidade descendo do teto e subindo do rodapé.
    for _ in range(9 if heavy else 6):
        streak(rows, rnd.randrange(size), 0, rnd.randrange(size // 3, size // 2),
               rnd.randrange(3, 10), (0.16, 0.14, 0.11), 0.35, rnd)
    blotches = 46 if heavy else 26
    for _ in range(blotches):
        cx = rnd.uniform(0, size)
        cy = rnd.uniform(size * 0.25, size) if rnd.random() < 0.6 else rnd.uniform(0, size)
        blotch(rows, height, cx, cy, rnd.uniform(14, 62 if heavy else 44),
               (0.10, 0.085, 0.065), rnd.uniform(0.35, 0.75), rnd, depth=0.25)
    for _ in range(blotches // 2):
        blotch(rows, height, rnd.uniform(0, size), rnd.uniform(0, size),
               rnd.uniform(8, 26), (0.20, 0.16, 0.10), 0.5, rnd, depth=0.15)
    # Descascados claros com borda escura.
    for _ in range(12 if heavy else 7):
        cx, cy = rnd.uniform(0, size), rnd.uniform(0, size)
        blotch(rows, height, cx, cy, rnd.uniform(8, 22), (0.68, 0.65, 0.58), 0.4, rnd, depth=-0.1)
    speckle(rows, height, rnd, 2600, (0.08, 0.07, 0.06), 0.5)
    speckle(rows, height, rnd, 900, (0.75, 0.72, 0.64), 0.35)
    save_maps("wall_heavy" if heavy else "wall", rows, height,
              rough_from(height, 0.88, 0.16, seed + 5), 1.6)


def tex_ceiling(size: int = 512) -> None:
    rnd = random.Random(41)
    rows, height = tint_noise(size, (0.66, 0.65, 0.60), 0.05, 41)
    for _ in range(5):  # anéis de infiltração
        cx, cy = rnd.uniform(0, size), rnd.uniform(0, size)
        for ring in range(3):
            r = 18 + ring * 9
            for t in range(90):
                a = t / 90 * math.tau
                blend_px(rows, int(cx + math.cos(a) * r), int(cy + math.sin(a) * r),
                         (0.45, 0.38, 0.28), 0.28)
    speckle(rows, height, rnd, 1500, (0.2, 0.18, 0.15), 0.3)
    save_maps("ceiling", rows, height, rough_from(height, 0.9, 0.1, 46), 0.8)


def tex_carpet(size: int = 1024) -> None:
    rnd = random.Random(97)
    rows, height = tint_noise(size, (0.335, 0.30, 0.255), 0.07, 97)
    # Fibras: ruído fino denso em dois tons.
    for _ in range(26000):
        x, y = rnd.randrange(size), rnd.randrange(size)
        tone = (0.42, 0.38, 0.31) if rnd.random() < 0.5 else (0.22, 0.20, 0.17)
        blend_px(rows, x, y, tone, 0.5)
    for _ in range(16):  # desgaste e manchas de tráfego
        blotch(rows, height, rnd.uniform(0, size), rnd.uniform(0, size),
               rnd.uniform(30, 95), (0.16, 0.145, 0.12), rnd.uniform(0.2, 0.42), rnd)
    for _ in range(5):
        blotch(rows, height, rnd.uniform(0, size), rnd.uniform(0, size),
               rnd.uniform(16, 40), (0.23, 0.10, 0.07), 0.35, rnd)  # manchas avermelhadas fracas
    save_maps("carpet", rows, height, rough_from(height, 0.97, 0.05, 99), 0.7)


def tex_cabinet(size: int = 512) -> None:
    rnd = random.Random(123)
    rows, height = tint_noise(size, (0.565, 0.585, 0.545), 0.07, 123)
    for _ in range(16):
        streak(rows, rnd.randrange(size), rnd.randrange(size // 2), rnd.randrange(40, 160),
               rnd.randrange(2, 6), (0.23, 0.24, 0.20), 0.3, rnd)
    speckle(rows, height, rnd, 2000, (0.16, 0.15, 0.12), 0.45)
    speckle(rows, height, rnd, 500, (0.72, 0.73, 0.68), 0.3)
    save_maps("cabinet", rows, height, rough_from(height, 0.62, 0.2, 125), 1.0)


def tex_enamel(size: int, seed: int, name: str, blood: bool) -> None:
    rnd = random.Random(seed)
    rows, height = tint_noise(size, (0.78, 0.78, 0.75), 0.05, seed)
    speckle(rows, height, rnd, 1500, (0.25, 0.23, 0.19), 0.4)
    for _ in range(10):
        streak(rows, rnd.randrange(size), rnd.randrange(size // 2), rnd.randrange(30, 120),
               rnd.randrange(2, 5), (0.35, 0.32, 0.27), 0.3, rnd)
    if blood:
        # Sangue: respingos densos na base e fios escorrendo do topo.
        for _ in range(30):
            blotch(rows, height, rnd.uniform(0, size), rnd.uniform(size * 0.78, size),
                   rnd.uniform(5, 26), (0.30, 0.05, 0.03), rnd.uniform(0.5, 0.9), rnd)
        for _ in range(9):
            streak(rows, rnd.randrange(size), 0, rnd.randrange(30, 130),
                   rnd.randrange(1, 3), (0.32, 0.05, 0.03), 0.65, rnd)
        for _ in range(500):
            x = rnd.randrange(size)
            y = int(size * 0.72 + rnd.random() ** 2 * size * 0.28)
            blend_px(rows, x, min(size - 1, y), (0.30, 0.04, 0.03), 0.7)
    save_maps(name, rows, height, rough_from(height, 0.34, 0.18, seed + 3), 0.8)


def tex_door_paint(size: int = 512) -> None:
    rnd = random.Random(77)
    rows, height = tint_noise(size, (0.72, 0.71, 0.67), 0.05, 77)
    speckle(rows, height, rnd, 1600, (0.3, 0.28, 0.24), 0.35)
    for _ in range(8):
        blotch(rows, height, rnd.uniform(0, size), rnd.uniform(size * 0.5, size),
               rnd.uniform(10, 30), (0.32, 0.28, 0.22), 0.35, rnd)
    save_maps("door_paint", rows, height, rough_from(height, 0.55, 0.15, 79), 0.9)


def tex_tile(size: int = 512) -> None:
    rnd = random.Random(55)
    rows, height = tint_noise(size, (0.55, 0.53, 0.45), 0.08, 55)
    tiles = 6
    step = size // tiles
    for ty in range(tiles):
        for tx in range(tiles):
            tint = rnd.uniform(-0.05, 0.05)
            for y in range(ty * step, (ty + 1) * step):
                for x in range(tx * step, (tx + 1) * step):
                    i = x * 3
                    rows[y][i] = clamp_byte(rows[y][i] + tint * 255)
                    rows[y][i + 1] = clamp_byte(rows[y][i + 1] + tint * 255)
                    rows[y][i + 2] = clamp_byte(rows[y][i + 2] + tint * 220)
    for y in range(size):  # rejunte escuro e mofado
        for x in range(size):
            if x % step < 3 or y % step < 3:
                blend_px(rows, x, y, (0.16, 0.15, 0.12), 0.85)
                height[y][x] -= 0.3
    for _ in range(24):
        blotch(rows, height, rnd.uniform(0, size), rnd.uniform(size * 0.4, size),
               rnd.uniform(10, 34), (0.13, 0.14, 0.08), rnd.uniform(0.3, 0.6), rnd)
    speckle(rows, height, rnd, 1500, (0.15, 0.14, 0.11), 0.4)
    save_maps("tile", rows, height, rough_from(height, 0.4, 0.25, 57), 1.4)


def tex_counter(size: int = 512) -> None:
    rnd = random.Random(66)
    rows, height = tint_noise(size, (0.20, 0.215, 0.20), 0.05, 66)
    speckle(rows, height, rnd, 5200, (0.45, 0.46, 0.42), 0.35, 1.4)
    speckle(rows, height, rnd, 900, (0.05, 0.05, 0.05), 0.5, 1.6)
    for _ in range(8):
        blotch(rows, height, rnd.uniform(0, size), rnd.uniform(0, size),
               rnd.uniform(12, 30), (0.10, 0.09, 0.07), 0.4, rnd)
    save_maps("counter", rows, height, rough_from(height, 0.38, 0.2, 68), 0.8)


def tex_rust(size: int = 512) -> None:
    rnd = random.Random(88)
    rows, height = tint_noise(size, (0.32, 0.19, 0.10), 0.12, 88)
    speckle(rows, height, rnd, 5200, (0.48, 0.26, 0.10), 0.6, 2.6)
    speckle(rows, height, rnd, 3200, (0.16, 0.09, 0.05), 0.6, 2.2)
    speckle(rows, height, rnd, 700, (0.62, 0.38, 0.16), 0.5, 1.6)
    save_maps("rust", rows, height, rough_from(height, 0.62, 0.3, 90), 1.8)


def tex_wood(size: int = 512) -> None:
    rnd = random.Random(33)
    rows, height = tint_noise(size, (0.36, 0.25, 0.15), 0.06, 33)
    for y in range(size):  # veios horizontais simples
        v = math.sin(y * 0.11 + noise_grid(size, 8, 35)[y][0] * 4.0) * 0.05
        for x in range(size):
            i = x * 3
            rows[y][i] = clamp_byte(rows[y][i] + v * 255)
            rows[y][i + 1] = clamp_byte(rows[y][i + 1] + v * 200)
    speckle(rows, height, rnd, 1200, (0.14, 0.09, 0.05), 0.5)
    save_maps("wood", rows, height, rough_from(height, 0.8, 0.15, 37), 1.0)


def tex_paper(size: int = 256) -> None:
    rows = base_rows(size, (0.82, 0.81, 0.76))
    height = [[0.0] * size for _ in range(size)]
    for y in range(40, size - 30, 18):  # linhas de pauta fracas
        for x in range(24, size - 24):
            blend_px(rows, x, y, (0.45, 0.48, 0.55), 0.5)
    rnd = random.Random(7)
    speckle(rows, height, rnd, 200, (0.4, 0.38, 0.33), 0.3)
    save_maps("paper", rows, height, rough_from(height, 0.9, 0.06, 9), 0.4)


def tex_stain_alpha(size: int = 256, rgb: tuple[int, int, int] = (70, 10, 6)) -> None:
    rnd = random.Random(15)
    rows: list[bytearray] = []
    for _ in range(size):
        rows.append(bytearray(size * 4))
    for _ in range(46):
        cx = size / 2 + rnd.uniform(-size * 0.3, size * 0.3)
        cy = size / 2 + rnd.uniform(-size * 0.3, size * 0.3)
        r = rnd.uniform(6, size * 0.24)
        for y in range(max(0, int(cy - r)), min(size, int(cy + r))):
            for x in range(max(0, int(cx - r)), min(size, int(cx + r))):
                d = math.hypot(x - cx, y - cy) / r
                if d < 1.0:
                    i = x * 4
                    a = int(190 * (1.0 - d) * rnd.uniform(0.6, 1.0))
                    if a > rows[y][i + 3]:
                        rows[y][i:i + 4] = bytes((rgb[0], rgb[1], rgb[2], a))
    write_png_rgba(TEX_DIR / "stain_alpha.png", rows)


def generate_textures() -> None:
    TEX_DIR.mkdir(parents=True, exist_ok=True)
    tex_wall(1024, 201, heavy=False)
    tex_wall(1024, 301, heavy=True)
    tex_ceiling()
    tex_carpet()
    tex_cabinet()
    tex_enamel(512, 401, "fridge_door", blood=True)
    tex_enamel(512, 421, "enamel", blood=False)
    tex_door_paint()
    tex_tile()
    tex_counter()
    tex_rust()
    tex_wood()
    tex_paper()
    tex_stain_alpha()
    print(f"Texturas: {len(list(TEX_DIR.glob('*.png')))} arquivos")


# ---------------------------------------------------------------------------
# Materiais
# ---------------------------------------------------------------------------

MATERIALS: dict[str, dict[str, object]] = {
    "wall": {"texture": "wall", "roughness": 0.92, "normal_scale": 0.7},
    "wall_heavy": {"texture": "wall_heavy", "roughness": 0.94, "normal_scale": 0.8},
    "ceiling": {"texture": "ceiling", "roughness": 0.92, "normal_scale": 0.4},
    "carpet": {"texture": "carpet", "roughness": 0.97, "normal_scale": 0.5},
    "cabinet": {"texture": "cabinet", "roughness": 0.62, "normal_scale": 0.6},
    "cabinet_dark": {"texture": "cabinet", "color": (0.30, 0.33, 0.31, 1), "roughness": 0.62, "normal_scale": 0.6},
    "counter": {"texture": "counter", "roughness": 0.38, "metallic": 0.05, "normal_scale": 0.5},
    "tile": {"texture": "tile", "roughness": 0.4, "normal_scale": 0.8},
    "fridge_door": {"texture": "fridge_door", "roughness": 0.32, "normal_scale": 0.4},
    "enamel": {"texture": "enamel", "roughness": 0.34, "normal_scale": 0.4},
    "door_paint": {"texture": "door_paint", "roughness": 0.55, "normal_scale": 0.5},
    "trim": {"texture": "door_paint", "color": (0.88, 0.86, 0.80, 1), "roughness": 0.5, "normal_scale": 0.4},
    "rust": {"texture": "rust", "roughness": 0.62, "metallic": 0.45, "normal_scale": 0.9},
    "wood": {"texture": "wood", "roughness": 0.8, "normal_scale": 0.6},
    "paper": {"texture": "paper", "roughness": 0.9, "normal_scale": 0.3},
    "chrome": {"color": (0.72, 0.76, 0.79, 1), "metallic": 0.95, "roughness": 0.22},
    "steel_dark": {"color": (0.16, 0.17, 0.18, 1), "metallic": 0.8, "roughness": 0.45},
    "brass": {"color": (0.48, 0.35, 0.18, 1), "metallic": 0.9, "roughness": 0.38},
    "iron_black": {"color": (0.05, 0.05, 0.055, 1), "metallic": 0.6, "roughness": 0.5},
    "glass_dark": {"color": (0.02, 0.025, 0.03, 1), "metallic": 0.2, "roughness": 0.08},
    "ceramic": {"color": (0.87, 0.86, 0.82, 1), "roughness": 0.28},
    "sticky": {"color": (0.85, 0.72, 0.25, 1), "roughness": 0.7},
    "skin": {"color": (0.64, 0.45, 0.36, 1), "roughness": 0.55},
    "blood": {"color": (0.26, 0.03, 0.02, 1), "roughness": 0.3},
    "coffee": {"color": (0.15, 0.08, 0.035, 1), "roughness": 0.15},
    "void": {"color": (0.004, 0.004, 0.005, 1), "roughness": 1.0},
    "diffuser_warm": {"color": (0.95, 0.88, 0.72, 1), "emission": (1.0, 0.84, 0.58, 1), "emission_energy": 2.6, "roughness": 0.5},
    "diffuser_cool": {"color": (0.90, 0.94, 1.0, 1), "emission": (0.84, 0.91, 1.0, 1), "emission_energy": 3.4, "roughness": 0.5},
    "strip_light": {"color": (0.92, 0.94, 0.86, 1), "emission": (0.95, 1.0, 0.82, 1), "emission_energy": 2.4, "roughness": 0.5},
    "red_hot": {"color": (0.20, 0.02, 0.01, 1), "emission": (1.0, 0.14, 0.03, 1), "emission_energy": 2.0, "roughness": 0.5},
    "board_pink": {"color": (0.60, 0.37, 0.32, 1), "roughness": 0.6},
    "stain": {"texture_alpha": "stain_alpha", "roughness": 0.35},
}


def fmt(value: float) -> str:
    if abs(value) < 5e-6:
        value = 0.0
    text = f"{value:.5f}".rstrip("0").rstrip(".")
    return text if text not in ("", "-0") else "0"


def color_text(color: tuple[float, ...]) -> str:
    return "Color(%s)" % ", ".join(fmt(float(c)) for c in color)


def write_materials() -> None:
    MAT_DIR.mkdir(parents=True, exist_ok=True)
    for name, spec in MATERIALS.items():
        lines = ["[gd_resource type=\"StandardMaterial3D\" format=3]", ""]
        texture = spec.get("texture")
        texture_alpha = spec.get("texture_alpha")
        if texture:
            lines.append("\n".join(
                f"[ext_resource type=\"Texture2D\" path=\"res://maps/reference/textures/{texture}_{suffix}.png\" id=\"tex_{label}\"]"
                for suffix, label in [("albedo", "albedo"), ("normal", "normal"), ("roughness", "roughness"), ("ao", "ao")]
            ))
            lines.append("")
        if texture_alpha:
            lines.append(f"[ext_resource type=\"Texture2D\" path=\"res://maps/reference/textures/{texture_alpha}.png\" id=\"tex_albedo\"]")
            lines.append("")
        lines.append("[resource]")
        if texture:
            lines.append("albedo_texture = ExtResource(\"tex_albedo\")")
            if "color" in spec:
                lines.append(f"albedo_color = {color_text(spec['color'])}")  # type: ignore[arg-type]
            lines.append("roughness_texture = ExtResource(\"tex_roughness\")")
            if "roughness" in spec:
                lines.append(f"roughness = {fmt(float(spec['roughness']))}")  # type: ignore[arg-type]
            lines.append("normal_enabled = true")
            lines.append("normal_texture = ExtResource(\"tex_normal\")")
            lines.append(f"normal_scale = {fmt(float(spec.get('normal_scale', 0.5)))}")
            lines.append("ao_enabled = true")
            lines.append("ao_texture = ExtResource(\"tex_ao\")")
            lines.append("ao_light_affect = 0.35")
        elif texture_alpha:
            lines.append("transparency = 1")
            lines.append("albedo_texture = ExtResource(\"tex_albedo\")")
            lines.append(f"roughness = {fmt(float(spec.get('roughness', 0.4)))}")  # type: ignore[arg-type]
        else:
            lines.append(f"albedo_color = {color_text(spec.get('color', (1, 1, 1, 1)))}")  # type: ignore[arg-type]
            lines.append(f"roughness = {fmt(float(spec.get('roughness', 0.7)))}")  # type: ignore[arg-type]
        lines.append(f"metallic = {fmt(float(spec.get('metallic', 0.0)))}")
        if "emission" in spec:
            lines.append("emission_enabled = true")
            lines.append(f"emission = {color_text(spec['emission'])}")  # type: ignore[arg-type]
            lines.append(f"emission_energy_multiplier = {fmt(float(spec.get('emission_energy', 1.0)))}")
        (MAT_DIR / f"{name}.tres").write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(f"Materiais: {len(MATERIALS)}")


# ---------------------------------------------------------------------------
# Construtor da cena
# ---------------------------------------------------------------------------


def basis_from_euler(euler: tuple[float, float, float]) -> tuple[float, ...]:
    """Base YXZ do Godot, gravada em ordem de LINHAS.

    O formato .tscn lê os 9 números como linhas da matriz; gravar as linhas
    faz os eixos efetivos no Godot serem exatamente os eixos calculados.
    """
    rx, ry, rz = euler
    cx, sx = math.cos(rx), math.sin(rx)
    cy, sy = math.cos(ry), math.sin(ry)
    cz, sz = math.cos(rz), math.sin(rz)
    x_axis = (cy * cz + sy * sx * sz, cx * sz, -sy * cz + cy * sx * sz)
    y_axis = (-cy * sz + sy * sx * cz, cx * cz, sy * sz + cy * sx * cz)
    z_axis = (sy * cx, -sx, cy * cx)
    return (x_axis[0], y_axis[0], z_axis[0],
            x_axis[1], y_axis[1], z_axis[1],
            x_axis[2], y_axis[2], z_axis[2])


class Builder:
    def __init__(self) -> None:
        self.nodes: list[str] = []
        self.mesh_ids: dict[tuple[object, ...], str] = {}
        self.shape_ids: dict[tuple[float, float, float], str] = {}
        self.subresources: list[str] = []
        self.counter = 0
        self.node_count = 0
        self._name_counts: dict[tuple[str, str], int] = {}

    def _next(self, prefix: str) -> str:
        self.counter += 1
        return f"{prefix}_{self.counter}"

    def _unique_name(self, parent: str, name: str) -> str:
        key = (parent, name)
        count = self._name_counts.get(key, 0) + 1
        self._name_counts[key] = count
        return name if count == 1 else f"{name}{count}"

    def group(self, name: str, parent: str = ".") -> str:
        unique = self._unique_name(parent, name)
        self.nodes.append(f"[node name=\"{unique}\" type=\"Node3D\" parent=\"{parent}\"]")
        self.node_count += 1
        return unique if parent == "." else f"{parent}/{unique}"

    def _mesh_id(self, key: tuple[object, ...], lines: list[str]) -> str:
        if key in self.mesh_ids:
            return self.mesh_ids[key]
        mesh_id = self._next("Mesh")
        self.mesh_ids[key] = mesh_id
        self.subresources.append(f"[sub_resource type=\"{lines[0]}\" id=\"{mesh_id}\"]\n" + "\n".join(lines[1:]))
        return mesh_id

    def box_mesh(self, size: tuple[float, float, float], material: str) -> str:
        key = ("BoxMesh", size, material)
        return self._mesh_id(key, ["BoxMesh", f"material = ExtResource(\"mat_{material}\")",
                                   f"size = Vector3({fmt(size[0])}, {fmt(size[1])}, {fmt(size[2])})"])

    def cyl_mesh(self, radius: float, height: float, material: str, segments: int = 24) -> str:
        key = ("CylinderMesh", radius, height, material, segments)
        return self._mesh_id(key, ["CylinderMesh", f"material = ExtResource(\"mat_{material}\")",
                                   f"top_radius = {fmt(radius)}", f"bottom_radius = {fmt(radius)}",
                                   f"height = {fmt(height)}", f"radial_segments = {segments}"])

    def sphere_mesh(self, radius: float, material: str, segments: int = 20) -> str:
        key = ("SphereMesh", radius, material, segments)
        return self._mesh_id(key, ["SphereMesh", f"material = ExtResource(\"mat_{material}\")",
                                   f"radius = {fmt(radius)}", f"height = {fmt(radius * 2)}",
                                   f"radial_segments = {segments}", f"rings = {segments // 2}"])

    def capsule_mesh(self, radius: float, height: float, material: str, segments: int = 16) -> str:
        key = ("CapsuleMesh", radius, height, material, segments)
        return self._mesh_id(key, ["CapsuleMesh", f"material = ExtResource(\"mat_{material}\")",
                                   f"radius = {fmt(radius)}", f"height = {fmt(height)}",
                                   f"radial_segments = {segments}", "rings = 8"])

    def torus_mesh(self, inner: float, outer: float, material: str) -> str:
        key = ("TorusMesh", inner, outer, material)
        return self._mesh_id(key, ["TorusMesh", f"material = ExtResource(\"mat_{material}\")",
                                   f"inner_radius = {fmt(inner)}", f"outer_radius = {fmt(outer)}",
                                   "rings = 12", "ring_segments = 6"])

    def node(self, name: str, kind: str, parent: str, pos: tuple[float, float, float],
             euler: tuple[float, float, float] = (0.0, 0.0, 0.0), extra: list[str] | None = None,
             scale: tuple[float, float, float] | None = None) -> None:
        basis = basis_from_euler(euler)
        if scale is not None:
            basis = tuple(basis[i] * scale[i // 3] if False else basis[i] for i in range(9))
            # escala aplicada por coluna (eixo)
            cols = [(basis[0], basis[3], basis[6]), (basis[1], basis[4], basis[7]), (basis[2], basis[5], basis[8])]
            scaled = []
            for c in range(3):
                scaled.extend([cols[0][c] * 1.0, cols[1][c] * 1.0, cols[2][c] * 1.0])
            basis = tuple(
                (cols[0][0] * scale[0], cols[1][0] * scale[1], cols[2][0] * scale[2],
                 cols[0][1] * scale[0], cols[1][1] * scale[1], cols[2][1] * scale[2],
                 cols[0][2] * scale[0], cols[1][2] * scale[1], cols[2][2] * scale[2])
            )
        values = ", ".join(fmt(v) for v in (*basis, *pos))
        unique = self._unique_name(parent, name)
        lines = [f"[node name=\"{unique}\" type=\"{kind}\" parent=\"{parent}\"]",
                 f"transform = Transform3D({values})"]
        if extra:
            lines.extend(extra)
        self.nodes.append("\n".join(lines))
        self.node_count += 1

    def box(self, name: str, parent: str, pos: tuple[float, float, float], size: tuple[float, float, float],
            material: str, euler: tuple[float, float, float] = (0.0, 0.0, 0.0)) -> None:
        mesh = self.box_mesh(size, material)
        self.node(name, "MeshInstance3D", parent, pos, euler, [f"mesh = SubResource(\"{mesh}\")"])

    def cyl(self, name: str, parent: str, pos: tuple[float, float, float], radius: float, height: float,
            material: str, euler: tuple[float, float, float] = (0.0, 0.0, 0.0), segments: int = 24) -> None:
        mesh = self.cyl_mesh(radius, height, material, segments)
        self.node(name, "MeshInstance3D", parent, pos, euler, [f"mesh = SubResource(\"{mesh}\")"])

    def sphere(self, name: str, parent: str, pos: tuple[float, float, float], radius: float, material: str,
               scale: tuple[float, float, float] | None = None, segments: int = 20) -> None:
        mesh = self.sphere_mesh(radius, material, segments)
        self.node(name, "MeshInstance3D", parent, pos, (0, 0, 0), [f"mesh = SubResource(\"{mesh}\")"], scale)

    def capsule(self, name: str, parent: str, pos: tuple[float, float, float], radius: float, height: float,
                material: str, euler: tuple[float, float, float] = (0.0, 0.0, 0.0)) -> None:
        mesh = self.capsule_mesh(radius, height, material)
        self.node(name, "MeshInstance3D", parent, pos, euler, [f"mesh = SubResource(\"{mesh}\")"])

    def torus(self, name: str, parent: str, pos: tuple[float, float, float], inner: float, outer: float,
              material: str, euler: tuple[float, float, float] = (0.0, 0.0, 0.0)) -> None:
        mesh = self.torus_mesh(inner, outer, material)
        self.node(name, "MeshInstance3D", parent, pos, euler, [f"mesh = SubResource(\"{mesh}\")"])

    def omni(self, name: str, parent: str, pos: tuple[float, float, float], color: tuple[float, float, float],
             energy: float, range_: float, attenuation: float = 1.1, shadow: bool = False) -> None:
        extra = [f"light_color = {color_text((*color, 1.0))}", f"light_energy = {fmt(energy)}",
                 f"omni_range = {fmt(range_)}", f"omni_attenuation = {fmt(attenuation)}",
                 f"shadow_enabled = {'true' if shadow else 'false'}"]
        self.node(name, "OmniLight3D", parent, pos, (0, 0, 0), extra)

    def spot(self, name: str, parent: str, pos: tuple[float, float, float], color: tuple[float, float, float],
             energy: float, range_: float, angle: float, shadow: bool = False,
             attenuation: float = 1.0) -> None:
        extra = [f"light_color = {color_text((*color, 1.0))}", f"light_energy = {fmt(energy)}",
                 f"spot_range = {fmt(range_)}", f"spot_angle = {fmt(angle)}",
                 f"spot_attenuation = {fmt(attenuation)}",
                 f"shadow_enabled = {'true' if shadow else 'false'}"]
        self.node(name, "SpotLight3D", parent, pos, (-math.pi / 2, 0, 0), extra)

    def collider(self, name: str, parent: str, pos: tuple[float, float, float],
                 size: tuple[float, float, float]) -> None:
        key = size
        if key not in self.shape_ids:
            shape_id = self._next("Shape")
            self.shape_ids[key] = shape_id
            self.subresources.append(
                f"[sub_resource type=\"BoxShape3D\" id=\"{shape_id}\"]\n"
                f"size = Vector3({fmt(size[0])}, {fmt(size[1])}, {fmt(size[2])})")
        unique = self._unique_name(parent, name)
        self.nodes.append(
            f"[node name=\"{unique}\" type=\"CollisionShape3D\" parent=\"{parent}\"]\n"
            f"transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, {fmt(pos[0])}, {fmt(pos[1])}, {fmt(pos[2])})\n"
            f"shape = SubResource(\"{self.shape_ids[key]}\")")
        self.node_count += 1


B = Builder()

# Sala: X [-3.6, 3.6], Z [-3.4, 3.0], pé-direito 2,75 m. Norte = -Z (cozinha).


def chain(parent: str, p0: tuple[float, float, float], p1: tuple[float, float, float],
          sag: float, name: str = "ChainLink") -> None:
    """Corrente de elos (toros alternados) entre dois pontos, com flecha."""
    dist = math.dist(p0, p1)
    steps = max(3, int(dist / 0.046))
    yaw = math.atan2(-(p1[0] - p0[0]), -(p1[2] - p0[2])) if abs(p1[0] - p0[0]) + abs(p1[2] - p0[2]) > 1e-6 else 0.0
    for i in range(steps + 1):
        t = i / steps
        x = p0[0] + (p1[0] - p0[0]) * t
        y = p0[1] + (p1[1] - p0[1]) * t - math.sin(t * math.pi) * sag
        z = p0[2] + (p1[2] - p0[2]) * t
        roll = (math.pi / 2) if i % 2 else 0.0
        B.torus(name, parent, (x, y, z), 0.013, 0.031, "rust", (roll, yaw, 0.0))


def padlock(parent: str, pos: tuple[float, float, float]) -> None:
    B.box("PadlockBody", parent, pos, (0.075, 0.095, 0.032), "brass")
    B.torus("PadlockShackle", parent, (pos[0], pos[1] + 0.065, pos[2]), 0.016, 0.034,
            "steel_dark", (0.0, math.pi / 2, 0.0))


def architecture() -> None:
    arch = B.group("Architecture")
    # Piso e teto.
    B.box("Floor", arch, (0, -0.06, -0.2), (7.35, 0.12, 6.55), "carpet")
    B.box("Ceiling", arch, (0, 2.81, -0.2), (7.35, 0.12, 6.55), "ceiling")
    # Parede oeste (porta em z=-0,8; vão 1,06 x 2,16).
    B.box("WallWestNorth", arch, (-3.6, 1.375, -2.365), (0.15, 2.75, 2.07), "wall_heavy")
    B.box("WallWestSouth", arch, (-3.6, 1.375, 1.365), (0.15, 2.75, 3.27), "wall_heavy")
    B.box("WallWestHeader", arch, (-3.6, 2.455, -0.8), (0.15, 0.59, 1.06), "wall_heavy")
    # Parede norte (cozinha) e sul (atrás da câmera).
    B.box("WallNorth", arch, (0, 1.375, -3.4), (7.35, 2.75, 0.15), "wall")
    B.box("WallSouth", arch, (0, 1.375, 3.0), (7.35, 2.75, 0.15), "wall")
    # Parede leste com vão escuro (z 1,25..2,25, altura 2,15).
    B.box("WallEastNorth", arch, (3.6, 1.375, -1.075), (0.15, 2.75, 4.65), "wall")
    B.box("WallEastSouth", arch, (3.6, 1.375, 2.625), (0.15, 2.75, 0.75), "wall")
    B.box("WallEastHeader", arch, (3.6, 2.45, 1.75), (0.15, 0.6, 1.0), "wall")
    # Cômodo escuro além do vão leste.
    dark = B.group("DarkRoom", arch)
    B.box("DarkBack", dark, (5.15, 1.375, 1.75), (0.15, 2.75, 2.6), "void")
    B.box("DarkSideA", dark, (4.4, 1.375, 0.5), (1.7, 2.75, 0.15), "void")
    B.box("DarkSideB", dark, (4.4, 1.375, 3.0), (1.7, 2.75, 0.15), "void")
    B.box("DarkFloor", dark, (4.4, -0.03, 1.75), (1.7, 0.06, 2.6), "void")
    B.box("DarkCeiling", dark, (4.4, 2.78, 1.75), (1.7, 0.06, 2.6), "void")
    B.box("DarkDoorFrame", arch, (3.58, 1.1, 1.75), (0.1, 2.2, 1.1), "trim")
    # Coluna/pilastra pesada junto à parede norte (canto da porta).
    B.box("Column", arch, (-2.52, 1.375, -3.06), (0.66, 2.75, 0.68), "wall_heavy")
    # Rodapés e moldura de teto (sanca em dois degraus).
    for name, pos, size in [
        ("BaseWest", (-3.51, 0.065, 0.3), (0.025, 0.13, 5.6)),
        ("BaseNorth", (-0.1, 0.065, -3.31), (6.9, 0.13, 0.025)),
        ("BaseEast", (3.51, 0.065, -0.6), (0.025, 0.13, 4.6)),
        ("BaseSouth", (0, 0.065, 2.91), (7.2, 0.13, 0.025)),
        ("BaseColumnA", (-2.18, 0.065, -3.06), (0.025, 0.13, 0.68)),
        ("BaseColumnB", (-2.52, 0.065, -2.71), (0.66, 0.13, 0.025)),
    ]:
        B.box(name, arch, pos, size, "trim")
    for name, pos, size in [
        ("CrownWest", (-3.53, 2.60, -0.2), (0.09, 0.11, 6.4)),
        ("CrownWestTop", (-3.55, 2.70, -0.2), (0.05, 0.07, 6.4)),
        ("CrownNorth", (0, 2.60, -3.33), (7.2, 0.11, 0.09)),
        ("CrownNorthTop", (0, 2.70, -3.35), (7.2, 0.07, 0.05)),
        ("CrownEast", (3.53, 2.60, -0.2), (0.09, 0.11, 6.4)),
        ("CrownSouth", (0, 2.60, 2.93), (7.2, 0.11, 0.09)),
        ("CrownColumn", (-2.52, 2.60, -3.06), (0.74, 0.11, 0.76)),
    ]:
        B.box(name, arch, pos, size, "trim")

    door = B.group("ChainedDoor", arch)
    # Batente e folha com painéis em relevo.
    B.box("DoorJambA", door, (-3.55, 1.08, -1.36), (0.1, 2.16, 0.09), "trim")
    B.box("DoorJambB", door, (-3.55, 1.08, -0.24), (0.1, 2.16, 0.09), "trim")
    B.box("DoorHead", door, (-3.55, 2.19, -0.8), (0.1, 0.09, 1.21), "trim")
    B.box("DoorSlab", door, (-3.56, 1.08, -0.8), (0.055, 2.16, 1.04), "door_paint")
    B.box("DoorPanelTop", door, (-3.52, 1.52, -0.8), (0.02, 0.86, 0.74), "door_paint")
    B.box("DoorPanelTopIn", door, (-3.515, 1.52, -0.8), (0.012, 0.68, 0.58), "door_paint")
    B.box("DoorPanelBottom", door, (-3.52, 0.52, -0.8), (0.02, 0.72, 0.74), "door_paint")
    B.box("DoorPanelBottomIn", door, (-3.515, 0.52, -0.8), (0.012, 0.54, 0.58), "door_paint")
    # Maçaneta esférica de latão e dobradiças.
    B.cyl("KnobStem", door, (-3.50, 1.02, -0.36), 0.011, 0.05, "brass", (0, 0, math.pi / 2), 12)
    B.sphere("Knob", door, (-3.465, 1.02, -0.36), 0.033, "brass", segments=16)
    B.box("HingeA", door, (-3.52, 1.72, -1.30), (0.015, 0.11, 0.03), "steel_dark")
    B.box("HingeB", door, (-3.52, 0.48, -1.30), (0.015, 0.11, 0.03), "steel_dark")
    # Placas de ancoragem enferrujadas (parede e folha).
    anchors = {
        "AnchorWallN": (-3.49, 1.80, -1.55),
        "AnchorDoorTop": (-3.49, 1.68, -0.82),
        "AnchorWallS": (-3.49, 1.74, -0.05),
        "AnchorDoorMid": (-3.49, 1.16, -1.04),
        "AnchorDoorLow": (-3.49, 0.76, -0.56),
        "AnchorWallLow": (-3.49, 0.98, -1.58),
        "AnchorDoorBottom": (-3.49, 0.40, -0.28),
    }
    for name, pos in anchors.items():
        B.box(name, door, pos, (0.045, 0.17, 0.17), "rust")
        B.cyl("AnchorBolt", door, (pos[0] + 0.03, pos[1], pos[2]), 0.016, 0.03, "steel_dark",
              (0, 0, math.pi / 2), 10)
    front = -3.44
    chain(door, (front, 1.80, -1.55), (front, 1.68, -0.82), 0.10)
    chain(door, (front, 1.68, -0.82), (front, 1.74, -0.05), 0.09)
    chain(door, (front, 1.16, -1.04), (front, 0.76, -0.56), 0.13)
    chain(door, (front, 0.98, -1.58), (front, 0.40, -0.28), 0.15)
    padlock(door, (-3.42, 1.02, -1.04))
    padlock(door, (-3.42, 0.62, -0.56))
    # Corrente pendurada na face da coluna.
    B.box("AnchorColumn", door, (-2.17, 2.0, -3.0), (0.045, 0.15, 0.15), "rust")
    chain(door, (-2.14, 1.98, -3.0), (-2.14, 1.22, -3.0), 0.0)
    # Interruptor ao lado da porta.
    B.box("SwitchPlate", door, (-3.505, 1.27, 0.22), (0.018, 0.125, 0.08), "ceramic")
    B.box("SwitchToggle", door, (-3.495, 1.27, 0.22), (0.012, 0.035, 0.02), "ceramic")


def cabinet_door(parent: str, cx: float, cy: float, w: float, h: float, z: float,
                 handle: str = "vertical") -> None:
    B.box("CabinetDoor", parent, (cx, cy, z), (w, h, 0.022), "cabinet")
    B.box("CabinetDoorPanel", parent, (cx, cy, z + 0.008), (w - 0.09, h - 0.09, 0.012), "cabinet")
    if handle == "vertical":
        B.cyl("DoorHandle", parent, (cx + w / 2 - 0.045, cy + h / 2 - 0.14, z + 0.03),
              0.008, 0.15, "brass", (0, 0, 0), 10)
    else:
        B.cyl("DrawerPull", parent, (cx, cy + 0.02, z + 0.03), 0.009, 0.16, "brass",
              (0, 0, math.pi / 2), 10)


def kitchen() -> None:
    kit = B.group("Kitchen")
    run = B.group("CounterRun", kit)
    # Bancada contínua e rodabancada de azulejos.
    B.box("Countertop", run, (1.20, 0.922, -3.05), (4.44, 0.05, 0.68), "counter")
    B.box("Backsplash", run, (1.20, 1.21, -3.365), (4.44, 0.55, 0.03), "tile")
    # Módulos inferiores: portas, pia, gavetas e portas.
    units = [(-1.02, -0.02, "doors"), (-0.02, 1.03, "sink"), (1.03, 1.58, "doors"),
             (1.58, 2.13, "drawers"), (2.88, 3.42, "doors")]
    for x0, x1, kind in units:
        cx, w = (x0 + x1) / 2, x1 - x0
        B.box("BaseCabinet", run, (cx, 0.47, -3.07), (w - 0.02, 0.82, 0.62), "cabinet_dark")
        B.box("ToeKick", run, (cx, 0.045, -3.10), (w - 0.06, 0.09, 0.52), "iron_black")
        if kind == "doors":
            cabinet_door(run, cx - w / 4 + 0.01, 0.50, w / 2 - 0.03, 0.74, -2.745)
            cabinet_door(run, cx + w / 4 - 0.01, 0.50, w / 2 - 0.03, 0.74, -2.745)
        elif kind == "drawers":
            for i, dy in enumerate((0.72, 0.47, 0.22)):
                B.box("DrawerFront", run, (cx, dy, -2.745), (w - 0.05, 0.21, 0.022), "cabinet")
                B.cyl("DrawerPull", run, (cx, dy + 0.03, -2.715), 0.009, 0.17, "brass",
                      (0, 0, math.pi / 2), 10)
        else:  # pia: frente falsa + cuba e torneira
            B.box("SinkFront", run, (cx, 0.62, -2.745), (w - 0.05, 0.42, 0.022), "cabinet")
            cabinet_door(run, cx - w / 4 + 0.01, 0.24, w / 2 - 0.03, 0.30, -2.745)
            cabinet_door(run, cx + w / 4 - 0.01, 0.24, w / 2 - 0.03, 0.30, -2.745)
    # Cuba de aço e torneira pescoço de ganso.
    B.box("SinkBasin", run, (0.50, 0.885, -3.05), (0.86, 0.13, 0.46), "steel_dark")
    B.box("SinkRim", run, (0.50, 0.952, -3.05), (0.92, 0.012, 0.52), "chrome")
    B.cyl("FaucetBase", run, (0.50, 0.975, -3.27), 0.026, 0.05, "chrome", segments=16)
    B.cyl("FaucetPost", run, (0.50, 1.10, -3.27), 0.015, 0.22, "chrome", segments=12)
    B.torus("FaucetNeck", run, (0.50, 1.21, -3.19), 0.062, 0.094, "chrome", (0, math.pi / 2, 0))
    B.cyl("FaucetTip", run, (0.50, 1.16, -3.11), 0.011, 0.07, "chrome", segments=10)
    B.box("FaucetLever", run, (0.56, 1.02, -3.27), (0.09, 0.015, 0.03), "chrome")
    # Armários aéreos (corridos; sobre o fogão, mais curtos e altos).
    wall_units = [(-1.02, 0.0), (0.0, 1.03), (1.03, 2.13), (2.88, 3.42)]
    for x0, x1 in wall_units:
        cx, w = (x0 + x1) / 2, x1 - x0
        B.box("WallCabinet", run, (cx, 1.98, -3.19), (w - 0.02, 0.92, 0.38), "cabinet_dark")
        cabinet_door(run, cx - w / 4 + 0.01, 1.98, w / 2 - 0.03, 0.86, -2.995)
        cabinet_door(run, cx + w / 4 - 0.01, 1.98, w / 2 - 0.03, 0.86, -2.995)
    B.box("WallCabinetStove", run, (2.505, 2.11, -3.19), (0.73, 0.66, 0.38), "cabinet_dark")
    cabinet_door(run, 2.32, 2.11, 0.33, 0.60, -2.995)
    cabinet_door(run, 2.69, 2.11, 0.33, 0.60, -2.995)
    # Fita de luz sob o armário da pia.
    B.box("SinkLightStrip", run, (0.50, 1.505, -3.10), (0.95, 0.02, 0.06), "strip_light")
    # Trilho com ganchos sob os armários (à direita da pia).
    B.cyl("HookRail", run, (2.45, 1.46, -3.28), 0.008, 0.80, "steel_dark", (0, 0, math.pi / 2), 8)
    for hx in (2.20, 2.45, 2.70):
        B.torus("Hook", run, (hx, 1.415, -3.28), 0.012, 0.030, "steel_dark", (0, 0, 0))

    # Geladeira: corpo, frente única com textura (sangue), divisão e puxadores.
    fridge = B.group("Refrigerator", kit)
    B.box("FridgeBody", fridge, (-1.58, 0.97, -3.01), (0.96, 1.94, 0.78), "enamel")
    B.box("FridgeFront", fridge, (-1.58, 0.97, -2.615), (0.92, 1.88, 0.02), "fridge_door")
    B.box("FridgeSplit", fridge, (-1.58, 1.40, -2.60), (0.92, 0.016, 0.008), "iron_black")
    B.cyl("FridgeHandleTop", fridge, (-1.16, 1.62, -2.585), 0.011, 0.34, "chrome", segments=10)
    B.cyl("FridgeHandleBottom", fridge, (-1.16, 0.95, -2.585), 0.011, 0.52, "chrome", segments=10)
    B.box("FridgePhoto", fridge, (-1.80, 1.66, -2.598), (0.10, 0.13, 0.004), "paper", (0, 0, 0.06))
    B.box("FridgeNoteA", fridge, (-1.70, 1.47, -2.598), (0.075, 0.075, 0.004), "sticky", (0, 0, -0.05))
    B.box("FridgeNoteB", fridge, (-1.76, 1.35, -2.598), (0.07, 0.07, 0.004), "sticky", (0, 0, 0.04))
    B.cyl("FridgeMagnet", fridge, (-1.86, 1.80, -2.60), 0.012, 0.008, "red_hot", (math.pi / 2, 0, 0), 10)
    # Objeto escuro avermelhado sobre a bancada ao lado da geladeira.
    B.box("CounterBoxDark", kit, (-0.72, 1.03, -3.18), (0.42, 0.17, 0.30), "board_pink")
    B.box("CounterBoxLid", kit, (-0.72, 1.125, -3.18), (0.44, 0.025, 0.32), "steel_dark")

    # Fogão: corpo esmaltado, painel com botões, forno, bocas e chaleira.
    stove = B.group("Stove", kit)
    B.box("StoveBody", stove, (2.505, 0.45, -3.05), (0.75, 0.86, 0.66), "enamel")
    B.box("StoveTop", stove, (2.505, 0.885, -3.05), (0.75, 0.025, 0.66), "iron_black")
    B.box("StovePanel", stove, (2.505, 0.79, -2.715), (0.75, 0.13, 0.02), "enamel")
    for i, kx in enumerate((2.28, 2.42, 2.56, 2.70)):
        B.cyl("StoveKnob", stove, (kx, 0.79, -2.695), 0.027, 0.025, "iron_black", (math.pi / 2, 0, 0), 14)
    B.box("StoveIndicator", stove, (2.80, 0.79, -2.70), (0.018, 0.018, 0.008), "red_hot")
    B.box("OvenDoor", stove, (2.505, 0.40, -2.715), (0.68, 0.56, 0.025), "enamel")
    B.box("OvenWindow", stove, (2.505, 0.44, -2.70), (0.52, 0.30, 0.012), "glass_dark")
    B.cyl("OvenHandle", stove, (2.505, 0.735, -2.68), 0.013, 0.62, "chrome", (0, 0, math.pi / 2), 12)
    for bx, bz, br in ((2.32, -3.20, 0.095), (2.69, -3.20, 0.075), (2.32, -2.92, 0.075), (2.69, -2.92, 0.09)):
        B.cyl("Burner", stove, (bx, 0.905, bz), br, 0.018, "iron_black", segments=20)
    B.cyl("BurnerHot", stove, (2.32, 0.912, -2.92), 0.062, 0.008, "red_hot", segments=20)
    # Chaleira sobre a boca traseira direita.
    B.sphere("KettleBody", stove, (2.69, 0.975, -3.20), 0.088, "steel_dark",
             scale=(1.0, 0.78, 1.0), segments=20)
    B.cyl("KettleLid", stove, (2.69, 1.045, -3.20), 0.035, 0.02, "iron_black", segments=14)
    B.cyl("KettleSpout", stove, (2.775, 0.99, -3.20), 0.013, 0.09, "steel_dark", (0, 0, -0.8), 10)
    B.torus("KettleHandle", stove, (2.69, 1.03, -3.20), 0.038, 0.058, "iron_black", (0, 0, 0))

    # Micro-ondas e torradeira sobre a bancada.
    micro = B.group("Microwave", kit)
    B.box("MicrowaveBody", micro, (1.30, 1.125, -3.12), (0.57, 0.35, 0.40), "enamel")
    B.box("MicrowaveDoor", micro, (1.175, 1.125, -2.915), (0.36, 0.27, 0.015), "glass_dark")
    B.box("MicrowavePanel", micro, (1.475, 1.125, -2.915), (0.13, 0.27, 0.015), "steel_dark")
    for i in range(3):
        B.box("MicrowaveButton", micro, (1.475, 1.19 - i * 0.05, -2.905), (0.07, 0.018, 0.008), "iron_black")
    B.box("Toaster", kit, (1.80, 1.03, -3.16), (0.27, 0.17, 0.26), "steel_dark")
    B.box("ToasterSlot", kit, (1.80, 1.12, -3.16), (0.20, 0.012, 0.05), "iron_black")
    # Forno elétrico e potes à direita do fogão.
    B.box("ToasterOven", kit, (3.13, 1.06, -3.14), (0.44, 0.23, 0.34), "steel_dark")
    B.box("ToasterOvenDoor", kit, (3.13, 1.05, -2.965), (0.38, 0.16, 0.015), "glass_dark")
    B.box("ToasterOvenGlow", kit, (3.13, 0.99, -2.955), (0.30, 0.012, 0.006), "red_hot")
    B.cyl("CanisterA", kit, (3.30, 1.06, -3.26), 0.055, 0.23, "steel_dark", segments=16)
    B.cyl("CanisterB", kit, (3.17, 1.03, -3.30), 0.048, 0.17, "iron_black", segments=16)
    # Itens junto à pia: pratos, tábua e papel toalha.
    for i in range(3):
        B.cyl("Plate", kit, (-0.28, 0.955 + i * 0.02, -3.08), 0.115, 0.016, "ceramic", segments=24)
    B.box("CuttingBoard", kit, (0.16, 1.10, -3.26), (0.25, 0.33, 0.016), "board_pink", (-0.22, 0, 0))
    B.cyl("TowelBase", kit, (0.90, 0.952, -3.12), 0.07, 0.012, "steel_dark", segments=18)
    B.cyl("TowelRoll", kit, (0.90, 1.10, -3.12), 0.056, 0.27, "ceramic", segments=20)


def island_and_props() -> None:
    isl = B.group("Island")
    B.box("IslandPlinth", isl, (1.30, 0.045, 1.05), (2.34, 0.09, 0.84), "iron_black")
    B.box("IslandBody", isl, (1.30, 0.50, 1.05), (2.50, 0.82, 0.98), "cabinet_dark")
    for i, dx in enumerate((-0.80, 0.0, 0.80)):
        B.box("IslandDoor", isl, (1.30 + dx, 0.52, 1.545), (0.72, 0.66, 0.02), "cabinet_dark")
        B.cyl("IslandHandle", isl, (1.30 + dx + 0.28, 0.74, 1.565), 0.008, 0.13, "brass", (0, 0, 0), 10)
    B.box("IslandTop", isl, (1.30, 0.937, 1.05), (2.68, 0.055, 1.16), "counter")
    # Xícara caída com café derramado e folha de papel.
    cup = B.group("FallenCup", isl)
    B.cyl("Cup", cup, (0.55, 0.997, 0.82), 0.036, 0.095, "ceramic", (0, 0, math.pi / 2), 20)
    B.cyl("CupBottom", cup, (0.505, 0.997, 0.82), 0.030, 0.006, "coffee", (0, 0, math.pi / 2), 20)
    B.torus("CupHandle", cup, (0.575, 1.0, 0.865), 0.010, 0.024, "ceramic", (math.pi / 2, 0, 0))
    B.cyl("CoffeeSpill", isl, (0.66, 0.967, 0.86), 0.085, 0.004, "coffee", segments=24)
    B.box("PaperSheet", isl, (2.02, 0.968, 1.22), (0.21, 0.003, 0.297), "paper", (0, 0.42, 0))
    # Braço no carpete, diante da ilha.
    arm = B.group("ArmOnFloor")
    B.capsule("Forearm", arm, (0.28, 0.045, 1.98), 0.042, 0.30, "skin", (0.25, 0.65, 1.35))
    B.cyl("ArmCut", arm, (0.135, 0.05, 2.10), 0.043, 0.012, "blood", (0.25, 0.65, 1.35), 16)
    B.box("HandPalm", arm, (0.47, 0.028, 1.80), (0.085, 0.024, 0.175), "skin", (0, 0.65, 0))
    for i, (fx, fl) in enumerate(((-0.033, 0.062), (-0.011, 0.075), (0.011, 0.072), (0.033, 0.058))):
        B.capsule("Finger", arm, (0.47 + fx, 0.026, 1.685), 0.0105, fl, "skin",
                  (1.25, 0.65, fx * 2.0), )
    B.capsule("Thumb", arm, (0.415, 0.026, 1.76), 0.010, 0.05, "skin", (0.9, 0.65, 0.8))
    B.cyl("BloodStain", arm, (0.30, 0.006, 1.95), 0.21, 0.004, "stain", segments=24)
    # Moscas paradas no ar (pontos escuros perto das luzes).
    flies = B.group("Flies")
    rnd = random.Random(4)
    for _ in range(9):
        B.sphere("Fly", flies, (rnd.uniform(-3.1, -1.8), rnd.uniform(1.9, 2.6),
                                rnd.uniform(-1.5, 0.1)), 0.0075, "iron_black", segments=8)
    for _ in range(7):
        B.sphere("Fly", flies, (rnd.uniform(0.4, 2.1), rnd.uniform(2.1, 2.6),
                                rnd.uniform(-1.4, -0.2)), 0.0075, "iron_black", segments=8)


def lights_and_collisions() -> None:
    lights = B.group("Lighting")
    # Luminária redonda quente sobre a porta.
    B.cyl("WarmFixtureBase", lights, (-2.45, 2.735, -0.75), 0.15, 0.035, "steel_dark", segments=24)
    B.sphere("WarmDome", lights, (-2.45, 2.715, -0.75), 0.125, "diffuser_warm",
             scale=(1.0, 0.55, 1.0), segments=24)
    B.omni("WarmCeilingLight", lights, (-2.45, 2.38, -0.75), (1.0, 0.82, 0.58), 1.5, 7.5, 1.1, False)
    # Painel fluorescente frio sobre a cozinha.
    B.box("FluoroHousing", lights, (1.25, 2.725, -0.85), (1.34, 0.06, 0.38), "iron_black")
    B.box("FluoroPanel", lights, (1.25, 2.69, -0.85), (1.26, 0.025, 0.31), "diffuser_cool")
    B.spot("FluoroLight", lights, (1.25, 2.58, -0.85), (0.82, 0.90, 1.0), 3.4, 8.5, 76, True, 0.9)
    B.omni("FluoroFill", lights, (1.25, 2.42, -0.85), (0.82, 0.90, 1.0), 0.55, 6.5, 1.1, False)
    # Luz de trabalho da pia.
    B.spot("SinkLight", lights, (0.50, 1.48, -2.92), (0.92, 1.0, 0.84), 1.15, 2.8, 58, False, 1.0)

    collision = B.group("Collision")
    B.nodes.append("[node name=\"StaticBodies\" type=\"StaticBody3D\" parent=\"Collision\"]")
    B.node_count += 1
    body = "Collision/StaticBodies"
    B.collider("Floor", body, (0, -0.11, -0.2), (7.35, 0.22, 6.55))
    B.collider("Ceiling", body, (0, 2.90, -0.2), (7.35, 0.2, 6.55))
    B.collider("WallWest", body, (-3.72, 1.4, -0.2), (0.3, 2.8, 6.55))
    B.collider("WallNorth", body, (0, 1.4, -3.52), (7.35, 2.8, 0.3))
    B.collider("WallSouth", body, (0, 1.4, 3.12), (7.35, 2.8, 0.3))
    B.collider("WallEastA", body, (3.72, 1.4, -1.05), (0.3, 2.8, 4.7))
    B.collider("WallEastB", body, (3.72, 1.4, 2.65), (0.3, 2.8, 0.8))
    B.collider("Column", body, (-2.52, 1.4, -3.06), (0.7, 2.8, 0.72))
    B.collider("Fridge", body, (-1.58, 0.97, -3.01), (1.0, 1.94, 0.82))
    B.collider("CounterRun", body, (1.20, 0.47, -3.06), (4.5, 0.94, 0.7))
    B.collider("Island", body, (1.30, 0.48, 1.05), (2.56, 0.96, 1.04))


def build_scene() -> None:
    REF.mkdir(parents=True, exist_ok=True)
    architecture()
    kitchen()
    island_and_props()
    lights_and_collisions()
    # Spawn no canto sudeste, olhando para a porta/cozinha (yaw ~0,77 rad).
    # Ordem gravada = linhas da base (X=(c,0,-s), Y=(0,1,0), Z=(s,0,c)).
    B.nodes.append("[node name=\"Spawn\" type=\"Marker3D\" parent=\".\"]\n"
                   "transform = Transform3D(0.718, 0, 0.696, 0, 1, 0, -0.696, 0, 0.718, 2.95, 0.05, 2.70)")
    B.node_count += 1

    ext_lines = []
    for name in MATERIALS:
        ext_lines.append(f"[ext_resource type=\"StandardMaterial3D\" path=\"res://maps/reference/materials/{name}.tres\" id=\"mat_{name}\"]")
    env = """[sub_resource type="Environment" id="Env_kitchen"]
background_mode = 1
background_color = Color(0.008, 0.008, 0.010, 1)
ambient_light_source = 2
ambient_light_color = Color(0.30, 0.33, 0.38, 1)
ambient_light_energy = 0.38
tonemap_mode = 2
adjustment_enabled = true
adjustment_brightness = 0.94
adjustment_contrast = 1.07
adjustment_saturation = 0.80"""
    world = "[node name=\"WorldEnvironment\" type=\"WorldEnvironment\" parent=\".\"]\nenvironment = SubResource(\"Env_kitchen\")"
    load_steps = len(MATERIALS) + len(B.subresources) + 2
    header = f"[gd_scene load_steps={load_steps} format=3]\n\n" + "\n".join(ext_lines) + "\n\n" + env + "\n\n" + "\n\n".join(B.subresources)
    scene = header + "\n\n[node name=\"KitchenReference\" type=\"Node3D\"]\n\n" + "\n\n".join(B.nodes) + "\n\n" + world + "\n"
    SCENE_PATH.write_text(scene, encoding="utf-8")
    print(f"Cena gerada: {SCENE_PATH.relative_to(ROOT)}")
    print(f"Nós declarados (incl. raiz): {B.node_count + 1}")
    print(f"Malhas reutilizáveis: {len(B.mesh_ids)}; formas de colisão: {len(B.shape_ids)}")


def main() -> None:
    generate_textures()
    write_materials()
    build_scene()


if __name__ == "__main__":
    main()
