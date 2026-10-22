#!/usr/bin/env python3
"""Give every Omarchy theme in the repo a background if it has none.

A theme without a backgrounds/ folder (or an empty one) gets two 3000x2000
images, which Omarchy's theme picker also uses as the preview:
  1-burst.png  rays fanning out from the bottom-left corner over black, in
               the theme's colours (accent, yellow, red, orange, magenta,
               cyan, blue, green from its colors.toml), with a sun glow
  2-black.png  plain black
Themes that already have backgrounds are left alone.

Usage:
    bin/theme-wallpapers.py            # every theme in config/omarchy/themes
    bin/theme-wallpapers.py starburst  # one theme
Needs ImageMagick (magick) to turn the drawing into a PNG.
"""

from __future__ import annotations

import math
import re
import subprocess
import sys
import tempfile
from pathlib import Path

WIDTH, HEIGHT = 3000, 2000
RAYS = 28
THEMES = Path(__file__).resolve().parent.parent / "config" / "omarchy" / "themes"
IMAGES = (".png", ".jpg", ".jpeg", ".webp", ".gif", ".bmp")


def theme_colors(colors_toml: Path) -> dict[str, str]:
    return dict(re.findall(r'^(\w+)\s*=\s*"(#[0-9a-fA-F]{6})"', colors_toml.read_text(), re.M))


def burst_svg(colors: dict[str, str]) -> str:
    keys = ("accent", "yellow", "red", "orange", "magenta", "cyan", "blue", "green")
    ray_colors = [colors[k] for k in keys if k in colors] or ["#ffffff"]
    accent = colors.get("accent", ray_colors[0])
    yellow = colors.get("yellow", accent)
    core = colors.get("bright_yellow", yellow)
    ox, oy = 0, HEIGHT
    reach = math.hypot(WIDTH, HEIGHT) * 1.05
    parts = [
        f'<svg xmlns="http://www.w3.org/2000/svg" width="{WIDTH}" height="{HEIGHT}" viewBox="0 0 {WIDTH} {HEIGHT}">',
        "<defs>",
        f'<radialGradient id="fade" cx="{ox}" cy="{oy}" r="{reach}" gradientUnits="userSpaceOnUse">'
        '<stop offset="0" stop-color="#fff" stop-opacity="1"/>'
        '<stop offset="0.55" stop-color="#fff" stop-opacity="0.35"/>'
        '<stop offset="1" stop-color="#fff" stop-opacity="0"/></radialGradient>',
        '<mask id="m"><rect width="100%" height="100%" fill="url(#fade)"/></mask>',
        f'<radialGradient id="sun" cx="{ox}" cy="{oy}" r="520" gradientUnits="userSpaceOnUse">'
        f'<stop offset="0" stop-color="{core}" stop-opacity="1"/>'
        f'<stop offset="0.35" stop-color="{yellow}" stop-opacity="0.95"/>'
        f'<stop offset="0.7" stop-color="{accent}" stop-opacity="0.6"/>'
        f'<stop offset="1" stop-color="{accent}" stop-opacity="0"/></radialGradient>',
        "</defs>",
        '<rect width="100%" height="100%" fill="#000"/>',
        '<g mask="url(#m)">',
    ]
    for i in range(RAYS):
        # Each ray is a thin wedge; the gaps between rays stay black.
        a0 = math.radians(90 * i / RAYS)
        a1 = math.radians(90 * (i + 0.55) / RAYS)
        x0, y0 = ox + reach * math.cos(a0), oy - reach * math.sin(a0)
        x1, y1 = ox + reach * math.cos(a1), oy - reach * math.sin(a1)
        color = ray_colors[i % len(ray_colors)]
        parts.append(f'<polygon points="{ox},{oy} {x0:.1f},{y0:.1f} {x1:.1f},{y1:.1f}" fill="{color}" fill-opacity="0.85"/>')
    parts += ["</g>", f'<circle cx="{ox}" cy="{oy}" r="520" fill="url(#sun)"/>', "</svg>"]
    return "\n".join(parts)


def has_backgrounds(theme: Path) -> bool:
    folder = theme / "backgrounds"
    return folder.is_dir() and any(p.suffix.lower() in IMAGES for p in folder.iterdir())


def make_backgrounds(theme: Path) -> None:
    folder = theme / "backgrounds"
    folder.mkdir(exist_ok=True)
    with tempfile.NamedTemporaryFile("w", suffix=".svg", delete=False) as svg:
        svg.write(burst_svg(theme_colors(theme / "colors.toml")))
    try:
        subprocess.run(["magick", "-background", "black", svg.name, "-resize", f"{WIDTH}x{HEIGHT}!",
                        str(folder / "1-burst.png")], check=True)
    finally:
        Path(svg.name).unlink(missing_ok=True)
    subprocess.run(["magick", "-size", f"{WIDTH}x{HEIGHT}", "xc:#000000", str(folder / "2-black.png")], check=True)
    print(f"{theme.name}: added backgrounds/1-burst.png and 2-black.png")


def main(names: list[str]) -> int:
    themes = [THEMES / n for n in names] if names else sorted(p for p in THEMES.iterdir() if p.is_dir())
    for theme in themes:
        if not (theme / "colors.toml").is_file():
            print(f"{theme.name}: no colors.toml, skipped", file=sys.stderr)
        elif has_backgrounds(theme):
            print(f"{theme.name}: has backgrounds, left alone")
        else:
            make_backgrounds(theme)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
