#!/usr/bin/env python3
"""Gera a Sala-Piloto Visual do Black Sight.

A sala é uma cena Godot estática e independente (10 m x 12 m), construída
apenas com geometria/caixas/cilindros do próprio projeto e texturas PBR
procedurais geradas por este roteiro. Nenhum asset externo é baixado.

Uso:
    python3 tools/arch/build_pilot_room.py

Saídas:
    maps/pilot/textures/*.png
    maps/pilot/materials/*.tres
    maps/pilot/pilot_research_room.tscn
"""

from __future__ import annotations

import math
import random
import struct
import zlib
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
PILOT = ROOT / "maps" / "pilot"
TEX_DIR = PILOT / "textures"
MAT_DIR = PILOT / "materials"
SCENE_PATH = PILOT / "pilot_research_room.tscn"

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


def hash2(x: int, y: int, seed: int) -> float:
    n = (x * 374761393 + y * 668265263 + seed * 974711) & 0xFFFFFFFF
    n = ((n ^ (n >> 13)) * 1274126177) & 0xFFFFFFFF
    return ((n ^ (n >> 16)) & 255) / 255.0


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


def save_maps(name: str, albedo: list[bytearray], height: list[list[float]], roughness: list[bytearray], strength: float = 2.0) -> None:
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
            nrow.extend((
                clamp_byte((-dx * inv * 0.5 + 0.5) * 255),
                clamp_byte((dy * inv * 0.5 + 0.5) * 255),
                clamp_byte(inv * 255),
            ))
            shade = clamp_byte(218 + (height[y][x] - 0.5) * 58)
            arow.extend((shade, shade, shade))
        normal.append(nrow)
        ao.append(arow)
    write_png(TEX_DIR / f"{name}_albedo.png", albedo)
    write_png(TEX_DIR / f"{name}_normal.png", normal)
    write_png(TEX_DIR / f"{name}_roughness.png", roughness)
    write_png(TEX_DIR / f"{name}_ao.png", ao)


def gray_rows(size: int, values: list[list[float]]) -> list[bytearray]:
    rows: list[bytearray] = []
    for y in range(size):
        row = bytearray()
        for x in range(size):
            v = clamp_byte(values[y][x] * 255)
            row.extend((v, v, v))
        rows.append(row)
    return rows


def generate_textures() -> None:
    TEX_DIR.mkdir(parents=True, exist_ok=True)

    # Painel técnico pintado: variação fina, riscos discretos e junta no bordo.
    size = 1024
    noise = combined_noise(size, 101)
    height: list[list[float]] = []
    albedo: list[bytearray] = []
    rough: list[bytearray] = []
    for y in range(size):
        hrow: list[float] = []
        arow = bytearray()
        rrow = bytearray()
        for x in range(size):
            n = noise[y][x]
            speckle = hash2(x, y, 501)
            edge = min(x, y, size - 1 - x, size - 1 - y)
            seam = 0.22 if edge < 3 else (0.10 if edge < 6 else 0.0)
            scuff = 0.05 if y > size * 0.93 and speckle > 0.72 else 0.0
            h = 0.52 + (n - 0.5) * 0.13 - seam - scuff
            tone = 0.90 + (n - 0.5) * 0.13 + (speckle - 0.5) * 0.025 - seam * 0.35
            arow.extend((clamp_byte(205 * tone), clamp_byte(211 * tone), clamp_byte(204 * tone)))
            rv = clamp_byte((0.48 + (n - 0.5) * 0.18 + seam * 0.25) * 255)
            rrow.extend((rv, rv, rv))
            hrow.append(h)
        height.append(hrow)
        albedo.append(arow)
        rough.append(rrow)
    save_maps("wall_panel", albedo, height, rough, 2.4)

    # Epóxi técnico: base cinza-azulada, flocos minerais e desgaste localizado.
    noise = combined_noise(size, 202)
    height = []
    albedo = []
    rough = []
    for y in range(size):
        hrow = []
        arow = bytearray()
        rrow = bytearray()
        for x in range(size):
            n = noise[y][x]
            speck = hash2(x, y, 909)
            h = 0.5 + (n - 0.5) * 0.075
            r0, g0, b0 = 116, 123, 121
            tone = 0.88 + (n - 0.5) * 0.22
            if speck > 0.992:
                r0, g0, b0 = 174, 178, 171
            elif speck < 0.008:
                r0, g0, b0 = 55, 61, 62
            elif speck > 0.975:
                r0, g0, b0 = 126, 132, 130
            arow.extend((clamp_byte(r0 * tone), clamp_byte(g0 * tone), clamp_byte(b0 * tone)))
            rv = clamp_byte((0.42 + (n - 0.5) * 0.23) * 255)
            rrow.extend((rv, rv, rv))
            hrow.append(h)
        height.append(hrow)
        albedo.append(arow)
        rough.append(rrow)
    save_maps("floor_epoxy", albedo, height, rough, 1.6)

    # Forro metálico perfurado.
    size = 512
    noise = combined_noise(size, 303)
    height = []
    albedo = []
    rough = []
    for y in range(size):
        hrow = []
        arow = bytearray()
        rrow = bytearray()
        for x in range(size):
            n = noise[y][x]
            hole = 0.16 if ((x % 18) - 9) ** 2 + ((y % 18) - 9) ** 2 < 5 else 0.0
            h = 0.55 + (n - 0.5) * 0.06 - hole
            tone = 0.94 + (n - 0.5) * 0.08 - hole * 0.28
            arow.extend((clamp_byte(203 * tone), clamp_byte(207 * tone), clamp_byte(205 * tone)))
            rv = clamp_byte((0.58 + (n - 0.5) * 0.1 + hole * 0.2) * 255)
            rrow.extend((rv, rv, rv))
            hrow.append(h)
        height.append(hrow)
        albedo.append(arow)
        rough.append(rrow)
    save_maps("ceiling_panel", albedo, height, rough, 2.0)

    # Metal escovado e tampo de bancada.
    for name, base, rough_base, seed, horizontal in [
        ("brushed_metal", (142, 148, 150), 0.36, 404, True),
        ("bench_top", (45, 48, 49), 0.52, 505, False),
    ]:
        noise = combined_noise(size, seed)
        height = []
        albedo = []
        rough = []
        for y in range(size):
            hrow = []
            arow = bytearray()
            rrow = bytearray()
            for x in range(size):
                n = noise[y][x]
                streak = hash2(y if horizontal else x, 0, seed + 3)
                speck = hash2(x, y, seed + 8)
                h = 0.5 + (n - 0.5) * 0.05 + (streak - 0.5) * 0.025
                tone = 0.90 + (n - 0.5) * 0.10 + (streak - 0.5) * 0.07
                if name == "bench_top" and speck > 0.986:
                    tone += 0.22
                arow.extend((clamp_byte(base[0] * tone), clamp_byte(base[1] * tone), clamp_byte(base[2] * tone)))
                rv = clamp_byte((rough_base + (n - 0.5) * 0.13 + (streak - 0.5) * 0.05) * 255)
                rrow.extend((rv, rv, rv))
                hrow.append(h)
            height.append(hrow)
            albedo.append(arow)
            rough.append(rrow)
        save_maps(name, albedo, height, rough, 1.2)


# ---------------------------------------------------------------------------
# Materiais Godot
# ---------------------------------------------------------------------------

