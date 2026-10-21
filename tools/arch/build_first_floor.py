#!/usr/bin/env python3
"""Gera a planta do primeiro andar do laboratório (Etapa 12A).

Fonte da verdade da planta: as tabelas abaixo. O script monta o `.tscn` com
os módulos aprovados na Etapa 11 e valida a planta antes de gravar:

  * nenhum ambiente se sobrepõe (célula de 2 m);
  * todas as paredes caem nas linhas de célula e têm comprimento par (módulos
    de 2 m), com portas/aberturas alinhadas;
  * todo o interior é coberto por piso e teto (exceto os poços das escadas);
  * todo ambiente é alcançável a pé a partir da entrada (BFS na grade);
  * não sobra vazio fechado (nenhuma célula cercada por paredes sem acesso).

Uso:
    python3 tools/arch/build_first_floor.py            # grava o .tscn
    python3 tools/arch/build_first_floor.py --check     # só valida

Convenção de coordenadas (a mesma da Etapa 11):
  * grade de 2 m; linha da célula i fica em x = 2*i + 1;
  * o interior de um ambiente vai de linha+0,2 até linha-0,2 (parede de
    0,40 m centrada na linha);
  * +X = leste, +Z = sul, y = 0 é o piso do primeiro andar.
"""

from __future__ import annotations

import json
import math
import sys
from dataclasses import dataclass, field
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SCENE_PATH = ROOT / "maps/scenes/laboratory_first_floor.tscn"
PLAN_PATH = ROOT / "tools/arch/first_floor_layout.json"

CELL = 2.0
HALF_WALL = 0.2
STOREY = 6.0


def line(index: int) -> float:
    """Coordenada (m) da linha da célula `index`."""
    return 2.0 * index + 1.0


def tile_origin(start: float, span: float) -> list[float]:
    """Centros das placas de 2 m que cobrem o vão (a última entra 0,4 na parede)."""
    count = int(round(span / 2.0 + 0.2))
    return [start + 1.0 + 2.0 * k for k in range(count)]


@dataclass
class Space:
    name: str          # nome curto usado em nós e testes
    label: str         # nome em português para documentação
    kind: str          # room | corridor | hall
    i0: int
    i1: int
    j0: int
    j1: int
    height: float = STOREY

    @property
    def x0(self) -> float:
        return line(self.i0) + HALF_WALL

    @property
    def x1(self) -> float:
        return line(self.i1) - HALF_WALL

    @property
    def z0(self) -> float:
        return line(self.j0) + HALF_WALL

    @property
    def z1(self) -> float:
        return line(self.j1) - HALF_WALL

    @property
    def width(self) -> float:
        return self.x1 - self.x0

    @property
    def depth(self) -> float:
        return self.z1 - self.z0

    @property
    def center(self) -> tuple[float, float]:
        return ((self.x0 + self.x1) / 2.0, (self.z0 + self.z1) / 2.0)


@dataclass
class Opening:
    kind: str          # door | opening | mouth
    axis: str          # 'x' parede em x=const | 'z' parede em z=const
    cell: int          # linha da célula da parede
    start: int         # célula inicial (ao longo da parede)
    span: int          # células de largura (2 = 4 m; mouth livre)


@dataclass
class Partition:
    axis: str
    cell: int
    start: int
    end: int
    openings: list[tuple[int, int, str]] = field(default_factory=list)


@dataclass
class Stair:
    name: str
    space: str
    # poço alinhado às placas: coluna x0..x0+2 e 4 linhas de 2 m em z
    x0: float
    z0: float
    z1: float
    landing_z0: float
    landing_z1: float

    @property
    def x_center(self) -> float:
        return self.x0 + 1.0

    @property
    def hole_end(self) -> float:
        """Fim do vão no piso (o resto do poço tem laje em y = 0)."""
        return self.z0 + 6.0


# ---------------------------------------------------------------------------
# PLANTA — primeiro andar (Etapa 12A)
# ---------------------------------------------------------------------------

SPACES: list[Space] = [
    # Setor A — entrada e controle
    Space("Lobby", "Entrada (vestíbulo)", "corridor", -24, -20, -4, 3),
    Space("Reception", "Recepção", "hall", -20, -8, -6, 5, 12.0),
    Space("Security", "Segurança", "room", -20, -8, -14, -6),
    Space("Control", "Posto de controle", "room", -8, 6, 1, 11),
    # Eixo principal
    Space("MainCorridorWest", "Corredor principal (oeste)", "corridor", -8, 6, -2, 1),
    Space("CentralHall", "Grande cruzamento central", "hall", 6, 17, -6, 5, 12.0),
    Space("MainCorridorEast", "Corredor principal (leste)", "corridor", 17, 38, -2, 1),
    # Setor de pesquisa (norte)
    Space("Storage", "Armazenamento", "room", -8, 6, -12, -2),
    Space("Research", "Pesquisa A", "room", 6, 17, -14, -6),
    Space("Analysis", "Análises", "room", 17, 29, -14, -2),
    Space("Observation", "Observação", "room", 29, 36, -14, -2, 12.0),
    # Setor administrativo / circulação norte
    Space("Offices", "Escritórios", "room", 17, 29, 1, 11),
    Space("Archive", "Arquivo", "room", 29, 36, 1, 11),
    Space("NorthService", "Corredor de serviço norte", "corridor", 9, 38, -16, -14),
    Space("NorthLink", "Ligação norte", "corridor", 36, 38, -14, -2),
    # Setor de funcionários e logística (sul)
    Space("Staff", "Área de funcionários", "room", 6, 17, 5, 11),
    Space("SouthService", "Corredor de serviço sul", "corridor", 6, 38, 11, 13),
    Space("SouthLink", "Ligação sul", "corridor", 36, 38, 1, 11),
    Space("Logistics", "Apoio logístico", "room", 6, 18, 13, 23),
    # Setor técnico
    Space("Electrical", "Elétrica", "room", 18, 24, 13, 23),
    Space("Maintenance", "Acesso à manutenção", "room", 24, 32, 13, 23),
    Space("StairSouthRoom", "Casa da escada sul", "room", 32, 40, 13, 23, 12.0),
    Space("StairNorthRoom", "Casa da escada norte", "room", 9, 17, -24, -16, 12.0),
]

