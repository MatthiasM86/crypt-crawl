extends Area2D
## Base for walk-in zones that need an explicit [E] confirm before firing
## (stairs, run portal, victory portal). Touch-triggered transitions kept
## happening by accident -- click paths run straight over the stairs, and
## after the boss the portal and stairs sit side by side. Subclasses
## override _activate(body); base tracks presence + the interact press.

var _player: Node2D = null


func _ready() -> void:
	body_entered.connect(_on_zone_entered)
	body_exited.connect(_on_zone_exited)


func _unhandled_input(event: InputEvent) -> void:
	if _player and is_instance_valid(_player) and not _player.get("dead") \
			and event.is_action_pressed("interact"):
		_activate(_player)


func _on_zone_entered(body: Node2D) -> void:
	_player = body


func _on_zone_exited(body: Node2D) -> void:
	if body == _player:
		_player = null


func _activate(_body: Node2D) -> void:
	pass  # override
