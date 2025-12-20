extends Node3D

@onready var play_board: Node3D = $PlayBoard
@onready var target_board: Node3D = $TargetBoard
@onready var camera: Camera3D = $Camera3D
@onready var win_label: Label = $CanvasLayer/WinLabel
@onready var steps_label: Label = $CanvasLayer/TopStats/StepsLabel
@onready var settings_panel: PanelContainer = $CanvasLayer/SettingsPanel
@onready var level_label: Label = $CanvasLayer/TopStats/LevelLabel
@onready var next_level_panel: PanelContainer = $CanvasLayer/NextLevelPanel
@onready var overlay_dim: ColorRect = $CanvasLayer/OverlayDim

var selected_ball_pos: Vector2i = Vector2i(-1, -1)
var is_dragging: bool = false
var drag_start_pos: Vector2
var step_count: int = 0
var current_level: int = 0

const BOARD_SIZE = 7
const GRID_SIZE = 7

func _ready() -> void:
	# Initialize Boards
	_setup_game()
	settings_panel.visible = false
	next_level_panel.visible = false
	overlay_dim.visible = false

func _on_next_level_pressed() -> void:
	current_level += 1
	_setup_game()
	next_level_panel.visible = false
	overlay_dim.visible = false
	set_process_unhandled_input(true)

func _on_settings_button_pressed() -> void:
	settings_panel.visible = true
	overlay_dim.visible = true

func _on_close_button_pressed() -> void:
	settings_panel.visible = false
	overlay_dim.visible = false

func _on_sound_check_toggled(toggled_on: bool) -> void:
	if play_board:
		play_board.is_muted = not toggled_on

func _update_steps() -> void:
	step_count += 1
	steps_label.text = "Steps: %d" % step_count

