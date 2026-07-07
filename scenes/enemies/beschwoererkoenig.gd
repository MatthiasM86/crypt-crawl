extends "res://scenes/enemies/boss_base.gd"
## Boss "Beschwörerkönig": a robed lich (summoner). Alternates between summoning
## a minion pack and firing a projectile fan; blinks away when the player closes
## in, so it stays a ranged menace. Enrages below half HP.

const MINION_SCENE := preload("res://scenes/enemies/melee_enemy.tscn")
const BOSS_PROJECTILE := preload("res://scenes/projectiles/projectile.tscn")
const SUMMON_COUNT := 2
const FAN_COUNT := 5
const FAN_SPREAD := 46.0        # degrees, full cone
const TELEPORT_RANGE := 105.0
const TELEPORT_CD := 3.0
const TELEPORT_DIST := 250.0
const ENRAGE_SPEEDUP := 0.6

enum Pattern { SUMMON, FAN }

var _pattern := Pattern.FAN
var _tp_cd := 0.0
var _attacks := 0


func _physics_process(delta: float) -> void:
	_tp_cd = maxf(_tp_cd - delta, 0.0)
	if ai_enabled and _player_alive() and _tp_cd == 0.0 and state != State.ATTACK \
			and _distance_to_player() < TELEPORT_RANGE:
		_blink()
	super(delta)


func _blink() -> void:
	_tp_cd = TELEPORT_CD
	Sfx.play("shoot", -4.0)
	var away := global_position.direction_to(_player.global_position) * -1.0
	global_position += away.rotated(randf_range(-0.5, 0.5)) * TELEPORT_DIST
	var pop := _make_ring(24.0, Color(0.6, 0.4, 0.9, 0.85), 4.0)
	var t := pop.create_tween().set_parallel()
	t.tween_property(pop, "scale", Vector2(2.0, 2.0), 0.25)
	t.tween_property(pop, "modulate:a", 0.0, 0.25)
	t.chain().tween_callback(pop.queue_free)


func _begin_attack() -> void:
	_pattern = Pattern.SUMMON if _attacks % 2 == 0 else Pattern.FAN
	super()


func _perform_attack() -> void:
	_attacks += 1
	match _pattern:
		Pattern.SUMMON:
			_do_summon()
		Pattern.FAN:
			_do_fan()
	if _enraged():
		_cooldown_left *= ENRAGE_SPEEDUP


func _do_summon() -> void:
	Sfx.play("shoot", -2.0)
	for i in SUMMON_COUNT:
		var m: Node2D = MINION_SCENE.instantiate()
		m.position = global_position + Vector2(64, 0).rotated(TAU * i / SUMMON_COUNT + randf())
		get_parent().add_child(m)


func _do_fan() -> void:
	Sfx.play("shoot")
	var base := 0.0
	if _player_alive():
		base = (_player.global_position - global_position).angle()
	for i in FAN_COUNT:
		var frac := 0.0 if FAN_COUNT == 1 else float(i) / float(FAN_COUNT - 1) - 0.5
		var dir := Vector2.from_angle(base + deg_to_rad(FAN_SPREAD) * frac)
		var p := BOSS_PROJECTILE.instantiate()
		p.direction = dir
		p.damage = 1
		p.position = global_position + dir * 30.0
		get_parent().add_child(p)
