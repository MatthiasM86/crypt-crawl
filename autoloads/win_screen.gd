extends CanvasLayer
## Victory screen (autoload): raised by level_generator._on_final_boss_defeated
## when "Die Quelle" dies on GameManager.FINAL_FLOOR -- the run's win condition
## (docs/plan.md "Rahmen & Run-Ziel"). Mirrors death_screen.gd's code-built UI,
## but pauses the tree (like loadout_choice.gd) and offers an explicit choice
## instead of auto-continuing: return to the hub, or dismiss and keep descending
## (endless) via the stairs the boss death already spawned right next to the
## victory portal.

const SHOW_DELAY := 0.9   # let the boss death-pop play first (matches DeathScreen)

var _floor_label: Label
var _souls_label: Label
var _wins_label: Label
var _box: VBoxContainer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # buttons stay live while paused
	layer = 20  # same tier as DeathScreen, above PauseMenu (10)
	visible = false
	_build_ui()


func show_win(floor_reached: int, souls_earned: int, wins_total: int) -> void:
	await get_tree().create_timer(SHOW_DELAY).timeout
	_floor_label.text = "Ebene erreicht: %d" % floor_reached
	_souls_label.text = "Seelen verdient: %d" % souls_earned
	_wins_label.text = "Gesamt-Siege: %d" % wins_total
	get_tree().paused = true
	visible = true


func _to_hub() -> void:
	get_tree().paused = false
	visible = false
	GameManager.return_to_hub()


func _continue_endless() -> void:
	# Dismiss: the run stays on FINAL_FLOOR with the victory portal, the stairs
	# and the boss loot still present. Grab the loot, then take the stairs to
	# keep descending (endless). "Zum Hub" is just a shortcut for the portal.
	get_tree().paused = false
	visible = false


func _build_ui() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.75)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	_box = VBoxContainer.new()
	_box.add_theme_constant_override("separation", 10)
	center.add_child(_box)
	var title := Label.new()
	title.text = "Die Quelle ist vernichtet!"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 32)
	title.add_theme_color_override("font_color", Color(1.0, 0.75, 0.3))
	_box.add_child(title)
	var subtitle := Label.new()
	subtitle.text = "Die Fleischseuche versiegt. Der Run ist gewonnen."
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 15)
	subtitle.modulate.a = 0.85
	_box.add_child(subtitle)
	_floor_label = _recap_label()
	_souls_label = _recap_label()
	_wins_label = _recap_label()
	_box.add_child(_make_button("Zum Hub", _to_hub))
	_box.add_child(_make_button("Endlos weiter →", _continue_endless))


func _recap_label() -> Label:
	var l := Label.new()
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", 20)
	_box.add_child(l)
	return l


func _make_button(text: String, handler: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(320, 38)
	b.pressed.connect(handler)
	return b
