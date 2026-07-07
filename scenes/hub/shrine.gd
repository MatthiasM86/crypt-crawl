extends Area2D
## Meta-upgrade shrine (hub): shows name/level/cost, press E while standing
## in the area to spend souls. Which upgrade it sells is set per-instance
## via upgrade_id (must match a key in GameManager.UPGRADE_DEFS).

@export var upgrade_id := "vitality"

# Per-upgrade shrine sprite (recolored gem) + a matching glow colour.
const GEM_TEX := {
	"vitality": preload("res://assets/sprites/props/shrine_vitality.png"),
	"might": preload("res://assets/sprites/props/shrine_might.png"),
	"reflexes": preload("res://assets/sprites/props/shrine_reflexes.png"),
	"belt": preload("res://assets/sprites/props/shrine_belt.png"),
}
const GEM_GLOW := {
	"vitality": Color(1.0, 0.4, 0.4),
	"might": Color(1.0, 0.7, 0.35),
	"reflexes": Color(0.4, 0.9, 1.0),
	"belt": Color(0.8, 0.5, 1.0),
}

var _player_near := false

@onready var _label: Label = $Info


func _ready() -> void:
	if upgrade_id in GEM_TEX:
		$Visual.texture = GEM_TEX[upgrade_id]
		$Glow.color = GEM_GLOW[upgrade_id]
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
	# Past the finite curve the shrine sells endless mini-tiers: the label
	# switches to the (weaker) endless increment and "Stufe n (∞)".
	var def: Dictionary = GameManager.UPGRADE_DEFS[upgrade_id]
	var max_level: int = def["costs"].size()
	var level := GameManager.upgrade_level(upgrade_id)
	var cost := GameManager.upgrade_cost(upgrade_id)
	var effect: String = def["effect"]
	var stufe := "Stufe %d/%d" % [level, max_level]
	if level >= max_level and def.has("endless"):
		effect = def["endless"]["effect"]
		stufe = "Stufe %d (∞)" % level
	var text := "%s\n%s\n%s" % [def["label"], effect, stufe]
	if cost < 0:
		text += "\nMAX"
	else:
		text += "\n%d Seelen [E]" % cost
	_label.text = text


func _flash() -> void:
	modulate = Color(1.7, 1.7, 2.0)
	var t := create_tween()
	t.tween_property(self, "modulate", Color.WHITE, 0.35)
