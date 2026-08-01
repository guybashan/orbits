extends SceneTree
func _init() -> void: _run.call_deferred()
func _run() -> void:
	change_scene_to_file("res://scenes/menu.tscn")
	for i in 10: await process_frame
	current_scene._on_settings_pressed()
	await create_timer(0.6).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OS.get_cmdline_user_args()[0])
	print("saved")
	quit()
