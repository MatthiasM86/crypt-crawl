extends Control
## Run HUD: framed HP bar, ability/relic slots, soul + floor banner, boss bar,
## minimap. Drawn immediate-mode over a CanvasLayer under the Player scene, so
## it exists in every level and is unaffected by the CanvasModulate darkness.
## mouse_filter must stay IGNORE (Controls otherwise eat click-to-move).
## Art: PixelLab ornate frame (9-sliced via _nine) + gothic font + icon set.

const FRAME := preload("res://assets/sprites/ui/hud_frame.png")
const HEART := preload("res://assets/sprites/props/heart.png")
const SOUL_ICON := preload("res://assets/sprites/props/soul_wisp.png")
const POTION_ICON := preload("res://assets/sprites/props/potion.png")
const DASH_ICON := preload("res://assets/sprites/props/skill_dash.png")
const FONT := preload("res://assets/fonts/hud_font.ttf")
# Preloaded so _draw() never calls load() (deferred loading returns a white
# placeholder mid-render — hence the dicts instead of load-by-id).
const SKILL_ICONS := {
	"rundumschlag": preload("res://assets/sprites/props/skill_rundumschlag.png"),
	"frostnova": preload("res://assets/sprites/props/skill_frostnova.png"),
	"blutopfer": preload("res://assets/sprites/props/skill_blutopfer.png"),
	"seelenkette": preload("res://assets/sprites/props/skill_seelenkette.png"),
}
const RELIC_ICONS := {
	"fire_slam": preload("res://assets/sprites/props/relic_fire_slam.png"),
	"lifesteal": preload("res://assets/sprites/props/relic_lifesteal.png"),
	"dash_charge": preload("res://assets/sprites/props/relic_dash_charge.png"),
	"heavy_hits": preload("res://assets/sprites/props/relic_heavy_hits.png"),
	"swift": preload("res://assets/sprites/props/relic_swift.png"),
	"potion_power": preload("res://assets/sprites/props/relic_potion_power.png"),
	"soul_greed": preload("res://assets/sprites/props/relic_soul_greed.png"),
}

const FRAME_M := 28              # frame texture's border margin (source px)
const SLOT := 28.0               # ability/relic slot size
const GAP := 4.0
const FILL_INSET := 7.0          # bar fill inset inside its frame
const TXT := Color(0.86, 0.84, 0.8)

@onready var _player: Node = get_parent().get_parent()


func _ready() -> void:
	texture_filter = TEXTURE_FILTER_NEAREST  # crisp pixel-art HUD


func _process(_delta: float) -> void:
	queue_redraw()


# --- 9-slice frame: scales the source corners to `cs` on screen ---------------
func _nine(dst: Rect2, cs: float, tint := Color.WHITE) -> void:
	var tw := float(FRAME.get_width())
	var th := float(FRAME.get_height())
	var m := float(FRAME_M)
	var sx := [0.0, m, tw - m, tw]
	var sy := [0.0, m, th - m, th]
	var dx := [dst.position.x, dst.position.x + cs, dst.end.x - cs, dst.end.x]
	var dy := [dst.position.y, dst.position.y + cs, dst.end.y - cs, dst.end.y]
	for i in 3:
		for j in 3:
			var src := Rect2(sx[i], sy[j], sx[i + 1] - sx[i], sy[j + 1] - sy[j])
			var d := Rect2(dx[i], dy[j], dx[i + 1] - dx[i], dy[j + 1] - dy[j])
			draw_texture_rect_region(FRAME, d, src, tint)


func _text(pos: Vector2, s: String, sz: int, col := TXT, w := -1.0,
		align := HORIZONTAL_ALIGNMENT_LEFT) -> void:
	draw_string(FONT, pos, s, align, w, sz, col)


