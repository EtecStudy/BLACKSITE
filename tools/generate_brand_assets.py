#!/usr/bin/env python3
"""Gera os assets visuais de marca da Etapa 1 do Black Sight.

Todos os arquivos gerados sao placeholders originais (sem material de terceiros),
criados proceduralmente para a fundacao do projeto:

    assets/textures/ui/background.png   - fundo escuro com brilho radial e grao
    assets/textures/ui/vignette.png     - vinheta preta com alpha (overlay de UI)
    assets/textures/fx/dust.png         - sprite suave para as particulas de poeira
    assets/textures/branding/icon_1024.png
    assets/textures/branding/boot_splash.png
    assets/textures/branding/icon.ico   - icone do executavel Windows

Requisitos: Python 3.10+ e Pillow (pip install pillow).

Uso:
    python tools/generate_brand_assets.py
"""

from __future__ import annotations

import math
import random
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = Path(__file__).resolve().parent.parent
FONT_DIR = ROOT / "assets" / "fonts" / "cinzel"
FONT_SEMIBOLD = FONT_DIR / "Cinzel-SemiBold.ttf"
FONT_REGULAR = FONT_DIR / "Cinzel-Regular.ttf"

UI_DIR = ROOT / "assets" / "textures" / "ui"
FX_DIR = ROOT / "assets" / "textures" / "fx"
BRAND_DIR = ROOT / "assets" / "textures" / "branding"

SUPERSAMPLE = 2

BONE = (222, 215, 199)
DIM_BONE = (150, 145, 133)
BLOOD = (122, 27, 27)

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------


def new_rgba(width: int, height: int, color=(0, 0, 0, 255)) -> Image.Image:
    return Image.new("RGBA", (width, height), color)


def vertical_gradient(width: int, height: int, top: tuple, bottom: tuple) -> Image.Image:
    img = Image.new("RGB", (1, height))
    pixels = img.load()
    for y in range(height):
        t = y / max(1, height - 1)
        pixels[0, y] = tuple(round(top[i] + (bottom[i] - top[i]) * t) for i in range(3))
    return img.resize((width, height), Image.BICUBIC).convert("RGBA")


def radial_layer(width: int, height: int, cx: float, cy: float, radius: float,
                 color: tuple, power: float = 2.0, max_alpha: int = 255) -> Image.Image:
    """Camada de brilho radial suave, em coordenadas relativas (0..1)."""
    small_w, small_h = width // 4, height // 4
    layer = Image.new("RGBA", (small_w, small_h), (0, 0, 0, 0))
    pixels = layer.load()
    px_cx, px_cy = cx * small_w, cy * small_h
    px_r = radius * max(small_w, small_h)
    for y in range(small_h):
        for x in range(small_w):
            d = math.hypot(x - px_cx, y - px_cy) / px_r
            if d >= 1.0:
                continue
            falloff = (1.0 - d) ** power
            pixels[x, y] = (*color, round(max_alpha * falloff))
    return layer.resize((width, height), Image.BICUBIC)


def add_grain(img: Image.Image, sigma: float = 3.0, seed: int = 7) -> Image.Image:
    rng = random.Random(seed)
    w, h = img.size
    noise = Image.new("L", (w, h))
    noise.putdata([max(0, min(255, int(128 + rng.gauss(0, sigma * 12)))) for _ in range(w * h)])
    noise = noise.filter(ImageFilter.GaussianBlur(0.4))
    grain = Image.merge("RGBA", (noise, noise, noise, Image.new("L", (w, h), 255)))
    base = img.convert("RGBA")
    # "overlay" aproximado: mistura o ruido em baixa opacidade
    grain.putalpha(noise.point(lambda v: abs(v - 128)))
    return Image.blend(base, Image.composite(grain, base, grain.getchannel("A")), 0.10)


def tracked_text(draw: ImageDraw.ImageDraw, text: str, font: ImageFont.FreeTypeFont,
                 center_x: float, y: float, tracking: float, fill: tuple) -> None:
    """Desenha texto com espacamento extra entre as letras (tracking), centralizado."""
    widths = [draw.textlength(ch, font=font) for ch in text]
    total = sum(widths) + tracking * (len(text) - 1)
    x = center_x - total / 2
    for ch, w in zip(text, widths):
        draw.text((x, y), ch, font=font, fill=fill)
        x += w + tracking


