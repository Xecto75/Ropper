extends Node2D

# ── Tune these ────────────────────────────────────────────────
const SEG_LEN      : float = 12.0    # pixels per segment — constant, controls density
const GRAVITY      : float = 1800.0
const DAMPING      : float = 0.97
const ITERATIONS   : int   = 12
const SUBSTEPS     : int   = 4
const ROPE_SLACK   : float = 0.9     # <1 = taut, >1 = saggy
const ROPE_WIDTH   : float = 5.0
const COLOR_NORMAL : Color = Color(0.85, 0.70, 0.40, 1.0)
const COLOR_BOMB   : Color = Color(1.00, 0.25, 0.25, 1.0)

var is_dragging       : bool  = false
var points            : Array = []
var prev_points       : Array = []
var _num_points       : int   = 2     # grows with path length
var intersected_tiles : Array = []
var _anchors          : Array = []
var _target_points    : int   = 2     # desired count, we lerp toward it

# Anchors the rope is currently wrapped around (updated each frame)
var active_anchors : Array = []

signal rope_released(tiles: Array, anchors_used: Array)


func start_rope(world_pos: Vector2, anchors: Array) -> void:
	is_dragging       = true
	intersected_tiles = []
	active_anchors    = []
	_anchors          = anchors
	_num_points       = 2
	_target_points    = 2
	points.clear()
	prev_points.clear()
	# Start with just 2 points — both at origin
	points.append(world_pos)
	prev_points.append(world_pos)
	points.append(world_pos)
	prev_points.append(world_pos)
	queue_redraw()


func update_cursor(world_pos: Vector2) -> void:
	if not is_dragging:
		return

	# Pin tail to cursor
	points[_num_points - 1]      = world_pos
	prev_points[_num_points - 1] = world_pos

	# Detect touched anchors and measure path
	active_anchors = _find_touched_anchors()
	var path : float = _measure_path(world_pos, active_anchors)

	# How many segments does this path need at constant density?
	_target_points = max(2, int(path * ROPE_SLACK / SEG_LEN) + 1)

	# Grow: add points near the tail when we need more
	while _num_points < _target_points:
		var tail     : Vector2 = points[_num_points - 1]
		var pre_tail : Vector2 = points[_num_points - 2]
		# Insert new point just before tail, slightly offset
		var new_pos  : Vector2 = tail.lerp(pre_tail, 0.1)
		points.insert(_num_points - 1, new_pos)
		prev_points.insert(_num_points - 1, new_pos)
		_num_points += 1

	# Shrink: remove points from tail when we need fewer
	# Only remove gradually — 1 per frame max — so tension never spikes
	if _num_points > _target_points + 1:
		points.remove_at(_num_points - 2)
		prev_points.remove_at(_num_points - 2)
		_num_points -= 1
		# Re-pin tail
		points[_num_points - 1]      = world_pos
		prev_points[_num_points - 1] = world_pos


func _find_touched_anchors() -> Array:
	var touched : Array = []
	for anchor : Node2D in _anchors:
		if not is_instance_valid(anchor):
			continue
		var center : Vector2 = anchor.global_position
		var radius : float   = anchor.peg_radius + ROPE_WIDTH * 0.5
		for i : int in _num_points - 1:
			var closest : Vector2 = _closest_point_on_segment(points[i], points[i + 1], center)
			if closest.distance_to(center) <= radius + 2.0:
				touched.append({ "anchor": anchor, "center": center, "seg_idx": i })
				break
	touched.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a.seg_idx < b.seg_idx
	)
	return touched


func _measure_path(cursor: Vector2, touched: Array) -> float:
	if touched.is_empty():
		return points[0].distance_to(cursor)
	var total  : float   = 0.0
	var prev_p : Vector2 = points[0]
	for entry : Dictionary in touched:
		total  += prev_p.distance_to(entry.center)
		prev_p  = entry.center
	total += prev_p.distance_to(cursor)
	return total


func release_rope() -> void:
	if not is_dragging:
		return
	is_dragging = false
	var used : Array = []
	for entry : Dictionary in active_anchors:
		used.append(entry.anchor)
	emit_signal("rope_released", intersected_tiles.duplicate(), used)
	points.clear()
	prev_points.clear()
	intersected_tiles = []
	active_anchors    = []
	_num_points       = 2
	queue_redraw()


func set_anchors(anchors: Array) -> void:
	_anchors = anchors


