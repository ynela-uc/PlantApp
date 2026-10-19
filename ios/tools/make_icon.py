#!/usr/bin/env python3
"""Draws the 1024x1024 app icon (white leaf on green) with no external libraries."""
import math
import struct
import sys
import zlib
from pathlib import Path

SIZE = 1024
OUT = Path(__file__).resolve().parents[1] / "PlantApp" / "Assets.xcassets" / "AppIcon.appiconset" / "icon-1024.png"

GREEN = (46, 125, 50)
WHITE = (255, 255, 255)


def in_leaf(x: float, y: float) -> bool:
    # Leaf = intersection of two circles (a lens), rotated 45 degrees, centered in the icon.
    cx, cy = SIZE / 2, SIZE / 2 - 20
    a = math.radians(-40)
    dx, dy = x - cx, y - cy
    u = dx * math.cos(a) - dy * math.sin(a)
    v = dx * math.sin(a) + dy * math.cos(a)
    r = 470.0   # circle radius
    d = 300.0   # circle center offset from the axis
    return (u * u + (v - d) ** 2 <= r * r) and (u * u + (v + d) ** 2 <= r * r)


def in_vein(x: float, y: float) -> bool:
    cx, cy = SIZE / 2, SIZE / 2 - 20
    a = math.radians(-40)
    dx, dy = x - cx, y - cy
    u = dx * math.cos(a) - dy * math.sin(a)
    v = dx * math.sin(a) + dy * math.cos(a)
    return abs(v) < 7 and -330 < u < 330


def main() -> int:
    rows = []
    for py in range(SIZE):
        row = bytearray([0])
        for px in range(SIZE):
            # 2x2 supersampling for smooth edges
            hits = 0
            vein = 0
            for sx in (0.25, 0.75):
                for sy in (0.25, 0.75):
                    if in_leaf(px + sx, py + sy):
                        hits += 1
                        if in_vein(px + sx, py + sy):
                            vein += 1
            t = hits / 4
            color = tuple(round(GREEN[i] + (WHITE[i] - GREEN[i]) * t) for i in range(3))
            if vein:
                k = vein / 4
                color = tuple(round(color[i] + (GREEN[i] - color[i]) * k) for i in range(3))
            row += bytes(color)
        rows.append(bytes(row))
    raw = b"".join(rows)

    def chunk(tag: bytes, data: bytes) -> bytes:
        return struct.pack(">I", len(data)) + tag + data + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)

    png = (
        b"\x89PNG\r\n\x1a\n"
        + chunk(b"IHDR", struct.pack(">IIBBBBB", SIZE, SIZE, 8, 2, 0, 0, 0))
        + chunk(b"IDAT", zlib.compress(raw, 9))
        + chunk(b"IEND", b"")
    )
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_bytes(png)
    print("wrote", OUT, len(png), "bytes")
    return 0


if __name__ == "__main__":
    sys.exit(main())
