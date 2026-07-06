extends Control
## Minimal run HUD: HP squares, potion charge, dash/skill cooldowns, floor
## number. Lives on a CanvasLayer under the Player scene so it exists in
## every level and is unaffected by the CanvasModulate darkness.
## mouse_filter must stay IGNORE (Controls otherwise eat click-to-move).

const POTION_ICON := preload("res://assets/sprites/props/potion.png")

@onready var _player: Node = get_parent().get_parent()


func _ready() -> void:
	texture_filter = TEXTURE_FILTER_NEAREST  # crisp pixel-art HUD icons


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var max_hp: int = _player.max_hp
	var hp: int = _player.hp
	for i in max_hp:
		var color := Color(0.85, 0.25, 0.25) if i < hp else Color(0.22, 0.1, 0.1)
		draw_rect(Rect2(10 + i * 24, 10, 20, 20), color)
	# Ability row: potion belt [1/Q], dash [Space/Shift], slam [RMB]
	var belt: int = _player.potion_max
	for i in belt:
		var tint := Color.WHITE if i < _player.potion_charges else Color(0.3, 0.3, 0.35, 0.7)
		draw_texture_rect(POTION_ICON, Rect2(10 + i * 24, 36, 22, 22), false, tint)
	# Dash square reads charges: ready as soon as one charge is up.
	_draw_cooldown_square(Vector2(16 + belt * 24, 38), Color(0.45, 0.8, 0.95),
			0.0 if _player.dash_charges > 0 else _player.dash_cooldown_left,
			_player.dash_cooldown)
	if _player.max_dash_charges > 1:
		draw_string(ThemeDB.fallback_font, Vector2(20 + belt * 24, 53),
				str(_player.dash_charges), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.1, 0.15, 0.2))
	_draw_cooldown_square(Vector2(40 + belt * 24, 38), Color(1.0, 0.75, 0.35),
			_player.skill_cooldown_left, _player.SLAM_COOLDOWN)
	draw_string(ThemeDB.fallback_font, Vector2(66 + belt * 24, 54), "[1] [Spc] [RMB]",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.55, 0.55, 0.6))
	draw_string(ThemeDB.fallback_font, Vector2(10, 84), "Ebene %d" % GameManager.floor_num,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.8, 0.8, 0.85))
	draw_string(ThemeDB.fallback_font, Vector2(10, 108), "Seelen: %d" % GameManager.souls,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.55, 0.9, 1.0))
	_draw_relics()
	_draw_message()
	_draw_boss_bar()


func _draw_relics() -> void:
	# One colored diamond per carried relic (max player.RELIC_MAX).
	for i in _player.relics.size():
		var def: Dictionary = GameManager.RELIC_DEFS[_player.relics[i]]
		var c := Vector2(20 + i * 26, 130)
		draw_colored_polygon(PackedVector2Array([
			c + Vector2(0, -9), c + Vector2(8, 0), c + Vector2(0, 9), c + Vector2(-8, 0),
		]), def["color"])


func _draw_message() -> void:
	# Transient announcement (relic pickups), fading out near the end.
	if _player.hud_message_left <= 0.0:
		return
	var alpha: float = clampf(_player.hud_message_left / 0.6, 0.0, 1.0)
	var w := get_viewport_rect().size.x
	draw_string(ThemeDB.fallback_font, Vector2(0, 92), _player.hud_message,
			HORIZONTAL_ALIGNMENT_CENTER, w, 17, Color(1.0, 0.92, 0.7, alpha))


func _draw_boss_bar() -> void:
	var boss: Node = get_tree().get_first_node_in_group("boss")
	if boss == null or boss.get("dead"):
		return
	var w := 360.0
	var x := (get_viewport_rect().size.x - w) / 2.0
	draw_rect(Rect2(x, 16, w, 14), Color(0.12, 0.05, 0.08))
	draw_rect(Rect2(x, 16, w * boss.hp / float(boss.max_hp), 14), Color(0.7, 0.15, 0.2))
	draw_string(ThemeDB.fallback_font, Vector2(x, 48), "Kryptwächter",
			HORIZONTAL_ALIGNMENT_LEFT, w, 14, Color(0.85, 0.7, 0.75))


func _draw_cooldown_square(pos: Vector2, ready_color: Color, left: float, total: float) -> void:
	if left <= 0.0:
		draw_rect(Rect2(pos, Vector2(20, 20)), ready_color)
		return
	draw_rect(Rect2(pos, Vector2(20, 20)), ready_color.darkened(0.75))
	# refill bar grows bottom-up as the cooldown runs out
	var frac := 1.0 - left / total
	var h := 20.0 * frac
	draw_rect(Rect2(pos + Vector2(0, 20.0 - h), Vector2(20, h)), ready_color.darkened(0.4))
