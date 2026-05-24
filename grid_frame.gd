extends Node2D

const ROWS       : int   = 13
const COLS       : int   = 8
const HEX_RADIUS : float = 36.0
const HEX_W      : float = HEX_RADIUS * 1.7320508
const HEX_H      : float = HEX_RADIUS * 1.5
const DRAW_R     : float = 30.0
const FRAME_TOP  : float = 80.0   # extra space above for UI

const COL_FRAME  : Color = Color(0.22, 0.22, 0.32)
const COL_SHINE  : Color = Color(0.45, 0.45, 0.62, 0.7)


func _ready() -> void:
	queue_redraw()


func _hex_to_world(row: int, col: int) -> Vector2:
	var x : float = col * HEX_W
	var y : float = row * HEX_H
	if row % 2 == 1:
		x += HEX_W * 0.5
	return Vector2(x, y)


func _draw() -> void:
	var gp : Vector2 = get_parent().get_node("GridHex").position
	var vp : Vector2 = get_viewport_rect().size

	# Simple tight rectangle around the grid content
	var grid_left   : float = gp.x - DRAW_R - 4.0
	var grid_right  : float = gp.x + (COLS - 1) * HEX_W + HEX_W * 0.5 + DRAW_R + 4.0
	var grid_top    : float = gp.y - DRAW_R - 4.0
	var grid_bottom : float = gp.y + (ROWS - 1) * HEX_H + DRAW_R + 4.0

	# 4 solid rects covering screen outside the grid rectangle
	draw_rect(Rect2(0, 0,            vp.x, grid_top + FRAME_TOP),      COL_FRAME, true)
	draw_rect(Rect2(0, grid_bottom,  vp.x, vp.y - grid_bottom),        COL_FRAME, true)
	draw_rect(Rect2(0, 0,            grid_left, vp.y),                  COL_FRAME, true)
	draw_rect(Rect2(grid_right, 0,   vp.x - grid_right, vp.y),         COL_FRAME, true)

	# Shine line on inner edges
	draw_line(Vector2(grid_left,  grid_top + FRAME_TOP),
			  Vector2(grid_right, grid_top + FRAME_TOP), COL_SHINE, 1.5)
	draw_line(Vector2(grid_left,  grid_bottom),
			  Vector2(grid_right, grid_bottom),           COL_SHINE, 1.5)
	draw_line(Vector2(grid_left,  grid_top + FRAME_TOP),
			  Vector2(grid_left,  grid_bottom),           COL_SHINE, 1.5)
	draw_line(Vector2(grid_right, grid_top + FRAME_TOP),
			  Vector2(grid_right, grid_bottom),           COL_SHINE, 1.5)
