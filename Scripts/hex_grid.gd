extends Node2D

const COLS          : int   = 12
const BOMB_CHANCE   : float = 0.06
const ANCHOR_CHANCE : float = 0.10
const HEADER_H      : float = 80.0   # space reserved at top for UI
const MARGIN        : float = 8.0

# These are set dynamically in _ready based on viewport size
var ROWS        : int   = 18
var HEX_RADIUS  : float = 22.0
var HEX_W       : float = HEX_RADIUS * 1.7320508
var HEX_H       : float = HEX_RADIUS * 1.5

# Scrolling
const SCROLL_SPEED_START : float = 6.0   # pixels per second
const SCROLL_SPEED_MAX   : float = 20.0
const SCROLL_ACCEL       : float = 0.5    # speed increase per second
var _scroll_speed         : float = SCROLL_SPEED_START
var _scroll_accum         : float = 0.0   # accumulated scroll pixels

var grid   : Array = []
var colors : Array = [
	Color("ff6b6b"), Color("4d96ff"), Color("6bcb77"),
	Color("ffd166"), Color("b892ff")
]

var hex_tile_scene   : PackedScene = preload("res://Scenes/HexTile.tscn")
var hex_anchor_scene : PackedScene = preload("res://Scenes/HexAnchor.tscn")

@onready var rope_node   : Node2D = get_parent().get_node("Rope")
@onready var health_bar  : Node2D = get_parent().get_node_or_null("HealthBar")
@onready var score_label : Label  = get_parent().get_node_or_null("ScoreLabel")
@onready var fx_layer    : Node2D = get_parent().get_node_or_null("FXLayer")

var score        : int    = 0
var origin_tile  : Node2D = null
var _is_dragging : bool   = false
var _clearing    : bool   = false
var _falling      : Dictionary = {}   # tile -> true while tween active
var _grid_ready   : bool       = false  # true after create_grid finishes
var _row_offset   : int        = 0     # increments each scroll, keeps stagger consistent


func _ready() -> void:
	_compute_layout()
	create_grid()
	_grid_ready = true
	rope_node.rope_released.connect(_on_rope_released)
	if health_bar:
		health_bar.health_empty.connect(game_over)
	if fx_layer:
		var cx : float = position.x + (COLS - 1) * HEX_W * 0.5 + HEX_W * 0.25
		var cy : float = position.y + (ROWS - 1) * HEX_H * 0.5
		fx_layer.grid_center = Vector2(cx, cy)


func _process(delta: float) -> void:
	if _is_dragging:
		# Keep rope origin locked to the scrolling start tile
		if origin_tile != null and is_instance_valid(origin_tile):
			rope_node.update_origin(origin_tile.global_position)
		rope_node.simulate(delta)
		# _update_intersections()  # disabled for rope testing
		rope_node.queue_redraw()
		rope_node.set_anchors(_get_all_anchors())

	# Scroll disabled for rope testing
	# _scroll_speed = min(SCROLL_SPEED_MAX, _scroll_speed + SCROLL_ACCEL * delta)
	# _scroll_accum += _scroll_speed * delta
	# if _scroll_accum >= HEX_H:
	# 	_scroll_accum -= HEX_H
	# 	_scroll_one_row()

	# _update_tile_positions()  # disabled for rope testing

	# Check bottom row bombs
	# if not _clearing:
	# 	_check_bottom_bombs()  # disabled for rope testing


