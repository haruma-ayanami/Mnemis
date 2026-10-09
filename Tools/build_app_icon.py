#!/usr/bin/env python3
"""Иконка приложения Mnemis: точечная сфера, как в дизайне (холст: App-Icon).

Использование:
    python3 Tools/build_app_icon.py <Assets.xcassets/AppIcon.appiconset> <icon.svg> [icon-light.svg]

Скрипт пишет три PNG для iOS: светлую (белый фон, обычный режим), тёмную и тонированную,
Contents.json для набора иконок и SVG-источники, которые использует холст дизайна.
Все варианты строятся из одного набора точек, поэтому совпадают между собой.
"""

import json
import math
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

CANVAS = 1024
SUPERSAMPLE = 2
DOT_COUNT = 1200
SPHERE_RADIUS = 330.0
CENTER = CANVAS / 2
TILT = 0.35                                   # поворот сферы вокруг вертикальной оси

BACKGROUND = (10, 10, 11)                     # #0A0A0B, фон приложения
PHOSPHOR = (76, 227, 138)                     # #4CE38A, акцент
DEEP = (20, 149, 74)                          # #14954A, теневая сторона
HIGHLIGHT = (233, 255, 233)                   # #E9FFE9, блик

# Светлая иконка: тёплый белый фон приложения и более тёмные зелёные, чтобы точки читались на белом.
LIGHT_BACKGROUND = (247, 247, 242)            # #F7F7F2
LIGHT_LIT = (31, 184, 96)                     # #1FB860, освещённая сторона
LIGHT_DEEP = (13, 94, 49)                     # #0D5E31, теневая сторона
LIGHT_CORE = (20, 149, 74)                    # #14954A, «выученное» слово

LIGHT = np.array([-0.45, 0.55, 0.70])
LIGHT = LIGHT / np.linalg.norm(LIGHT)
TARGET = np.array([-0.35, 0.45, 0.82])        # точка сферы, где горит одно «выученное» слово
TARGET = TARGET / np.linalg.norm(TARGET)



def sphere_points(count):
    """Равномерно распределённые точки на единичной сфере (спираль Фибоначчи)."""
    golden = math.pi * (3 - math.sqrt(5))
    points = []
    for i in range(count):
        y = 1 - 2 * i / (count - 1)
        r = math.sqrt(max(0.0, 1 - y * y))
        theta = golden * i
        points.append(np.array([math.cos(theta) * r, y, math.sin(theta) * r]))
    return points


def rotate_y(p, angle):
    c, s = math.cos(angle), math.sin(angle)
    x, y, z = p
    return np.array([c * x + s * z, y, -s * x + c * z])


def shade(normal, light=False):
    """Цвет и прозрачность точки: блик сверху слева, задняя сторона почти не видна.
    На светлом фоне блик не белеет, а остаётся ярко-зелёным, иначе он пропадёт на белом."""
    lambert = max(0.0, float(normal @ LIGHT))
    facing = (normal[2] + 1) / 2
    mix = lambert ** 1.4
    if light:
        color = np.array(LIGHT_DEEP) * (1 - mix) + np.array(LIGHT_LIT) * mix
    else:
        color = np.array(DEEP) * (1 - mix) + np.array(PHOSPHOR) * mix
        if lambert > 0.8:
            t = (lambert - 0.8) / 0.2
            color = color * (1 - t) + np.array(HIGHLIGHT) * t
    alpha = 0.16 + 0.84 * facing ** 0.7
    radius = 2.6 + 3.8 * facing
    return tuple(int(round(v)) for v in color), alpha, radius


def build_dots(light=False):
    """Точки уже в порядке от задних к передним и с координатами в пикселях холста."""
    dots = []
    for p in sphere_points(DOT_COUNT):
        normal = rotate_y(p, TILT)
        color, alpha, radius = shade(normal, light)
        dots.append({
            "depth": normal[2],
            "x": CENTER + SPHERE_RADIUS * normal[0],
            "y": CENTER - SPHERE_RADIUS * normal[1],
            "radius": radius,
            "color": color,
            "alpha": alpha,
            "normal": normal,
        })
    dots.sort(key=lambda d: d["depth"])
    highlight = max(range(len(dots)), key=lambda i: float(dots[i]["normal"] @ TARGET))
    return dots, highlight


def add_halo(image, strength_scale=0.26):
    """Мягкое свечение фосфора за сферой, как GlowHalo в приложении."""
    size = image.size[0]
    arr = np.asarray(image).astype(np.float32)
    yy, xx = np.mgrid[0:size, 0:size]
    distance = np.hypot(xx - size / 2, yy - size / 2) / (size / 2)
    strength = (np.clip(1 - distance, 0, 1) ** 2 * strength_scale)[..., None]
    arr[..., :3] = arr[..., :3] * (1 - strength) + np.array(PHOSPHOR, np.float32) * strength
    return Image.fromarray(arr.astype(np.uint8), "RGBA")