func _setup_game() -> void:
	play_board.clear_balls()
	target_board.clear_balls()
	win_label.visible = false
	
	step_count = 0
	steps_label.text = "Steps: 0"
	level_label.text = "Level: %d" % (current_level + 1)
	
	var levels = [
		{ # 1. Square (2 colors: 4, 2)
			"name": "Square",
			"pattern": [
				[0, 0, 0, 0, 0, 0, 0],
				[0, 4, 4, 4, 4, 4, 0],
				[0, 4, 2, 2, 2, 4, 0],
				[0, 4, 2, 2, 2, 4, 0],
				[0, 4, 2, 2, 2, 4, 0],
				[0, 4, 4, 4, 4, 4, 0],
				[0, 0, 0, 0, 0, 0, 0]
			]
		},
		{ # 2. Plus (2 colors: 4, 2)
			"name": "Plus",
			"pattern": [
				[0, 0, 0, 4, 0, 0, 0],
				[0, 0, 0, 4, 0, 0, 0],
				[0, 0, 0, 2, 0, 0, 0],
				[4, 4, 2, 2, 2, 4, 4],
				[0, 0, 0, 2, 0, 0, 0],
				[0, 0, 0, 4, 0, 0, 0],
				[0, 0, 0, 4, 0, 0, 0]
			]
		},
		{ # 3. Triangle (2 colors: 4, 1)
			"name": "Triangle",
			"pattern": [
				[0, 0, 0, 4, 0, 0, 0],
				[0, 0, 4, 1, 4, 0, 0],
				[0, 0, 4, 1, 4, 0, 0],
				[0, 4, 1, 1, 1, 4, 0],
				[0, 4, 1, 1, 1, 4, 0],
				[4, 4, 4, 4, 4, 4, 4],
				[0, 0, 0, 0, 0, 0, 0]
			]
		},
		{ # 4. X-Shape (2 colors: 4, 2)
			"name": "X-Shape",
			"pattern": [
				[4, 0, 0, 0, 0, 0, 4],
				[0, 4, 0, 0, 0, 4, 0],
				[0, 0, 2, 0, 2, 0, 0],
				[0, 0, 0, 2, 0, 0, 0],
				[0, 0, 2, 0, 2, 0, 0],
				[0, 4, 0, 0, 0, 4, 0],
				[4, 0, 0, 0, 0, 0, 4]
			]
		},
		{ # 5. Frame (2 colors: 4, 3)
			"name": "Frame",
			"pattern": [
				[4, 4, 4, 4, 4, 4, 4],
				[4, 3, 3, 3, 3, 3, 4],
				[4, 3, 0, 0, 0, 3, 4],
				[4, 3, 0, 0, 0, 3, 4],
				[4, 3, 0, 0, 0, 3, 4],
				[4, 3, 3, 3, 3, 3, 4],
				[4, 4, 4, 4, 4, 4, 4]
			]
		},
		{ # 6. Small Heart (3 colors: 2, 4, 1)
			"name": "Small Heart",
			"pattern": [
				[0, 0, 0, 0, 0, 0, 0],
				[0, 4, 4, 0, 4, 4, 0],
				[4, 2, 2, 4, 2, 2, 4],
				[4, 2, 2, 2, 2, 2, 4],
				[0, 4, 2, 1, 2, 4, 0],
				[0, 0, 4, 2, 4, 0, 0],
				[0, 0, 0, 4, 0, 0, 0]
			]
		},
		{ # 7. Arrow (3 colors: 2, 3, 4)
			"name": "Arrow",
			"pattern": [
				[0, 0, 0, 2, 0, 0, 0],
				[0, 0, 2, 3, 2, 0, 0],
				[0, 2, 3, 3, 3, 2, 0],
				[2, 2, 2, 3, 2, 2, 2],
				[0, 0, 0, 3, 0, 0, 0],
				[0, 0, 0, 3, 0, 0, 0],
				[0, 0, 0, 4, 0, 0, 0]
			]
		},
		{ # 8. Diamond (3 colors: 1, 2, 4)
			"name": "Diamond",
			"pattern": [
				[0, 0, 0, 1, 0, 0, 0],
				[0, 0, 1, 2, 1, 0, 0],
				[0, 1, 2, 4, 2, 1, 0],
				[1, 2, 4, 4, 4, 2, 1],
				[0, 1, 2, 4, 2, 1, 0],
				[0, 0, 1, 2, 1, 0, 0],
				[0, 0, 0, 1, 0, 0, 0]
			]
		},
		{ # 9. House (3 colors: 2, 4, 3)
			"name": "House",
			"pattern": [
				[0, 0, 0, 2, 0, 0, 0],
				[0, 0, 2, 2, 2, 0, 0],
				[0, 2, 2, 2, 2, 2, 0],
				[0, 4, 4, 4, 4, 4, 0],
				[0, 4, 4, 3, 4, 4, 0],
				[0, 4, 4, 3, 4, 4, 0],
				[0, 0, 0, 0, 0, 0, 0]
			]
		},
		{ # 10. Tree (3 colors: 1, 4, 2)
			"name": "Tree",
			"pattern": [
				[0, 0, 0, 1, 0, 0, 0],
				[0, 0, 1, 1, 1, 0, 0],
				[0, 1, 1, 1, 1, 1, 0],
				[1, 1, 1, 1, 1, 1, 1],
				[0, 0, 0, 4, 0, 0, 0],
				[0, 0, 0, 4, 0, 0, 0],
				[0, 0, 2, 2, 2, 0, 0]
			]
		},
		{ # 11. Star (4 colors: 4, 1, 2, 3)
			"name": "Star",
			"pattern": [
				[0, 0, 0, 4, 0, 0, 0],
				[1, 0, 4, 4, 4, 0, 3],
				[0, 4, 4, 2, 4, 4, 0],
				[4, 4, 2, 2, 2, 4, 4],
				[0, 4, 4, 2, 4, 4, 0],
				[1, 0, 4, 4, 4, 0, 3],
				[0, 0, 0, 4, 0, 0, 0]
			]
		},
		{ # 12. Boat (4 colors: 3, 4, 1, 2)
			"name": "Boat",
			"pattern": [
				[0, 0, 0, 3, 0, 0, 0],
				[0, 0, 3, 3, 0, 0, 0],
				[0, 3, 3, 3, 0, 0, 0],
				[0, 0, 0, 4, 0, 0, 0],
				[1, 1, 1, 1, 1, 1, 1],
				[0, 1, 1, 1, 1, 1, 0],
				[2, 2, 2, 2, 2, 2, 2]
			]
		},
		{ # 13. Face (4 colors: 4, 3, 2, 1)
			"name": "Face",
			"pattern": [
				[0, 4, 4, 4, 4, 4, 0],
				[4, 4, 4, 4, 4, 4, 4],
				[4, 3, 4, 4, 4, 3, 4],
				[4, 4, 4, 2, 4, 4, 4],
				[4, 4, 1, 1, 1, 4, 4],
				[4, 4, 4, 4, 4, 4, 4],
				[0, 4, 4, 4, 4, 4, 0]
			]
		},
		{ # 14. Flower (4 colors: 2, 4, 1, 3)
			"name": "Flower",
			"pattern": [
				[0, 0, 4, 4, 4, 0, 0],
				[0, 4, 1, 1, 1, 4, 0],
				[4, 1, 2, 1, 1, 1, 4],
				[4, 1, 1, 1, 1, 1, 4],
				[0, 4, 1, 1, 1, 4, 0],
				[0, 0, 0, 3, 0, 0, 0],
				[0, 2, 2, 3, 2, 2, 0]
			]
		},
		{ # 15. Butterfly (4 colors: 1, 2, 4, 3)
			"name": "Butterfly",
			"pattern": [
				[1, 1, 0, 4, 0, 2, 2],
				[1, 1, 1, 4, 2, 2, 2],
				[1, 1, 1, 4, 2, 2, 2],
				[0, 1, 1, 4, 2, 2, 0],
				[3, 3, 3, 4, 3, 3, 3],
				[3, 3, 3, 4, 3, 3, 3],
				[0, 0, 0, 4, 0, 0, 0]
			]
		},
		{ # 16. Rocket (4 colors: 3, 4, 2, 1)
			"name": "Rocket",
			"pattern": [
				[0, 0, 0, 3, 0, 0, 0],
				[0, 0, 3, 3, 3, 0, 0],
				[0, 0, 4, 4, 4, 0, 0],
				[0, 0, 4, 2, 4, 0, 0],
				[0, 4, 4, 4, 4, 4, 0],
				[4, 4, 4, 4, 4, 4, 4],
				[0, 1, 0, 1, 0, 1, 0]
			]
		},
		{ # 17. Sword (4 colors: 3, 4, 1, 2)
			"name": "Sword",
			"pattern": [
				[0, 0, 0, 3, 0, 0, 0],
				[0, 0, 3, 3, 3, 0, 0],
				[0, 0, 3, 3, 3, 0, 0],
				[0, 0, 3, 3, 3, 0, 0],
				[0, 1, 1, 1, 1, 1, 0],
				[0, 0, 0, 4, 0, 0, 0],
				[0, 0, 2, 4, 2, 0, 0]
			]
		},
		{ # 18. Shield (4 colors: 1, 4, 2, 3)
			"name": "Shield",
			"pattern": [
				[1, 1, 1, 1, 1, 1, 1],
				[1, 4, 4, 4, 4, 4, 1],
				[1, 4, 2, 2, 2, 4, 1],
				[1, 4, 2, 3, 2, 4, 1],
				[0, 1, 4, 2, 4, 1, 0],
				[0, 0, 1, 4, 1, 0, 0],
				[0, 0, 0, 1, 0, 0, 0]
			]
		},
		{ # 19. Crown (4 colors: 4, 1, 2, 3)
			"name": "Crown",
			"pattern": [
				[4, 0, 4, 0, 4, 0, 4],
				[4, 4, 4, 4, 4, 4, 4],
				[4, 1, 4, 2, 4, 3, 4],
				[4, 4, 4, 4, 4, 4, 4],
				[4, 4, 4, 4, 4, 4, 4],
				[0, 4, 4, 4, 4, 4, 0],
				[0, 0, 0, 0, 0, 0, 0]
			]
		},
		{ # 20. Complex Heart (4 colors: 2, 4, 1, 3)
			"name": "Final Heart",
			"pattern": [
				[0, 4, 4, 0, 4, 4, 0],
				[4, 2, 2, 4, 2, 2, 4],
				[2, 2, 2, 2, 2, 2, 2],
				[2, 2, 1, 3, 1, 2, 2],
				[0, 2, 2, 1, 2, 2, 0],
				[0, 0, 2, 2, 2, 0, 0],
				[0, 0, 0, 2, 0, 0, 0]
			]
		}
	]
	
	var level = levels[current_level % levels.size()]
	var pattern_grid = level["pattern"]
	print("Loading Level: ", level["name"])
	
	var balls_data = [] 
	var all_positions = []
	
	for y in range(BOARD_SIZE):
		for x in range(BOARD_SIZE):
			var pos = Vector2i(x, y)
			all_positions.append(pos)
			
			var color_code = pattern_grid[y][x]
			if color_code != 0:
				target_board.place_ball(pos, color_code)
				balls_data.append(color_code)
			# If 0, it's an empty hole in the target 
			# (Wait, user said "start with 6 holes without balls" - usually implies Play board has holes.
			#  Does target board also have holes? Yes, "match the upper board". 
			#  So the Target board should effectively show where the holes go too?)
			#  Yes, to match it perfectly, the holes must align.
	
	# 2. Scatter on Play Board
	# We take the exact list of balls (from balls_data) and scatter them.
	var play_slots = all_positions.duplicate()
	play_slots.shuffle()
	
	for color in balls_data:
		# We have N balls. We have 36 slots.
		# balls_data size is number of non-zero entries.
		# Scatter them into random slots.
		if play_slots.is_empty():
			break
		var pos = play_slots.pop_back()
		play_board.place_ball(pos, color)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_handle_touch_start(event.position)
			else:
				_handle_touch_end(event.position)

