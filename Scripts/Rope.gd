extends Node2D

const ROPE_WIDTH  : float = 8.0
const ARC_STEPS   : int   = 40
const SNAP_DIST   : float = 8.0

const COLOR_NORMAL : Color = Color(0.85, 0.70, 0.40, 1.0)
const COLOR_BOMB   : Color = Color(1.00, 0.25, 0.25, 1.0)
const LOOP_FILL    : Color = Color(0.3, 0.9, 0.5, 0.20)
const LOOP_BORDER  : Color = Color(0.3, 0.9, 0.5, 0.85)

var is_dragging       : bool  = false
var _origin           : Vector2 = Vector2.ZERO
var _cursor           : Vector2 = Vector2.ZERO
var _anchors          : Array   = []
var intersected_tiles : Array   = []
var active_anchors    : Array   = []
var _rope_path        : Array   = []

# Each entry: {
#   anchor,
#   center,   # updated each frame (anchor scrolls)
#   radius,   # peg_radius + ROPE_WIDTH*0.5
#   side,     # +1 or -1, LOCKED at wrap time, never changes
#   impact,   # Vector2 — the point on the segment where wrap was detected, LOCKED
# }
var _wrapped : Array = []

var loop_detected : bool               = false
var loop_polygon  : PackedVector2Array = PackedVector2Array()

signal rope_released(tiles: Array, has_loop: bool, loop_poly: PackedVector2Array)


func start_rope(world_pos: Vector2, anchors: Array) -> void:
	is_dragging       = true
	_origin           = world_pos
	_cursor           = world_pos
	_anchors          = anchors
	_wrapped          = []
	intersected_tiles = []
	active_anchors    = []
	loop_detected     = false
	loop_polygon      = PackedVector2Array()
	_rebuild()
	queue_redraw()


func update_origin(world_pos: Vector2) -> void:
	if not is_dragging:
		return
	_origin = world_pos
	_rebuild()
	queue_redraw()


func update_cursor(world_pos: Vector2) -> void:
	if not is_dragging:
		return
	_cursor = world_pos
	_try_wrap()
	_try_unwrap()
	_rebuild()
	_update_loop()
	queue_redraw()


func release_rope() -> void:
	if not is_dragging:
		return
	is_dragging = false
	emit_signal("rope_released", intersected_tiles.duplicate(),
				 loop_detected, loop_polygon)
	await get_tree().create_timer(3.0).timeout
	_rope_path        = []
	_wrapped          = []
	intersected_tiles = []
	active_anchors    = []
	loop_detected     = false
	loop_polygon      = PackedVector2Array()
	queue_redraw()


func set_anchors(anchors: Array) -> void:
	_anchors = anchors


func simulate(_delta: float) -> void:
	pass


# ── Tangent point ─────────────────────────────────────────────
# Returns the point on circle (center, radius) where a taut rope
# from from_pt touches. side=+1 or -1 picks which of the two tangents.
# Formula verified in interactive debugger:
#   baseAngle = atan2 from CENTER toward from_pt
#   alpha     = acos(radius / distance)
#   touch     = center + (baseAngle + side*alpha)

func _tangent_pt(from_pt: Vector2, center: Vector2, radius: float, side: float) -> Vector2:
	var dx  : float = from_pt.x - center.x
	var dy  : float = from_pt.y - center.y
	var d   : float = sqrt(dx*dx + dy*dy)
	if d <= radius:
		return center + Vector2(dx, dy).normalized() * radius
	var base_angle : float = atan2(dy, dx)
	var alpha      : float = acos(clamp(radius / d, 0.0, 1.0))
	var angle      : float = base_angle + side * alpha
	return center + Vector2(cos(angle), sin(angle)) * radius


# ── Wrap / unwrap ─────────────────────────────────────────────

func _prev_exit() -> Vector2:
	# The point the rope comes FROM when approaching the next peg
	if _wrapped.is_empty():
		return _origin
	var w = _wrapped.back()
	# exit = tangent from CURSOR side, using -side
	return _tangent_pt(_cursor, w.center, w.radius, -w.side)


