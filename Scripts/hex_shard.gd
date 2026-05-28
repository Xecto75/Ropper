extends Node2D

# A single triangular shard that flies out from a destroyed hex tile.
# HexShard.tscn = Node2D root with this script. No children needed.

var _color    : Color   = Color.WHITE
var _angle    : float   = 0.0     # which of the 6 wedges
var _vel      : Vector2 = Vector2.ZERO
var _rot_vel  : float   = 0.0
var _alpha    : float   = 1.0
var _scale_v  : float   = 1.0


func launch(shard_index: int, tile_color: Color) -> void:
	_color   = tile_color
	# Each shard flies out in its wedge direction with some randomness
	var base_angle : float = deg_to_rad(60.0 * shard_index - 90.0)
	var spread     : float = deg_to_rad(randf_range(-15.0, 15.0))
	var speed      : float = randf_range(120.0, 260.0)
	_vel     = Vector2(cos(base_angle + spread), sin(base_angle + spread)) * speed
	_rot_vel = randf_range(-4.0, 4.0)
	_alpha   = 1.0
	_scale_v = randf_range(0.6, 1.0)


func _process(delta: float) -> void:
	_vel     *= 0.88                        # drag
	position += _vel * delta
	rotation += _rot_vel * delta
	_alpha   -= delta * 2.8
	modulate.a = max(0.0, _alpha)
	if _alpha <= 0.0:
		queue_free()


func _draw() -> void:
	# Triangle: center + two adjacent hex corners
	var r  : float   = 30.0 * _scale_v
	var a0 : float   = deg_to_rad(-30.0)
	var a1 : float   = deg_to_rad(30.0)
	var tri: PackedVector2Array = PackedVector2Array([
		Vector2.ZERO,
		Vector2(r * cos(a0), r * sin(a0)),
		Vector2(r * cos(a1), r * sin(a1))
	])
	draw_colored_polygon(tri, _color)
	draw_colored_polygon(tri, Color(1.0, 1.0, 1.0, 0.15))
