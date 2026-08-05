extends SceneTree

## The top bar, stats row and toast are anchored at fixed offsets. A device
## with a notch pushes the top bar down, and if the rest does not move with it
## the level name ends up underneath the move counter — which is exactly what
## happened on a real phone.
##   godot --script tests/test_safe_area.gd --resolution 720x1280

var failures: Array[String] = []


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	root.get_node_or_null("/root/GameData").persist_enabled = false
	change_scene_to_file("res://scenes/main.tscn")
	for i in 12:
		await process_frame

	var main := current_scene
	var top: MarginContainer = main.get_node("UI/Top")
	var stats: MarginContainer = main.get_node("UI/Stats")
	var name_label: Label = main.get_node("UI/Top/Row/Centre/NameLabel")

	# Simulate a generous notch, larger than most devices.
	main._offset_top_ui(120)
	for i in 4:
		await process_frame

	var name_bottom := name_label.global_position.y + name_label.size.y
	if name_bottom > stats.global_position.y + 1.0:
		failures.append("level name overlaps the stats row by %.0f px" % (name_bottom - stats.global_position.y))

	if top.global_position.y + top.size.y > stats.global_position.y + 1.0:
		failures.append("top bar overlaps the stats row")

	if stats.global_position.y < 120.0:
		failures.append("stats row did not move down with the inset (y=%.0f)" % stats.global_position.y)

	if failures.is_empty():
		print("PASS — top stack clears the notch (name ends %.0f, stats start %.0f)" % [
			name_bottom, stats.global_position.y])
		# quit() does not return, so without this a pass fell through to the
		# quit(1) below and a green run reported an exit code of 1.
		quit(0)
		return
	for f in failures:
		print("FAIL: ", f)
	quit(1)
