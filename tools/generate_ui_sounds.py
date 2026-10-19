#!/usr/bin/env python3
"""Gera os sons de interface do Black Sight (feedback curto de UI).

Arquivos gerados (originais, sintetizados proceduralmente):
    audio/assets/sfx/ui_click.wav    - clique seco ao acionar um botão
    audio/assets/sfx/ui_confirm.wav  - confirmação curta e mais grave

Requisitos: Python 3.10+ (apenas biblioteca padrão).

Uso:
    python tools/generate_ui_sounds.py
"""

from __future__ import annotations

import math
import random
import struct
import wave
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
OUT_DIR = ROOT / "audio" / "assets" / "sfx"

SAMPLE_RATE = 44100


def envelope(t: float, duration: float, attack: float, decay_power: float) -> float:
    """Ataque rápido + decaimento exponencial (evita clique no início)."""
    if t < attack:
        return t / attack
    progress = (t - attack) / max(duration - attack, 1e-6)
    return max(0.0, (1.0 - progress) ** decay_power)


def render(path: Path, duration: float, tones: list[tuple[float, float]],
           noise_level: float, decay_power: float, gain: float) -> None:
    total = int(SAMPLE_RATE * duration)
    rng = random.Random(7)
    samples: list[int] = []

    for index in range(total):
        t = index / SAMPLE_RATE
        env = envelope(t, duration, 0.002, decay_power)
        value = 0.0
        for frequency, weight in tones:
            value += math.sin(2.0 * math.pi * frequency * t) * weight
        value += rng.uniform(-1.0, 1.0) * noise_level
        # pequeno "clique" de transiente nos primeiros milissegundos
        if t < 0.004:
            value += rng.uniform(-0.5, 0.5)
        samples.append(int(max(-1.0, min(1.0, value * env * gain)) * 32767))

    with wave.open(str(path), "wb") as handle:
        handle.setnchannels(1)
        handle.setsampwidth(2)
        handle.setframerate(SAMPLE_RATE)
        handle.writeframes(b"".join(struct.pack("<h", s) for s in samples))


def main() -> None:
    OUT_DIR.mkdir(parents=True, exist_ok=True)

    render(
        OUT_DIR / "ui_click.wav",
        duration=0.055,
        tones=[(1250.0, 0.55), (2100.0, 0.22)],
        noise_level=0.12,
        decay_power=3.2,
        gain=0.55,
    )
    print("  audio/assets/sfx/ui_click.wav")

    render(
        OUT_DIR / "ui_confirm.wav",
        duration=0.14,
        tones=[(520.0, 0.6), (780.0, 0.25), (1040.0, 0.12)],
        noise_level=0.03,
        decay_power=2.4,
        gain=0.55,
    )
    print("  audio/assets/sfx/ui_confirm.wav")


if __name__ == "__main__":
    print("Gerando sons de interface do Black Sight...")
    main()
    print("Concluído.")
