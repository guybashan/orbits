class_name Board
extends Node3D

## The 3D play field. Owns the sockets (the grid) and the balls sitting in it.
##
## Sockets are tinted with the colour the goal pattern wants in that cell, so
## the player can read the objective straight off the board instead of
## eyeballing it against a second grid. The puzzle is the sliding, not the
## memorising.

signal move_finished

const SPACING := 1.1
const BALL_Y := 0.30
const MOVE_TIME := 0.13

const BALL_SCENE := preload("res://scenes/ball.tscn")

var grid_size := 7

var _sockets: Dictionary = {}      # Vector2i -> MeshInstance3D
var _socket_mats: Dictionary = {}  # Vector2i -> StandardMaterial3D
var _balls: Dictionary = {}        # Vector2i -> Ball
var _goal: Array = []              # [y][x] goal colours
var _ball_tweens: Dictionary = {}  # ball instance id -> Tween

var _socket_mesh: TorusMesh
var _flash_mesh: TorusMesh


func _init() -> void:
	_socket_mesh = TorusMesh.new()
	_socket_mesh.inner_radius = 0.34
	_socket_mesh.outer_radius = 0.46
	_socket_mesh.rings = 24
	_socket_mesh.ring_segments = 12

	_flash_mesh = TorusMesh.new()
	_flash_mesh.inner_radius = 0.40
	_flash_mesh.outer_radius = 0.52
	_flash_mesh.rings = 24
	_flash_mesh.ring_segments = 8


# ---------------------------------------------------------------- geometry --

func _origin_offset() -> float:
	return (grid_size - 1) * SPACING * 0.5


func cell_to_world(cell: Vector2i) -> Vector3:
	var off := _origin_offset()
	return Vector3(cell.x * SPACING - off, 0.0, cell.y * SPACING - off)


func cell_to_ball_pos(cell: Vector2i) -> Vector3:
	var p := cell_to_world(cell)
	p.y = BALL_Y
	return p


## Nearest cell to a point on the board plane, or (-1,-1) if the point falls
## outside the grid (plus a forgiving margin for fat fingers).
func world_to_cell(world_pos: Vector3) -> Vector2i:
	var local := to_local(world_pos)
	var off := _origin_offset()
	var fx := (local.x + off) / SPACING
	var fz := (local.z + off) / SPACING
	var x := int(round(fx))
	var y := int(round(fz))
	if x < 0 or x >= grid_size or y < 0 or y >= grid_size:
		return Vector2i(-1, -1)
	if absf(fx - x) > 0.62 or absf(fz - y) > 0.62:
		return Vector2i(-1, -1)
	return Vector2i(x, y)


func in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.x < grid_size and cell.y >= 0 and cell.y < grid_size


# ------------------------------------------------------------------- build --

func build(size: int, goal: Array) -> void:
	grid_size = size
	_goal = goal
	_clear_all()

	for y in size:
		for x in size:
			var cell := Vector2i(x, y)
			var socket := MeshInstance3D.new()
			socket.mesh = _socket_mesh
			socket.position = cell_to_world(cell)

			var mat := StandardMaterial3D.new()
			mat.metallic = 0.4
			mat.roughness = 0.45
			mat.emission_enabled = true
			socket.material_override = mat

			add_child(socket)
			_sockets[cell] = socket
			_socket_mats[cell] = mat
			_paint_socket(cell, false)


func _paint_socket(cell: Vector2i, satisfied: bool) -> void:
	var mat: StandardMaterial3D = _socket_mats.get(cell)
	if mat == null:
		return

	var goal_color: int = _goal[cell.y][cell.x]
	if goal_color == 0:
		# Cell should end up empty: keep it cool and recessive.
		mat.albedo_color = Color(0.10, 0.13, 0.20)
		mat.emission = Color(0.20, 0.35, 0.60)
		mat.emission_energy_multiplier = 0.10
	else:
		# The ring is the loud half of the "this ball is home" signal — the
		# ball itself only brightens a little, so its colour stays readable.
		var tint := Ball.color_for(goal_color)
		mat.albedo_color = tint.darkened(0.55)
		mat.emission = tint
		mat.emission_energy_multiplier = 2.2 if satisfied else 0.45


## Populate the board from a [y][x] state grid.
func load_state(state: Array, animate: bool = true) -> void:
	_clear_balls()
	for y in grid_size:
		for x in grid_size:
			var color_type: int = state[y][x]
			if color_type == 0:
				continue
			var cell := Vector2i(x, y)
			var ball: Ball = BALL_SCENE.instantiate()
			add_child(ball)
			ball.position = cell_to_ball_pos(cell)
			ball.color_type = color_type
			_balls[cell] = ball
			if animate:
				# Spawn on a diagonal sweep so the board assembles itself.
				ball.spawn_in(0.012 * (x + y) + 0.02)
	refresh_correct(false)


func _clear_balls() -> void:
	for ball in _balls.values():
		ball.queue_free()
	_balls.clear()
	_ball_tweens.clear()


func _clear_all() -> void:
	_clear_balls()
	for socket in _sockets.values():
		socket.queue_free()
	_sockets.clear()
	_socket_mats.clear()


