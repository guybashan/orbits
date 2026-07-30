extends SceneTree

## Level-bank integrity check. Run with:
##   godot --headless --script tests/test_levels.gd
##
## Guards the property the whole game rests on: every level must be solvable,
## and solvable within its advertised par.

const GameDataScript = preload("res://scripts/game_data.gd")

## Every player must get byte-identical starting layouts, so the generator is
## seeded from the level index alone. These are the layouts as shipped: if a
## change to Levels reshuffles a board, this list fails loudly rather than
## silently handing existing players a different puzzle.
const GOLDEN_LAYOUTS: Array[String] = [
	"0000010100010100",
	"0000012000002001",
	"0030000300000330",
	"0400004000000404",
	"1000002400300000",
	"0111000101011010",
	"2202202222000000",
	"3003030300033000",
	"0001001001011000110000101",
	"2002002200002000220000020",
	"0004444004000040040004004",
	"1111100020032022003230033",
	"3000030033003333000300000",
	"1100210202102443030030344",
	"5055505550055500555055550",
	"0101012321100020020111000",
	"202000002020002202020220002000002000",
	"002300101003012030120030102000122033",
	"404004040404444440040044404004400044",
	"112000101000200000010044030000030444",
	"500550000000050000055000000005500005",
	"011111011001101111111101101010001000",
	"003033330333333000303000303033300303",
	"101202223001101002123302012210201310",
	"0200220022000002040202002020000022022200200000000",
	"3000400030440004043300044040340443000340000004300",
	"0044004004200000004004420244422202040400440400404",
	"4010000100140040400410044010401400004104404000100",
	"3000300003333031401303301130311013303010033303003",
	"2022020000222002202202220200202202000022000200220",
	"4000442240200042440040242004004202040000440004402",
	"0111210020232110333210235021113032002232211011110",
	"4144144401101440010140412014000101441111414444404",
	"1212121220120201120210220012220212012122221212121",
	"3433434024212331111240412153411110434021234233434",
]

var failures: Array[String] = []


func _init() -> void:
	for index in Levels.count():
		_check_level(index)

	print("")
	if failures.is_empty():
		print("PASS — %d levels verified" % Levels.count())
		quit(0)
	else:
		for failure in failures:
			print("FAIL: ", failure)
		print("%d failure(s)" % failures.size())
		quit(1)


func _fail(index: int, message: String) -> void:
	failures.append("level %d (%s): %s" % [index + 1, Levels.get_level(index)["name"], message])


func _check_level(index: int) -> void:
	var level := Levels.get_level(index)
	var size: int = level["size"]
	var pattern: Array = level["pattern"]
	var par: int = level["depth"]

	# --- the pattern itself must be well formed -----------------------------
	if pattern.size() != size:
		_fail(index, "pattern has %d rows, expected %d" % [pattern.size(), size])
		return
	for row in pattern:
		if (row as Array).size() != size:
			_fail(index, "a pattern row has %d cells, expected %d" % [row.size(), size])
			return
	for row in pattern:
		for value in row:
			if value < 0 or value > 5:
				_fail(index, "colour %s is outside 0..5" % str(value))
				return

	var empties := 0
	for row in pattern:
		for value in row:
			if value == 0:
				empties += 1
	if empties == 0:
		_fail(index, "pattern has no empty cell, so nothing can ever move")
		return

	# --- generation ---------------------------------------------------------
	var generated := Levels.generate(index)
	var state: Array = generated["state"]
	var moves: Array = generated["moves"]

	if moves.size() < par:
		_fail(index, "shuffle stalled at %d of %d moves" % [moves.size(), par])
		return

	if Levels.grids_equal(state, pattern):
		_fail(index, "start state is already solved")
		return

	if Levels.key(state) != GOLDEN_LAYOUTS[index]:
		_fail(index, "layout changed — every existing player would get a different board")
		return

	# Generating twice must give the same board: no time, device or session
	# state may leak into level generation.
	if Levels.key(Levels.generate_start(index)) != Levels.key(state):
		_fail(index, "generation is not deterministic across calls")
		return

	if _histogram(state) != _histogram(pattern):
		_fail(index, "start state has a different set of balls than the goal")
		return

	# --- the start state must be reachable back to the goal -----------------
	# Replaying the shuffle backwards is the solution; if every step of it is
	# legal and it lands on the pattern, par is a real, achievable move count.
	var board := Levels.copy_grid(state)
	for i in range(moves.size() - 1, -1, -1):
		var ball: Vector2i = moves[i]["ball"]
		var hole: Vector2i = moves[i]["hole"]
		if board[hole.y][hole.x] == 0:
			_fail(index, "replay step %d expected a ball at %s" % [i, str(hole)])
			return
		if board[ball.y][ball.x] != 0:
			_fail(index, "replay step %d expected %s to be empty" % [i, str(ball)])
			return
		board[ball.y][ball.x] = board[hole.y][hole.x]
		board[hole.y][hole.x] = 0

	if not Levels.grids_equal(board, pattern):
		_fail(index, "replaying the shuffle backwards did not reach the goal")
		return

	# --- scoring sanity -----------------------------------------------------
	if GameDataScript.stars_for_moves(par, par) != 3:
		_fail(index, "solving in par does not award 3 stars")

	print("  ok  level %2d  %-16s %dx%d  par %2d  %d balls" % [
		index + 1, level["name"], size, size, par, _ball_count(pattern)
	])


func _histogram(grid: Array) -> Dictionary:
	var counts := {}
	for row in grid:
		for value in row:
			counts[value] = int(counts.get(value, 0)) + 1
	return counts


func _ball_count(grid: Array) -> int:
	var total := 0
	for row in grid:
		for value in row:
			if value != 0:
				total += 1
	return total
