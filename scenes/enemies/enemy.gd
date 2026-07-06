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
const HURT_ANIM_TIME := 0.3          # flinch clip hold on a surviving hit
const DEATH_POP_TIME := 0.12
const TELEGRAPH_COLOR := Color(1.0, 0.85, 0.3)  # windup ramps body to this
const TELEGRAPH_SCALE := 1.15                    # ...and grows to this
const LUNGE_SPEED := 240.0                       # melee forward pop on strike
const WORLD_MASK := 1                            # LOS ray: walls/pillar only
const POTION_DROP_CHANCE := 0.22
const PICKUP_SCENE := preload("res://scenes/pickups/potion_pickup.tscn")
const SOUL_SCENE := preload("res://scenes/pickups/soul_wisp.tscn")
const RELIC_SCENE := preload("res://scenes/pickups/relic_pickup.tscn")
const ELITE_TINT := Color(0.9, 0.55, 1.0)  # violet: distinct from the yellow telegraph
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
@export var soul_value := 2         # meta-currency dropped on death
@export var ai_enabled := true      # false = passive training dummy
@export var elite := false          # generator flag: bigger, meaner, drops a relic
# ------------------------------------------------------------------------------

# 8-way sprite facing (see player.gd). +Y down: rotation 0 = east, PI/2 = south.
const DIR8 := ["east", "south-east", "south", "south-west", "west", "north-west", "north", "north-east"]

enum State { IDLE, CHASE, ATTACK }

var hp: int
var dead := false
var state := State.IDLE
var _base_scale := Vector2.ONE   # elites are bigger; telegraph scales relative
var _knockback := Vector2.ZERO
var _flash_tween: Tween
var _telegraph_tween: Tween
var _player: Node2D = null
var _base_color: Color
var _cooldown_left := 0.0
var _attack_time := 0.0
var _struck := false
var _hurt_left := 0.0

@onready var _visual: AnimatedSprite2D = $Visual
@onready var _nav: NavigationAgent2D = $NavigationAgent2D
@onready var _pivot: Node2D = $AttackPivot
@onready var _hitbox: Area2D = $AttackPivot/Hitbox


func _ready() -> void:
	if elite:
		max_hp = max_hp * 2 + 2
		attack_damage += 1
		soul_value *= 3
		_base_scale = Vector2(1.3, 1.3)
		_visual.scale = _base_scale
		_visual.self_modulate = ELITE_TINT
	hp = max_hp
	_base_color = _visual.self_modulate
	_player = get_tree().get_first_node_in_group("player") as Node2D
	if _visual.sprite_frames and _visual.sprite_frames.has_animation("idle_south"):
		_visual.play("idle_south")


func _physics_process(delta: float) -> void:
	_cooldown_left = maxf(_cooldown_left - delta, 0.0)
	_hurt_left = maxf(_hurt_left - delta, 0.0)
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
	_update_animation()


func _dir_name() -> String:
	return DIR8[posmod(int(round(_pivot.rotation / (PI / 4.0))), 8)]


func _update_animation() -> void:
	# State + facing -> "<state>_<dir>" clip; the color/scale telegraph and (for
	# melee) the forward lunge layer on top. Missing clip -> hold current frame.
	if _hurt_left > 0.0:
		return  # let the hit flinch play out (knockback still slides the body)
	var base := "idle"
	match state:
		State.CHASE:
			base = "walk"
		State.ATTACK:
			base = "attack"
	var want := base + "_" + _dir_name()
	var frames := _visual.sprite_frames
	if frames and frames.has_animation(want) and _visual.animation != want:
		_visual.play(want)


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
	_telegraph_tween.tween_property(_visual, "self_modulate", TELEGRAPH_COLOR, attack_windup)
	_telegraph_tween.tween_property(_visual, "scale", _base_scale * TELEGRAPH_SCALE, attack_windup)
	_show_attack_tell()


func _show_attack_tell() -> void:
	# Melee: the windup->strike now reads from the "attack_<dir>" sprite clip plus
	# the color/scale telegraph. Ranged overrides this; boss adds an AoE ring.
	pass