def render(dots, highlight, tinted, light=False):
    """Полноразмерный мастер 1024 px. Тонированный вариант — чёрный фон и белые точки, без цвета.
    Светлый вариант — белый фон приложения, лёгкое зелёное свечение и тёмно-зелёные точки."""
    size = CANVAS * SUPERSAMPLE
    scale = SUPERSAMPLE
    background = (0, 0, 0) if tinted else LIGHT_BACKGROUND if light else BACKGROUND
    image = Image.new("RGBA", (size, size), background + (255,))
    if not tinted:
        image = add_halo(image, 0.14 if light else 0.26)

    layer = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer)
    for dot in dots:
        r = dot["radius"] * scale
        cx, cy = dot["x"] * scale, dot["y"] * scale
        fill = (255, 255, 255) if tinted else dot["color"]
        draw.ellipse([cx - r, cy - r, cx + r, cy + r], fill=fill + (int(dot["alpha"] * 255),))
    image = Image.alpha_composite(image, layer)

    hx, hy = dots[highlight]["x"] * scale, dots[highlight]["y"] * scale
    glow = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    gr = 70 * scale
    glow_fill = (255, 255, 255, 170) if tinted else PHOSPHOR + (150,) if light else PHOSPHOR + (170,)
    ImageDraw.Draw(glow).ellipse([hx - gr, hy - gr, hx + gr, hy + gr], fill=glow_fill)
    glow = glow.filter(ImageFilter.GaussianBlur(28 * scale / 2))
    image = Image.alpha_composite(image, glow)

    core = 15 * scale
    core_fill = (255, 255, 255) if tinted else LIGHT_CORE if light else HIGHLIGHT
    ImageDraw.Draw(image).ellipse([hx - core, hy - core, hx + core, hy + core], fill=core_fill + (255,))
    return image.resize((CANVAS, CANVAS), Image.Resampling.LANCZOS).convert("RGB")


def svg_markup(dots, highlight, light=False):
    def hex_color(rgb):
        return "#{:02X}{:02X}{:02X}".format(*rgb)

    hx, hy = dots[highlight]["x"], dots[highlight]["y"]
    lines = [
        '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1024 1024">',
        "<defs>",
        '<radialGradient id="mnemis-halo" cx="512" cy="512" r="512" gradientUnits="userSpaceOnUse">',
        f'<stop offset="0" stop-color="{hex_color(PHOSPHOR)}" stop-opacity="{0.14 if light else 0.26}"/>',
        f'<stop offset="1" stop-color="{hex_color(PHOSPHOR)}" stop-opacity="0"/>',
        "</radialGradient>",
        '<radialGradient id="mnemis-glow" cx="0.5" cy="0.5" r="0.5">',
        f'<stop offset="0" stop-color="{hex_color(PHOSPHOR)}" stop-opacity="0.7"/>',
        f'<stop offset="1" stop-color="{hex_color(PHOSPHOR)}" stop-opacity="0"/>',
        "</radialGradient>",
        '<g id="mnemis-icon">',
        f'<rect width="1024" height="1024" fill="{hex_color(LIGHT_BACKGROUND if light else BACKGROUND)}"/>',
        '<circle cx="512" cy="512" r="512" fill="url(#mnemis-halo)"/>',
    ]
    for dot in dots:
        lines.append(
            f'<circle cx="{dot["x"]:.1f}" cy="{dot["y"]:.1f}" r="{dot["radius"]:.2f}" '
            f'fill="{hex_color(dot["color"])}" fill-opacity="{dot["alpha"]:.3f}"/>'
        )
    lines += [
        f'<circle cx="{hx:.1f}" cy="{hy:.1f}" r="110" fill="url(#mnemis-glow)"/>',
        f'<circle cx="{hx:.1f}" cy="{hy:.1f}" r="15" fill="{hex_color(LIGHT_CORE if light else HIGHLIGHT)}"/>',
        "</g>",
        "</defs>",
        '<use href="#mnemis-icon"/>',
        "</svg>",
    ]
    return "\n".join(lines) + "\n"


def write_contents(appicon):
    images = [
        {"idiom": "universal", "platform": "ios", "size": "1024x1024", "filename": "AppIcon-ios.png"},
        {"appearances": [{"appearance": "luminosity", "value": "dark"}], "idiom": "universal",
         "platform": "ios", "size": "1024x1024", "filename": "AppIcon-ios-dark.png"},
        {"appearances": [{"appearance": "luminosity", "value": "tinted"}], "idiom": "universal",
         "platform": "ios", "size": "1024x1024", "filename": "AppIcon-ios-tinted.png"},
    ]
    contents = {"images": images, "info": {"author": "xcode", "version": 1}}
    (appicon / "Contents.json").write_text(json.dumps(contents, indent=2) + "\n", encoding="utf-8")


def main(argv):
    if len(argv) not in (3, 4):
        print(__doc__.strip())
        return 1

    appicon = Path(argv[1])
    svg_path = Path(argv[2])
    appicon.mkdir(parents=True, exist_ok=True)

    dots, highlight = build_dots()
    light_dots, _ = build_dots(light=True)
    # Обычный (светлый) режим iOS — белая иконка, тёмный режим — чёрная, как экраны приложения.
    render(light_dots, highlight, tinted=False, light=True).save(appicon / "AppIcon-ios.png")
    render(dots, highlight, tinted=False).save(appicon / "AppIcon-ios-dark.png")
    render(dots, highlight, tinted=True).save(appicon / "AppIcon-ios-tinted.png")
    write_contents(appicon)

    svg_path.write_text(svg_markup(dots, highlight), encoding="utf-8")
    if len(argv) == 4:
        Path(argv[3]).write_text(svg_markup(light_dots, highlight, light=True), encoding="utf-8")
    print(f"icon written to {appicon} ({len(dots)} dots), svg to {svg_path}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
