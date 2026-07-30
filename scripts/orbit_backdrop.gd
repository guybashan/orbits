class_name OrbitBackdrop
extends Control

## Slow drifting rings of coloured dots behind the menus — the game's name,
## made literal. Pure _draw, so it costs nothing to ship.

const RING_COUNT := 4
const DOTS_PER_RING := 7

var _time := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _draw() -> void:
	var centre := size * Vector2(0.5, 0.42)
	var base_radius := minf(size.x, size.y) * 0.16

	for ring in RING_COUNT:
		var radius := base_radius * (1.0 + ring * 0.62)
		var speed := 0.16 / (1.0 + ring * 0.55)
		var tilt := 0.42 + ring * 0.06

		draw_arc(centre, radius, 0.0, TAU, 64, Color(0.35, 0.6, 1.0, 0.05), 1.5, true)

		for dot in DOTS_PER_RING:
			var angle := _time * speed + TAU * dot / float(DOTS_PER_RING) + ring * 0.7
			var point := centre + Vector2(cos(angle) * radius, sin(angle) * radius * tilt)
			var color := Ball.color_for((ring + dot) % 5 + 1)
			var depth := 0.55 + 0.45 * sin(angle)
			draw_circle(point, 3.5 + 3.0 * depth, Color(color.r, color.g, color.b, 0.10 + 0.16 * depth))
