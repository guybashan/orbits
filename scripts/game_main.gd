extends Node3D

## Play screen. Owns input, the move/undo history, scoring and the win flow.

const DRAG_THRESHOLD := 34.0       # px before a press counts as a swipe
const CAMERA_PITCH_DEG := 61.0
const CAMERA_DISTANCE := 34.0
const BOARD_SCREEN_HEIGHT := 0.52  # fraction of the screen the board fills
const BOARD_SCREEN_CENTRE := 0.555 # where the board's centre sits vertically

const DIRS: Array[Vector2i] = [
	Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)
]

@onready var board: Board = $Board
@onready var camera: Camera3D = $Camera3D

@onready var dim: ColorRect = $UI/Dim
@onready var top_margin: MarginContainer = $UI/Top
@onready var level_label: Label = $UI/Top/Row/Centre/LevelLabel
@onready var name_label: Label = $UI/Top/Row/Centre/NameLabel
@onready var goal_view: GoalView = $UI/Top/Row/Goal
@onready var moves_label: Label = $UI/Stats/Row/MovesLabel
@onready var placed_label: Label = $UI/Stats/Row/PlacedLabel
@onready var undo_button: Button = $UI/Bottom/Row/UndoButton
@onready var toast: Label = $UI/Toast

@onready var win_panel: PanelContainer = $UI/WinPanel
@onready var win_title: Label = $UI/WinPanel/VBox/TitleLabel
@onready var win_stars: StarRow = $UI/WinPanel/VBox/Stars
@onready var win_stats: Label = $UI/WinPanel/VBox/StatsLabel
@onready var next_button: Button = $UI/WinPanel/VBox/Buttons/NextButton

var level_index := 0
var level: Dictionary = {}
var par := 0

var moves := 0
var history: Array = []            # [{from, to}] — for undo
var solved := false
var input_locked := false

var _selected := Vector2i(-1, -1)
var _press_cell := Vector2i(-1, -1)
var _press_screen := Vector2.ZERO
var _toast_tween: Tween


func _ready() -> void:
	level_index = clampi(GameData.last_level, 0, Levels.count() - 1)
	Audio.update_music()
	_apply_safe_area()
	get_viewport().size_changed.connect(_frame_camera)
	_start_level()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_on_menu_pressed()


# ------------------------------------------------------------------ setup --

func _start_level(animate: bool = true) -> void:
	level = Levels.get_level(level_index)
	par = Levels.par(level_index)

	GameData.last_level = level_index
	GameData.save_data()

	moves = 0
	history.clear()
	solved = false
	input_locked = false
	_selected = Vector2i(-1, -1)
	_press_cell = Vector2i(-1, -1)

	board.build(level["size"], level["pattern"])
	board.load_state(Levels.generate_start(level_index), animate)

	level_label.text = "LEVEL %d" % (level_index + 1)
	name_label.text = str(level["name"]).to_upper()
	goal_view.pattern = level["pattern"]
	goal_view.solved_cells = {}

	win_panel.visible = false
	dim.visible = false
	toast.visible = false

	_frame_camera()
	_refresh_hud()
	_maybe_onboard()


## Fit the board to whatever viewport we actually got, and seat it low on the
## screen so the HUD never sits on top of the puzzle.
func _frame_camera() -> void:
	var pitch := deg_to_rad(CAMERA_PITCH_DEG)
	# Cell centres span (n-1) gaps; the extra covers the outer balls' radius
	# plus a little breathing room at the edges.
	var span: float = (board.grid_size - 1) * Board.SPACING + 1.3

	var viewport_size := get_viewport().get_visible_rect().size
	var aspect: float = viewport_size.x / maxf(viewport_size.y, 1.0)

	# Vertical ortho extent needed to fit the board's width, and the extent
	# needed to keep its foreshortened depth within its screen budget.
	var for_width := span / maxf(aspect, 0.01)
	var for_depth := (span * sin(pitch)) / BOARD_SCREEN_HEIGHT
	camera.size = maxf(for_width, for_depth)

	camera.position = Vector3(0.0, sin(pitch), cos(pitch)) * CAMERA_DISTANCE
	camera.rotation = Vector3(-pitch, 0.0, 0.0)
	# Slide the camera "up" the screen so the board settles below centre.
	camera.position += camera.transform.basis.y * (camera.size * (BOARD_SCREEN_CENTRE - 0.5))


func _apply_safe_area() -> void:
	var safe := DisplayServer.get_display_safe_area()
	var screen := DisplayServer.window_get_size()
	if screen.y <= 0 or safe.size.y >= screen.y:
		return
	# Convert the device-pixel inset into our stretched viewport's units.
	var scale := get_viewport().get_visible_rect().size.y / float(screen.y)
	var inset := int(safe.position.y * scale)
	top_margin.add_theme_constant_override("margin_top", 20 + inset)


# ------------------------------------------------------------------ input --

func _unhandled_input(event: InputEvent) -> void:
	if input_locked or solved:
		return

	if event is InputEventScreenTouch:
		if event.pressed:
			_press(event.position)
		else:
			_release(event.position)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_press(event.position)
		else:
			_release(event.position)