# Portas (4 m), aberturas estruturais (4 m) e bocas de corredor (sem módulo).
OPENINGS: list[Opening] = [
    # entrada → recepção → eixo principal
    Opening("mouth", "x", -20, -2, 3),
    Opening("mouth", "x", -8, -2, 3),
    # recepção
    Opening("door", "z", -6, -18, 2),
    Opening("door", "x", -8, 1, 2),
    # corredor principal oeste
    Opening("door", "z", -2, -4, 2),
    Opening("door", "z", 1, -4, 2),
    # grande cruzamento central (bocas de 6 m para o eixo)
    Opening("mouth", "x", 6, -2, 3),
    Opening("mouth", "x", 17, -2, 3),
    # salas abertas para o cruzamento
    Opening("opening", "z", -6, 10, 2),
    Opening("door", "z", 5, 10, 2),
    Opening("door", "x", 6, -5, 2),
    Opening("door", "x", 6, 2, 2),
    Opening("door", "x", 17, -5, 2),
    Opening("door", "x", 17, 2, 2),
    # pesquisa ↔ análises (fluxo de amostras) e armazenamento
    Opening("opening", "x", 17, -10, 2),
    Opening("door", "x", 6, -10, 2),
    # parede de observação: dois vãos estruturais de 4 m entre análises e observação
    Opening("opening", "x", 29, -10, 2),
    Opening("opening", "x", 29, -6, 2),
    # corredor principal leste
    Opening("door", "z", -2, 20, 2),
    Opening("door", "z", -2, 31, 2),
    Opening("door", "z", 1, 20, 2),
    Opening("door", "z", 1, 31, 2),
    Opening("door", "z", -2, 36, 2),
    Opening("door", "z", 1, 36, 2),
    # corredor de serviço norte
    Opening("door", "z", -14, 10, 2),
    Opening("door", "z", -16, 11, 2),
    Opening("opening", "z", -14, 36, 2),
    # corredor de serviço sul
    Opening("door", "z", 11, 8, 2),
    Opening("door", "z", 11, 20, 2),
    Opening("door", "z", 11, 31, 2),
    Opening("opening", "z", 11, 36, 2),
    Opening("door", "z", 13, 8, 2),
    Opening("door", "z", 13, 20, 2),
    Opening("door", "z", 13, 26, 2),
    Opening("door", "z", 13, 34, 2),
    # setor técnico
    Opening("door", "x", 18, 16, 2),
    Opening("door", "x", 24, 16, 2),
    Opening("door", "x", 32, 16, 2),
    # controle ↔ funcionários
    Opening("door", "x", 6, 7, 2),
    # escritórios ↔ arquivo
    Opening("door", "x", 29, 4, 2),
]

# Divisórias internas (não fecham ambientes; dão escala e especialização).
PARTITIONS: list[Partition] = [
    Partition("x", 23, 1, 11, [(3, 2, "door"), (7, 2, "door")]),        # escritórios
    Partition("x", 34, 1, 11, [(3, 2, "door"), (7, 2, "door")]),        # arquivo
    Partition("z", -8, 17, 23, [(19, 2, "door")]),                       # análises (ala norte)
    Partition("x", 23, -12, -8, [(-11, 2, "door")]),                     # análises (sala fria)
    Partition("x", 13, 5, 11, [(7, 2, "door")]),                         # funcionários (apoio)
    Partition("x", -14, -14, -6, [(-11, 2, "door")]),                    # segurança (sala de vídeo)
    Partition("z", 18, 24, 32, [(27, 2, "door")]),                       # manutenção (depósito)
]

# Pilares: (x, z, níveis de 6 m, ambiente).
PILLARS: list[tuple[float, float, int, str]] = [
    (-32.0, -5.0, 2, "Reception"),
    (-22.0, -5.0, 2, "Reception"),
    (-32.0, 5.0, 2, "Reception"),
    (-22.0, 5.0, 2, "Reception"),
    (17.2, -6.8, 2, "CentralHall"),
    (29.2, -6.8, 2, "CentralHall"),
    (17.2, 6.8, 2, "CentralHall"),
    (29.2, 6.8, 2, "CentralHall"),
    (19.2, -24.0, 1, "Research"),
    (27.2, -24.0, 1, "Research"),
    (21.2, 37.2, 1, "Logistics"),
    (29.2, 37.2, 1, "Logistics"),
    (-19.2, -15.0, 1, "Security"),
    (-35.2, -15.0, 1, "Security"),
    (63.2, 8.0, 1, "Archive"),
]

# Vigas de 6 m atravessando o corredor principal (vão livre de 5,6 m).
BEAMS: list[float] = [-12.0, 0.0, 40.0, 52.0, 64.0]

