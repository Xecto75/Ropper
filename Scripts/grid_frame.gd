extends Node2D

const COL_FRAME : Color = Color(0.22, 0.22, 0.32)
const COL_SHINE : Color = Color(0.45, 0.45, 0.62, 0.7)

var _grid : Node2D = null

func _ready() -> void:
	_grid = get_parent().get_node("GridHex")
	queue_redraw()

func _draw() -> void:
	if _grid == null:
		return
	var vp   : Vector2 = get_viewport_rect().size
	var gp   : Vector2 = _grid.position
	var r    : float   = _grid.HEX_RADIUS
	var hw   : float   = _grid.HEX_W
	var hh   : float   = _grid.HEX_H
	var rows : int     = _grid.ROWS
	var cols : int     = _grid.COLS

	var grid_left   : float = gp.x - r
	var grid_right  : float = gp.x + (cols-1)*hw + hw*0.5 + r
	var grid_top    : float = gp.y - r
	var grid_bottom : float = gp.y + (rows-1)*hh + r

	# 4 solid border rects
	draw_rect(Rect2(0, 0,           vp.x, grid_top),              COL_FRAME, true)
	draw_rect(Rect2(0, grid_bottom, vp.x, vp.y - grid_bottom),   COL_FRAME, true)
	draw_rect(Rect2(0, 0,           grid_left, vp.y),             COL_FRAME, true)
	draw_rect(Rect2(grid_right, 0,  vp.x-grid_right, vp.y),      COL_FRAME, true)

	# Shine on inner edges
	draw_line(Vector2(grid_left, grid_top),  Vector2(grid_right, grid_top),  COL_SHINE, 1.5)
	draw_line(Vector2(grid_left, grid_bottom),Vector2(grid_right,grid_bottom),COL_SHINE,1.5)
	draw_line(Vector2(grid_left, grid_top),  Vector2(grid_left,  grid_bottom),COL_SHINE,1.5)
	draw_line(Vector2(grid_right,grid_top),  Vector2(grid_right, grid_bottom),COL_SHINE,1.5)
