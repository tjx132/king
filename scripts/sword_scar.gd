extends Node2D

const SEGMENT_COUNT = 14
const FLAME_COUNT = 9

var length = 210.0
var direction = -1.0
var progress = 0.0
var time = 0.0

func _ready() -> void:
	z_index = 3

func _process(delta: float) -> void:
	time += delta
	queue_redraw()

func _draw() -> void:
	if progress <= 0.001:
		return
	var reach = length * clampf(progress, 0.0, 1.0)
	var points = PackedVector2Array()
	for index in range(SEGMENT_COUNT + 1):
		var ratio = float(index) / SEGMENT_COUNT
		var y = sin(index * 2.37) * 2.2
		points.append(Vector2(direction * reach * ratio, y))
	draw_polyline(points, Color(0.02, 0.2, 0.65, 0.2), 22.0, true)
	draw_polyline(points, Color(0.015, 0.018, 0.025, 0.95), 13.0, true)
	draw_polyline(points, Color(0.02, 0.3, 0.95, 0.75), 5.0, true)
	draw_polyline(points, Color(0.35, 0.9, 1.0, 0.9), 1.6, true)
	for index in range(FLAME_COUNT):
		var ratio = (float(index) + 0.5) / FLAME_COUNT
		var base = Vector2(direction * reach * ratio, -2.0)
		var phase = time * 8.0 + index * 1.73
		var height = 24.0 + sin(phase) * 7.0
		var width = 7.0 + cos(phase * 0.83) * 1.5
		var sway = sin(phase * 0.71) * 6.0
		draw_circle(base + Vector2(0.0, -5.0), 15.0, Color(0.02, 0.35, 1.0, 0.09))
		var outer = PackedVector2Array([
			base + Vector2(-width, 0.0),
			base + Vector2(-width * 0.7, -height * 0.36),
			base + Vector2(sway, -height),
			base + Vector2(width * 0.65, -height * 0.42),
			base + Vector2(width, 0.0)
		])
		draw_colored_polygon(outer, Color(0.02, 0.32, 1.0, 0.58))
		var inner = PackedVector2Array([
			base + Vector2(-width * 0.48, 0.0),
			base + Vector2(-width * 0.25, -height * 0.3),
			base + Vector2(sway * 0.35, -height * 0.68),
			base + Vector2(width * 0.42, 0.0)
		])
		draw_colored_polygon(inner, Color(0.2, 0.85, 1.0, 0.88))
		draw_circle(base + Vector2(0.0, -2.0), 2.2, Color(0.8, 0.98, 1.0, 0.9))