func _press(screen_pos: Vector2) -> void:
	var cell := _cell_at(screen_pos)
	if cell == Vector2i(-1, -1):
		_deselect()
		return

	if board.ball_at(cell) != null:
		_press_cell = cell
		_press_screen = screen_pos
		board.lift(cell, true)
		return

	# Tapped an empty socket: if a ball is selected next to it, that's a move.
	if _selected != Vector2i(-1, -1) and _is_adjacent(_selected, cell):
		var from := _selected
		_deselect()
		_do_move(from, cell)
	else:
		_deselect()


func _release(screen_pos: Vector2) -> void:
	if _press_cell == Vector2i(-1, -1):
		return

	var cell := _press_cell
	_press_cell = Vector2i(-1, -1)
	if cell != _selected:
		board.lift(cell, false)

	var drag := screen_pos - _press_screen
	if drag.length() >= DRAG_THRESHOLD:
		_deselect()
		_swipe(cell, drag)
		return

	# A tap. One free neighbour is unambiguous, so just go; otherwise select
	# the ball and let the next tap pick the destination.
	if _selected == cell:
		_deselect()
		return

	var free := _free_neighbours(cell)
	if free.size() == 1:
		_deselect()
		_do_move(cell, free[0])
	elif free.is_empty():
		board.bump(cell, Vector2i(0, -1))
		Audio.play("bounce", 0.06)
	else:
		_select(cell)


func _swipe(cell: Vector2i, drag: Vector2) -> void:
	# The camera is pitched but never yawed, so screen axes map straight onto
	# grid axes: right is +x, down the screen is +y.
	var direction := Vector2i.RIGHT if drag.x > 0 else Vector2i.LEFT
	if absf(drag.y) > absf(drag.x):
		direction = Vector2i.DOWN if drag.y > 0 else Vector2i.UP
	_do_move(cell, cell + direction)


func _cell_at(screen_pos: Vector2) -> Vector2i:
	var origin := camera.project_ray_origin(screen_pos)
	var direction := camera.project_ray_normal(screen_pos)
	var plane := Plane(Vector3.UP, board.global_position.y)
	var hit = plane.intersects_ray(origin, direction)
	if hit == null:
		return Vector2i(-1, -1)
	return board.world_to_cell(hit)


func _select(cell: Vector2i) -> void:
	if _selected != Vector2i(-1, -1):
		board.lift(_selected, false)
	_selected = cell
	board.lift(cell, true)
	Audio.play("ui")


func _deselect() -> void:
	if _selected != Vector2i(-1, -1):
		board.lift(_selected, false)
	_selected = Vector2i(-1, -1)


func _is_adjacent(a: Vector2i, b: Vector2i) -> bool:
	var d := a - b
	return absi(d.x) + absi(d.y) == 1


