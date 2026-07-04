extends CharacterBody2D
## Diablo-style click-to-move / attack-move.
## Left click (action "click"): on enemy -> pursue + strike when in range;
## on ground -> walk there. Holding steers continuously.

# --- Feel dials -------------------------------------------------------------
const MOVE_SPEED := 300.0
const ATTACK_RANGE := 56.0       # start swing when this close to target center
const ATTACK_COOLDOWN := 0.5     # time between swing starts (docs/plan.md)
const ATTACK_WINDUP := 0.12      # swing start -> damage frame
const ATTACK_RECOVER := 0.15     # damage frame -> can act again
const ATTACK_DAMAGE := 1
const HIT_TRAUMA := 0.22
const KILL_TRAUMA := 0.35
# ----------------------------------------------------------------------------

const CLICKABLE_MASK := 32  # physics layer 6 "clickable" (enemy ClickAreas)

enum State { IDLE, MOVE, ATTACK }

var state := State.IDLE
var attack_target: Node2D = null
var _click_held := false
var _cooldown_left := 0.0
var _attack_time := 0.0
var _struck := false

@onready var _nav: NavigationAgent2D = $NavigationAgent2D
@onready var _pivot: Node2D = $AttackPivot
@onready var _hitbox: Area2D = $AttackPivot/Hitbox
@onready var _weapon: Polygon2D = $AttackPivot/WeaponVisual
@onready var _camera: Camera2D = $Camera2D


func _unhandled_input(event: InputEvent) -> void:
	# Only records intent; space-state queries must run in _physics_process.
	if event.is_action_pressed("click"):
		_click_held = true
	elif event.is_action_released("click"):
		_click_held = false


func _physics_process(delta: float) -> void:
	_cooldown_left = maxf(_cooldown_left - delta, 0.0)
	_validate_target()
	if _click_held and state != State.ATTACK:
		_apply_click_intent()
	if state == State.ATTACK:
		_tick_attack(delta)
	else:
		_tick_movement()


func _validate_target() -> void:
	if attack_target and (not is_instance_valid(attack_target) or attack_target.get("dead")):
		attack_target = null


func _apply_click_intent() -> void:
	var mouse_pos := get_global_mouse_position()
	var enemy := _enemy_at_point(mouse_pos)
	if enemy:
		attack_target = enemy
	else:
		attack_target = null
		_nav.target_position = mouse_pos


func _enemy_at_point(point: Vector2) -> Node2D:
	var params := PhysicsPointQueryParameters2D.new()
	params.position = point
	params.collision_mask = CLICKABLE_MASK
	params.collide_with_areas = true
	params.collide_with_bodies = false
	for hit in get_world_2d().direct_space_state.intersect_point(params, 4):
		var candidate := (hit.collider as Node).get_parent() as Node2D
		if candidate and candidate.has_method("take_damage") and not candidate.get("dead"):
			return candidate
	return null


func _tick_movement() -> void:
	if attack_target:
		_pivot.rotation = (attack_target.global_position - global_position).angle()
		if global_position.distance_to(attack_target.global_position) <= ATTACK_RANGE:
			velocity = Vector2.ZERO
			state = State.IDLE
			if _cooldown_left == 0.0:
				_begin_attack()
			return
		_nav.target_position = attack_target.global_position
	if _nav.is_navigation_finished():
		velocity = Vector2.ZERO
		state = State.IDLE
		return
	state = State.MOVE
	var next := _nav.get_next_path_position()
	velocity = global_position.direction_to(next) * MOVE_SPEED
	if attack_target == null and velocity != Vector2.ZERO:
		_pivot.rotation = velocity.angle()
	move_and_slide()


func _begin_attack() -> void:
	state = State.ATTACK
	_attack_time = 0.0
	_struck = false
	_cooldown_left = ATTACK_COOLDOWN
	velocity = Vector2.ZERO
	_weapon.visible = true
	_weapon.position.x = 16.0
	var t := create_tween()
	t.tween_property(_weapon, "position:x", 34.0, ATTACK_WINDUP)
	t.tween_property(_weapon, "position:x", 16.0, ATTACK_RECOVER)


func _tick_attack(delta: float) -> void:
	_attack_time += delta
	if not _struck and _attack_time >= ATTACK_WINDUP:
		_struck = true
		_strike()
	if _attack_time >= ATTACK_WINDUP + ATTACK_RECOVER:
		_weapon.visible = false
		state = State.IDLE


func _strike() -> void:
	var landed := false
	var killed := false
	for body in _hitbox.get_overlapping_bodies():
		if body.has_method("take_damage") and not body.get("dead"):
			body.take_damage(ATTACK_DAMAGE, global_position)
			landed = true
			if body.get("dead"):
				killed = true
	if killed:
		_camera.add_trauma(KILL_TRAUMA)
	elif landed:
		_camera.add_trauma(HIT_TRAUMA)
