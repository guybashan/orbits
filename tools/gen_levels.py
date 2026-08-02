#!/usr/bin/env python3
"""
Generate the Orbits level bank.

The hand-built 35 had par climbing cleanly but ball density wandering: level
21 was 75% empty, as roomy as the tutorial, while level 15 was 32%. Congestion
is what actually makes a board hard to manoeuvre, so it has to fall as steadily
as par rises.

Here both are driven from the level's position in the game:

    par        climbs  3 -> 70
    free space falls  78% -> 8%
    grid       grows  4x4 -> 8x8

Shape and colour scheme are chosen per level for variety *within* a difficulty
band, never across one. Every pattern is emitted into scripts/levels.gd and
then verified by tests/test_levels.gd, which proves each is solvable within its
par by replaying its shuffle backwards.
"""
import math
from pathlib import Path

LEVELS_GD = Path(__file__).resolve().parent.parent / "scripts" / "levels.gd"
COUNT = 100

# Grid size by fraction through the game.
BANDS = [
    (0.00, 4),
    (0.12, 5),
    (0.32, 6),
    (0.56, 7),
    (0.80, 8),
]

FREE_START, FREE_END = 0.78, 0.03
PAR_START, PAR_END = 3, 70

# Fractions through the game at which a new colour is introduced.
PALETTE_STEPS = [0.15, 0.35, 0.55, 0.75]

# A Constellation lands after every ten regular boards. It is a gift, not a
# test: the board arrives already solved, comes apart in front of the player,
# and they put it back. Deliberately small and roomy so it reads as relief
# after a hard stretch, and it is excluded from the difficulty curve checks
# because it is meant to break the climb.
BONUS_EVERY = 10
BONUS_NAMES = [
    "Constellation", "Nebula Drift", "Starfall", "Perihelion", "Syzygy",
    "Aphelion", "Corona", "Meridian Drift", "Parallax", "Apogee",
]

NAMES = [
    "Origin", "Ember", "Drift", "Signal", "Tether", "Cairn",
    "Vessel", "Anchor", "Sunrise", "Relay", "Bloom", "Ballast",
    "Prime", "Quill", "Nomad", "Spindle", "Ascend", "Verge",
    "Hollow", "Prism", "Lantern", "Kite", "Beacon", "Trellis",
    "Sable", "Marker", "Cinder", "Lattice", "Vertex", "Quartz",
    "Halo", "Cadence", "Wingspan", "Pinwheel", "Meridian", "Devotion",
    "Coil", "Mosaic", "Keystone", "Bastion", "Cascade", "Filament",
    "Harbour", "Ingot", "Junction", "Kestrel", "Lodestone", "Mantle",
    "Nocturne", "Obsidian", "Palisade", "Quiver", "Ridgeline", "Compass",
    "Summit", "Crosswind", "Orbit", "Serpentine", "Tessellate", "Iris",
    "Bullseye", "Gridlock", "Reliquary", "Sentinel", "Tessera", "Undertow",
    "Vanguard", "Wavefront", "Xenolith", "Yardarm", "Zenith", "Aperture",
    "Bulwark", "Citadel", "Draughtsman", "Equinox", "Fulcrum", "Gauntlet",
    "Helix", "Ironclad", "Jetstream", "Kiln", "Labyrinth", "Monolith",
    "Nebula", "Outpost", "Paragon", "Quorum", "Rampart", "Stronghold",
    "Threshold", "Umbra", "Vortex", "Watchtower", "Xerography", "Yoke",
    "Zephyr", "Terminus", "Event Horizon", "Singularity",
]
assert len(NAMES) == COUNT, f"need {COUNT} names, have {len(NAMES)}"


_SEEN = set()


def lerp(a, b, t):
    return a + (b - a) * t


def grid_size(t):
    size = BANDS[0][1]
    for threshold, value in BANDS:
        if t >= threshold:
            size = value
    return size


# --------------------------------------------------------------- shapes --
# Each returns a score per cell; the lowest-scoring cells get balls, so a
# shape defines the order in which a board fills up.

