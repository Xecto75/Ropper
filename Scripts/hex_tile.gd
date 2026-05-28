extends Area2D

var RADIUS  : float = 22.0
var DRAW_R  : float = 18.0

var row        : int   = 0
var col        : int   = 0
var is_bomb    : bool  = false
var is_anchor  : bool  = false

var _color         : Color = Color.WHITE
var _outlined      : bool  = false
var _outline_color : Color = Color.WHITE

@onready var collision : CollisionPolygon2D = $CollisionPolygon2D


func _ready() -> void:
	collision.polygon = _hex_polygon(RADIUS)


func setup(p_row: int, p_col: int, p_color: Color, p_is_bomb: bool = false, p_radius: float = 22.0) -> void:
	row     = p_row
	col     = p_col
	is_bomb = p_is_bomb
	_color  = p_color
	RADIUS  = p_radius
	DRAW_R  = p_radius * 0.82
	collision.polygon = _hex_polygon(RADIUS)
	queue_redraw()


func set_outline(active: bool) -> void:
	if _outlined == active:
		return
	_outlined      = active
	_outline_color = Color(1.0, 0.25, 0.25) if is_bomb else Color(1.0, 1.0, 1.0)
	queue_redraw()
	if active:
		var tw : Tween = create_tween()
		tw.tween_property(self, "scale", Vector2(1.07, 1.07), 0.06)
		tw.tween_property(self, "scale", Vector2(1.0,  1.0),  0.06)


func destroy_delayed(delay: float) -> void:
	var tw : Tween = create_tween()
	tw.tween_interval(delay)
	tw.tween_callback(_do_destroy)


func flash_destroy() -> void:
	_do_destroy()


func _do_destroy() -> void:
	var tw : Tween = create_tween()
	tw.set_parallel(true)
	tw.tween_property(self, "modulate:a", 0.0,              0.08)
	tw.tween_property(self, "scale",      Vector2(1.3, 1.3), 0.08)
	await tw.finished
	queue_free()


func _draw() -> void:
	var poly : PackedVector2Array = _hex_polygon(DRAW_R)
	draw_colored_polygon(poly, _color)
	var top_poly : PackedVector2Array = PackedVector2Array([
		poly[0], poly[1], poly[2], Vector2(0.0, 0.0)
	])
	draw_colored_polygon(top_poly, Color(1.0, 1.0, 1.0, 0.08))
	if _outlined:
		for i : int in poly.size():
			draw_line(poly[i], poly[(i+1) % poly.size()], _outline_color, 2.0, true)
	if is_bomb:
		draw_circle(Vector2.ZERO, DRAW_R * 0.35, Color(0.0, 0.0, 0.0, 0.7))
		draw_arc(Vector2.ZERO, DRAW_R * 0.35, 0.0, TAU, 24, Color(1.0, 0.3, 0.3), 2.0)
		draw_line(Vector2(0.0, -DRAW_R * 0.35),
				  Vector2(DRAW_R * 0.2, -DRAW_R * 0.55),
				  Color(1.0, 0.75, 0.2), 1.5)


func _hex_polygon(r: float) -> PackedVector2Array:
	var pts : PackedVector2Array = PackedVector2Array()
	for i : int in 6:
		var angle : float = deg_to_rad(60.0 * i - 90.0)
		pts.append(Vector2(r * cos(angle), r * sin(angle)))
	return pts


func center() -> Vector2:
	return global_position
