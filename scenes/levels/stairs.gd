extends "res://scenes/levels/interact_zone.gd"
## Floor exit. Standing on it and pressing E carries HP, potion belt and
## relics to the next generated floor (explicit confirm -- walking over
## stairs by accident used to end exploration prematurely).

var _used := false


func _activate(body: Node2D) -> void:
	if _used:
		return
	_used = true
	Sfx.play("stairs")
	GameManager.next_floor(body.hp, body.potion_charges, body.relics.duplicate())
