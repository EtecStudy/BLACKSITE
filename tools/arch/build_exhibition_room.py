#!/usr/bin/env python3
"""Gera a Sala de Exibição do Kit Visual do Black Sight.

Espaço neutro e espaçoso (showroom técnico de 32 x 14 m) para avaliar
individualmente os elementos do kit visual do jogo. Nesta etapa:

- piso de teste (vinílico de laboratório, 6 x 4 m, embutido no piso neutro);
- parede de teste (painéis compostos de 6 m com junções e rodapé);
- teto de teste (trecho de 4,8 x 3,6 m com estrutura, perfis e suportes);
- iluminação neutra inicial apenas para avaliação dos materiais.

Uso:
    python3 tools/arch/build_exhibition_room.py

Saídas:
    maps/exhibition/textures/*.png
    maps/exhibition/materials/*.tres
    maps/exhibition/exhibition_room.tscn
"""

from __future__ import annotations

import math
import random
import struct
import zlib
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
REF = ROOT / "maps" / "exhibition"
TEX_DIR = REF / "textures"
MAT_DIR = REF / "materials"
SCENE_PATH = REF / "exhibition_room.tscn"

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
            shade = clamp_byte((0.78 + height[y][x] * 0.4) * 255)
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


def blend_px(rows: list[bytearray], x: int, y: int, rgb: tuple[float, float, float], alpha: float) -> None:
    if 0 <= y < len(rows) and 0 <= x < len(rows[0]) // 3:
        i = x * 3
        for c in range(3):
            rows[y][i + c] = clamp_byte(rows[y][i + c] * (1.0 - alpha) + rgb[c] * 255 * alpha)


def speckle(rows: list[bytearray], height: list[list[float]], rnd: random.Random,
            count: int, rgb: tuple[float, float, float], alpha: float, max_r: float = 1.8) -> None:
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
                    height[yy][xx] += rnd.uniform(-0.02, 0.02)


def rough_from(height: list[list[float]], base: float, vary: float, seed: int) -> list[bytearray]:
    size = len(height)
    n = combined_noise(size, seed)
    rows: list[bytearray] = []
    for y in range(size):
        row = bytearray()
        for x in range(size):
            v = clamp_byte((base + (n[y][x] - 0.5) * vary + height[y][x] * 0.05) * 255)
            row += bytes((v, v, v))
        rows.append(row)
    return rows


def tint_noise(size: int, base: tuple[float, float, float], amp: float, seed: int):
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
# Texturas
# ---------------------------------------------------------------------------


def tex_showroom_floor(size: int = 512) -> None:
    """Piso neutro da galeria: concreto fosco cinza, sem protagonismo."""
    rnd = random.Random(11)
    rows, height = tint_noise(size, (0.30, 0.305, 0.31), 0.05, 11)
    speckle(rows, height, rnd, 2600, (0.16, 0.16, 0.17), 0.35, 1.6)
    speckle(rows, height, rnd, 1200, (0.48, 0.48, 0.49), 0.25, 1.4)
    save_maps("showroom_floor", rows, height, rough_from(height, 0.85, 0.12, 13), 0.8)


def tex_showroom_wall(size: int = 512) -> None:
    """Parede neutra da galeria: pintura lisa cinza-clara."""
    rnd = random.Random(21)
    rows, height = tint_noise(size, (0.60, 0.61, 0.62), 0.035, 21)
    speckle(rows, height, rnd, 900, (0.4, 0.4, 0.41), 0.2, 1.4)
    save_maps("showroom_wall", rows, height, rough_from(height, 0.9, 0.08, 23), 0.6)