func _scroll_one_row() -> void:
	# Free ALL bottom row nodes before shifting
	for col : int in COLS:
		var t = grid[ROWS - 1][col]
		if t != null and is_instance_valid(t):
			if t.is_anchor:
				pass   # anchors are permanent, just fall off silently
			elif t.is_bomb:
				if health_bar:
					health_bar.damage(25.0)
				if fx_layer:
					fx_layer.spawn_screen_flash(Color(1.0, 0.1, 0.1, 0.8))
				t.queue_free()
			else:
				t.queue_free()
		grid[ROWS - 1][col] = null

	_row_offset += 1   # keep stagger consistent across scrolls
	# Shift all rows down by one
	for row in range(ROWS - 1, 0, -1):
		for col : int in COLS:
			grid[row][col] = grid[row - 1][col]
			if grid[row][col] != null:
				grid[row][col].row = row

	# Spawn new row at top — position will be set by _update_tile_positions
	for col : int in COLS:
		if randf() < _anchor_chance_at(0, col):
			grid[0][col] = spawn_anchor(0, col)
		else:
			grid[0][col] = spawn_tile(0, col)
		# Start invisible, fade in as they scroll into view
		if grid[0][col] != null:
			grid[0][col].modulate.a = 0.0
			var tw : Tween = create_tween()
			tw.tween_property(grid[0][col], "modulate:a", 1.0, 0.3)


func _update_tile_positions() -> void:
	# Tiles visually offset by scroll accumulation — skip ones mid-tween
	for row : int in ROWS:
		for col : int in COLS:
			var t = grid[row][col]
			if t != null and is_instance_valid(t) and not _falling.has(t):
				var target : Vector2 = hex_to_world(row, col)
				target.y += _scroll_accum
				t.position = target


# ── Hex layout ────────────────────────────────────────────────

func hex_to_world(row: int, col: int) -> Vector2:
	var x : float = col * HEX_W
	var y : float = row * HEX_H
	# Use global row offset so stagger doesn't flip when rows shift
	if (row + _row_offset) % 2 == 1:
		x += HEX_W * 0.5
	return Vector2(x, y)


func hex_neighbors(row: int, col: int) -> Array:
	var offsets : Array
	if row % 2 == 0:
		offsets = [
			Vector2i(row-1, col-1), Vector2i(row-1, col),
			Vector2i(row,   col-1), Vector2i(row,   col+1),
			Vector2i(row+1, col-1), Vector2i(row+1, col)
		]
	else:
		offsets = [
			Vector2i(row-1, col),   Vector2i(row-1, col+1),
			Vector2i(row,   col-1), Vector2i(row,   col+1),
			Vector2i(row+1, col),   Vector2i(row+1, col+1)
		]
	var result : Array = []
	for v : Vector2i in offsets:
		if v.x >= 0 and v.x < ROWS and v.y >= 0 and v.y < COLS:
			result.append(v)
	return result


# ── Grid init ─────────────────────────────────────────────────

func _compute_layout() -> void:
	var vp  : Vector2 = get_viewport_rect().size
	# Grid total width = (COLS-1)*HEX_W + HEX_W*0.5 (odd row offset) + HEX_RADIUS*2 (margins)
	# Solve: vp.x - MARGIN*2 = (COLS-1)*r*sqrt3 + r*sqrt3*0.5 + r*2
	var sqrt3   : float = 1.7320508
	HEX_RADIUS  = (vp.x - MARGIN * 2.0) / ((COLS - 1) * sqrt3 + sqrt3 * 0.5 + 2.0)
	# Scale down slightly so there's breathing room
	HEX_RADIUS *= 0.96
	HEX_W      = HEX_RADIUS * sqrt3
	HEX_H      = HEX_RADIUS * 1.5
	# How many rows fit
	var available_h : float = vp.y - HEADER_H - MARGIN * 2.0
	ROWS = int((available_h - HEX_RADIUS * 2.0) / HEX_H) + 1
	# Actual grid pixel dimensions
	var grid_w : float = (COLS - 1) * HEX_W + HEX_W * 0.5 + HEX_RADIUS * 2.0
	var grid_h : float = (ROWS - 1) * HEX_H + HEX_RADIUS * 2.0
	# Center horizontally, place below header
	position = Vector2((vp.x - grid_w) * 0.5 + HEX_RADIUS, HEADER_H + MARGIN)


