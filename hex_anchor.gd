extends Area2D

const RADIUS    : float = 36.0
const DRAW_R    : float = 30.0
var peg_radius  : float = 20.0

var row       : int  = 0
var col       : int  = 0
var is_bomb   : bool = false
var is_anchor : bool = true

@onready var collision : CollisionPolygon2D = $CollisionPolygon2D


func _ready() -> void:
	collision.polygon = _hex_polygon(RADIUS)


func setup(p_row: int, p_col: int) -> void:
	row = p_row
	col = p_col
	queue_redraw()


func set_outline(_active: bool) -> void:
	pass

func destroy_delayed(delay: float) -> void:
	var tw : Tween = create_tween()
	tw.tween_interval(delay)
	tw.tween_callback(flash_destroy)


func flash_destroy() -> void:
	var tw : Tween = create_tween()
	tw.tween_property(self, "scale", Vector2(1.5, 1.5), 0.10)
	tw.tween_property(self, "modulate:a", 0.0,          0.10)
	await tw.finished
	queue_free()


func center() -> Vector2:
	return global_position


func _draw() -> void:
	var poly : PackedVector2Array = _hex_polygon(DRAW_R)

	# Dark hex base
	draw_colored_polygon(poly, Color(0.10, 0.10, 0.14))

	# Teal rim
	draw_polyline(poly, Color(0.0, 0.85, 0.70, 1.0), 3.0, true)
	draw_line(poly[poly.size()-1], poly[0], Color(0.0, 0.85, 0.70, 1.0), 3.0, true)

	# Peg circle
	draw_arc(Vector2.ZERO, peg_radius, 0.0, TAU, 36,
			 Color(0.0, 0.85, 0.70, 0.9), 2.5)
	draw_circle(Vector2.ZERO, 5.0, Color(0.0, 0.85, 0.70, 0.9))

	# Glow
	draw_arc(Vector2.ZERO, peg_radius + 4.0, 0.0, TAU, 36,
			 Color(0.0, 0.85, 0.70, 0.18), 6.0)


func _hex_polygon(r: float) -> PackedVector2Array:
	var pts : PackedVector2Array = PackedVector2Array()
	for i : int in 6:
		var angle : float = deg_to_rad(60.0 * i - 90.0)
		pts.append(Vector2(r * cos(angle), r * sin(angle)))
	return pts
