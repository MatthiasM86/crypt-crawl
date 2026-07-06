extends "res://scenes/levels/interact_zone.gd"
## Hub portal: stand inside and press E to start a fresh run.

var _used := false


func _activate(_body: Node2D) -> void:
	if _used:
		return
	_used = true
	Sfx.play("stairs")
	GameManager.start_run()