func create_grid() -> void:
	for row : int in ROWS:
		grid.append([])
		for col : int in COLS:
			if randf() < _anchor_chance_at(row, col):
				grid[row].append(spawn_anchor(row, col))
			else:
				grid[row].append(spawn_tile(row, col))


func spawn_tile(row: int, col: int) -> Node2D:
	var tile    : Node2D = hex_tile_scene.instantiate()
	add_child(tile)
	# No bombs in first 8 rows at grid creation — give player time to learn
	var safe_row : bool  = not _grid_ready and row >= ROWS - 8
	var is_bomb  : bool  = false if safe_row else randf() < BOMB_CHANCE
	var color    : Color = Color(0.08, 0.08, 0.08) if is_bomb else colors[randi() % colors.size()]
	tile.setup(row, col, color, is_bomb, HEX_RADIUS)
	tile.position = hex_to_world(row, col)
	return tile


func spawn_anchor(row: int, col: int) -> Node2D:
	var anchor : Node2D = hex_anchor_scene.instantiate()
	add_child(anchor)
	anchor.position = hex_to_world(row, col)
	anchor.setup(row, col, HEX_RADIUS)
	anchor.force_update_transform()
	return anchor


func _anchor_chance_at(row: int, col: int) -> float:
	for n : Vector2i in hex_neighbors(row, col):
		if n.x >= grid.size():
			continue
		if n.y >= grid[n.x].size():
			continue
		var t = grid[n.x][n.y]
		if t != null and t.get("is_anchor") == true:
			return ANCHOR_CHANCE * 0.1
	return ANCHOR_CHANCE


# ── Input ─────────────────────────────────────────────────────

func _input(event: InputEvent) -> void:
	if _clearing:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			var tile : Node2D = _tile_at_world(get_global_mouse_position())
			if tile != null and not tile.is_anchor:
				origin_tile  = tile
				_is_dragging = true
				var anchors : Array = _get_all_anchors()
				rope_node.set_anchors(anchors)
				rope_node.start_rope(tile.global_position, anchors)
		else:
			if _is_dragging:
				_is_dragging = false
				rope_node.release_rope()
			origin_tile = null
	if event is InputEventMouseMotion and _is_dragging:
		rope_node.update_cursor(get_global_mouse_position())


# ── Bottom bomb check ─────────────────────────────────────────

func _check_bottom_bombs() -> void:
	pass   # handled in _scroll_one_row now


# ── Intersection detection ────────────────────────────────────

func _update_intersections() -> void:
	var polyline : Array = rope_node.get_polyline()
	if polyline.size() < 2:
		return
	var hit : Array = []
	if origin_tile != null and is_instance_valid(origin_tile):
		hit.append(origin_tile)
	for row : int in ROWS:
		for col : int in COLS:
			var tile : Node2D = grid[row][col]
			if tile == null or tile.is_anchor or tile == origin_tile:
				continue
			var center : Vector2 = tile.global_position
			for i : int in polyline.size() - 1:
				var closest : Vector2 = _closest_on_seg(polyline[i], polyline[i+1], center)
				if closest.distance_to(center) <= HEX_RADIUS * 0.85:
					hit.append(tile)
					break
	for row : int in ROWS:
		for col : int in COLS:
			var tile : Node2D = grid[row][col]
			if tile != null and not tile.is_anchor:
				tile.set_outline(hit.has(tile))
	rope_node.intersected_tiles = hit


# ── Rope released ─────────────────────────────────────────────

