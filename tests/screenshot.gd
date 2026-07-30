extends SceneTree

## Dev helper: boot a scene, let it settle, save a PNG.
##   godot --script tests/screenshot.gd --resolution 720x1280 -- <scene> <out.png> [frames]

var scene_path := "res://scenes/main.tscn"
var out_path := "res://shot.png"
var wait_frames := 60


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() >= 1:
		scene_path = args[0]
	if args.size() >= 2:
		out_path = args[1]
	if args.size() >= 3:
		wait_frames = int(args[2])
	_run.call_deferred()


func _run() -> void:
	change_scene_to_file(scene_path)
	for i in wait_frames:
		await process_frame
	await RenderingServer.frame_post_draw

	var image := root.get_texture().get_image()
	var error := image.save_png(out_path)
	print("screenshot %s -> %s (err %d)" % [scene_path, out_path, error])
	quit(0 if error == OK else 1)
