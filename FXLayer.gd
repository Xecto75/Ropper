extends Node2D

# ── All visual effects live here, drawn on top of everything ──

const VIEWPORT_W : float = 540.0
const VIEWPORT_H : float = 960.0

# Active effects list
var _effects : Array = []


func _process(delta: float) -> void:
	if _effects.is_empty():
		return
	for fx : Dictionary in _effects:
		fx.time += delta
	_effects = _effects.filter(func(fx: Dictionary) -> bool: return fx.time < fx.duration)
	queue_redraw()


func _draw() -> void:
	for fx : Dictionary in _effects:
		var t : float = fx.time / fx.duration   # 0→1
		match fx.type:
			"ripple":      _draw_ripple(fx, t)
			"combo_text":  _draw_combo_text(fx, t)
			"screen_flash":_draw_screen_flash(fx, t)
			"health_pulse":_draw_health_pulse(fx, t)


# ── Public API ────────────────────────────────────────────────

func spawn_ripple(world_pos: Vector2, color: Color) -> void:
	_effects.append({
		"type": "ripple", "time": 0.0, "duration": 0.55,
		"pos": world_pos, "color": color
	})


# grid_center should be passed from HexGrid
var grid_center : Vector2 = Vector2(270.0, 480.0)   # fallback, updated by HexGrid

func spawn_combo_text(count: int, combo: int) -> void:
	if count < 3:
		return
	_effects.append({
		"type": "combo_text", "time": 0.0, "duration": 1.1,
		"pos": grid_center, "count": count, "combo": combo
	})


func spawn_screen_flash(color: Color) -> void:
	_effects.append({
		"type": "screen_flash", "time": 0.0, "duration": 0.35,
		"color": color
	})


func spawn_health_pulse(bar_pos: Vector2, bar_w: float, bar_h: float) -> void:
	_effects.append({
		"type": "health_pulse", "time": 0.0, "duration": 0.4,
		"pos": bar_pos, "w": bar_w, "h": bar_h
	})


# ── Draw functions ────────────────────────────────────────────

func _draw_ripple(fx: Dictionary, t: float) -> void:
	# Hex-shaped shockwave expanding outward and fading
	var ease_t  : float = 1.0 - pow(1.0 - t, 2.0)   # ease out
	var radius  : float = ease_t * 180.0
	var alpha   : float = (1.0 - t) * 0.7
	var color   : Color = fx.color
	color.a = alpha
	var width   : float = (1.0 - t) * 5.0 + 1.0

	# Draw expanding hex
	var pts : PackedVector2Array = PackedVector2Array()
	for i : int in 6:
		var angle : float = deg_to_rad(60.0 * i - 90.0)
		pts.append(fx.pos + Vector2(cos(angle), sin(angle)) * radius)
	for i : int in 6:
		draw_line(pts[i], pts[(i + 1) % 6], color, width, true)

	# Second ring slightly behind
	if t < 0.7:
		var r2    : float = ease_t * 120.0
		var a2    : float = (0.7 - t) / 0.7 * 0.4
		var c2    : Color = fx.color
		c2.a = a2
		var pts2  : PackedVector2Array = PackedVector2Array()
		for i : int in 6:
			var angle : float = deg_to_rad(60.0 * i - 90.0)
			pts2.append(fx.pos + Vector2(cos(angle), sin(angle)) * r2)
		for i : int in 6:
			draw_line(pts2[i], pts2[(i + 1) % 6], c2, 2.0, true)


func _draw_combo_text(fx: Dictionary, t: float) -> void:
	var font    : Font   = ThemeDB.fallback_font
	var count   : int    = fx.count
	var combo   : int    = fx.combo

	# Float upward
	var rise    : float  = t * 80.0
	var pos     : Vector2 = fx.pos - Vector2(0, rise)

	# Scale: pop in, then shrink out
	var scale_t : float
	if t < 0.2:
		scale_t = t / 0.2
	elif t < 0.7:
		scale_t = 1.0
	else:
		scale_t = 1.0 - (t - 0.7) / 0.3
	var font_size : int = int(lerp(0.0, 52.0, scale_t))
	if font_size < 4:
		return

	var alpha   : float  = clamp(scale_t, 0.0, 1.0)

	# Color based on combo size
	var color   : Color
	if combo >= 6:
		color = Color(1.0, 0.3, 0.9, alpha)   # pink — insane
	elif combo >= 4:
		color = Color(1.0, 0.6, 0.1, alpha)   # orange — great
	else:
		color = Color(1.0, 1.0, 0.3, alpha)   # yellow — good

	var text    : String = "x%d" % combo if combo > 1 else "%d!" % count
	var tw      : float  = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x

	# Shadow
	draw_string(font, pos + Vector2(2, 2) - Vector2(tw * 0.5, 0),
		text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(0, 0, 0, alpha * 0.5))
	# Main text
	draw_string(font, pos - Vector2(tw * 0.5, 0),
		text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)

	# Sparkle dots around text on high combos
	if combo >= 4:
		for i : int in 6:
			var angle  : float   = deg_to_rad(60.0 * i + t * 180.0)
			var dist   : float   = 40.0 + sin(t * TAU) * 8.0
			var spark  : Vector2 = pos + Vector2(cos(angle), sin(angle)) * dist
			var sa     : float   = alpha * (0.5 + 0.5 * sin(t * TAU * 2.0 + i))
			draw_circle(spark, 3.0, Color(color.r, color.g, color.b, sa))


func _draw_screen_flash(fx: Dictionary, t: float) -> void:
	# Flash on screen edges only — vignette style
	var alpha : float = (1.0 - t) * fx.color.a
	var color : Color = fx.color
	color.a   = alpha
	var edge  : float = 60.0 * (1.0 - t * 0.5)

	draw_rect(Rect2(0, 0, VIEWPORT_W, edge), color, true)
	draw_rect(Rect2(0, VIEWPORT_H - edge, VIEWPORT_W, edge), color, true)
	draw_rect(Rect2(0, 0, edge, VIEWPORT_H), color, true)
	draw_rect(Rect2(VIEWPORT_W - edge, 0, edge, VIEWPORT_H), color, true)


func _draw_health_pulse(fx: Dictionary, t: float) -> void:
	# Green glow expanding from health bar
	var alpha : float = (1.0 - t) * 0.6
	var grow  : float = t * 12.0
	var rect  : Rect2 = Rect2(
		fx.pos.x - grow, fx.pos.y - grow,
		fx.w + grow * 2.0, fx.h + grow * 2.0
	)
	draw_rect(rect, Color(0.2, 0.9, 0.35, alpha), false, 3.0 * (1.0 - t))
