extends Area2D
## Spawns when the boss dies. Touching it ends the run as a WIN:
## GameManager banks the victory and returns to the hub.

var _used := false


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if _used or body.get("dead"):
		return
	_used = true
	GameManager.run_won()
