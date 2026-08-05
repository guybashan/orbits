extends SceneTree

## Save-file handling across a level-bank change.
##   godot --headless --script tests/test_save.gd
##
## Progress is keyed by level index. When the patterns behind those indices
## change, carrying old stars forward marks levels cleared that the player has
## never seen and opens the unlock chain in the wrong places.

const GameDataScript = preload("res://scripts/game_data.gd")

var failures: Array[String] = []


func _init() -> void:
	var path := "user://orbits.save"

	# A save written by an older build, with progress and non-default settings.
	var old := {
		"version": 3,
		"stars": {"0": 3, "1": 3, "20": 2},
		"best_moves": {"0": 4},
		"best_times": {"0": 12.5},
		"best_scores": {"0": 900},
		"last_level": 34,
		"sfx_enabled": false,
		"music_enabled": true,
		"haptics_enabled": false,
	}
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(old))
	file.close()

	var data = GameDataScript.new()
	data.load_data()

	if not data.stars.is_empty():
		failures.append("stale progress survived a bank change (%d levels)" % data.stars.size())
	if not data.best_scores.is_empty():
		failures.append("stale best scores survived a bank change")
	if data.last_level != 0:
		failures.append("last_level %d not reset" % data.last_level)

	# Settings describe the player, not the levels, so they must carry over.
	if data.sfx_enabled != false or data.haptics_enabled != false:
		failures.append("settings were wiped along with progress")

	# A current-version save must load untouched.
	data.stars = {"5": 3}
	data.last_level = 5
	data.save_data()
	var fresh = GameDataScript.new()
	fresh.load_data()
	if fresh.stars_for(5) != 3 or fresh.last_level != 5:
		failures.append("a current-version save did not round-trip")

	# last_level must never point past the end of the bank.
	fresh.last_level = 9999
	fresh.save_data()
	var clamped = GameDataScript.new()
	clamped.load_data()
	if clamped.last_level >= Levels.count():
		failures.append("last_level %d is outside the bank" % clamped.last_level)

	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

	if failures.is_empty():
		print("PASS — stale progress is cleared, settings kept, save round-trips")
		# quit() does not return, so without this a pass fell through to the
		# quit(1) below and a green run reported an exit code of 1.
		quit(0)
		return
	for f in failures:
		print("FAIL: ", f)
	quit(1)
