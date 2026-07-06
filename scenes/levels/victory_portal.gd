extends "res://scenes/levels/interact_zone.gd"
## Spawns when the boss dies (the win itself is banked on the kill).
## Stand inside and press E to end the run and return to the hub -- the
## safe exit, as opposed to the stairs right next to it that continue the
## descent. Explicit confirm: the two zones sit side by side.

var _used := false


func _activate(_body: Node2D) -> void:
	if _used:
		return
	_used = true
	Sfx.play("stairs")
	GameManager.return_to_hub()