# Poço alinhado às linhas da grade (x0 = linha, largura 2 m, comprimento 10 m).
STAIRS: list[Stair] = [
    Stair("StairNorth", "StairNorthRoom", 23.0, -45.0, -35.0, -39.4, -35.0),
    Stair("StairSouth", "StairSouthRoom", 67.0, 29.0, 39.0, 34.6, 39.0),
]

SPAWN = (-45.0, 0.05, 0.0)
## Rotação do nascimento em quartos de volta (1 = -90° em Y, olhando para +X/leste).
SPAWN_QUARTER = 1


# ---------------------------------------------------------------------------
# Validação da planta
# ---------------------------------------------------------------------------

def validate() -> None:
    errors: list[str] = []

    # 1. sobreposição de ambientes
    for a in SPACES:
        for b in SPACES:
            if a is b:
                continue
            if a.i0 < b.i1 and b.i0 < a.i1 and a.j0 < b.j1 and b.j0 < a.j1:
                errors.append(f"sobreposição: {a.name} × {b.name}")

    # 2. dimensões pares e alturas válidas
    for s in SPACES:
        if (s.i1 - s.i0) % 1 or (s.j1 - s.j0) % 1:
            errors.append(f"{s.name}: células fracionárias")
        if s.width < 3.0 or s.depth < 3.0:
            errors.append(f"{s.name}: pequeno demais ({s.width:.1f} × {s.depth:.1f})")
        if s.height not in (6.0, 12.0):
            errors.append(f"{s.name}: altura {s.height} fora do padrão")

    # 3. vazios fechados: células não ocupadas cercadas por ambientes
    cell_map: dict[tuple[int, int], str] = {}
    for s in SPACES:
        for i in range(s.i0, s.i1):
            for j in range(s.j0, s.j1):
                cell_map[(i, j)] = s.name
    xs = [c[0] for c in cell_map]
    zs = [c[1] for c in cell_map]
    reach: set[tuple[int, int]] = set()
    stack = [(min(xs) - 1, min(zs) - 1)]
    seen = set(stack)
    while stack:
        i, j = stack.pop()
        reach.add((i, j))
        for di, dj in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            n = (i + di, j + dj)
            if n in seen or n in cell_map:
                continue
            if min(xs) - 1 <= n[0] <= max(xs) + 1 and min(zs) - 1 <= n[1] <= max(zs) + 1:
                seen.add(n)
                stack.append(n)
    for i in range(min(xs), max(xs) + 1):
        for j in range(min(zs), max(zs) + 1):
            if (i, j) not in cell_map and (i, j) not in reach:
                errors.append(f"vazio fechado na célula ({i}, {j})")

    # 4. toda porta/abertura precisa cair numa parede entre dois ambientes
    for o in OPENINGS:
        if o.kind in ("door", "opening") and o.span != 2:
            errors.append(f"porta/abertura com {o.span} células (precisa 2)")
        if o.kind == "mouth" and o.span not in (3, 4):
            errors.append(f"boca de corredor com {o.span} células (precisa 3 ou 4)")
        for k in range(o.start, o.start + o.span):
            i, j = (o.cell, k) if o.axis == "x" else (k, o.cell)
            before = cell_map.get((i - 1, j)) if o.axis == "x" else cell_map.get((i, j - 1))
            after = cell_map.get((i, j)) if o.axis == "x" else cell_map.get((i, j))
            if o.axis == "z":
                before = cell_map.get((i, j - 1))
                after = cell_map.get((i, j))
            if before is None or after is None:
                errors.append(
                    f"{o.kind} em {o.axis}={line(o.cell):.0f} célula {k}: "
                    f"não separa dois ambientes ({before} | {after})"
                )
    # 5. partições dentro de um ambiente e sem tocar paredes externas
    for p in PARTITIONS:
        for k in range(p.start, p.end):
            i, j = (p.cell, k) if p.axis == "x" else (k, p.cell)
            owner = cell_map.get((i, j))
            if owner is None:
                errors.append(f"partição em {p.axis}={line(p.cell):.0f} fora de ambiente")
                break
            if p.axis == "x" and cell_map.get((i - 1, j)) != owner:
                errors.append(f"partição {p.axis}{p.cell} toca a borda de {owner} na célula {k}")
                break
            if p.axis == "z" and cell_map.get((i, j - 1)) != owner:
                errors.append(f"partição {p.axis}{p.cell} toca a borda de {owner} na célula {k}")
                break

    # 5b. paredes: comprimento par e trechos com vãos também pares
    bands = wall_bands()
    for band in bands:
        axis, cell, start, end, height = band
        if (end - start) < 1:
            errors.append(f"faixa {axis}={line(cell):.0f}: comprimento inválido")
        for seg in band_pieces(band, OPENINGS):
            if seg[1] <= seg[0]:
                errors.append(f"faixa {axis}={line(cell):.0f}: trecho vazio")
    used = {(o.axis, o.cell, o.start, o.span) for b in bands for o in openings_on_band(b, OPENINGS)}
    for o in OPENINGS:
        if (o.axis, o.cell, o.start, o.span) not in used:
            errors.append(
                f"vão {o.kind} em {o.axis}={line(o.cell):.0f} células {o.start}.."
                f"{o.start + o.span} não está contido numa faixa de parede")
        pairs = set()
        for k in range(o.start, o.start + o.span):
            i, j = (o.cell, k) if o.axis == "x" else (k, o.cell)
            before = cell_map.get((i - 1, j)) if o.axis == "x" else cell_map.get((i, j - 1))
            after = cell_map.get((i, j)) if o.axis == "x" else cell_map.get((i, j))
            pairs.add((before, after))
        if len(pairs) != 1:
            errors.append(f"vão {o.kind} em {o.axis}={line(o.cell):.0f}: liga mais de um par de ambientes")

    # 5c. pilares: dentro do ambiente, folgados das paredes e longe dos vãos
    for x, z, levels, space in PILLARS:
        room = next((r for r in SPACES if r.name == space), None)
        if room is None:
            errors.append(f"pilar {x},{z}: ambiente {space} inexistente")
            continue
        margin = 1.0
        if not (room.x0 + margin <= x <= room.x1 - margin
                and room.z0 + margin <= z <= room.z1 - margin):
            errors.append(f"pilar {x},{z}: fora de {space}")
        for o in OPENINGS:
            half = CELL * o.span / 2.0
            center = line(o.start) + half - CELL / 2.0
            c = line(o.cell)
            ox, oz = (c, center) if o.axis == "x" else (center, c)
            if abs(x - ox) < 1.6 and abs(z - oz) < half + 1.2:
                errors.append(f"pilar {x},{z}: bloqueia o vão em {o.axis}={c:.0f}")
        if levels not in (1, 2):
            errors.append(f"pilar {x},{z}: {levels} níveis")

    # 5d. escadas: poço dentro do ambiente e sem sobrepor parede/vão
    for st in STAIRS:
        room = next((r for r in SPACES if r.name == st.space), None)
        if room is None:
            errors.append(f"escada {st.name}: ambiente {st.space} inexistente")
            continue
        if not (room.x0 + 0.5 <= st.x0 and st.x0 + 2.0 <= room.x1 - 0.5
                and room.z0 + 0.5 <= st.z0 and st.z1 <= room.z1 - 0.5):
            errors.append(f"escada {st.name}: poço fora de {st.space}")
        if abs((st.z0 + 6.0) - st.hole_end) > 1e-6:
            errors.append(f"escada {st.name}: vão do piso desalinhado")
        if abs((st.z1 - st.z0) - 10.0) > 1e-6:
            errors.append(f"escada {st.name}: poço de {st.z1 - st.z0} m (esperado 10)")
        for value, label in ((st.x0, "x"), (st.z0, "z0"), (st.z1, "z1")):
            if (value - 1.0) % 2.0 != 0.0:
                errors.append(f"escada {st.name}: {label} = {value} fora da linha da grade")
        if room.height < 12.0:
            errors.append(f"escada {st.name}: casa da escada com {room.height} m")

    # 5e. vigas atravessam o corredor principal (vão livre de 5,6 m)
    for x in BEAMS:
        corridor = next((r for r in SPACES
                         if r.name.startswith("MainCorridor")
                         and r.x0 <= x <= r.x1), None)
        if corridor is None:
            errors.append(f"viga em x={x}: fora do corredor principal")
        elif abs((corridor.z1 - corridor.z0) - 5.6) > 0.01:
            errors.append(f"viga em x={x}: vão de {corridor.z1 - corridor.z0} m")

    # 6. conectividade a pé (grade de 0,5 m)
    walkable = []
    for s in SPACES:
        walkable.append((s.x0, s.x1, s.z0, s.z1))
    for o in OPENINGS:
        half = CELL * o.span / 2.0
        center = line(o.start) + half - CELL / 2.0
        lo, hi = center - half, center + half
        c = line(o.cell)
        if o.axis == "x":
            walkable.append((c - HALF_WALL - 0.01, c + HALF_WALL + 0.01, lo, hi))
        else:
            walkable.append((lo, hi, c - HALF_WALL - 0.01, c + HALF_WALL + 0.01))

    def inside(x: float, z: float) -> bool:
        for x0, x1, z0, z1 in walkable:
            if x0 - 1e-6 <= x <= x1 + 1e-6 and z0 - 1e-6 <= z <= z1 + 1e-6:
                return True
        return False

    step = 0.5
    minx = min(w[0] for w in walkable) - 1
    maxx = max(w[1] for w in walkable) + 1
    minz = min(w[2] for w in walkable) - 1
    maxz = max(w[3] for w in walkable) + 1
    start = (round(SPAWN[0] / step), round(SPAWN[2] / step))
    seen_pts = {start}
    stack = [start]
    while stack:
        i, j = stack.pop()
        for di, dj in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            n = (i + di, j + dj)
            if n in seen_pts:
                continue
            x, z = n[0] * step, n[1] * step
            if x < minx or x > maxx or z < minz or z > maxz:
                continue
            if not inside(x, z):
                continue
            seen_pts.add(n)
            stack.append(n)
    for s in SPACES:
        cx, cz = s.center
        if (round(cx / step), round(cz / step)) not in seen_pts:
            errors.append(f"{s.name}: inalcançável a pé a partir da entrada")

    if errors:
        print("PLANTA INVÁLIDA:")
        for e in errors:
            print("  -", e)
        raise SystemExit(1)
    print(f"planta válida: {len(SPACES)} ambientes, {len(OPENINGS)} vãos, "
          f"{len(PARTITIONS)} divisórias, {len(STAIRS)} escadas")