func simulate(delta: float) -> void:
	if not is_dragging or _num_points < 2:
		return
	var sub_dt : float = delta / float(SUBSTEPS)
	for _s : int in SUBSTEPS:
		_step(sub_dt)
	queue_redraw()


func _step(dt: float) -> void:
	# 1. Verlet integrate — skip pinned endpoints
	for i : int in range(1, _num_points - 1):
		var pos  : Vector2 = points[i]
		var prev : Vector2 = prev_points[i]
		var vel  : Vector2 = (pos - prev) * DAMPING
		prev_points[i] = pos
		points[i]      = pos + vel + Vector2(0.0, GRAVITY * dt * dt)

	points[0]              = prev_points[0]
	points[_num_points - 1] = prev_points[_num_points - 1]

	# 2. Constraint iterations
	for _iter : int in ITERATIONS:
		for i : int in _num_points - 1:
			var a   : Vector2 = points[i]
			var b   : Vector2 = points[i + 1]
			var d   : Vector2 = b - a
			var len : float   = d.length()
			if len < 0.0001:
				continue
			var diff       : float   = (len - SEG_LEN) / len
			var correction : Vector2 = d * 0.5 * diff
			if i > 0:
				points[i]     += correction
			if i < _num_points - 1:
				points[i + 1] -= correction

		points[0]               = prev_points[0]
		points[_num_points - 1] = prev_points[_num_points - 1]

		# Anchor collisions every iteration
		for anchor : Node2D in _anchors:
			if not is_instance_valid(anchor):
				continue
			var center : Vector2 = anchor.global_position
			var radius : float   = anchor.peg_radius + ROPE_WIDTH * 0.5
			for i : int in range(1, _num_points - 1):
				_push_point_out(i, center, radius)
			for i : int in _num_points - 1:
				_resolve_segment(i, i + 1, center, radius)

		points[0]               = prev_points[0]
		points[_num_points - 1] = prev_points[_num_points - 1]


func _push_point_out(i: int, center: Vector2, radius: float) -> void:
	var diff : Vector2 = points[i] - center
	var dist : float   = diff.length()
	if dist >= radius or dist < 0.0001:
		return
	points[i] = center + diff.normalized() * radius
	var pd    : Vector2 = prev_points[i] - center
	var pdist : float   = pd.length()
	if pdist < radius:
		prev_points[i] = center + (pd.normalized() if pdist > 0.0001 else diff.normalized()) * radius


func _resolve_segment(ia: int, ib: int, center: Vector2, radius: float) -> void:
	var closest : Vector2 = _closest_point_on_segment(points[ia], points[ib], center)
	if closest.distance_to(center) >= radius or closest.distance_to(center) < 0.0001:
		return
	if ia > 0:
		_push_point_out(ia, center, radius)
	if ib < _num_points - 1:
		_push_point_out(ib, center, radius)


func _closest_point_on_segment(a: Vector2, b: Vector2, p: Vector2) -> Vector2:
	var ab  : Vector2 = b - a
	var len : float   = ab.length()
	if len < 0.0001:
		return a
	var t : float = clamp((p - a).dot(ab) / (len * len), 0.0, 1.0)
	return a + ab * t


func _draw() -> void:
	if not is_dragging or _num_points < 2:
		return
	# Rope points are in global space but _draw works in local space.
	# Cancel out this node's transform so we draw in global space.
	draw_set_transform(-global_position, 0.0, Vector2.ONE)
	var has_bomb : bool = false
	for t : Node2D in intersected_tiles:
		if t.is_bomb:
			has_bomb = true
			break
	var color : Color = COLOR_BOMB if has_bomb else COLOR_NORMAL

	for i : int in _num_points - 1:
		draw_line(
			points[i]     + Vector2(2.0, 2.0),
			points[i + 1] + Vector2(2.0, 2.0),
			Color(0.0, 0.0, 0.0, 0.18), ROPE_WIDTH + 2.0, true
		)
	for i : int in _num_points - 1:
		var t : float = float(i) / float(_num_points - 1)
		var c : Color = color.lerp(color.darkened(0.3), t)
		draw_line(points[i], points[i + 1], c, ROPE_WIDTH, true)

	draw_circle(points[0], 6.0, color)
	draw_circle(points[0], 3.5, Color.WHITE)


func get_polyline() -> Array:
	return points.slice(0, _num_points)
