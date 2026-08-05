extends SceneTree

## Screenshot a live board, without the win overlay dimming it.
##   godot --script tests/screenshot.gd --resolution 720x1280 -- <level> <path>
##
## Worth having because the sphere previews in tools/gen_planets.py are not the
## game: they miss the key/fill lights, the emission wash and the bloom, and a
## texture that looks right in isolation can still bleach out on the board.
##
## If a texture change seems to have no effect, Godot is serving a cached
## import. Force it with:  godot --headless --import --path .
func _init() -> void:
	_run.call_deferred()
func _run() -> void:
	var data := root.get_node_or_null("/root/GameData")
	data.persist_enabled = false
	var argv := OS.get_cmdline_user_args()
	data.last_level = int(argv[0]) if argv.size() > 0 else 0
	change_scene_to_file("res://scenes/main.tscn")
	for i in 40:
		await process_frame
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	img.save_png(argv[1] if argv.size() > 1 else "/tmp/board.png")
	print("shot saved")
	quit(0)
