extends Area2D
## Spawns when the boss dies (the win itself is banked on the kill).
## Touching it ends the run and returns to the hub -- the safe exit,
## as opposed to the stairs that continue the descent.

const SPIN_SPEED := 0.6  # rad/s -- vortex swirl (sprite rotation)

var _used := false
var _t := 0.0
@onready var _swirl: Sprite2D = $Swirl


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
	_t += delta
	_swirl.rotation += SPIN_SPEED * delta
	_swirl.scale = Vector2.ONE * (1.0 + 0.04 * sin(_t * 2.0))  # gentle pulse


func _on_body_entered(body: Node2D) -> void:
	if _used or body.get("dead"):
		return
	_used = true
	Sfx.play("stairs")
	GameManager.return_to_hub()
