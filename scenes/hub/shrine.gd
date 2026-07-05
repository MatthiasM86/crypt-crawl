extends Area2D
## Meta-upgrade shrine (hub): shows name/level/cost, press E while standing
## in the area to spend souls. Which upgrade it sells is set per-instance
## via upgrade_id (must match a key in GameManager.UPGRADE_DEFS).

@export var upgrade_id := "vitality"

var _player_near := false

@onready var _label: Label = $Info


func _ready() -> void:
	body_entered.connect(_on_body_changed.bind(true))
	body_exited.connect(_on_body_changed.bind(false))
	_refresh()


func _on_body_changed(_body: Node2D, entered: bool) -> void:
	_player_near = entered
	_refresh()


func _unhandled_input(event: InputEvent) -> void:
	if _player_near and event.is_action_pressed("interact"):
		if GameManager.buy_upgrade(upgrade_id):
			_flash()
		_refresh()


func _refresh() -> void:
	var def: Dictionary = GameManager.UPGRADE_DEFS[upgrade_id]
	var max_level: int = def["costs"].size()
	var cost := GameManager.upgrade_cost(upgrade_id)
	var text := "%s\n%s\nStufe %d/%d" % [
			def["label"], def["effect"], GameManager.upgrade_level(upgrade_id), max_level]
	if cost < 0:
		text += "\nMAX"
	else:
		text += "\n%d Seelen [E]" % cost
	_label.text = text


func _flash() -> void:
	modulate = Color(1.7, 1.7, 2.0)
	var t := create_tween()
	t.tween_property(self, "modulate", Color.WHITE, 0.35)
