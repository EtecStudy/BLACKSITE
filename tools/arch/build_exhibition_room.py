#!/usr/bin/env python3
"""Gera a Sala de Exibição do Kit Visual do Black Sight (espaço aberto).

Correção da etapa: NADA de sala fechada. Apenas um grande chão/plataforma
neutro e aberto em todas as direções, com áreas de exposição demarcadas
por fita no chão e placas de identificação. Cada elemento do kit visual
será criado depois, dentro da sua área:

- ÁREA DA PAREDE (fita 7,0 x 3,0 m, vazia) + placa "PAREDE";
- ÁREA DO PISO   (fita 7,0 x 5,0 m, vazia) + placa "PISO";
- ÁREA DO TETO   (fita 6,0 x 5,0 m, vazia) + placa "TETO".

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
# Texturas (somente a plataforma neutra)
# ---------------------------------------------------------------------------


def tex_platform(size: int = 512) -> None:
    """Chão neutro da exposição: concreto fosco cinza, sem protagonismo."""
    rnd = random.Random(11)
    rows, height = tint_noise(size, (0.32, 0.325, 0.33), 0.05, 11)
    speckle(rows, height, rnd, 2600, (0.17, 0.17, 0.18), 0.32, 1.6)
    speckle(rows, height, rnd, 1200, (0.50, 0.50, 0.51), 0.22, 1.4)
    save_maps("showroom_floor", rows, height, rough_from(height, 0.85, 0.12, 13), 0.8)


def tex_tape(size: int = 256) -> None:
    """Fita de demarcação: amarela com desgaste leve de uso."""
    rnd = random.Random(71)
    rows, height = tint_noise(size, (0.80, 0.63, 0.10), 0.05, 71)
    speckle(rows, height, rnd, 1500, (0.55, 0.42, 0.06), 0.35, 1.5)
    speckle(rows, height, rnd, 500, (0.30, 0.30, 0.30), 0.25, 1.6)
    save_maps("tape", rows, height, rough_from(height, 0.55, 0.15, 73), 0.8)


def generate_textures() -> None:
    TEX_DIR.mkdir(parents=True, exist_ok=True)
    # Remove texturas do desenho anterior (sala fechada) que não são mais usadas.
    keep = {"showroom_floor", "tape"}
    for png in TEX_DIR.glob("*.png"):
        if png.name.rsplit("_", 1)[0] not in keep:
            png.unlink()
    tex_platform()
    tex_tape()
    print(f"Texturas: {len(list(TEX_DIR.glob('*.png')))} arquivos")


# ---------------------------------------------------------------------------
# Materiais
# ---------------------------------------------------------------------------

MATERIALS: dict[str, dict[str, object]] = {
    "showroom_floor": {"texture": "showroom_floor", "roughness": 0.85, "normal_scale": 0.4},
    "platform_side": {"color": (0.16, 0.165, 0.17, 1), "roughness": 0.9},
    "tape": {"texture": "tape", "roughness": 0.55, "normal_scale": 0.5},
    "sign_panel": {"color": (0.09, 0.095, 0.10, 1), "roughness": 0.55},
    "sign_frame": {"color": (0.55, 0.57, 0.59, 1), "metallic": 0.85, "roughness": 0.35},
    "steel_dark": {"color": (0.20, 0.21, 0.22, 1), "metallic": 0.8, "roughness": 0.45},
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
    for stale in MAT_DIR.glob("*.tres"):
        if stale.stem not in MATERIALS:
            stale.unlink()
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

    def cyl_mesh(self, radius: float, height: float, material: str, segments: int = 16) -> str:
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
            material: str, euler: tuple[float, float, float] = (0.0, 0.0, 0.0), segments: int = 16) -> None:
        mesh = self.cyl_mesh(radius, height, material, segments)
        self.node(name, "MeshInstance3D", parent, pos, euler, [f"mesh = SubResource(\"{mesh}\")"])

    def label3d(self, name: str, parent: str, pos: tuple[float, float, float], text: str,
                pixel_size: float, color: tuple[float, float, float] = (0.92, 0.93, 0.94)) -> None:
        extra = [f"text = \"{text}\"", f"pixel_size = {fmt(pixel_size)}",
                 f"modulate = {color_text((*color, 1.0))}", "billboard = 0", "no_depth_test = false"]
        self.node(name, "Label3D", parent, pos, (0, 0, 0), extra)

    def directional(self, name: str, parent: str, euler: tuple[float, float, float],
                    color: tuple[float, float, float], energy: float, shadow: bool = True) -> None:
        extra = [f"light_color = {color_text((*color, 1.0))}", f"light_energy = {fmt(energy)}",
                 f"shadow_enabled = {'true' if shadow else 'false'}",
                 "directional_shadow_mode = 1", "directional_shadow_max_distance = 60.0"]
        self.node(name, "DirectionalLight3D", parent, (0, 0, 0), euler, extra)

    def omni(self, name: str, parent: str, pos: tuple[float, float, float], color: tuple[float, float, float],
             energy: float, range_: float, attenuation: float = 1.0) -> None:
        extra = [f"light_color = {color_text((*color, 1.0))}", f"light_energy = {fmt(energy)}",
                 f"omni_range = {fmt(range_)}", f"omni_attenuation = {fmt(attenuation)}",
                 "shadow_enabled = false"]
        self.node(name, "OmniLight3D", parent, pos, (0, 0, 0), extra)

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

# Plataforma aberta: X [-20, 20], Z [-9, 9]. Sem paredes, sem teto.

AREAS = [
    # (grupo, centro_x, largura_x, profundidade_z, texto da placa, nome do grupo)
    ("AreaParede", -11.5, 7.0, 3.0, "PAREDE"),
    ("AreaPiso", 0.0, 7.0, 5.0, "PISO"),
    ("AreaTeto", 11.5, 6.0, 5.0, "TETO"),
]
SIGN_COLLIDERS: list[tuple[float, float, float, tuple[float, float, float]]] = []


def platform() -> None:
    g = B.group("Platform")
    B.box("Deck", g, (0, -0.11, 0), (40.0, 0.22, 18.0), "showroom_floor")
    # Friso lateral escuro: leitura da borda da plataforma no vazio.
    B.box("EdgeN", g, (0, -0.03, -9.02), (40.0, 0.06, 0.05), "platform_side")
    B.box("EdgeS", g, (0, -0.03, 9.02), (40.0, 0.06, 0.05), "platform_side")
    B.box("EdgeW", g, (-20.02, -0.03, 0), (0.05, 0.06, 18.0), "platform_side")
    B.box("EdgeE", g, (20.02, -0.03, 0), (0.05, 0.06, 18.0), "platform_side")


def tape_rectangle(parent: str, cx: float, cz: float, w: float, d: float) -> None:
    """Contorno de fita (4 tiras de 8 cm) delimitando a área de exposição."""
    t = 0.08
    y = 0.004
    B.box("TapeN", parent, (cx, y, cz - d / 2 + t / 2), (w, 0.006, t), "tape")
    B.box("TapeS", parent, (cx, y, cz + d / 2 - t / 2), (w, 0.006, t), "tape")
    B.box("TapeW", parent, (cx - w / 2 + t / 2, y, cz), (t, 0.006, d - 2 * t), "tape")
    B.box("TapeE", parent, (cx + w / 2 - t / 2, y, cz), (t, 0.006, d - 2 * t), "tape")
    # Cantoneiras reforçadas (leitura do canto a distância).
    for sx in (-1, 1):
        for sz in (-1, 1):
            B.box("TapeCorner", parent, (cx + sx * (w / 2 - 0.14), y + 0.001, cz + sz * (d / 2 - 0.14)),
                  (0.28, 0.007, 0.28), "tape")


def sign(parent: str, cx: float, cz: float, title: str) -> None:
    """Placa simples de pé: 2 postes, painel e textos 3D (título + aviso)."""
    B.cyl("SignPost", parent, (cx - 0.34, 0.55, cz), 0.022, 1.1, "sign_frame")
    B.cyl("SignPost", parent, (cx + 0.34, 0.55, cz), 0.022, 1.1, "sign_frame")
    B.box("SignFoot", parent, (cx - 0.34, 0.02, cz), (0.16, 0.04, 0.30), "steel_dark")
    B.box("SignFoot", parent, (cx + 0.34, 0.02, cz), (0.16, 0.04, 0.30), "steel_dark")
    B.box("SignPanel", parent, (cx, 1.12, cz), (0.95, 0.58, 0.035), "sign_panel")
    B.box("SignPanelFrame", parent, (cx, 1.12, cz - 0.012), (1.0, 0.63, 0.02), "sign_frame")
    # Textos voltados para +Z (corredor sul de circulação).
    B.label3d("SignTitle", parent, (cx, 1.24, cz + 0.022), title, 0.0060)
    B.label3d("SignSub", parent, (cx, 0.99, cz + 0.022), "ÁREA RESERVADA", 0.0032, (0.65, 0.68, 0.70))
    SIGN_COLLIDERS.append((cx, cz, 0.0, (1.05, 1.45, 0.30)))


def areas() -> None:
    for name, cx, w, d, title in AREAS:
        g = B.group(name)
        tape_rectangle(g, cx, 0.0, w, d)
        # Placa ao lado sul da área, fora da fita.
        sign(g, cx, d / 2 + 1.05, title)


def lighting_and_collisions() -> None:
    lights = B.group("Lighting")
    # Luz neutra simples de espaço aberto: sol de avaliação + preenchimentos.
    B.directional("KeyLight", lights, (-0.85, -0.55, 0.0), (1.0, 0.99, 0.96), 1.15, True)
    B.omni("FillA", lights, (-11.5, 7.0, 2.0), (0.95, 0.97, 1.0), 0.55, 22.0, 1.0)
    B.omni("FillB", lights, (0.0, 7.0, 2.0), (0.95, 0.97, 1.0), 0.55, 22.0, 1.0)
    B.omni("FillC", lights, (11.5, 7.0, 2.0), (0.95, 0.97, 1.0), 0.55, 22.0, 1.0)

    collision = B.group("Collision")
    B.nodes.append("[node name=\"StaticBodies\" type=\"StaticBody3D\" parent=\"Collision\"]")
    B.node_count += 1
    body = "Collision/StaticBodies"
    B.collider("Deck", body, (0, -0.12, 0), (40.2, 0.24, 18.2))
    # Barreiras invisíveis nas bordas: o espaço é aberto, mas o jogador
    # não cai da plataforma durante a avaliação.
    B.collider("EdgeBarrierN", body, (0, 0.7, -9.15), (40.4, 1.4, 0.3))
    B.collider("EdgeBarrierS", body, (0, 0.7, 9.15), (40.4, 1.4, 0.3))
    B.collider("EdgeBarrierW", body, (-20.15, 0.7, 0), (0.3, 1.4, 18.4))
    B.collider("EdgeBarrierE", body, (20.15, 0.7, 0), (0.3, 1.4, 18.4))
    for i, (cx, cz, _r, size) in enumerate(SIGN_COLLIDERS):
        B.collider(f"Sign{i}", body, (cx, size[1] / 2, cz), size)


def build_scene() -> None:
    REF.mkdir(parents=True, exist_ok=True)
    platform()
    areas()
    lighting_and_collisions()
    # Spawn na extremidade oeste, sobre a plataforma, olhando ao longo dela.
    # Linhas da base: X=(0,0,-1), Y=(0,1,0), Z=(1,0,0) -> yaw -90 graus.
    B.nodes.append("[node name=\"Spawn\" type=\"Marker3D\" parent=\".\"]\n"
                   "transform = Transform3D(0, 0, 1, 0, 1, 0, -1, 0, 0, -17.5, 0.05, 3.2)")
    B.node_count += 1

    ext_lines = []
    for name in MATERIALS:
        ext_lines.append(f"[ext_resource type=\"StandardMaterial3D\" path=\"res://maps/exhibition/materials/{name}.tres\" id=\"mat_{name}\"]")
    env = """[sub_resource type="Environment" id="Env_gallery"]
background_mode = 1
background_color = Color(0.016, 0.017, 0.020, 1)
ambient_light_source = 2
ambient_light_color = Color(0.56, 0.58, 0.61, 1)
ambient_light_energy = 0.62
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
