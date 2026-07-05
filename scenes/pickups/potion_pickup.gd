extends Area2D
## Health potion drop (from slain enemies). Never a dead pickup: goes into
## the belt if there's room, heals on the spot if the belt is full but the
## player is injured, and converts to souls at full belt + full HP.

const FULL_CONVERT_SOULS := 5
const SOUL_SCENE := preload("res://scenes/pickups/soul_wisp.tscn")


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
	if not body.has_method("take_potion_pickup"):
		return
	if body.take_potion_pickup():
		Sfx.play("pickup")
	else:
		var wisp := SOUL_SCENE.instantiate()
		wisp.value = FULL_CONVERT_SOULS
		wisp.position = global_position
		get_parent().add_child.call_deferred(wisp)
	queue_free()
