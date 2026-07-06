extends CharacterBody2D
## Diablo-style click-to-move / attack-move.
## Left click (action "click"): on enemy -> pursue + strike when in range;
## on ground -> walk there. Holding steers continuously.
## Damage contract (duck-typed, mirrors enemies): take_damage(amount,
## source_position) + `dead` flag -- enemies and projectiles call/read these.

# --- Feel dials -------------------------------------------------------------
const MOVE_SPEED := 300.0
const ATTACK_RANGE := 56.0       # start swing when this close to target center
const ATTACK_COOLDOWN := 0.5     # time between swing starts (docs/plan.md)
const ATTACK_WINDUP := 0.12      # swing start -> damage frame
const ATTACK_RECOVER := 0.15     # damage frame -> can act again
const ATTACK_DAMAGE := 1
const HIT_TRAUMA := 0.22
const KILL_TRAUMA := 0.35
const MAX_HP := 10
const POTION_HEAL := 5
const POTION_MAX := 3            # belt size; drops beyond this stay lying
const DASH_SPEED := 950.0        # toward cursor; ~140 px per dash
const DASH_TIME := 0.15
const DASH_COOLDOWN := 0.8
const SLAM_WINDUP := 0.2         # right-click AoE: commit before the boom
const SLAM_RECOVER := 0.25
const SLAM_COOLDOWN := 3.0
const SLAM_DAMAGE := 2
const SLAM_RADIUS := 90.0
const SLAM_KNOCKBACK := 2.2      # multiplier on the enemies' base knockback
const SLAM_TRAUMA := 0.5
const HURT_TRAUMA := 0.45        # taking a hit out-shakes dealing one
const INVULN_TIME := 0.6         # i-frames: 3 converging melees can't stunlock
const RELIC_MAX := 4             # run-bound relics carried at once
const SWIFT_BONUS := 40.0        # "Hetzjagd" relic: bonus move speed
const HEAVY_KNOCKBACK := 2.0     # "Wuchtklinge" relic: strike knockback scale
const HUD_MESSAGE_TIME := 3.0
const FLASH_TIME := 0.15
const HURT_ANIM_TIME := 0.22     # non-interrupting flinch: clip holds this long, control stays live
const DEATH_POP_TIME := 0.25
const DEATH_TRAUMA := 0.6
# ----------------------------------------------------------------------------

const CLICKABLE_MASK := 32  # physics layer 6 "clickable" (enemy ClickAreas)
const FIRE_PATCH := preload("res://scenes/effects/fire_patch.gd")

# 8-way sprite facing, indexed by round(pivot.rotation / 45deg). +Y is down, so
# rotation 0 = east, PI/2 = south. Names match the SpriteFrames clip suffixes.
const DIR8 := ["east", "south-east", "south", "south-west", "west", "north-west", "north", "north-east"]

enum State { IDLE, MOVE, ATTACK, DASH, SLAM }

var state := State.IDLE
var attack_target: Node2D = null
var hp: int
var potion_charges := 1
var dead := false
var relics: Array = []           # run-bound relic ids (GameManager.RELIC_DEFS)
# Effective stats = base const + permanent meta-upgrades + relics (in _ready).
var max_hp := MAX_HP
var attack_damage := ATTACK_DAMAGE
var slam_damage := SLAM_DAMAGE
var dash_cooldown := DASH_COOLDOWN
var potion_max := POTION_MAX
var move_speed := MOVE_SPEED
var max_dash_charges := 1
var dash_charges := 1
var dash_cooldown_left := 0.0    # public: HUD reads these
var skill_cooldown_left := 0.0
var hud_message := ""            # transient announcement (relic pickups)
var hud_message_left := 0.0
var _click_held := false
var _dash_requested := false
var _skill_requested := false
var _dash_dir := Vector2.ZERO
var _dash_time_left := 0.0
var _slam_time := 0.0
var _slam_struck := false
var _cooldown_left := 0.0
var _attack_time := 0.0
var _struck := false
var _invuln_left := 0.0
var _hurt_left := 0.0
var _flash_tween: Tween
var _blink_tween: Tween

@onready var _nav: NavigationAgent2D = $NavigationAgent2D
@onready var _pivot: Node2D = $AttackPivot
@onready var _hitbox: Area2D = $AttackPivot/Hitbox
@onready var _camera: Camera2D = $Camera2D
@onready var _visual: AnimatedSprite2D = $Visual


