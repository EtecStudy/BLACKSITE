#!/usr/bin/env python3
"""Desenha a planta do primeiro andar para o `docs/ETAPA-12A.md`.

Uso:
    python3 tools/arch/render_plan.py [saida.png]

Dependência: Pillow (`pip install pillow`). Não faz parte do jogo nem do
build; serve para revisar a planta e publicar o mapa de referência.
"""

from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

import build_first_floor as plan  # noqa: E402  (mesma pasta)

from PIL import Image, ImageDraw  # noqa: E402

SCALE = 7.0
COLORS = {
    "room": (46, 54, 68),
    "corridor": (30, 66, 62),
    "hall": (84, 66, 38),
}
OPENING_COLORS = {
    "door": (95, 240, 135),
    "opening": (95, 155, 255),
    "mouth": (255, 190, 80),
}


def render(path: Path) -> tuple[int, int]:
    min_x = min(s.x0 for s in plan.SPACES) - 4
    max_x = max(s.x1 for s in plan.SPACES) + 4
    min_z = min(s.z0 for s in plan.SPACES) - 4
    max_z = max(s.z1 for s in plan.SPACES) + 4
    width = int((max_x - min_x) * SCALE)
    height = int((max_z - min_z) * SCALE)
    image = Image.new("RGB", (width, height), (11, 12, 15))
    draw = ImageDraw.Draw(image)

    def px(x: float, z: float) -> tuple[float, float]:
        return ((x - min_x) * SCALE, (z - min_z) * SCALE)

    for space in plan.SPACES:
        draw.rectangle([px(space.x0, space.z0), px(space.x1, space.z1)],
                       fill=COLORS[space.kind])

    for axis, cell, start, end, storeys in plan.wall_bands():
        c = plan.line(cell)
        a = plan.line(start)
        b = plan.line(end)
        color = (200, 205, 215) if storeys > 6 else (150, 156, 168)
        if axis == "z":
            draw.rectangle([px(a, c - 0.2), px(b, c + 0.2)], fill=color)
        else:
            draw.rectangle([px(c - 0.2, a), px(c + 0.2, b)], fill=color)

    for opening in plan.OPENINGS:
        c = plan.line(opening.cell)
        a = plan.line(opening.start)
        b = plan.line(opening.start + opening.span)
        color = OPENING_COLORS[opening.kind]
        if opening.axis == "z":
            draw.rectangle([px(a, c - 0.36), px(b, c + 0.36)], fill=color)
        else:
            draw.rectangle([px(c - 0.36, a), px(c + 0.36, b)], fill=color)

    for partition in plan.PARTITIONS:
        c = plan.line(partition.cell)
        a = plan.line(partition.start)
        b = plan.line(partition.end)
        if partition.axis == "z":
            draw.rectangle([px(a, c - 0.14), px(b, c + 0.14)], fill=(122, 128, 142))
        else:
            draw.rectangle([px(c - 0.14, a), px(c + 0.14, b)], fill=(122, 128, 142))

    for x, z, _levels, _space in plan.PILLARS:
        draw.rectangle([px(x - 0.46, z - 0.46), px(x + 0.46, z + 0.46)],
                       fill=(230, 204, 124))

    for stair in plan.STAIRS:
        draw.rectangle([px(stair.x0, stair.z0), px(stair.x0 + 2.0, stair.z1)],
                       fill=(64, 40, 40), outline=(240, 140, 140), width=2)

    for space in plan.SPACES:
        cx, cz = space.center
        draw.text(px(cx - space.width * 0.28, cz - 0.9), space.name, fill=(240, 242, 248))
        draw.text(px(cx - space.width * 0.28, cz + 0.6),
                  f"{space.width:.0f} x {space.depth:.0f} m  h{space.height:.0f}",
                  fill=(150, 158, 170))

    sx, sz = plan.SPAWN[0], plan.SPAWN[2]
    draw.ellipse([px(sx - 1, sz - 1), px(sx + 1, sz + 1)], fill=(255, 70, 70))

    path.parent.mkdir(parents=True, exist_ok=True)
    image.save(path)
    return image.size


def main() -> int:
    out = Path(sys.argv[1]) if len(sys.argv) > 1 else \
        Path(__file__).resolve().parents[2] / "docs/images/etapa-12a-planta.png"
    size = render(out)
    print(f"planta desenhada em {out} ({size[0]}x{size[1]})")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