func _slot_icon(inner: Rect2, tex: Texture2D, tint := Color.WHITE) -> void:
	if tex == null:
		return
	var s := minf(inner.size.x, inner.size.y)
	var p := inner.position + (inner.size - Vector2(s, s)) * 0.5
	draw_texture_rect(tex, Rect2(p, Vector2(s, s)), false, tint)


func _draw() -> void:
	_draw_hp()
	_draw_abilities()
	_draw_relics()
	_draw_souls_and_floor()
	_draw_message()
	_draw_boss_bar()
	_draw_minimap()


func _draw_hp() -> void:
	var max_hp: int = _player.max_hp
	var hp: int = _player.hp
	draw_texture_rect(HEART, Rect2(8, 8, 22, 22), false)
	var bar := Rect2(34, 9, 210, 22)
	_nine(bar, 8.0)
	var fill := Rect2(bar.position + Vector2(FILL_INSET, FILL_INSET),
			bar.size - Vector2(FILL_INSET * 2.0, FILL_INSET * 2.0))
	draw_rect(fill, Color(0.12, 0.03, 0.04))
	var frac := clampf(float(hp) / maxf(1.0, float(max_hp)), 0.0, 1.0)
	draw_rect(Rect2(fill.position, Vector2(fill.size.x * frac, fill.size.y)),
			Color(0.82, 0.22, 0.24))
	_text(Vector2(bar.position.x, bar.end.y + 1), "%d / %d" % [hp, max_hp], 12,
			Color(1, 1, 1, 0.85), bar.size.x, HORIZONTAL_ALIGNMENT_CENTER)


func _draw_abilities() -> void:
	var y := 42.0
	var x := 8.0
	# Potion belt
	for i in _player.potion_max:
		var charged: bool = i < _player.potion_charges
		_draw_slot(Vector2(x, y), POTION_ICON,
				Color.WHITE if charged else Color(0.35, 0.35, 0.4, 0.8))
		x += SLOT + GAP
	x += GAP
	# Dash slot (ready if any charge up)
	var dash_inner := _draw_slot(Vector2(x, y), DASH_ICON, Color.WHITE)
	_cooldown(dash_inner, 0.0 if _player.dash_charges > 0 else _player.dash_cooldown_left,
			_player.dash_cooldown)
	if _player.max_dash_charges > 1:
		_text(Vector2(x + SLOT - 8.0, y + SLOT - 2.0), str(_player.dash_charges), 12,
				Color(0.85, 0.95, 1.0))
	x += SLOT + GAP
	# Skill slot
	var skill_def: Dictionary = GameManager.SKILL_DEFS[_player.skill_id]
	var skill_inner := _draw_slot(Vector2(x, y), SKILL_ICONS.get(_player.skill_id), Color.WHITE)
	_cooldown(skill_inner, _player.skill_cooldown_left, skill_def["cooldown"])
	x += SLOT + GAP + GAP
	_text(Vector2(x, y + SLOT * 0.5 + 5.0), "[1] [Spc] [RMB]", 12, Color(0.55, 0.55, 0.6))


func _draw_slot(pos: Vector2, tex: Texture2D, tint: Color) -> Rect2:
	var r := Rect2(pos, Vector2(SLOT, SLOT))
	_nine(r, 8.0)
	var inner := Rect2(r.position + Vector2(6, 6), r.size - Vector2(12, 12))
	_slot_icon(inner, tex, tint)
	return inner


func _cooldown(inner: Rect2, left: float, total: float) -> void:
	if left <= 0.0 or total <= 0.0:
		return
	# Dark curtain over the still-cooling top portion; icon reveals from bottom.
	var frac := clampf(1.0 - left / total, 0.0, 1.0)
	var covered := inner.size.y * (1.0 - frac)
	draw_rect(Rect2(inner.position, Vector2(inner.size.x, covered)), Color(0, 0, 0, 0.62))


func _draw_relics() -> void:
	var y := 78.0
	for i in _player.relics.size():
		var relic_id: String = _player.relics[i]
		_draw_slot(Vector2(8.0 + i * (SLOT + GAP), y), RELIC_ICONS.get(relic_id), Color.WHITE)