func _ready() -> void:
	relics = GameManager.carry_relics.duplicate()  # before stats: relics feed them
	_apply_meta_upgrades()
	dash_charges = max_dash_charges
	# Re-apply live when a hub shrine sells an upgrade (the hub player is
	# already spawned and would otherwise show stale stats until next run).
	GameManager.upgrades_changed.connect(_apply_meta_upgrades)
	# HP and potion belt carry across floor transitions; -1 marks a fresh run.
	if GameManager.carry_hp > 0:
		hp = GameManager.carry_hp
		potion_charges = GameManager.carry_potions
	else:
		hp = max_hp
		potion_charges = 1
	_pivot.rotation = PI / 2.0  # face south (toward the camera) on spawn
	_visual.play("idle_south")


func _apply_meta_upgrades() -> void:
	var old_max := max_hp
	max_hp = MAX_HP + 2 * GameManager.upgrades["vitality"]
	attack_damage = ATTACK_DAMAGE + GameManager.upgrades["might"]
	slam_damage = SLAM_DAMAGE + GameManager.upgrades["might"]
	dash_cooldown = DASH_COOLDOWN - 0.1 * GameManager.upgrades["reflexes"]
	potion_max = POTION_MAX + GameManager.upgrades["belt"]
	# Relic-driven stats live here too so one recompute covers both sources.
	move_speed = MOVE_SPEED + (SWIFT_BONUS if has_relic("swift") else 0.0)
	max_dash_charges = 2 if has_relic("dash_charge") else 1
	if max_hp > old_max and hp > 0:
		hp += max_hp - old_max  # fresh vitality fills the new squares


func has_relic(id: String) -> bool:
	return relics.has(id)


func add_relic(id: String) -> bool:
	if relics.size() >= RELIC_MAX or relics.has(id):
		return false
	relics.append(id)
	_apply_meta_upgrades()
	dash_charges = clampi(dash_charges + 1, 0, max_dash_charges)  # fresh charge feels good
	var def: Dictionary = GameManager.RELIC_DEFS[id]
	hud_message = "Relikt: %s — %s" % [def["label"], def["desc"]]
	hud_message_left = HUD_MESSAGE_TIME
	Sfx.play("relic")
	return true


func add_potion() -> bool:
	if potion_charges >= potion_max:
		return false
	potion_charges += 1
	return true


func _unhandled_input(event: InputEvent) -> void:
	# Only records intent; space-state queries must run in _physics_process.
	if event.is_action_pressed("click"):
		_click_held = true
	elif event.is_action_released("click"):
		_click_held = false
	elif event.is_action_pressed("potion"):
		_drink_potion()
	elif event.is_action_pressed("dash"):
		_dash_requested = true
	elif event.is_action_pressed("skill"):
		_skill_requested = true


func _physics_process(delta: float) -> void:
	if dead:
		return
	_invuln_left = maxf(_invuln_left - delta, 0.0)
	_hurt_left = maxf(_hurt_left - delta, 0.0)
	_cooldown_left = maxf(_cooldown_left - delta, 0.0)
	dash_cooldown_left = maxf(dash_cooldown_left - delta, 0.0)
	skill_cooldown_left = maxf(skill_cooldown_left - delta, 0.0)
	hud_message_left = maxf(hud_message_left - delta, 0.0)
	if dash_cooldown_left == 0.0 and dash_charges < max_dash_charges:
		dash_charges += 1
		if dash_charges < max_dash_charges:
			dash_cooldown_left = dash_cooldown
	_validate_target()
	if _dash_requested:
		_dash_requested = false
		_try_dash()
	if _skill_requested:
		_skill_requested = false
		_try_slam()
	if _click_held and state != State.ATTACK and state != State.SLAM:
		_apply_click_intent()
	if state == State.DASH:
		_tick_dash(delta)
	elif state == State.SLAM:
		_tick_slam(delta)
	elif state == State.ATTACK:
		_tick_attack(delta)
	else:
		_tick_movement()
	_update_animation()


func _dir_name() -> String:
	# Snap the attack-pivot facing to one of 8 sprite directions.
	return DIR8[posmod(int(round(_pivot.rotation / (PI / 4.0))), 8)]


func _update_animation() -> void:
	# State + facing -> "<state>_<dir>" clip. idle/walk loop; attack plays once
	# (non-looping in the SpriteFrames) and is left alone once it has started.
	if _hurt_left > 0.0:
		return  # hold the non-interrupting hurt flinch (physics/control still run)
	var base := "idle"
	match state:
		State.MOVE, State.DASH:
			base = "walk"
		State.ATTACK, State.SLAM:
			base = "attack"
	var want := base + "_" + _dir_name()
	if _visual.animation != want:
		_visual.play(want)


