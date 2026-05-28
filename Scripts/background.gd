extends Node2D

const COL_BG         : Color = Color(0.08, 0.08, 0.12)
const COL_GRID_BG    : Color = Color(0.11, 0.11, 0.16)
const COL_HEX_SLOT   : Color = Color(0.06, 0.06, 0.10)
const COL_HEX_SLOT_B : Color = Color(0.20, 0.20, 0.30, 0.5)

var _grid : Node2D = null

func _ready() -> void:
	_grid = get_parent().get_node("GridHex")
	queue_redraw()

func _draw() -> void:
	var vp : Vector2 = get_viewport_rect().size
	draw_rect(Rect2(Vector2.ZERO, vp), COL_BG, true)
	if _grid == null:
		return
	var r  : float = _grid.HEX_RADIUS
	var hw : float = _grid.HEX_W
	var hh : float = _grid.HEX_H
	var gp : Vector2 = _grid.position
	var rows : int = _grid.ROWS
	var cols : int = _grid.COLS
	var min_x : float = gp.x - r
	var min_y : float = gp.y - r
	var max_x : float = gp.x + (cols-1)*hw + hw*0.5 + r
	var max_y : float = gp.y + (rows-1)*hh + r
	draw_rect(Rect2(min_x, min_y, max_x-min_x, max_y-min_y), COL_GRID_BG, true)
	for row : int in rows:
		for col : int in cols:
			var pos : Vector2 = gp + _hw(row, col, hw, hh)
			_draw_hex(pos, _grid.HEX_RADIUS * 0.82, COL_HEX_SLOT)
			_draw_hex_border(pos, _grid.HEX_RADIUS * 0.82, COL_HEX_SLOT_B, 1.0)

func _hw(row: int, col: int, hw: float, hh: float) -> Vector2:
	var x : float = col * hw
	var y : float = row * hh
	if (row + _grid._row_offset) % 2 == 1:
		x += hw * 0.5
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
		draw_line(poly[i], poly[(i+1) % poly.size()], color, width, true)
