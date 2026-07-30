class_name StarRow
extends Control

## Draws up to `total` five-pointed stars, `earned` of them filled. Drawn
## rather than typeset so it renders identically regardless of what glyphs the
## bundled font happens to carry.

const FILLED := Color(1.0, 0.82, 0.29)
const EMPTY := Color(1.0, 1.0, 1.0, 0.16)

@export var total: int = 3:
	set(value):
		total = value
		queue_redraw()

@export var earned: int = 0:
	set(value):
		earned = value
		queue_redraw()


func _draw() -> void:
	if total <= 0:
		return

	var slot := size.x / float(total)
	var radius := minf(slot * 0.42, size.y * 0.5)

	for i in total:
		var centre := Vector2(slot * (i + 0.5), size.y * 0.5)
		var color := FILLED if i < earned else EMPTY
		draw_colored_polygon(_star_points(centre, radius), color)


func _star_points(centre: Vector2, radius: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	var inner := radius * 0.44
	for i in 10:
		var r := radius if i % 2 == 0 else inner
		var angle := -PI / 2.0 + i * PI / 5.0
		points.append(centre + Vector2(cos(angle), sin(angle)) * r)
	return points
