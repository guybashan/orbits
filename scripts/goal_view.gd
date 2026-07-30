class_name GoalView
extends Control

## Compact 2D thumbnail of the pattern the player is rebuilding. The board
## itself carries the per-cell hints; this is the "picture on the jigsaw box".

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

	var n: int = pattern.size()
	var box := minf(size.x, size.y)
	var step := box / float(n)
	var radius := step * 0.34
	var origin := Vector2((size.x - box) * 0.5, (size.y - box) * 0.5) + Vector2(step, step) * 0.5

	for y in n:
		for x in n:
			var color_type: int = pattern[y][x]
			var centre := origin + Vector2(x, y) * step
			if color_type == 0:
				draw_circle(centre, radius * 0.34, Color(1, 1, 1, 0.10))
				continue

			var tint := Ball.color_for(color_type)
			if solved_cells.get(Vector2i(x, y), false):
				draw_circle(centre, radius, tint)
			else:
				draw_circle(centre, radius, Color(tint.r, tint.g, tint.b, 0.28))
				draw_arc(centre, radius, 0.0, TAU, 20, Color(tint.r, tint.g, tint.b, 0.85), 1.6, true)