func _try_wrap() -> void:
	var from : Vector2 = _prev_exit()
	for anchor in _anchors:
		if not is_instance_valid(anchor):
			continue
		if _is_wrapped(anchor):
			continue
		var center : Vector2 = anchor.global_position
		var radius : float   = anchor.peg_radius + ROPE_WIDTH * 0.5
		var closest : Vector2 = _closest_on_seg(from, _cursor, center)
		if closest.distance_to(center) <= radius + SNAP_DIST:
			# Compute side from cross product at moment of impact — LOCK IT
			var dc    : Vector2 = center - from
			var dp    : Vector2 = _cursor - from
			var cross : float   = dc.x * dp.y - dc.y * dp.x
			var side  : float   = -1.0 if cross >= 0.0 else 1.0
			_wrapped.append({
				"anchor": anchor,
				"center": center,
				"radius": radius,
				"side":   side,
				"impact": closest  # locked, never recalculated
			})
			break


func _try_unwrap() -> void:
	if _wrapped.is_empty():
		return
	var w = _wrapped.back()
	if not is_instance_valid(w.anchor):
		_wrapped.pop_back()
		return
	w.center = w.anchor.global_position
	w.radius = w.anchor.peg_radius + ROPE_WIDTH * 0.5
	var from_pt : Vector2 = _origin if _wrapped.size() < 2 else _tangent_pt(
		_cursor, _wrapped[_wrapped.size()-2].center,
		_wrapped[_wrapped.size()-2].radius, -_wrapped[_wrapped.size()-2].side)
	var entry : Vector2 = _tangent_pt(from_pt, w.center, w.radius,  w.side)
	var exit  : Vector2 = _tangent_pt(_cursor, w.center, w.radius, -w.side)
	var a1 : float = atan2(entry.y - w.center.y, entry.x - w.center.x)
	var a2 : float = atan2(exit.y  - w.center.y, exit.x  - w.center.x)
	var sw : float = a2 - a1
	if w.side > 0 and sw < 0: sw += TAU
	if w.side < 0 and sw > 0: sw -= TAU
	# When entry and exit converge, sw goes to TAU (full circle) not 0 due to wrapping.
	# Treat near-TAU as near-zero: cursor came back to where it started.
	if abs(sw) < 0.15 or abs(abs(sw) - TAU) < 0.15:
		_wrapped.pop_back()

func _is_wrapped(anchor) -> bool:
	for w in _wrapped:
		if w.anchor == anchor: return true
	return false


# ── Rebuild rope path ─────────────────────────────────────────

func _rebuild() -> void:
	# Update scrolling centers but never side
	for w in _wrapped:
		if is_instance_valid(w.anchor):
			w.center = w.anchor.global_position
			w.radius = w.anchor.peg_radius + ROPE_WIDTH * 0.5

	var pts : Array = [_origin]

	for i : int in _wrapped.size():
		var w = _wrapped[i]
		if not is_instance_valid(w.anchor):
			continue

		# from_pt = where rope comes from (origin, or exit of previous peg)
		var from_pt : Vector2
		if i == 0:
			from_pt = _origin
		else:
			var pw = _wrapped[i - 1]
			from_pt = _tangent_pt(_cursor, pw.center, pw.radius, -pw.side)

		# to_pt = where rope goes next (cursor, or entry of next peg)
		var to_pt : Vector2
		if i == _wrapped.size() - 1:
			to_pt = _cursor
		else:
			var nw = _wrapped[i + 1]
			to_pt = _tangent_pt(from_pt, nw.center, nw.radius, nw.side)

		# entry: tangent from from_pt side (locked side)
		var entry : Vector2 = _tangent_pt(from_pt, w.center, w.radius,  w.side)
		# exit:  tangent from cursor/next side (-side)
		var exit  : Vector2 = _tangent_pt(to_pt,   w.center, w.radius, -w.side)

		pts.append(entry)

		# Arc from entry to exit, sweep direction locked by side
		var a1 : float = atan2(entry.y - w.center.y, entry.x - w.center.x)
		var a2 : float = atan2(exit.y  - w.center.y, exit.x  - w.center.x)
		var sw : float = a2 - a1
		if w.side > 0 and sw < 0: sw += TAU
		if w.side < 0 and sw > 0: sw -= TAU

		for s : int in range(1, ARC_STEPS):
			var t     : float = float(s) / float(ARC_STEPS)
			var angle : float = a1 + sw * t
			pts.append(w.center + Vector2(cos(angle), sin(angle)) * w.radius)

		pts.append(exit)

	pts.append(_cursor)
	_rope_path = pts

	active_anchors = []
	for w in _wrapped:
		active_anchors.append({"anchor": w.anchor, "center": w.center, "seg_idx": 0})


