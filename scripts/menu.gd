extends Control

## Title screen. "Continue" resumes wherever the player left off; everything
## else is one tap away.

@onready var continue_button: Button = $Centre/VBox/ContinueButton
@onready var stars_label: Label = $Centre/VBox/StarsLabel
@onready var settings_panel: PanelContainer = $SettingsPanel
@onready var dim: ColorRect = $Dim
@onready var sfx_check: CheckButton = $SettingsPanel/VBox/SfxCheck
@onready var music_check: CheckButton = $SettingsPanel/VBox/MusicCheck
@onready var haptics_check: CheckButton = $SettingsPanel/VBox/HapticsCheck
@onready var reset_confirm: ConfirmationDialog = $ResetConfirm


func _ready() -> void:
	Audio.update_music()
	settings_panel.visible = false
	dim.visible = false

	sfx_check.button_pressed = GameData.sfx_enabled
	music_check.button_pressed = GameData.music_enabled
	haptics_check.button_pressed = GameData.haptics_enabled

	_refresh()


func _refresh() -> void:
	var resume := clampi(GameData.last_level, 0, Levels.count() - 1)
	continue_button.text = "CONTINUE  ·  LEVEL %d" % (resume + 1)

	var possible := Levels.count() * 3
	stars_label.text = "%d / %d stars   ·   %s points" % [
		GameData.total_stars(), possible, _grouped(GameData.total_score())
	]


func _grouped(value: int) -> String:
	var digits := str(value)
	var out := ""
	for i in digits.length():
		if i > 0 and (digits.length() - i) % 3 == 0:
			out += ","
		out += digits[i]
	return out


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if settings_panel.visible:
			_on_close_settings_pressed()
		else:
			get_tree().quit()


func _on_continue_pressed() -> void:
	Audio.play("ui")
	GameData.last_level = clampi(GameData.last_level, 0, Levels.count() - 1)
	get_tree().change_scene_to_file("res://scenes/main.tscn")


func _on_levels_pressed() -> void:
	Audio.play("ui")
	get_tree().change_scene_to_file("res://scenes/level_select.tscn")


func _on_settings_pressed() -> void:
	Audio.play("ui")
	settings_panel.visible = true
	dim.visible = true


func _on_close_settings_pressed() -> void:
	Audio.play("ui")
	settings_panel.visible = false
	dim.visible = false


func _on_sfx_toggled(pressed: bool) -> void:
	GameData.sfx_enabled = pressed
	GameData.save_data()
	Audio.play("ui")


func _on_music_toggled(pressed: bool) -> void:
	GameData.music_enabled = pressed
	GameData.save_data()
	Audio.update_music()


func _on_haptics_toggled(pressed: bool) -> void:
	GameData.haptics_enabled = pressed
	GameData.save_data()
	Audio.haptic(20)


func _on_reset_pressed() -> void:
	Audio.play("ui")
	reset_confirm.popup_centered()


func _on_reset_confirmed() -> void:
	GameData.reset_progress()
	_refresh()
