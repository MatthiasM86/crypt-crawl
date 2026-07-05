extends Area2D
## Health potion drop (from slain enemies). Walk over it to gain a belt
## charge via the duck-typed add_potion() -> bool; stays on the ground if
## the belt is full.


func _ready() -> void:
	add_to_group("pickups")
	body_entered.connect(_on_body_entered)
	# Deferred: spawners may position us after add_child; capturing
	# position.y in the same frame would bob around the wrong spot.
	_start_bob.call_deferred()


func _start_bob() -> void:
	var t := create_tween().set_loops()
	t.tween_property(self, "position:y", position.y - 3.0, 0.6).set_trans(Tween.TRANS_SINE)
	t.tween_property(self, "position:y", position.y + 3.0, 0.6).set_trans(Tween.TRANS_SINE)


func _on_body_entered(body: Node2D) -> void:
	if body.has_method("add_potion") and body.add_potion():
		queue_free()
