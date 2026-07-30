#!/usr/bin/env python3
"""Generate the Orbits icon set: shaded orbs on rings, matching the game."""
from pathlib import Path

import numpy as np
from PIL import Image

OUT = Path("/Users/columbo/dev/godot-orbits/assets/icons")
SS = 4  # supersample factor

PALETTE = {
    "coral": (1.00, 0.35, 0.42),
    "mint": (0.24, 0.85, 0.70),
    "azure": (0.34, 0.60, 1.00),
    "amber": (1.00, 0.76, 0.24),
}

LIGHT = np.array([-0.42, -0.58, 0.70])
LIGHT /= np.linalg.norm(LIGHT)


def new_canvas(size):
    """RGBA float canvas."""
    return np.zeros((size, size, 4), dtype=np.float64)


def composite(dst, src_rgb, src_a):
    """Standard source-over onto a premultiplied-by-alpha float canvas."""
    a = src_a[..., None]
    dst[..., :3] = src_rgb * a + dst[..., :3] * (1 - a)
    dst[..., 3] = src_a + dst[..., 3] * (1 - src_a)


def grid(size, cx, cy, r):
    yy, xx = np.mgrid[0:size, 0:size].astype(np.float64)
    return (xx - cx) / r, (yy - cy) / r


def draw_orb(canvas, cx, cy, r, color):
    """A shaded sphere: diffuse term, tight specular, and a rim light."""
    size = canvas.shape[0]
    dx, dy = grid(size, cx, cy, r)
    d2 = dx * dx + dy * dy
    inside = d2 <= 1.0

    nz = np.sqrt(np.clip(1.0 - d2, 0.0, 1.0))
    ndl = np.clip(dx * LIGHT[0] + dy * LIGHT[1] + nz * LIGHT[2], 0.0, 1.0)

    base = np.array(color)
    diffuse = 0.28 + 0.80 * ndl
    rim = (1.0 - nz) ** 3 * 0.40
    spec = ndl ** 34 * 1.05

    rgb = base[None, None, :] * (diffuse + rim)[..., None] + spec[..., None]
    rgb = np.clip(rgb, 0.0, 1.0)

    alpha = inside.astype(np.float64)
    composite(canvas, rgb, alpha)


def draw_ring(canvas, cx, cy, r, thickness, color, energy=1.0):
    size = canvas.shape[0]
    dx, dy = grid(size, cx, cy, r)
    d = np.sqrt(dx * dx + dy * dy)
    half = thickness / (2.0 * r)
    band = np.abs(d - 1.0) <= half

    rgb = np.zeros((size, size, 3))
    rgb[..., :] = np.array(color) * energy
    composite(canvas, np.clip(rgb, 0, 1), band.astype(np.float64))


def draw_glow(canvas, cx, cy, r, color, strength=0.5):
    size = canvas.shape[0]
    dx, dy = grid(size, cx, cy, r)
    d = np.sqrt(dx * dx + dy * dy)
    falloff = np.clip(1.0 - d, 0.0, 1.0) ** 2.6 * strength

    rgb = np.zeros((size, size, 3))
    rgb[..., :] = np.array(color)
    composite(canvas, rgb, falloff)


def cluster(canvas, size, scale=1.0, centre=0.5):
    """The 2x2 motif: three balls home, one ring still waiting."""
    c = size * centre
    step = size * 0.215 * scale
    r_orb = size * 0.098 * scale
    r_ring = size * 0.125 * scale

    cells = [
        (-1, -1, "coral"),
        (+1, -1, "mint"),
        (-1, +1, "amber"),
        (+1, +1, "azure"),
    ]

    # Rings first, so the orbs sit on top of them.
    for gx, gy, name in cells:
        x, y = c + gx * step, c + gy * step
        col = PALETTE[name]
        draw_glow(canvas, x, y, r_ring * 2.3, col, 0.22)
        draw_ring(canvas, x, y, r_ring, size * 0.026 * scale, col, 1.0)

    for gx, gy, name in cells:
        # Bottom-right stays empty: that is the puzzle, in one glance.
        if (gx, gy) == (+1, +1):
            continue
        x, y = c + gx * step, c + gy * step
        draw_orb(canvas, x, y, r_orb, PALETTE[name])


def background(canvas, size):
    """Deep navy with a soft radial lift toward the centre."""
    yy, xx = np.mgrid[0:size, 0:size].astype(np.float64)
    dx = (xx - size / 2) / (size / 2)
    dy = (yy - size / 2) / (size / 2)
    d = np.clip(np.sqrt(dx * dx + dy * dy) / 1.414, 0, 1)

    deep = np.array([0.012, 0.020, 0.055])
    lift = np.array([0.055, 0.090, 0.205])
    rgb = lift[None, None, :] * (1 - d)[..., None] ** 1.6 + deep[None, None, :]
    canvas[..., :3] = np.clip(rgb, 0, 1)
    canvas[..., 3] = 1.0


def save(canvas, path, size):
    img = np.clip(canvas, 0.0, 1.0)
    # Un-premultiply is unnecessary: composite() keeps colour straight.
    arr = (img * 255.0 + 0.5).astype(np.uint8)
    image = Image.fromarray(arr, mode="RGBA").resize((size, size), Image.LANCZOS)
    image.save(path)
    print(f"{path.name}: {size}x{size}  {path.stat().st_size / 1024:.1f} KB")


def render(size, *, with_bg, scale=1.0, out=None):
    big = size * SS
    canvas = new_canvas(big)
    if with_bg:
        background(canvas, big)
    cluster(canvas, big, scale=scale)
    save(canvas, out, size)


if __name__ == "__main__":
    OUT.mkdir(parents=True, exist_ok=True)

    # Full-bleed icons (Play Store listing, in-engine window icon).
    render(512, with_bg=True, out=OUT / "icon_512.png")
    render(1024, with_bg=True, out=OUT / "icon_1024.png")

    # Android legacy launcher icon.
    render(192, with_bg=True, out=OUT / "launcher_192.png")

    # Adaptive icon: the foreground must survive a 66% mask crop, so the
    # motif is scaled down to sit inside the safe zone.
    render(432, with_bg=False, scale=0.62, out=OUT / "adaptive_foreground_432.png")

    bg = new_canvas(432 * SS)
    background(bg, 432 * SS)
    save(bg, OUT / "adaptive_background_432.png", 432)

    mono = new_canvas(432 * SS)
    cluster(mono, 432 * SS, scale=0.62)
    mono[..., :3] = 1.0  # themed icons are tinted by the launcher
    save(mono, OUT / "adaptive_monochrome_432.png", 432)