MATERIALS: dict[str, dict[str, object]] = {
    "wall_panel": {"texture": "wall_panel", "metallic": 0.06, "normal_scale": 0.65},
    "wall_lower": {"texture": "wall_panel", "color": (0.60, 0.64, 0.64, 1), "metallic": 0.10, "normal_scale": 0.5},
    "service_metal": {"texture": "brushed_metal", "color": (0.56, 0.60, 0.61, 1), "metallic": 0.38, "normal_scale": 0.35},
    "floor_epoxy": {"texture": "floor_epoxy", "metallic": 0.02, "normal_scale": 0.45},
    "floor_alt": {"texture": "floor_epoxy", "color": (0.96, 0.98, 1.0, 1), "metallic": 0.02, "normal_scale": 0.45},
    "ceiling_panel": {"texture": "ceiling_panel", "metallic": 0.12, "normal_scale": 0.55},
    "brushed_metal": {"texture": "brushed_metal", "metallic": 0.72, "normal_scale": 0.3},
    "bench_top": {"texture": "bench_top", "metallic": 0.05, "normal_scale": 0.35},
    "dark_metal": {"color": (0.10, 0.11, 0.12, 1), "metallic": 0.55, "roughness": 0.50},
    "frame_metal": {"color": (0.23, 0.26, 0.27, 1), "metallic": 0.65, "roughness": 0.42},
    "stainless": {"color": (0.58, 0.62, 0.63, 1), "metallic": 0.86, "roughness": 0.30},
    "cabinet": {"color": (0.58, 0.62, 0.62, 1), "metallic": 0.18, "roughness": 0.58},
    "cabinet_dark": {"color": (0.29, 0.35, 0.36, 1), "metallic": 0.20, "roughness": 0.62},
    "cabinet_teal": {"color": (0.21, 0.41, 0.43, 1), "metallic": 0.16, "roughness": 0.60},
    "plastic_black": {"color": (0.045, 0.048, 0.052, 1), "metallic": 0.05, "roughness": 0.72},
    "plastic_white": {"color": (0.78, 0.80, 0.78, 1), "metallic": 0.02, "roughness": 0.64},
    "glass": {"color": (0.36, 0.55, 0.60, 0.30), "metallic": 0.05, "roughness": 0.08, "transparency": 1},
    "glass_dark": {"color": (0.08, 0.13, 0.15, 0.52), "metallic": 0.05, "roughness": 0.12, "transparency": 1},
    "screen": {"color": (0.015, 0.035, 0.045, 1), "emission": (0.05, 0.22, 0.27, 1), "emission_energy": 0.75, "roughness": 0.35},
    "screen_dim": {"color": (0.02, 0.03, 0.035, 1), "emission": (0.03, 0.10, 0.12, 1), "emission_energy": 0.45, "roughness": 0.4},
    "light_panel": {"color": (0.92, 0.94, 0.92, 1), "emission": (0.95, 0.97, 0.94, 1), "emission_energy": 2.4, "roughness": 0.4},
    "task_light": {"color": (0.85, 0.88, 0.84, 1), "emission": (0.72, 0.78, 0.72, 1), "emission_energy": 1.2, "roughness": 0.5},
    "indicator_green": {"color": (0.02, 0.12, 0.05, 1), "emission": (0.05, 0.65, 0.22, 1), "emission_energy": 1.5},
    "indicator_red": {"color": (0.16, 0.015, 0.012, 1), "emission": (0.65, 0.035, 0.025, 1), "emission_energy": 1.3},
    "indicator_amber": {"color": (0.16, 0.08, 0.01, 1), "emission": (0.70, 0.34, 0.04, 1), "emission_energy": 1.1},
    "safety_red": {"color": (0.48, 0.055, 0.045, 1), "metallic": 0.08, "roughness": 0.55},
    "safety_yellow": {"color": (0.58, 0.43, 0.08, 1), "metallic": 0.02, "roughness": 0.66},
    "safety_green": {"color": (0.04, 0.30, 0.16, 1), "metallic": 0.02, "roughness": 0.62},
    "paper": {"color": (0.78, 0.77, 0.72, 1), "roughness": 0.86},
    "cardboard": {"color": (0.39, 0.30, 0.20, 1), "roughness": 0.88},
    "container_blue": {"color": (0.10, 0.23, 0.34, 1), "metallic": 0.04, "roughness": 0.62},
    "container_gray": {"color": (0.34, 0.37, 0.37, 1), "metallic": 0.08, "roughness": 0.68},
    "rubber": {"color": (0.018, 0.019, 0.02, 1), "roughness": 0.94},
    "outside_dark": {"color": (0.035, 0.04, 0.047, 1), "roughness": 0.9},
}


def fmt(value: object) -> str:
    if isinstance(value, bool):
        return "true" if value else "false"
    if isinstance(value, float):
        return ("%.6f" % value).rstrip("0").rstrip(".") or "0"
    if isinstance(value, (tuple, list)):
        inner = ", ".join(fmt(v) for v in value)
        return inner
    return str(value)


def color_text(color: tuple[float, ...]) -> str:
    return "Color(%s)" % ", ".join(fmt(float(v)) for v in color)


def write_materials() -> None:
    MAT_DIR.mkdir(parents=True, exist_ok=True)
    for name, spec in MATERIALS.items():
        lines = ["[gd_resource type=\"StandardMaterial3D\" format=3]", ""]
        ext: list[tuple[str, str]] = []
        texture = spec.get("texture")
        if texture:
            for suffix, label in [("albedo", "albedo"), ("normal", "normal"), ("roughness", "roughness"), ("ao", "ao")]:
                ext.append((label, f"res://maps/pilot/textures/{texture}_{suffix}.png"))
            lines.append("\n".join(
                f"[ext_resource type=\"Texture2D\" path=\"{path}\" id=\"tex_{label}\"]" for label, path in ext
            ))
            lines.append("")
        lines.append("[resource]")
        if texture:
            lines.append("albedo_texture = ExtResource(\"tex_albedo\")")
            if "color" in spec:
                lines.append(f"albedo_color = {color_text(spec['color'])}")  # type: ignore[arg-type]
            lines.append("roughness_texture = ExtResource(\"tex_roughness\")")
            lines.append("normal_enabled = true")
            lines.append("normal_texture = ExtResource(\"tex_normal\")")
            lines.append(f"normal_scale = {fmt(float(spec.get('normal_scale', 0.5)))}")
            lines.append("ao_enabled = true")
            lines.append("ao_texture = ExtResource(\"tex_ao\")")
            lines.append("ao_light_affect = 0.35")
        else:
            lines.append(f"albedo_color = {color_text(spec.get('color', (1, 1, 1, 1)))}")  # type: ignore[arg-type]
            lines.append(f"roughness = {fmt(float(spec.get('roughness', 0.7)))}")
        lines.append(f"metallic = {fmt(float(spec.get('metallic', 0.0)))}")
        if "transparency" in spec:
            lines.append(f"transparency = {int(spec['transparency'])}")  # type: ignore[arg-type]
        if "emission" in spec:
            lines.append("emission_enabled = true")
            lines.append(f"emission = {color_text(spec['emission'])}")  # type: ignore[arg-type]
            lines.append(f"emission_energy_multiplier = {fmt(float(spec.get('emission_energy', 1.0)))}")
        (MAT_DIR / f"{name}.tres").write_text("\n".join(lines) + "\n", encoding="utf-8")


# ---------------------------------------------------------------------------
# Construção da cena
# ---------------------------------------------------------------------------


def basis_from_euler(euler: tuple[float, float, float]) -> tuple[float, ...]:
    # Ordem YXZ do Godot: yaw * pitch * roll, retornado por colunas X/Y/Z.
    rx, ry, rz = euler
    cx, sx = math.cos(rx), math.sin(rx)
    cy, sy = math.cos(ry), math.sin(ry)
    cz, sz = math.cos(rz), math.sin(rz)
    # Matriz combinada calculada por colunas.
    x_axis = (cy * cz + sy * sx * sz, cx * sz, -sy * cz + cy * sx * sz)
    y_axis = (-cy * sz + sy * sx * cz, cx * cz, sy * sz + cy * sx * cz)
    z_axis = (sy * cx, -sx, cy * cx)
    return (*x_axis, *y_axis, *z_axis)


