#!/usr/bin/env python3
"""
Generate the Orbits icon set.

Flat, geometric, white ground — the shape language Android launchers expect.
The mark is the game's central verb reduced to two elements: a socket, and the
ball seated in it. The socket is left open on one side, which keeps it from
reading as a generic record/target symbol and hints at the direction the ball
slid in from.

No gradients, glows or 3D shading: those collapse into mush at 48px, which is
the size that actually decides whether an icon works.

Everything renders at 8x and downsamples, so the curves stay clean.
"""
import math
from pathlib import Path

import numpy as np
from PIL import Image

OUT = Path(__file__).resolve().parent.parent / "assets" / "icons"
SS = 8  # supersample factor; flat art needs more than shaded art

CORAL = (0.98, 0.30, 0.36)
WHITE = (1.0, 1.0, 1.0)

RING_RADIUS = 0.300
RING_WIDTH = 0.078
BALL_RADIUS = 0.150

# The socket opens toward the upper left — the direction the ball came from.
GAP_CENTRE_DEG = -132.0
GAP_WIDTH_DEG = 46.0


def canvas(size, opaque_white=False):
    dst = np.zeros((size, size, 4), dtype=np.float64)
    if opaque_white:
        dst[..., :3] = 1.0
        dst[..., 3] = 1.0
    return dst


def coords(size):
    yy, xx = np.mgrid[0:size, 0:size].astype(np.float64)
    return xx, yy


def composite(dst, color, alpha):
    rgb = np.empty(dst.shape[:2] + (3,))
    rgb[..., :] = np.array(color)
    a = alpha[..., None]
    dst[..., :3] = rgb * a + dst[..., :3] * (1.0 - a)
    dst[..., 3] = alpha + dst[..., 3] * (1.0 - alpha)


def disc(dst, size, cx, cy, r, color):
    xx, yy = coords(size)
    d = np.sqrt((xx - cx) ** 2 + (yy - cy) ** 2)
    composite(dst, color, (d <= r).astype(np.float64))


def open_ring(dst, size, cx, cy, radius, width, color,
              gap_centre_deg=None, gap_width_deg=0.0):
    """A stroked circle, optionally with an arc removed and rounded ends."""
    xx, yy = coords(size)
    px, py = xx - cx, yy - cy
    d = np.sqrt(px * px + py * py)
    band = np.abs(d - radius) <= width * 0.5

    if gap_centre_deg is not None and gap_width_deg > 0.0:
        angle = np.arctan2(py, px)
        delta = np.abs(np.arctan2(
            np.sin(angle - math.radians(gap_centre_deg)),
            np.cos(angle - math.radians(gap_centre_deg)),
        ))
        band = band & (delta > math.radians(gap_width_deg * 0.5))

    composite(dst, color, band.astype(np.float64))

    # Round the cut ends so the stroke terminates cleanly rather than square.
    if gap_centre_deg is not None and gap_width_deg > 0.0:
        for sign in (-1.0, 1.0):
            a = math.radians(gap_centre_deg + sign * gap_width_deg * 0.5)
            disc(dst, size, cx + radius * math.cos(a), cy + radius * math.sin(a),
                 width * 0.5, color)


def scene(dst, size, scale=1.0):
    c = size * 0.5
    open_ring(dst, size, c, c,
              size * RING_RADIUS * scale, size * RING_WIDTH * scale, CORAL,
              GAP_CENTRE_DEG, GAP_WIDTH_DEG)
    disc(dst, size, c, c, size * BALL_RADIUS * scale, CORAL)


def save(dst, path, size):
    arr = (np.clip(dst, 0.0, 1.0) * 255.0 + 0.5).astype(np.uint8)
    Image.fromarray(arr, mode="RGBA").resize((size, size), Image.LANCZOS).save(path)
    print(f"  {path.name:<34} {size}x{size}  {path.stat().st_size / 1024:6.1f} KB")


def render(size, out, *, white_bg=True, scale=1.0):
    big = size * SS
    dst = canvas(big, opaque_white=white_bg)
    scene(dst, big, scale=scale)
    save(dst, out, size)


if __name__ == "__main__":
    OUT.mkdir(parents=True, exist_ok=True)

    render(512, OUT / "icon_512.png")
    render(1024, OUT / "icon_1024.png")
    render(192, OUT / "launcher_192.png")

    # Adaptive foreground is masked to the inner ~66%, so the mark shrinks to
    # survive a circle crop on every launcher shape.
    render(432, OUT / "adaptive_foreground_432.png", white_bg=False, scale=0.66)

    bg = canvas(432 * SS, opaque_white=True)
    save(bg, OUT / "adaptive_background_432.png", 432)

    # Themed icons are tinted by the launcher, so the mark is drawn in solid
    # white on transparent and the system recolours it.
    mono = canvas(432 * SS)
    scene(mono, 432 * SS, scale=0.66)
    mono[..., :3] = 1.0
    save(mono, OUT / "adaptive_monochrome_432.png", 432)
