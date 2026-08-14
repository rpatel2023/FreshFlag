#!/usr/bin/env python3
"""Generate FreshFlag branding and every iOS AppIcon PNG using stdlib only.

Run from the repository root:

    python3 tool/generate_freshflag_icons.py

The design is deliberately simple at small sizes: a warm flag with a fresh sprout
on a deep-green field. PNGs are RGB/no-alpha to avoid App Store icon-alpha issues.
"""

from __future__ import annotations

import math
import struct
import zlib
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
IOS_ICON_DIR = ROOT / "ios" / "Runner" / "Assets.xcassets" / "AppIcon.appiconset"
MASTER_PATH = ROOT / "assets" / "images" / "logos" / "freshflag.png"

BACKGROUND = (24, 83, 61)
INNER = (31, 101, 75)
CREAM = (248, 246, 232)
MINT = (116, 202, 153)
STEM = (18, 65, 48)

# filename -> output pixels. These match the checked-in Xcode Contents.json.
IOS_ICONS = {
    "Icon-App-20x20@1x.png": 20,
    "Icon-App-20x20@2x.png": 40,
    "Icon-App-20x20@3x.png": 60,
    "Icon-App-29x29@1x.png": 29,
    "Icon-App-29x29@2x.png": 58,
    "Icon-App-29x29@3x.png": 87,
    "Icon-App-40x40@1x.png": 40,
    "Icon-App-40x40@2x.png": 80,
    "Icon-App-40x40@3x.png": 120,
    "Icon-App-50x50@1x.png": 50,
    "Icon-App-50x50@2x.png": 100,
    "Icon-App-57x57@1x.png": 57,
    "Icon-App-57x57@2x.png": 114,
    "Icon-App-60x60@2x.png": 120,
    "Icon-App-60x60@3x.png": 180,
    "Icon-App-72x72@1x.png": 72,
    "Icon-App-72x72@2x.png": 144,
    "Icon-App-76x76@1x.png": 76,
    "Icon-App-76x76@2x.png": 152,
    "Icon-App-83.5x83.5@2x.png": 167,
    "Icon-App-1024x1024@1x.png": 1024,
}


def _inside_ellipse(x: float, y: float, cx: float, cy: float, rx: float, ry: float) -> bool:
    return ((x - cx) / rx) ** 2 + ((y - cy) / ry) ** 2 <= 1.0


def _inside_rotated_ellipse(
    x: float,
    y: float,
    cx: float,
    cy: float,
    rx: float,
    ry: float,
    degrees: float,
) -> bool:
    radians = math.radians(degrees)
    cos_a = math.cos(radians)
    sin_a = math.sin(radians)
    dx = x - cx
    dy = y - cy
    xr = dx * cos_a + dy * sin_a
    yr = -dx * sin_a + dy * cos_a
    return (xr / rx) ** 2 + (yr / ry) ** 2 <= 1.0


def _inside_polygon(x: float, y: float, points: tuple[tuple[float, float], ...]) -> bool:
    inside = False
    j = len(points) - 1
    for i, (xi, yi) in enumerate(points):
        xj, yj = points[j]
        crosses = (yi > y) != (yj > y)
        if crosses:
            edge_x = (xj - xi) * (y - yi) / (yj - yi) + xi
            if x < edge_x:
                inside = not inside
        j = i
    return inside


def _distance_to_segment(
    px: float,
    py: float,
    ax: float,
    ay: float,
    bx: float,
    by: float,
) -> float:
    dx = bx - ax
    dy = by - ay
    if dx == 0 and dy == 0:
        return math.hypot(px - ax, py - ay)
    t = max(0.0, min(1.0, ((px - ax) * dx + (py - ay) * dy) / (dx * dx + dy * dy)))
    qx = ax + t * dx
    qy = ay + t * dy
    return math.hypot(px - qx, py - qy)


def _pixel(nx: float, ny: float) -> tuple[int, int, int]:
    # nx/ny are normalized to the 1024x1024 design coordinate space.
    color = BACKGROUND

    if _inside_ellipse(nx, ny, 512, 512, 352, 352):
        color = INNER

    # Pole (simple rectangle plus rounded-ish top/bottom markers).
    if 270 <= nx <= 330 and 210 <= ny <= 850:
        color = CREAM
    if _inside_ellipse(nx, ny, 300, 220, 30, 30):
        color = CREAM
    if _inside_ellipse(nx, ny, 300, 850, 55, 55):
        color = MINT

    # Flag fabric.
    flag = ((315, 225), (760, 285), (665, 480), (315, 435))
    if _inside_polygon(nx, ny, flag):
        color = CREAM

    # Sprout on the flag. Draw after fabric so it stays visible.
    if _inside_rotated_ellipse(nx, ny, 515, 318, 78, 40, -28):
        color = MINT
    if _inside_rotated_ellipse(nx, ny, 615, 325, 76, 39, 28):
        color = MINT
    if _distance_to_segment(nx, ny, 555, 382, 575, 326) <= 8:
        color = STEM

    return color


def render(size: int) -> bytes:
    rows = bytearray()
    scale = 1024.0 / size
    for y in range(size):
        rows.append(0)  # PNG filter type 0.
        ny = (y + 0.5) * scale
        for x in range(size):
            nx = (x + 0.5) * scale
            rows.extend(_pixel(nx, ny))
    return _png(size, size, bytes(rows))


def _chunk(kind: bytes, payload: bytes) -> bytes:
    return (
        struct.pack(">I", len(payload))
        + kind
        + payload
        + struct.pack(">I", zlib.crc32(kind + payload) & 0xFFFFFFFF)
    )


def _png(width: int, height: int, raw_rows: bytes) -> bytes:
    signature = b"\x89PNG\r\n\x1a\n"
    ihdr = struct.pack(">IIBBBBB", width, height, 8, 2, 0, 0, 0)  # RGB, no alpha.
    return signature + _chunk(b"IHDR", ihdr) + _chunk(b"IDAT", zlib.compress(raw_rows, 9)) + _chunk(b"IEND", b"")


def main() -> None:
    IOS_ICON_DIR.mkdir(parents=True, exist_ok=True)
    MASTER_PATH.parent.mkdir(parents=True, exist_ok=True)

    generated: dict[int, bytes] = {}
    for filename, size in IOS_ICONS.items():
        image = generated.setdefault(size, render(size))
        (IOS_ICON_DIR / filename).write_bytes(image)

    MASTER_PATH.write_bytes(generated.setdefault(1024, render(1024)))
    print(f"Generated {len(IOS_ICONS)} iOS icons and {MASTER_PATH.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