class Builder:
    def __init__(self) -> None:
        self.nodes: list[str] = []
        self.mesh_ids: dict[tuple[object, ...], str] = {}
        self.shape_ids: dict[tuple[float, float, float], str] = {}
        self.subresources: list[str] = []
        self.counter = 0
        self.node_count = 0
        self._name_counts: dict[tuple[str, str], int] = {}

    def _unique_name(self, parent: str, name: str) -> str:
        key = (parent, name)
        count = self._name_counts.get(key, 0)
        self._name_counts[key] = count + 1
        return name if count == 0 else f"{name}{count}"

    def _next(self, prefix: str) -> str:
        self.counter += 1
        return f"{prefix}_{self.counter:03d}"

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
        self.subresources.append("\n".join([f"[sub_resource type=\"{lines[0]}\" id=\"{mesh_id}\"]", *lines[1:]]))
        return mesh_id

    def box_mesh(self, size: tuple[float, float, float], material: str) -> str:
        key = ("BoxMesh", size, material)
        return self._mesh_id(key, ["BoxMesh", f"material = ExtResource(\"mat_{material}\")", f"size = Vector3({fmt(size)})"])

    def cyl_mesh(self, radius: float, height: float, material: str, segments: int = 24) -> str:
        key = ("CylinderMesh", radius, height, material, segments)
        return self._mesh_id(key, [
            "CylinderMesh", f"material = ExtResource(\"mat_{material}\")",
            f"top_radius = {fmt(radius)}", f"bottom_radius = {fmt(radius)}",
            f"height = {fmt(height)}", f"radial_segments = {segments}",
        ])

    def sphere_mesh(self, radius: float, material: str) -> str:
        key = ("SphereMesh", radius, material)
        return self._mesh_id(key, [
            "SphereMesh", f"material = ExtResource(\"mat_{material}\")",
            f"radius = {fmt(radius)}", f"height = {fmt(radius * 2)}",
            "radial_segments = 24", "rings = 12",
        ])

    def torus_mesh(self, inner: float, outer: float, material: str) -> str:
        key = ("TorusMesh", inner, outer, material)
        return self._mesh_id(key, [
            "TorusMesh", f"material = ExtResource(\"mat_{material}\")",
            f"inner_radius = {fmt(inner)}", f"outer_radius = {fmt(outer)}",
            "rings = 24", "ring_segments = 10",
        ])

    def shape_id(self, size: tuple[float, float, float]) -> str:
        if size in self.shape_ids:
            return self.shape_ids[size]
        shape_id = self._next("Shape")
        self.shape_ids[size] = shape_id
        self.subresources.append(f"[sub_resource type=\"BoxShape3D\" id=\"{shape_id}\"]\nsize = Vector3({fmt(size)})")
        return shape_id

    def node(self, name: str, kind: str, parent: str, pos: tuple[float, float, float],
             euler: tuple[float, float, float] = (0.0, 0.0, 0.0), extra: list[str] | None = None) -> None:
        basis = basis_from_euler(euler)
        values = ", ".join(fmt(v) for v in (*basis, *pos))
        unique = self._unique_name(parent, name)
        lines = [f"[node name=\"{unique}\" type=\"{kind}\" parent=\"{parent}\"]", f"transform = Transform3D({values})"]
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

    def sphere(self, name: str, parent: str, pos: tuple[float, float, float], radius: float, material: str) -> None:
        mesh = self.sphere_mesh(radius, material)
        self.node(name, "MeshInstance3D", parent, pos, (0, 0, 0), [f"mesh = SubResource(\"{mesh}\")"])

    def torus(self, name: str, parent: str, pos: tuple[float, float, float], inner: float, outer: float,
              material: str, euler: tuple[float, float, float] = (0.0, 0.0, 0.0)) -> None:
        mesh = self.torus_mesh(inner, outer, material)
        self.node(name, "MeshInstance3D", parent, pos, euler, [f"mesh = SubResource(\"{mesh}\")"])

    def collider(self, name: str, parent: str, pos: tuple[float, float, float], size: tuple[float, float, float],
                 euler: tuple[float, float, float] = (0.0, 0.0, 0.0)) -> None:
        shape = self.shape_id(size)
        self.node(name, "CollisionShape3D", parent, pos, euler, [f"shape = SubResource(\"{shape}\")"])

    def label(self, name: str, parent: str, pos: tuple[float, float, float], text: str, yaw: float,
              size: int = 42, color: tuple[float, float, float, float] = (0.88, 0.90, 0.88, 1), pixel: float = 0.0022) -> None:
        extra = [
            f"pixel_size = {fmt(pixel)}",
            f"modulate = {color_text(color)}",
            "outline_size = 4",
            "outline_modulate = Color(0.015, 0.018, 0.02, 1)",
            f"text = \"{text}\"",
            f"font_size = {size}",
            "horizontal_alignment = 1",
        ]
        self.node(name, "Label3D", parent, pos, (0.0, yaw, 0.0), extra)

    def omni(self, name: str, parent: str, pos: tuple[float, float, float], color: tuple[float, float, float],
             energy: float, range_: float, attenuation: float = 1.15, shadow: bool = False) -> None:
        extra = [
            f"light_color = {color_text((*color, 1.0))}",
            f"light_energy = {fmt(energy)}",
            f"omni_range = {fmt(range_)}",
            f"omni_attenuation = {fmt(attenuation)}",
            f"shadow_enabled = {'true' if shadow else 'false'}",
        ]
        self.node(name, "OmniLight3D", parent, pos, (0, 0, 0), extra)

    def spot(self, name: str, parent: str, pos: tuple[float, float, float], color: tuple[float, float, float],
             energy: float, range_: float, angle: float, shadow: bool = False) -> None:
        extra = [
            f"light_color = {color_text((*color, 1.0))}",
            f"light_energy = {fmt(energy)}",
            f"spot_range = {fmt(range_)}",
            f"spot_angle = {fmt(angle)}",
            "spot_attenuation = 1.1",
            f"shadow_enabled = {'true' if shadow else 'false'}",
        ]
        self.node(name, "SpotLight3D", parent, pos, (-math.pi / 2, 0, 0), extra)


B = Builder()


def intervals_without(start: float, end: float, blocks: list[tuple[float, float]]) -> list[tuple[float, float]]:
    result: list[tuple[float, float]] = []
    cursor = start
    for block_start, block_end in sorted(blocks):
        if block_start > cursor:
            result.append((cursor, min(block_start, end)))
        cursor = max(cursor, block_end)
    if cursor < end:
        result.append((cursor, end))
    return [(a, b) for a, b in result if b - a > 0.03]


def split_interval(start: float, end: float, max_len: float = 1.5) -> list[tuple[float, float]]:
    count = max(1, math.ceil((end - start) / max_len))
    step = (end - start) / count
    return [(start + i * step, start + (i + 1) * step) for i in range(count)]


def wall_panels() -> None:
    walls = B.group("Walls", "Architecture")
    # Estrutura opaca atrás do sistema de painéis, já recortada nos vãos.
    openings = {
        "north": [], "south": [(-2.95, -1.45)], "west": [], "east": [(-2.85, 0.85)],
    }
    heights = {"south": 2.68, "east": (1.02, 2.58)}
    for side in ["north", "south", "west", "east"]:
        horizontal = side in ("north", "south")
        start, end = (-5.0, 5.0) if horizontal else (-6.0, 6.0)
        fixed = {"north": -6.16, "south": 6.16, "west": -5.16, "east": 5.16}[side]
        for a, b in intervals_without(start, end, openings[side]):
            center = (a + b) / 2
            length = b - a
            pos = (center, 2.6, fixed) if horizontal else (fixed, 2.6, center)
            size = (length, 5.2, 0.30) if horizontal else (0.30, 5.2, length)
            B.box(f"Structure_{side}", walls, pos, size, "outside_dark")
        if side in openings and openings[side]:
            for a, b in openings[side]:
                center = (a + b) / 2
                length = b - a
                if side == "south":
                    B.box("Structure_south_lintel", walls, (center, (2.68 + 5.2) / 2, fixed), (length, 5.2 - 2.68, 0.30), "outside_dark")
                else:
                    low_h = heights["east"][0]  # type: ignore[index]
                    high_y = heights["east"][1]  # type: ignore[index]
                    B.box("Structure_east_low", walls, (fixed, low_h / 2, center), (0.30, low_h, length), "outside_dark")
                    B.box("Structure_east_high", walls, (fixed, (high_y + 5.2) / 2, center), (0.30, 5.2 - high_y, length), "outside_dark")

    bands = [
        ("Lower", 0.16, 1.02, "wall_lower"),
        ("Main", 1.09, 3.30, "wall_panel"),
        ("Service", 3.38, 4.02, "service_metal"),
        ("Upper", 4.10, 5.16, "wall_panel"),
    ]
    for side in ["north", "south", "west", "east"]:
        horizontal = side in ("north", "south")
        start, end = (-5.0, 5.0) if horizontal else (-6.0, 6.0)
        fixed = {"north": -5.965, "south": 5.965, "west": -4.965, "east": 4.965}[side]
        for band, y0, y1, material in bands:
            blocks: list[tuple[float, float]] = []
            if side == "south" and y0 < 2.68:
                blocks = openings["south"]
            if side == "east" and y0 < 2.58 and y1 > 1.02:
                blocks = openings["east"]
            if side == "east" and band == "Lower":
                blocks = []
            for a, b in intervals_without(start, end, blocks):
                for pa, pb in split_interval(a, b, 1.48):
                    center = (pa + pb) / 2
                    length = max(0.05, pb - pa - 0.025)
                    pos = (center, (y0 + y1) / 2, fixed) if horizontal else (fixed, (y0 + y1) / 2, center)
                    size = (length, y1 - y0 - 0.018, 0.07) if horizontal else (0.07, y1 - y0 - 0.018, length)
                    B.box(f"Panel_{side}_{band}", walls, pos, size, material)
        # Rodapé sanitário: faixa vertical + plano inclinado, sem dividir o plano da parede.
        for a, b in intervals_without(start, end, openings[side] if side == "south" else []):
            center = (a + b) / 2
            length = b - a
            if horizontal:
                z = -5.94 if side == "north" else 5.94
                B.box(f"Cove_{side}", walls, (center, 0.075, z), (length, 0.15, 0.10), "cabinet_dark")
                pitch = math.radians(38 if side == "north" else -38)
                B.box(f"CoveSlope_{side}", walls, (center, 0.055, (-5.955 if side == "north" else 5.955)), (length, 0.025, 0.19), "floor_alt", (pitch, 0, 0))
            else:
                x = -4.94 if side == "west" else 4.94
                B.box(f"Cove_{side}", walls, (x, 0.075, center), (0.10, 0.15, length), "cabinet_dark")
                roll = math.radians(-38 if side == "west" else 38)
                B.box(f"CoveSlope_{side}", walls, ((-4.955 if side == "west" else 4.955), 0.055, center), (0.19, 0.025, length), "floor_alt", (0, 0, roll))
        # Proteção contra carrinhos a 0,95 m.
        pos = (0, 0.98, -5.91) if side == "north" else (0, 0.98, 5.91) if side == "south" else (-4.91, 0.98, 0) if side == "west" else (4.91, 0.98, 0)
        if side == "east":
            pos = (4.91, 0.98, -4.4)
            B.box("WallGuard_east_a", walls, pos, (0.07, 0.13, 3.0), "frame_metal")
            B.box("WallGuard_east_b", walls, (4.91, 0.98, 3.6), (0.07, 0.13, 4.6), "frame_metal")
        else:
            size = (10.0, 0.13, 0.07) if horizontal else (0.07, 0.13, 12.0)
            if side == "south":
                B.box("WallGuard_south_a", walls, (-3.65, 0.98, 5.91), (2.6, 0.13, 0.07), "frame_metal")
                B.box("WallGuard_south_b", walls, (1.4, 0.98, 5.91), (7.0, 0.13, 0.07), "frame_metal")
            else:
                B.box(f"WallGuard_{side}", walls, pos, size, "frame_metal")
    for x in (-4.93, 4.93):
        for z in (-5.93, 5.93):
            B.box("CornerTrim", walls, (x, 2.6, z), (0.13, 5.2, 0.13), "frame_metal")


