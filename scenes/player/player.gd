extends CharacterBody2D
## Diablo-style click-to-move / attack-move.
## Left click (action "click"): on enemy -> pursue + strike when in range;
## on ground -> walk there. Holding steers continuously.
## Damage contract (duck-typed, mirrors enemies): take_damage(amount,
## source_position) + `dead` flag -- enemies and projectiles call/read these.

# --- Feel dials -------------------------------------------------------------
const MOVE_SPEED := 270.0
const HIT_TRAUMA := 0.22
const KILL_TRAUMA := 0.35
const MAX_HP := 10
const POTION_HEAL := 5
const POTION_MAX := 3            # belt size; drops beyond this stay lying
const DASH_SPEED := 950.0        # toward cursor; ~140 px per dash
const DASH_TIME := 0.15
const DASH_COOLDOWN := 0.8
const SKILL_WINDUP := 0.2        # right-click active skill: commit before it fires
const SKILL_RECOVER := 0.25      # shared windup/recover across all equippable skills
# --- Rundumschlag (starter skill) ---
const SLAM_DAMAGE := 2
const SLAM_RADIUS := 90.0
const SLAM_KNOCKBACK := 2.2      # multiplier on the enemies' base knockback
const SLAM_TRAUMA := 0.5
# --- Frostnova ---
const FROST_RADIUS := 100.0
const FROST_DURATION := 1.4
const FROST_FACTOR := 0.05       # near-total stop, not just a slow
# --- Blutopfer ---
const BLUTOPFER_COST := 2
const BLUTOPFER_RADIUS := 80.0
const BLUTOPFER_DAMAGE := 2
# --- Seelenkette ---
const SEELENKETTE_RADIUS := 140.0
const SEELENKETTE_CONE_DEG := 70.0   # half-angle in front of the facing direction
const SEELENKETTE_PULL := 420.0
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

enum State { IDLE, MOVE, ATTACK, DASH, SKILL }

var state := State.IDLE
var attack_target: Node2D = null
var hp: int
var potion_charges := 1
var dead := false
var relics: Array = []           # run-bound relic ids (GameManager.RELIC_DEFS)
var weapon_id := "kurzschwert"    # run-bound, always exactly one (GameManager.WEAPON_DEFS)
var skill_id := "rundumschlag"    # run-bound, always exactly one (GameManager.SKILL_DEFS)
# Effective stats = base const + permanent meta-upgrades + relics + weapon (in _ready).
var max_hp := MAX_HP
var attack_damage := 1
var attack_range := 56.0
var attack_windup := 0.12
var attack_recover := 0.15
var attack_cooldown := 0.5
var weapon_knockback := 1.0
var slam_damage := SLAM_DAMAGE
var dash_cooldown := DASH_COOLDOWN
var potion_max := POTION_MAX
var move_speed := MOVE_SPEED
var max_dash_charges := 1
var dash_charges := 1
# Run-bound boons from soul shrines (carry over stairs, die with the run).
var boon_max_hp := 0
var boon_damage := 0
var boon_skill_cd := 1.0         # multiplicative cooldown factor, stacks
var dash_cooldown_left := 0.0    # public: HUD reads these
var skill_cooldown_left := 0.0
var hud_message := ""            # transient announcement (relic/weapon/skill pickups)
var hud_message_left := 0.0
var _click_held := false
var _dash_requested := false
var _skill_requested := false
var _dash_dir := Vector2.ZERO
var _dash_time_left := 0.0
var _skill_time := 0.0
var _skill_struck := false
var _cooldown_left := 0.0
var _attack_time := 0.0
var _struck := false
var _invuln_left := 0.0
var _hurt_left := 0.0
var _flash_tween: Tween
var _blink_tween: Tween
var _windup_tween: Tween

@onready var _nav: NavigationAgent2D = $NavigationAgent2D
@onready var _pivot: Node2D = $AttackPivot
@onready var _hitbox: Area2D = $AttackPivot/Hitbox
@onready var _camera: Camera2D = $Camera2D
@onready var _visual: AnimatedSprite2D = $Visual