# ---------------------------------------------------------------------------
# Assets
# ---------------------------------------------------------------------------


def make_background() -> None:
    width, height = 1920, 1080
    base = vertical_gradient(width, height, (7, 8, 10), (0, 0, 0))

    glow = radial_layer(width, height, 0.5, 0.40, 0.62, (28, 34, 36), power=2.4, max_alpha=235)
    base = Image.alpha_composite(base, glow)

    warm = radial_layer(width, height, 0.5, 0.36, 0.34, (34, 20, 18), power=2.0, max_alpha=90)
    base = Image.alpha_composite(base, warm)

    # leve queda de luz no rodape (profundidade)
    bottom = radial_layer(width, height, 0.5, 1.15, 1.0, (0, 0, 0), power=1.4, max_alpha=210)
    base = Image.alpha_composite(base, bottom)

    base = add_grain(base, sigma=2.0, seed=11)
    base.convert("RGB").save(UI_DIR / "background.png", optimize=True)
    print(f"  assets/textures/ui/background.png ({width}x{height})")


def make_vignette() -> None:
    width, height = 1920, 1080
    small_w, small_h = width // 4, height // 4
    layer = Image.new("RGBA", (small_w, small_h), (0, 0, 0, 0))
    pixels = layer.load()
    cx, cy = small_w / 2, small_h / 2
    max_r = math.hypot(cx, cy)
    for y in range(small_h):
        for x in range(small_w):
            d = math.hypot(x - cx, y - cy) / max_r
            t = max(0.0, min(1.0, (d - 0.30) / 0.70))
            t = t * t * (3 - 2 * t)  # smoothstep
            pixels[x, y] = (0, 0, 0, round(248 * t))
    layer = layer.resize((width, height), Image.BICUBIC)
    layer.save(UI_DIR / "vignette.png", optimize=True)
    print(f"  assets/textures/ui/vignette.png ({width}x{height})")


def make_dust() -> None:
    size = 64
    layer = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    pixels = layer.load()
    c = (size - 1) / 2
    for y in range(size):
        for x in range(size):
            d = math.hypot(x - c, y - c) / c
            if d >= 1.0:
                continue
            a = (1.0 - d) ** 2.6
            pixels[x, y] = (255, 250, 240, round(255 * a))
    layer = layer.filter(ImageFilter.GaussianBlur(0.6))
    layer.save(FX_DIR / "dust.png", optimize=True)
    print(f"  assets/textures/fx/dust.png ({size}x{size})")


def draw_eye_emblem(img: Image.Image, draw: ImageDraw.ImageDraw, cx: float, cy: float,
                    scale: float, line: int, glow: bool = True) -> None:
    """Olho estilizado: anel fino + pupila em fenda vertical."""
    radius = 300 * scale
    ring = 26 * scale

    if glow:
        halo = Image.new("RGBA", img.size, (0, 0, 0, 0))
        hd = ImageDraw.Draw(halo)
        hd.ellipse([cx - radius - 40 * scale, cy - radius - 40 * scale,
                    cx + radius + 40 * scale, cy + radius + 40 * scale],
                   outline=(*BLOOD, 70), width=int(ring * 1.8))
        halo = halo.filter(ImageFilter.GaussianBlur(28 * scale))
        img.alpha_composite(halo)
        draw = ImageDraw.Draw(img)

    # anel externo
    draw.ellipse([cx - radius, cy - radius, cx + radius, cy + radius],
                 outline=(*BONE, 255), width=int(ring))
    # anel interno fino de sangue
    inner = radius * 0.80
    draw.ellipse([cx - inner, cy - inner, cx + inner, cy + inner],
                 outline=(*BLOOD, 200), width=max(1, int(7 * scale)))
    # pupila em fenda
    slit_w = 74 * scale
    slit_h = 330 * scale
    draw.ellipse([cx - slit_w / 2, cy - slit_h / 2, cx + slit_w / 2, cy + slit_h / 2],
                 fill=(2, 2, 3, 255))
    # brilho discreto na iris
    draw.ellipse([cx + 26 * scale, cy - 96 * scale, cx + 62 * scale, cy - 60 * scale],
                 fill=(*BONE, 110))
    # marcas horizontais (cicatriz)
    for sign in (-1, 1):
        x0 = cx + sign * radius * 1.03
        x1 = cx + sign * radius * 1.22
        draw.line([(x0, cy), (x1, cy)], fill=(*DIM_BONE, 90), width=max(1, int(6 * scale)))


