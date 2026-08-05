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

THE SIZE RULE. A ball is about 54px on an 8x8 board. The first version of this
file was written for realism at 512px and never checked at 54, and three of the
five bodies collapsed to flat discs — Uranus rendered as a plain cyan circle
that read as a missing texture, and Earth's continents landed on the poles so
the visible face was empty navy. Only Jupiter survived, because bold horizontal
bands with real light/dark contrast are the one thing that downsamples.

So: features must be LARGE, HIGH-CONTRAST and mostly HORIZONTAL, and they must
sit near the equator, which is the part of the sphere facing the camera. Where
that fights the real planet, the game wins — a puzzle piece has to be legible
first. Run this file's __main__ to print the small-size contrast of each body;
anything under ~0.10 is a flat disc no matter how good the 512px art looks.
"""
import colorsys
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
    """Ocean blue with big equatorial continents and a thin cloud layer."""
    img = np.zeros((H, W, 3))
    img[:] = (0.07, 0.33, 0.70)                       # deep ocean
    # Big enough to survive downsampling, but not so big that the whole face is
    # one continent: at cells=1.6 this produced a single green wedge with
    # straight edges that read as a cut-out shape rather than land.
    land = noise((H, W), 2.2, seed=11, octaves=5)
    lat = latitude()

    # The old penalty here was abs(lat) * 0.12, far too weak against noise in
    # [0, 1] — and worse, the percentile was taken over the whole map, where
    # polar rows carry as many pixels as the equator despite covering almost no
    # sphere area. The poles duly won and the face of the ball came out empty.
    # Push land hard into the tropics and mid-latitudes, and take the sea level
    # only from that band.
    # Quadratic falloff rather than a clipped ramp: the ramp's shoulder left a
    # green stripe running along one latitude, which looked like a painted band.
    land = land - (np.abs(lat) ** 2) * 0.55
    band = np.abs(lat) < 0.60

    sea_level = np.percentile(land[band], 52)         # ~35% land on the face
    inland = np.percentile(land[band], 74)
    span = max(land.max() - sea_level, 1e-6)

    shelf = np.clip((land - (sea_level - span * 0.12)) / (span * 0.12), 0, 1)
    img = blend(img, (0.13, 0.48, 0.80), shelf)       # shallow water
    # Crisp, but not a hard edge — 0.05 of span gave coastlines that looked
    # laser-cut. This keeps them readable with a pixel or two of falloff.
    green = np.clip((land - sea_level) / (span * 0.10), 0, 1)
    img = blend(img, (0.24, 0.60, 0.26), green)       # vegetation
    arid = np.clip((land - inland) / (span * 0.22), 0, 1)
    img = blend(img, (0.78, 0.68, 0.40), arid)        # desert / rock

    # Small caps: a wide one eats the top of the disc and reads as glare.
    img = polar_caps(img, 0.93)
    cloud = noise((H, W), 4, seed=27, octaves=3)
    img = blend(img, (1.0, 1.0, 1.0),
                np.clip((cloud - np.percentile(cloud, 80)) / 0.12, 0, 1) * 0.42)
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
    """Pale cyan, banded well past the real planet's contrast.

    Uranus really is nearly featureless, and rendering that honestly is what
    produced a 1 KB texture that looked like a missing asset on the board. The
    hue is what identifies the slot; the banding is what stops it reading as an
    untextured sphere. Realism loses this one.
    """
    lat = latitude()
    turb = (noise((H, W), 3, seed=23, octaves=3) - 0.5) * 0.16
    bands = np.sin((lat + turb) * math.pi * 4.5) * 0.5 + 0.5

    img = np.zeros((H, W, 3))
    # Pulled green, toward the MINT socket tint. Real Uranus is a pure pale
    # cyan, which sat close enough to AZURE that the two balls were hard to
    # tell apart on the board while their sockets stayed obviously different.
    light = np.array((0.52, 0.95, 0.88))
    dark = np.array((0.16, 0.68, 0.62))
    mix = bands[..., None]
    img[:] = light * mix + dark * (1 - mix)

    # The bright polar hood Voyager saw, kept narrow so it frames rather than
    # floods the disc.
    hood = np.clip((np.abs(lat) - 0.74) / 0.26, 0, 1)
    img = blend(img, (0.70, 0.97, 0.90), hood * 0.55)
    return img


def neptune():
    """Deep indigo with a dark storm, kept violet enough to read as its slot."""
    lat = latitude()
    turb = (noise((H, W), 3.5, seed=41, octaves=3) - 0.5) * 0.20
    bands = np.sin((lat + turb) * math.pi * 4.0) * 0.5 + 0.5

    # Built as a light/dark mix like Jupiter rather than a dark wash over a
    # flat base, which is what left the old one a featureless purple disc.
    img = np.zeros((H, W, 3))
    # Pushed off blue and into purple, toward the VIOLET socket tint. Neptune's
    # true indigo landed right on top of AZURE, so the board had two blue balls
    # and the colour match — the entire puzzle — became guesswork.
    light = np.array((0.64, 0.44, 0.96))
    dark = np.array((0.30, 0.14, 0.60))
    mix = bands[..., None]
    img[:] = light * mix + dark * (1 - mix)

    yy, xx = np.mgrid[0:H, 0:W]
    spot = (((xx - W * 0.35) / (W * 0.11)) ** 2 + ((yy - H * 0.44) / (H * 0.085)) ** 2)
    img = blend(img, (0.16, 0.07, 0.36), np.clip(1.0 - spot, 0, 1) ** 0.45)

    # Bright methane cloud streaks. Absolute cut-offs put these below the noise
    # floor before, so nothing showed; percentiles pin how much is visible.
    # Kept to a few wisps: at the 80th percentile and 0.75 opacity they covered
    # half the disc and the ball stopped reading as violet at all, which breaks
    # the only thing the player actually matches on.
    # Finer noise (5 -> 8 cells) so these break into several wisps instead of
    # one broad patch sitting on one side of the disc.
    streak = noise((H, W), 8, seed=31, octaves=3) - np.abs(lat) * 0.15
    img = blend(img, (0.88, 0.90, 1.0),
                np.clip((streak - np.percentile(streak, 93)) / 0.06, 0, 1) * 0.50)
    return img


# Slot order matches Ball.ColorType: CORAL, MINT, AZURE, AMBER, VIOLET.
PLANETS = [
    ("coral_mars", mars),
    ("mint_uranus", uranus),
    ("azure_earth", earth),
    ("amber_jupiter", jupiter),
    ("violet_neptune", neptune),
]


## A ball is ~54px in game. Sample the equatorial third of the texture at that
## width and measure how much luminance variation is left: this is the number
## that decides whether a body reads as a planet or as a coloured disc.
BALL_PX = 54
FLAT = 0.10


## Colour is what the player matches on, so a body must stay unmistakably its
## slot's hue. Chasing contrast is what breaks this: Neptune's cloud streaks,
## turned up until they were visible, covered half the disc in white and the
## ball stopped reading as violet. Mean chroma over the visible face is the
## cheap proxy — it falls as a texture washes toward white or grey.
MIN_CHROMA = 0.18

## Ball.PALETTE, which tints the socket a ball has to reach. The planet and its
## socket must read as the same colour: they are the two halves of the match.
## Uranus and Neptune shipped at their true hues — pale cyan and indigo — and
## both drifted into AZURE's blue, so the board carried three balls a player
## could not reliably tell apart while their sockets stayed distinct.
SLOT_HUE = {
    "coral_mars": (1.00, 0.35, 0.42),
    "mint_uranus": (0.24, 0.85, 0.70),
    "azure_earth": (0.34, 0.60, 1.00),
    "amber_jupiter": (1.00, 0.76, 0.24),
    "violet_neptune": (0.72, 0.45, 1.00),
}
MAX_HUE_DRIFT = 30.0  # degrees


def _hue(rgb):
    return colorsys.rgb_to_hsv(*rgb)[0] * 360.0


def hue_drift(img, name):
    """Degrees between the texture's DOMINANT hue and its socket tint.

    Dominant, not mean: Earth's continents drag an average toward green by ~38
    degrees while the ball still plainly reads as blue, and a mean would have
    demanded that the land be bleached out to satisfy a number. The histogram
    peak is what the eye actually calls the colour. Near-grey pixels are
    excluded because their hue is noise.
    """
    face = np.clip(img[int(H * 0.33):int(H * 0.67), :], 0, 1).reshape(-1, 3)
    chroma = face.max(axis=1) - face.min(axis=1)
    face = face[chroma > 0.08]
    if len(face) == 0:
        return 180.0

    mx = face.max(axis=1); mn = face.min(axis=1); span = mx - mn
    r, g, b = face[:, 0], face[:, 1], face[:, 2]
    hue = np.where(
        mx == r, (g - b) / span % 6,
        np.where(mx == g, (b - r) / span + 2, (r - g) / span + 4),
    ) * 60.0

    counts, edges = np.histogram(hue % 360.0, bins=36, range=(0, 360))
    peak = (edges[counts.argmax()] + edges[counts.argmax() + 1]) / 2
    delta = abs(peak - _hue(SLOT_HUE[name]))
    return min(delta, 360.0 - delta)


def face_chroma(img):
    face = np.clip(img[int(H * 0.33):int(H * 0.67), :], 0, 1)
    return float((face.max(axis=2) - face.min(axis=2)).mean())


def small_contrast(img):
    face = img[int(H * 0.33):int(H * 0.67), :]
    thumb = Image.fromarray((np.clip(face, 0, 1) * 255).astype(np.uint8), "RGB")
    thumb = thumb.resize((BALL_PX, BALL_PX // 2), Image.LANCZOS)
    lum = np.asarray(thumb).astype(float).mean(axis=2) / 255.0
    return float(lum.max() - lum.min())


if __name__ == "__main__":
    OUT.mkdir(parents=True, exist_ok=True)
    problems = []
    for name, fn in PLANETS:
        img = np.clip(fn(), 0, 1)
        path = OUT / f"{name}.png"
        Image.fromarray((img * 255 + 0.5).astype(np.uint8), "RGB").save(path)

        contrast = small_contrast(img)
        chroma = face_chroma(img)
        drift = hue_drift(img, name)
        marks = []
        if contrast < FLAT:
            marks.append("FLAT")
            problems.append(f"{name}: flat at ball size (contrast {contrast:.3f})")
        if chroma < MIN_CHROMA:
            marks.append("WASHED")
            problems.append(f"{name}: washed out of its colour slot (chroma {chroma:.3f})")
        if drift > MAX_HUE_DRIFT:
            marks.append("OFF-HUE")
            problems.append(f"{name}: {drift:.0f} deg from its socket tint")

        print(f"  {name:<16} {path.stat().st_size / 1024:6.1f} KB"
              f"  contrast {contrast:.3f}  chroma {chroma:.3f}"
              f"  hue drift {drift:4.0f} deg  {' '.join(marks)}")

    if problems:
        raise SystemExit("\n" + "\n".join(problems) + "\n"
                         "features must be large, horizontal and high-contrast "
                         "WITHOUT diluting the slot hue")
