extends Control

## Level grid. Cards are built in code so adding levels to the bank is the
## only thing needed to extend the game.

const COLUMNS := 4
const SEPARATION := 14

## Past this much NET movement a press is a scroll, not a tap, and the card
## under the finger must not navigate.
##
## Net, not accumulated. Summing absolute movement counted a finger's jitter:
## resting on a card wobbles a pixel or two per frame, so an ordinary tap piled
## up past the threshold without the finger going anywhere and the level refused
## to open. What matters is whether the finger travelled, not how much it
## trembled getting there.
const DRAG_CANCEL := 16.0

## How quickly a flick decays once the finger lifts. Per second, applied
## exponentially so it is frame-rate independent.
const FLICK_FRICTION := 5.5
## Below this the list is effectively still; stop rather than creep.
const FLICK_CUTOFF := 8.0
## How fast the captured speed fades while the finger is still down. Fast
## enough that pausing for a moment before lifting means no flick, slow enough
## that the frame or two between the last movement and the lift costs nothing.
const HOLD_DECAY := 12.0

@onready var scroll: ScrollContainer = $Scroll
@onready var grid: GridContainer = $Scroll/Grid

var _net_drag := 0.0
var _is_scrolling := false
## Position is kept as a float. ScrollContainer only takes whole pixels, and
## rounding every individual drag event threw away sub-pixel motion, so slow
## drags moved in steps or not at all.
var _scroll_pos := 0.0
var _velocity := 0.0
var _dragging := false
## Godot turns touch into mouse events as well (Input.emulate_mouse_from_touch,
## on by default), so one finger drag arrives twice: once as a screen drag and
## once as mouse motion. Counting both moved the list at double speed, which
## slammed it into the end of the range where the flick velocity is zeroed —
## the list overshot AND refused to coast. Mouse input is ignored while a
## finger is down; desktop, which has no touch, is unaffected.
var _touch_active := false
@onready var stars_label: Label = $Header/Row/StarsLabel


func _ready() -> void:
	Audio.update_music()
	# The container must not scroll itself: this script drives scroll_vertical,
	# and leaving the built-in handler live meant a drag was applied twice, so
	# the list moved at double speed and fought the flick.
	scroll.mouse_filter = Control.MOUSE_FILTER_IGNORE
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
	var pressed_now := false
	var released_now := false
	if event is InputEventScreenTouch:
		_touch_active = event.pressed
		pressed_now = event.pressed
		released_now = not event.pressed
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if _touch_active:
			return  # the emulated twin of a touch we have already handled
		pressed_now = event.pressed
		released_now = not event.pressed

	if pressed_now:
		# Catching a moving list should stop it, the way every native list does.
		_net_drag = 0.0
		_is_scrolling = false
		_dragging = true
		_velocity = 0.0
		_scroll_pos = float(scroll.scroll_vertical)
		return
	if released_now:
		_dragging = false
		return

	var motion := 0.0
	if event is InputEventScreenDrag:
		motion = event.relative.y
	elif event is InputEventMouseMotion and (event.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
		if _touch_active:
			return  # already counted as a screen drag
		motion = event.relative.y
	else:
		return

	_net_drag += motion
	if absf(_net_drag) >= DRAG_CANCEL:
		_is_scrolling = true

	_scroll_pos -= motion
	# Carry the finger's speed so releasing mid-drag flicks rather than stops.
	var frame := maxf(get_process_delta_time(), 1.0 / 120.0)
	_velocity = -motion / frame
	_apply_scroll()


## Coast after the finger lifts, decaying exponentially, and stop dead at the
## ends so the list cannot drift past its bounds.
func _process(delta: float) -> void:
	if _dragging:
		# Decay, never zero. Zeroing here wiped the flick speed on the frame
		# between the last drag event and the finger lifting — which is every
		# release — so the list could never coast at all. Decaying instead also
		# gives the behaviour a native list has: hold still for a moment before
		# lifting and it releases into stillness rather than flicking.
		_velocity *= exp(-HOLD_DECAY * delta)
		return
	if absf(_velocity) < FLICK_CUTOFF:
		_velocity = 0.0
		return
	_scroll_pos += _velocity * delta
	_velocity *= exp(-FLICK_FRICTION * delta)
	_apply_scroll()


func _apply_scroll() -> void:
	var limit := maxf(scroll.get_v_scroll_bar().max_value - scroll.size.y, 0.0)
	if _scroll_pos < 0.0 or _scroll_pos > limit:
		_velocity = 0.0
	_scroll_pos = clampf(_scroll_pos, 0.0, limit)
	scroll.scroll_vertical = int(round(_scroll_pos))


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

	var bonus := Levels.is_bonus(index)

	var button := Button.new()
	button.custom_minimum_size = Vector2(card_size, card_size)
	if bonus and unlocked:
		# Gold, so a breather is visible from the grid rather than a surprise.
		var gold := StyleBoxFlat.new()
		gold.bg_color = Color(0.20, 0.15, 0.04, 0.85)
		gold.border_width_left = 2
		gold.border_width_top = 2
		gold.border_width_right = 2
		gold.border_width_bottom = 2
		gold.border_color = Color(1.0, 0.82, 0.29, 0.85)
		gold.corner_radius_top_left = 20
		gold.corner_radius_top_right = 20
		gold.corner_radius_bottom_right = 20
		gold.corner_radius_bottom_left = 20
		button.add_theme_stylebox_override("normal", gold)
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
	var number_colour := Color(0.88, 0.93, 1.0)
	if not unlocked:
		number_colour = Color(0.34, 0.38, 0.48)
	elif bonus:
		number_colour = Color(1.0, 0.85, 0.35)
	number.add_theme_color_override("font_color", number_colour)
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
