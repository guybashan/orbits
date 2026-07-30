extends SceneTree

## Level-bank integrity check. Run with:
##   godot --headless --script tests/test_levels.gd
##
## Guards the property the whole game rests on: every level must be solvable,
## and solvable within its advertised par.

const GameDataScript = preload("res://scripts/game_data.gd")

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