def tex_kit_floor(size: int = 1024) -> None:
    """KIT — piso vinílico de laboratório (protótipo do piso do jogo).

    Textura desenhada para uma placa de 6 m (costuras soldadas a cada 2 m
    no eixo X): vinil cinza quente com speckle fino de duas tonalidades,
    marmoramento suave e linhas de solda levemente mais escuras.
    """
    rnd = random.Random(31)
    rows, height = tint_noise(size, (0.515, 0.52, 0.50), 0.045, 31)
    # Variação de tom por folha (3 folhas de 2 m).
    for sheet in range(3):
        delta = rnd.uniform(-0.022, 0.022)
        x0 = sheet * size // 3
        x1 = (sheet + 1) * size // 3
        for y in range(size):
            for x in range(x0, x1):
                i = x * 3
                rows[y][i] = clamp_byte(rows[y][i] + delta * 255)
                rows[y][i + 1] = clamp_byte(rows[y][i + 1] + delta * 255)
                rows[y][i + 2] = clamp_byte(rows[y][i + 2] + delta * 235)
    # Speckle mineral fino, típico de vinil homogêneo.
    speckle(rows, height, rnd, 21000, (0.40, 0.41, 0.395), 0.4, 1.3)
    speckle(rows, height, rnd, 15000, (0.64, 0.645, 0.62), 0.35, 1.3)
    speckle(rows, height, rnd, 2600, (0.30, 0.315, 0.31), 0.3, 1.2)
    # Costuras soldadas a cada 2 m (X) e uma transversal central.
    for sx in (size // 3, 2 * size // 3):
        for y in range(size):
            for dx in (-1, 0, 1):
                blend_px(rows, sx + dx, y, (0.335, 0.34, 0.325), 0.8 if dx == 0 else 0.45)
                height[y][sx + dx] -= 0.16
    for x in range(size):
        blend_px(rows, x, size // 2, (0.335, 0.34, 0.325), 0.6)
        height[size // 2][x] -= 0.13
    # Desgaste leve no centro (tráfego).
    for _ in range(7000):
        x = int(size / 2 + rnd.gauss(0, size * 0.16))
        y = int(size / 2 + rnd.gauss(0, size * 0.16))
        blend_px(rows, x, y, (0.44, 0.445, 0.43), 0.10)
    rough = rough_from(height, 0.34, 0.16, 33)
    # Solda levemente mais lisa que o campo: linha de brilho nas costuras.
    for sx in (size // 3, 2 * size // 3):
        for y in range(size):
            for dx in (-1, 0, 1):
                i = (sx + dx) * 3
                v = clamp_byte(0.22 * 255)
                rough[y][i:i + 3] = bytes((v, v, v))
    for x in range(size):
        i = x * 3
        v = clamp_byte(0.24 * 255)
        rough[size // 2][i:i + 3] = bytes((v, v, v))
    save_maps("kit_floor", rows, height, rough, 1.2)


def tex_kit_wall(size: int = 1024) -> None:
    """KIT — painel composto de parede (protótipo do sistema de paredes).

    Metal pintado cinza-claro, grão fino de pintura eletrostática, leve
    textura de escovação vertical e sujeira mínima junto à base (a textura
    cobre um painel inteiro de 1,2 x 2,8 m: a base da textura é o rodapé).
    """
    rnd = random.Random(41)
    rows, height = tint_noise(size, (0.615, 0.625, 0.615), 0.03, 41)
    # Escovação vertical sutil.
    grain = noise_grid(size, 96, 43)
    for y in range(size):
        for x in range(size):
            v = (grain[y][x] - 0.5) * 0.028
            i = x * 3
            rows[y][i] = clamp_byte(rows[y][i] + v * 255)
            rows[y][i + 1] = clamp_byte(rows[y][i + 1] + v * 255)
    speckle(rows, height, rnd, 3000, (0.5, 0.51, 0.5), 0.18, 1.3)
    # Sombra/sujeira crescente junto ao rodapé (10% inferiores).
    for y in range(int(size * 0.90), size):
        f = (y - size * 0.90) / (size * 0.10)
        for x in range(size):
            blend_px(rows, x, y, (0.42, 0.42, 0.40), 0.20 * f)
    save_maps("kit_wall", rows, height, rough_from(height, 0.46, 0.12, 45), 0.7)


def tex_kit_ceiling(size: int = 512) -> None:
    """KIT — placa de teto 600 x 600: lisa, microperfurada nas bordas."""
    rnd = random.Random(51)
    rows, height = tint_noise(size, (0.78, 0.785, 0.78), 0.02, 51)
    step = size // 16
    for gy in range(16):
        for gx in range(16):
            cx, cy = gx * step + step // 2, gy * step + step // 2
            if 1 <= gx <= 14 and 1 <= gy <= 14:
                for dy in (-1, 0, 1):
                    for dx in (-1, 0, 1):
                        blend_px(rows, cx + dx, cy + dy, (0.55, 0.55, 0.55), 0.5)
                        height[cy + dy][cx + dx] -= 0.15
    speckle(rows, height, rnd, 500, (0.6, 0.6, 0.6), 0.15, 1.2)
    save_maps("kit_ceiling", rows, height, rough_from(height, 0.6, 0.08, 53), 0.9)


def generate_textures() -> None:
    TEX_DIR.mkdir(parents=True, exist_ok=True)
    tex_showroom_floor()
    tex_showroom_wall()
    tex_kit_floor()
    tex_kit_wall()
    tex_kit_ceiling()
    print(f"Texturas: {len(list(TEX_DIR.glob('*.png')))} arquivos")


# ---------------------------------------------------------------------------
# Materiais
# ---------------------------------------------------------------------------

MATERIALS: dict[str, dict[str, object]] = {
    "showroom_floor": {"texture": "showroom_floor", "roughness": 0.85, "normal_scale": 0.4},
    "showroom_wall": {"texture": "showroom_wall", "roughness": 0.9, "normal_scale": 0.3},
    "showroom_ceiling": {"color": (0.46, 0.47, 0.48, 1), "roughness": 0.92},
    "kit_floor": {"texture": "kit_floor", "roughness": 0.36, "normal_scale": 0.55},
    "kit_wall": {"texture": "kit_wall", "roughness": 0.46, "normal_scale": 0.45},
    "kit_wall_b": {"texture": "kit_wall", "color": (0.965, 0.97, 0.965, 1), "roughness": 0.46, "normal_scale": 0.45},
    "kit_wall_c": {"texture": "kit_wall", "color": (0.93, 0.935, 0.93, 1), "roughness": 0.48, "normal_scale": 0.45},
    "kit_joint": {"color": (0.16, 0.165, 0.16, 1), "roughness": 0.6},
    "kit_skirt": {"texture": "kit_wall", "color": (0.82, 0.83, 0.82, 1), "roughness": 0.5, "normal_scale": 0.4},
    "kit_ceiling": {"texture": "kit_ceiling", "roughness": 0.6, "normal_scale": 0.5},
    "alu_profile": {"color": (0.62, 0.64, 0.66, 1), "metallic": 0.85, "roughness": 0.38},
    "steel_dark": {"color": (0.20, 0.21, 0.22, 1), "metallic": 0.8, "roughness": 0.45},
    "edge_trim": {"color": (0.55, 0.57, 0.59, 1), "metallic": 0.9, "roughness": 0.3},
    "light_panel": {"color": (0.92, 0.94, 0.96, 1), "emission": (0.92, 0.96, 1.0, 1), "emission_energy": 1.6, "roughness": 0.5},
    "light_panel_off": {"color": (0.55, 0.57, 0.59, 1), "roughness": 0.5},
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
        if texture:
            lines.append("\n".join(
                f"[ext_resource type=\"Texture2D\" path=\"res://maps/exhibition/textures/{texture}_{suffix}.png\" id=\"tex_{label}\"]"
                for suffix, label in [("albedo", "albedo"), ("normal", "normal"), ("roughness", "roughness"), ("ao", "ao")]
            ))
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
    """Base YXZ do Godot, gravada em ordem de LINHAS (eixos efetivos exatos)."""
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

    def cyl_mesh(self, radius: float, height: float, material: str, segments: int = 20) -> str:
        key = ("CylinderMesh", radius, height, material, segments)
        return self._mesh_id(key, ["CylinderMesh", f"material = ExtResource(\"mat_{material}\")",
                                   f"top_radius = {fmt(radius)}", f"bottom_radius = {fmt(radius)}",
                                   f"height = {fmt(height)}", f"radial_segments = {segments}"])

    def node(self, name: str, kind: str, parent: str, pos: tuple[float, float, float],
             euler: tuple[float, float, float] = (0.0, 0.0, 0.0), extra: list[str] | None = None) -> None:
        basis = basis_from_euler(euler)
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
            material: str, euler: tuple[float, float, float] = (0.0, 0.0, 0.0), segments: int = 20) -> None:
        mesh = self.cyl_mesh(radius, height, material, segments)
        self.node(name, "MeshInstance3D", parent, pos, euler, [f"mesh = SubResource(\"{mesh}\")"])

    def omni(self, name: str, parent: str, pos: tuple[float, float, float], color: tuple[float, float, float],
             energy: float, range_: float, attenuation: float = 1.0, shadow: bool = False) -> None:
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

# Showroom: X [-16, 16], Z [-7, 7], pé-direito 5,0 m. Elementos ao longo de X.


def gallery_shell() -> None:
    g = B.group("Gallery")
    B.box("Floor", g, (0, -0.06, 0), (32.3, 0.12, 14.3), "showroom_floor")
    B.box("Ceiling", g, (0, 5.06, 0), (32.3, 0.12, 14.3), "showroom_ceiling")
    B.box("WallNorth", g, (0, 2.5, -7.0), (32.3, 5.0, 0.15), "showroom_wall")
    B.box("WallSouth", g, (0, 2.5, 7.0), (32.3, 5.0, 0.15), "showroom_wall")
    B.box("WallWest", g, (-16.0, 2.5, 0), (0.15, 5.0, 14.3), "showroom_wall")
    B.box("WallEast", g, (16.0, 2.5, 0), (0.15, 5.0, 14.3), "showroom_wall")
    # Rodapé neutro simples da galeria.
    for name, pos, size in [
        ("BaseN", (0, 0.05, -6.90), (32.0, 0.10, 0.04)),
        ("BaseS", (0, 0.05, 6.90), (32.0, 0.10, 0.04)),
        ("BaseW", (-15.90, 0.05, 0), (0.04, 0.10, 13.8)),
        ("BaseE", (15.90, 0.05, 0), (0.04, 0.10, 13.8)),
    ]:
        B.box(name, g, pos, size, "steel_dark")


def kit_floor_section() -> None:
    """Piso de teste 6 x 4 m embutido (topo 2 mm acima do piso neutro)."""
    f = B.group("KitFloor")
    cx, cz = -9.0, 0.0
    B.box("FloorSlab", f, (cx, -0.018, cz), (6.0, 0.04, 4.0), "kit_floor")
    # Perfil metálico de borda (acabamento do encontro com o piso neutro).
    B.box("EdgeN", f, (cx, 0.004, cz - 2.01), (6.06, 0.008, 0.03), "edge_trim")
    B.box("EdgeS", f, (cx, 0.004, cz + 2.01), (6.06, 0.008, 0.03), "edge_trim")
    B.box("EdgeW", f, (cx - 3.01, 0.004, cz), (0.03, 0.008, 4.06), "edge_trim")
    B.box("EdgeE", f, (cx + 3.01, 0.004, cz), (0.03, 0.008, 4.06), "edge_trim")
    # Soleira de transição (chanfro metálico) no lado de circulação.
    B.box("RampS", f, (cx, 0.002, cz + 2.09), (6.06, 0.006, 0.14), "alu_profile", (0.10, 0, 0))


def kit_wall_section() -> None:
    """Parede de teste isolada: 5 painéis de 1,2 m, junções, rodapé, 2 faces."""
    w = B.group("KitWall")
    cx, cz = 0.0, -1.2
    # Núcleo escuro que aparece nas junções (fuga de 6 mm entre painéis).
    B.box("WallCore", w, (cx, 1.40, cz), (6.02, 2.80, 0.10), "kit_joint")
    mats = ["kit_wall", "kit_wall_b", "kit_wall", "kit_wall_c", "kit_wall_b"]
    for i in range(5):
        px = cx - 2.4 + i * 1.2
        for side, pz, label in ((1, cz + 0.062, "F"), (-1, cz - 0.062, "B")):
            B.box(f"Panel{label}", w, (px, 1.46, pz), (1.185, 2.66, 0.024), mats[i])
        # Tampa superior do painel (topo acabado).
        B.box("PanelTop", w, (px, 2.815, cz), (1.185, 0.03, 0.148), "alu_profile")
    # Rodapé do sistema (perfil com topo chanfrado), nas duas faces.
    for side, pz in ((1, cz + 0.075), (-1, cz - 0.075)):
        B.box("Skirt", w, (cx, 0.075, pz), (6.0, 0.15, 0.03), "kit_skirt")
        B.box("SkirtChamfer", w, (cx, 0.158, pz + (0.008 if side > 0 else -0.008)),
              (6.0, 0.018, 0.036), "kit_skirt", (0.6 * side, 0, 0))
    # Placa de topo corrida (remate superior da parede de demonstração).
    B.box("WallCoping", w, (cx, 2.845, cz), (6.10, 0.04, 0.20), "alu_profile")


def kit_ceiling_section() -> None:
    """Teto de teste 4,8 x 3,6 m a 3,0 m: estrutura, perfis, placas, suportes.

    Uma célula fica sem placa (aberta) para inspecionar a construção; uma
    placa é luminária neutra apagada (forma apenas, nesta etapa).
    """
    c = B.group("KitCeiling")
    cx, cz, y = 9.6, 0.0, 3.02
    sx, sz = 4.8, 3.6
    # Perfis perimetrais (cantoneira de borda).
    B.box("FrameN", c, (cx, y, cz - sz / 2), (sx + 0.06, 0.07, 0.05), "alu_profile")
    B.box("FrameS", c, (cx, y, cz + sz / 2), (sx + 0.06, 0.07, 0.05), "alu_profile")
    B.box("FrameW", c, (cx - sx / 2, y, cz), (0.05, 0.07, sz + 0.06), "alu_profile")
    B.box("FrameE", c, (cx + sx / 2, y, cz), (0.05, 0.07, sz + 0.06), "alu_profile")
    # Perfis T principais e secundários (malha 600 mm).
    for i in range(1, 8):
        x = cx - sx / 2 + i * 0.6
        B.box("MainT", c, (x, y - 0.012, cz), (0.035, 0.045, sz), "alu_profile")
    for j in range(1, 6):
        z = cz - sz / 2 + j * 0.6
        B.box("CrossT", c, (cx, y - 0.012, z), (sx, 0.045, 0.035), "alu_profile")
    # Placas 600x600 (célula [5,2] aberta; [2,4] é luminária apagada).
    for i in range(8):
        for j in range(6):
            if (i, j) == (5, 2):
                continue
            x = cx - sx / 2 + 0.3 + i * 0.6
            z = cz - sz / 2 + 0.3 + j * 0.6
            if (i, j) == (2, 4):
                B.box("CeilingLightTile", c, (x, y + 0.012, z), (0.58, 0.03, 0.58), "light_panel_off")
                B.box("CeilingLightFrame", c, (x, y - 0.004, z), (0.60, 0.012, 0.60), "steel_dark")
            else:
                B.box("CeilingTile", c, (x, y + 0.012, z), (0.58, 0.025, 0.58), "kit_ceiling")
    # Tirantes de suspensão até o teto da galeria (5,0 m).
    for hx in (cx - 1.8, cx, cx + 1.8):
        for hz in (cz - 1.2, cz + 1.2):
            B.cyl("Hanger", c, (hx, (y + 5.0) / 2 + 0.02, hz), 0.006, 5.0 - y - 0.02, "steel_dark", segments=8)
            B.box("HangerClip", c, (hx, y + 0.06, hz), (0.05, 0.06, 0.05), "steel_dark")


def lighting_and_collisions() -> None:
    lights = B.group("Lighting")
    # Trilho neutro de avaliação: 4 conjuntos de painéis emissivos + spots.
    for i, lx in enumerate((-12.0, -4.0, 4.0, 12.0)):
        B.box("GalleryLightPanel", lights, (lx, 4.94, 0), (2.6, 0.05, 0.5), "light_panel")
        B.box("GalleryLightPanel2", lights, (lx, 4.94, 0.55), (2.6, 0.05, 0.5), "light_panel")
        B.spot(f"GallerySpot{i}", lights, (lx, 4.86, 0), (0.98, 0.99, 1.0),
               3.1, 13.0, 68, i in (1, 2), 1.0)
    B.omni("GalleryFillA", lights, (-8.0, 4.4, 0), (0.96, 0.97, 1.0), 0.5, 14.0, 1.0, False)
    B.omni("GalleryFillB", lights, (8.0, 4.4, 0), (0.96, 0.97, 1.0), 0.5, 14.0, 1.0, False)

    collision = B.group("Collision")
    B.nodes.append("[node name=\"StaticBodies\" type=\"StaticBody3D\" parent=\"Collision\"]")
    B.node_count += 1
    body = "Collision/StaticBodies"
    B.collider("Floor", body, (0, -0.12, 0), (32.4, 0.24, 14.4))
    B.collider("Ceiling", body, (0, 5.2, 0), (32.4, 0.3, 14.4))
    B.collider("WallNorth", body, (0, 2.5, -7.15), (32.4, 5.0, 0.3))
    B.collider("WallSouth", body, (0, 2.5, 7.15), (32.4, 5.0, 0.3))
    B.collider("WallWest", body, (-16.15, 2.5, 0), (0.3, 5.0, 14.4))
    B.collider("WallEast", body, (16.15, 2.5, 0), (0.3, 5.0, 14.4))
    B.collider("KitWall", body, (0, 1.4, -1.2), (6.15, 2.9, 0.35))
    B.collider("KitCeiling", body, (9.6, 3.06, 0), (4.95, 0.14, 3.75))


def build_scene() -> None:
    REF.mkdir(parents=True, exist_ok=True)
    gallery_shell()
    kit_floor_section()
    kit_wall_section()
    kit_ceiling_section()
    lighting_and_collisions()
    # Spawn na extremidade oeste, olhando ao longo da galeria (+X).
    # Linhas da base: X=(0,0,-1), Y=(0,1,0), Z=(1,0,0) -> yaw -90 graus.
    B.nodes.append("[node name=\"Spawn\" type=\"Marker3D\" parent=\".\"]\n"
                   "transform = Transform3D(0, 0, 1, 0, 1, 0, -1, 0, 0, -13.5, 0.05, 0)")
    B.node_count += 1

    ext_lines = []
    for name in MATERIALS:
        ext_lines.append(f"[ext_resource type=\"StandardMaterial3D\" path=\"res://maps/exhibition/materials/{name}.tres\" id=\"mat_{name}\"]")
    env = """[sub_resource type="Environment" id="Env_gallery"]
background_mode = 1
background_color = Color(0.055, 0.058, 0.062, 1)
ambient_light_source = 2
ambient_light_color = Color(0.62, 0.64, 0.67, 1)
ambient_light_energy = 0.72
tonemap_mode = 2
adjustment_enabled = true
adjustment_brightness = 1.0
adjustment_contrast = 1.02
adjustment_saturation = 0.95"""
    world = "[node name=\"WorldEnvironment\" type=\"WorldEnvironment\" parent=\".\"]\nenvironment = SubResource(\"Env_gallery\")"
    load_steps = len(MATERIALS) + len(B.subresources) + 2
    header = f"[gd_scene load_steps={load_steps} format=3]\n\n" + "\n".join(ext_lines) + "\n\n" + env + "\n\n" + "\n\n".join(B.subresources)
    scene = header + "\n\n[node name=\"ExhibitionRoom\" type=\"Node3D\"]\n\n" + "\n\n".join(B.nodes) + "\n\n" + world + "\n"
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