def sq_centre(dx, dy, n):     return max(abs(dx), abs(dy))
def sq_edge(dx, dy, n):       return -max(abs(dx), abs(dy))
def diamond(dx, dy, n):       return abs(dx) + abs(dy)
def circle(dx, dy, n):        return math.hypot(dx, dy)
def cross(dx, dy, n):         return min(abs(dx), abs(dy))
def saltire(dx, dy, n):       return abs(abs(dx) - abs(dy))
def cols(dx, dy, n):          return (dx + n) % 2 * 10 + abs(dy) * 0.1
def rows(dx, dy, n):          return (dy + n) % 2 * 10 + abs(dx) * 0.1
def diagonals(dx, dy, n):     return (dx + dy + 2 * n) % 3 * 10 + abs(dx) * 0.1
def checker(dx, dy, n):       return (dx + dy + 2 * n) % 2 * 10 + math.hypot(dx, dy) * 0.1
def bands(dx, dy, n):         return abs(dy) * 3 + (abs(dx) % 2)
def spiral(dx, dy, n):        return (math.atan2(dy, dx) + math.pi) * 1.4 + math.hypot(dx, dy)

SHAPES = [sq_centre, sq_edge, diamond, circle, cross, saltire,
          cols, rows, diagonals, checker, bands, spiral]


# --------------------------------------------------------------- colours --

