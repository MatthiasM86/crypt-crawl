extends Area2D
## Floor exit. Touching it carries the player's HP to the next generated
## floor (GameManager owns the transition; the heal potion refills per floor).

var _used := false


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if _used or body.get("dead"):
		return
	_used = true
	GameManager.next_floor(body.hp)
