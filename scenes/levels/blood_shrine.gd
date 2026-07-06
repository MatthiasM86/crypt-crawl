extends "res://scenes/levels/interact_zone.gd"
## Blood shrine (prefab rooms): sacrifice HP for souls, once per shrine.
## Uses the player's sacrifice_hp() so i-frames can't dodge the cost.

const HP_COST := 3
const SOUL_REWARD := 35
const SOUL_SCENE := preload("res://scenes/pickups/soul_wisp.tscn")

var _used := false


func _activate(body: Node2D) -> void:
	if _used:
		return
	if not body.has_method("sacrifice_hp") or not body.sacrifice_hp(HP_COST):
		return  # too weak to pay -- shrine stays lit
	_used = true
	Sfx.play("relic")
	modulate = Color(0.5, 0.45, 0.5)
	$Glow.energy = 0.1
	$Hint.text = "erschöpft"
	var per_wisp := SOUL_REWARD / 3
	for i in 3:
		var wisp := SOUL_SCENE.instantiate()
		wisp.value = per_wisp if i > 0 else SOUL_REWARD - 2 * per_wisp
		wisp.position = position
		get_parent().add_child.call_deferred(wisp)
