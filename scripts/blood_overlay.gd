extends Control

var drips: Array[Vector3] = []
var splatters: Array[Vector3] = []
var central_drops: Array[Vector3] = []

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var random = RandomNumberGenerator.new()
	random.seed = 9137
	for index in range(24):
		drips.append(Vector3(random.randf(), random.randf_range(7.0, 25.0), random.randf_range(45.0, 230.0)))
	for index in range(42):
		splatters.append(Vector3(random.randf(), random.randf(), random.randf_range(2.0, 16.0)))
	for index in range(55):
		central_drops.append(Vector3(random.randf_range(0.26, 0.74), random.randf_range(0.18, 0.55), random.randf_range(3.0, 24.0)))

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()

func _draw() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return
	draw_rect(Rect2(Vector2.ZERO, Vector2(size.x, 20.0)), Color(0.24, 0.002, 0.008, 0.88))
	for drip in drips:
		var x = drip.x * size.x
		var width = drip.y
		var height = drip.z
		var color = Color(0.32, 0.004, 0.012, 0.82)
		var polygon = PackedVector2Array([
			Vector2(x - width * 0.5, 0.0),
			Vector2(x + width * 0.5, 0.0),
			Vector2(x + width * 0.24, height * 0.7),
			Vector2(x, height),
			Vector2(x - width * 0.24, height * 0.7)
		])
		draw_colored_polygon(polygon, color)
		draw_circle(Vector2(x, height * 0.88), width * 0.3, Color(0.42, 0.005, 0.012, 0.78))
	for drop in splatters:
		var point = Vector2(drop.x * size.x, drop.y * size.y)
		draw_circle(point, drop.z, Color(0.25, 0.002, 0.008, 0.5))
		draw_line(point, point + Vector2(drop.z * 1.8, drop.z * 2.8), Color(0.36, 0.003, 0.01, 0.42), 2.0, true)
	for drop in central_drops:
		var point = Vector2(drop.x * size.x, drop.y * size.y)
		draw_circle(point, drop.z, Color(0.38, 0.003, 0.012, 0.58))
	for index in range(14):
		var x = size.x * float(index) / 13.0
		var radius = 28.0 + 18.0 * sin(index * 2.1)
		draw_circle(Vector2(x, size.y + 6.0), radius, Color(0.3, 0.002, 0.008, 0.78))