func _try_dash() -> void:
	# Dash cancels windups/slams (responsiveness is the point) and grants
	# i-frames; collision mask drops to world-only so you dash THROUGH enemies.
	# Charge-based: normally 1, the Schattenschritt relic grants a second.
	if dead or dash_charges <= 0 or state == State.DASH:
		return
	var dir := get_global_mouse_position() - global_position
	if dir.length() < 4.0:
		dir = Vector2.RIGHT.rotated(_pivot.rotation)
	_dash_dir = dir.normalized()
	state = State.DASH
	_dash_time_left = DASH_TIME
	dash_charges -= 1
	if dash_cooldown_left == 0.0:
		dash_cooldown_left = dash_cooldown
	_invuln_left = maxf(_invuln_left, DASH_TIME + 0.05)
	collision_mask = 1
	Sfx.play("dash")
	_visual.modulate.a = 0.55
	var t := create_tween()
	t.tween_property(_visual, "modulate:a", 1.0, DASH_TIME + 0.1)


func _tick_dash(delta: float) -> void:
	velocity = _dash_dir * DASH_SPEED
	move_and_slide()
	_dash_time_left -= delta
	if _dash_time_left <= 0.0:
		state = State.IDLE
		velocity = Vector2.ZERO
		collision_mask = 5


func _try_slam() -> void:
	if dead or skill_cooldown_left > 0.0 or state == State.DASH or state == State.SLAM:
		return
	skill_cooldown_left = SLAM_COOLDOWN
	state = State.SLAM
	_slam_time = 0.0
	_slam_struck = false
	velocity = Vector2.ZERO
	var t := create_tween()
	t.tween_property(_visual, "scale", Vector2(1.3, 1.3), SLAM_WINDUP)


func _tick_slam(delta: float) -> void:
	_slam_time += delta
	if not _slam_struck and _slam_time >= SLAM_WINDUP:
		_slam_struck = true
		_do_slam()
	if _slam_time >= SLAM_WINDUP + SLAM_RECOVER:
		state = State.IDLE


func _do_slam() -> void:
	_visual.scale = Vector2.ONE
	_camera.add_trauma(SLAM_TRAUMA)
	Sfx.play("slam")
	_spawn_slam_ring()
	if has_relic("fire_slam"):
		var patch := FIRE_PATCH.new()
		patch.position = global_position
		get_parent().add_child(patch)
	var kills := 0
	var shape := CircleShape2D.new()
	shape.radius = SLAM_RADIUS
	var params := PhysicsShapeQueryParameters2D.new()
	params.shape = shape
	params.transform = Transform2D(0.0, global_position)
	params.collision_mask = 4
	for hit in get_world_2d().direct_space_state.intersect_shape(params, 16):
		var body: Node = hit.collider
		if body.has_method("take_damage") and not body.get("dead"):
			body.take_damage(slam_damage, global_position, SLAM_KNOCKBACK)
			if body.get("dead"):
				kills += 1
	_apply_lifesteal(kills)


func _apply_lifesteal(kills: int) -> void:
	if kills > 0 and has_relic("lifesteal") and not dead:
		hp = mini(hp + kills, max_hp)


func _spawn_slam_ring() -> void:
	var ring := Line2D.new()
	ring.width = 6.0
	ring.default_color = Color(1, 0.9, 0.6, 0.9)
	var points := PackedVector2Array()
	for i in 33:
		points.append(Vector2.from_angle(TAU * i / 32.0) * SLAM_RADIUS)
	ring.points = points
	add_child(ring)
	var t := ring.create_tween().set_parallel()
	t.tween_property(ring, "scale", Vector2(1.25, 1.25), 0.25)
	t.tween_property(ring, "modulate:a", 0.0, 0.25)
	t.chain().tween_callback(ring.queue_free)


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
	velocity = global_position.direction_to(next) * move_speed
	if attack_target == null and velocity != Vector2.ZERO:
		_pivot.rotation = velocity.angle()
	move_and_slide()


func _begin_attack() -> void:
	state = State.ATTACK
	_attack_time = 0.0
	_struck = false
	_cooldown_left = ATTACK_COOLDOWN
	velocity = Vector2.ZERO
	# The swing is the "attack_<dir>" sprite clip, played by _update_animation().


