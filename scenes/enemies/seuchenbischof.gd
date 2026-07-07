extends "res://scenes/enemies/boss_base.gd"
## Boss "Seuchenbischof": a plague priest (zoner). Close -> drops burning ground
## patches (telegraphed rings, then fire) on/around the player to deny space;
## far -> a rotating spiral projectile volley. Enrages below half HP.

const FIRE_PATCH := preload("res://scenes/effects/fire_patch.gd")
const BOSS_PROJECTILE := preload("res://scenes/projectiles/projectile.tscn")
const PATCH_TRIGGER := 240.0
const PATCH_OFFSETS := [Vector2.ZERO, Vector2(96, 0), Vector2(-72, 72)]
const SPIRAL_SHOTS := 10
const ENRAGE_SPEEDUP := 0.6

enum Pattern { PATCH, SPIRAL }

var _pattern := Pattern.SPIRAL
var _spiral_deg := 0.0
var _markers: Array[Node2D] = []
var _patch_targets: Array[Vector2] = []


func _begin_attack() -> void:
	_pattern = Pattern.PATCH if _distance_to_player() <= PATCH_TRIGGER else Pattern.SPIRAL
	super()


func _show_attack_tell() -> void:
	if _pattern != Pattern.PATCH:
		return
	# Telegraph fixed ground spots (level children so they don't follow the boss).
	_patch_targets.clear()
	var base := _player.global_position if _player_alive() else global_position
	for off: Vector2 in PATCH_OFFSETS:
		var pos: Vector2 = base + off
		_patch_targets.append(pos)
		_spawn_marker(pos)


func _perform_attack() -> void:
	match _pattern:
		Pattern.PATCH:
			_do_patch()
		Pattern.SPIRAL:
			_do_spiral()
	if _enraged():
		_cooldown_left *= ENRAGE_SPEEDUP


func _do_patch() -> void:
	_clear_markers()
	Sfx.play("slam", -3.0)
	for pos: Vector2 in _patch_targets:
		var f: Node2D = FIRE_PATCH.new()
		f.position = pos
		get_parent().add_child(f)


func _do_spiral() -> void:
	Sfx.play("shoot")
	for i in SPIRAL_SHOTS:
		var dir := Vector2.from_angle(deg_to_rad(_spiral_deg + i * (360.0 / SPIRAL_SHOTS)))
		var p := BOSS_PROJECTILE.instantiate()
		p.direction = dir
		p.damage = 1
		p.position = global_position + dir * 30.0
		get_parent().add_child(p)
	_spiral_deg += 18.0  # each volley rotates -> reads as a spiral


func _spawn_marker(pos: Vector2) -> void:
	var ring := Line2D.new()
	ring.width = 3.0
	ring.default_color = Color(0.45, 0.9, 0.35, 0.5)
	var pts := PackedVector2Array()
	for i in 33:
		pts.append(Vector2.from_angle(TAU * i / 32.0) * 60.0)
	ring.points = pts
	ring.global_position = pos
	get_parent().add_child(ring)
	_markers.append(ring)


func _clear_markers() -> void:
	for m in _markers:
		if is_instance_valid(m):
			m.queue_free()
	_markers.clear()


func _cancel_attack() -> void:
	_clear_markers()
	super()
