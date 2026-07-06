extends Area2D
## Run-bound relic lying on the ground (from chests or the boss). Auto-pickup
## on touch if the player has a free slot (player.RELIC_MAX); otherwise
## LoadoutChoice offers a swap -- decline and it stays lying.

@export var relic_id := "lifesteal"


func _ready() -> void:
	var def: Dictionary = GameManager.RELIC_DEFS[relic_id]
	$Visual.color = def["color"]
	$Glow.color = def["color"]
	$Name.text = def["label"]
	body_entered.connect(_on_body_entered)
	_start_bob.call_deferred()


func _start_bob() -> void:
	var t := create_tween().set_loops()
	t.tween_property(self, "position:y", position.y - 4.0, 0.7).set_trans(Tween.TRANS_SINE)
	t.tween_property(self, "position:y", position.y + 4.0, 0.7).set_trans(Tween.TRANS_SINE)


func _on_body_entered(body: Node2D) -> void:
	if not body.has_method("add_relic"):
		return
	if body.add_relic(relic_id):
		queue_free()
	else:
		# add_relic() only fails on a full belt here -- chest/boss drops
		# already exclude relics the run owns, so this can't be a duplicate.
		LoadoutChoice.offer("relic", relic_id, body.relics, body, self)
