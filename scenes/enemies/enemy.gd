extends CharacterBody2D
## Training-dummy enemy: has HP, flashes, gets knocked back, dies with a pop.
## Contract used by the player (duck-typed): take_damage(amount, source_position)
## and the `dead` flag. Phase 4 step 3 turns this into the Enemy base scene;
## the AI state machine and melee/ranged variants layer on top of this file
## without changing take_damage/knockback/flash.

# --- Feel dials -------------------------------------------------------------
const KNOCKBACK_SPEED := 260.0      # px/s impulse when hit
const KNOCKBACK_FRICTION := 1100.0  # px/s^2 decay -> ~30 px slide
const FLASH_TIME := 0.15
const DEATH_POP_TIME := 0.12
# ----------------------------------------------------------------------------

@export var max_hp := 3

var hp: int
var dead := false
var _knockback := Vector2.ZERO
var _flash_tween: Tween

@onready var _visual: Polygon2D = $Visual


func _ready() -> void:
	hp = max_hp


func _physics_process(delta: float) -> void:
	velocity = _knockback
	_knockback = _knockback.move_toward(Vector2.ZERO, KNOCKBACK_FRICTION * delta)
	move_and_slide()


func take_damage(amount: int, source_position: Vector2) -> void:
	if dead:
		return
	hp -= amount
	_knockback = (global_position - source_position).normalized() * KNOCKBACK_SPEED
	_play_flash()
	if hp <= 0:
		_die()


func _play_flash() -> void:
	if _flash_tween:
		_flash_tween.kill()
	_visual.material.set_shader_parameter("flash_amount", 1.0)
	_flash_tween = create_tween()
	_flash_tween.tween_property(_visual.material, "shader_parameter/flash_amount", 0.0, FLASH_TIME)


func _die() -> void:
	dead = true
	# Stop blocking movement/clicks immediately; can't free shapes mid-physics.
	$CollisionShape2D.set_deferred("disabled", true)
	$ClickArea/ClickShape.set_deferred("disabled", true)
	set_physics_process(false)
	var t := create_tween().set_parallel()
	t.tween_property(self, "scale", Vector2(1.35, 1.35), DEATH_POP_TIME)
	t.tween_property(self, "modulate:a", 0.0, DEATH_POP_TIME)
	t.chain().tween_callback(queue_free)