func _on_rope_released(tiles: Array, has_loop: bool, loop_poly: PackedVector2Array) -> void:
	for row : int in ROWS:
		for col : int in COLS:
			var t : Node2D = grid[row][col]
			if t != null and not t.is_anchor:
				t.set_outline(false)

	if tiles.is_empty() and not has_loop:
		return

	_clearing = true

	# ── Loop defuse: bombs inside loop polygon are defused safely ──
	var defused_bombs : Array = []
	if has_loop and loop_poly.size() >= 3:
		for row : int in ROWS:
			for col : int in COLS:
				var t : Node2D = grid[row][col]
				if t == null or not t.is_bomb or defused_bombs.has(t):
					continue
				if rope_node.point_in_polygon(t.global_position, loop_poly):
					defused_bombs.append(t)

	# Remove defused bombs from tiles list (don't penalize for them)
	var normal_tiles : Array = []
	var bomb_tiles   : Array = []
	for tile : Node2D in tiles:
		if not is_instance_valid(tile):
			continue
		if tile.is_bomb:
			if not defused_bombs.has(tile):
				bomb_tiles.append(tile)
			# defused bombs handled separately
		else:
			normal_tiles.append(tile)

	# Defused bombs — green flash, no damage, bonus score
	for bomb : Node2D in defused_bombs:
		if grid[bomb.row][bomb.col] == bomb:
			grid[bomb.row][bomb.col] = null
		bomb.flash_destroy()
		score += 50
		if fx_layer:
			fx_layer.spawn_screen_flash(Color(0.2, 0.9, 0.3, 0.3))

	# Bomb explosions — destroy neighbors, health damage
	var all_destroy : Array = normal_tiles.duplicate()
	for bomb : Node2D in bomb_tiles:
		if not all_destroy.has(bomb):
			all_destroy.append(bomb)
		for n : Vector2i in hex_neighbors(bomb.row, bomb.col):
			var nb : Node2D = grid[n.x][n.y]
			if nb != null and not nb.is_anchor and not all_destroy.has(nb):
				all_destroy.append(nb)

	# Score for normal tiles
	var count : int = normal_tiles.size()
	if count > 0:
		var combo : int = max(1, count - 1)
		score += count * 10 * combo
		_update_score_label(count, combo)
		if health_bar:
			health_bar.gain(float(count) * health_bar.REGEN_PER_TILE)
		if fx_layer:
			fx_layer.spawn_combo_text(count, combo)
			if is_instance_valid(origin_tile):
				fx_layer.spawn_ripple(origin_tile.global_position,
									  Color(1.0, 0.85, 0.3, 0.8))

	# Health damage for bombs hit directly
	if bomb_tiles.size() > 0:
		if health_bar:
			health_bar.damage(health_bar.BOMB_DAMAGE * float(bomb_tiles.size()))
		if fx_layer:
			fx_layer.spawn_screen_flash(Color(1.0, 0.15, 0.15, 0.7))

	# Snapshot normal tile data before any destruction
	var polyline      : Array = rope_node.get_polyline()
	var origin_pos    : Vector2 = origin_tile.global_position if is_instance_valid(origin_tile) else Vector2.ZERO
	var normal_data   : Array = []
	for t : Node2D in normal_tiles:
		if not is_instance_valid(t):
			continue
		var hit_idx : int = 999999
		for i : int in polyline.size() - 1:
			var closest : Vector2 = _closest_on_seg(polyline[i], polyline[i+1], t.global_position)
			if closest.distance_to(t.global_position) <= HEX_RADIUS * 0.85:
				hit_idx = i
				break
		normal_data.append({"node": t, "col": t.col, "hit_idx": hit_idx})
	normal_data.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a.hit_idx < b.hit_idx)

	# Null all destroyed tiles at once
	var cols_hit : Dictionary = {}
	for tile : Node2D in all_destroy:
		if not is_instance_valid(tile):
			continue
		if grid[tile.row][tile.col] == tile:
			grid[tile.row][tile.col] = null
			cols_hit[tile.col] = true

	# Bomb explosion — simultaneous
	var bomb_cols : Dictionary = {}
	for tile : Node2D in all_destroy:
		if not is_instance_valid(tile):
			continue
		if bomb_tiles.has(tile) or _is_bomb_neighbor(tile, bomb_tiles):
			tile.flash_destroy()
			bomb_cols[tile.col] = true
	if not bomb_cols.is_empty():
		await get_tree().create_timer(0.12).timeout
		for col : int in bomb_cols.keys():
			collapse_column(col)
		await get_tree().create_timer(0.05).timeout

	# Normal tiles chain
	var popped_cols : Dictionary = {}
	for col : int in bomb_cols.keys():
		popped_cols[col] = true
	for entry : Dictionary in normal_data:
		var tcol : int = entry.col
		var tile        = entry.node
		if is_instance_valid(tile):
			tile.flash_destroy()
		await get_tree().create_timer(0.10).timeout
		if not popped_cols.has(tcol):
			popped_cols[tcol] = true
			collapse_column(tcol)

	for col : int in cols_hit.keys():
		if not popped_cols.has(col):
			collapse_column(col)

	_clearing = false