def floor_and_ceiling() -> None:
    floor = B.group("Floor", "Architecture")
    B.box("FloorSlab", floor, (0, -0.12, 0), (10.7, 0.22, 12.7), "outside_dark")
    rnd = random.Random(42)
    for ix in range(5):
        for iz in range(6):
            x = -4 + ix * 2.0
            z = -5 + iz * 2.0
            mat = "floor_alt" if rnd.random() < 0.22 else "floor_epoxy"
            B.box("FloorPanel", floor, (x, 0.012, z), (2.0, 0.024, 2.0), mat)
    B.box("DoorThreshold", floor, (-2.2, 0.026, 5.82), (1.65, 0.018, 0.28), "brushed_metal")
    B.cyl("FloorDrain", floor, (-4.15, 0.027, 0.72), 0.09, 0.008, "dark_metal", segments=28)
    # Linhas discretas de circulação/segurança, gastas e sem neon.
    B.box("FloorLineDoor", floor, (-2.2, 0.027, 4.72), (1.7, 0.006, 0.07), "safety_yellow")
    B.box("FloorLineHood", floor, (-2.3, 0.027, -4.25), (2.6, 0.006, 0.07), "container_gray")

    ceiling = B.group("Ceiling", "Architecture")
    B.box("CeilingSlab", ceiling, (0, 5.34, 0), (10.7, 0.24, 12.7), "outside_dark")
    for ix in range(4):
        for iz in range(5):
            B.box("CeilingPanel", ceiling, (-3.75 + ix * 2.5, 5.19, -4.8 + iz * 2.4), (2.38, 0.05, 2.28), "ceiling_panel")
    for x in (-4.72, 4.72):
        B.box("CeilingSoffit", ceiling, (x, 4.98, 0), (0.55, 0.20, 12.0), "service_metal")
    for z in (-5.72, 5.72):
        B.box("CeilingSoffit", ceiling, (0, 4.98, z), (10.0, 0.20, 0.55), "service_metal")
    B.box("MainDuct", ceiling, (0, 4.94, 0), (0.82, 0.26, 10.9), "ceiling_panel")
    B.box("CableTray", ceiling, (0.72, 4.86, 0), (0.30, 0.08, 10.9), "frame_metal")
    B.cyl("PipeWater", ceiling, (-0.78, 4.90, 0), 0.055, 10.9, "stainless", (math.pi / 2, 0, 0), 18)
    B.cyl("PipeAir", ceiling, (-0.92, 4.84, 0), 0.038, 10.9, "frame_metal", (math.pi / 2, 0, 0), 16)
    for z in (-3.6, 0.0, 3.6):
        B.box("CeilingBeam", ceiling, (0, 5.03, z), (10.0, 0.24, 0.24), "service_metal")
    for x in (-2.3, 2.3):
        for z in (-4.5, -1.5, 1.5, 4.5):
            B.box("LightHousing", ceiling, (x, 5.13, z), (1.78, 0.09, 0.36), "frame_metal")
            B.box("LightPanel", ceiling, (x, 5.075, z), (1.62, 0.025, 0.25), "light_panel")
    for x in (-3.8, 3.8):
        for z in (-3.0, 3.0):
            B.box("Diffuser", ceiling, (x, 5.12, z), (0.78, 0.05, 0.28), "dark_metal")
            for i in range(4):
                B.box("DiffuserSlat", ceiling, (x - 0.27 + i * 0.18, 5.085, z), (0.07, 0.018, 0.24), "stainless")
    B.cyl("SprinklerPipe", ceiling, (0, 5.02, -5.45), 0.026, 9.4, "frame_metal", (0, 0, math.pi / 2), 14)
    for x in (-4.0, -2.0, 0.0, 2.0, 4.0):
        B.cyl("SprinklerHead", ceiling, (x, 4.94, -5.45), 0.018, 0.11, "brushed_metal", segments=10)
    for x, z in [(-4.2, -5.2), (4.2, 5.2)]:
        B.cyl("SmokeDetector", ceiling, (x, 5.10, z), 0.075, 0.045, "plastic_white", segments=20)
    B.sphere("CeilingCamera", ceiling, (4.55, 5.02, -5.45), 0.085, "glass_dark")


def door_and_window() -> None:
    door = B.group("Door", "Architecture")
    # Porta técnica fechada, com batente real e folha de 40 mm.
    B.box("DoorFrameTop", door, (-2.2, 2.62, 6.02), (1.72, 0.16, 0.28), "frame_metal")
    B.box("DoorFrameLeft", door, (-3.02, 1.31, 6.02), (0.14, 2.68, 0.28), "frame_metal")
    B.box("DoorFrameRight", door, (-1.38, 1.31, 6.02), (0.14, 2.68, 0.28), "frame_metal")
    B.box("DoorLeaf", door, (-2.2, 1.30, 6.03), (1.46, 2.56, 0.075), "cabinet_teal")
    B.box("DoorKickPlate", door, (-2.2, 0.28, 5.975), (1.30, 0.34, 0.018), "brushed_metal")
    B.box("DoorVisionFrame", door, (-2.52, 1.72, 5.982), (0.34, 0.98, 0.025), "frame_metal")
    B.box("DoorVisionGlass", door, (-2.52, 1.72, 5.978), (0.25, 0.88, 0.012), "glass")
    B.box("DoorHandlePlate", door, (-1.62, 1.05, 5.972), (0.09, 0.28, 0.018), "stainless")
    B.cyl("DoorHandle", door, (-1.70, 1.08, 5.94), 0.018, 0.34, "stainless", (0, 0, math.pi / 2), 12)
    B.box("DoorCloser", door, (-1.72, 2.36, 5.96), (0.34, 0.09, 0.07), "dark_metal")
    for y in (0.45, 1.30, 2.15):
        B.box("DoorHinge", door, (-2.90, y, 5.965), (0.055, 0.14, 0.025), "stainless")
    B.box("CardReader", door, (-1.18, 1.28, 5.90), (0.11, 0.19, 0.045), "plastic_black")
    B.box("CardReaderLight", door, (-1.18, 1.34, 5.872), (0.035, 0.018, 0.008), "indicator_green")
    B.box("ExitSignPlate", door, (-2.2, 2.92, 5.90), (0.62, 0.20, 0.035), "safety_green")
    B.label("ExitSign", door, (-2.2, 2.92, 5.875), "SAÍDA", math.pi, 38, (0.94, 0.97, 0.94, 1), 0.0020)
    B.box("RoomSignPlate", door, (-0.72, 1.72, 5.91), (0.54, 0.30, 0.025), "plastic_white")
    B.label("RoomSign", door, (-0.72, 1.76, 5.887), "PESQUISA 04", math.pi, 34, (0.08, 0.10, 0.11, 1), 0.0017)
    B.label("RoomSignSub", door, (-0.72, 1.63, 5.887), "ANÁLISE CIENTÍFICA", math.pi, 22, (0.20, 0.24, 0.25, 1), 0.0015)

    window = B.group("ObservationWindow", "Architecture")
    # Janela flush de observação: dois panos, montante central e peitoril técnico.
    B.box("WindowSill", window, (4.94, 0.98, -1.0), (0.16, 0.09, 3.95), "brushed_metal")
    B.box("WindowHead", window, (4.94, 2.62, -1.0), (0.16, 0.10, 3.95), "frame_metal")
    B.box("WindowJambA", window, (4.94, 1.80, -2.94), (0.16, 1.70, 0.12), "frame_metal")
    B.box("WindowJambB", window, (4.94, 1.80, 0.94), (0.16, 1.70, 0.12), "frame_metal")
    B.box("WindowMullion", window, (4.94, 1.80, -1.0), (0.13, 1.58, 0.09), "frame_metal")
    B.box("WindowGlassA", window, (4.955, 1.80, -1.97), (0.025, 1.48, 1.78), "glass")
    B.box("WindowGlassB", window, (4.955, 1.80, -0.03), (0.025, 1.48, 1.78), "glass")
    B.box("WindowSignPlate", window, (4.90, 2.88, -1.0), (0.025, 0.24, 0.78), "plastic_white")
    B.label("WindowSign", window, (4.875, 2.88, -1.0), "OBSERVAÇÃO", math.pi / 2, 30, (0.08, 0.10, 0.11, 1), 0.0016)
    # Painéis de fechamento acima dos vãos, no mesmo plano dos painéis principais.
    B.box("DoorTransomPanel", door, (-2.2, 3.02, 5.965), (1.58, 0.58, 0.07), "wall_panel")
    B.box("WindowTransomPanel", window, (4.965, 3.00, -1.0), (0.07, 0.62, 3.82), "wall_panel")

    outside = B.group("ExteriorObservation", "Architecture")
    B.box("ObsFloor", outside, (6.45, -0.06, -1.0), (2.9, 0.10, 5.6), "outside_dark")
    B.box("ObsBackWall", outside, (7.85, 1.55, -1.0), (0.18, 3.3, 5.6), "outside_dark")
    B.box("ObsCeiling", outside, (6.45, 3.20, -1.0), (2.9, 0.16, 5.6), "outside_dark")
    B.box("ObsSideA", outside, (6.45, 1.55, -3.85), (2.9, 3.3, 0.18), "outside_dark")
    B.box("ObsSideB", outside, (6.45, 1.55, 1.85), (2.9, 3.3, 0.18), "outside_dark")
    B.box("ObsBackPanel", outside, (7.72, 1.55, -1.0), (0.05, 2.60, 4.80), "cabinet_dark")
    B.box("ObsDesk", outside, (7.05, 0.78, -1.0), (0.75, 0.06, 2.6), "cabinet_dark")
    B.box("ObsDeskLegA", outside, (7.05, 0.38, -2.15), (0.58, 0.76, 0.06), "frame_metal")
    B.box("ObsDeskLegB", outside, (7.05, 0.38, 0.15), (0.58, 0.76, 0.06), "frame_metal")
    B.box("ObsChairSeat", outside, (6.55, 0.52, -0.55), (0.48, 0.06, 0.46), "plastic_black")
    B.box("ObsChairBack", outside, (6.82, 0.88, -0.55), (0.06, 0.58, 0.44), "plastic_black")
    B.box("ObsConsole", outside, (6.82, 1.25, -1.45), (0.48, 0.42, 0.08), "plastic_black", (0, 0, -0.18))
    B.box("ObsScreen", outside, (6.79, 1.26, -1.45), (0.42, 0.34, 0.015), "screen_dim", (0, 0, -0.18))
    B.box("ObsLightStrip", outside, (6.45, 3.08, -1.0), (1.8, 0.035, 0.18), "task_light")
    vest = B.group("EntryVestibule", "Architecture")
    B.box("VestFloor", vest, (-2.2, -0.06, 7.35), (3.2, 0.10, 2.3), "outside_dark")
    B.box("VestBackWall", vest, (-2.2, 1.45, 8.52), (3.2, 3.1, 0.18), "outside_dark")
    B.box("VestSideA", vest, (-3.82, 1.45, 7.35), (0.18, 3.1, 2.3), "outside_dark")
    B.box("VestSideB", vest, (-0.58, 1.45, 7.35), (0.18, 3.1, 2.3), "outside_dark")
    B.box("VestCeiling", vest, (-2.2, 3.02, 7.35), (3.2, 0.14, 2.3), "outside_dark")
    B.box("VestDoor", vest, (-2.2, 1.28, 8.40), (1.25, 2.48, 0.07), "cabinet_dark")
    B.box("VestLight", vest, (-2.2, 2.90, 7.35), (0.85, 0.04, 0.16), "task_light")


