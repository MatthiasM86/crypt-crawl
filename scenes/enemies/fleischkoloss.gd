extends "res://scenes/enemies/boss_base.gd"
## Boss "Fleischkoloss": a hulking flesh brute (rusher). Far -> telegraphs a lane
## then CHARGES across the arena in a straight line (sidestep out of the lane!);
## close -> a ground shockwave slam. Enrages into faster attacks below half HP.

const CHARGE_TRIGGER := 240.0   # player farther than this -> charge, else slam
const CHARGE_SPEED := 640.0
const CHARGE_TIME := 0.55
const CHARGE_LANE_LEN := 430.0
const CHARGE_HIT_RANGE := 44.0
const SLAM_RADIUS := 130.0
const ENRAGE_SPEEDUP := 0.6

enum Pattern { CHARGE, SLAM }

var _pattern := Pattern.SLAM
var _charging := false
var _charge_left := 0.0
var _charge_dir := Vector2.RIGHT
var _charge_hit := false


func _physics_process(delta: float) -> void:
	if _charging:
		_charge_left -= delta
		velocity = _charge_dir * CHARGE_SPEED
		move_and_slide()
		if not _charge_hit and _player_alive() and _distance_to_player() <= CHARGE_HIT_RANGE:
			_player.take_damage(attack_damage, global_position)
			_charge_hit = true  # one hit per charge (player i-frames also guard)
		if _charge_left <= 0.0:
			_charging = false
			state = State.CHASE
		return
	super(delta)


func _begin_attack() -> void:
	_pattern = Pattern.CHARGE if _distance_to_player() >= CHARGE_TRIGGER else Pattern.SLAM
	super()


func _show_attack_tell() -> void:
	if _pattern == Pattern.CHARGE:
		_charge_dir = global_position.direction_to(_player.global_position) \
				if _player_alive() else Vector2.RIGHT
		_lane = _make_lane(_charge_dir, CHARGE_LANE_LEN, 26.0, Color(0.9, 0.2, 0.25, 0.28))
	else:
		_telegraph_ring = _make_ring(SLAM_RADIUS, Color(0.9, 0.2, 0.25, 0.35), 3.0)
		_telegraph_ring.scale = Vector2(0.25, 0.25)
		_telegraph_tween.tween_property(_telegraph_ring, "scale", Vector2.ONE, attack_windup)


func _perform_attack() -> void:
	_clear_telegraph_ring()
	match _pattern:
		Pattern.CHARGE:
			_start_charge()
		Pattern.SLAM:
			_do_slam()
	if _enraged():
		_cooldown_left *= ENRAGE_SPEEDUP


func _start_charge() -> void:
	Sfx.play("charge")
	_charging = true
	_charge_left = CHARGE_TIME
	_charge_hit = false


func _do_slam() -> void:
	Sfx.play("slam", -2.0)
	var flash := _make_ring(SLAM_RADIUS, Color(0.95, 0.3, 0.3, 0.9), 6.0)
	var t := flash.create_tween().set_parallel()
	t.tween_property(flash, "scale", Vector2(1.15, 1.15), 0.25)
	t.tween_property(flash, "modulate:a", 0.0, 0.25)
	t.chain().tween_callback(flash.queue_free)
	if _player_alive() and _distance_to_player() <= SLAM_RADIUS + 13.0:
		_player.take_damage(attack_damage, global_position)
