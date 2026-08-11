class_name GoalView
extends Control

## Compact 2D thumbnail of the pattern the player is rebuilding. The board
## itself carries the per-cell hints; this is the "picture on the jigsaw box".

static var _panel: StyleBoxFlat


static func _panel_style() -> StyleBoxFlat:
	if _panel == null:
		_panel = StyleBoxFlat.new()
		_panel.bg_color = Color(0.07, 0.10, 0.20, 0.85)
		_panel.border_color = Color(0.42, 0.56, 0.86, 0.55)
		_panel.set_border_width_all(1)
		_panel.set_corner_radius_all(10)
	return _panel


var pattern: Array = []:
	set(value):
		pattern = value
		queue_redraw()

## Cells already satisfied on the play board, drawn solid instead of hollow.
var solved_cells: Dictionary = {}:
	set(value):
		solved_cells = value
		queue_redraw()


func _draw() -> void:
	if pattern.is_empty():
		return

	# Card backdrop, so the goal reads as "the picture on the box" instead of
	# loose dots floating on the sky. Also earns its keep functionally: the
	# panel edge is what tells the eye this is a miniature, not part of the
	# play field.
	draw_style_box(_panel_style(), Rect2(Vector2.ZERO, size))

	var n: int = pattern.size()
	var inset := 7.0
	var box := minf(size.x, size.y) - inset * 2.0
	var step := box / float(n)
	var radius := step * 0.40
	var origin := Vector2((size.x - box) * 0.5, (size.y - box) * 0.5) + Vector2(step, step) * 0.5

	for y in n:
		for x in n:
			var color_type: int = pattern[y][x]
			var centre := origin + Vector2(x, y) * step
			if color_type == 0:
				draw_circle(centre, radius * 0.30, Color(1, 1, 1, 0.14))
				continue

			var tint := Ball.color_for(color_type)
			if solved_cells.get(Vector2i(x, y), false):
				draw_circle(centre, radius, tint)
				# The same top-left highlight the 3D balls carry, so the
				# miniature and the board speak the same language.
				draw_circle(centre + Vector2(-radius, -radius) * 0.35,
					radius * 0.28, Color(1, 1, 1, 0.55))
			else:
				draw_circle(centre, radius, Color(tint.r, tint.g, tint.b, 0.30))
				draw_arc(centre, radius, 0.0, TAU, 24, Color(tint.r, tint.g, tint.b, 0.95), 2.2, true)
