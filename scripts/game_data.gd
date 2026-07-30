extends Node

## Autoloaded save file: level progress plus the handful of settings the
## player can change. Written on every meaningful change — mobile apps get
## killed without warning.

const SAVE_FILE := "user://orbits.save"
const SAVE_VERSION := 2

var stars: Dictionary = {}       # level index (int) -> 0..3
var best_moves: Dictionary = {}  # level index (int) -> best move count
var last_level: int = 0

var sfx_enabled := true
var music_enabled := true
var haptics_enabled := true

var _dirty_timer: SceneTreeTimer


func _ready() -> void:
	load_data()


# ---------------------------------------------------------------- progress --

func stars_for(index: int) -> int:
	return int(stars.get(index, 0))


func best_for(index: int) -> int:
	return int(best_moves.get(index, 0))


func total_stars() -> int:
	var sum := 0
	for value in stars.values():
		sum += int(value)
	return sum


func is_unlocked(index: int) -> bool:
	if index <= 0:
		return true
	return stars_for(index - 1) > 0


func highest_unlocked() -> int:
	var index := 0
	while index + 1 < Levels.count() and is_unlocked(index + 1):
		index += 1
	return index


## Star thresholds are relative to par (the level's shuffle depth), which is a
## guaranteed-achievable move count.
static func stars_for_moves(moves: int, par: int) -> int:
	if moves <= par:
		return 3
	if moves <= int(ceil(par * 1.5)):
		return 2
	return 1


func record_result(index: int, moves: int, earned_stars: int) -> bool:
	var improved := false

	if earned_stars > stars_for(index):
		stars[index] = earned_stars
		improved = true

	var previous_best := best_for(index)
	if previous_best == 0 or moves < previous_best:
		best_moves[index] = moves
		improved = true

	save_data()
	return improved


func reset_progress() -> void:
	stars.clear()
	best_moves.clear()
	last_level = 0
	save_data()


# ------------------------------------------------------------------- disk --

func save_data() -> void:
	var payload := {
		"version": SAVE_VERSION,
		"stars": _int_keyed_to_string(stars),
		"best_moves": _int_keyed_to_string(best_moves),
		"last_level": last_level,
		"sfx_enabled": sfx_enabled,
		"music_enabled": music_enabled,
		"haptics_enabled": haptics_enabled,
	}
	var file := FileAccess.open(SAVE_FILE, FileAccess.WRITE)
	if file == null:
		push_warning("Orbits: could not open save file for writing")
		return
	file.store_string(JSON.stringify(payload))
	file.close()


func load_data() -> void:
	if not FileAccess.file_exists(SAVE_FILE):
		return

	var file := FileAccess.open(SAVE_FILE, FileAccess.READ)
	if file == null:
		return
	var text := file.get_as_text()
	file.close()

	var json := JSON.new()
	if json.parse(text) != OK or typeof(json.data) != TYPE_DICTIONARY:
		push_warning("Orbits: save file unreadable, starting fresh")
		return

	var data: Dictionary = json.data
	stars = _string_keyed_to_int(data.get("stars", {}))
	best_moves = _string_keyed_to_int(data.get("best_moves", {}))
	last_level = int(data.get("last_level", 0))
	sfx_enabled = bool(data.get("sfx_enabled", true))
	music_enabled = bool(data.get("music_enabled", true))
	haptics_enabled = bool(data.get("haptics_enabled", true))


# JSON object keys are always strings; convert both ways so the rest of the
# code can index by plain level number.
func _int_keyed_to_string(source: Dictionary) -> Dictionary:
	var out := {}
	for key in source:
		out[str(key)] = source[key]
	return out


func _string_keyed_to_int(source: Dictionary) -> Dictionary:
	var out := {}
	for key in source:
		out[int(str(key))] = int(source[key])
	return out
