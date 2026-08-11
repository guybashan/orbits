class_name Levels
extends RefCounted

## Level bank + start-state generation.
##
## A level is defined only by its SOLVED state (the pattern the player must
## rebuild). The starting layout is produced by walking backwards from that
## solved state with `depth` random legal moves. Because every move is
## reversible, this guarantees the level is solvable in at most `depth` moves,
## which also gives us an honest par to score against.
##
## Pattern cells: 0 = empty socket, 1..5 = ball colour (see Ball.ColorType).
## Patterns are indexed [y][x].

const DIRS: Array[Vector2i] = [
	Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)
]

## Layouts must be identical for every player, so generation is seeded from the
## level index alone — never from time, device or session state. Changing these
## two numbers reshuffles every level in the game; tests/test_levels.gd pins the
## current layouts so that can never happen by accident.
const SEED_BASE := 987654321
const SEED_STRIDE := 2654435761

const LEVELS: Array = [
	{
		"name": "Origin", "size": 4, "depth": 3,
		"pattern": [
			[0, 0, 0, 0],
			[0, 1, 1, 0],
			[0, 1, 1, 0],
			[0, 0, 0, 0],
		],
	},
	{
		"name": "Ember", "size": 4, "depth": 3,
		"pattern": [
			[0, 0, 0, 0],
			[0, 0, 1, 0],
			[0, 0, 1, 0],
			[1, 0, 0, 1],
		],
	},
	{
		"name": "Drift", "size": 4, "depth": 4,
		"pattern": [
			[0, 0, 0, 0],
			[0, 1, 2, 0],
			[0, 1, 2, 0],
			[0, 0, 0, 0],
		],
	},
	{
		"name": "Signal", "size": 4, "depth": 5,
		"pattern": [
			[0, 0, 0, 0],
			[0, 2, 2, 0],
			[0, 1, 1, 0],
			[0, 0, 0, 0],
		],
	},
	{
		"name": "Tether", "size": 4, "depth": 5,
		"pattern": [
			[0, 2, 0, 0],
			[0, 0, 0, 2],
			[0, 0, 1, 0],
			[0, 2, 0, 0],
		],
	},
	{
		"name": "Cairn", "size": 4, "depth": 6,
		"pattern": [
			[1, 0, 0, 1],
			[2, 0, 0, 2],
			[0, 0, 0, 0],
			[0, 0, 0, 0],
		],
	},
	{
		"name": "Vessel", "size": 4, "depth": 6,
		"pattern": [
			[0, 0, 0, 0],
			[1, 0, 2, 0],
			[2, 0, 3, 0],
			[0, 0, 0, 0],
		],
	},
	{
		"name": "Anchor", "size": 4, "depth": 7,
		"pattern": [
			[0, 0, 0, 0],
			[0, 3, 1, 0],
			[0, 1, 2, 0],
			[0, 0, 0, 0],
		],
	},
	{
		"name": "Sunrise", "size": 4, "depth": 7,
		"pattern": [
			[0, 0, 0, 0],
			[0, 0, 2, 0],
			[0, 0, 3, 0],
			[2, 0, 0, 1],
		],
	},
	{
		"name": "Relay", "size": 4, "depth": 8,
		"pattern": [
			[0, 0, 0, 0],
			[0, 1, 2, 2],
			[0, 3, 1, 0],
			[0, 0, 0, 0],
		],
	},
	{
		"name": "Bloom", "size": 4, "depth": 9,
		"pattern": [
			[0, 0, 0, 0],
			[0, 3, 1, 0],
			[0, 1, 2, 0],
			[0, 0, 3, 0],
		],
	},
	{
		"name": "Ballast", "size": 4, "depth": 9,
		"pattern": [
			[0, 1, 0, 0],
			[1, 0, 0, 2],
			[0, 0, 1, 0],
			[0, 3, 0, 0],
		],
	},
	{
		"name": "Prime", "size": 5, "depth": 10,
		"pattern": [
			[0, 2, 3, 0, 2],
			[1, 0, 0, 0, 0],
			[1, 0, 0, 0, 0],
			[1, 0, 0, 0, 0],
			[0, 2, 0, 0, 2],
		],
	},
	{
		"name": "Quill", "size": 5, "depth": 10,
		"pattern": [
			[0, 1, 0, 0, 0],
			[0, 1, 0, 2, 0],
			[0, 3, 0, 1, 0],
			[0, 3, 0, 1, 0],
			[0, 3, 0, 0, 0],
		],
	},
	{
		"name": "Nomad", "size": 5, "depth": 11,
		"pattern": [
			[0, 0, 0, 0, 0],
			[0, 2, 2, 2, 0],
			[0, 3, 3, 3, 0],
			[0, 1, 1, 0, 0],
			[0, 0, 0, 0, 0],
		],
	},
	{
		"name": "Spindle", "size": 5, "depth": 12,
		"pattern": [
			[1, 0, 0, 0, 2],
			[0, 1, 0, 2, 0],
			[0, 0, 0, 0, 0],
			[0, 3, 0, 4, 0],
			[3, 0, 0, 0, 4],
		],
	},
	{
		"name": "Ascend", "size": 5, "depth": 12,
		"pattern": [
			[0, 0, 0, 0, 0],
			[1, 0, 3, 0, 0],
			[1, 2, 3, 4, 1],
			[1, 0, 0, 0, 1],
			[0, 0, 0, 0, 0],
		],
	},
	{
		"name": "Verge", "size": 5, "depth": 13,
		"pattern": [
			[0, 0, 0, 0, 0],
			[0, 1, 2, 2, 0],
			[0, 3, 4, 4, 0],
			[0, 3, 4, 4, 0],
			[0, 0, 0, 0, 0],
		],
	},
	{
		"name": "Hollow", "size": 5, "depth": 14,
		"pattern": [
			[1, 0, 0, 1, 0],
			[0, 0, 2, 0, 0],
			[0, 3, 3, 0, 3],
			[4, 0, 0, 4, 0],
			[0, 0, 1, 0, 0],
		],
	},
	{
		"name": "Prism", "size": 5, "depth": 14,
		"pattern": [
			[1, 2, 0, 4, 1],
			[0, 0, 0, 0, 2],
			[0, 0, 0, 0, 3],
			[4, 0, 0, 0, 0],
			[1, 0, 0, 4, 0],
		],
	},
	{
		"name": "Lantern", "size": 5, "depth": 15,
		"pattern": [
			[0, 1, 0, 1, 0],
			[0, 2, 0, 2, 0],
			[0, 3, 0, 3, 0],
			[0, 4, 0, 4, 0],
			[0, 0, 0, 1, 0],
		],
	},
	{
		"name": "Kite", "size": 5, "depth": 16,
		"pattern": [
			[0, 0, 0, 0, 0],
			[0, 3, 4, 1, 0],
			[0, 4, 1, 2, 0],
			[0, 1, 2, 3, 0],
			[0, 0, 0, 0, 0],
		],
	},
	{
		"name": "Beacon", "size": 5, "depth": 16,
		"pattern": [
			[1, 0, 0, 0, 2],
			[0, 1, 0, 2, 0],
			[0, 3, 4, 0, 0],
			[0, 3, 0, 4, 0],
			[3, 0, 0, 0, 4],
		],
	},
	{
		"name": "Trellis", "size": 5, "depth": 17,
		"pattern": [
			[0, 0, 0, 0, 0],
			[1, 0, 3, 0, 1],
			[1, 2, 3, 4, 1],
			[1, 0, 3, 0, 0],
			[0, 0, 0, 0, 0],
		],
	},
	{
		"name": "Sable", "size": 5, "depth": 18,
		"pattern": [
			[0, 0, 0, 0, 0],
			[0, 1, 2, 2, 0],
			[3, 3, 4, 4, 0],
			[0, 3, 4, 4, 0],
			[0, 0, 0, 0, 0],
		],
	},
	{
		"name": "Marker", "size": 5, "depth": 18,
		"pattern": [
			[1, 2, 0, 4, 0],
			[0, 0, 3, 0, 0],
			[0, 2, 3, 0, 1],
			[1, 0, 0, 4, 0],
			[0, 0, 3, 0, 0],
		],
	},
	{
		"name": "Cinder", "size": 5, "depth": 19,
		"pattern": [
			[1, 0, 2, 2, 0],
			[1, 0, 0, 0, 2],
			[0, 0, 0, 0, 4],
			[0, 0, 0, 0, 4],
			[3, 0, 4, 0, 4],
		],
	},
	{
		"name": "Lattice", "size": 5, "depth": 19,
		"pattern": [
			[0, 1, 0, 1, 0],
			[0, 2, 0, 2, 0],
			[0, 3, 0, 3, 3],
			[0, 4, 0, 4, 0],
			[0, 5, 0, 5, 0],
		],
	},
	{
		"name": "Vertex", "size": 5, "depth": 20,
		"pattern": [
			[0, 0, 0, 0, 0],
			[1, 2, 3, 4, 0],
			[0, 2, 3, 4, 0],
			[0, 2, 3, 4, 5],
			[0, 0, 0, 0, 0],
		],
	},
	{
		"name": "Quartz", "size": 5, "depth": 21,
		"pattern": [
			[1, 0, 0, 0, 1],
			[0, 2, 0, 2, 0],
			[0, 0, 3, 3, 0],
			[0, 4, 0, 4, 0],
			[5, 5, 0, 0, 5],
		],
	},
	{
		"name": "Halo", "size": 5, "depth": 21,
		"pattern": [
			[0, 0, 0, 0, 0],
			[1, 0, 3, 0, 5],
			[1, 2, 3, 4, 5],
			[1, 0, 3, 0, 5],
			[0, 0, 0, 0, 0],
		],
	},
	{
		"name": "Cadence", "size": 5, "depth": 22,
		"pattern": [
			[0, 0, 0, 0, 0],
			[0, 3, 4, 5, 0],
			[0, 4, 5, 1, 2],
			[0, 5, 1, 2, 0],
			[0, 0, 2, 0, 0],
		],
	},
	{
		"name": "Wingspan", "size": 6, "depth": 23,
		"pattern": [
			[0, 0, 1, 1, 0, 1],
			[0, 2, 2, 0, 2, 0],
			[3, 0, 0, 3, 3, 0],
			[0, 0, 4, 4, 0, 4],
			[0, 5, 5, 0, 5, 0],
			[1, 0, 0, 1, 0, 0],
		],
	},
	{
		"name": "Pinwheel", "size": 6, "depth": 23,
		"pattern": [
			[1, 1, 1, 0, 1, 1],
			[2, 0, 0, 0, 0, 2],
			[3, 0, 0, 0, 0, 3],
			[4, 0, 0, 0, 0, 4],
			[5, 0, 0, 0, 0, 0],
			[0, 1, 1, 1, 1, 1],
		],
	},
	{
		"name": "Meridian", "size": 6, "depth": 24,
		"pattern": [
			[0, 2, 0, 4, 0, 1],
			[0, 3, 0, 5, 0, 2],
			[0, 4, 0, 1, 0, 3],
			[0, 5, 0, 2, 0, 4],
			[0, 1, 0, 3, 0, 5],
			[0, 2, 0, 4, 0, 0],
		],
	},
	{
		"name": "Devotion", "size": 6, "depth": 25,
		"pattern": [
			[0, 0, 0, 0, 0, 0],
			[0, 2, 3, 4, 5, 0],
			[1, 2, 3, 4, 5, 0],
			[0, 2, 3, 4, 5, 0],
			[0, 2, 3, 4, 5, 0],
			[0, 0, 0, 0, 0, 0],
		],
	},
	{
		"name": "Coil", "size": 6, "depth": 25,
		"pattern": [
			[1, 2, 0, 0, 5, 1],
			[0, 2, 0, 0, 5, 0],
			[0, 0, 3, 4, 5, 0],
			[0, 0, 3, 4, 0, 0],
			[1, 2, 0, 4, 5, 0],
			[1, 2, 0, 0, 0, 1],
		],
	},
	{
		"name": "Mosaic", "size": 6, "depth": 26,
		"pattern": [
			[0, 0, 0, 0, 0, 0],
			[1, 0, 0, 4, 0, 1],
			[1, 2, 3, 4, 5, 1],
			[1, 2, 3, 4, 5, 1],
			[1, 0, 3, 0, 0, 1],
			[0, 0, 0, 0, 0, 0],
		],
	},
	{
		"name": "Keystone", "size": 6, "depth": 27,
		"pattern": [
			[0, 0, 0, 1, 0, 0],
			[0, 2, 2, 2, 2, 0],
			[0, 3, 3, 3, 3, 0],
			[0, 4, 4, 4, 4, 0],
			[0, 5, 5, 5, 5, 0],
			[0, 0, 1, 0, 0, 0],
		],
	},
	{
		"name": "Bastion", "size": 6, "depth": 27,
		"pattern": [
			[0, 0, 1, 1, 0, 1],
			[0, 2, 2, 0, 2, 0],
			[3, 0, 0, 3, 3, 0],
			[0, 0, 4, 4, 0, 4],
			[0, 5, 5, 0, 5, 0],
			[1, 1, 0, 1, 1, 0],
		],
	},
	{
		"name": "Cascade", "size": 6, "depth": 28,
		"pattern": [
			[1, 1, 1, 1, 1, 0],
			[2, 0, 0, 0, 0, 2],
			[3, 0, 0, 0, 0, 3],
			[4, 0, 0, 0, 0, 4],
			[5, 0, 0, 0, 0, 5],
			[1, 1, 1, 1, 1, 1],
		],
	},
	{
		"name": "Filament", "size": 6, "depth": 29,
		"pattern": [
			[0, 1, 0, 2, 0, 3],
			[0, 2, 0, 3, 0, 4],
			[0, 2, 0, 3, 0, 4],
			[2, 3, 0, 4, 0, 5],
			[0, 3, 0, 4, 0, 5],
			[0, 4, 0, 5, 0, 1],
		],
	},
	{
		"name": "Harbour", "size": 6, "depth": 30,
		"pattern": [
			[0, 1, 0, 0, 0, 0],
			[0, 2, 2, 2, 2, 0],
			[0, 3, 3, 3, 3, 0],
			[0, 4, 4, 4, 4, 4],
			[5, 5, 5, 5, 5, 0],
			[0, 0, 0, 0, 0, 0],
		],
	},
	{
		"name": "Ingot", "size": 6, "depth": 30,
		"pattern": [
			[1, 0, 0, 0, 0, 1],
			[2, 3, 0, 5, 1, 0],
			[0, 4, 5, 1, 2, 0],
			[0, 5, 1, 2, 3, 0],
			[0, 1, 2, 0, 4, 5],
			[1, 0, 0, 0, 0, 1],
		],
	},
	{
		"name": "Junction", "size": 6, "depth": 31,
		"pattern": [
			[0, 0, 0, 0, 0, 0],
			[1, 0, 3, 4, 0, 1],
			[1, 2, 3, 4, 5, 1],
			[1, 2, 3, 4, 5, 1],
			[1, 0, 3, 4, 0, 1],
			[0, 0, 0, 0, 0, 0],
		],
	},
	{
		"name": "Kestrel", "size": 6, "depth": 32,
		"pattern": [
			[0, 0, 3, 0, 0, 0],
			[0, 3, 4, 5, 1, 0],
			[3, 4, 5, 1, 2, 0],
			[4, 5, 1, 2, 3, 0],
			[0, 1, 2, 3, 4, 0],
			[0, 0, 3, 0, 0, 0],
		],
	},
	{
		"name": "Lodestone", "size": 6, "depth": 32,
		"pattern": [
			[0, 0, 1, 1, 0, 1],
			[0, 2, 2, 0, 2, 0],
			[3, 3, 0, 3, 3, 0],
			[0, 0, 4, 4, 0, 4],
			[0, 5, 5, 0, 5, 0],
			[1, 1, 0, 1, 1, 0],
		],
	},
	{
		"name": "Mantle", "size": 6, "depth": 33,
		"pattern": [
			[1, 2, 3, 4, 5, 1],
			[1, 0, 0, 0, 0, 1],
			[1, 0, 0, 0, 0, 1],
			[1, 0, 0, 0, 0, 1],
			[1, 0, 0, 4, 0, 1],
			[1, 2, 3, 4, 5, 1],
		],
	},
	{
		"name": "Nocturne", "size": 6, "depth": 34,
		"pattern": [
			[0, 1, 0, 1, 0, 1],
			[0, 2, 0, 2, 0, 2],
			[0, 3, 0, 3, 3, 3],
			[0, 4, 4, 4, 4, 4],
			[0, 5, 0, 5, 0, 5],
			[0, 1, 0, 1, 0, 1],
		],
	},
	{
		"name": "Obsidian", "size": 6, "depth": 34,
		"pattern": [
			[1, 0, 0, 1, 0, 0],
			[0, 2, 2, 2, 2, 0],
			[0, 3, 3, 3, 3, 0],
			[0, 4, 4, 4, 4, 0],
			[0, 5, 5, 5, 5, 5],
			[1, 0, 0, 0, 0, 1],
		],
	},
	{
		"name": "Palisade", "size": 6, "depth": 35,
		"pattern": [
			[1, 1, 0, 0, 1, 1],
			[2, 2, 2, 2, 2, 2],
			[0, 0, 3, 3, 0, 0],
			[0, 4, 4, 4, 4, 0],
			[0, 5, 0, 0, 5, 0],
			[1, 1, 0, 0, 1, 1],
		],
	},
	{
		"name": "Quiver", "size": 6, "depth": 36,
		"pattern": [
			[0, 0, 0, 0, 0, 0],
			[1, 0, 3, 4, 0, 1],
			[1, 2, 3, 4, 5, 1],
			[1, 2, 3, 4, 5, 1],
			[1, 2, 3, 4, 5, 1],
			[0, 0, 0, 0, 0, 0],
		],
	},
	{
		"name": "Ridgeline", "size": 6, "depth": 36,
		"pattern": [
			[0, 0, 0, 1, 0, 0],
			[0, 2, 2, 2, 2, 0],
			[0, 3, 3, 3, 3, 3],
			[4, 4, 4, 4, 4, 4],
			[0, 5, 5, 5, 5, 0],
			[0, 0, 1, 1, 0, 0],
		],
	},
	{
		"name": "Compass", "size": 6, "depth": 37,
		"pattern": [
			[1, 0, 1, 1, 0, 1],
			[0, 2, 2, 0, 2, 0],
			[3, 3, 0, 3, 3, 0],
			[0, 0, 4, 4, 0, 4],
			[0, 5, 5, 0, 5, 5],
			[1, 1, 0, 1, 1, 0],
		],
	},
	{
		"name": "Summit", "size": 6, "depth": 38,
		"pattern": [
			[1, 2, 3, 4, 5, 1],
			[2, 3, 0, 0, 0, 2],
			[3, 4, 0, 0, 2, 3],
			[4, 0, 0, 0, 0, 4],
			[5, 0, 0, 0, 0, 5],
			[1, 2, 3, 4, 5, 1],
		],
	},
	{
		"name": "Crosswind", "size": 6, "depth": 39,
		"pattern": [
			[0, 1, 0, 1, 0, 1],
			[0, 2, 0, 2, 0, 2],
			[3, 3, 3, 3, 0, 3],
			[4, 4, 4, 4, 4, 4],
			[0, 5, 0, 5, 0, 5],
			[0, 1, 0, 1, 0, 1],
		],
	},
	{
		"name": "Orbit", "size": 7, "depth": 39,
		"pattern": [
			[0, 0, 3, 0, 0, 1, 0],
			[2, 3, 4, 5, 1, 2, 0],
			[3, 4, 5, 1, 2, 3, 4],
			[0, 5, 1, 2, 3, 4, 0],
			[0, 1, 2, 3, 4, 5, 0],
			[0, 2, 3, 4, 5, 1, 0],
			[0, 0, 4, 0, 0, 2, 0],
		],
	},
	{
		"name": "Serpentine", "size": 7, "depth": 40,
		"pattern": [
			[1, 1, 0, 0, 0, 1, 1],
			[2, 2, 2, 0, 2, 2, 2],
			[0, 3, 3, 3, 3, 3, 0],
			[0, 0, 4, 4, 4, 0, 0],
			[0, 5, 5, 5, 5, 5, 0],
			[1, 1, 1, 0, 1, 1, 1],
			[2, 2, 0, 0, 0, 0, 2],
		],
	},
	{
		"name": "Tessellate", "size": 7, "depth": 41,
		"pattern": [
			[0, 0, 0, 0, 0, 0, 0],
			[1, 2, 0, 4, 5, 1, 2],
			[1, 2, 3, 4, 5, 1, 2],
			[1, 2, 3, 4, 5, 1, 2],
			[1, 2, 3, 4, 5, 1, 2],
			[1, 2, 0, 4, 0, 1, 2],
			[0, 0, 0, 0, 0, 0, 0],
		],
	},
	{
		"name": "Iris", "size": 7, "depth": 41,
		"pattern": [
			[0, 0, 1, 1, 0, 0, 0],
			[0, 2, 2, 2, 2, 2, 0],
			[3, 3, 3, 3, 3, 3, 3],
			[4, 4, 4, 4, 4, 4, 4],
			[5, 5, 5, 5, 5, 5, 0],
			[0, 1, 1, 1, 1, 1, 0],
			[0, 0, 0, 2, 0, 0, 0],
		],
	},
	{
		"name": "Bullseye", "size": 7, "depth": 42,
		"pattern": [
			[0, 2, 3, 4, 5, 1, 0],
			[1, 2, 0, 4, 5, 0, 2],
			[1, 0, 3, 4, 0, 1, 2],
			[0, 2, 3, 0, 5, 1, 0],
			[1, 2, 0, 4, 5, 0, 2],
			[1, 0, 3, 4, 0, 1, 2],
			[0, 2, 3, 0, 5, 1, 0],
		],
	},
	{
		"name": "Gridlock", "size": 7, "depth": 43,
		"pattern": [
			[1, 1, 1, 1, 1, 1, 1],
			[2, 0, 2, 2, 0, 2, 2],
			[3, 0, 0, 0, 0, 0, 3],
			[4, 4, 0, 0, 0, 0, 4],
			[5, 5, 0, 0, 0, 0, 5],
			[1, 1, 1, 0, 1, 1, 1],
			[2, 2, 2, 2, 2, 2, 2],
		],
	},
	{
		"name": "Reliquary", "size": 7, "depth": 43,
		"pattern": [
			[1, 0, 1, 0, 1, 0, 1],
			[2, 0, 2, 0, 2, 0, 2],
			[3, 0, 3, 3, 3, 3, 3],
			[4, 4, 4, 4, 4, 4, 4],
			[5, 5, 5, 0, 5, 0, 5],
			[1, 0, 1, 0, 1, 0, 1],
			[2, 0, 2, 0, 2, 0, 2],
		],
	},
	{
		"name": "Sentinel", "size": 7, "depth": 44,
		"pattern": [
			[0, 1, 0, 0, 3, 0, 4],
			[0, 2, 2, 3, 3, 4, 0],
			[0, 2, 3, 3, 4, 4, 0],
			[2, 3, 3, 4, 4, 5, 0],
			[3, 3, 4, 4, 5, 5, 1],
			[0, 4, 4, 5, 5, 1, 1],
			[0, 4, 0, 0, 1, 0, 0],
		],
	},
	{
		"name": "Tessera", "size": 7, "depth": 45,
		"pattern": [
			[1, 1, 0, 0, 0, 1, 1],
			[2, 2, 2, 0, 2, 2, 2],
			[0, 3, 3, 3, 3, 3, 0],
			[0, 0, 4, 4, 4, 0, 0],
			[5, 5, 5, 5, 5, 5, 0],
			[1, 1, 1, 0, 1, 1, 1],
			[2, 2, 0, 0, 2, 2, 2],
		],
	},
	{
		"name": "Undertow", "size": 7, "depth": 46,
		"pattern": [
			[0, 0, 0, 0, 0, 0, 0],
			[1, 2, 2, 3, 3, 4, 4],
			[2, 2, 3, 3, 4, 4, 5],
			[2, 3, 3, 4, 4, 5, 5],
			[3, 3, 4, 4, 5, 5, 1],
			[3, 4, 4, 5, 5, 1, 1],
			[0, 0, 0, 0, 0, 0, 0],
		],
	},
	{
		"name": "Vanguard", "size": 7, "depth": 46,
		"pattern": [
			[0, 0, 1, 1, 1, 0, 0],
			[0, 2, 2, 2, 2, 2, 0],
			[3, 3, 3, 3, 3, 3, 3],
			[4, 4, 4, 4, 4, 4, 4],
			[0, 5, 5, 5, 5, 5, 5],
			[0, 1, 1, 1, 1, 1, 0],
			[0, 0, 2, 2, 0, 0, 0],
		],
	},
	{
		"name": "Wavefront", "size": 7, "depth": 47,
		"pattern": [
			[0, 2, 3, 4, 5, 1, 0],
			[2, 3, 4, 5, 1, 0, 3],
			[3, 0, 5, 1, 0, 3, 4],
			[0, 5, 1, 2, 3, 4, 0],
			[5, 1, 0, 3, 4, 0, 1],
			[1, 0, 3, 4, 0, 1, 2],
			[0, 3, 4, 5, 1, 2, 0],
		],
	},
	{
		"name": "Xenolith", "size": 7, "depth": 48,
		"pattern": [
			[1, 1, 1, 1, 1, 1, 1],
			[2, 2, 2, 0, 2, 2, 2],
			[3, 3, 0, 0, 0, 3, 3],
			[4, 0, 0, 0, 0, 4, 4],
			[5, 5, 0, 0, 0, 5, 5],
			[1, 1, 0, 1, 1, 0, 1],
			[2, 2, 2, 2, 2, 2, 2],
		],
	},
	{
		"name": "Yardarm", "size": 7, "depth": 48,
		"pattern": [
			[1, 0, 3, 0, 5, 0, 2],
			[1, 0, 3, 0, 5, 0, 2],
			[1, 2, 3, 4, 5, 1, 2],
			[1, 2, 3, 4, 5, 1, 2],
			[1, 0, 3, 4, 5, 1, 2],
			[1, 0, 3, 0, 5, 0, 2],
			[1, 0, 3, 0, 5, 0, 2],
		],
	},
	{
		"name": "Zenith", "size": 7, "depth": 49,
		"pattern": [
			[1, 0, 0, 1, 0, 0, 1],
			[2, 2, 2, 2, 2, 2, 2],
			[0, 3, 3, 3, 3, 3, 0],
			[0, 4, 4, 4, 4, 4, 0],
			[5, 5, 5, 5, 5, 5, 0],
			[1, 1, 1, 1, 1, 1, 1],
			[2, 2, 0, 2, 0, 0, 2],
		],
	},
	{
		"name": "Aperture", "size": 7, "depth": 50,
		"pattern": [
			[1, 2, 3, 0, 0, 1, 2],
			[1, 2, 3, 4, 5, 1, 2],
			[0, 2, 3, 4, 5, 1, 2],
			[0, 2, 3, 4, 5, 0, 0],
			[0, 2, 3, 4, 5, 1, 0],
			[1, 2, 3, 0, 5, 1, 2],
			[1, 2, 0, 0, 0, 1, 2],
		],
	},
	{
		"name": "Bulwark", "size": 7, "depth": 51,
		"pattern": [
			[0, 1, 0, 0, 0, 1, 0],
			[2, 2, 2, 2, 2, 2, 2],
			[3, 3, 3, 3, 3, 3, 3],
			[4, 4, 4, 4, 4, 4, 4],
			[5, 5, 5, 5, 5, 5, 5],
			[1, 1, 1, 1, 1, 1, 1],
			[0, 0, 0, 0, 0, 2, 0],
		],
	},
	{
		"name": "Citadel", "size": 7, "depth": 51,
		"pattern": [
			[0, 0, 1, 1, 1, 0, 0],
			[0, 2, 2, 2, 2, 2, 0],
			[3, 3, 3, 3, 3, 3, 3],
			[4, 4, 4, 4, 4, 4, 4],
			[5, 5, 5, 5, 5, 5, 5],
			[0, 1, 1, 1, 1, 1, 0],
			[0, 0, 2, 2, 2, 2, 0],
		],
	},
	{
		"name": "Draughtsman", "size": 7, "depth": 52,
		"pattern": [
			[0, 1, 2, 2, 3, 3, 0],
			[1, 2, 2, 3, 3, 0, 4],
			[2, 0, 3, 3, 4, 4, 5],
			[0, 3, 3, 4, 4, 5, 0],
			[3, 3, 0, 4, 5, 0, 1],
			[3, 0, 4, 5, 5, 1, 1],
			[0, 4, 5, 5, 1, 1, 0],
		],
	},
	{
		"name": "Equinox", "size": 7, "depth": 53,
		"pattern": [
			[1, 1, 1, 1, 1, 1, 1],
			[2, 2, 2, 2, 2, 2, 2],
			[3, 3, 0, 0, 0, 0, 3],
			[4, 4, 0, 0, 0, 4, 4],
			[5, 5, 0, 0, 0, 5, 5],
			[1, 1, 1, 1, 1, 1, 1],
			[2, 2, 2, 2, 2, 2, 2],
		],
	},
	{
		"name": "Fulcrum", "size": 7, "depth": 53,
		"pattern": [
			[1, 0, 2, 0, 3, 0, 4],
			[1, 2, 2, 0, 3, 0, 4],
			[2, 2, 3, 3, 4, 4, 5],
			[2, 3, 3, 4, 4, 5, 5],
			[3, 3, 4, 4, 5, 5, 1],
			[3, 0, 4, 5, 5, 0, 1],
			[4, 0, 5, 0, 1, 0, 2],
		],
	},
	{
		"name": "Gauntlet", "size": 7, "depth": 54,
		"pattern": [
			[1, 0, 1, 0, 1, 1, 0],
			[2, 2, 2, 2, 2, 2, 2],
			[3, 3, 3, 3, 3, 3, 3],
			[4, 4, 4, 4, 4, 4, 4],
			[0, 5, 5, 5, 5, 5, 0],
			[0, 1, 1, 1, 1, 1, 0],
			[2, 0, 2, 2, 0, 2, 0],
		],
	},
	{
		"name": "Helix", "size": 7, "depth": 55,
		"pattern": [
			[1, 2, 3, 0, 5, 1, 2],
			[2, 3, 4, 0, 1, 2, 3],
			[3, 4, 5, 1, 2, 3, 4],
			[0, 5, 1, 2, 3, 0, 0],
			[0, 1, 2, 3, 4, 5, 1],
			[1, 2, 3, 0, 5, 1, 2],
			[2, 3, 4, 0, 0, 2, 3],
		],
	},
	{
		"name": "Ironclad", "size": 7, "depth": 56,
		"pattern": [
			[0, 1, 0, 1, 0, 1, 0],
			[2, 2, 2, 2, 2, 2, 2],
			[3, 3, 3, 3, 3, 3, 3],
			[4, 4, 4, 4, 4, 4, 4],
			[5, 5, 5, 5, 5, 5, 5],
			[1, 1, 1, 1, 1, 1, 1],
			[0, 2, 0, 2, 0, 0, 0],
		],
	},
	{
		"name": "Jetstream", "size": 8, "depth": 56,
		"pattern": [
			[0, 0, 3, 4, 5, 1, 0, 0],
			[0, 3, 4, 5, 1, 2, 3, 0],
			[3, 4, 5, 1, 2, 3, 4, 5],
			[4, 5, 1, 2, 3, 4, 5, 1],
			[5, 1, 2, 3, 4, 5, 1, 2],
			[1, 2, 3, 4, 5, 1, 2, 3],
			[0, 3, 4, 5, 1, 2, 3, 4],
			[0, 0, 5, 1, 2, 3, 0, 0],
		],
	},
	{
		"name": "Kiln", "size": 8, "depth": 57,
		"pattern": [
			[1, 1, 1, 1, 1, 1, 1, 1],
			[2, 0, 2, 2, 2, 2, 2, 0],
			[0, 3, 3, 3, 3, 3, 0, 3],
			[4, 4, 4, 4, 4, 4, 4, 4],
			[5, 0, 5, 5, 5, 5, 5, 0],
			[0, 1, 1, 1, 1, 1, 0, 1],
			[2, 2, 0, 2, 2, 2, 2, 2],
			[3, 0, 3, 3, 3, 3, 3, 0],
		],
	},
	{
		"name": "Labyrinth", "size": 8, "depth": 58,
		"pattern": [
			[1, 2, 3, 4, 5, 1, 2, 3],
			[1, 2, 3, 4, 5, 1, 2, 3],
			[1, 2, 0, 4, 5, 0, 2, 3],
			[1, 2, 0, 0, 0, 0, 2, 3],
			[1, 2, 3, 0, 0, 1, 2, 3],
			[1, 2, 3, 0, 0, 1, 2, 3],
			[1, 2, 3, 4, 5, 1, 2, 3],
			[1, 2, 3, 4, 5, 1, 2, 3],
		],
	},
	{
		"name": "Monolith", "size": 8, "depth": 58,
		"pattern": [
			[5, 0, 4, 0, 4, 0, 5, 0],
			[5, 0, 3, 3, 3, 3, 4, 5],
			[4, 3, 3, 2, 2, 3, 3, 4],
			[4, 3, 2, 1, 1, 2, 3, 4],
			[4, 3, 2, 1, 1, 2, 3, 4],
			[4, 3, 3, 2, 2, 3, 3, 4],
			[5, 4, 3, 0, 3, 3, 4, 5],
			[5, 0, 4, 0, 4, 0, 5, 0],
		],
	},
	{
		"name": "Nebula", "size": 8, "depth": 59,
		"pattern": [
			[0, 1, 1, 0, 1, 0, 1, 1],
			[0, 2, 2, 2, 2, 2, 2, 2],
			[3, 3, 3, 3, 3, 3, 3, 3],
			[4, 4, 4, 4, 4, 4, 4, 0],
			[5, 5, 5, 5, 5, 5, 5, 0],
			[1, 1, 1, 1, 1, 1, 1, 1],
			[0, 2, 2, 2, 2, 2, 2, 2],
			[3, 3, 3, 0, 3, 3, 0, 3],
		],
	},
	{
		"name": "Outpost", "size": 8, "depth": 60,
		"pattern": [
			[5, 5, 4, 0, 0, 4, 5, 5],
			[5, 4, 3, 3, 3, 3, 4, 5],
			[4, 3, 3, 2, 2, 3, 3, 4],
			[0, 3, 2, 1, 1, 2, 3, 0],
			[0, 3, 2, 1, 1, 2, 3, 0],
			[4, 3, 3, 2, 2, 3, 3, 0],
			[5, 4, 3, 3, 3, 3, 4, 5],
			[5, 5, 4, 0, 0, 4, 5, 5],
		],
	},
	{
		"name": "Paragon", "size": 8, "depth": 61,
		"pattern": [
			[0, 1, 0, 1, 1, 0, 1, 0],
			[2, 2, 2, 2, 2, 2, 2, 2],
			[3, 3, 3, 3, 3, 3, 3, 3],
			[4, 4, 4, 4, 4, 4, 4, 4],
			[5, 5, 5, 5, 5, 5, 5, 5],
			[1, 1, 1, 1, 1, 1, 1, 1],
			[2, 2, 2, 2, 2, 2, 2, 2],
			[0, 3, 0, 3, 3, 0, 3, 0],
		],
	},
	{
		"name": "Quorum", "size": 8, "depth": 61,
		"pattern": [
			[0, 0, 2, 2, 3, 3, 4, 0],
			[0, 2, 2, 3, 3, 4, 4, 0],
			[2, 2, 3, 3, 4, 4, 5, 5],
			[2, 3, 3, 4, 4, 5, 5, 1],
			[3, 3, 4, 4, 5, 5, 1, 1],
			[3, 4, 4, 5, 5, 1, 1, 2],
			[4, 4, 5, 5, 1, 1, 2, 0],
			[0, 5, 5, 1, 1, 2, 2, 0],
		],
	},
	{
		"name": "Rampart", "size": 8, "depth": 62,
		"pattern": [
			[1, 1, 1, 1, 1, 1, 1, 1],
			[2, 0, 2, 2, 2, 2, 2, 0],
			[0, 3, 3, 3, 3, 3, 3, 3],
			[4, 4, 4, 4, 4, 4, 4, 4],
			[5, 5, 5, 5, 5, 5, 5, 0],
			[0, 1, 1, 1, 1, 1, 1, 1],
			[2, 2, 2, 2, 2, 2, 2, 2],
			[3, 0, 3, 3, 3, 3, 3, 0],
		],
	},
	{
		"name": "Stronghold", "size": 8, "depth": 63,
		"pattern": [
			[1, 2, 3, 4, 5, 1, 2, 3],
			[2, 3, 4, 5, 1, 2, 3, 4],
			[3, 4, 5, 1, 2, 3, 4, 5],
			[4, 5, 1, 0, 0, 4, 5, 1],
			[5, 1, 0, 0, 0, 0, 1, 2],
			[1, 2, 3, 4, 5, 0, 2, 3],
			[2, 3, 4, 5, 1, 2, 3, 4],
			[3, 4, 5, 1, 2, 3, 4, 5],
		],
	},
	{
		"name": "Threshold", "size": 8, "depth": 63,
		"pattern": [
			[1, 0, 1, 0, 1, 0, 1, 1],
			[2, 2, 2, 2, 2, 2, 2, 2],
			[3, 3, 3, 3, 3, 3, 3, 3],
			[4, 4, 4, 4, 4, 4, 4, 4],
			[5, 5, 5, 5, 5, 5, 5, 5],
			[1, 1, 1, 1, 1, 1, 1, 1],
			[2, 2, 2, 2, 2, 2, 2, 2],
			[3, 0, 3, 0, 3, 3, 3, 0],
		],
	},
	{
		"name": "Umbra", "size": 8, "depth": 64,
		"pattern": [
			[1, 2, 0, 4, 5, 1, 2, 0],
			[2, 3, 4, 5, 1, 2, 3, 4],
			[0, 4, 5, 1, 2, 3, 4, 5],
			[4, 5, 1, 2, 3, 4, 5, 1],
			[5, 1, 2, 3, 4, 5, 1, 2],
			[1, 2, 3, 4, 5, 1, 2, 0],
			[2, 3, 4, 5, 1, 2, 3, 4],
			[0, 4, 5, 1, 2, 0, 4, 5],
		],
	},
	{
		"name": "Vortex", "size": 8, "depth": 65,
		"pattern": [
			[1, 1, 1, 1, 0, 1, 1, 1],
			[2, 2, 2, 2, 2, 2, 2, 2],
			[3, 3, 3, 3, 3, 3, 3, 3],
			[0, 4, 4, 4, 4, 4, 4, 0],
			[5, 5, 5, 5, 5, 5, 5, 0],
			[1, 1, 1, 1, 1, 1, 1, 1],
			[2, 2, 2, 2, 2, 2, 2, 2],
			[3, 3, 3, 0, 3, 3, 3, 3],
		],
	},
	{
		"name": "Watchtower", "size": 8, "depth": 66,
		"pattern": [
			[1, 2, 0, 4, 5, 1, 2, 0],
			[1, 2, 3, 4, 5, 1, 2, 3],
			[1, 2, 3, 4, 5, 1, 2, 3],
			[1, 2, 3, 4, 5, 1, 2, 3],
			[1, 2, 3, 4, 5, 1, 2, 3],
			[1, 2, 3, 4, 5, 1, 2, 3],
			[1, 2, 3, 4, 5, 1, 2, 3],
			[1, 2, 0, 4, 5, 0, 2, 0],
		],
	},
	{
		"name": "Xerography", "size": 8, "depth": 66,
		"pattern": [
			[0, 5, 4, 4, 4, 4, 5, 0],
			[5, 4, 3, 3, 3, 3, 4, 5],
			[4, 3, 3, 2, 2, 3, 3, 4],
			[4, 3, 2, 1, 1, 2, 3, 4],
			[4, 3, 2, 1, 1, 2, 3, 4],
			[4, 3, 3, 2, 2, 3, 3, 4],
			[5, 4, 3, 3, 3, 3, 4, 5],
			[0, 5, 4, 4, 4, 4, 5, 0],
		],
	},
	{
		"name": "Yoke", "size": 8, "depth": 67,
		"pattern": [
			[1, 2, 3, 4, 5, 1, 2, 3],
			[1, 2, 3, 4, 5, 1, 2, 0],
			[1, 2, 3, 4, 5, 1, 2, 3],
			[1, 2, 3, 4, 5, 1, 2, 3],
			[1, 2, 3, 4, 5, 1, 2, 0],
			[0, 2, 3, 4, 5, 1, 2, 3],
			[1, 2, 3, 4, 5, 1, 2, 3],
			[1, 2, 3, 4, 5, 1, 2, 0],
		],
	},
	{
		"name": "Zephyr", "size": 8, "depth": 68,
		"pattern": [
			[5, 5, 4, 4, 4, 4, 5, 5],
			[5, 4, 3, 3, 3, 3, 4, 5],
			[4, 3, 3, 2, 2, 3, 3, 4],
			[4, 3, 2, 1, 0, 2, 3, 4],
			[4, 3, 2, 0, 0, 2, 3, 4],
			[4, 3, 3, 2, 2, 3, 3, 4],
			[5, 4, 3, 3, 3, 3, 4, 5],
			[5, 5, 4, 4, 4, 4, 5, 5],
		],
	},
	{
		"name": "Terminus", "size": 8, "depth": 69,
		"pattern": [
			[1, 1, 1, 1, 1, 0, 1, 0],
			[2, 2, 2, 2, 2, 2, 2, 2],
			[3, 3, 3, 3, 3, 3, 3, 3],
			[4, 4, 4, 4, 4, 4, 4, 4],
			[5, 5, 5, 5, 5, 5, 5, 5],
			[1, 1, 1, 1, 1, 1, 1, 1],
			[2, 2, 2, 2, 2, 2, 2, 2],
			[3, 3, 3, 3, 3, 0, 3, 3],
		],
	},
	{
		"name": "Event Horizon", "size": 8, "depth": 69,
		"pattern": [
			[1, 1, 2, 2, 3, 3, 4, 4],
			[1, 2, 2, 3, 3, 4, 4, 5],
			[2, 2, 3, 3, 4, 4, 5, 5],
			[2, 3, 3, 4, 4, 5, 5, 1],
			[0, 3, 4, 4, 5, 5, 1, 1],
			[3, 4, 4, 5, 5, 1, 1, 2],
			[4, 4, 5, 5, 1, 1, 2, 2],
			[4, 5, 5, 1, 1, 2, 2, 0],
		],
	},
	{
		"name": "Singularity", "size": 8, "depth": 70,
		"pattern": [
			[1, 1, 1, 0, 1, 1, 1, 1],
			[2, 2, 2, 2, 2, 2, 2, 2],
			[3, 3, 3, 3, 3, 3, 3, 3],
			[4, 4, 4, 4, 4, 4, 4, 4],
			[5, 5, 5, 5, 5, 5, 5, 5],
			[1, 1, 1, 1, 1, 1, 1, 1],
			[2, 2, 2, 2, 2, 2, 2, 2],
			[3, 3, 3, 3, 3, 3, 3, 3],
		],
	},
]