func _ready() -> void:
	relics = GameManager.carry_relics.duplicate()  # before stats: relics feed them
	weapon_id = GameManager.carry_weapon
	skill_id = GameManager.carry_skill
	boon_max_hp = int(GameManager.carry_boons.get("max_hp", 0))
	boon_damage = int(GameManager.carry_boons.get("damage", 0))
	boon_skill_cd = float(GameManager.carry_boons.get("skill_cd", 1.0))
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
	# Base shrine levels give the full increment; endless levels the weaker one
	# (see UPGRADE_DEFS): vitality +2/+1, reflexes -0.1s/-0.02s (0.25s floor),
	# might +1 weapon+skill damage per BASE level but skill-only past the cap.
	var old_max := max_hp
	max_hp = MAX_HP + 2 * GameManager.upgrade_base_level("vitality") \
			+ GameManager.upgrade_endless_level("vitality") + boon_max_hp
	slam_damage = SLAM_DAMAGE + GameManager.upgrades["might"]
	dash_cooldown = maxf(DASH_COOLDOWN - 0.1 * GameManager.upgrade_base_level("reflexes")
			- 0.02 * GameManager.upgrade_endless_level("reflexes"), 0.25)
	potion_max = POTION_MAX + GameManager.upgrades["belt"]
	# Relic-driven stats live here too so one recompute covers both sources.
	move_speed = MOVE_SPEED + (SWIFT_BONUS if has_relic("swift") else 0.0)
	max_dash_charges = 2 if has_relic("dash_charge") else 1
	if max_hp > old_max and hp > 0:
		hp += max_hp - old_max  # fresh vitality fills the new squares
	_apply_weapon()


func _apply_weapon() -> void:
	# Full moveset per weapon: hitbox size/position, range, timing and
	# knockback all differ (docs/plan.md Ausblick 6). Each weapon has its own
	# attack clips with the weapon visible in hand (attack_<weapon_id>_<dir>;
	# Kurzschwert ist der attack_<dir>-Basissatz).
	var def: Dictionary = GameManager.WEAPON_DEFS[weapon_id]
	attack_damage = def["damage"] + GameManager.upgrade_base_level("might") + boon_damage
	attack_range = def["range"]
	attack_windup = def["windup"]
	attack_recover = def["recover"]
	attack_cooldown = def["cooldown"]
	weapon_knockback = def["knockback"]
	# Deferred: callers include Area2D physics callbacks (pickup body_entered),
	# where reassigning a live CollisionShape2D's shape mid-flush is an error.
	_apply_hitbox_shape.call_deferred(def["hitbox_size"], def["hitbox_pos"])


func _apply_hitbox_shape(hitbox_size: Vector2, hitbox_pos: Vector2) -> void:
	var shape := RectangleShape2D.new()
	shape.size = hitbox_size
	$AttackPivot/Hitbox/HitboxShape.shape = shape
	$AttackPivot/Hitbox/HitboxShape.position = hitbox_pos


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


func replace_relic(old_id: String, new_id: String) -> void:
	## Called by LoadoutChoice when the relic belt is full and the player
	## chose to swap one out.
	relics.erase(old_id)
	relics.append(new_id)
	_apply_meta_upgrades()
	var def: Dictionary = GameManager.RELIC_DEFS[new_id]
	hud_message = "Relikt: %s — %s" % [def["label"], def["desc"]]
	hud_message_left = HUD_MESSAGE_TIME
	Sfx.play("relic")


func set_weapon(id: String) -> void:
	## Called directly (weapon slot has no "free space") or by LoadoutChoice.
	weapon_id = id
	_apply_weapon()
	var def: Dictionary = GameManager.WEAPON_DEFS[id]
	hud_message = "Waffe: %s — %s" % [def["label"], def["desc"]]
	hud_message_left = HUD_MESSAGE_TIME
	Sfx.play("relic")


func set_skill(id: String) -> void:
	skill_id = id
	skill_cooldown_left = 0.0  # fresh skill, ready immediately -- feels good
	var def: Dictionary = GameManager.SKILL_DEFS[id]
	hud_message = "Skill: %s — %s" % [def["label"], def["desc"]]
	hud_message_left = HUD_MESSAGE_TIME
	Sfx.play("relic")


func add_potion() -> bool:
	if potion_charges >= potion_max:
		return false
	potion_charges += 1
	return true


