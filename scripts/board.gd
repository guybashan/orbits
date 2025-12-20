extends Node3D

const GRID_SIZE = 7
const SPACING = 1.1

var holes: Dictionary = {} # Vector2i -> Hole Node
var balls: Dictionary = {} # Vector2i -> Ball Node

var ball_scene = preload("res://scenes/ball.tscn")
var hole_scene = preload("res://scenes/hole.tscn")

var sfx_move: AudioStreamPlayer
var sfx_bounce: AudioStreamPlayer

var is_muted: bool = false

func _ready() -> void:
	_setup_audio()
	_create_grid()

func _setup_audio() -> void:
	sfx_move = AudioStreamPlayer.new()
	sfx_move.stream = load("res://sounds/move.wav")
	add_child(sfx_move)
	
	sfx_bounce = AudioStreamPlayer.new()
	sfx_bounce.stream = load("res://sounds/bounce.wav")
	add_child(sfx_bounce)

func _create_grid() -> void:
	for x in range(GRID_SIZE):
		for y in range(GRID_SIZE):
			var pos = Vector3(x * SPACING, 0, y * SPACING)
			var hole = hole_scene.instantiate()
			add_child(hole)
			hole.position = pos
			holes[Vector2i(x, y)] = hole

func clear_balls() -> void:
	for ball in balls.values():
		ball.queue_free()
	balls.clear()

func place_ball(grid_pos: Vector2i, color_type: int) -> void:
	if balls.has(grid_pos):
		return # Occupied
	
	var ball = ball_scene.instantiate()
	add_child(ball)
	# Ball sits slightly above the hole
	ball.position = Vector3(grid_pos.x * SPACING, 0.5, grid_pos.y * SPACING)
	ball.color_type = color_type
	balls[grid_pos] = ball

func get_ball_at(grid_pos: Vector2i) -> Node:
	return balls.get(grid_pos)

func move_ball(from: Vector2i, to: Vector2i) -> void:
	if not balls.has(from) or balls.has(to):
		return
	
	var ball = balls[from]
	balls.erase(from)
	balls[to] = ball
	
	# Tween movement
	var tween = create_tween()
	var target_pos = Vector3(to.x * SPACING, 0.5, to.y * SPACING)
	tween.tween_property(ball, "position", target_pos, 0.2)
	
	if sfx_move and not is_muted:
		sfx_move.play()

func animate_bounce(grid_pos: Vector2i, direction: Vector2i) -> void:
	if not balls.has(grid_pos):
		return
	
	var ball = balls[grid_pos]
	var original_pos = ball.position
	var bounce_vec = Vector3(direction.x, 0, direction.y) * (SPACING * 0.4)
	
	# Create a complex tween for position and scale (squash & stretch)
	var tween = create_tween()
	tween.set_parallel(true)
	
	# Position: Move out and back
	tween.tween_property(ball, "position", original_pos + bounce_vec, 0.1).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.chain().tween_property(ball, "position", original_pos, 0.2).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	
	# Scale: Squash when hitting "wall", traverse to stretch
	var squash = Vector3(1.2, 0.8, 1.2) # Flatten
	if direction.x != 0: squash = Vector3(0.8, 1.2, 1.2) # Adjust based on axis if needed, but uniform squash is fine for this simple abstract style
	
	# Simple wobble
	var original_scale = Vector3.ONE
	var wobble_scale = Vector3(1.2, 0.8, 1.2) 
	
	tween.tween_property(ball, "scale", wobble_scale, 0.1).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.chain().tween_property(ball, "scale", original_scale, 0.3).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	
	if sfx_bounce and not is_muted:
		sfx_bounce.play()

func get_state() -> Array:
	var state = []
	for x in range(GRID_SIZE):
		var col = []
		for y in range(GRID_SIZE):
			if balls.has(Vector2i(x, y)):
				col.append(balls[Vector2i(x, y)].color_type)
			else:
				col.append(0) # NONE
		state.append(col)
	return state