# ── Collapse + refill from top ───────────────────────────────

func collapse_column(col: int) -> void:
	# Slide existing tiles down
	for row : int in range(ROWS - 1, -1, -1):
		if grid[row][col] == null:
			for above : int in range(row - 1, -1, -1):
				var t = grid[above][col]
				if t != null:
					grid[row][col]   = t
					grid[above][col] = null
					t.row = row
					t.col = col
					break
	# Fill remaining nulls at top with new tiles, spawning above grid
	for row : int in ROWS:
		if grid[row][col] == null:
			var tile : Node2D
			if randf() < _anchor_chance_at(row, col):
				tile = spawn_anchor(row, col)
			else:
				tile = spawn_tile(row, col)
			var target : Vector2 = hex_to_world(row, col)
			# Spawn above the visible area
			tile.position   = Vector2(target.x, hex_to_world(0, col).y - HEX_RADIUS * 3.0)
			tile.modulate.a = 0.0
			grid[row][col]  = tile
			# Animate fall to target position
			_falling[tile] = true
			var tw : Tween = create_tween()
			tw.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_IN)
			tw.tween_property(tile, "position", target, 0.25)
			tw.tween_callback(func() -> void: _falling.erase(tile))
			var tw2 : Tween = create_tween()
			tw2.tween_property(tile, "modulate:a", 1.0, 0.20)


# ── Helpers ───────────────────────────────────────────────────

func _is_bomb_neighbor(tile: Node2D, bombs: Array) -> bool:
	for bomb : Node2D in bombs:
		if not is_instance_valid(bomb):
			continue
		for n : Vector2i in hex_neighbors(bomb.row, bomb.col):
			if n.x == tile.row and n.y == tile.col:
				return true
	return false


func _get_all_anchors() -> Array:
	var result : Array = []
	for row : int in ROWS:
		for col : int in COLS:
			var t = grid[row][col]
			if t != null and t.is_anchor:
				result.append(t)
	return result


func _tile_at_world(world_pos: Vector2) -> Node2D:
	var best_dist : float  = HEX_RADIUS
	var best_tile : Node2D = null
	for row : int in ROWS:
		for col : int in COLS:
			var t = grid[row][col]
			if t == null:
				continue
			var dist : float = world_pos.distance_to(t.global_position)
			if dist < best_dist:
				best_dist = dist
				best_tile = t
	return best_tile


func _closest_on_seg(a: Vector2, b: Vector2, p: Vector2) -> Vector2:
	var ab  : Vector2 = b - a
	var len : float   = ab.length()
	if len < 0.0001:
		return a
	var t : float = clamp((p - a).dot(ab) / (len * len), 0.0, 1.0)
	return a + ab * t


func _update_score_label(count: int, combo: int) -> void:
	if score_label == null:
		return
	score_label.text = "Score: %d" % score
	if combo > 1:
		score_label.text += "  x%d COMBO!" % combo


func game_over() -> void:
	pass  # disabled for testing