func _handle_touch_start(screen_pos: Vector2) -> void:
	var from = camera.project_ray_origin(screen_pos)
	var to = from + camera.project_ray_normal(screen_pos) * 100
	
	var space_state = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(from, to)
	var result = space_state.intersect_ray(query)
	
	if result:
		var collider = result.collider
		# Check if it's a ball (Area3D) or Hole?
		# My Ball is Area3D, but Board has Holes as StaticBody.
		# If we hit a Ball (Area3D), we need to check collision mask/layer or parent
		
		# Let's assume we hit the Ball Area3D. Area3D doesn't block rays by default for intersect_ray unless verify.
		# Actually, standard intersect_ray hits Bodies. Area3D requires intersect_point or special setup.
		# Easier: User clicks ON THE BALL.
		# The Ball script has an Area3D. I should probably use `_input_event` on the Area3D or switch Ball to StaticBody for Raycast.
		# Let's rely on mapping world pos to grid pos for robustness.
		
		pass

	# Alternative: GRID BASED CLICK
	# Map world intersection to PlayBoard grid.
	var grid_pos = _world_to_grid(result.position if result else Vector3.ZERO)
	if grid_pos != Vector2i(-1, -1):
		# Check if there is a ball there
		if play_board.get_ball_at(grid_pos):
			selected_ball_pos = grid_pos
			drag_start_pos = screen_pos
			is_dragging = true

