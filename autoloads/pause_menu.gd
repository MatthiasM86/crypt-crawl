extends CanvasLayer
## ESC pause menu (autoload -> exists in hub and runs). Pauses the whole
## tree; this layer keeps processing via PROCESS_MODE_ALWAYS. "Aufgeben"
## only shows during a run and returns to the hub (no win banked -- souls
## are always safe anyway). UI is built in code, no scene file.

var _give_up_button: Button


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 10
	visible = false
	_build_ui()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") and not DeathScreen.visible and not LoadoutChoice.visible \
			and not FullMap.visible:
		_toggle()


func _toggle() -> void:
	if visible:
		_resume()
	else:
		get_tree().paused = true
		_give_up_button.visible = _in_run()
		visible = true


func _resume() -> void:
	get_tree().paused = false
	visible = false


func _in_run() -> bool:
	var scene := get_tree().current_scene
	return scene != null and scene.scene_file_path == GameManager.RUN_SCENE


func _give_up() -> void:
	_resume()
	GameManager.return_to_hub()


func _quit() -> void:
	get_tree().quit()


func _build_ui() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	center.add_child(box)
	var title := Label.new()
	title.text = "Pause"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	box.add_child(title)
	box.add_child(_make_button("Fortsetzen", _resume))
	_give_up_button = _make_button("Aufgeben (zurück zur Basis)", _give_up)
	box.add_child(_give_up_button)
	box.add_child(_make_button("Beenden", _quit))


func _make_button(text: String, handler: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(250, 40)
	b.pressed.connect(handler)
	return b
