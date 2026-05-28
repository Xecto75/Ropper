extends Node2D

const ARC_THICKNESS : float = 6.0
const ARC_SEGMENTS  : int   = 32
const COLOR_ACTIVE  : Color = Color(0.85, 0.70, 0.40, 0.95)
const COLOR_GLOW    : Color = Color(0.85, 0.70, 0.40, 0.18)

var _active      : bool  = false
var _entry_angle : float = 0.0   # LOCKED — where rope arrived
var _exit_angle  : float = 0.0   # DYNAMIC — where rope leaves toward cursor
var _peg_radius  : float = 12.0


func activate(peg_radius: float, entry_angle: float, exit_angle: float) -> void:
	_active      = true
	_peg_radius  = peg_radius
	_entry_angle = entry_angle
	_exit_angle  = exit_angle
	queue_redraw()


func deactivate() -> void:
	if not _active:
		return
	_active = false
	queue_redraw()


func _draw() -> void:
	if not _active:
		return

	var r_inner : float = max(_peg_radius - ARC_THICKNESS * 0.5, 1.0)
	var r_outer : float = _peg_radius + ARC_THICKNESS * 0.5

	# Sweep from entry to exit — shorter path
	var sweep : float = _exit_angle - _entry_angle
	while sweep > PI:  sweep -= TAU
	while sweep < -PI: sweep += TAU

	# Build donut polygon
	var outer : PackedVector2Array = PackedVector2Array()
	var inner : PackedVector2Array = PackedVector2Array()
	for i : int in ARC_SEGMENTS + 1:
		var t     : float   = float(i) / float(ARC_SEGMENTS)
		var angle : float   = _entry_angle + sweep * t
		var dir   : Vector2 = Vector2(cos(angle), sin(angle))
		outer.append(dir * r_outer)
		inner.append(dir * r_inner)

	var poly : PackedVector2Array = PackedVector2Array()
	for p : Vector2 in outer:
		poly.append(p)
	for i : int in range(inner.size() - 1, -1, -1):
		poly.append(inner[i])
	draw_colored_polygon(poly, COLOR_ACTIVE)

	# Glow ring
	var glow : PackedVector2Array = PackedVector2Array()
	for i : int in ARC_SEGMENTS + 1:
		var t     : float   = float(i) / float(ARC_SEGMENTS)
		var angle : float   = _entry_angle + sweep * t
		glow.append(Vector2(cos(angle), sin(angle)) * (r_outer + 5.0))
	for i : int in range(ARC_SEGMENTS, -1, -1):
		var t     : float   = float(i) / float(ARC_SEGMENTS)
		var angle : float   = _entry_angle + sweep * t
		glow.append(Vector2(cos(angle), sin(angle)) * (r_outer + 9.0))
	draw_colored_polygon(glow, COLOR_GLOW)
