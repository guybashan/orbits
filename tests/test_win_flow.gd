extends SceneTree

## End-to-end check of the play screen: boot it, solve the level by replaying
## the shuffle backwards, and confirm the win flow fires and scores correctly.
##   godot --script tests/test_win_flow.gd --resolution 720x1280 -- [level] [out.png]

var level_index := 0
var out_path := ""
var failures: Array[String] = []


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() >= 1:
		level_index = int(args[0])
	if args.size() >= 2:
		out_path = args[1]
	_run.call_deferred()


func _run() -> void:
	var data := root.get_node_or_null("/root/GameData")
	if data == null:
		print("FAIL: GameData autoload missing")
		quit(1)
		return
	data.persist_enabled = false  # never touch the player's real save
	data.last_level = level_index

	change_scene_to_file("res://scenes/main.tscn")
	for i in 10:
		await process_frame

	var main := current_scene
	var solution: Array = Levels.generate(level_index)["moves"]

	if main.moves != 0:
		failures.append("move counter did not start at zero")
	if main.solved:
		failures.append("level reported solved before any move")

	# Replay the shuffle backwards — each step puts one ball back.
	for i in range(solution.size() - 1, -1, -1):
		var step: Dictionary = solution[i]
		main._do_move(step["hole"], step["ball"])
		await process_frame

	if not main.solved:
		failures.append("board matched the goal but the win never fired")

	var par: int = Levels.par(level_index)
	if main.moves != solution.size():
		failures.append("counted %d moves, expected %d" % [main.moves, solution.size()])
	if main.moves > par:
		failures.append("solution took %d moves, above par %d" % [main.moves, par])

	# Let the win sequence play out. This has to wait on wall-clock time, not
	# a frame count — the window runs uncapped here, so frames are no guide.
	await create_timer(3.0).timeout

	# Every ball must be sitting exactly on its socket once the celebration has
	# played out. The winning move is still animating when the win fires, so a
	# celebration that clobbers that tween leaves the last ball visibly short.
	for y in main.board.grid_size:
		for x in main.board.grid_size:
			var cell := Vector2i(x, y)
			var ball = main.board.ball_at(cell)
			if ball == null:
				continue
			var home: Vector3 = main.board.cell_to_ball_pos(cell)
			var drift: float = ball.position.distance_to(home)
			if drift > 0.02:
				failures.append("ball at %s settled %.3f units off its socket" % [str(cell), drift])

	if not main.win_panel.visible:
		failures.append("win panel never appeared")
	if main.win_stars.earned != 3:
		failures.append("solving in par awarded %d stars, expected 3" % main.win_stars.earned)
	if data.stars_for(level_index) != 3:
		failures.append("3 stars were not persisted to the save file")
	if data.best_for(level_index) != main.moves:
		failures.append("best move count was not persisted")

	# --- scoring ------------------------------------------------------------
	var expected: int = Score.for_level(main.moves, par, main.elapsed)
	if data.score_for(level_index) != expected:
		failures.append("score %d persisted, expected %d" % [data.score_for(level_index), expected])
	if expected <= 0:
		failures.append("a par clear scored %d points" % expected)
	if expected > Score.best_possible(par):
		failures.append("score %d exceeds the level maximum %d" % [expected, Score.best_possible(par)])
	if main.elapsed <= 0.0:
		failures.append("the clock never ran")
	if data.time_for(level_index) != main.elapsed:
		failures.append("best time was not persisted")

	if out_path != "":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(out_path)
		print("screenshot -> ", out_path)

	if failures.is_empty():
		print("PASS — level %d solved in %d moves (par %d), 3 stars awarded" % [
			level_index + 1, main.moves, par
		])
		quit(0)
	else:
		for failure in failures:
			print("FAIL: ", failure)
		quit(1)
