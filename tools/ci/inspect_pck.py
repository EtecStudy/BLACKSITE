#!/usr/bin/env python3
"""Inspeciona um pacote de dados (.pck) exportado pelo Godot 4.

Uso:
    python tools/ci/inspect_pck.py build/windows/BlackSight.pck

Valida o cabeçalho GDPC e lista os recursos `res://` embutidos. Usado pelo CI
para confirmar que o pacote que acompanha o executável contém a cena inicial,
os scripts e os assets esperados. Sai com código 1 se algo obrigatório faltar.
"""

from __future__ import annotations

import re
import struct
import sys
from pathlib import Path

# Cada item aceita mais de uma forma de exportação (texto ou binário).
REQUIRED: list[list[str]] = [
    ["res://project.binary"],
    ["res://scenes/boot/title_screen.scn", "res://scenes/boot/title_screen.tscn"],
    ["res://scripts/ui/title_screen.gdc", "res://scripts/ui/title_screen.gd"],
    ["res://scripts/autoload/app_info.gdc", "res://scripts/autoload/app_info.gd"],
    ["res://assets/themes/black_sight.res", "res://assets/themes/black_sight.tres"],
    ["res://assets/fonts/cinzel/Cinzel-Regular.ttf"],
    ["res://assets/fonts/cinzel/Cinzel-SemiBold.ttf"],
]

FORBIDDEN_PREFIXES = [
    "res://tools/",
    "res://docs/",
]


def parse_directory(data: bytes) -> list[str]:
    """Lê a tabela de arquivos do pacote (formato Godot 4)."""
    offset = 4
    (_pack_format,) = struct.unpack_from("<I", data, offset)
    offset += 4
    offset += 12  # versão da engine (major, minor, patch)
    offset += 4   # flags
    offset += 8   # file_base
    offset += 64  # 16 campos reservados (uint32)
    (file_count,) = struct.unpack_from("<I", data, offset)
    offset += 4

    if file_count <= 0 or file_count > 100_000:
        raise ValueError(f"quantidade de arquivos implausível: {file_count}")

    names: list[str] = []
    for _ in range(file_count):
        (path_length,) = struct.unpack_from("<I", data, offset)
        offset += 4
        if path_length <= 0 or path_length > 4096:
            raise ValueError(f"tamanho de caminho implausível: {path_length}")
        names.append(data[offset:offset + path_length].decode("utf-8"))
        offset += path_length
        offset += 8 + 8 + 16 + 4  # offset, size, md5, flags
    return names


def parse_fallback(data: bytes) -> list[str]:
    """Alternativa tolerante: extrai caminhos res:// via expressão regular."""
    pattern = rb"res://[A-Za-z0-9_./\-]+"
    suffixes = (".binary", ".scn", ".gdc", ".res", ".ttf", ".png", ".ctex",
                ".import", ".remap", ".cfg", ".bin", ".uid")
    found: set[str] = set()
    for match in re.finditer(pattern, data):
        text = match.group(0).decode("utf-8", "replace")
        for suffix in suffixes:
            index = text.find(suffix)
            if index != -1:
                text = text[:index + len(suffix)]
                break
        found.add(text)
    return sorted(found)


def main(argv: list[str]) -> int:
    if len(argv) < 2:
        print(__doc__)
        return 2

    path = Path(argv[1])
    if not path.is_file():
        print(f"ERRO: pacote não encontrado: {path}")
        return 1

    data = path.read_bytes()
    if data[:4] != b"GDPC":
        print(f"ERRO: {path} não é um pacote Godot (magic={data[:4]!r})")
        return 1

    pack_format, vmaj, vmin, vpatch = struct.unpack_from("<IIII", data, 4)
    print(f"{path} ({len(data) / (1024 * 1024):.1f} MB)")
    print(f"  formato de pacote: {pack_format}")
    print(f"  gerado pelo Godot: {vmaj}.{vmin}.{vpatch}")

    try:
        entries = parse_directory(data)
        origem = "tabela do pacote"
    except Exception as error:  # noqa: BLE001 - fallback intencional
        print(f"  aviso: não foi possível ler a tabela ({error}); usando busca textual")
        entries = parse_fallback(data)
        origem = "busca textual"

    entries = sorted(set(entries))
    print(f"  recursos embutidos: {len(entries)} ({origem})")
    for entry in entries:
        print(f"    {entry}")

    missing = [item[0] for item in REQUIRED if not any(cand in entries for cand in item)]
    forbidden = [entry for entry in entries
                 if any(entry.startswith(prefix) for prefix in FORBIDDEN_PREFIXES)]

    if missing:
        print("\nERRO: recursos obrigatórios ausentes:")
        for item in missing:
            print(f"  - {item}")
    if forbidden:
        print("\nERRO: recursos que não deveriam ser exportados:")
        for item in forbidden:
            print(f"  - {item}")

    if missing or forbidden:
        return 1

    print("\nPACOTE OK: cena inicial, scripts e assets presentes.")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