func _handle_touch_end(screen_pos: Vector2) -> void:
	if is_dragging:
		var drag_vec = screen_pos - drag_start_pos
		if drag_vec.length() > 50: # Threshold
			_try_move(selected_ball_pos, drag_vec)
		
		is_dragging = false
		selected_ball_pos = Vector2i(-1, -1)

func _try_move(from: Vector2i, drag_vec: Vector2) -> void:
	var direction = Vector2i.ZERO
	if abs(drag_vec.x) > abs(drag_vec.y):
		direction = Vector2i.RIGHT if drag_vec.x > 0 else Vector2i.LEFT
	else:
		direction = Vector2i.DOWN if drag_vec.y > 0 else Vector2i.UP # Screen Y is down
	
	# Transform screen direction to grid direction?
	# Assuming camera looks straight down or angled consistently.
	# If Camera is rotated 45 deg, this might be tricky.
	# Let's align camera with grid axes. Grid X is Right, Grid Z is Down (visually).
	
	var target = from + direction
	
	# Check bounds
	if target.x < 0 or target.x >= BOARD_SIZE or target.y < 0 or target.y >= BOARD_SIZE:
		play_board.animate_bounce(from, direction)
		return
	
	# Check empty
	if not play_board.get_ball_at(target):
		play_board.move_ball(from, target)
		_update_steps()
		_check_win()
	else:
		play_board.animate_bounce(from, direction)

func _check_win() -> void:
	var state_play = play_board.get_state()
	var state_target = target_board.get_state()
	
	if state_play == state_target:
		win_label.visible = true
		next_level_panel.visible = true
		overlay_dim.visible = true
		set_process_unhandled_input(false)
		print("WIN!")

func _world_to_grid(world_pos: Vector3) -> Vector2i:
	# Playboard is at (0,0,0) locally? Need to check scene setup.
	# Assuming PlayBoard is at origin.
	# Board spacing is 1.1.
	
	# Raycast hit might be slightly off.
	# Inverse transform.
	var local_pos = play_board.to_local(world_pos)
	
	# Adjust for center/offset if needed. Holes are at x*1.1, z*1.1
	# Allow some tolerance.
	var x = round(local_pos.x / 1.1)
	var z = round(local_pos.z / 1.1)
	
	if x >= 0 and x < BOARD_SIZE and z >= 0 and z < BOARD_SIZE:
		return Vector2i(int(x), int(z))
	
	return Vector2i(-1, -1)
