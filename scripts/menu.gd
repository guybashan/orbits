extends Control

func _ready() -> void:
    # Optional: Add any intro animations here
    pass

func _on_play_pressed() -> void:
    get_tree().change_scene_to_file("res://scenes/main.tscn")

func _on_quit_pressed() -> void:
    get_tree().quit()