func _free_neighbours(cell: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for direction in DIRS:
		var neighbour := cell + direction
		if board.is_empty(neighbour):
			out.append(neighbour)
	return out


# ------------------------------------------------------------------ moves --

func _do_move(from: Vector2i, to: Vector2i, record: bool = true) -> void:
	if board.ball_at(from) == null:
		return

	if not board.in_bounds(to) or not board.is_empty(to):
		board.bump(from, to - from)
		Audio.play("bounce", 0.06)
		Audio.haptic(12)
		return

	board.move(from, to)
	if record:
		history.append({"from": from, "to": to})
		moves += 1

	Audio.play("move", 0.09)
	Audio.haptic(10)
	_after_board_change()


func _on_undo_pressed() -> void:
	if solved or history.is_empty():
		return
	var last: Dictionary = history.pop_back()
	moves = maxi(0, moves - 1)
	_deselect()
	board.move(last["to"], last["from"])
	Audio.play("ui")
	_after_board_change(false)


func _after_board_change(celebrate_locks: bool = true) -> void:
	var newly := board.refresh_correct()
	if celebrate_locks and not newly.is_empty():
		for cell in newly:
			var ball := board.ball_at(cell)
			if ball:
				board.flash(cell, Ball.color_for(ball.color_type))
		Audio.play("lock", 0.04)

	_refresh_hud()
	_check_win()


func _refresh_hud() -> void:
	moves_label.text = "%d moves  ·  par %d" % [moves, par]
	placed_label.text = "%d / %d in place" % [board.correct_count(), board.goal_ball_count()]
	undo_button.disabled = history.is_empty() or solved

	var solved_cells := {}
	for y in board.grid_size:
		for x in board.grid_size:
			var cell := Vector2i(x, y)
			var ball := board.ball_at(cell)
			if ball and ball.is_correct():
				solved_cells[cell] = true
	goal_view.solved_cells = solved_cells


# -------------------------------------------------------------------- win --

func _check_win() -> void:
	if solved:
		return
	if not Levels.grids_equal(board.get_state(), level["pattern"]):
		return

	solved = true
	input_locked = true
	_deselect()
	_refresh_hud()  # re-run now that `solved` is set, so UNDO greys out

	var earned := GameData.stars_for_moves(moves, par)
	var previous_best := GameData.best_for(level_index)
	GameData.record_result(level_index, moves, earned)

	board.celebrate()
	Audio.play("win")
	Audio.haptic(40)

	await get_tree().create_timer(0.85).timeout
	if not is_inside_tree():
		return

	win_title.text = "SOLVED"
	win_stars.earned = 0
	win_stats.text = "%d moves   ·   par %d" % [moves, par]
	if previous_best > 0:
		win_stats.text += "\nbest %d" % mini(previous_best, moves)

	next_button.disabled = false
	next_button.text = "NEXT" if level_index + 1 < Levels.count() else "FINISH"

	dim.visible = true
	dim.modulate.a = 0.0
	win_panel.visible = true
	win_panel.pivot_offset = win_panel.size * 0.5
	win_panel.scale = Vector2(0.85, 0.85)

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(dim, "modulate:a", 1.0, 0.2)
	tween.tween_property(win_panel, "scale", Vector2.ONE, 0.35) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	await get_tree().create_timer(0.3).timeout
	if not is_inside_tree():
		return
	Audio.play_star_run(earned)
	for i in earned:
		win_stars.earned = i + 1
		await get_tree().create_timer(0.18).timeout
		if not is_inside_tree():
			return


# ------------------------------------------------------------------- hint --

func _on_hint_pressed() -> void:
	if solved:
		return
	Audio.play("ui")

	var hint := _find_hint()
	if hint.is_empty():
		_show_toast("No obvious move — free up a socket first")
		return

	var from: Vector2i = hint[0]
	var to: Vector2i = hint[1]
	var ball := board.ball_at(from)
	board.flash(from, Color(1, 1, 1, 0.9))
	board.flash(to, Ball.color_for(ball.color_type) if ball else Color.WHITE)
	_show_toast("Slide the highlighted ball")


## Greedy one-ply hint. Not a solver — it just avoids the two obvious traps
## (undoing a ball that is already home, and moving one further from where it
## is needed).
func _find_hint() -> Array:
	var state := board.get_state()
	var goal: Array = level["pattern"]
	var best: Array = []
	var best_score := -INF

	for y in board.grid_size:
		for x in board.grid_size:
			if state[y][x] != 0:
				continue
			var hole := Vector2i(x, y)
			for direction in DIRS:
				var from := hole + direction
				if not board.in_bounds(from):
					continue
				var color: int = state[from.y][from.x]
				if color == 0:
					continue

				var score := 0.0
				if goal[from.y][from.x] == color:
					score -= 100.0  # already home, leave it alone
				if goal[hole.y][hole.x] == color:
					score += 100.0  # lands it home
				else:
					var before := _distance_to_need(state, goal, color, from)
					var after := _distance_to_need(state, goal, color, hole)
					score += (before - after) * 5.0

				if score > best_score:
					best_score = score
					best = [from, hole]

	if best_score <= 0.0:
		return []
	return best


func _distance_to_need(state: Array, goal: Array, color: int, from: Vector2i) -> float:
	var best := 99.0
	for y in board.grid_size:
		for x in board.grid_size:
			if goal[y][x] != color:
				continue
			if state[y][x] == color:
				continue  # some ball already satisfies this cell
			best = minf(best, absi(x - from.x) + absi(y - from.y))
	return best


func _show_toast(message: String, hold: float = 1.6) -> void:
	toast.text = message
	toast.modulate.a = 0.0
	toast.visible = true
	if _toast_tween and _toast_tween.is_valid():
		_toast_tween.kill()
	_toast_tween = create_tween()
	_toast_tween.tween_property(toast, "modulate:a", 1.0, 0.15)
	_toast_tween.tween_interval(hold)
	_toast_tween.tween_property(toast, "modulate:a", 0.0, 0.35)


## First-run coaching, in place of a tutorial screen. Only ever shown to a
## player who has not yet cleared level 1.
func _maybe_onboard() -> void:
	if level_index != 0 or GameData.stars_for(0) > 0:
		return
	_show_toast("Slide each ball onto a ring of its own colour", 3.4)
	await get_tree().create_timer(4.2).timeout
	if is_inside_tree() and not solved and moves == 0:
		_show_toast("Tap a ball beside an empty ring to move it", 3.4)


# ---------------------------------------------------------------- buttons --

func _on_restart_pressed() -> void:
	Audio.play("ui")
	_start_level()


func _on_menu_pressed() -> void:
	Audio.play("ui")
	get_tree().change_scene_to_file("res://scenes/level_select.tscn")


func _on_next_pressed() -> void:
	Audio.play("ui")
	if level_index + 1 >= Levels.count():
		get_tree().change_scene_to_file("res://scenes/level_select.tscn")
		return
	level_index += 1
	_start_level()


func _on_replay_pressed() -> void:
	Audio.play("ui")
	_start_level()


func _on_levels_pressed() -> void:
	Audio.play("ui")
	get_tree().change_scene_to_file("res://scenes/level_select.tscn")
