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
import collections
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
#
# Front-loaded, and deliberately not on the same gentle slope as par, balls and
# board size. Those were all ramped linearly together, which put the second
# colour at level 16 and the third at level 40 — so for the first fifteen levels
# every ball was identical, any ball fitted any socket, and the game was a plain
# sliding puzzle. Colour matching is the whole idea; a player deciding in the
# first three minutes never reached it. Two colours now land almost immediately
# and all five by the end of the first quarter.
PALETTE_STEPS = [0.015, 0.06, 0.15, 0.27]

# Bonus boards are off. They were the same mechanic on an easier board with a
# scripted come-apart animation and three guaranteed stars — not different
# enough to earn a slot, and their presence made the game 110 levels when it was
# sold as 100. Turning them off also puts the one-gap finale last, where it
# belongs, instead of behind a breather. Set to 10 to bring them back; the
# builder below is left intact.
BONUS_EVERY = 0
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

# Accepted boards per size, flattened, for the look-alike check below. Two
# levels sharing this fraction of their cells read as "the same screen again"
# even when no cell-for-cell duplicate exists. Crowded late boards cannot go
# much below this: at 63 balls in 64 cells the occupancy is forced, so only the
# colour arrangement is free to differ.
MAX_SIMILARITY = 0.82
_ACCEPTED = collections.defaultdict(list)


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

def c_blocks(x, y, dx, dy, n, k):     return 1 + ((x // 2) + (y // 2)) % k
def c_spiral(x, y, dx, dy, n, k):     return 1 + int((math.atan2(dy, dx) + math.pi) / (2 * math.pi) * k) % k
def c_stripe3(x, y, dx, dy, n, k):    return 1 + ((x + 2 * y) // 2) % k
def c_wedge(x, y, dx, dy, n, k):      return 1 + (abs(int(dx)) + 2 * abs(int(dy))) % k
def c_knight(x, y, dx, dy, n, k):     return 1 + (x * 2 + y * 3) % k

# Eleven, not seven. With seven schemes and a selector that advanced with the
# level index, boards seven apart drew the same one — and on a crowded board the
# scheme is the arrangement, so those pairs came out nearly identical. A count
# coprime with the shape count also stops the two cycling in step.
COLOURS = [c_quadrant, c_rings, c_rows, c_cols,
           c_checker, c_diagonal, c_radial,
           c_blocks, c_spiral, c_stripe3, c_wedge, c_knight]


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
    # Rejecting only exact duplicates was not enough. There are 7 colour schemes
    # and the selector advanced with the level index, so boards seven apart drew
    # the same scheme; on a crowded board, where the shape barely shows because
    # nearly every cell is filled, the scheme IS the arrangement, and those pairs
    # came out 92-97% identical. Every candidate is now scored against the boards
    # already accepted at this size, and the least similar one wins.
    best = None  # (similarity, key, candidate)
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
            if len({v for row in candidate for v in row if v}) != palette_size:
                continue

            flat = [c for row in candidate for c in row]
            worst = max((sum(1 for a, b in zip(flat, prev) if a == b) / len(flat)
                         for prev in _ACCEPTED[n]), default=0.0)
            if best is None or worst < best[0]:
                best = (worst, key, candidate)
            if worst <= MAX_SIMILARITY:
                break
        if best is not None and best[0] <= MAX_SIMILARITY:
            break

    if best is None:
        raise SystemExit(f"no unique board possible for level {index + 1}")
    _SEEN.add(best[1])
    _ACCEPTED[n].append([c for row in best[2] for c in row])
    pattern = best[2]

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
        flag = ' "bonus": true,' if lv.get("bonus") else ''
        out.append(
            '\t{\n'
            f'\t\t"name": "{lv["name"]}", "size": {lv["size"]}, "depth": {lv["depth"]},{flag}\n'
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
        if BONUS_EVERY and (i + 1) % BONUS_EVERY == 0:
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
