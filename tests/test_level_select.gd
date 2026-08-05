extends SceneTree

## Level-select scrolling, driven by real touch events.
##   godot --script tests/test_level_select.gd --resolution 720x1280
##
## The grid is completely covered by level-card Buttons. If the ScrollContainer
## does not take the gesture away from them, a drag starting on a card is
## swallowed by that button and the list appears stuck — which is exactly what
## happened on device with scroll_deadzone left at its default of 0.

var failures: Array[String] = []


func _init() -> void:
	_run.call_deferred()


func _touch(position: Vector2, pressed: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.index = 0
	event.position = position
	event.pressed = pressed
	Input.parse_input_event(event)


func _drag(position: Vector2, relative: Vector2) -> void:
	var event := InputEventScreenDrag.new()
	event.index = 0
	event.position = position
	event.relative = relative
	Input.parse_input_event(event)


## Drag upward from `start`, as a finger flicking the list up.
func _swipe_up(start: Vector2, distance: float, steps: int) -> void:
	_touch(start, true)
	var step := distance / steps
	var at := start
	for i in steps:
		at += Vector2(0, -step)
		_drag(at, Vector2(0, -step))
		await process_frame
	_touch(at, false)
	await process_frame


func _run() -> void:
	var data := root.get_node_or_null("/root/GameData")
	data.persist_enabled = false
	# Unlock a good chunk so the grid is tall enough to actually scroll.
	for i in 20:
		data.stars[i] = 3

	change_scene_to_file("res://scenes/level_select.tscn")
	for i in 15:
		await process_frame

	var screen = current_scene
	var scroll: ScrollContainer = screen.get_node("Scroll")
	var grid: GridContainer = scroll.get_node("Grid")

	# --- the list must actually be longer than its viewport ------------------
	if grid.size.y <= scroll.size.y:
		failures.append("grid (%d px) is not taller than the scroll view (%d px); nothing to scroll" % [
			grid.size.y, scroll.size.y
		])

	# --- drag starting ON a card --------------------------------------------
	var card: Button = null
	for child in grid.get_children():
		if child is Button:
			card = child
			break
	if card == null:
		failures.append("no level cards were built")
		_finish()
		return

	var start := card.global_position + card.size * 0.5
	var before := scroll.scroll_vertical
	await _swipe_up(start, 420.0, 14)
	var after := scroll.scroll_vertical

	if after <= before:
		failures.append("dragging from a card scrolled nothing (%d -> %d)" % [before, after])
	elif after - before < 100:
		failures.append("drag of 420px only scrolled %d px" % (after - before))

	# --- a drag must not also open the card it started on -------------------
	if not screen._is_scrolling:
		failures.append("a 420px drag was not recognised as a scroll, so the card would open")

	# --- a drag must move the list one-for-one, not double -------------------
	# Touch also arrives as emulated mouse motion, and counting both moved the
	# list at twice the finger's speed.
	scroll.scroll_vertical = 0
	screen._scroll_pos = 0.0
	await _swipe_up(start, 200.0, 8)
	var travelled := scroll.scroll_vertical
	if travelled > 300:
		failures.append("a 200px drag scrolled %d px — input is being counted twice" % travelled)

	# --- a flick must coast after the finger lifts --------------------------
	scroll.scroll_vertical = 0
	screen._scroll_pos = 0.0
	await _swipe_up(start, 300.0, 6)
	var at_release := scroll.scroll_vertical
	for i in 30:
		await process_frame
	if scroll.scroll_vertical <= at_release:
		failures.append("the list stopped dead on release instead of coasting (%d)" % at_release)

	# --- and touching it again must stop it ---------------------------------
	_touch(start, true)
	await process_frame
	var caught := scroll.scroll_vertical
	for i in 20:
		await process_frame
	if scroll.scroll_vertical != caught:
		failures.append("touching a coasting list did not stop it")
	# Release past the tap threshold. A clean release here would register as a
	# tap and navigate away mid-test.
	var lifted := start + Vector2(0, -20)
	_drag(lifted, Vector2(0, -20))
	await process_frame
	_touch(lifted, false)
	await process_frame

	# --- a clean tap must still open a level ---------------------------------
	# Deliberately last: this navigates, which frees the scene. Run earlier, it
	# left every later assertion reading a freed node, and the resulting script
	# error killed the coroutine before it could report — so the whole test
	# looked like a hang instead of telling us what was wrong.
	# Back to the top first: all the scrolling above leaves this screen point
	# over a card far down the list, which is locked and cannot be pressed.
	scroll.scroll_vertical = 0
	screen._scroll_pos = 0.0
	screen._velocity = 0.0
	for i in 4:
		await process_frame

	_touch(start, true)
	await process_frame
	_touch(start, false)
	for i in 10:
		await process_frame
	if current_scene == null or current_scene.scene_file_path != "res://scenes/main.tscn":
		failures.append("a clean tap on a card did not open the level")

	_finish(before, after)


func _finish(before: int = 0, after: int = 0) -> void:
	if failures.is_empty():
		print("PASS — dragging from a level card scrolls the list (%d -> %d px)" % [before, after])
		# quit() does not return, so without this the pass fell through to the
		# quit(1) below and a green run reported an exit code of 1.
		quit(0)
		return
	for failure in failures:
		print("FAIL: ", failure)
	quit(1)
