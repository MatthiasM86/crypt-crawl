extends CanvasLayer
## Post-death recap (autoload, mirrors pause_menu.gd's code-built-UI approach).
## Shown by GameManager.player_died() after player.gd's death-fade finishes;
## reports the floor reached and souls earned this run, then hands off to
## the hub. Dismiss early with any key/click, or it auto-continues.

const SHOW_DELAY := 0.9   # lets player.gd's death-fade animation finish first
const MIN_HOLD := 0.4     # ignore input for a beat so the killing blow can't insta-skip
const AUTO_CONTINUE := 3.0

var _floor_label: Label
var _souls_label: Label
var _can_dismiss := false
var _done := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 20  # above PauseMenu's 10
	visible = false
	_build_ui()


func show_recap(floor_reached: int, souls_earned: int) -> void:
	_done = false
	_can_dismiss = false
	await get_tree().create_timer(SHOW_DELAY).timeout
	_floor_label.text = "Ebene erreicht: %d" % floor_reached
	_souls_label.text = "Seelen verdient: %d" % souls_earned
	visible = true
	await get_tree().create_timer(MIN_HOLD).timeout
	_can_dismiss = true
	await get_tree().create_timer(AUTO_CONTINUE - MIN_HOLD).timeout
	_continue()


func _unhandled_input(event: InputEvent) -> void:
	if not visible or not _can_dismiss or _done:
		return
	if (event is InputEventKey or event is InputEventMouseButton) and event.pressed:
		get_viewport().set_input_as_handled()
		_continue()


func _continue() -> void:
	if _done:
		return
	_done = true
	visible = false
	get_tree().change_scene_to_file.call_deferred(GameManager.HUB_SCENE)


func _build_ui() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.75)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	center.add_child(box)
	var title := Label.new()
	title.text = "Ihr seid gefallen"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 32)
	title.add_theme_color_override("font_color", Color(0.85, 0.15, 0.2))
	box.add_child(title)
	_floor_label = Label.new()
	_floor_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_floor_label.add_theme_font_size_override("font_size", 20)
	box.add_child(_floor_label)
	_souls_label = Label.new()
	_souls_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_souls_label.add_theme_font_size_override("font_size", 20)
	box.add_child(_souls_label)
	var hint := Label.new()
	hint.text = "(Taste oder Klick zum Fortfahren)"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 14)
	hint.modulate.a = 0.7
	box.add_child(hint)
