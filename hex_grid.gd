extends Node2D

const COLS         : int   = 8
const ROWS         : int   = 13
const HEX_RADIUS   : float = 36.0
const BOMB_CHANCE  : float = 0.12
const ANCHOR_CHANCE: float = 0.08
const HEX_W        : float = HEX_RADIUS * 1.7320508
const HEX_H        : float = HEX_RADIUS * 1.5

var grid   : Array = []
var colors : Array = [
	Color("ff6b6b"), Color("4d96ff"), Color("6bcb77"),
	Color("ffd166"), Color("b892ff")
]

var hex_tile_scene   : PackedScene = preload("res://HexTile.tscn")
var hex_anchor_scene : PackedScene = preload("res://HexAnchor.tscn")

@onready var rope_node   : Node2D = get_parent().get_node("Rope")
@onready var score_label : Label  = get_parent().get_node_or_null("ScoreLabel")
@onready var health_bar  : Node2D = get_parent().get_node_or_null("HealthBar")
@onready var fx_layer    : Node2D = get_parent().get_node_or_null("FXLayer")

var score        : int    = 0
var origin_tile  : Node2D = null
var _is_dragging : bool   = false
var _clearing    : bool   = false


func _ready() -> void:
	create_grid()
	rope_node.rope_released.connect(_on_rope_released)
	if health_bar:
		health_bar.health_empty.connect(game_over)
	# Tell FXLayer where grid center is
	if fx_layer:
		var cx : float = position.x + (COLS - 1) * HEX_W * 0.5 + HEX_W * 0.25
		var cy : float = position.y + (ROWS - 1) * HEX_H * 0.5
		fx_layer.grid_center = Vector2(cx, cy)


func _process(delta: float) -> void:
	if _is_dragging:
		rope_node.simulate(delta)
		_update_intersections()
		rope_node.queue_redraw()
		rope_node.set_anchors(_get_all_anchors())
	if not _clearing:
		_check_bottom_bombs()


# ── Hex layout ────────────────────────────────────────────────

func hex_to_world(row: int, col: int) -> Vector2:
	var x : float = col * HEX_W
	var y : float = row * HEX_H
	if row % 2 == 1:
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

func _anchor_chance_at(row: int, col: int) -> float:
	for n : Vector2i in hex_neighbors(row, col):
		# Guard: row may not exist yet, or col may not be filled yet
		if n.x >= grid.size():
			continue
		if n.y >= grid[n.x].size():
			continue
		var t = grid[n.x][n.y]   # untyped to avoid null cast issues
		if t != null and t.get("is_anchor") == true:
			return ANCHOR_CHANCE * 0.1
	return ANCHOR_CHANCE


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
	var is_bomb : bool   = randf() < BOMB_CHANCE
	var color   : Color  = Color(0.08, 0.08, 0.08) if is_bomb else colors[randi() % colors.size()]
	tile.setup(row, col, color, is_bomb)
	tile.position = hex_to_world(row, col)
	return tile


func spawn_anchor(row: int, col: int) -> Node2D:
	var anchor : Node2D = hex_anchor_scene.instantiate()
	add_child(anchor)
	anchor.position = hex_to_world(row, col)
	anchor.setup(row, col)
	anchor.force_update_transform()
	return anchor


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


# ── Bomb at bottom — defuse ───────────────────────────────────

func _check_bottom_bombs() -> void:
	for col : int in COLS:
		var t : Node2D = grid[ROWS - 1][col]
		if t != null and not t.is_anchor and t.is_bomb:
			grid[ROWS - 1][col] = null
			_clearing = true
			t.flash_destroy()
			await get_tree().create_timer(0.15).timeout
			collapse_column(col)
			await get_tree().create_timer(0.20).timeout
			_clearing = false
			return


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

