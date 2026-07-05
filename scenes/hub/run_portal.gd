extends Area2D
## Hub portal: touching it starts a fresh run (GameManager.start_run()).

var _used := false


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(_body: Node2D) -> void:
	if _used:
		return
	_used = true
	GameManager.start_run()
