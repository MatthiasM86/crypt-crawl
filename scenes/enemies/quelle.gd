extends "res://scenes/enemies/boss_base.gd"
## Endboss "Die Quelle" (GameManager.FINAL_FLOOR = 50): the source of the
## flesh-plague and the run's win condition (docs/plan.md "Rahmen & Run-Ziel").
## A near-stationary caster with three telegraphed patterns:
##   AOE   -- slam ring when the player is close (dash out!)
##   RING  -- a dense projectile burst when far
##   BROOD -- periodically "births" minions (thematic: the source spawns flesh)
## Enrages below half HP (cooldowns speed up). Killing it is handled by
## level_generator._on_final_boss_defeated (banks the win, raises WinScreen).

const AOE_TRIGGER := 160.0     # player closer than this at windup start -> AoE
const AOE_RADIUS := 130.0
const RING_PROJECTILES := 12
const BROOD_EVERY := 3         # every Nth attack births minions instead
const BROOD_COUNT := 3
const BROOD_CAP := 4           # living births at once
const BROOD_HP := 3
const BROOD_SOULS := 1
const BROOD_TINT := Color(0.7, 0.35, 0.4)
const BOSS_SCALE := Vector2(1.5, 1.5)  # finale presence
const ENRAGE_SPEEDUP := 0.5    # cooldown multiplier while enraged

const BOSS_PROJECTILE := preload("res://scenes/projectiles/projectile.tscn")
const BROOD_SCENE := preload("res://scenes/enemies/melee_enemy.tscn")

enum Pattern { AOE, RING, BROOD }

var _pattern := Pattern.RING
var _attack_count := 0
var _brood: Array = []


func _ready() -> void:
	super()  # boss_base: enemy._ready() + joins "boss" group
	_base_scale = BOSS_SCALE  # telegraph scale ramps relative to this
	_visual.scale = _base_scale


func _begin_attack() -> void:
	# Pattern locks at windup start so the telegraph is honest.
	_attack_count += 1
	_prune_brood()
	if _attack_count % BROOD_EVERY == 0 and _brood.size() < BROOD_CAP:
		_pattern = Pattern.BROOD
	else:
		_pattern = Pattern.AOE if _distance_to_player() <= AOE_TRIGGER else Pattern.RING
	super()


func _show_attack_tell() -> void:
	match _pattern:
		Pattern.AOE:
			_telegraph_ring = _make_ring(AOE_RADIUS, Color(1, 0.3, 0.2, 0.35), 3.0)
			_telegraph_ring.scale = Vector2(0.25, 0.25)
			_telegraph_tween.tween_property(_telegraph_ring, "scale", Vector2.ONE, attack_windup)
		Pattern.BROOD:
			# Sickly green birth pulse -> reads as "something's coming".
			_telegraph_ring = _make_ring(70.0, Color(0.5, 0.9, 0.4, 0.5), 4.0)
			_telegraph_tween.tween_property(_telegraph_ring, "modulate:a", 0.12, attack_windup)
		Pattern.RING:
			pass  # body color/scale telegraph is enough


func _perform_attack() -> void:
	_clear_telegraph_ring()
	match _pattern:
		Pattern.AOE:
			_do_aoe()
		Pattern.RING:
			_do_ring()
		Pattern.BROOD:
			_do_brood()
	if _enraged():
		_cooldown_left *= ENRAGE_SPEEDUP


func _do_aoe() -> void:
	Sfx.play("slam", -2.0)
	var flash_ring := _make_ring(AOE_RADIUS, Color(1, 0.45, 0.25, 0.9), 6.0)
	var t := flash_ring.create_tween().set_parallel()
	t.tween_property(flash_ring, "scale", Vector2(1.15, 1.15), 0.25)
	t.tween_property(flash_ring, "modulate:a", 0.0, 0.25)
	t.chain().tween_callback(flash_ring.queue_free)
	# Distance check instead of a hitbox: boss -> player only, radius is king.
	if _player_alive() and _distance_to_player() <= AOE_RADIUS + 13.0:
		_player.take_damage(attack_damage, global_position)


func _do_ring() -> void:
	Sfx.play("shoot")
	for i in RING_PROJECTILES:
		var dir := Vector2.from_angle(TAU * i / RING_PROJECTILES)
		var projectile := BOSS_PROJECTILE.instantiate()
		projectile.direction = dir
		projectile.damage = 1
		projectile.position = global_position + dir * 34.0
		get_parent().add_child(projectile)


func _do_brood() -> void:
	Sfx.play("relic", -4.0)
	for i in BROOD_COUNT:
		if _brood.size() >= BROOD_CAP:
			return
		var minion: Node2D = BROOD_SCENE.instantiate()
		minion.max_hp = BROOD_HP
		minion.soul_value = BROOD_SOULS
		minion.get_node("Visual").self_modulate = BROOD_TINT
		# Snapped onto the navmesh: births next to a wall must not land inside it.
		minion.position = GameManager.snap_to_walkable(self,
				global_position + Vector2(52, 0).rotated(TAU * i / BROOD_COUNT + randf() * 0.6))
		get_parent().add_child(minion)
		_brood.append(minion)


func _prune_brood() -> void:
	_brood = _brood.filter(func(m): return is_instance_valid(m) and not m.dead)