# ---------------------------------------------------------------------------
# Paredes
# ---------------------------------------------------------------------------

def wall_bands() -> list[tuple[str, int, int, int, float]]:
    """Faixas de parede (axis, linha, início, fim, altura) após união."""
    raw: dict[tuple[str, int], list[tuple[int, int, float]]] = {}
    for s in SPACES:
        raw.setdefault(("x", s.i0), []).append((s.j0, s.j1, s.height))
        raw.setdefault(("x", s.i1), []).append((s.j0, s.j1, s.height))
        raw.setdefault(("z", s.j0), []).append((s.i0, s.i1, s.height))
        raw.setdefault(("z", s.j1), []).append((s.i0, s.i1, s.height))

    bands: list[tuple[str, int, int, int, float]] = []
    for (axis, cell), spans in raw.items():
        cuts = sorted({p for s in spans for p in (s[0], s[1])})
        pieces: list[tuple[int, int, float]] = []
        for a, b in zip(cuts, cuts[1:]):
            h = 0.0
            for s0, s1, height in spans:
                if s0 <= a and b <= s1:
                    h = max(h, height)
            if h <= 0.0:
                continue
            if pieces and pieces[-1][1] == a and pieces[-1][2] == h:
                pieces[-1] = (pieces[-1][0], b, h)
            else:
                pieces.append((a, b, h))
        for a, b, h in pieces:
            bands.append((axis, cell, a, b, h))
    return bands


