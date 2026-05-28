extends Node2D

const MAX_HEALTH    : float = 100.0
const DRAIN_RATE    : float = 3.5
const REGEN_PER_TILE: float = 4.0
const BOMB_DAMAGE   : float = 30.0
const BAR_W         : float = 460.0   # wider — centered on 540px viewport
const BAR_H         : float = 28.0   # taller

const COLOR_LOW  : Color = Color(0.95, 0.20, 0.20)
const COLOR_MID  : Color = Color(0.95, 0.65, 0.10)
const COLOR_FULL : Color = Color(0.20, 0.90, 0.35)

var health          : float = MAX_HEALTH
var _display_health : float = MAX_HEALTH

signal health_empty


func _process(delta: float) -> void:
	health          = max(0.0, health - DRAIN_RATE * delta)
	_display_health = lerp(_display_health, health, 12.0 * delta)
	queue_redraw()
	if health <= 0.0:
		emit_signal("health_empty")
		set_process(false)


func gain(amount: float) -> void:
	health = min(MAX_HEALTH, health + amount)


func damage(amount: float) -> void:
	health = max(0.0, health - amount)


func _health_color(pct: float) -> Color:
	if pct < 0.5:
		return COLOR_LOW.lerp(COLOR_MID, pct * 2.0)
	else:
		return COLOR_MID.lerp(COLOR_FULL, (pct - 0.5) * 2.0)


func _draw() -> void:
	var pct : float = clamp(_display_health / MAX_HEALTH, 0.0, 1.0)

	# Background
	draw_rect(Rect2(0.0, 0.0, BAR_W, BAR_H), Color(0.1, 0.1, 0.1, 0.85), true)

	# Fill
	var fill_w : float = BAR_W * pct
	if fill_w > 1.0:
		var col : Color = _health_color(pct)
		draw_rect(Rect2(0.0, 0.0, fill_w, BAR_H), col, true)
		# Shine strip
		draw_rect(Rect2(0.0, 0.0, fill_w, BAR_H * 0.35), Color(1.0, 1.0, 1.0, 0.10), true)

	# Border
	draw_rect(Rect2(0.0, 0.0, BAR_W, BAR_H), Color(1.0, 1.0, 1.0, 0.25), false, 1.5)

	# Percentage text
	draw_string(ThemeDB.fallback_font, Vector2(4.0, BAR_H - 4.0),
		"%d%%" % int(pct * 100.0),
		HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(1.0, 1.0, 1.0, 0.9))
