extends Node

const SAVE_FILE = "user://savegame.save"

var current_level_index: int = 0
var max_completed_level: int = 0

func _ready() -> void:
	load_data()

func save_data() -> void:
	var data = {
		"current_level_index": current_level_index,
		"max_completed_level": max_completed_level
	}
	var file = FileAccess.open(SAVE_FILE, FileAccess.WRITE)
	file.store_string(JSON.stringify(data))

func load_data() -> void:
	if not FileAccess.file_exists(SAVE_FILE):
		return
	
	var file = FileAccess.open(SAVE_FILE, FileAccess.READ)
	var text = file.get_as_text()
	var json = JSON.new()
	var error = json.parse(text)
	
	if error == OK:
		var data = json.data
		current_level_index = data.get("current_level_index", 0)
		max_completed_level = data.get("max_completed_level", 0)
