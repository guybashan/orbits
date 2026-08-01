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

	# --- but a clean tap must still open a level ----------------------------
	_touch(start, true)
	await process_frame
	_touch(start, false)
	await process_frame
	if screen._is_scrolling:
		failures.append("a tap with no movement was mistaken for a scroll")

	_finish(before, after)


func _finish(before: int = 0, after: int = 0) -> void:
	if failures.is_empty():
		print("PASS — dragging from a level card scrolls the list (%d -> %d px)" % [before, after])
		quit(0)
	for failure in failures:
		print("FAIL: ", failure)
	quit(1)
