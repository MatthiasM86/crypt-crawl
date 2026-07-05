extends Control
## Minimal run HUD: HP squares, potion charge, floor number. Lives on a
## CanvasLayer under the Player scene so it exists in every level and is
## unaffected by the CanvasModulate darkness. mouse_filter must stay IGNORE
## (Controls otherwise eat the click-to-move input).

@onready var _player: Node = get_parent().get_parent()


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var max_hp: int = _player.MAX_HP
	var hp: int = _player.hp
	for i in max_hp:
		var color := Color(0.85, 0.25, 0.25) if i < hp else Color(0.22, 0.1, 0.1)
		draw_rect(Rect2(10 + i * 24, 10, 20, 20), color)
	var potion_color := Color(0.35, 0.8, 0.4) if _player.potion_charges > 0 else Color(0.13, 0.22, 0.14)
	draw_rect(Rect2(10, 38, 20, 20), potion_color)
	draw_string(ThemeDB.fallback_font, Vector2(38, 54), "[1/Q]",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.55, 0.55, 0.6))
	draw_string(ThemeDB.fallback_font, Vector2(10, 82), "Ebene %d" % GameManager.floor_num,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.8, 0.8, 0.85))