func _on_rope_released(tiles: Array, anchors_used: Array) -> void:
	for row : int in ROWS:
		for col : int in COLS:
			var t : Node2D = grid[row][col]
			if t != null and not t.is_anchor:
				t.set_outline(false)

	if tiles.is_empty():
		return

	_clearing = true

	# Ripple from origin
	if fx_layer and is_instance_valid(origin_tile):
		fx_layer.spawn_ripple(origin_tile.global_position, Color(1.0, 0.85, 0.3, 0.8))

	# Separate bombs from normal
	var normal_tiles : Array = []
	var bomb_tiles   : Array = []
	for tile : Node2D in tiles:
		if tile.is_bomb:
			bomb_tiles.append(tile)
		else:
			normal_tiles.append(tile)

	# Bombs explode — collect neighbors
	var all_destroy : Array = normal_tiles.duplicate()
	for bomb : Node2D in bomb_tiles:
		if not all_destroy.has(bomb):
			all_destroy.append(bomb)
		for n : Vector2i in hex_neighbors(bomb.row, bomb.col):
			var nb : Node2D = grid[n.x][n.y]
			if nb != null and not all_destroy.has(nb):
				all_destroy.append(nb)

	# Snapshot col data from normal_tiles, sorted by where along the rope each tile was hit
	var polyline : Array = rope_node.get_polyline()
	var normal_data : Array = []
	for t : Node2D in normal_tiles:
		if not is_instance_valid(t):
			continue
		# Find the earliest rope segment index that touches this tile
		var hit_idx : int = 999999
		for i : int in polyline.size() - 1:
			var closest : Vector2 = _closest_on_seg(polyline[i], polyline[i + 1], t.global_position)
			if closest.distance_to(t.global_position) <= HEX_RADIUS * 0.85:
				hit_idx = i
				break
		normal_data.append({ "node": t, "col": t.col, "hit_idx": hit_idx })
	normal_data.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a.hit_idx < b.hit_idx
	)

	# Score
	var count : int = normal_tiles.size()
	if count > 0:
		var combo : int = max(1, count - 1)
		score += count * 10 * combo
		_update_score_label(count, combo)
		if health_bar:
			health_bar.gain(float(count) * health_bar.REGEN_PER_TILE)
			if fx_layer:
				fx_layer.spawn_health_pulse(health_bar.global_position, health_bar.BAR_W, health_bar.BAR_H)
		if fx_layer:
			fx_layer.spawn_combo_text(count, combo)

	# Health damage for bombs hit by rope
	if bomb_tiles.size() > 0:
		if health_bar:
			health_bar.damage(health_bar.BOMB_DAMAGE * float(bomb_tiles.size()))
		if fx_layer:
			fx_layer.spawn_screen_flash(Color(1.0, 0.15, 0.15, 0.7))

	# Destroy used anchors — add their cols to collapse set
	var cols_hit : Dictionary = {}
	for anchor : Node2D in anchors_used:
		if not is_instance_valid(anchor):
			continue
		if grid[anchor.row][anchor.col] == anchor:
			grid[anchor.row][anchor.col] = null
			cols_hit[anchor.col] = true
		anchor.flash_destroy()

	# Step 1: null ALL tiles at once so grid state is final before any animation
	for tile : Node2D in all_destroy:
		if not is_instance_valid(tile):
			continue
		if grid[tile.row][tile.col] == tile:
			grid[tile.row][tile.col] = null
			cols_hit[tile.col] = true

	# Step 2a: bomb explosions all pop at once, then their columns collapse together
	var bomb_cols : Dictionary = {}
	for bomb : Node2D in bomb_tiles:
		if is_instance_valid(bomb):
			bomb.flash_destroy()
			bomb_cols[bomb.col] = true
		for n : Vector2i in hex_neighbors(bomb.row, bomb.col):
			var nb : Node2D = grid[n.x][n.y] if grid[n.x][n.y] == null else null
			# neighbor was already nulled — find the node in all_destroy
			pass
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

	# Step 2b: normal tiles chain one by one
	# Snapshot col values NOW before any nodes get freed
	var popped_cols : Dictionary = {}
	for col : int in bomb_cols.keys():
		popped_cols[col] = true
	# normal_data already built above
	for entry : Dictionary in normal_data:
		var tcol : int = entry.col
		var tile       = entry.node   # untyped — typed assignment throws on freed instance
		if is_instance_valid(tile):
			tile.flash_destroy()
		await get_tree().create_timer(0.10).timeout
		if not popped_cols.has(tcol):
			popped_cols[tcol] = true
			collapse_column(tcol)

	# Collapse any remaining cols (anchors etc)
	for col : int in cols_hit.keys():
		if not popped_cols.has(col):
			collapse_column(col)

	_clearing = false


# ── Collapse & refill ─────────────────────────────────────────

func collapse_column(col: int) -> void:
	for row : int in range(ROWS - 1, -1, -1):
		if grid[row][col] == null:
			for above : int in range(row - 1, -1, -1):
				var t : Node2D = grid[above][col]
				if t != null:
					grid[row][col]   = t
					grid[above][col] = null
					t.row = row
					t.col = col
					_animate_fall_to(t, hex_to_world(row, col))
					break
	for row : int in ROWS:
		if grid[row][col] == null:
			# Spawn just above grid, fade in
			var tile   : Node2D  = spawn_anchor(row, col) if randf() < _anchor_chance_at(row, col) else spawn_tile(row, col)
			var target : Vector2 = hex_to_world(row, col)
			tile.position   = Vector2(target.x, hex_to_world(0, col).y - HEX_RADIUS * 2.5)
			tile.modulate.a = 0.0
			grid[row][col]  = tile
			_animate_fall_to(tile, target)
			var tw : Tween = create_tween()
			tw.tween_property(tile, "modulate:a", 1.0, 0.20)


func _animate_fall_to(tile: Node2D, target: Vector2) -> void:
	var tw : Tween = create_tween()
	tw.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_IN)
	tw.tween_property(tile, "position", target, 0.18)
	tw.set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	tw.tween_property(tile, "scale:y", 0.92, 0.05)
	tw.tween_property(tile, "scale:y", 1.0,  0.08)


# ── Helpers ───────────────────────────────────────────────────

func _get_all_anchors() -> Array:
	var result : Array = []
	for row : int in ROWS:
		for col : int in COLS:
			var t : Node2D = grid[row][col]
			if t != null and t.is_anchor:
				result.append(t)
	return result


# Return closest tile to click — not just first within radius
func _tile_at_world(world_pos: Vector2) -> Node2D:
	var best_dist : float  = HEX_RADIUS
	var best_tile : Node2D = null
	for row : int in ROWS:
		for col : int in COLS:
			var t    : Node2D = grid[row][col]
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


func _is_bomb_neighbor(tile: Node2D, bombs: Array) -> bool:
	for bomb : Node2D in bombs:
		if not is_instance_valid(bomb):
			continue
		for n : Vector2i in hex_neighbors(bomb.row, bomb.col):
			if n.x == tile.row and n.y == tile.col:
				return true
	return false


func game_over() -> void:
	get_tree().paused = true
	var lbl : Label = get_parent().get_node_or_null("GameOverLabel")
	if lbl:
		lbl.visible = true