def band_length(band) -> float:
    return (band[3] - band[2]) * CELL


def openings_on_band(band, openings) -> list[Opening]:
    axis, cell = band[0], band[1]
    return [o for o in openings if o.axis == axis and o.cell == cell
            and band[2] <= o.start and o.start + o.span <= band[3]]


def band_pieces(band, openings) -> list[tuple[int, int]]:
    """Trechos da faixa sem vãos, em células."""
    axis, cell, start, end, height = band
    holes = sorted((o.start, o.start + o.span) for o in openings_on_band(band, openings))
    segments = []
    cursor = start
    for a, b in holes:
        if a > cursor:
            segments.append((cursor, a))
        cursor = max(cursor, b)
    if cursor < end:
        segments.append((cursor, end))
    # uma porta pode cobrir a faixa inteira: o trecho resultante pode ser vazio
    return segments


# ---------------------------------------------------------------------------
# Geração do .tscn
# ---------------------------------------------------------------------------

EXT = [
    ("PackedScene", "res://maps/modular/floors/floor_tile.tscn", "1_floor"),
    ("PackedScene", "res://maps/modular/floors/threshold_2m.tscn", "2_threshold"),
    ("PackedScene", "res://maps/modular/ceilings/ceiling_tile.tscn", "3_ceil"),
    ("PackedScene", "res://maps/modular/ceilings/ceiling_light.tscn", "4_light"),
    ("PackedScene", "res://maps/modular/walls/wall_panel_2m.tscn", "5_wall"),
    ("PackedScene", "res://maps/modular/walls/wall_door_4m.tscn", "6_door"),
    ("PackedScene", "res://maps/modular/walls/wall_opening_4m.tscn", "7_opening"),
    ("PackedScene", "res://maps/modular/walls/wall_corner_outer.tscn", "8_corner"),
    ("PackedScene", "res://maps/modular/structure/pillar.tscn", "9_pillar"),
    ("PackedScene", "res://maps/modular/structure/beam_6m.tscn", "10_beam"),
    ("PackedScene", "res://maps/modular/structure/railing_2m.tscn", "11_rail"),
    ("PackedScene", "res://maps/modular/stairs/stairs_straight.tscn", "12_stair"),
    ("StandardMaterial3D", "res://maps/modular/materials/wall_material.tres", "m_wall"),
    ("StandardMaterial3D", "res://maps/modular/materials/floor_material.tres", "m_floor"),
    ("StandardMaterial3D", "res://maps/modular/materials/trim_material.tres", "m_trim"),
]


def fmt(value: float) -> str:
    if abs(value) < 1e-9:
        return "0"
    text = f"{value:.4f}".rstrip("0").rstrip(".")
    return text


def enc(v: float) -> str:
    """Codifica um número para nome de nó: -12,5 -> m12p5 (sem '-' nem '.')."""
    text = f"{v:.1f}"
    return text.replace("-", "m").replace(".", "p")


def node_name(prefix: str, axis: str, cell: int, along: float, upper: int = 0) -> str:

    return f"{prefix}_{axis}{enc(cell)}_{enc(along)}{'_U' if upper else ''}"


def transform(x: float, y: float, z: float, yaw_quarter: int = 0) -> str:
    """Transform3D a partir de posição e rotação em quartos de volta (Y)."""
    bases = {
        0: (1, 0, 0, 0, 1, 0, 0, 0, 1),
        1: (0, 0, 1, 0, 1, 0, -1, 0, 0),   # +X → +Z
        2: (-1, 0, 0, 0, 1, 0, 0, 0, -1),
        3: (0, 0, -1, 0, 1, 0, 1, 0, 0),   # +X → -Z
    }[yaw_quarter % 4]
    return "Transform3D(%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)" % (
        *(fmt(b) for b in bases), fmt(x), fmt(y), fmt(z)
    )


