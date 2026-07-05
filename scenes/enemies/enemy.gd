extends CharacterBody2D
## Enemy base scene: HP / knockback / hit-flash / death (contract unchanged)
## plus the AI state machine IDLE -> CHASE -> ATTACK (docs/plan.md Phase 4.3).
## The base archetype IS the melee enemy; ranged_enemy.gd inherits this script
## and overrides positioning + attack delivery. Duck-typed contract used by
## the player: take_damage(amount, source_position) and the `dead` flag.

# --- Feel dials (shared) -----------------------------------------------------
const KNOCKBACK_SPEED := 260.0      # px/s impulse when hit
const KNOCKBACK_FRICTION := 1100.0  # px/s^2 decay -> ~30 px slide
const FLASH_TIME := 0.15
const DEATH_POP_TIME := 0.12
const TELEGRAPH_COLOR := Color(1.0, 0.85, 0.3)  # windup ramps body to this
const TELEGRAPH_SCALE := 1.15                    # ...and grows to this
const LUNGE_SPEED := 240.0                       # melee forward pop on strike
const WORLD_MASK := 1                            # LOS ray: walls/pillar only
# ------------------------------------------------------------------------------

# --- Archetype dials (variants override these in their .tscn) -----------------
@export var max_hp := 3
@export var move_speed := 200.0     # < player 300 so disengaging always works
@export var detect_radius := 320.0
@export var attack_range := 55.0
@export var attack_windup := 0.45   # dodge window: player covers 135 px
@export var attack_recover := 0.3
@export var attack_cooldown := 1.1
@export var attack_damage := 1
@export var ai_enabled := true      # false = passive training dummy
# ------------------------------------------------------------------------------

enum State { IDLE, CHASE, ATTACK }

var hp: int
var dead := false
var state := State.IDLE
var _knockback := Vector2.ZERO
var _flash_tween: Tween
var _telegraph_tween: Tween
var _player: Node2D = null
var _base_color: Color
var _cooldown_left := 0.0
var _attack_time := 0.0
var _struck := false

@onready var _visual: Polygon2D = $Visual
@onready var _nav: NavigationAgent2D = $NavigationAgent2D
@onready var _pivot: Node2D = $AttackPivot
@onready var _hitbox: Area2D = $AttackPivot/Hitbox
@onready var _weapon: Polygon2D = $AttackPivot/WeaponVisual


func _ready() -> void:
	hp = max_hp
	_base_color = _visual.color
	_player = get_tree().get_first_node_in_group("player") as Node2D


func _physics_process(delta: float) -> void:
	_cooldown_left = maxf(_cooldown_left - delta, 0.0)
	var ai_velocity := Vector2.ZERO
	if ai_enabled and _player_alive():
		match state:
			State.IDLE:
				_tick_idle()
			State.CHASE:
				ai_velocity = _chase_velocity()
			State.ATTACK:
				_tick_attack(delta)
	elif state != State.IDLE:
		_cancel_attack()
		state = State.IDLE
	velocity = ai_velocity + _knockback
	_knockback = _knockback.move_toward(Vector2.ZERO, KNOCKBACK_FRICTION * delta)
	move_and_slide()


func _tick_idle() -> void:
	if _distance_to_player() <= detect_radius and _has_los():
		state = State.CHASE  # permanent aggro; no de-aggro flicker at cover edges


func _chase_velocity() -> Vector2:
	_face_player()
	if _in_attack_position():
		if _cooldown_left == 0.0:
			_begin_attack()
		return Vector2.ZERO
	_nav.target_position = _player.global_position
	if _nav.is_navigation_finished():
		return Vector2.ZERO
	return global_position.direction_to(_nav.get_next_path_position()) * move_speed


func _in_attack_position() -> bool:
	# Base/melee: close enough. Ranged also demands line of sight.
	return _distance_to_player() <= attack_range


func _begin_attack() -> void:
	state = State.ATTACK
	_attack_time = 0.0
	_struck = false
	_cooldown_left = attack_cooldown
	_face_player()  # direction locks HERE -> sidestepping the windup dodges
	_start_telegraph()


func _start_telegraph() -> void:
	if _telegraph_tween:
		_telegraph_tween.kill()
	_telegraph_tween = create_tween().set_parallel()
	_telegraph_tween.tween_property(_visual, "color", TELEGRAPH_COLOR, attack_windup)
	_telegraph_tween.tween_property(_visual, "scale", Vector2.ONE * TELEGRAPH_SCALE, attack_windup)
	_show_attack_tell()


func _show_attack_tell() -> void:
	# Melee: blade creeps out along the locked strike direction ("where").
	# Ranged overrides this to a no-op.
	_weapon.visible = true
	_weapon.position.x = 10.0
	_telegraph_tween.tween_property(_weapon, "position:x", 22.0, attack_windup)


func _tick_attack(delta: float) -> void:
	_attack_time += delta
	if not _struck and _attack_time >= attack_windup:
		_struck = true
		_snap_telegraph_back()
		_perform_attack()
	if _attack_time >= attack_windup + attack_recover:
		_weapon.visible = false
		state = State.CHASE


func _perform_attack() -> void:
	# Melee strike: locked-direction hitbox sweep + forward lunge via the
	# knockback channel. Overlap list is fine here: monitoring Area2D,
	# queried during _physics_process, not from a physics callback.
	_weapon.position.x = 34.0
	_knockback = Vector2.RIGHT.rotated(_pivot.rotation) * LUNGE_SPEED
	for body in _hitbox.get_overlapping_bodies():
		if body.has_method("take_damage") and not body.get("dead"):
			body.take_damage(attack_damage, global_position)


func _snap_telegraph_back() -> void:
	# Hard snap, no ease-out: the contrast IS the "hit happened now" read.
	if _telegraph_tween:
		_telegraph_tween.kill()
	_visual.color = _base_color
	_visual.scale = Vector2.ONE


func _cancel_attack() -> void:
	_snap_telegraph_back()
	_weapon.visible = false


func _face_player() -> void:
	_pivot.rotation = (_player.global_position - global_position).angle()


func _distance_to_player() -> float:
	return global_position.distance_to(_player.global_position)


func _has_los() -> bool:
	var params := PhysicsRayQueryParameters2D.create(
			global_position, _player.global_position, WORLD_MASK)
	return get_world_2d().direct_space_state.intersect_ray(params).is_empty()


func _player_alive() -> bool:
	return _player != null and is_instance_valid(_player) and not _player.get("dead")


func take_damage(amount: int, source_position: Vector2) -> void:
	if dead:
		return
	hp -= amount
	_knockback = (global_position - source_position).normalized() * KNOCKBACK_SPEED
	_play_flash()
	if ai_enabled and state == State.IDLE and _player_alive():
		state = State.CHASE  # hit from cover -> wake up
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
	_cancel_attack()
	# Stop blocking movement/clicks immediately; can't free shapes mid-physics.
	$CollisionShape2D.set_deferred("disabled", true)
	$ClickArea/ClickShape.set_deferred("disabled", true)
	set_physics_process(false)
	var t := create_tween().set_parallel()
	t.tween_property(self, "scale", Vector2(1.35, 1.35), DEATH_POP_TIME)
	t.tween_property(self, "modulate:a", 0.0, DEATH_POP_TIME)
	t.chain().tween_callback(queue_free)
