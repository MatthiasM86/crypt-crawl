extends Node2D
## Soul pickup: bursts out of a slain enemy, then homes to the player and
## banks its value in GameManager (souls persist across death via the save
## file). Pure Node2D — no physics; collection is a distance check.

const BURST_TIME := 0.3
const BURST_DECEL := 300.0
const HOME_SPEED := 520.0
const HOME_ACCEL := 2400.0
const COLLECT_DIST := 20.0
const MAX_LIFE := 6.0   # failsafe: bank anyway so souls never get lost

var value := 2

var _age := 0.0
var _vel := Vector2.ZERO
var _player: Node2D


func _ready() -> void:
	_player = get_tree().get_first_node_in_group("player") as Node2D
	_vel = Vector2.from_angle(randf() * TAU) * randf_range(60.0, 140.0)


func _process(delta: float) -> void:
	_age += delta
	if _age > MAX_LIFE:
		_collect()
		return
	if _age < BURST_TIME or _player == null or not is_instance_valid(_player):
		position += _vel * delta
		_vel = _vel.move_toward(Vector2.ZERO, BURST_DECEL * delta)
		return
	var dir := global_position.direction_to(_player.global_position)
	_vel = _vel.move_toward(dir * HOME_SPEED, HOME_ACCEL * delta)
	position += _vel * delta
	if global_position.distance_to(_player.global_position) < COLLECT_DIST:
		_collect()


func _collect() -> void:
	GameManager.add_souls(value)
	queue_free()
