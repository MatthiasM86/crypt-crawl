extends Area2D
## Run-bound relic lying on the ground (from chests or the boss). Touching it
## always pauses via LoadoutChoice -- "take it" if there's a free slot
## (player.RELIC_MAX), otherwise a swap; decline and it stays lying.

@export var relic_id := "lifesteal"


func _ready() -> void:
	var def: Dictionary = GameManager.RELIC_DEFS[relic_id]
	$Visual.texture = load("res://assets/sprites/props/relic_%s.png" % relic_id)
	$Glow.color = def["color"]
	$Name.text = def["label"]
	body_entered.connect(_on_body_entered)
	_start_bob.call_deferred()


func _start_bob() -> void:
	var t := create_tween().set_loops()
	t.tween_property(self, "position:y", position.y - 4.0, 0.7).set_trans(Tween.TRANS_SINE)
	t.tween_property(self, "position:y", position.y + 4.0, 0.7).set_trans(Tween.TRANS_SINE)


func _on_body_entered(body: Node2D) -> void:
	if not body.has_method("add_relic") or body.relics.has(relic_id):
		return
	LoadoutChoice.offer("relic", relic_id, body.relics, body.RELIC_MAX, body, self)
