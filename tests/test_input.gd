extends SceneTree

## Drives the play screen through real input events rather than calling the
## move functions directly — this is the path a player actually takes, and a
## broken screen-to-cell projection would make the game unplayable.
##   godot --script tests/test_input.gd --resolution 720x1280

var failures: Array[String] = []


func _init() -> void:
	_run.call_deferred()


func _screen_pos(main, cell: Vector2i) -> Vector2:
	return main.camera.unproject_position(main.board.cell_to_ball_pos(cell))


func _click(position: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.position = position
	event.global_position = position
	Input.parse_input_event(event)


func _tap(position: Vector2) -> void:
	_click(position, true)
	_click(position, false)


func _find_move(main) -> Array:
	## A ball with exactly one free neighbour — an unambiguous tap target.
	for y in main.board.grid_size:
		for x in main.board.grid_size:
			var cell := Vector2i(x, y)
			if main.board.ball_at(cell) == null:
				continue
			var free: Array = main._free_neighbours(cell)
			if free.size() == 1:
				return [cell, free[0]]
	return []


func _run() -> void:
	var data := root.get_node_or_null("/root/GameData")
	data.last_level = 8  # a 5x5 board: plenty of room to move
	change_scene_to_file("res://scenes/main.tscn")
	for i in 10:
		await process_frame

	var main := current_scene

	# --- tap ---------------------------------------------------------------
	var pair := _find_move(main)
	if pair.is_empty():
		failures.append("no unambiguous tap target on the starting board")
	else:
		var from: Vector2i = pair[0]
		var to: Vector2i = pair[1]
		var colour: int = main.board.ball_at(from).color_type

		_tap(_screen_pos(main, from))
		for i in 4:
			await process_frame

		if main.board.ball_at(from) != null:
			failures.append("tap left the ball at its origin %s" % str(from))
		elif main.board.ball_at(to) == null:
			failures.append("tap did not land the ball on %s" % str(to))
		elif main.board.ball_at(to).color_type != colour:
			failures.append("the wrong ball moved")
		if main.moves != 1:
			failures.append("tap recorded %d moves, expected 1" % main.moves)

	# --- swipe -------------------------------------------------------------
	var before: int = main.moves
	var swiped := false
	for y in main.board.grid_size:
		for x in main.board.grid_size:
			if swiped:
				continue
			var cell := Vector2i(x, y)
			if main.board.ball_at(cell) == null:
				continue
			for direction in [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP]:
				if swiped or not main.board.is_empty(cell + direction):
					continue
				var start := _screen_pos(main, cell)
				var finish := _screen_pos(main, cell + direction)
				_click(start, true)
				_click(finish, false)
				swiped = true
				for i in 4:
					await process_frame
				if main.board.ball_at(cell + direction) == null:
					failures.append("swipe %s did not move the ball" % str(direction))
				if main.moves != before + 1:
					failures.append("swipe recorded %d moves, expected %d" % [main.moves, before + 1])

	if not swiped:
		failures.append("found no ball to swipe")

	# --- undo --------------------------------------------------------------
	var undo_from: int = main.moves
	main._on_undo_pressed()
	for i in 4:
		await process_frame
	if main.moves != undo_from - 1:
		failures.append("undo did not decrement the move counter")

	# --- a tap on empty space must not move anything ------------------------
	var quiet: int = main.moves
	_tap(Vector2(360, 1275))
	for i in 4:
		await process_frame
	if main.moves != quiet:
		failures.append("a tap off the board changed the move count")

	if failures.is_empty():
		print("PASS — tap, swipe, undo and off-board taps all behave")
		quit(0)
	else:
		for failure in failures:
			print("FAIL: ", failure)
		quit(1)