def bench_cabinet_run(parent: str, axis: str, fixed: float, start: float, length: float, name: str, front_sign: float = 1.0) -> None:
    """Bancada encostada: axis='z' corre ao longo de Z; axis='x' ao longo de X."""
    count = max(1, int(length // 1.05))
    step = length / count
    for i in range(count):
        c = start + step * (i + 0.5)
        if axis == "z":
            B.box(f"{name}Cabinet", parent, (fixed, 0.47, c), (0.68, 0.76, step - 0.07), "cabinet")
            B.box(f"{name}Front", parent, (fixed + front_sign * 0.355, 0.52, c), (0.025, 0.58, step - 0.16), "cabinet_dark" if i % 3 == 1 else "cabinet")
            B.box(f"{name}DrawerLine", parent, (fixed + front_sign * 0.372, 0.72, c), (0.012, 0.018, step - 0.22), "frame_metal")
            B.cyl(f"{name}Handle", parent, (fixed + front_sign * 0.39, 0.64, c), 0.011, 0.34, "stainless", (math.pi / 2, 0, 0), 10)
        else:
            B.box(f"{name}Cabinet", parent, (c, 0.47, fixed), (step - 0.07, 0.76, 0.68), "cabinet")
            B.box(f"{name}Front", parent, (c, 0.52, fixed - 0.355), (step - 0.16, 0.58, 0.025), "cabinet_dark" if i % 3 == 1 else "cabinet")
            B.box(f"{name}DrawerLine", parent, (c, 0.72, fixed - 0.372), (step - 0.22, 0.018, 0.012), "frame_metal")
            B.cyl(f"{name}Handle", parent, (c, 0.64, fixed - 0.39), 0.011, 0.34, "stainless", (0, 0, math.pi / 2), 10)


def furniture() -> None:
    furniture = B.group("Furniture")
    west = B.group("WestBench", furniture)
    B.box("WestBenchTop", west, (-4.56, 0.92, -1.4), (0.82, 0.07, 6.6), "bench_top")
    B.box("WestToeKick", west, (-4.66, 0.10, -1.4), (0.58, 0.16, 6.5), "dark_metal")
    bench_cabinet_run(west, "z", -4.60, -4.55, 6.3, "West")
    B.box("WestServiceTrunk", west, (-4.88, 1.18, -1.4), (0.16, 0.20, 6.3), "service_metal")
    for z in (-4.2, -3.0, -1.8, -0.6, 0.6, 1.8):
        B.box("BenchOutlet", west, (-4.78, 1.18, z), (0.025, 0.10, 0.20), "plastic_white")
        B.box("BenchOutletSlot", west, (-4.765, 1.18, z), (0.008, 0.045, 0.10), "plastic_black")
    for y in (1.72, 2.18):
        B.box("WestShelf", west, (-4.78, y, -1.6), (0.38, 0.045, 5.6), "brushed_metal")
    for z in (-4.35, -1.6, 1.15):
        B.box("WestShelfUpright", west, (-4.78, 1.95, z), (0.34, 0.52, 0.045), "frame_metal")
    B.box("SinkBasin", west, (-4.56, 0.965, 0.72), (0.58, 0.035, 0.82), "dark_metal")
    B.cyl("FaucetPost", west, (-4.82, 1.10, 0.72), 0.022, 0.32, "stainless", segments=12)
    B.cyl("FaucetArm", west, (-4.70, 1.25, 0.72), 0.018, 0.34, "stainless", (0, 0, math.pi / 2), 12)

    island = B.group("IslandBench", furniture)
    B.box("IslandTop", island, (0, 0.93, -0.55), (5.0, 0.08, 1.18), "bench_top")
    B.box("IslandToeA", island, (-1.2, 0.10, -0.55), (2.2, 0.16, 0.86), "dark_metal")
    B.box("IslandToeB", island, (1.2, 0.10, -0.55), (2.2, 0.16, 0.86), "dark_metal")
    for side in (-0.31, 0.31):
        for i, x in enumerate((-1.85, -0.65, 0.65, 1.85)):
            B.box("IslandCabinet", island, (x, 0.50, -0.55 + side), (1.05, 0.74, 0.48), "cabinet_teal" if i == 2 else "cabinet")
            front_z = -0.55 + side + (0.255 if side > 0 else -0.255)
            B.box("IslandFront", island, (x, 0.55, front_z), (0.88, 0.52, 0.022), "cabinet_dark" if i % 2 else "cabinet")
            B.cyl("IslandHandle", island, (x, 0.70, front_z + (0.025 if side > 0 else -0.025)), 0.010, 0.30, "stainless", (0, 0, math.pi / 2), 10)
    B.box("IslandServiceSpine", island, (0, 1.10, -0.55), (4.35, 0.18, 0.22), "service_metal")
    B.box("IslandShelf", island, (0, 1.48, -0.55), (4.15, 0.045, 0.34), "brushed_metal")
    for x in (-2.0, 0.0, 2.0):
        B.box("IslandShelfPost", island, (x, 1.28, -0.55), (0.045, 0.42, 0.045), "frame_metal")
    for x in (-1.8, -0.6, 0.6, 1.8):
        for side in (-0.14, 0.14):
            B.box("IslandOutlet", island, (x, 1.10, -0.55 + side), (0.18, 0.09, 0.018), "plastic_white")

    east = B.group("EastAnalysisBench", furniture)
    B.box("EastBenchTop", east, (4.55, 0.91, 2.15), (0.78, 0.07, 3.7), "bench_top")
    bench_cabinet_run(east, "z", 4.60, 0.55, 3.3, "East", front_sign=-1.0)

    desk = B.group("WorkstationDesk", furniture)
    B.box("DeskTop", desk, (2.85, 0.78, 5.48), (2.35, 0.06, 0.72), "bench_top")
    B.box("DeskCabinet", desk, (1.88, 0.39, 5.48), (0.55, 0.72, 0.62), "cabinet_dark")
    B.box("DeskLeg", desk, (3.82, 0.39, 5.48), (0.06, 0.72, 0.62), "frame_metal")
    for i in range(3):
        B.box("DeskDrawer", desk, (1.88, 0.28 + i * 0.22, 5.15), (0.44, 0.15, 0.018), "cabinet")
    B.box("DeskModesty", desk, (2.85, 0.52, 5.76), (2.2, 0.42, 0.035), "cabinet_dark")

    storage = B.group("Storage", furniture)
    for i, x in enumerate((0.65, 1.55, 2.45)):
        B.box("TallCabinet", storage, (x, 1.35, -5.52), (0.82, 2.62, 0.62), "cabinet")
        B.box("TallCabinetDoor", storage, (x, 1.42, -5.20), (0.68, 2.28, 0.025), "cabinet_dark" if i == 1 else "cabinet")
        B.cyl("TallCabinetHandle", storage, (x + 0.25, 1.35, -5.17), 0.011, 0.42, "stainless", segments=10)
        B.box("TallCabinetVent", storage, (x, 2.48, -5.185), (0.48, 0.10, 0.012), "dark_metal")
    B.box("MobileCartTop", storage, (-3.75, 0.82, 4.65), (0.92, 0.05, 0.58), "stainless")
    B.box("MobileCartShelf", storage, (-3.75, 0.38, 4.65), (0.86, 0.04, 0.52), "frame_metal")
    for dx in (-0.40, 0.40):
        for dz in (-0.23, 0.23):
            B.cyl("CartPost", storage, (-3.75 + dx, 0.58, 4.65 + dz), 0.016, 0.62, "stainless", segments=10)
            B.cyl("CartWheel", storage, (-3.75 + dx, 0.055, 4.65 + dz), 0.052, 0.035, "rubber", (math.pi / 2, 0, 0), 14)
    # Banquetas e cadeira de escritório.
    for i, (x, z) in enumerate([(-1.55, 0.48), (0.35, 0.48), (1.65, -1.62), (-0.85, -1.62)]):
        B.cyl(f"StoolSeat{i}", furniture, (x, 0.64, z), 0.19, 0.055, "plastic_black", segments=24)
        B.cyl(f"StoolPost{i}", furniture, (x, 0.34, z), 0.028, 0.56, "stainless", segments=12)
        B.cyl(f"StoolRing{i}", furniture, (x, 0.24, z), 0.16, 0.018, "frame_metal", segments=24)
        B.cyl(f"StoolBase{i}", furniture, (x, 0.035, z), 0.24, 0.035, "dark_metal", segments=24)
    chair = B.group("OfficeChair", furniture)
    B.box("ChairSeat", chair, (2.85, 0.52, 4.72), (0.52, 0.07, 0.50), "plastic_black")
    B.box("ChairBack", chair, (2.85, 0.92, 4.99), (0.50, 0.62, 0.07), "plastic_black", (-0.10, 0, 0))
    B.cyl("ChairPost", chair, (2.85, 0.27, 4.78), 0.028, 0.46, "stainless", segments=12)
    for yaw in (0.0, 2.1, 4.2):
        B.box("ChairLeg", chair, (2.85, 0.055, 4.78), (0.62, 0.035, 0.07), "dark_metal", (0, yaw, 0))


def equipment() -> None:
    equip = B.group("Equipment")
    hood = B.group("FumeHood", equip)
    B.box("HoodBase", hood, (-2.3, 0.46, -5.48), (2.45, 0.84, 0.82), "cabinet_dark")
    B.box("HoodWorktop", hood, (-2.3, 0.94, -5.48), (2.55, 0.07, 0.92), "bench_top")
    B.box("HoodLeftPost", hood, (-3.48, 1.83, -5.48), (0.14, 1.78, 0.86), "stainless")
    B.box("HoodRightPost", hood, (-1.12, 1.83, -5.48), (0.14, 1.78, 0.86), "stainless")
    B.box("HoodTop", hood, (-2.3, 2.78, -5.48), (2.55, 0.28, 0.92), "cabinet")
    B.box("HoodInterior", hood, (-2.3, 1.82, -5.72), (2.18, 1.62, 0.38), "cabinet_dark")
    B.box("HoodBackPanel", hood, (-2.3, 1.82, -5.90), (2.02, 1.48, 0.035), "plastic_white")
    B.box("HoodSidePanel", hood, (-3.36, 1.82, -5.50), (0.035, 1.48, 0.72), "cabinet")
    B.box("HoodBottleA", hood, (-2.85, 1.06, -5.55), (0.16, 0.22, 0.16), "container_blue")
    B.box("HoodBottleB", hood, (-2.58, 1.04, -5.48), (0.13, 0.18, 0.13), "plastic_white")
    B.box("HoodSampleTray", hood, (-1.75, 1.005, -5.45), (0.52, 0.035, 0.34), "stainless")
    B.box("HoodSashGlass", hood, (-2.3, 2.12, -5.08), (2.18, 0.72, 0.025), "glass")
    B.box("HoodSashBar", hood, (-2.3, 1.72, -5.065), (2.22, 0.07, 0.035), "frame_metal")
    B.cyl("HoodDuct", hood, (-2.3, 3.65, -5.55), 0.19, 1.55, "brushed_metal", segments=24)
    B.box("HoodMonitor", hood, (-1.02, 1.56, -5.20), (0.16, 0.11, 0.025), "screen")
    B.box("HoodLight", hood, (-2.3, 2.56, -5.45), (1.65, 0.025, 0.18), "task_light")

    bsc = B.group("BiosafetyCabinet", equip)
    B.box("BscBody", bsc, (3.75, 1.55, -5.48), (1.55, 2.05, 0.82), "stainless")
    B.box("BscWork", bsc, (3.75, 0.91, -5.48), (1.42, 0.07, 0.76), "bench_top")
    B.box("BscGlass", bsc, (3.75, 1.72, -5.10), (1.28, 0.72, 0.025), "glass", (-0.10, 0, 0))
    B.box("BscInterior", bsc, (3.75, 1.48, -5.68), (1.30, 0.95, 0.34), "cabinet_dark")
    B.box("BscBackPanel", bsc, (3.75, 1.48, -5.82), (1.18, 0.86, 0.03), "plastic_white")
    B.box("BscTray", bsc, (3.48, 0.985, -5.48), (0.42, 0.03, 0.30), "stainless")
    B.box("BscContainer", bsc, (3.98, 1.06, -5.52), (0.20, 0.14, 0.18), "container_blue")
    B.box("BscGrille", bsc, (3.75, 1.02, -5.13), (1.28, 0.13, 0.018), "dark_metal")
    B.box("BscDisplay", bsc, (4.38, 2.22, -5.08), (0.22, 0.12, 0.02), "screen")

    fridge = B.group("LaboratoryRefrigerator", equip)
    B.box("FridgeBody", fridge, (4.48, 1.08, -4.15), (0.88, 2.16, 0.82), "plastic_white")
    B.box("FridgeDoorLine", fridge, (4.02, 1.12, -4.15), (0.018, 1.92, 0.68), "frame_metal")
    B.cyl("FridgeHandle", fridge, (3.99, 1.22, -3.86), 0.014, 0.48, "stainless", segments=10)
    B.box("FridgeDisplay", fridge, (4.015, 1.78, -4.15), (0.018, 0.13, 0.22), "screen")
    B.box("FridgeVent", fridge, (4.48, 0.16, -3.76), (0.70, 0.18, 0.018), "dark_metal")

    incubator = B.group("Incubator", equip)
    B.box("IncubatorBody", incubator, (4.50, 0.92, -2.55), (0.86, 1.78, 0.78), "cabinet")
    B.box("IncubatorGlass", incubator, (4.05, 1.05, -2.55), (0.022, 1.25, 0.58), "glass_dark")
    B.box("IncubatorDisplay", incubator, (4.045, 1.78, -2.55), (0.018, 0.14, 0.24), "screen")
    for y in (0.68, 1.02, 1.36):
        B.box("IncubatorShelf", incubator, (4.18, y, -2.55), (0.42, 0.018, 0.58), "stainless")

    # Instrumentos de bancada: silhuetas plausíveis, sem telas holográficas.
    island = B.group("IslandInstruments", equip)
    # Microscópio.
    B.box("MicroscopeBase", island, (-1.55, 1.015, -0.55), (0.34, 0.07, 0.26), "plastic_black")
    B.box("MicroscopeStage", island, (-1.55, 1.10, -0.55), (0.28, 0.035, 0.22), "dark_metal")
    B.box("MicroscopeArm", island, (-1.42, 1.23, -0.55), (0.07, 0.30, 0.09), "plastic_black", (0, 0, -0.25))
    B.cyl("MicroscopeTube", island, (-1.58, 1.34, -0.55), 0.032, 0.30, "plastic_black", (0, 0, 0.55), 14)
    B.cyl("MicroscopeObjective", island, (-1.62, 1.17, -0.55), 0.020, 0.10, "stainless", segments=12)
    # Centrífuga.
    B.box("CentrifugeBody", island, (0.35, 1.13, -0.58), (0.52, 0.34, 0.46), "plastic_white")
    B.cyl("CentrifugeLid", island, (0.35, 1.325, -0.58), 0.20, 0.045, "cabinet_dark", segments=28)
    B.box("CentrifugeDisplay", island, (0.35, 1.16, -0.345), (0.22, 0.10, 0.018), "screen")
    # Analisador com tampa e leitor.
    B.box("AnalyzerBody", island, (1.65, 1.16, -0.58), (0.62, 0.40, 0.48), "cabinet")
    B.box("AnalyzerLid", island, (1.65, 1.39, -0.60), (0.56, 0.055, 0.42), "cabinet_dark")
    B.box("AnalyzerScreen", island, (1.47, 1.20, -0.335), (0.24, 0.15, 0.018), "screen", (-0.08, 0, 0))
    B.cyl("AnalyzerPort", island, (1.88, 1.12, -0.34), 0.045, 0.025, "dark_metal", (math.pi / 2, 0, 0), 16)
    # Espectrofotômetro na bancada leste.
    B.box("SpectroBody", equip, (4.52, 1.08, 1.35), (0.58, 0.28, 0.72), "plastic_white")
    B.box("SpectroLid", equip, (4.52, 1.24, 1.35), (0.52, 0.035, 0.62), "cabinet_dark")
    B.box("SpectroDisplay", equip, (4.22, 1.12, 1.12), (0.018, 0.11, 0.20), "screen")
    # Balança analítica com cabine de vidro.
    B.box("BalanceBase", equip, (4.52, 1.02, 2.25), (0.52, 0.16, 0.55), "plastic_white")
    B.box("BalanceGlass", equip, (4.52, 1.25, 2.25), (0.46, 0.34, 0.48), "glass")
    B.cyl("BalancePan", equip, (4.52, 1.12, 2.25), 0.09, 0.018, "stainless", segments=20)
    B.box("BalanceDisplay", equip, (4.25, 1.03, 2.25), (0.018, 0.09, 0.18), "screen")
    # Computadores da estação de trabalho.
    for x in (2.48, 3.22):
        B.box("MonitorFrame", equip, (x, 1.23, 5.62), (0.58, 0.36, 0.035), "plastic_black", (-0.06, 0, 0))
        B.box("MonitorScreen", equip, (x, 1.23, 5.598), (0.52, 0.30, 0.012), "screen", (-0.06, 0, 0))
        B.box("MonitorStand", equip, (x, 0.98, 5.66), (0.07, 0.34, 0.07), "dark_metal")
        B.box("MonitorFoot", equip, (x, 0.825, 5.62), (0.28, 0.025, 0.20), "dark_metal")
    B.box("Keyboard", equip, (2.85, 0.825, 5.28), (0.46, 0.025, 0.17), "plastic_black", (0, 0.04, 0))
    B.box("Mouse", equip, (3.38, 0.83, 5.30), (0.07, 0.03, 0.11), "plastic_black")
    B.box("ComputerTower", equip, (3.72, 0.48, 5.55), (0.22, 0.48, 0.52), "plastic_black")
    B.box("ComputerLight", equip, (3.60, 0.58, 5.30), (0.018, 0.018, 0.018), "indicator_green")


def props_and_details() -> None:
    props = B.group("Props")
    # Garrafas e recipientes com tampas, em grupos pequenos e intencionais.
    bottle_positions = [
        (-4.62, 1.755, -3.55, "container_blue"), (-4.72, 1.755, -3.28, "plastic_white"),
        (-4.55, 2.235, -2.10, "container_gray"), (-4.70, 2.235, -1.82, "container_blue"),
        (-1.05, 1.535, -0.55, "plastic_white"), (-0.78, 1.535, -0.55, "container_blue"),
        (0.92, 1.535, -0.55, "container_gray"), (4.50, 0.985, 3.05, "container_blue"),
    ]
    for i, (x, y, z, mat) in enumerate(bottle_positions):
        B.cyl(f"Bottle{i}", props, (x, y + 0.07, z), 0.045, 0.14, mat, segments=16)
        B.cyl(f"BottleNeck{i}", props, (x, y + 0.155, z), 0.018, 0.045, mat, segments=12)
        B.cyl(f"BottleCap{i}", props, (x, y + 0.185, z), 0.021, 0.025, "plastic_black", segments=12)
    for i, (x, y, z, sx, sz, mat) in enumerate([
        (-4.72, 1.76, -0.95, 0.26, 0.34, "cardboard"), (-4.70, 2.26, -3.85, 0.30, 0.38, "container_gray"),
        (1.25, 1.53, -0.55, 0.32, 0.24, "cardboard"), (2.05, 1.02, -0.48, 0.36, 0.28, "container_gray"),
        (4.48, 1.02, 3.48, 0.38, 0.30, "cardboard"), (-3.75, 0.87, 4.65, 0.34, 0.24, "container_blue"),
    ]):
        B.box(f"StorageBox{i}", props, (x, y, z), (sx, 0.16, sz), mat)
    for i, (x, z, yaw) in enumerate([(-0.25, -0.42, 0.12), (0.05, -0.68, -0.08), (2.62, 5.42, 0.03), (-4.38, -1.15, 0.20)]):
        y = 0.975 if z < 5 else 0.815
        if z < -4:
            y = 0.975
        B.box(f"PaperSheet{i}", props, (x, y, z), (0.22, 0.006, 0.30), "paper", (0, yaw, 0))
    for i, x in enumerate((-1.35, -1.22, -1.09, 1.08, 1.21)):
        B.box(f"Binder{i}", props, (x, 1.60, -0.55), (0.055, 0.24, 0.22), "cabinet_teal" if i % 2 else "container_gray")
    B.box("Clipboard", props, (0.48, 0.982, -0.28), (0.24, 0.012, 0.32), "cardboard", (0, -0.18, 0))
    B.box("ClipboardPaper", props, (0.48, 0.992, -0.28), (0.20, 0.006, 0.27), "paper", (0, -0.18, 0))
    # Lixeiras técnicas e recipientes de resíduos.
    B.cyl("WasteBinYellow", props, (-4.35, 0.31, 2.55), 0.19, 0.58, "safety_yellow", segments=24)
    B.cyl("WasteBinGray", props, (4.30, 0.29, 4.55), 0.18, 0.54, "container_gray", segments=24)

    details = B.group("TechnicalDetails")
    # Painéis elétricos e de utilidades na parede norte.
    for i, x in enumerate((-4.15, -3.55)):
        B.box(f"ElectricalPanel{i}", details, (x, 1.72, -5.90), (0.52, 0.92, 0.07), "service_metal")
        B.box(f"ElectricalPanelSeam{i}", details, (x, 1.72, -5.858), (0.44, 0.82, 0.008), "frame_metal")
        B.box(f"ElectricalLight{i}", details, (x - 0.14, 1.98, -5.85), (0.035, 0.035, 0.012), "indicator_green")
        B.box(f"ElectricalLightB{i}", details, (x + 0.02, 1.98, -5.85), (0.035, 0.035, 0.012), "indicator_amber")
    # Grelhas no band técnico.
    for side, positions in {
        "north": [(-3.6, -5.90, 0), (3.6, -5.90, 0)],
        "west": [(-4.90, -3.4, math.pi / 2), (-4.90, 2.8, math.pi / 2)],
        "south": [(3.9, 5.90, math.pi)],
    }.items():
        for x, z, yaw in positions:
            pos = (x, 3.70, z)
            size = (0.92, 0.42, 0.035) if side != "west" else (0.035, 0.42, 0.92)
            B.box(f"VentGrille_{side}", details, pos, size, "dark_metal")
            for j in range(4):
                if side == "west":
                    B.box(f"VentSlat_{side}", details, (x - 0.022, 3.57 + j * 0.09, z), (0.012, 0.025, 0.80), "stainless")
                else:
                    B.box(f"VentSlat_{side}", details, (x, 3.57 + j * 0.09, z - (0.022 if side == "north" else -0.022)), (0.80, 0.025, 0.012), "stainless")
    # Pontos de gases e tomadas na espinha da ilha.
    for x, mat in [(-1.45, "container_blue"), (-1.28, "safety_green"), (-1.11, "safety_yellow"), (1.28, "container_blue"), (1.45, "safety_green")]:
        B.cyl("GasPoint", details, (x, 1.13, -0.40), 0.020, 0.055, mat, (math.pi / 2, 0, 0), 12)
    # Extintor, primeiros socorros e chuveiro/lava-olhos discretos.
    B.cyl("FireExtinguisher", details, (-4.72, 0.78, 3.72), 0.085, 0.48, "safety_red", segments=20)
    B.cyl("ExtinguisherNozzle", details, (-4.66, 1.08, 3.72), 0.016, 0.22, "plastic_black", (0, 0, 0.7), 10)
    B.box("ExtinguisherSign", details, (-4.91, 1.48, 3.72), (0.025, 0.30, 0.24), "safety_red")
    B.label("ExtinguisherLabel", details, (-4.895, 1.48, 3.72), "EXTINTOR", -math.pi / 2, 26, (0.96, 0.96, 0.94, 1), 0.0014)
    B.box("FirstAidBox", details, (-4.91, 1.62, 4.38), (0.07, 0.32, 0.42), "plastic_white")
    B.box("FirstAidCrossV", details, (-4.868, 1.62, 4.38), (0.012, 0.20, 0.055), "safety_red")
    B.box("FirstAidCrossH", details, (-4.868, 1.62, 4.38), (0.012, 0.055, 0.20), "safety_red")
    B.box("SafetySignPlate", details, (-4.91, 2.05, 1.55), (0.025, 0.34, 0.58), "safety_yellow")
    B.label("SafetySign", details, (-4.895, 2.08, 1.55), "EPI OBRIGATÓRIO", -math.pi / 2, 28, (0.05, 0.05, 0.04, 1), 0.0015)
    B.cyl("EyewashPipe", details, (-4.82, 2.15, 2.45), 0.022, 1.05, "stainless", segments=12)
    B.cyl("EyewashArm", details, (-4.62, 2.64, 2.45), 0.018, 0.42, "stainless", (0, 0, math.pi / 2), 12)
    B.cyl("EyewashDrop", details, (-4.48, 2.52, 2.45), 0.016, 0.24, "stainless", segments=10)
    B.cyl("EyewashBowl", details, (-4.48, 2.38, 2.45), 0.16, 0.07, "safety_green", segments=24)
    B.box("EyewashDrain", details, (-4.48, 2.30, 2.45), (0.20, 0.035, 0.20), "frame_metal")
    # Câmera, sensor e interruptor junto à porta.
    B.sphere("DoorCamera", details, (-4.45, 4.78, 5.55), 0.075, "glass_dark")
    B.cyl("PirSensor", details, (4.55, 4.72, 5.55), 0.055, 0.035, "plastic_white", segments=16)
    B.box("LightSwitch", details, (-1.05, 1.28, 5.91), (0.11, 0.17, 0.025), "plastic_white")
    B.box("LightSwitchToggle", details, (-1.05, 1.28, 5.895), (0.025, 0.055, 0.010), "plastic_black")
    # Cabos curtos e organizados dos instrumentos até a espinha.
    for x in (-1.55, 0.35, 1.65):
        B.cyl("InstrumentCable", details, (x, 1.02, -0.43), 0.008, 0.20, "rubber", (math.pi / 2, 0, 0), 8)
    # Placas pequenas de identificação de bancadas/armários.
    B.box("BenchSignPlate", details, (0, 1.10, -0.438), (0.62, 0.16, 0.018), "plastic_white")
    B.label("BenchSign", details, (0, 1.10, -0.425), "BANCADA CENTRAL", 0, 25, (0.08, 0.10, 0.11, 1), 0.0014)
    B.label("CabinetCode", details, (1.55, 2.18, -5.175), "ARM-02", 0, 28, (0.75, 0.78, 0.75, 1), 0.0015)


def lights_and_collisions() -> None:
    lights = B.group("Lighting")
    light_index = 0
    for x in (-2.3, 2.3):
        for z in (-3.0, 3.0):
            B.omni(f"MainLight{light_index}", lights, (x, 4.62, z), (0.92, 0.96, 1.0), 1.55, 9.5, 1.2, False)
            light_index += 1
    B.spot("IslandTaskLight", lights, (0, 4.95, -0.55), (0.96, 0.98, 0.94), 1.7, 7.0, 52, True)
    B.spot("WestTaskLight", lights, (-4.35, 4.95, -1.4), (0.96, 0.98, 0.94), 1.25, 6.5, 48, False)
    B.omni("ObservationLight", lights, (6.45, 2.65, -1.0), (0.55, 0.68, 0.78), 0.95, 5.0, 1.2, False)
    B.omni("HoodWorkLight", lights, (-2.3, 2.35, -4.95), (0.94, 0.97, 0.94), 0.55, 2.6, 1.25, False)
    B.omni("DoorEmergencyLight", lights, (-2.2, 3.15, 5.55), (1.0, 0.18, 0.10), 0.35, 3.2, 1.3, False)
    B.box("EmergencyFixture", lights, (-2.2, 3.18, 5.88), (0.34, 0.09, 0.06), "indicator_red")

    collision = B.group("Collision")
    B.nodes.append("[node name=\"ArchitectureBodies\" type=\"StaticBody3D\" parent=\"Collision\"]")
    B.node_count += 1
    body = "Collision/ArchitectureBodies"
    B.collider("Floor", body, (0, -0.11, 0), (10.7, 0.22, 12.7))
    B.collider("Ceiling", body, (0, 5.32, 0), (10.7, 0.22, 12.7))
    B.collider("WallNorth", body, (0, 2.6, -6.16), (10.7, 5.2, 0.32))
    B.collider("WallSouth", body, (0, 2.6, 6.16), (10.7, 5.2, 0.32))
    B.collider("WallWest", body, (-5.16, 2.6, 0), (0.32, 5.2, 12.7))
    B.collider("WallEast", body, (5.16, 2.6, 0), (0.32, 5.2, 12.7))
    B.nodes.append("[node name=\"FurnitureBodies\" type=\"StaticBody3D\" parent=\"Collision\"]")
    B.node_count += 1
    fbody = "Collision/FurnitureBodies"
    B.collider("WestBench", fbody, (-4.58, 0.48, -1.4), (0.84, 0.96, 6.6))
    B.collider("IslandBench", fbody, (0, 0.50, -0.55), (5.0, 1.0, 1.18))
    B.collider("EastBench", fbody, (4.56, 0.48, 2.15), (0.82, 0.96, 3.7))
    B.collider("FumeHood", fbody, (-2.3, 1.35, -5.48), (2.55, 2.7, 0.92))
    B.collider("BiosafetyCabinet", fbody, (3.75, 1.25, -5.48), (1.55, 2.5, 0.82))
    B.collider("Refrigerator", fbody, (4.48, 1.08, -4.15), (0.88, 2.16, 0.82))
    B.collider("Incubator", fbody, (4.50, 0.92, -2.55), (0.86, 1.84, 0.78))
    B.collider("Desk", fbody, (2.85, 0.42, 5.48), (2.35, 0.84, 0.72))
    B.collider("MobileCart", fbody, (-3.75, 0.45, 4.65), (0.92, 0.9, 0.58))
    for i, x in enumerate((0.65, 1.55, 2.45)):
        B.collider(f"TallCabinet{i}", fbody, (x, 1.35, -5.52), (0.82, 2.7, 0.62))
    for i, (x, z) in enumerate([(-1.55, 0.48), (0.35, 0.48), (1.65, -1.62), (-0.85, -1.62), (2.85, 4.78)]):
        B.collider(f"Seat{i}", fbody, (x, 0.35, z), (0.52, 0.7, 0.52))


def build_scene() -> None:
    PILOT.mkdir(parents=True, exist_ok=True)
    arch = B.group("Architecture")
    floor_and_ceiling()
    wall_panels()
    door_and_window()
    furniture()
    equipment()
    props_and_details()
    lights_and_collisions()
    # Spawn e centro: leitura humana e ponto de entrada do jogador.
    B.nodes.append("[node name=\"Spawn\" type=\"Marker3D\" parent=\".\"]\ntransform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, -2.60, 0.05, 4.35)")
    B.nodes.append("[node name=\"Center\" type=\"Marker3D\" parent=\".\"]\ntransform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 1.6, 0)")
    B.node_count += 2

    ext_lines = []
    for name in MATERIALS:
        ext_lines.append(f"[ext_resource type=\"StandardMaterial3D\" path=\"res://maps/pilot/materials/{name}.tres\" id=\"mat_{name}\"]")
    env = """[sub_resource type=\"Environment\" id=\"Env_pilot\"]
background_mode = 1
background_color = Color(0.008, 0.010, 0.014, 1)
ambient_light_source = 2
ambient_light_color = Color(0.38, 0.43, 0.50, 1)
ambient_light_energy = 0.48
tonemap_mode = 2"""
    world = "[node name=\"WorldEnvironment\" type=\"WorldEnvironment\" parent=\".\"]\nenvironment = SubResource(\"Env_pilot\")"
    load_steps = len(MATERIALS) + len(B.subresources) + 2
    header = f"[gd_scene load_steps={load_steps} format=3]\n\n" + "\n".join(ext_lines) + "\n\n" + env + "\n\n" + "\n\n".join(B.subresources)
    scene = header + "\n\n[node name=\"PilotResearchRoom\" type=\"Node3D\"]\n\n" + "\n\n".join(B.nodes) + "\n\n" + world + "\n"
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