func add_boon(kind: String, value: float, label: String) -> void:
	## Soul-shrine purchase (run-bound). Stats recompute through the one
	## _apply_meta_upgrades pipeline; the max_hp diff-fill there also grants
	## the fresh HP squares.
	match kind:
		"max_hp":
			boon_max_hp += int(value)
		"damage":
			boon_damage += int(value)
		"skill_cd":
			boon_skill_cd *= value
		"potion":
			potion_charges = potion_max
	_apply_meta_upgrades()
	hud_message = "Boon: %s" % label
	hud_message_left = HUD_MESSAGE_TIME
	Sfx.play("boon")


func export_boons() -> Dictionary:
	## Stairs carry these to the next floor (GameManager.carry_boons).
	return {"max_hp": boon_max_hp, "damage": boon_damage, "skill_cd": boon_skill_cd}


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
		_try_skill()
	if _click_held and state != State.ATTACK and state != State.SKILL:
		_apply_click_intent()
	if state == State.DASH:
		_tick_dash(delta)
	elif state == State.SKILL:
		_tick_skill(delta)
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
	var d := _dir_name()
	var want := "idle_" + d
	match state:
		State.MOVE, State.DASH:
			want = "walk_" + d
		State.ATTACK:
			# Per-weapon swing (spiess = thrust, kriegshammer = overhead smash);
			# kurzschwert has no dedicated clip and falls back to the base chop.
			want = "attack_%s_%s" % [weapon_id, d]
			if not _visual.sprite_frames.has_animation(want):
				want = "attack_" + d
		State.SKILL:
			want = "attack_" + d
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
	if state == State.SKILL:
		_reset_skill_windup_visual()  # canceled windup: nothing else un-grows us
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


func _try_skill() -> void:
	if dead or skill_cooldown_left > 0.0 or state == State.DASH or state == State.SKILL:
		return
	skill_cooldown_left = GameManager.SKILL_DEFS[skill_id]["cooldown"] * boon_skill_cd
	state = State.SKILL
	_skill_time = 0.0
	_skill_struck = false
	velocity = Vector2.ZERO
	_windup_tween = create_tween()
	_windup_tween.tween_property(_visual, "scale", Vector2(1.3, 1.3), SKILL_WINDUP)


func _tick_skill(delta: float) -> void:
	_skill_time += delta
	if not _skill_struck and _skill_time >= SKILL_WINDUP:
		_skill_struck = true
		_perform_skill()
	if _skill_time >= SKILL_WINDUP + SKILL_RECOVER:
		state = State.IDLE


func _reset_skill_windup_visual() -> void:
	# The windup tween must die BEFORE the scale reset: it steps in idle time
	# after physics, so a live tween re-applies ~1.3 right over the reset and
	# the player stays grown permanently.
	if _windup_tween:
		_windup_tween.kill()
	_visual.scale = Vector2.ONE


func _perform_skill() -> void:
	_reset_skill_windup_visual()
	match skill_id:
		"rundumschlag":
			_do_rundumschlag()
		"frostnova":
			_do_frostnova()
		"blutopfer":
			_do_blutopfer()
		"seelenkette":
			_do_seelenkette()


func _do_rundumschlag() -> void:
	_camera.add_trauma(SLAM_TRAUMA)
	Sfx.play("slam")
	_spawn_skill_ring(SLAM_RADIUS, Color(1, 0.9, 0.6, 0.9))
	if has_relic("fire_slam"):
		var patch := FIRE_PATCH.new()
		patch.position = global_position
		get_parent().add_child(patch)
	var kills := 0
	for body in _bodies_in_radius(SLAM_RADIUS):
		if body.has_method("take_damage") and not body.get("dead"):
			body.take_damage(slam_damage, global_position, SLAM_KNOCKBACK)
			if body.get("dead"):
				kills += 1
	_apply_lifesteal(kills)


func _do_frostnova() -> void:
	_camera.add_trauma(0.3)
	Sfx.play("slam")
	_spawn_skill_ring(FROST_RADIUS, Color(0.6, 0.85, 1.0, 0.9))
	for body in _bodies_in_radius(FROST_RADIUS):
		if body.has_method("apply_slow"):
			body.apply_slow(FROST_FACTOR, FROST_DURATION)