func _tick_attack(delta: float) -> void:
	_attack_time += delta
	if not _struck and _attack_time >= ATTACK_WINDUP:
		_struck = true
		_strike()
	if _attack_time >= ATTACK_WINDUP + ATTACK_RECOVER:
		state = State.IDLE


func _strike() -> void:
	var landed := false
	var kills := 0
	var knockback := HEAVY_KNOCKBACK if has_relic("heavy_hits") else 1.0
	for body in _hitbox.get_overlapping_bodies():
		if body.has_method("take_damage") and not body.get("dead"):
			body.take_damage(attack_damage, global_position, knockback)
			landed = true
			if body.get("dead"):
				kills += 1
	if kills > 0:
		_camera.add_trauma(KILL_TRAUMA)
	elif landed:
		_camera.add_trauma(HIT_TRAUMA)
	if landed:
		Sfx.play("hit")
	_apply_lifesteal(kills)


func take_damage(amount: int, _source_position: Vector2, _knockback_scale := 1.0) -> void:
	# _source_position/_knockback_scale kept for contract symmetry with the
	# enemies (callers like the exploder blast pass all three); player
	# knockback stays a deliberate non-feature.
	if dead or _invuln_left > 0.0:
		return
	hp -= amount
	_invuln_left = INVULN_TIME
	_camera.add_trauma(HURT_TRAUMA)
	Sfx.play("hurt")
	_play_flash()
	if hp <= 0:
		_die()
	else:
		_play_invuln_blink()
		# Non-interrupting flinch: shows the hit landing without stopping control.
		# Skipped mid-swing so the player's own attack animation still reads.
		if state != State.ATTACK and state != State.SLAM \
				and _visual.sprite_frames.has_animation("hurt_" + _dir_name()):
			_hurt_left = HURT_ANIM_TIME
			_visual.play("hurt_" + _dir_name())


func take_potion_pickup() -> bool:
	## Called by potion pickups. Belt first; with a full belt an injured
	## player drinks on the spot. Returns false only at full belt + full HP
	## (the pickup then converts itself to souls) -- pickups never dead-end.
	if add_potion():
		return true
	if hp < max_hp:
		hp = mini(hp + _potion_heal_amount(), max_hp)
		_heal_feedback()
		return true
	return false


func _potion_heal_amount() -> int:
	return max_hp if has_relic("potion_power") else POTION_HEAL


func _drink_potion() -> void:
	if dead or potion_charges <= 0 or hp >= max_hp:
		return
	potion_charges -= 1
	hp = mini(hp + _potion_heal_amount(), max_hp)
	_heal_feedback()


func _heal_feedback() -> void:
	Sfx.play("potion")
	_visual.modulate = Color(0.55, 1.25, 0.6, _visual.modulate.a)
	var t := create_tween()
	t.tween_property(_visual, "modulate", Color(1, 1, 1, _visual.modulate.a), 0.4)


func _play_flash() -> void:
	if _flash_tween:
		_flash_tween.kill()
	_visual.material.set_shader_parameter("flash_amount", 1.0)
	_flash_tween = create_tween()
	_flash_tween.tween_property(_visual.material, "shader_parameter/flash_amount", 0.0, FLASH_TIME)


func _play_invuln_blink() -> void:
	if _blink_tween:
		_blink_tween.kill()
	_blink_tween = create_tween().set_loops(3)  # 3 * 0.2s = INVULN_TIME
	_blink_tween.tween_property(_visual, "modulate:a", 0.4, INVULN_TIME / 6.0)
	_blink_tween.tween_property(_visual, "modulate:a", 1.0, INVULN_TIME / 6.0)


func _die() -> void:
	dead = true
	velocity = Vector2.ZERO
	set_process_unhandled_input(false)
	# Can't free/disable shapes mid-physics-callback.
	$CollisionShape2D.set_deferred("disabled", true)
	if _blink_tween:
		_blink_tween.kill()
	_camera.add_trauma(DEATH_TRAUMA)
	Sfx.play("death_player")
	# Play the fall-back death clip in the last facing, then fade out inside
	# GameManager's 0.9s RESTART_DELAY (before the scene changes).
	_hurt_left = 0.0
	_visual.modulate.a = 1.0
	_visual.play("death_" + _dir_name())
	var t := create_tween()
	t.tween_interval(0.55)
	t.tween_property(_visual, "modulate:a", 0.0, 0.3)
	GameManager.player_died()
