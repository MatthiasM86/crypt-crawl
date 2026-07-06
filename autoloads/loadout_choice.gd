extends CanvasLayer
## Unified "keep or swap" choice popup for relics/weapons/skills at capacity
## (docs/plan.md Ausblick 6, Entscheidung Juli 2026). Pauses the tree while
## open (PROCESS_MODE_ALWAYS) so nothing can hit the player mid-decision.
## Declining leaves the new pickup lying in the world -- same "stays lying"
## idiom relics already used before this system existed.

var _pickup: Node = null
var _player: Node = null
var _kind := ""
var _new_id := ""
var _box: VBoxContainer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 15  # above PauseMenu (10), below DeathScreen (20)
	visible = false
	_build_ui()


func offer(kind: String, new_id: String, current_ids: Array, player: Node, pickup: Node) -> void:
	_kind = kind
	_new_id = new_id
	_player = player
	_pickup = pickup
	var defs := _defs_for(kind)
	for c in _box.get_children():
		c.queue_free()
	var new_def: Dictionary = defs[new_id]
	var title := Label.new()
	title.text = "Neuer Fund: %s" % new_def["label"]
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 22)
	_box.add_child(title)
	var desc := Label.new()
	desc.text = new_def["desc"]
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.add_theme_font_size_override("font_size", 14)
	desc.modulate.a = 0.85
	_box.add_child(desc)
	for old_id in current_ids:
		var old_def: Dictionary = defs[old_id]
		_box.add_child(_make_button(
				"Ersetzen: %s  →  %s" % [old_def["label"], new_def["label"]],
				_choose.bind(old_id)))
	_box.add_child(_make_button("Ablehnen (liegen lassen)", _choose.bind("")))
	get_tree().paused = true
	visible = true


func _choose(old_id: String) -> void:
	get_tree().paused = false
	visible = false
	if old_id == "" or not is_instance_valid(_player):
		return  # declined, or player gone -- pickup stays put either way
	match _kind:
		"relic":
			_player.replace_relic(old_id, _new_id)
		"weapon":
			_player.set_weapon(_new_id)
		"skill":
			_player.set_skill(_new_id)
	if is_instance_valid(_pickup):
		_pickup.queue_free()


func _defs_for(kind: String) -> Dictionary:
	match kind:
		"relic":
			return GameManager.RELIC_DEFS
		"weapon":
			return GameManager.WEAPON_DEFS
		_:
			return GameManager.SKILL_DEFS


func _build_ui() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.7)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	_box = VBoxContainer.new()
	_box.add_theme_constant_override("separation", 8)
	center.add_child(_box)


func _make_button(text: String, handler: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(360, 36)
	b.pressed.connect(handler)
	return b
