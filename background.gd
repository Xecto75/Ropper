extends Node2D

const ROWS         : int   = 13
const COLS       : int   = 8
const HEX_RADIUS : float = 36.0
const HEX_W      : float = HEX_RADIUS * 1.7320508
const HEX_H      : float = HEX_RADIUS * 1.5
const DRAW_R     : float = 30.0

const COL_BG         : Color = Color(0.08, 0.08, 0.12)
const COL_GRID_BG    : Color = Color(0.11, 0.11, 0.16)
const COL_HEX_SLOT   : Color = Color(0.06, 0.06, 0.10)
const COL_HEX_SLOT_B : Color = Color(0.20, 0.20, 0.30, 0.5)


func _ready() -> void:
	queue_redraw()


func _draw() -> void:
	var vp : Vector2 = get_viewport_rect().size
	var gp : Vector2 = get_parent().get_node("GridHex").position

	# Full screen background
	draw_rect(Rect2(Vector2.ZERO, vp), COL_BG, true)

	# Grid background panel — tight around hex centers
	var min_x : float = gp.x - HEX_RADIUS
	var min_y : float = gp.y - HEX_RADIUS
	var max_x : float = gp.x + (COLS - 1) * HEX_W + HEX_W * 0.5 + HEX_RADIUS
	var max_y : float = gp.y + (ROWS - 1) * HEX_H + HEX_RADIUS
	draw_rect(Rect2(min_x, min_y, max_x - min_x, max_y - min_y), COL_GRID_BG, true)

	# Hex slots — only inner grid, no edge ring (GridFrame handles edges)
	for row : int in ROWS:
		for col : int in COLS:
			var pos : Vector2 = gp + _hex_to_world(row, col)
			_draw_hex(pos, DRAW_R - 1.0, COL_HEX_SLOT)
			_draw_hex_border(pos, DRAW_R - 1.0, COL_HEX_SLOT_B, 1.0)


func _hex_to_world(row: int, col: int) -> Vector2:
	var x : float = col * HEX_W
	var y : float = row * HEX_H
	if row % 2 == 1:
		x += HEX_W * 0.5
	return Vector2(x, y)


func _hex_polygon(center: Vector2, r: float) -> PackedVector2Array:
	var pts : PackedVector2Array = PackedVector2Array()
	for i : int in 6:
		var angle : float = deg_to_rad(60.0 * i - 90.0)
		pts.append(center + Vector2(r * cos(angle), r * sin(angle)))
	return pts


func _draw_hex(center: Vector2, r: float, color: Color) -> void:
	draw_colored_polygon(_hex_polygon(center, r), color)


func _draw_hex_border(center: Vector2, r: float, color: Color, width: float) -> void:
	var poly : PackedVector2Array = _hex_polygon(center, r)
	for i : int in poly.size():
		draw_line(poly[i], poly[(i + 1) % poly.size()], color, width, true)
