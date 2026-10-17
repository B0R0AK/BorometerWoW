#!/usr/bin/env python3
"""Renders the ring textures (white, alpha only) as 32-bit TGA. Run after changing the ring geometry."""
import pathlib
import struct

import numpy as np

SIZE = 256
out = pathlib.Path(__file__).resolve().parent.parent / "Borometer" / "Media"

y, x = np.mgrid[0:SIZE, 0:SIZE]
r = np.hypot(x - (SIZE - 1) / 2, y - (SIZE - 1) / 2) / (SIZE / 2)  # 1.0 = texture edge


def smooth(v):
    return np.clip(v, 0.0, 1.0)


def write_tga(name, alpha):
    a = (smooth(alpha) * 255).astype(np.uint8)
    rgba = np.zeros((SIZE, SIZE, 4), np.uint8)
    rgba[..., :3] = 255
    rgba[..., 3] = a
    bgra = rgba[..., [2, 1, 0, 3]]
    header = struct.pack("<BBBHHBHHHHBB", 0, 0, 2, 0, 0, 0, 0, 0, SIZE, SIZE, 32, 8 | 0x20)  # top-left origin
    (out / name).write_bytes(header + bgra.tobytes())


aa = 1.5 / (SIZE / 2)
inner, outer = 0.70, 0.90
ring = smooth((r - inner) / aa + 0.5) * smooth((outer - r) / aa + 0.5)
write_tga("ring.tga", ring)

# Halo: the same ring, blurred wide, brighter toward the ring itself.
mid = (inner + outer) / 2
d = np.abs(r - mid)
halo = np.exp(-((d / 0.13) ** 2)) * smooth((0.99 - r) / 0.03)
write_tga("glow.tga", halo)
print("wrote ring.tga, glow.tga")
