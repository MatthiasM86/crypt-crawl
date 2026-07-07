extends Area2D
## Run-bound active skill lying on the ground (from chests or the boss). The
## skill slot has no free space -- it's always exactly one -- so touching
## it always offers a LoadoutChoice swap against the currently equipped
## skill; touching your own equipped skill is a deliberate non-event.

@export var skill_id := "frostnova"


func _ready() -> void:
	var def: Dictionary = GameManager.SKILL_DEFS[skill_id]
	$Visual.texture = load("res://assets/sprites/props/skill_%s.png" % skill_id)
	$Glow.color = def["color"]
	$Name.text = def["label"]
	body_entered.connect(_on_body_entered)
	_start_bob.call_deferred()


func _start_bob() -> void:
	var t := create_tween().set_loops()
	t.tween_property(self, "position:y", position.y - 4.0, 0.7).set_trans(Tween.TRANS_SINE)
	t.tween_property(self, "position:y", position.y + 4.0, 0.7).set_trans(Tween.TRANS_SINE)


func _on_body_entered(body: Node2D) -> void:
	if not body.has_method("set_skill") or body.skill_id == skill_id:
		return
	LoadoutChoice.offer("skill", skill_id, [body.skill_id], 1, body, self)