# ── Loop detection ────────────────────────────────────────────

func _update_loop() -> void:
	var pts : Array = _rope_path
	var n   : int   = pts.size()
	if n < 3:
		loop_detected = false
		loop_polygon  = PackedVector2Array()
		return
	var area : float = 0.0
	for i : int in n - 1:
		area += pts[i].x * pts[i+1].y - pts[i+1].x * pts[i].y
	area += pts[n-1].x * pts[0].y - pts[0].x * pts[n-1].y
	area *= 0.5
	if abs(area) >= 1500.0:
		loop_detected = true
		loop_polygon  = PackedVector2Array()
		for p : Vector2 in pts:
			loop_polygon.append(p)
	else:
		loop_detected = false
		loop_polygon  = PackedVector2Array()


func point_in_polygon(p: Vector2, poly: PackedVector2Array) -> bool:
	var n      : int  = poly.size()
	var inside : bool = false
	var j      : int  = n - 1
	for i : int in n:
		var xi : float = poly[i].x
		var yi : float = poly[i].y
		var xj : float = poly[j].x
		var yj : float = poly[j].y
		if ((yi > p.y) != (yj > p.y)) and \
		   (p.x < (xj - xi) * (p.y - yi) / (yj - yi) + xi):
			inside = not inside
		j = i
	return inside


# ── Drawing ───────────────────────────────────────────────────

func _draw() -> void:
	if _rope_path.size() < 2:
		return
	draw_set_transform(-global_position, 0.0, Vector2.ONE)

	var has_bomb : bool = false
	for t in intersected_tiles:
		if is_instance_valid(t) and t.is_bomb:
			has_bomb = true
			break
	var color : Color = COLOR_BOMB if has_bomb else COLOR_NORMAL

	if loop_detected and loop_polygon.size() >= 3:
		draw_colored_polygon(loop_polygon, LOOP_FILL)
		for i : int in loop_polygon.size():
			draw_line(loop_polygon[i], loop_polygon[(i+1) % loop_polygon.size()],
					  LOOP_BORDER, 2.0, true)

	for i : int in _rope_path.size() - 1:
		draw_line(_rope_path[i] + Vector2(2,2), _rope_path[i+1] + Vector2(2,2),
				  Color(0,0,0,0.2), ROPE_WIDTH + 2.0, true)
	for i : int in _rope_path.size() - 1:
		var t : float = float(i) / float(_rope_path.size() - 1)
		draw_line(_rope_path[i], _rope_path[i+1],
				  color.lerp(color.darkened(0.3), t), ROPE_WIDTH, true)

	draw_circle(_origin, ROPE_WIDTH * 0.7, color)
	draw_circle(_origin, ROPE_WIDTH * 0.35, Color.WHITE)


func _closest_on_seg(a: Vector2, b: Vector2, p: Vector2) -> Vector2:
	var ab  : Vector2 = b - a
	var len : float   = ab.length()
	if len < 0.0001:
		return a
	var t : float = clamp((p - a).dot(ab) / (len * len), 0.0, 1.0)
	return a + ab * t


func get_polyline() -> Array:
	return _rope_path.duplicate()
