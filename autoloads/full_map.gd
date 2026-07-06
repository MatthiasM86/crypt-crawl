extends CanvasLayer
## Toggleable full-map overlay ([M]). Pauses the tree while open, mirroring
## PauseMenu/LoadoutChoice/DeathScreen. Drawing itself lives in
## full_map_view.gd, attached to a plain Control child (a CanvasLayer can't
## override _draw() directly).

var _view: Control


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 12  # above PauseMenu (10), below LoadoutChoice (15) and DeathScreen (20)
	visible = false
	_build_ui()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("map") and not _blocked():
		_toggle()


func _blocked() -> bool:
	return PauseMenu.visible or DeathScreen.visible or LoadoutChoice.visible


func _toggle() -> void:
	if visible:
		get_tree().paused = false
		visible = false
	else:
		get_tree().paused = true
		visible = true
		_view.queue_redraw()


func _build_ui() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.75)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	_view = Control.new()
	_view.set_script(preload("res://autoloads/full_map_view.gd"))
	_view.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_view)