func _draw_souls_and_floor() -> void:
	draw_texture_rect(SOUL_ICON, Rect2(8, 110, 20, 20), false)
	_text(Vector2(32, 125), "%d" % GameManager.souls, 16, Color(0.6, 0.92, 1.0))
	# Framed floor/biome banner
	var banner := Rect2(8, 136, 200, 26)
	_nine(banner, 8.0)
	_text(Vector2(banner.position.x, banner.position.y + 18),
			"Ebene %d — %s" % [GameManager.floor_num, GameManager.biome()["name"]], 14,
			TXT, banner.size.x, HORIZONTAL_ALIGNMENT_CENTER)
	var weapon_def: Dictionary = GameManager.WEAPON_DEFS[_player.weapon_id]
	_text(Vector2(10, 182), "Waffe: %s" % weapon_def["label"], 13, weapon_def["color"])


func _draw_message() -> void:
	if _player.hud_message_left <= 0.0:
		return
	var alpha: float = clampf(_player.hud_message_left / 0.6, 0.0, 1.0)
	var w := get_viewport_rect().size.x
	_text(Vector2(0, 96), _player.hud_message, 18, Color(1.0, 0.92, 0.7, alpha), w,
			HORIZONTAL_ALIGNMENT_CENTER)


func _draw_boss_bar() -> void:
	var boss: Node = get_tree().get_first_node_in_group("boss")
	if boss == null or boss.get("dead"):
		return
	var w := 380.0
	var x := (get_viewport_rect().size.x - w) / 2.0
	var bar := Rect2(x, 14, w, 26)
	_nine(bar, 9.0)
	var fill := Rect2(bar.position + Vector2(FILL_INSET, FILL_INSET),
			bar.size - Vector2(FILL_INSET * 2.0, FILL_INSET * 2.0))
	draw_rect(fill, Color(0.1, 0.03, 0.05))
	draw_rect(Rect2(fill.position, Vector2(fill.size.x * boss.hp / float(boss.max_hp),
			fill.size.y)), Color(0.72, 0.15, 0.2))
	var bname: String = boss.get("boss_name") if boss.get("boss_name") != null else "Boss"
	_text(Vector2(x, bar.end.y + 16), bname, 15, Color(0.88, 0.72, 0.76), w,
			HORIZONTAL_ALIGNMENT_CENTER)


func _draw_minimap() -> void:
	var level := get_tree().current_scene
	if level == null or not level.has_method("get_map_data"):
		return
	var data: Dictionary = level.get_map_data()
	var cell: int = data["cell"]
	var map_w: int = data["map_w"]
	var map_h: int = data["map_h"]
	const BOX_W := 160.0
	const BOX_H := 90.0
	var frame := Rect2(get_viewport_rect().size.x - BOX_W - 18, 8, BOX_W + 12, BOX_H + 12)
	_nine(frame, 8.0)
	var origin := frame.position + Vector2(6, 6)
	draw_rect(Rect2(origin, Vector2(BOX_W, BOX_H)), Color(0.05, 0.05, 0.07, 0.7))
	var scale_x: float = BOX_W / map_w
	var scale_y: float = BOX_H / map_h
	var visited: Dictionary = data["visited"]
	for c in visited:
		var cv: Vector2i = c
		draw_rect(Rect2(origin + Vector2(cv.x * scale_x, cv.y * scale_y),
				Vector2(scale_x + 0.6, scale_y + 0.6)), Color(0.55, 0.55, 0.65, 0.85))
	var p_pos: Vector2 = origin + (_player.position / cell) * Vector2(scale_x, scale_y)
	draw_circle(p_pos, 3.0, Color(1.0, 0.85, 0.3))
	_text(origin + Vector2(0, BOX_H + 16), "[M] Karte", 12, Color(0.6, 0.6, 0.65))