def make_emblem() -> None:
    """Emblema (olho) com fundo transparente, usado na tela inicial."""
    size = 1024
    big = size * SUPERSAMPLE
    img = new_rgba(big, big, (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    draw_eye_emblem(img, draw, big / 2, big / 2, scale=big / 1024.0 * 0.92,
                    line=26, glow=True)
    img = img.resize((size, size), Image.LANCZOS)
    img.save(BRAND_DIR / "emblem.png", optimize=True)
    print("  assets/textures/branding/emblem.png")


def make_icon() -> None:
    size = 1024
    big = size * SUPERSAMPLE
    img = new_rgba(big, big, (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    # tile arredondado
    pad = int(big * 0.02)
    draw.rounded_rectangle([pad, pad, big - pad, big - pad], radius=int(big * 0.20),
                           fill=(6, 7, 8, 255))
    glow = radial_layer(big, big, 0.5, 0.48, 0.55, (26, 20, 20), power=2.0, max_alpha=120)
    img = Image.alpha_composite(img, glow)
    draw = ImageDraw.Draw(img)

    draw_eye_emblem(img, draw, big / 2, big / 2, scale=big / 1024.0 * 1.15,
                    line=26, glow=True)

    # borda sutil
    draw.rounded_rectangle([pad, pad, big - pad, big - pad], radius=int(big * 0.20),
                           outline=(*DIM_BONE, 45), width=int(big * 0.006))

    img = img.resize((size, size), Image.LANCZOS)
    img.save(BRAND_DIR / "icon_1024.png", optimize=True)

    # .ico para o executavel Windows
    icon = img.copy()
    icon.save(BRAND_DIR / "icon.ico", sizes=[(256, 256), (128, 128), (64, 64),
                                             (48, 48), (32, 32), (16, 16)])
    print("  assets/textures/branding/icon_1024.png")
    print("  assets/textures/branding/icon.ico")


def make_boot_splash() -> None:
    width, height = 1920, 1080
    img = vertical_gradient(width, height, (8, 9, 11), (0, 0, 0))
    img = Image.alpha_composite(img, radial_layer(width, height, 0.5, 0.45, 0.55,
                                                  (24, 29, 31), power=2.2, max_alpha=210))
    draw = ImageDraw.Draw(img)

    draw_eye_emblem(img, draw, width / 2, height * 0.40, scale=0.62, line=16, glow=True)
    draw = ImageDraw.Draw(img)

    title_font = ImageFont.truetype(str(FONT_SEMIBOLD), 104)
    tracked_text(draw, "BLACK SIGHT", title_font, width / 2, height * 0.60, 34, (*BONE, 255))

    small_font = ImageFont.truetype(str(FONT_REGULAR), 26)
    tracked_text(draw, "ETAPA 1  ·  FUNDAÇÃO DO PROJETO", small_font,
                 width / 2, height * 0.74, 9, (*DIM_BONE, 210))

    img.convert("RGB").save(BRAND_DIR / "boot_splash.png", optimize=True)
    print("  assets/textures/branding/boot_splash.png")


def main() -> None:
    for directory in (UI_DIR, FX_DIR, BRAND_DIR):
        directory.mkdir(parents=True, exist_ok=True)
    print("Gerando assets de marca do Black Sight...")
    make_background()
    make_vignette()
    make_dust()
    make_emblem()
    make_icon()
    make_boot_splash()
    print("Concluido.")


if __name__ == "__main__":
    main()