class Scene:
    def __init__(self) -> None:
        self.nodes: list[str] = []
        self.counts: dict[str, int] = {}
        self.records: list[dict] = []

    def group(self, name: str, parent: str = ".") -> None:
        self.nodes.append(f'[node name="{name}" type="Node3D" parent="{parent}"]\n')

    def marker(self, name: str, parent: str, x: float, y: float, z: float,
               yaw: int = 0) -> None:
        self.nodes.append(
            f'[node name="{name}" type="Marker3D" parent="{parent}"]\n'
            f"transform = {transform(x, y, z, yaw)}\n"
        )
        self.count("marker")

    def instance(self, name: str, parent: str, res: str, x: float, y: float, z: float,
                 yaw: int = 0, kind: str = "") -> None:
        self.nodes.append(
            f'[node name="{name}" parent="{parent}" instance=ExtResource("{res}")]\n'
            f"transform = {transform(x, y, z, yaw)}\n"
        )
        self.records.append({"name": name, "res": res, "kind": kind, "x": x,
                             "y": y, "z": z, "yaw": yaw})
        self.count(kind or res)

    def light(self, name: str, parent: str, x: float, y: float, z: float) -> None:
        self.nodes.append(
            f'[node name="{name}" type="OmniLight3D" parent="{parent}"]\n'
            f"transform = {transform(x, y, z)}\n"
            "light_color = Color(0.86, 0.9, 1, 1)\n"
            "light_energy = 1.15\n"
            "shadow_enabled = false\n"
            "omni_range = 16.0\n"
            "omni_attenuation = 1.2\n"
        )
        self.count("light")

    def count(self, key: str, amount: int = 1) -> None:
        self.counts[key] = self.counts.get(key, 0) + amount