func _do_blutopfer() -> void:
	if not sacrifice_hp(BLUTOPFER_COST):
		return  # too low on HP -- the skill fizzles rather than kill you
	_camera.add_trauma(0.45)
	_spawn_skill_ring(BLUTOPFER_RADIUS, Color(0.75, 0.15, 0.2, 0.9))
	var kills := 0
	for body in _bodies_in_radius(BLUTOPFER_RADIUS):
		if body.has_method("take_damage") and not body.get("dead"):
			body.take_damage(BLUTOPFER_DAMAGE, global_position)
			if body.get("dead"):
				kills += 1
	if kills > 0:
		hp = mini(hp + kills, max_hp)  # instant lifesteal off this nova's kills


func _do_seelenkette() -> void:
	_camera.add_trauma(0.25)
	Sfx.play("dash")
	_spawn_skill_ring(SEELENKETTE_RADIUS, Color(0.6, 0.4, 0.9, 0.7))
	var facing := Vector2.RIGHT.rotated(_pivot.rotation)
	var cone := deg_to_rad(SEELENKETTE_CONE_DEG)
	for body in _bodies_in_radius(SEELENKETTE_RADIUS):
		if not body.has_method("apply_pull"):
			continue
		var to_body: Vector2 = body.global_position - global_position
		if to_body.length() < 1.0:
			continue
		if absf(facing.angle_to(to_body)) <= cone:
			body.apply_pull(global_position, SEELENKETTE_PULL)


func _bodies_in_radius(radius: float) -> Array:
	var shape := CircleShape2D.new()
	shape.radius = radius
	var params := PhysicsShapeQueryParameters2D.new()
	params.shape = shape
	params.transform = Transform2D(0.0, global_position)
	params.collision_mask = 4
	var out: Array = []
	for hit in get_world_2d().direct_space_state.intersect_shape(params, 16):
		out.append(hit.collider)
	return out


func _apply_lifesteal(kills: int) -> void:
	if kills > 0 and has_relic("lifesteal") and not dead:
		hp = mini(hp + kills, max_hp)


func _spawn_skill_ring(radius: float, color: Color) -> void:
	var ring := Line2D.new()
	ring.width = 6.0
	ring.default_color = color
	var points := PackedVector2Array()
	for i in 33:
		points.append(Vector2.from_angle(TAU * i / 32.0) * radius)
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
		if global_position.distance_to(attack_target.global_position) <= attack_range:
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
	_cooldown_left = attack_cooldown
	velocity = Vector2.ZERO
	# The swing is the "attack_<dir>" sprite clip, played by _update_animation().


func _tick_attack(delta: float) -> void:
	_attack_time += delta
	if not _struck and _attack_time >= attack_windup:
		_struck = true
		_strike()
	if _attack_time >= attack_windup + attack_recover:
		state = State.IDLE


func _strike() -> void:
	var landed := false
	var kills := 0
	var knockback := weapon_knockback * (HEAVY_KNOCKBACK if has_relic("heavy_hits") else 1.0)
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
		if state != State.ATTACK and state != State.SKILL \
				and _visual.sprite_frames.has_animation("hurt_" + _dir_name()):
			_hurt_left = HURT_ANIM_TIME
			_visual.play("hurt_" + _dir_name())


func sacrifice_hp(amount: int) -> bool:
	## Voluntary HP cost (blood shrine): bypasses i-frames, refuses to kill.
	if dead or hp <= amount:
		return false
	hp -= amount
	_camera.add_trauma(0.3)
	Sfx.play("hurt")
	_play_flash()
	return true


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
	_reset_skill_windup_visual()  # dying mid-windup: physics stops, nothing else resets it
	set_process_unhandled_input(false)
	# Can't free/disable shapes mid-physics-callback.
	$CollisionShape2D.set_deferred("disabled", true)
	if _blink_tween:
		_blink_tween.kill()
	_camera.add_trauma(DEATH_TRAUMA)
	Sfx.play("death_player")
	# Play the fall-back death clip in the last facing, then fade out inside
	# DeathScreen's SHOW_DELAY (before the recap appears and the scene changes).
	_hurt_left = 0.0
	_visual.modulate.a = 1.0
	_visual.play("death_" + _dir_name())
	var t := create_tween()
	t.tween_interval(0.55)
	t.tween_property(_visual, "modulate:a", 0.0, 0.3)
	GameManager.player_died()
