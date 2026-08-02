#!/usr/bin/env python3
"""
Generate equirectangular planet textures for the five ball colours.

The constraint that shapes everything here: colour is the channel the game
matches on. Sockets are tinted with the goal colour, so a planet has to keep
its slot's hue dominant and read as a real body *within* that hue — Earth blue
enough to be the azure ball, but with continents visible at 54px, which is how
large a ball actually is on an 8x8 board.

Textures are 512x256 and wrap horizontally, so they map onto a sphere without
a visible seam.
"""
import math
from pathlib import Path

import numpy as np
from PIL import Image

OUT = Path(__file__).resolve().parent.parent / "assets" / "planets"
W, H = 512, 256


def noise(shape, cells, seed, octaves=4):
    """Value noise that wraps in x, so the texture has no seam on the sphere."""
    h, w = shape
    total = np.zeros(shape)
    amplitude = 1.0
    norm = 0.0
    rng = np.random.default_rng(seed)

    for o in range(octaves):
        cx = max(int(cells * (2 ** o)), 2)
        cy = max(int(cells * (2 ** o) * h / w), 2)
        grid = rng.random((cy + 1, cx))
        # Wrap in x by repeating the first column; clamp in y (poles).
        grid = np.concatenate([grid, grid[:, :1]], axis=1)

        ys = np.linspace(0, cy, h, endpoint=False)
        xs = np.linspace(0, cx, w, endpoint=False)
        y0 = np.floor(ys).astype(int); y1 = np.minimum(y0 + 1, cy)
        x0 = np.floor(xs).astype(int); x1 = np.minimum(x0 + 1, cx)
        fy = (ys - y0)[:, None]; fx = (xs - x0)[None, :]
        # Smoothstep for rounded blobs rather than diamond artefacts.
        fy = fy * fy * (3 - 2 * fy); fx = fx * fx * (3 - 2 * fx)

        top = grid[np.ix_(y0, x0)] * (1 - fx) + grid[np.ix_(y0, x1)] * fx
        bot = grid[np.ix_(y1, x0)] * (1 - fx) + grid[np.ix_(y1, x1)] * fx
        total += (top * (1 - fy) + bot * fy) * amplitude
        norm += amplitude
        amplitude *= 0.5

    return total / norm


def latitude():
    return np.linspace(-1.0, 1.0, H)[:, None] * np.ones((1, W))


def blend(base, colour, mask):
    return base * (1 - mask[..., None]) + np.array(colour)[None, None, :] * mask[..., None]


def polar_caps(img, extent=0.86, colour=(0.96, 0.97, 1.0)):
    lat = np.abs(latitude())
    cap = np.clip((lat - extent) / (1.0 - extent), 0, 1) ** 0.6
    return blend(img, colour, cap)


# ------------------------------------------------------------------ bodies --

def earth():
    """Ocean blue with real landmass shapes and a thin cloud layer."""
    img = np.zeros((H, W, 3))
    img[:] = (0.06, 0.28, 0.62)                       # deep ocean
    land = noise((H, W), 2.5, seed=11, octaves=5)
    # Squeeze toward the equator so continents are not smeared over the poles.
    land = land - np.abs(latitude()) * 0.12

    # Thresholds are percentiles, not fixed values: the noise range shifts with
    # seed and octave count, and hard-coded cut-offs produced a world that was
    # all ocean. This pins land coverage at roughly a third, like the real one.
    sea_level = np.percentile(land, 66)
    inland = np.percentile(land, 80)
    span = max(land.max() - sea_level, 1e-6)

    shelf = np.clip((land - (sea_level - span * 0.10)) / (span * 0.10), 0, 1)
    img = blend(img, (0.10, 0.44, 0.74), shelf)       # shallow water
    green = np.clip((land - sea_level) / (span * 0.12), 0, 1)
    img = blend(img, (0.18, 0.50, 0.22), green)       # vegetation
    arid = np.clip((land - inland) / (span * 0.30), 0, 1)
    img = blend(img, (0.66, 0.58, 0.34), arid)        # desert / rock

    img = polar_caps(img, 0.88)
    cloud = noise((H, W), 5, seed=27, octaves=4)
    img = blend(img, (1.0, 1.0, 1.0),
                np.clip((cloud - np.percentile(cloud, 72)) / 0.16, 0, 1) * 0.50)
    return img


