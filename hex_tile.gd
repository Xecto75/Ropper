extends Area2D

const RADIUS   : float = 36.0
const DRAW_R   : float = 30.0

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


func setup(p_row: int, p_col: int, p_color: Color, p_is_bomb: bool = false) -> void:
	row     = p_row
	col     = p_col
	is_bomb = p_is_bomb
	_color  = p_color
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


# Chain-reaction staggered destroy — delay in seconds before popping
func destroy_delayed(delay: float) -> void:
	var tw : Tween = create_tween()
	tw.tween_interval(delay)
	tw.tween_callback(_do_destroy)


func _do_destroy() -> void:
	_spawn_shards()
	var tw : Tween = create_tween()
	tw.set_parallel(true)
	tw.tween_property(self, "modulate:a", 0.0,               0.08)
	tw.tween_property(self, "scale",      Vector2(1.3, 1.3),  0.08)
	await tw.finished
	queue_free()


func flash_destroy() -> void:
	_do_destroy()


func _spawn_shards() -> void:
	var shard_scene : PackedScene = preload("res://HexShard.tscn")
	for i : int in 6:
		var shard : Node2D = shard_scene.instantiate()
		get_parent().add_child(shard)
		shard.global_position = global_position
		shard.launch(i, _color)


func ripple_neighbors() -> void:
	# Visual pop on this tile without destroying it
	var tw : Tween = create_tween()
	tw.tween_property(self, "scale", Vector2(1.12, 1.12), 0.07)
	tw.tween_property(self, "scale", Vector2(1.0,  1.0),  0.07)


func _draw() -> void:
	var poly : PackedVector2Array = _hex_polygon(DRAW_R)
	draw_colored_polygon(poly, _color)
	var top_poly : PackedVector2Array = PackedVector2Array([
		poly[0], poly[1], poly[2], Vector2(0.0, 0.0)
	])
	draw_colored_polygon(top_poly, Color(1.0, 1.0, 1.0, 0.08))
	if _outlined:
		for i : int in poly.size():
			draw_line(poly[i], poly[(i + 1) % poly.size()], _outline_color, 3.0, true)
	if is_bomb:
		draw_circle(Vector2.ZERO, DRAW_R * 0.28, Color(0.0, 0.0, 0.0, 0.6))
		draw_arc(Vector2.ZERO, DRAW_R * 0.28, 0.0, TAU, 24, Color(1.0, 0.3, 0.3), 2.5)
		draw_line(Vector2(0.0, -DRAW_R * 0.28),
				  Vector2(DRAW_R * 0.18, -DRAW_R * 0.52),
				  Color(1.0, 0.75, 0.2), 2.0)


func _hex_polygon(r: float) -> PackedVector2Array:
	var pts : PackedVector2Array = PackedVector2Array()
	for i : int in 6:
		var angle : float = deg_to_rad(60.0 * i - 90.0)
		pts.append(Vector2(r * cos(angle), r * sin(angle)))
	return pts


func center() -> Vector2:
	return global_position
