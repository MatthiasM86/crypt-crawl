extends Area2D
## Spawns when the boss dies (the win itself is banked on the kill).
## Touching it ends the run and returns to the hub -- the safe exit,
## as opposed to the stairs that continue the descent.

var _used := false


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if _used or body.get("dead"):
		return
	_used = true
	Sfx.play("stairs")
	GameManager.return_to_hub()