# ------------------------------------------------------------------- state --

func ball_at(cell: Vector2i) -> Ball:
	return _balls.get(cell)


func is_empty(cell: Vector2i) -> bool:
	return in_bounds(cell) and not _balls.has(cell)


func get_state() -> Array:
	var state: Array = []
	for y in grid_size:
		var row: Array = []
		for x in grid_size:
			var ball: Ball = _balls.get(Vector2i(x, y))
			row.append(ball.color_type if ball else 0)
		state.append(row)
	return state


func correct_count() -> int:
	var n := 0
	for cell in _balls:
		if _balls[cell].is_correct():
			n += 1
	return n


func goal_ball_count() -> int:
	var n := 0
	for row in _goal:
		for v in row:
			if v != 0:
				n += 1
	return n


# ------------------------------------------------------------------- moves --

## Slide the ball at `from` into the empty cell at `to`. Board state updates
## immediately; only the visuals are tweened, so rapid input can never desync.
func move(from: Vector2i, to: Vector2i) -> void:
	if not _balls.has(from) or _balls.has(to):
		return

	var ball: Ball = _balls[from]
	_balls.erase(from)
	_balls[to] = ball

	_kill_tween(ball)
	var tween := create_tween()
	_ball_tweens[ball.get_instance_id()] = tween
	tween.set_parallel(true)

	var target := cell_to_ball_pos(to)
	tween.tween_property(ball, "position:x", target.x, MOVE_TIME) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(ball, "position:z", target.z, MOVE_TIME) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	# A small hop sells the slide as physical rather than a teleport.
	tween.tween_property(ball, "position:y", BALL_Y + 0.16, MOVE_TIME * 0.45) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.chain().tween_property(ball, "position:y", BALL_Y, MOVE_TIME * 0.55) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(func() -> void: move_finished.emit())


## Nudge a ball that cannot go where the player asked.
func bump(cell: Vector2i, direction: Vector2i) -> void:
	var ball: Ball = _balls.get(cell)
	if ball == null:
		return

	var home := cell_to_ball_pos(cell)
	var nudge := Vector3(direction.x, 0, direction.y) * (SPACING * 0.18)

	_kill_tween(ball)
	var tween := create_tween()
	_ball_tweens[ball.get_instance_id()] = tween
	tween.tween_property(ball, "position", home + nudge, 0.06) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(ball, "position", home, 0.22) \
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


func lift(cell: Vector2i, lifted: bool) -> void:
	var ball: Ball = _balls.get(cell)
	if ball == null:
		return
	var target := Vector3.ONE * (1.14 if lifted else 1.0)
	var tween := create_tween()
	tween.tween_property(ball, "scale", target, 0.10) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _kill_tween(ball: Ball) -> void:
	var id := ball.get_instance_id()
	var tween: Tween = _ball_tweens.get(id)
	if tween and tween.is_valid():
		tween.kill()
	_ball_tweens.erase(id)


# -------------------------------------------------------------- correctness --

## Re-evaluate which balls sit on their goal cell. Returns the cells that
## newly became correct, so the caller can fire sound and effects for them.
func refresh_correct(animate: bool = true) -> Array[Vector2i]:
	var newly: Array[Vector2i] = []
	for y in grid_size:
		for x in grid_size:
			var cell := Vector2i(x, y)
			var goal_color: int = _goal[y][x]
			var ball: Ball = _balls.get(cell)
			var correct := ball != null and goal_color != 0 and ball.color_type == goal_color
			if ball != null:
				var was: bool = ball.is_correct()
				ball.set_correct(correct, animate)
				if correct and not was:
					newly.append(cell)
			_paint_socket(cell, correct)
	return newly


func flash(cell: Vector2i, color: Color) -> void:
	var ring := MeshInstance3D.new()
	ring.mesh = _flash_mesh
	ring.position = cell_to_world(cell) + Vector3(0, 0.05, 0)

	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 3.0
	ring.material_override = mat
	add_child(ring)

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(ring, "scale", Vector3(2.4, 1.0, 2.4), 0.42) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(mat, "albedo_color:a", 0.0, 0.42) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.chain().tween_callback(ring.queue_free)


## Win flourish: every ball bobs in a wave radiating from the board centre.
func celebrate() -> void:
	var centre := Vector2(grid_size - 1, grid_size - 1) * 0.5
	for cell in _balls:
		var ball: Ball = _balls[cell]
		var ball_color: int = ball.color_type
		var delay := Vector2(cell).distance_to(centre) * 0.055
		var home := cell_to_ball_pos(cell)

		_kill_tween(ball)
		var tween := create_tween()
		_ball_tweens[ball.get_instance_id()] = tween

		# Settle into the exact cell first. The winning move is still mid-flight
		# when the win fires, and killing its tween would otherwise strand that
		# ball short of its socket for the whole celebration.
		tween.tween_property(ball, "position", home, MOVE_TIME) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

		tween.tween_interval(delay)
		tween.tween_property(ball, "position:y", BALL_Y + 0.55, 0.20) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(ball, "position:y", BALL_Y, 0.55) \
			.set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
		tween.parallel().tween_callback(func() -> void: flash(cell, Ball.color_for(ball_color)))