def build() -> Scene:
    scene = Scene()
    bands = wall_bands()

    # --- grupos ---------------------------------------------------------
    scene.nodes.append('[node name="LaboratoryFirstFloor" type="Node3D"]\n')
    scene.group("STRUCTURE")
    for name in ("Floors", "Ceilings", "Walls", "Doors", "Structural"):
        scene.group(name, "STRUCTURE")
    scene.group("CORRIDORS")
    scene.group("ROOMS")
    scene.group("STAIRS")
    scene.group("LIGHTING")
    scene.nodes.append(
        '[node name="WorldEnvironment" type="WorldEnvironment" parent="."]\n'
        'environment = SubResource("Env_first_floor")\n'
    )
    scene.nodes.append(
        '[node name="FillLight" type="DirectionalLight3D" parent="LIGHTING"]\n'
        'transform = Transform3D(0.866025, -0.353553, 0.353553, 0, 0.707107, 0.707107, '
        '-0.5, -0.612372, 0.612372, 0, 40, 0)\n'
        "light_color = Color(0.62, 0.7, 0.85, 1)\n"
        "light_energy = 0.18\n"
        "shadow_enabled = false\n"
    )
    scene.marker("Spawn", ".", *SPAWN, yaw=SPAWN_QUARTER)

    for s in SPACES:
        parent = "CORRIDORS" if s.kind in ("corridor", "hall") else "ROOMS"
        scene.group(s.name, parent)
        cx, cz = s.center
        scene.marker("Center", f"{parent}/{s.name}", cx, 0.05, cz)

    # --- pisos, tetos e luzes ------------------------------------------
    # Uma placa por CÉLULA (alinhada às linhas da grade): duas salas vizinhas
    # nunca geram placas sobrepostas no vão da parede, que causariam
    # z-fighting exatamente embaixo das portas e bocas de corredor.
    holes = [(st.x0, st.x0 + 2.0, st.z0, st.z0 + 6.0) for st in STAIRS]
    cells_by_space: dict[str, list[tuple[float, float]]] = {r.name: [] for r in SPACES}
    for s in SPACES:
        for i in range(s.i0, s.i1):
            for j in range(s.j0, s.j1):
                cells_by_space[s.name].append((line(i) + 1.0, line(j) + 1.0))
    for s in SPACES:
        cy = s.height - STOREY
        cells = [c for c in cells_by_space[s.name]
                 if not any(hx0 <= c[0] < hx1 and hz0 <= c[1] < hz1
                            for hx0, hx1, hz0, hz1 in holes)]
        # luminárias embutidas: corredores a cada 3 placas, salas a cada 4
        step = 3 if s.kind != "room" else 4
        light_slots = [n for n in range(len(cells)) if n % step == 0]
        area = s.width * s.depth
        wanted = max(1, min(8, int(round(area / 220.0))))
        if len(light_slots) > wanted:
            pick = {round(i * (len(light_slots) - 1) / max(1, wanted - 1))
                    for i in range(wanted)}
        else:
            pick = set(range(len(light_slots)))
        for n, (x, z) in enumerate(cells):
            light = n in light_slots
            scene.instance(f"Floor_{s.name}_{n:03d}", "STRUCTURE/Floors",
                           "1_floor", x, 0.0, z, kind="floor_tile")
            scene.instance(
                f"Ceil_{s.name}_{n:03d}", "STRUCTURE/Ceilings",
                "4_light" if light else "3_ceil", x, cy, z,
                kind="ceiling_light" if light else "ceiling_tile",
            )
        for rank, slot in enumerate(sorted(pick)):
            x, z = cells[light_slots[slot]]
            height = 11.2 if s.height > STOREY else 5.2
            scene.light(f"Light_{s.name}_{rank:02d}", "LIGHTING", x, height, z)

    # --- escadas (poço, patamar inferior e guarda-corpos) ---------------
    for st in STAIRS:
        parent = f"STAIRS/{st.name}"
        scene.group(st.name, "STAIRS")
        # módulo: topo em y = 0 no bordo norte do vão, descendo para +Z até -3,2
        scene.instance("StairModule", parent, "12_stair",
                       st.x_center, -3.2, st.z0 + 5.6, kind="stair")
        # piso do hall inferior (-3,2): cobre o poço inteiro, uma placa por célula
        for k in range(5):
            scene.instance(f"LandingFloor_{k}", parent, "1_floor",
                           st.x_center, -3.2, st.z0 + 1.0 + 2.0 * k, kind="floor_tile")
        # paredes do hall inferior: do fundo até -0,3 (sob a laje do andar)
        for k in range(5):
            z = st.z0 + 1.0 + 2.0 * k
            scene.instance(f"ShaftWallW_{k}", parent, "5_wall",
                           st.x0 - 0.2, -6.15, z, yaw=1, kind="wall_panel")
            scene.instance(f"ShaftWallE_{k}", parent, "5_wall",
                           st.x0 + 2.2, -6.15, z, yaw=1, kind="wall_panel")
        # (as paredes ficam 0,2 m fora do poço: o vão livre é 23,0..25,0)
        scene.instance("ShaftWallN", parent, "5_wall",
                       st.x_center, -6.15, st.z0 - 0.2, kind="wall_panel")
        scene.instance("ShaftWallS", parent, "5_wall",
                       st.x_center, -6.15, st.z1 + 0.2, kind="wall_panel")
        # guarda-corpos na borda do vão (o norte é a entrada da escada)
        for k in range(3):
            z = st.z0 + 1.0 + 2.0 * k
            scene.instance(f"RailW_{k}", parent, "11_rail", st.x0, 0.0, z, yaw=1, kind="rail")
            scene.instance(f"RailE_{k}", parent, "11_rail", st.x0 + 2.0, 0.0, z, yaw=1, kind="rail")
        scene.instance("RailS", parent, "11_rail", st.x_center, 0.0, st.z0 + 6.0, kind="rail")

    # --- paredes --------------------------------------------------------
    for band in bands:
        axis, cell, start, end, height = band
        layers = int(round(height / STOREY))
        holes_on = openings_on_band(band, OPENINGS)
        for layer in range(layers):
            # na altura da porta/abertura o vão existe; acima dela a parede é cheia
            holes = OPENINGS if layer == 0 else []
            for seg_start, seg_end in band_pieces(band, holes):
                for k in range(seg_start, seg_end):
                    center = line(k) + 1.0
                    y = layer * STOREY
                    # eixo 'x': plano x = line(cell), painel ao longo de Z (yaw 90°)
                    # eixo 'z': plano z = line(cell), painel ao longo de X (yaw 0)
                    pos = (center, y, line(cell)) if axis == "z" else (line(cell), y, center)
                    scene.instance(
                        node_name("Wall", axis.upper(), cell, center, layer),
                        "STRUCTURE/Walls", "5_wall", *pos,
                        yaw=0 if axis == "z" else 1, kind="wall_panel",
                    )
        for o in holes_on:
            if o.kind == "mouth":
                # boca de corredor: vão livre, sem módulo (é o alargamento);
                # só a soleira fecha a banda de 0,4 m entre os dois pisos
                for step in range(o.span):
                    center = line(o.start + step) + 1.0
                    pos = ((center, 0.0, line(cell)) if axis == "z"
                           else (line(cell), 0.0, center))
                    scene.instance(node_name("Sill", axis.upper(), cell, center),
                                   "STRUCTURE/Floors", "2_threshold", *pos,
                                   yaw=0 if axis == "z" else 1, kind="threshold")
                continue
            center = line(o.start) + o.span
            pos = (center, 0.0, line(cell)) if axis == "z" else (line(cell), 0.0, center)
            res = "6_door" if o.kind == "door" else "7_opening"
            prefix = "Door" if o.kind == "door" else "Opening"
            scene.instance(node_name(prefix, axis.upper(), cell, center),
                           "STRUCTURE/Doors", res, *pos,
                           yaw=0 if axis == "z" else 1, kind=o.kind)

    # --- divisórias internas -------------------------------------------
    for p in PARTITIONS:
        openings = [Opening(kind, p.axis, p.cell, start, span)
                    for start, span, kind in p.openings]
        band = (p.axis, p.cell, p.start, p.end, STOREY)
        for seg_start, seg_end in band_pieces(band, openings):
            for k in range(seg_start, seg_end):
                center = line(k) + 1.0
                pos = ((center, 0.0, line(p.cell)) if p.axis == "z"
                       else (line(p.cell), 0.0, center))
                scene.instance(node_name("Part", p.axis.upper(), p.cell, center),
                               "STRUCTURE/Walls", "5_wall", *pos,
                               yaw=0 if p.axis == "z" else 1, kind="wall_panel")
        for start, span, kind in p.openings:
            center = line(start) + span
            pos = ((center, 0.0, line(p.cell)) if p.axis == "z"
                   else (line(p.cell), 0.0, center))
            scene.instance(node_name("PartDoor", p.axis.upper(), p.cell, center),
                           "STRUCTURE/Doors", "6_door", *pos,
                           yaw=0 if p.axis == "z" else 1, kind="door")

    # --- pilares, vigas e guarda-corpos --------------------------------
    for n, (x, z, levels, space) in enumerate(PILLARS):
        for level in range(levels):
            scene.instance(f"Pillar_{space}_{n}_{level}", "STRUCTURE/Structural",
                           "9_pillar", x, level * STOREY, z, kind="pillar")
    for n, x in enumerate(BEAMS):
        scene.instance(f"Beam_{n:02d}", "STRUCTURE/Structural", "10_beam",
                       x, 0.0, 0.0, yaw=1, kind="beam")

    return scene


