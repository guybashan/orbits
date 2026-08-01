extends Control

## Level grid. Cards are built in code so adding levels to the bank is the
## only thing needed to extend the game.

const COLUMNS := 4
const SEPARATION := 14

## Past this many pixels of movement a press is a scroll, not a tap, and the
## card under the finger must not navigate.
const DRAG_CANCEL := 12.0

@onready var scroll: ScrollContainer = $Scroll
@onready var grid: GridContainer = $Scroll/Grid

var _drag_distance := 0.0
var _is_scrolling := false
@onready var stars_label: Label = $Header/Row/StarsLabel


func _ready() -> void:
	Audio.update_music()
	grid.columns = COLUMNS
	grid.add_theme_constant_override("h_separation", SEPARATION)
	grid.add_theme_constant_override("v_separation", SEPARATION)

	var possible := Levels.count() * 3
	stars_label.text = "%d / %d" % [GameData.total_stars(), possible]

	_build_cards()
	# Cards size themselves off the viewport, so rebuild on rotation/resize.
	get_viewport().size_changed.connect(_build_cards)


## Scrolling is driven here rather than left to ScrollContainer's built-in
## touch handling. The grid is entirely covered by card Buttons, which consume
## the touch before the container ever sees it — on device the list barely
## moved. Handling it at the scene level means the gesture works no matter what
## is under the finger.
func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			_drag_distance = 0.0
			_is_scrolling = false
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_drag_distance = 0.0
			_is_scrolling = false
		return

	var motion := 0.0
	if event is InputEventScreenDrag:
		motion = event.relative.y
	elif event is InputEventMouseMotion and (event.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
		motion = event.relative.y
	else:
		return

	_drag_distance += absf(motion)
	if _drag_distance >= DRAG_CANCEL:
		_is_scrolling = true
	scroll.scroll_vertical -= int(round(motion))


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_on_back_pressed()


func _build_cards() -> void:
	for child in grid.get_children():
		child.queue_free()

	var available: float = grid.size.x
	if available <= 0.0:
		available = get_viewport().get_visible_rect().size.x - 48.0
	var card: float = floorf((available - (COLUMNS - 1) * SEPARATION) / COLUMNS)
	card = maxf(card, 80.0)

	for index in Levels.count():
		grid.add_child(_make_card(index, card))


func _make_card(index: int, card_size: float) -> Button:
	var level := Levels.get_level(index)
	var unlocked := GameData.is_unlocked(index)
	var earned := GameData.stars_for(index)

	var button := Button.new()
	button.custom_minimum_size = Vector2(card_size, card_size)
	button.disabled = not unlocked
	button.focus_mode = Control.FOCUS_NONE
	button.tooltip_text = str(level["name"])
	button.clip_contents = true
	if unlocked:
		button.pressed.connect(_on_level_pressed.bind(index))

	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 4)
	button.add_child(box)

	var number := Label.new()
	number.text = str(index + 1)
	number.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	number.add_theme_font_size_override("font_size", 34)
	number.add_theme_color_override(
		"font_color",
		Color(0.88, 0.93, 1.0) if unlocked else Color(0.34, 0.38, 0.48)
	)
	box.add_child(number)

	if unlocked:
		var stars := StarRow.new()
		stars.total = 3
		stars.earned = earned
		stars.custom_minimum_size = Vector2(card_size * 0.62, card_size * 0.20)
		stars.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		box.add_child(stars)
	else:
		var locked := Label.new()
		locked.text = "locked"
		locked.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		locked.add_theme_font_size_override("font_size", 16)
		locked.add_theme_color_override("font_color", Color(0.34, 0.38, 0.48))
		box.add_child(locked)

	return button


func _on_level_pressed(index: int) -> void:
	# A press that ended a scroll must not also open a level.
	if _is_scrolling:
		return
	Audio.play("ui")
	GameData.last_level = index
	GameData.save_data()
	get_tree().change_scene_to_file("res://scenes/main.tscn")


func _on_back_pressed() -> void:
	Audio.play("ui")
	get_tree().change_scene_to_file("res://scenes/menu.tscn")