static func count() -> int:
	return LEVELS.size()


static func get_level(index: int) -> Dictionary:
	return LEVELS[clampi(index, 0, LEVELS.size() - 1)]


## A bonus board arrives already solved and comes apart on screen. It is a
## breather between difficulty bands, so it is exempt from par scoring.
static func is_bonus(index: int) -> bool:
	return bool(get_level(index).get("bonus", false))


## Planet textures are off. They never held up at the size a ball actually is:
## a 512px texture that looks like Jupiter reads at 54px as a bullseye, and the
## fixes traded one artefact for the next — bleached poles, then a white cap,
## then bands that vanished under the board lighting. Plain spheres are clean at
## every size and keep the slot colour unambiguous, which is the only thing the
## puzzle is matched on. The generator and textures stay in the repo; set this
## to a level index to bring them back.
const PLANETS_FROM := -1


static func uses_planets(index: int) -> bool:
	return PLANETS_FROM >= 0 and index >= PLANETS_FROM


static func par(index: int) -> int:
	return int(get_level(index)["depth"])


## Deterministic start layout for a level: the solved pattern walked backwards
## by `depth` legal moves. Returns a fresh [y][x] grid.
static func generate_start(index: int) -> Array:
	return generate(index)["state"]


## As `generate_start`, but also returns the shuffle moves that produced it.
## Replaying them in reverse solves the level — which is what makes par honest,
## and what the level-integrity test checks.
##
## Returns {state: Array, moves: Array[{ball: Vector2i, hole: Vector2i}]}.
static func generate(index: int) -> Dictionary:
	var level := get_level(index)
	var size: int = level["size"]
	var depth: int = level["depth"]
	var state := copy_grid(level["pattern"])

	# Fixed, explicitly-derived seed: every player on every device gets exactly
	# the same starting layout for a given level, and it survives restarts and
	# reinstalls. Deliberately arithmetic rather than hash("...") so it cannot
	# drift if the engine ever changes String.hash().
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED_BASE + SEED_STRIDE * (index + 1)

	# Never revisit a state we've already produced — including the solved one,
	# so the player can never be handed an already-finished board, and each
	# shuffle step buys real distance instead of undoing the previous one.
	var visited := {key(state): true}
	var log: Array = []
	var attempts := 0
	var attempt_budget := depth * 80

	while log.size() < depth and attempts < attempt_budget:
		attempts += 1

		var empties := _empty_cells(state, size)
		if empties.is_empty():
			break

		var hole: Vector2i = empties[rng.randi_range(0, empties.size() - 1)]
		var ball: Vector2i = hole + DIRS[rng.randi_range(0, DIRS.size() - 1)]
		if ball.x < 0 or ball.x >= size or ball.y < 0 or ball.y >= size:
			continue
		if state[ball.y][ball.x] == 0:
			continue

		state[hole.y][hole.x] = state[ball.y][ball.x]
		state[ball.y][ball.x] = 0

		var k := key(state)
		if visited.has(k):
			state[ball.y][ball.x] = state[hole.y][hole.x]
			state[hole.y][hole.x] = 0
			continue

		visited[k] = true
		log.append({"ball": ball, "hole": hole})

	return {"state": state, "moves": log}


static func copy_grid(grid: Array) -> Array:
	var out: Array = []
	for row in grid:
		out.append((row as Array).duplicate())
	return out


static func grids_equal(a: Array, b: Array) -> bool:
	if a.size() != b.size():
		return false
	for y in a.size():
		if a[y] != b[y]:
			return false
	return true


static func key(grid: Array) -> String:
	var parts := PackedStringArray()
	for row in grid:
		for v in row:
			parts.append(str(v))
	return "".join(parts)


static func _empty_cells(state: Array, size: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for y in size:
		for x in size:
			if state[y][x] == 0:
				out.append(Vector2i(x, y))
	return out
