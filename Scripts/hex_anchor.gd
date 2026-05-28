extends Area2D

var RADIUS      : float = 22.0
var DRAW_R      : float = 18.0
var peg_radius  : float = 16.0

var row       : int  = 0
var col       : int  = 0
var is_bomb   : bool = false
var is_anchor : bool = true

@onready var collision : CollisionPolygon2D = $CollisionPolygon2D


func _ready() -> void:
	collision.polygon = _hex_polygon(RADIUS)


func setup(p_row: int, p_col: int, p_radius: float = 22.0) -> void:
	row        = p_row
	col        = p_col
	RADIUS     = p_radius
	DRAW_R     = p_radius * 0.82
	peg_radius = p_radius * 0.65
	collision.polygon = _hex_polygon(RADIUS)
	queue_redraw()


func set_outline(_active: bool) -> void:
	pass


func destroy_delayed(_delay: float) -> void:
	pass   # anchors are permanent


func flash_destroy() -> void:
	pass   # anchors are permanent — never destroyed


func _draw() -> void:
	var poly : PackedVector2Array = _hex_polygon(DRAW_R)
	draw_colored_polygon(poly, Color(0.10, 0.10, 0.14))
	for i : int in poly.size():
		draw_line(poly[i], poly[(i+1) % poly.size()],
				  Color(0.0, 0.85, 0.70, 1.0), 2.0, true)
	draw_arc(Vector2.ZERO, peg_radius, 0.0, TAU, 36,
			 Color(0.0, 0.85, 0.70, 0.9), 2.0)
	draw_circle(Vector2.ZERO, 3.0, Color(0.0, 0.85, 0.70, 0.9))
	draw_arc(Vector2.ZERO, peg_radius + 3.0, 0.0, TAU, 36,
			 Color(0.0, 0.85, 0.70, 0.15), 4.0)


func _hex_polygon(r: float) -> PackedVector2Array:
	var pts : PackedVector2Array = PackedVector2Array()
	for i : int in 6:
		var angle : float = deg_to_rad(60.0 * i - 90.0)
		pts.append(Vector2(r * cos(angle), r * sin(angle)))
	return pts


func center() -> Vector2:
	return global_position


# Called by rope each frame with incoming/outgoing directions relative to this anchor
func update_arc(peg_r: float, entry_angle: float, exit_angle: float) -> void:
	var arc : Node2D = get_node_or_null("AnchorArc")
	if arc == null:
		return
	arc.activate(peg_r, entry_angle, exit_angle)


func clear_arc() -> void:
	var arc : Node2D = get_node_or_null("AnchorArc")
	if arc != null:
		arc.deactivate()