## Checagens sobre o que foi realmente instanciado (não sobre a intenção).
def self_check(scene: Scene) -> None:
    errors: list[str] = []
    seen: dict[tuple[str, float, float, float], str] = {}
    for r in scene.records:
        key = (r["res"], round(r["x"], 3), round(r["y"], 3), round(r["z"], 3))
        if key in seen:
            errors.append(f"instância duplicada: {r['name']} e {seen[key]} em {key}")
        seen[key] = r["name"]

    # painéis de parede: mesma faixa e mesmo nível não podem se sobrepor
    bands: dict[tuple[str, float, float], list[tuple[float, float, str]]] = {}
    for r in scene.records:
        if r["kind"] not in ("wall_panel", "door", "opening"):
            continue
        if r["kind"] == "wall_panel":
            along = r["z"] if r["yaw"] % 2 == 1 else r["x"]
            across = r["x"] if r["yaw"] % 2 == 1 else r["z"]
            half = 1.0
        elif r["kind"] == "door":
            along = r["z"] if r["yaw"] % 2 == 1 else r["x"]
            across = r["x"] if r["yaw"] % 2 == 1 else r["z"]
            half = 2.0
        else:
            along = r["z"] if r["yaw"] % 2 == 1 else r["x"]
            across = r["x"] if r["yaw"] % 2 == 1 else r["z"]
            half = 2.0
        key = ("z" if r["yaw"] % 2 == 1 else "x", round(across, 2), round(r["y"], 2))
        bands.setdefault(key, []).append((along - half, along + half, r["name"]))
    for key, spans in bands.items():
        spans.sort()
        for (a0, a1, an), (b0, b1, bn) in zip(spans, spans[1:]):
            if b0 < a1 - 1e-6:
                errors.append(f"paredes sobrepostas em {key}: {an} e {bn}")

    # paredes/door/abertura: o plano tem de cair numa linha da grade e o
    # painel estar centrado numa célula (2 m), senão a parede atravessa o vão.
    for r in scene.records:
        if r["kind"] not in ("wall_panel", "door", "opening"):
            continue
        if r["name"].startswith("Shaft"):
            # paredes do poço da escada: ficam 0,2 m fora da célula, de propósito
            continue
        runs_along_x = r["yaw"] % 2 == 0
        across = r["z"] if runs_along_x else r["x"]
        along = r["x"] if runs_along_x else r["z"]
        if (across - 1.0) % 2.0 != 0.0:
            errors.append(f"{r['name']}: plano fora da linha da grade ({across})")
        half = 1.0 if r["kind"] == "wall_panel" else 2.0
        if half == 1.0 and along % 2.0 != 0.0:
            errors.append(f"{r['name']}: painel fora do centro da célula ({along})")

    # piso e teto: uma placa por posição
    for kind in ("floor_tile", "ceiling_tile", "ceiling_light"):
        spots = [(r["x"], r["y"], r["z"]) for r in scene.records if r["kind"] == kind]
        if len(spots) != len(set(spots)):
            errors.append(f"{kind}: placas sobrepostas")

    if errors:
        print("CENA INVÁLIDA:")
        for e in errors[:40]:
            print("  -", e)
        raise SystemExit(1)
    print("cena consistente: sem instância duplicada nem parede sobreposta")


def write_scene(scene: Scene) -> None:
    ext_lines = [
        f'[ext_resource type="{kind}" path="{path}" id="{rid}"]'
        for kind, path, rid in EXT
    ]
    env = (
        '[sub_resource type="Environment" id="Env_first_floor"]\n'
        "background_mode = 1\n"
        "background_color = Color(0.015, 0.018, 0.024, 1)\n"
        "ambient_light_source = 2\n"
        "ambient_light_color = Color(0.34, 0.4, 0.52, 1)\n"
        "ambient_light_energy = 0.42\n"
        "fog_enabled = true\n"
        "fog_light_color = Color(0.06, 0.07, 0.09, 1)\n"
        "fog_density = 0.0035\n"
        "tonemap_mode = 2\n"
    )
    header = f"[gd_scene load_steps={len(EXT) + 2} format=3]\n"
    body = "\n".join(scene.nodes)
    SCENE_PATH.write_text(
        header + "\n" + "\n".join(ext_lines) + "\n\n" + env + "\n" + body,
        encoding="utf-8")


def write_plan() -> None:
    plan = {
        "grid_m": CELL,
        "spaces": [
            {
                "name": s.name,
                "label": s.label,
                "kind": s.kind,
                "interior": [round(s.x0, 2), round(s.x1, 2), round(s.z0, 2), round(s.z1, 2)],
                "size": [round(s.width, 2), round(s.height, 2), round(s.depth, 2)],
            }
            for s in SPACES
        ],
        "stairs": [{"name": st.name, "room": st.space, "x": st.x_center,
                    "z_top": st.z0, "z_bottom": st.z1} for st in STAIRS],
        "spawn": list(SPAWN),
    }
    PLAN_PATH.parent.mkdir(parents=True, exist_ok=True)
    PLAN_PATH.write_text(json.dumps(plan, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")


def main() -> int:
    validate()
    if "--check" in sys.argv:
        return 0
    scene = build()
    self_check(scene)
    write_scene(scene)
    write_plan()
    total = sum(scene.counts.values())
    print(f"cenário gravado: {SCENE_PATH.relative_to(ROOT)}")
    print(f"  nós instanciados: {total}")
    for key in sorted(scene.counts):
        print(f"  {key:>16}: {scene.counts[key]}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
