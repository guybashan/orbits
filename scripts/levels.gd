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

const LEVELS: Array = [
	# ---------------------------------------------------------------- 4x4 --
	{
		"name": "First Light", "size": 4, "depth": 3,
		"pattern": [
			[0, 0, 0, 0],
			[0, 1, 1, 0],
			[0, 1, 1, 0],
			[0, 0, 0, 0],
		],
	},
	{
		"name": "Pair Up", "size": 4, "depth": 4,
		"pattern": [
			[0, 0, 0, 0],
			[0, 1, 2, 0],
			[0, 2, 1, 0],
			[0, 0, 0, 0],
		],
	},
	{
		"name": "Four Corners", "size": 4, "depth": 5,
		"pattern": [
			[3, 0, 0, 3],
			[0, 0, 0, 0],
			[0, 0, 0, 0],
			[3, 0, 0, 3],
		],
	},
	{
		"name": "The Bar", "size": 4, "depth": 6,
		"pattern": [
			[0, 0, 0, 0],
			[4, 4, 4, 4],
			[0, 0, 0, 0],
			[0, 0, 0, 0],
		],
	},
	{
		"name": "Descent", "size": 4, "depth": 7,
		"pattern": [
			[1, 0, 0, 0],
			[0, 2, 0, 0],
			[0, 0, 3, 0],
			[0, 0, 0, 4],
		],
	},
	{
		"name": "Checker", "size": 4, "depth": 8,
		"pattern": [
			[1, 0, 1, 0],
			[0, 1, 0, 1],
			[1, 0, 1, 0],
			[0, 1, 0, 1],
		],
	},
	{
		"name": "Half Frame", "size": 4, "depth": 9,
		"pattern": [
			[2, 2, 2, 2],
			[2, 0, 0, 2],
			[2, 0, 0, 2],
			[0, 0, 0, 0],
		],
	},
	{
		"name": "Twin Towers", "size": 4, "depth": 10,
		"pattern": [
			[3, 0, 0, 3],
			[3, 0, 0, 3],
			[3, 0, 0, 3],
			[0, 0, 0, 0],
		],
	},
	# ---------------------------------------------------------------- 5x5 --
	{
		"name": "Neon Plus", "size": 5, "depth": 10,
		"pattern": [
			[0, 0, 1, 0, 0],
			[0, 0, 1, 0, 0],
			[1, 1, 1, 1, 1],
			[0, 0, 1, 0, 0],
			[0, 0, 1, 0, 0],
		],
	},
	{
		"name": "Small Ring", "size": 5, "depth": 12,
		"pattern": [
			[0, 0, 0, 0, 0],
			[0, 2, 2, 2, 0],
			[0, 2, 0, 2, 0],
			[0, 2, 2, 2, 0],
			[0, 0, 0, 0, 0],
		],
	},
	{
		"name": "Crossfire", "size": 5, "depth": 13,
		"pattern": [
			[4, 0, 0, 0, 4],
			[0, 4, 0, 4, 0],
			[0, 0, 4, 0, 0],
			[0, 4, 0, 4, 0],
			[4, 0, 0, 0, 4],
		],
	},
	{
		"name": "Spectrum", "size": 5, "depth": 14,
		"pattern": [
			[1, 1, 1, 1, 1],
			[0, 0, 0, 0, 0],
			[2, 2, 2, 2, 2],
			[0, 0, 0, 0, 0],
			[3, 3, 3, 3, 3],
		],
	},
	{
		"name": "Ascend", "size": 5, "depth": 15,
		"pattern": [
			[0, 0, 3, 0, 0],
			[0, 3, 3, 3, 0],
			[3, 0, 3, 0, 3],
			[0, 0, 3, 0, 0],
			[0, 0, 3, 0, 0],
		],
	},
	{
		"name": "Quadrants", "size": 5, "depth": 16,
		"pattern": [
			[1, 1, 0, 2, 2],
			[1, 1, 0, 2, 2],
			[0, 0, 0, 0, 0],
			[3, 3, 0, 4, 4],
			[3, 3, 0, 4, 4],
		],
	},
	{
		"name": "Hourglass", "size": 5, "depth": 17,
		"pattern": [
			[5, 5, 5, 5, 5],
			[0, 5, 5, 5, 0],
			[0, 0, 5, 0, 0],
			[0, 5, 5, 5, 0],
			[5, 5, 5, 5, 5],
		],
	},
	{
		"name": "Prism", "size": 5, "depth": 18,
		"pattern": [
			[0, 0, 1, 0, 0],
			[0, 1, 2, 1, 0],
			[1, 2, 3, 2, 1],
			[0, 1, 2, 1, 0],
			[0, 0, 1, 0, 0],
		],
	},
	# ---------------------------------------------------------------- 6x6 --
	{
		"name": "Halo", "size": 6, "depth": 18,
		"pattern": [
			[0, 0, 0, 0, 0, 0],
			[0, 2, 2, 2, 2, 0],
			[0, 2, 0, 0, 2, 0],
			[0, 2, 0, 0, 2, 0],
			[0, 2, 2, 2, 2, 0],
			[0, 0, 0, 0, 0, 0],
		],
	},
	{
		"name": "Barcode", "size": 6, "depth": 20,
		"pattern": [
			[1, 0, 2, 0, 3, 0],
			[1, 0, 2, 0, 3, 0],
			[1, 0, 2, 0, 3, 0],
			[1, 0, 2, 0, 3, 0],
			[1, 0, 2, 0, 3, 0],
			[1, 0, 2, 0, 3, 0],
		],
	},
	{
		"name": "Wingspan", "size": 6, "depth": 21,
		"pattern": [
			[4, 0, 0, 0, 0, 4],
			[4, 4, 0, 0, 4, 4],
			[0, 4, 4, 4, 4, 0],
			[0, 4, 4, 4, 4, 0],
			[4, 4, 0, 0, 4, 4],
			[4, 0, 0, 0, 0, 4],
		],
	},
	{
		"name": "Pinwheel", "size": 6, "depth": 22,
		"pattern": [
			[1, 1, 1, 0, 0, 0],
			[1, 0, 0, 2, 0, 0],
			[1, 0, 0, 2, 0, 0],
			[0, 0, 3, 0, 0, 4],
			[0, 0, 3, 0, 0, 4],
			[0, 0, 0, 4, 4, 4],
		],
	},
	{
		"name": "Lattice", "size": 6, "depth": 23,
		"pattern": [
			[5, 0, 5, 0, 5, 0],
			[0, 0, 0, 0, 0, 0],
			[5, 0, 5, 0, 5, 0],
			[0, 0, 0, 0, 0, 0],
			[5, 0, 5, 0, 5, 0],
			[0, 0, 0, 0, 0, 0],
		],
	},
	{
		"name": "Devotion", "size": 6, "depth": 24,
		"pattern": [
			[0, 1, 1, 0, 1, 1],
			[1, 1, 1, 1, 1, 1],
			[1, 1, 1, 1, 1, 1],
			[0, 1, 1, 1, 1, 0],
			[0, 0, 1, 1, 0, 0],
			[0, 0, 0, 0, 0, 0],
		],
	},
	{
		"name": "Azure Coil", "size": 6, "depth": 26,
		"pattern": [
			[3, 3, 3, 3, 3, 3],
			[0, 0, 0, 0, 0, 3],
			[3, 3, 3, 3, 0, 3],
			[3, 0, 0, 0, 0, 3],
			[3, 0, 3, 3, 3, 3],
			[3, 0, 0, 0, 0, 0],
		],
	},
	{
		"name": "Mosaic", "size": 6, "depth": 28,
		"pattern": [
			[1, 2, 1, 2, 1, 2],
			[2, 0, 0, 0, 0, 1],
			[1, 0, 3, 3, 0, 2],
			[2, 0, 3, 3, 0, 1],
			[1, 0, 0, 0, 0, 2],
			[2, 1, 2, 1, 2, 1],
		],
	},
	# ---------------------------------------------------------------- 7x7 --
	{
		"name": "Wide Ring", "size": 7, "depth": 26,
		"pattern": [
			[0, 0, 0, 0, 0, 0, 0],
			[0, 2, 2, 2, 2, 2, 0],
			[0, 2, 0, 0, 0, 2, 0],
			[0, 2, 0, 4, 0, 2, 0],
			[0, 2, 0, 0, 0, 2, 0],
			[0, 2, 2, 2, 2, 2, 0],
			[0, 0, 0, 0, 0, 0, 0],
		],
	},
	{
		"name": "Compass", "size": 7, "depth": 28,
		"pattern": [
			[0, 0, 0, 4, 0, 0, 0],
			[0, 0, 3, 4, 3, 0, 0],
			[0, 3, 0, 4, 0, 3, 0],
			[4, 4, 4, 4, 4, 4, 4],
			[0, 3, 0, 4, 0, 3, 0],
			[0, 0, 3, 4, 3, 0, 0],
			[0, 0, 0, 4, 0, 0, 0],
		],
	},
	{
		"name": "Golden Peak", "size": 7, "depth": 30,
		"pattern": [
			[0, 0, 0, 4, 0, 0, 0],
			[0, 0, 4, 4, 4, 0, 0],
			[0, 0, 4, 2, 4, 0, 0],
			[0, 4, 2, 2, 2, 4, 0],
			[0, 4, 2, 2, 2, 4, 0],
			[4, 4, 4, 4, 4, 4, 4],
			[0, 0, 0, 0, 0, 0, 0],
		],
	},
	{
		"name": "The Cross", "size": 7, "depth": 31,
		"pattern": [
			[4, 0, 0, 0, 0, 0, 4],
			[0, 4, 1, 0, 1, 4, 0],
			[0, 1, 4, 0, 4, 1, 0],
			[0, 0, 0, 4, 0, 0, 0],
			[0, 1, 4, 0, 4, 1, 0],
			[0, 4, 1, 0, 1, 4, 0],
			[4, 0, 0, 0, 0, 0, 4],
		],
	},
	{
		"name": "Orbit Rings", "size": 7, "depth": 33,
		"pattern": [
			[0, 3, 3, 3, 3, 3, 0],
			[3, 0, 0, 0, 0, 0, 3],
			[3, 0, 1, 1, 1, 0, 3],
			[3, 0, 1, 4, 1, 0, 3],
			[3, 0, 1, 1, 1, 0, 3],
			[3, 0, 0, 0, 0, 0, 3],
			[0, 3, 3, 3, 3, 3, 0],
		],
	},
	{
		"name": "Emerald Snake", "size": 7, "depth": 35,
		"pattern": [
			[2, 2, 2, 2, 2, 2, 0],
			[0, 0, 0, 0, 0, 2, 0],
			[0, 2, 2, 2, 2, 2, 0],
			[0, 2, 0, 0, 0, 0, 0],
			[0, 2, 2, 2, 2, 2, 0],
			[0, 0, 0, 0, 0, 2, 0],
			[0, 2, 2, 2, 2, 2, 0],
		],
	},
	{
		"name": "The Checkers", "size": 7, "depth": 37,
		"pattern": [
			[4, 0, 4, 0, 4, 0, 4],
			[0, 2, 0, 2, 0, 2, 0],
			[4, 0, 4, 0, 4, 0, 4],
			[0, 2, 0, 2, 0, 2, 0],
			[4, 0, 4, 0, 4, 0, 4],
			[0, 2, 0, 2, 0, 2, 0],
			[4, 0, 4, 0, 4, 0, 4],
		],
	},
	{
		"name": "Crystal Eye", "size": 7, "depth": 40,
		"pattern": [
			[0, 0, 1, 1, 1, 0, 0],
			[0, 1, 2, 2, 2, 1, 0],
			[1, 2, 3, 3, 3, 2, 1],
			[1, 2, 3, 5, 3, 2, 1],
			[1, 2, 3, 3, 3, 2, 1],
			[0, 1, 2, 2, 2, 1, 0],
			[0, 0, 1, 1, 1, 0, 0],
		],
	},
	{
		"name": "Bullseye", "size": 7, "depth": 42,
		"pattern": [
			[0, 4, 4, 4, 4, 4, 0],
			[4, 1, 1, 1, 1, 1, 4],
			[4, 1, 0, 0, 0, 1, 4],
			[4, 1, 0, 2, 0, 1, 4],
			[4, 1, 0, 0, 0, 1, 4],
			[4, 1, 1, 1, 1, 1, 4],
			[0, 4, 4, 4, 4, 4, 0],
		],
	},
	{
		"name": "Gridlock", "size": 7, "depth": 45,
		"pattern": [
			[1, 2, 1, 2, 1, 2, 1],
			[2, 0, 2, 0, 2, 0, 2],
			[1, 2, 1, 2, 1, 2, 1],
			[2, 0, 2, 0, 2, 0, 2],
			[1, 2, 1, 2, 1, 2, 1],
			[2, 0, 2, 0, 2, 0, 2],
			[1, 2, 1, 2, 1, 2, 1],
		],
	},
	{
		"name": "The Singularity", "size": 7, "depth": 50,
		"pattern": [
			[4, 3, 4, 3, 4, 3, 4],
			[3, 2, 1, 2, 1, 2, 3],
			[4, 1, 0, 1, 0, 1, 4],
			[3, 2, 1, 5, 1, 2, 3],
			[4, 1, 0, 1, 0, 1, 4],
			[3, 2, 1, 2, 1, 2, 3],
			[4, 3, 4, 3, 4, 3, 4],
		],
	},
]


static func count() -> int:
	return LEVELS.size()


static func get_level(index: int) -> Dictionary:
	return LEVELS[clampi(index, 0, LEVELS.size() - 1)]


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

	var rng := RandomNumberGenerator.new()
	rng.seed = hash("orbits.v2.level.%d" % index)

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