def mars():
    """Rust, with darker maria and a bright southern cap."""
    img = np.zeros((H, W, 3))
    img[:] = (0.72, 0.30, 0.18)
    n = noise((H, W), 3, seed=5, octaves=5)
    img = blend(img, (0.46, 0.17, 0.10), np.clip((n - np.percentile(n, 55)) / 0.12, 0, 1))
    img = blend(img, (0.86, 0.46, 0.28), np.clip((0.42 - n) / 0.12, 0, 1))
    return polar_caps(img, 0.92)


def jupiter():
    """Banded amber. The one body whose texture survives at small size."""
    lat = latitude()
    turb = (noise((H, W), 4, seed=17, octaves=4) - 0.5) * 0.30
    bands = np.sin((lat + turb) * math.pi * 5.5)

    img = np.zeros((H, W, 3))
    light = np.array((0.98, 0.86, 0.62))
    dark = np.array((0.78, 0.50, 0.22))
    mix = ((bands + 1) / 2)[..., None]
    img[:] = light * mix + dark * (1 - mix)

    # Great Red Spot: an oval, positioned below the equator.
    yy, xx = np.mgrid[0:H, 0:W]
    spot = (((xx - W * 0.62) / (W * 0.075)) ** 2 + ((yy - H * 0.62) / (H * 0.055)) ** 2)
    img = blend(img, (0.80, 0.34, 0.24), np.clip(1.0 - spot, 0, 1) ** 0.5)
    return img


def uranus():
    """Almost featureless pale cyan — its real character is its blankness."""
    lat = latitude()
    img = np.zeros((H, W, 3))
    base = np.array((0.55, 0.85, 0.88))
    img[:] = base
    faint = np.sin(lat * math.pi * 3.0) * 0.5 + 0.5
    img = blend(img, (0.44, 0.78, 0.83), faint * 0.22)
    return img


def neptune():
    """Deep indigo with a dark storm, kept violet enough to read as its slot."""
    lat = latitude()
    img = np.zeros((H, W, 3))
    img[:] = (0.30, 0.30, 0.72)
    turb = (noise((H, W), 4, seed=41, octaves=3) - 0.5) * 0.22
    bands = np.sin((lat + turb) * math.pi * 4.0) * 0.5 + 0.5
    img = blend(img, (0.18, 0.16, 0.54), bands * 0.60)

    yy, xx = np.mgrid[0:H, 0:W]
    spot = (((xx - W * 0.35) / (W * 0.10)) ** 2 + ((yy - H * 0.42) / (H * 0.075)) ** 2)
    img = blend(img, (0.10, 0.09, 0.34), np.clip(1.0 - spot, 0, 1) ** 0.45)
    streak = noise((H, W), 6, seed=31, octaves=3)
    img = blend(img, (0.62, 0.62, 0.92), np.clip((streak - 0.68) / 0.18, 0, 1) * 0.35)
    return img


# Slot order matches Ball.ColorType: CORAL, MINT, AZURE, AMBER, VIOLET.
PLANETS = [
    ("coral_mars", mars),
    ("mint_uranus", uranus),
    ("azure_earth", earth),
    ("amber_jupiter", jupiter),
    ("violet_neptune", neptune),
]


if __name__ == "__main__":
    OUT.mkdir(parents=True, exist_ok=True)
    for name, fn in PLANETS:
        img = np.clip(fn(), 0, 1)
        path = OUT / f"{name}.png"
        Image.fromarray((img * 255 + 0.5).astype(np.uint8), "RGB").save(path)
        print(f"  {name:<16} {W}x{H}  {path.stat().st_size / 1024:6.1f} KB")
