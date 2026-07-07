extends Control
## Full-map drawing, attached (via set_script) to a Control child of the
## FullMap autoload's CanvasLayer -- CanvasLayer itself can't override _draw().
## Reads the current level's fog-of-war data via get_map_data()
## (level_generator.gd); shows a placeholder if the scene has none (hub,
## test_room -- both small enough not to need a map).

const FRAME := preload("res://assets/sprites/ui/hud_frame.png")
const FONT := preload("res://assets/fonts/hud_font.ttf")
const FRAME_M := 28
const BOX_W := 900.0
const BOX_H := 506.0
const REVEALED_COLOR := Color(0.55, 0.55, 0.65, 0.9)
const PLAYER_COLOR := Color(1.0, 0.85, 0.3)


func _nine(dst: Rect2, cs: float) -> void:
	var tw := float(FRAME.get_width())
	var th := float(FRAME.get_height())
	var m := float(FRAME_M)
	var sx := [0.0, m, tw - m, tw]
	var sy := [0.0, m, th - m, th]
	var dx := [dst.position.x, dst.position.x + cs, dst.end.x - cs, dst.end.x]
	var dy := [dst.position.y, dst.position.y + cs, dst.end.y - cs, dst.end.y]
	for i in 3:
		for j in 3:
			draw_texture_rect_region(FRAME,
					Rect2(dx[i], dy[j], dx[i + 1] - dx[i], dy[j + 1] - dy[j]),
					Rect2(sx[i], sy[j], sx[i + 1] - sx[i], sy[j + 1] - sy[j]))


func _draw() -> void:
	draw_string(FONT, Vector2(size.x / 2.0 - 40, 44), "Karte",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color(0.9, 0.9, 0.95))
	var level := get_tree().current_scene
	if level == null or not level.has_method("get_map_data"):
		draw_string(FONT, Vector2(size.x / 2.0 - 150, size.y / 2.0),
				"Für diesen Ort gibt es keine Karte", HORIZONTAL_ALIGNMENT_LEFT, -1, 16,
				Color(0.7, 0.7, 0.75))
		return
	var data: Dictionary = level.get_map_data()
	var cell: int = data["cell"]
	var map_w: int = data["map_w"]
	var map_h: int = data["map_h"]
	var origin := Vector2((size.x - BOX_W) / 2.0, (size.y - BOX_H) / 2.0)
	var scale_x: float = BOX_W / map_w
	var scale_y: float = BOX_H / map_h
	_nine(Rect2(origin - Vector2(16, 16), Vector2(BOX_W + 32, BOX_H + 32)), 18.0)
	draw_rect(Rect2(origin, Vector2(BOX_W, BOX_H)), Color(0.08, 0.08, 0.1, 0.6))
	var visited: Dictionary = data["visited"]
	for c in visited:
		var cv: Vector2i = c
		draw_rect(Rect2(origin + Vector2(cv.x * scale_x, cv.y * scale_y),
				Vector2(scale_x + 0.6, scale_y + 0.6)), REVEALED_COLOR)
	var player := get_tree().get_first_node_in_group("player")
	if player:
		var p_pos: Vector2 = origin + (player.position / cell) * Vector2(scale_x, scale_y)
		draw_circle(p_pos, 6.0, PLAYER_COLOR)
	draw_string(FONT, Vector2(size.x / 2.0 - 60, size.y - 24),
			"[M] schließen", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.6, 0.6, 0.65))