func _tick_attack(delta: float) -> void:
	_attack_time += delta
	if not _struck and _attack_time >= attack_windup:
		_struck = true
		_snap_telegraph_back()
		_perform_attack()
	if _attack_time >= attack_windup + attack_recover:
		state = State.CHASE


func _perform_attack() -> void:
	# Melee strike: locked-direction hitbox sweep + forward lunge via the
	# knockback channel. Overlap list is fine here: monitoring Area2D,
	# queried during _physics_process, not from a physics callback.
	_knockback = Vector2.RIGHT.rotated(_pivot.rotation) * LUNGE_SPEED
	for body in _hitbox.get_overlapping_bodies():
		if body.has_method("take_damage") and not body.get("dead"):
			body.take_damage(attack_damage, global_position)


func _snap_telegraph_back() -> void:
	# Hard snap, no ease-out: the contrast IS the "hit happened now" read.
	if _telegraph_tween:
		_telegraph_tween.kill()
	_visual.self_modulate = _base_color
	_visual.scale = _base_scale


func _cancel_attack() -> void:
	_snap_telegraph_back()


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


func take_damage(amount: int, source_position: Vector2, knockback_scale := 1.0) -> void:
	if dead:
		return
	hp -= amount
	_knockback = (global_position - source_position).normalized() * KNOCKBACK_SPEED * knockback_scale
	_play_flash()
	if ai_enabled and state == State.IDLE and _player_alive():
		state = State.CHASE  # hit from cover -> wake up
	if hp <= 0:
		_die()
	elif state != State.ATTACK and _visual.sprite_frames \
			and _visual.sprite_frames.has_animation("hurt_" + _dir_name()):
		# Flinch on a surviving hit -- skipped mid-windup so the attack telegraph
		# stays readable, and skipped entirely when there's no hurt clip (boss).
		_hurt_left = HURT_ANIM_TIME
		_visual.play("hurt_" + _dir_name())


func _play_flash() -> void:
	if _flash_tween:
		_flash_tween.kill()
	_visual.material.set_shader_parameter("flash_amount", 1.0)
	_flash_tween = create_tween()
	_flash_tween.tween_property(_visual.material, "shader_parameter/flash_amount", 0.0, FLASH_TIME)


func _die() -> void:
	dead = true
	_cancel_attack()
	Sfx.play("death_enemy")
	if randf() < POTION_DROP_CHANCE:
		var drop := PICKUP_SCENE.instantiate()
		drop.position = global_position  # before add_child: level sits at origin
		get_parent().add_child(drop)
	var wisp := SOUL_SCENE.instantiate()
	wisp.value = soul_value
	wisp.position = global_position
	get_parent().add_child(wisp)
	if elite:
		# Elites guarantee a relic the run doesn't own yet (souls burst as
		# fallback once the run holds everything).
		var owned: Array = _player.relics if _player_alive() and _player.get("relics") != null else []
		var relic_id: String = GameManager.random_unowned_relic(owned)
		if relic_id != "":
			var rp := RELIC_SCENE.instantiate()
			rp.relic_id = relic_id
			rp.position = global_position + Vector2(0, 24)
			get_parent().add_child(rp)
		else:
			for i in 3:
				var bonus := SOUL_SCENE.instantiate()
				bonus.value = 5
				bonus.position = global_position
				get_parent().add_child(bonus)
	# Stop blocking movement/clicks immediately; can't free shapes mid-physics.
	$CollisionShape2D.set_deferred("disabled", true)
	$ClickArea/ClickShape.set_deferred("disabled", true)
	set_physics_process(false)
	# Play the fall-back death clip in the last facing, then fade the corpse out.
	if _visual.sprite_frames and _visual.sprite_frames.has_animation("death_" + _dir_name()):
		_visual.play("death_" + _dir_name())
	var t := create_tween()
	t.tween_interval(0.55)
	t.tween_property(self, "modulate:a", 0.0, 0.3)
	t.tween_callback(queue_free)
