extends Area2D
## Hub portal: touching it starts a fresh run (GameManager.start_run()).

const SPIN_SPEED := 0.6  # rad/s -- the vortex swirls in-engine (sprite rotation)

var _used := false
var _t := 0.0
@onready var _swirl: Sprite2D = $Swirl


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
	_t += delta
	_swirl.rotation += SPIN_SPEED * delta
	_swirl.scale = Vector2.ONE * (1.0 + 0.04 * sin(_t * 2.0))  # gentle pulse


func _on_body_entered(_body: Node2D) -> void:
	if _used:
		return
	_used = true
	Sfx.play("stairs")
	GameManager.start_run()