def c_quadrant(x, y, dx, dy, n, k):   return 1 + ((1 if dx >= 0 else 0) + 2 * (1 if dy >= 0 else 0)) % k
def c_rings(x, y, dx, dy, n, k):      return 1 + int(max(abs(dx), abs(dy))) % k
def c_rows(x, y, dx, dy, n, k):       return 1 + y % k
def c_cols(x, y, dx, dy, n, k):       return 1 + x % k
def c_checker(x, y, dx, dy, n, k):    return 1 + (x + y) % k
def c_diagonal(x, y, dx, dy, n, k):   return 1 + ((x + y) // 2) % k
def c_radial(x, y, dx, dy, n, k):     return 1 + int(math.hypot(dx, dy)) % k

COLOURS = [c_quadrant, c_rings, c_rows, c_cols,
           c_checker, c_diagonal, c_radial]


def build(index):
    t = index / (COUNT - 1)
    n = grid_size(t)
    cells = n * n

    free_ratio = lerp(FREE_START, FREE_END, t)
    balls = int(round(cells * (1.0 - free_ratio)))
    balls = min(balls, cells - 1)
    balls = max(balls, 3)
    # The last board is deliberately a one-gap puzzle — the tightest the
    # mechanic goes, and the reason the curve exists at all.
    if index == COUNT - 1:
        balls = cells - 1

    # Colour count is the third difficulty dial, alongside ball count and grid
    # size: more colours means more balls that look placeable but are not.
    # Spread across the whole game — keyed to index it topped out at level 48
    # and then sat flat for the remaining half.
    palette_size = 1
    for threshold in PALETTE_STEPS:
        if t >= threshold:
            palette_size += 1
    palette_size = min(palette_size, 5)
    offset = (n - 1) / 2.0

    # Try shape/jitter combinations until this board differs from every earlier
    # one. Without this, small boards collide: at four balls on a 4x4 several
    # shape functions pick the same cells, and four levels shipped identical
    # under different names.
    pattern = None
    fallback = None
    for attempt in range(len(SHAPES) * 5):
        shape = SHAPES[(index * 5 + index // 7 + attempt) % len(SHAPES)]
        spread = 1 + attempt % 5
        scored = []
        for y in range(n):
            for x in range(n):
                dx, dy = x - offset, y - offset
                jitter = ((x * 7 + y * 13 + index * 31 + attempt * 17) % 11) * 0.001 * spread
                scored.append((shape(dx, dy, n) + jitter, x, y))
        scored.sort()
        chosen = scored[:balls]

        for c_offset in range(len(COLOURS)):
            colour = COLOURS[(index * 3 + index // 5 + c_offset) % len(COLOURS)]
            candidate = [[0] * n for _ in range(n)]
            for _, x, y in chosen:
                dx, dy = x - offset, y - offset
                candidate[y][x] = colour(x, y, dx, dy, n, palette_size)

            key = (n, tuple(tuple(r) for r in candidate))
            if key in _SEEN:
                continue
            distinct = len({v for row in candidate for v in row if v})
            if fallback is None:
                fallback = (key, candidate)
            if distinct == palette_size:
                _SEEN.add(key)
                pattern = candidate
                break
        if pattern is not None:
            break

    if pattern is None:
        if fallback is None:
            raise SystemExit(f"no unique board possible for level {index + 1}")
        _SEEN.add(fallback[0])
        pattern = fallback[1]

    par = int(round(lerp(PAR_START, PAR_END, t ** 1.08)))
    return {
        "name": NAMES[index],
        "size": n,
        "depth": par,
        "pattern": pattern,
        "balls": balls,
        "free": cells - balls,
        "free_pct": 100.0 * (cells - balls) / cells,
        "colours": len({v for row in pattern for v in row if v}),
        "palette": palette_size,
    }


def render(levels):
    out = []
    for lv in levels:
        rows_src = ",\n".join(
            "\t\t\t[" + ", ".join(str(v) for v in row) + "]" for row in lv["pattern"]
        )
        out.append(
            '\t{\n'
            f'\t\t"name": "{lv["name"]}", "size": {lv["size"]}, "depth": {lv["depth"]},\n'
            '\t\t"pattern": [\n' + rows_src + ',\n'
            '\t\t],\n'
            '\t},'
        )
    return "\n".join(out)


def build_bonus(slot, after_index):
    """A small, roomy board that starts solved and is scattered on screen."""
    n = 5
    balls = 8 + slot % 3
    offset = (n - 1) / 2.0
    shape = SHAPES[(slot * 3) % len(SHAPES)]
    scored = []
    for y in range(n):
        for x in range(n):
            dx, dy = x - offset, y - offset
            scored.append((shape(dx, dy, n) + ((x * 5 + y * 3 + slot) % 7) * 0.002, x, y))
    scored.sort()

    colour = COLOURS[(slot * 2) % len(COLOURS)]
    palette = 2 + slot % 3
    pattern = [[0] * n for _ in range(n)]
    for _, x, y in scored[:balls]:
        pattern[y][x] = colour(x, y, x - offset, y - offset, n, palette)

    return {
        "name": BONUS_NAMES[slot % len(BONUS_NAMES)],
        "size": n,
        # Shallow: the scatter is what the player watches, and undoing it
        # should take seconds, not minutes.
        "depth": 5 + slot % 3,
        "pattern": pattern,
        "bonus": True,
        "balls": balls,
        "free": n * n - balls,
        "free_pct": 100.0 * (n * n - balls) / (n * n),
        "colours": len({v for row in pattern for v in row if v}),
        "palette": palette,
    }


if __name__ == "__main__":
    regular = [build(i) for i in range(COUNT)]

    levels = []
    slot = 0
    for i, lv in enumerate(regular):
        levels.append(lv)
        if (i + 1) % BONUS_EVERY == 0:
            levels.append(build_bonus(slot, i))
            slot += 1

    # --- invariants the whole design rests on -----------------------------
    problems = []
    graded = [lv for lv in levels if not lv.get("bonus")]
    for i in range(1, len(graded)):
        if graded[i]["depth"] < graded[i - 1]["depth"]:
            problems.append(f"par drops at L{i + 1}")
        if graded[i]["colours"] < graded[i - 1]["colours"]:
            problems.append(f"colours drop at graded level {i + 1}")
        if graded[i]["free_pct"] > graded[i - 1]["free_pct"] + 0.01:
            problems.append(f"congestion eases at graded level {i + 1}")
    seen = {}
    for i, lv in enumerate(levels):
        key = (lv["size"], tuple(tuple(r) for r in lv["pattern"]))
        if key in seen:
            problems.append(f"L{i + 1} is identical to L{seen[key] + 1}")
        seen[key] = i
        if lv["free"] < 1:
            problems.append(f"L{i + 1} has no free cell, so nothing can move")
        used = {v for row in lv["pattern"] for v in row if v}
        if not used:
            problems.append(f"L{i + 1} has no balls")

    if problems:
        for p in problems[:12]:
            print("PROBLEM:", p)
        raise SystemExit(1)

    source = LEVELS_GD.read_text()
    head, _, rest = source.partition("const LEVELS: Array = [\n")
    _, _, tail = rest.partition("\n]\n")
    LEVELS_GD.write_text(head + "const LEVELS: Array = [\n" + render(levels) + "\n]\n" + tail)

    bonus_count = sum(1 for lv in levels if lv.get("bonus"))
    print(f"wrote {len(levels)} levels ({len(graded)} graded + {bonus_count} bonus)")
    print(f"{'#':>4} {'name':<17} {'grid':<5} {'balls':>5} {'free%':>6} {'cols':>5} {'par':>4}")
    for i in list(range(0, len(levels), 11)) + [len(levels) - 1]:
        lv = levels[i]
        print(f"{i+1:>4} {lv['name']:<17} {lv['size']}x{lv['size']}   "
              f"{lv['balls']:>5} {lv['free_pct']:>5.0f}% {lv['colours']:>5} {lv['depth']:>4}")
    print("\npar, congestion and colour count all climb monotonically")
